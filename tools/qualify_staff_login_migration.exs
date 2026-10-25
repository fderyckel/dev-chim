defmodule StaffLoginMigrationTrial do
  @moduledoc false
  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Identity.{PublicSessionAdapter, StaffDirectoryFixture, VerifiedLocalCredential}
  alias Chimwemwe.Platform.{Persistence, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @staff_version 20_261_024_134_746
  @basis_version 20_261_024_135_716

  def run do
    database = Application.fetch_env!(:chimwemwe_core, Repo) |> Keyword.fetch!(:database)

    unless Mix.env() == :test and String.starts_with?(database, "chimwemwe_staff_migration_") do
      raise "requires an isolated test-only staff-login migration database"
    end

    mode =
      cond do
        String.ends_with?(database, "_empty") -> :empty
        String.ends_with?(database, "_retained") -> :retained
        true -> raise "requires an explicit empty or retained migration mode"
      end

    {:ok, _applications} = Application.ensure_all_started(:chimwemwe_core)
    {:ok, _repo} = Repo.start_link(pool: DBConnection.ConnectionPool, pool_size: 4, log: false)

    # The trial never cleans an earlier database or overwrites retained evidence.
    %{rows: [[nil, nil]]} =
      Repo.query!(
        "SELECT to_regclass('identity_accounts')::text,to_regclass('schema_migrations')::text"
      )

    migrate(:up, all: true)
    true = installed?()
    true = List.last(Ecto.Migrator.migrated_versions(Repo)) == @basis_version
    trial(mode)
  end

  defp trial(:empty) do
    %{rows: [[0, 0]]} =
      Repo.query!(
        "SELECT (SELECT count(*) FROM identity_staff_directory_entries)," <>
          "(SELECT count(*) FROM identity_application_sessions)"
      )

    [@basis_version, @staff_version] = migrate(:down, step: 2)
    false = installed?()

    %{rows: [[nil, 0, "NO"]]} =
      Repo.query!("""
      SELECT to_regclass('identity_staff_directory_entries')::text,
        (SELECT count(*) FROM information_schema.columns
          WHERE table_schema='public' AND table_name='identity_application_sessions'
            AND column_name IN ('local_account_id','local_credential_fingerprint')),
        (SELECT is_nullable FROM information_schema.columns
          WHERE table_schema='public' AND table_name='identity_application_sessions'
            AND column_name='external_identity_link_id')
      """)

    [@staff_version, @basis_version] = migrate(:up, all: true)
    true = installed?()
    true = List.last(Ecto.Migrator.migrated_versions(Repo)) == @basis_version
    IO.puts("Empty staff-login apply/rollback/reapply passed; isolated database retained.")
  end

  defp trial(:retained) do
    Application.put_env(
      :chimwemwe_core,
      :identity_session_hmac_secret,
      Base.encode64(:crypto.strong_rand_bytes(48))
    )

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
      Base.encode64(:crypto.strong_rand_bytes(48))
    ])

    {:ok, persistence} = PersistenceRuntime.start_link(Fixture.runtime_options())
    {:ok, f} = StaffDirectoryFixture.seed!(persistence)
    password = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    f = StaffDirectoryFixture.bootstrap!(f, password)

    try do
      {:ok, {:ok, proof}} =
        Persistence.with_writer(persistence, Fixture.context_a(), fn ->
          VerifiedLocalCredential.authenticate(StaffDirectoryFixture.admin_email(), password)
        end)

      target = %{
        tenant_id: TrustedActor.tenant_id(Fixture.context_a().actor),
        membership_id: f.membership_a,
        locale: "en"
      }

      {:ok, cookie} = PublicSessionAdapter.complete_local_sign_in(persistence, proof, target)
      {:ok, _request} = authenticate(persistence, cookie)
      before = retained_digest()
      versions = Ecto.Migrator.migrated_versions(Repo)

      refused =
        try do
          migrate(:down, step: 1)
          false
        rescue
          error in Postgrex.Error ->
            error.postgres.code == :raise_exception and
              error.postgres.message == "retained local credential basis requires forward repair"
        end

      true = refused
      true = before == retained_digest()
      true = versions == Ecto.Migrator.migrated_versions(Repo)
      true = @basis_version in versions
      true = installed?()

      # Check the retained cookie after comparing rows: validation refreshes idle state.
      {:ok, request} = authenticate(persistence, cookie)
      true = request.session.actor_id == f.admin_account.actor_id

      IO.puts(
        "Retained staff-login rollback refusal, row preservation and live local session passed; isolated database retained."
      )
    after
      for source <- [f.source, f.account_source],
          do: if(Process.alive?(source), do: Agent.stop(source))

      Supervisor.stop(persistence)
    end
  end

  defp authenticate(runtime, cookie),
    do: PublicSessionAdapter.authenticate(runtime, cookie, :session_read, "en", UUID.generate())

  defp retained_digest do
    # Only digests leave PostgreSQL; account hashes and session material are never printed.
    %{rows: [[accounts, entries, sessions]]} =
      Repo.query!("""
      SELECT
        (SELECT md5(COALESCE(jsonb_agg(to_jsonb(a) ORDER BY id)::text,'[]')) FROM identity_accounts a),
        (SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM identity_staff_directory_entries d),
        (SELECT md5(COALESCE(jsonb_agg(to_jsonb(s) ORDER BY id)::text,'[]')) FROM identity_application_sessions s)
      """)

    {accounts, entries, sessions}
  end

  defp installed? do
    %{rows: [[table, fingerprint]]} =
      Repo.query!("""
      SELECT to_regclass('identity_staff_directory_entries')::text,
        EXISTS(SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='identity_application_sessions'
            AND column_name='local_credential_fingerprint')
      """)

    table != nil and fingerprint
  end

  defp migrate(direction, options) do
    path = Application.app_dir(:chimwemwe_core, "priv/repo/migrations")
    Ecto.Migrator.run(Repo, path, direction, Keyword.put(options, :log, false))
  end
end

StaffLoginMigrationTrial.run()
