# Dedicated synthetic migration evidence only. Never deletes retained accounts.
alias Chimwemwe.Identity.LocalCredentials
alias Chimwemwe.Repo

database = Application.fetch_env!(:chimwemwe_core, Repo) |> Keyword.fetch!(:database)

unless String.starts_with?(database, "chimwemwe_account_fence_migration_") do
  raise "requires an isolated account-fence migration database"
end

mode =
  cond do
    String.ends_with?(database, "_empty") -> :empty
    String.ends_with?(database, "_retained") -> :retained
    true -> raise "requires explicit empty or retained migration mode"
  end

{:ok, _repo} = Repo.start_link(pool: DBConnection.ConnectionPool, pool_size: 2)
path = Application.app_dir(:chimwemwe_core, "priv/repo/migrations")
version = 20_261_023_195_111

guard_installed? = fn ->
  %{rows: [[count]]} =
    Repo.query!("""
    SELECT count(*) FROM pg_trigger
    WHERE tgrelid = 'identity_accounts'::regclass
      AND tgname IN ('identity_accounts_source_guard', 'identity_accounts_source_truncate')
      AND NOT tgisinternal
    """)

  count == 2
end

case mode do
  :empty ->
    Ecto.Migrator.run(Repo, path, :up, all: true, log: false)
    true = guard_installed?.()
    true = List.last(Ecto.Migrator.migrated_versions(Repo)) == version
    [^version] = Ecto.Migrator.run(Repo, path, :down, step: 1, log: false)
    false = guard_installed?.()
    [^version] = Ecto.Migrator.run(Repo, path, :up, all: true, log: false)
    true = guard_installed?.()
    IO.puts("Empty apply/rollback/reapply passed; database retained.")

  :retained ->
    Ecto.Migrator.run(Repo, path, :up, to: version - 1, log: false)
    false = guard_installed?.()

    # Discard the generated temporary password inside this process; never print it.
    {:ok, %{account: account}} =
      LocalCredentials.provision("retained-fence@example.test", Ecto.UUID.generate())

    digest = fn ->
      %{rows: [[digest]]} =
        Repo.query!("SELECT md5(row_to_json(a)::text) FROM identity_accounts a WHERE id = $1", [
          Ecto.UUID.dump!(account.id)
        ])

      digest
    end

    before = digest.()
    [^version] = Ecto.Migrator.run(Repo, path, :up, all: true, log: false)
    true = digest.() == before
    true = guard_installed?.()

    refused =
      try do
        Ecto.Migrator.run(Repo, path, :down, step: 1, log: false)
        false
      rescue
        error in Postgrex.Error ->
          error.postgres.message == "retained accounts require forward repair"
      end

    true = refused
    true = digest.() == before
    true = guard_installed?.()
    true = version in Ecto.Migrator.migrated_versions(Repo)

    # Existing named application writers still work after the expansion.
    {:ok, suspended} = LocalCredentials.suspend(account.id)
    true = suspended.id == account.id and suspended.status == :suspended

    IO.puts(
      "Retained row preservation, rollback refusal and old writer passed; database retained."
    )
end
