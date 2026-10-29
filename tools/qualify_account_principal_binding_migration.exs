defmodule AccountBindingMigrationTrial do
  @moduledoc false

  alias AshAuthentication.BcryptProvider
  alias Chimwemwe.Identity.LocalCredentials
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @version 20_261_024_134_151

  def run do
    database = Application.fetch_env!(:chimwemwe_core, Repo) |> Keyword.fetch!(:database)

    unless String.starts_with?(database, "chimwemwe_binding_migration_") do
      raise "requires a dedicated binding-marker migration database"
    end

    mode =
      Enum.find(["empty", "retained", "deleted", "exhausted", "contended"], fn mode ->
        String.ends_with?(database, "_#{mode}")
      end) || raise "requires an explicit migration trial mode"

    {:ok, _applications} = Application.ensure_all_started(:chimwemwe_core)
    {:ok, _repo} = Repo.start_link(pool: DBConnection.ConnectionPool, pool_size: 4)
    migrate(:up, to: @version - 1)
    %{rows: [[0]]} = Repo.query!("SELECT count(*) FROM identity_accounts")
    trial(mode)
    IO.puts("Binding-marker #{mode} trial passed; isolated database retained.")
  end

  defp trial("empty") do
    [@version] = migrate(:up, to: @version)
    true = installed?()
    [@version] = migrate(:down, step: 1)
    false = installed?()
    [@version] = migrate(:up, to: @version)
    true = installed?()
  end

  defp trial("retained") do
    id = legacy_insert!()
    _other = legacy_insert!()
    before = retained_digest(id)
    [@version] = migrate(:up, to: @version)
    true = before == retained_digest(id)

    %{rows: [[2, 2]]} =
      Repo.query!(
        "SELECT count(*), count(DISTINCT principal_binding_id) FROM identity_accounts WHERE principal_binding_id > 0"
      )

    binding = binding_marker(id)
    refuse_down!()
    true = before == retained_digest(id)
    true = binding == binding_marker(id)
    {:ok, account} = LocalCredentials.suspend(id)
    true = account.principal_binding_id == binding
    _old_shape_insert = legacy_insert!()
  end

  defp trial("deleted") do
    [@version] = migrate(:up, to: @version)
    id = legacy_insert!()
    Repo.query!("DELETE FROM identity_accounts WHERE id = $1", [UUID.dump!(id)])
    %{rows: [[0]]} = Repo.query!("SELECT count(*) FROM identity_accounts")
    refuse_down!()
  end

  defp trial("exhausted") do
    [@version] = migrate(:up, to: @version)
    id = legacy_insert!()
    original = retained_digest(id)
    binding = binding_marker(id)

    # Privileged fault injection in this dedicated database only; never reset it afterward.
    Repo.query!(
      "SELECT setval('identity_account_principal_binding_sequence', 9223372036854775807, true)"
    )

    {:error, %Postgrex.Error{postgres: %{code: :sequence_generator_limit_exceeded}}} =
      Repo.query("UPDATE identity_accounts SET actor_id = $2 WHERE id = $1", [
        UUID.dump!(id),
        UUID.dump!(UUID.generate())
      ])

    {:error, %Postgrex.Error{postgres: %{code: :sequence_generator_limit_exceeded}}} =
      Repo.query(
        """
        INSERT INTO identity_accounts (id, actor_id, email, hashed_password, status,
          lock_version, inserted_at, updated_at)
        SELECT $2, $3, $4, hashed_password, status, 1, NOW(), NOW()
        FROM identity_accounts WHERE id = $1
        """,
        [
          UUID.dump!(id),
          UUID.dump!(UUID.generate()),
          UUID.dump!(UUID.generate()),
          "exhausted@example.test"
        ]
      )

    true = retained_digest(id) == original
    true = binding_marker(id) == binding
    {:ok, account} = LocalCredentials.suspend(id)
    true = account.principal_binding_id == binding
    %{rows: [[1]]} = Repo.query!("SELECT count(*) FROM identity_accounts")
    refuse_down!()
  end

  defp trial("contended") do
    id = legacy_insert!()
    before = retained_digest(id)
    parent = self()

    holder =
      Task.async(fn ->
        Repo.transaction(fn ->
          Repo.query!("SELECT id FROM identity_accounts WHERE id = $1 FOR UPDATE", [
            UUID.dump!(id)
          ])

          send(parent, :row_held)

          receive do
            :release -> :released
          after
            10_000 -> Repo.rollback(:trial_timeout)
          end
        end)
      end)

    receive do
      :row_held -> :ok
    after
      2_000 -> raise "migration trial barrier unavailable"
    end

    try do
      true = refuses?({:up, [to: @version]}, :lock_not_available)
      false = installed?()
      true = retained_digest(id) == before
    after
      send(holder.pid, :release)
      {:ok, :released} = Task.await(holder)
    end

    [@version] = migrate(:up, to: @version)
    true = retained_digest(id) == before
    true = binding_marker(id) > 0
  end

  defp legacy_insert! do
    id = UUID.generate()
    {:ok, hash} = BcryptProvider.hash(Base.url_encode64(:crypto.strong_rand_bytes(24)))

    Repo.query!(
      """
      INSERT INTO identity_accounts (id, actor_id, email, hashed_password, status,
        lock_version, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, 'active', 1, NOW(), NOW())
      """,
      [UUID.dump!(id), UUID.dump!(UUID.generate()), "legacy-#{id}@example.test", hash]
    )

    id
  end

  defp retained_digest(id) do
    %{rows: [[digest]]} =
      Repo.query!(
        "SELECT md5((to_jsonb(a) - 'principal_binding_id')::text) FROM identity_accounts a WHERE id = $1",
        [UUID.dump!(id)]
      )

    digest
  end

  defp binding_marker(id) do
    %{rows: [[binding]]} =
      Repo.query!("SELECT principal_binding_id FROM identity_accounts WHERE id = $1", [
        UUID.dump!(id)
      ])

    binding
  end

  defp installed? do
    %{rows: [[name]]} =
      Repo.query!("SELECT to_regclass('identity_account_principal_binding_sequence')::text")

    name != nil
  end

  defp refuse_down! do
    true = refuses?({:down, [step: 1]}, :raise_exception)
    true = installed?()
    true = @version in Ecto.Migrator.migrated_versions(Repo)
  end

  defp refuses?({direction, options}, code) do
    migrate(direction, options)
    false
  rescue
    error in Postgrex.Error -> error.postgres.code == code
  end

  defp migrate(direction, options) do
    path = Application.app_dir(:chimwemwe_core, "priv/repo/migrations")
    Ecto.Migrator.run(Repo, path, direction, Keyword.put(options, :log, false))
  end
end

AccountBindingMigrationTrial.run()
