defmodule PeopleSourceFenceMigrationTrial do
  @moduledoc false
  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.People.{Error, Foundation, StaffAudience, StaffAudienceFixture}
  alias Chimwemwe.Platform.{PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID
  @version 20_261_025_091_633

  def run do
    database = Application.fetch_env!(:chimwemwe_core, Repo) |> Keyword.fetch!(:database)

    unless String.starts_with?(database, "chimwemwe_people_fence_migration_"),
      do: raise("dedicated People-fence migration database required")

    mode =
      Enum.find(
        ["empty", "retained", "contended", "rollback_race"],
        &String.ends_with?(database, "_#{&1}")
      ) ||
        raise "explicit migration mode required"

    {:ok, _} = Application.ensure_all_started(:chimwemwe_core)
    {:ok, _} = Repo.start_link(pool: DBConnection.ConnectionPool, pool_size: 4)
    migrate(:up, to: @version - 1)
    for table <- tables(), do: [[0]] = Repo.query!("SELECT count(*) FROM #{table}").rows
    trial(mode)
    IO.puts("People source-fence #{mode} migration trial passed; database retained.")
  end

  defp trial("empty") do
    [@version] = migrate(:up, to: @version)
    true = installed?()
    [@version] = migrate(:down, step: 1)
    false = installed?()
    semantic_guards!()
    [@version] = migrate(:up, to: @version)
    true = installed?()
  end

  defp trial("retained") do
    {:ok, persistence} = PersistenceRuntime.start_link(Fixture.runtime_options())
    {:ok, seeded} = Fixture.seed!(persistence)

    Application.put_env(
      :chimwemwe_core,
      :identity_session_hmac_secret,
      :crypto.strong_rand_bytes(48)
    )

    f = StaffAudienceFixture.connect!(seeded)
    reference = make_ref()

    {:error, %Error{code: :retryable_dependency}} =
      StaffAudience.capture(f.audience, f.request, StaffAudienceFixture.draft(), fn _ ->
        send(self(), reference)
        {:ok, :unexpected}
      end)

    receive do
      ^reference -> raise "old database reached source callback"
    after
      0 -> :ok
    end

    before = digest()
    [@version] = migrate(:up, to: @version)
    true = before == digest()
    true = installed?()
    semantic_guards!()
    captured!(f)

    try do
      migrate(:down, step: 1)
      raise "retained rollback unexpectedly succeeded"
    rescue
      error in Postgrex.Error ->
        unless error.postgres.code == :raise_exception and
                 error.postgres.message == "retained people sources require forward repair",
               do: reraise(error, __STACKTRACE__)
    end

    true = before == digest()
    true = installed?()
    true = @version in Ecto.Migrator.migrated_versions(Repo)
    {:ok, _} = Foundation.register_person(f.runtime, Fixture.context_a(), Fixture.person_input())
    legacy_insert!()
    captured!(f)
  end

  defp trial("contended") do
    parent = self()

    holder =
      Task.async(fn ->
        Repo.transaction(fn ->
          legacy_insert!()
          send(parent, :write_held)
          receive do: (:release -> :released)
        end)
      end)

    receive do
      :write_held -> :ok
    after
      2_000 -> raise "legacy writer barrier unavailable"
    end

    try do
      try do
        migrate(:up, to: @version)
        raise "contended DDL unexpectedly succeeded"
      rescue
        error in Postgrex.Error ->
          unless error.postgres.code == :lock_not_available, do: reraise(error, __STACKTRACE__)
      end

      false = installed?()
      semantic_guards!()
      false = @version in Ecto.Migrator.migrated_versions(Repo)
    after
      send(holder.pid, :release)
      {:ok, :released} = Task.await(holder)
    end

    before = digest()
    [@version] = migrate(:up, to: @version)
    true = installed?()
    true = before == digest()
  end

  defp trial("rollback_race") do
    [@version] = migrate(:up, to: @version)
    parent = self()

    holder =
      Task.async(fn ->
        Repo.transaction(fn ->
          legacy_insert!()
          send(parent, :rollback_write_held)
          receive do: (:release -> :released)
        end)
      end)

    receive do
      :rollback_write_held -> :ok
    after
      2_000 -> raise "rollback writer barrier unavailable"
    end

    try do
      try do
        migrate(:down, step: 1)
        raise "rollback raced past a retained source writer"
      rescue
        error in Postgrex.Error ->
          unless error.postgres.code == :lock_not_available, do: reraise(error, __STACKTRACE__)
      end

      true = installed?()
      semantic_guards!()
      true = @version in Ecto.Migrator.migrated_versions(Repo)
    after
      send(holder.pid, :release)
      {:ok, :released} = Task.await(holder)
    end

    try do
      migrate(:down, step: 1)
      raise "committed retained source unexpectedly permitted rollback"
    rescue
      error in Postgrex.Error ->
        unless error.postgres.message == "retained people sources require forward repair",
          do: reraise(error, __STACKTRACE__)
    end

    true = installed?()
  end

  defp legacy_insert! do
    Repo.query!(
      """
      INSERT INTO people_persons (id, tenant_id, display_name, lock_version, inserted_at)
      VALUES ($1,$2,'Synthetic migration person',1,NOW())
      """,
      [UUID.dump!(UUID.generate()), UUID.dump!(TrustedActor.tenant_id(Fixture.context_a().actor))]
    )
  end

  defp captured!(f) do
    {:ok, :captured} =
      StaffAudience.capture(f.audience, f.request, StaffAudienceFixture.draft(), fn _ ->
        {:ok, :captured}
      end)
  end

  defp digest do
    for table <- tables() do
      [[digest]] =
        Repo.query!(
          "SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY id)::text, '[]')) FROM #{table} t"
        ).rows

      digest
    end
  end

  defp installed? do
    [[count]] =
      Repo.query!("""
      SELECT count(*) FROM pg_trigger WHERE tgname = 'people_00_source_fence'
        AND NOT tgisinternal AND tgenabled = 'O'
      """).rows

    count == 3
  end

  defp semantic_guards! do
    [[3]] =
      Repo.query!(
        "SELECT count(*) FROM pg_trigger WHERE tgfoid = 'people_record_guard()'::regprocedure AND NOT tgisinternal AND tgenabled = 'O'"
      ).rows
  end

  defp tables,
    do: ["people_persons", "people_participations", "people_staff_account_associations"]

  defp migrate(direction, options) do
    Ecto.Migrator.run(
      Repo,
      Application.app_dir(:chimwemwe_core, "priv/repo/migrations"),
      direction,
      Keyword.put(options, :log, false)
    )
  end
end

PeopleSourceFenceMigrationTrial.run()
