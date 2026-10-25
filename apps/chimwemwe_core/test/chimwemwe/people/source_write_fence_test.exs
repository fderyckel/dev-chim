defmodule Chimwemwe.People.SourceWriteFenceTest do
  use ExUnit.Case, async: false
  import Chimwemwe.People.StaffAudienceFixture
  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.People.{Error, Foundation, InternalWriter, StaffAudience}
  alias Chimwemwe.Platform.{Persistence, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, f} = Fixture.seed!(persistence)
    old = Application.get_env(:chimwemwe_core, :identity_session_hmac_secret)

    Application.put_env(
      :chimwemwe_core,
      :identity_session_hmac_secret,
      :crypto.strong_rand_bytes(48)
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:chimwemwe_core, :identity_session_hmac_secret, old),
        else: Application.delete_env(:chimwemwe_core, :identity_session_hmac_secret)

      for agent <- [f.source, f.account_source],
          do: if(Process.alive?(agent), do: Agent.stop(agent))

      cleanup!()
    end)

    {:ok, connect!(f)}
  end

  for operation <- [
        :person_insert,
        :person_revise,
        :staff_insert,
        :staff_end,
        :association_insert,
        :association_revoke,
        :person_delete,
        :participation_delete,
        :association_delete
      ] do
    @operation operation
    test "actual write fence orders SQL #{@operation} before semantic/FK work", f do
      recipient = staff!(f, dates: %{effective_from: Date.add(Date.utc_today(), -1)})
      {sql, params} = operation(f, recipient, @operation)
      {source, source_backend} = hold_source(f)
      writer = writer(f, sql, params)
      assert_receive {:writer_started, backend}, 1_000
      assert wait_blocked(f, backend, source_backend, :advisory)
      release_source(source)
      result = Task.await(writer)

      if @operation in [:person_delete, :participation_delete, :association_delete],
        do: assert(result == {:ok, {:error, :check_violation}}),
        else: assert(result == {:ok, {:ok, :written}})

      assert {:ok, _} = StaffAudience.capture(f.audience, f.request, draft())
    end
  end

  test "new source guards precede the retained semantic guards on all three tables", f do
    for table <- tables() do
      %{rows: [["people_00_source_fence", "O"] | existing_guards]} =
        sql!(
          f,
          """
          SELECT tgname, tgenabled::text FROM pg_trigger
          WHERE tgrelid = $1::text::regclass AND NOT tgisinternal AND (tgtype::int & 2) <> 0
          ORDER BY tgname
          """,
          [table]
        )

      assert existing_guards != []
      assert Enum.all?(existing_guards, fn [_name, enabled] -> enabled == "O" end)
    end
  end

  test "missing source tenant is refused without a write", f do
    assert {:ok, {:error, :check_violation}} = query(f, "SELECT people_source_lock(NULL)", [])
  end

  test "both old and proposed new tenant fences protect a rejected tenant move", f do
    person = Fixture.person!(f)

    for context <- [Fixture.context_a(), Fixture.context_b()] do
      parent = self()
      tenant = TrustedActor.tenant_id(context.actor)

      holder =
        Task.async(fn ->
          InternalWriter.run(f.persistence, context, fn _, _ ->
            Repo.query!("SELECT people_source_lock($1)", [UUID.dump!(tenant)])
            [[pid]] = Repo.query!("SELECT pg_backend_pid()").rows
            send(parent, {:tenant_held, pid})
            receive do: (:release -> {:ok, :released})
          end)
        end)

      assert_receive {:tenant_held, backend}, 1_000

      writer =
        writer(f, "UPDATE people_persons SET tenant_id = $2, lock_version = 2 WHERE id = $1", [
          UUID.dump!(person.id),
          UUID.dump!(TrustedActor.tenant_id(Fixture.context_b().actor))
        ])

      assert_receive {:writer_started, writer_backend}, 1_000
      assert wait_blocked(f, writer_backend, backend, :advisory)
      send(holder.pid, :release)
      assert {:ok, :released} = Task.await(holder)
      assert {:ok, {:error, :check_violation}} = Task.await(writer)
    end
  end

  test "unrelated tenant SQL progresses during a held source callback", f do
    {source, _backend} = hold_source(f)
    context = Fixture.context_b()

    assert {:ok, {:ok, :written}} =
             query(
               f,
               person_insert_sql(),
               [UUID.dump!(UUID.generate()), UUID.dump!(TrustedActor.tenant_id(context.actor))],
               context
             )

    release_source(source)
  end

  test "truncate is serialized by retained relation locks and always rolled back in the probe",
       f do
    for table <- tables() do
      before = sql!(f, "SELECT count(*) FROM #{table}").rows
      {source, backend} = hold_source(f)
      writer = writer(f, "TRUNCATE #{table} CASCADE", [], :always_rollback)
      assert_receive {:writer_started, writer_backend}, 1_000
      assert wait_blocked(f, writer_backend, backend, :any)
      release_source(source)
      assert {:ok, {:error, :probe_rollback}} = Task.await(writer)
      assert sql!(f, "SELECT count(*) FROM #{table}").rows == before
    end
  end

  test "reverse explicit row/fence order aborts a victim without partial owner evidence", f do
    person = Fixture.person!(f)
    tenant = TrustedActor.tenant_id(Fixture.context_a().actor)
    capability = UUID.generate()
    parent = self()

    owner =
      Task.async(fn ->
        InternalWriter.run(f.persistence, Fixture.context_a(), fn _, _ ->
          Repo.query!("SELECT people_source_lock($1)", [UUID.dump!(tenant)])

          Fixture.insert_capability(
            capability,
            tenant,
            "synthetic.fence_#{String.replace(capability, "-", "_")}"
          )

          send(parent, :owner_locked)
          receive do: (:continue -> :ok)

          Repo.query!("SELECT id FROM people_persons WHERE id = $1 FOR UPDATE", [
            UUID.dump!(person.id)
          ])

          {:ok, :owner_committed}
        end)
      end)

    assert_receive :owner_locked, 1_000

    alternate =
      Task.async(fn ->
        Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
          Repo.transaction(fn ->
            Repo.query!("SELECT id FROM people_persons WHERE id = $1 FOR UPDATE", [
              UUID.dump!(person.id)
            ])

            send(parent, :row_locked)
            receive do: (:continue -> :ok)

            sql_result(
              Repo.query(
                "UPDATE people_persons SET display_name = 'Synthetic changed', lock_version = 2 WHERE id = $1",
                [UUID.dump!(person.id)]
              ),
              :commit
            )
          end)
        end)
      end)

    assert_receive :row_locked, 1_000
    send(owner.pid, :continue)
    send(alternate.pid, :continue)
    owner_result = Task.await(owner)
    alternate_result = Task.await(alternate)

    assert {owner_result, alternate_result} in [
             {{:ok, :owner_committed}, {:ok, {:error, :deadlock_detected}}},
             {{:error, %Error{code: :retryable_dependency}}, {:ok, {:ok, :written}}}
           ]

    expected = if owner_result == {:ok, :owner_committed}, do: 1, else: 0

    assert sql!(f, "SELECT count(*) FROM platform_capabilities WHERE id = $1", [
             UUID.dump!(capability)
           ]).rows == [[expected]]
  end

  defp operation(f, _r, :person_insert),
    do: {person_insert_sql(), [UUID.dump!(UUID.generate()), tenant(f)]}

  defp operation(_f, r, :person_revise),
    do:
      {"UPDATE people_persons SET display_name = 'Synthetic revised', lock_version = 2 WHERE id = $1",
       [UUID.dump!(r.person.id)]}

  defp operation(f, _r, :staff_insert) do
    person = Fixture.person!(f)

    {"""
     INSERT INTO people_participations
       (id, tenant_id, person_id, institutional_unit_id, kind, effective_from, source_reference, lock_version, inserted_at)
     VALUES ($1,$2,$3,$4,'staff',CURRENT_DATE + 1,$5,1,NOW())
     """,
     Enum.map(
       [
         UUID.generate(),
         TrustedActor.tenant_id(Fixture.context_a().actor),
         person.id,
         f.unit.id,
         UUID.generate()
       ],
       &UUID.dump!/1
     )}
  end

  defp operation(_f, r, :staff_end),
    do:
      {"UPDATE people_participations SET effective_until = CURRENT_DATE, lock_version = 2 WHERE id = $1",
       [UUID.dump!(r.part.id)]}

  defp operation(f, r, :association_insert) do
    {:ok, _} =
      Foundation.revoke_staff_account_association(
        f.runtime,
        Fixture.context_a(),
        Map.merge(Fixture.keys(), %{association_id: r.association.id, expected_version: 1})
      )

    {"""
     INSERT INTO people_staff_account_associations
       (id, tenant_id, person_id, participation_id, membership_id, evidence_reference, verification, lock_version, inserted_at)
     SELECT $1, tenant_id, person_id, participation_id, membership_id, $2,
       jsonb_set(jsonb_set(verification, '{evidence_reference}', to_jsonb($2::uuid::text)),
         '{checked_at}', to_jsonb(clock_timestamp())), 1, NOW()
     FROM people_staff_account_associations WHERE id = $3
     """, Enum.map([UUID.generate(), UUID.generate(), r.association.id], &UUID.dump!/1)}
  end

  defp operation(_f, r, :association_revoke),
    do:
      {"UPDATE people_staff_account_associations SET revoked_at = clock_timestamp() AT TIME ZONE 'UTC', revoked_by_actor_id = $2, lock_version = 2 WHERE id = $1",
       [
         UUID.dump!(r.association.id),
         UUID.dump!(TrustedActor.actor_id(Fixture.context_a().actor))
       ]}

  defp operation(_f, r, :person_delete),
    do: {"DELETE FROM people_persons WHERE id = $1", [UUID.dump!(r.person.id)]}

  defp operation(_f, r, :participation_delete),
    do: {"DELETE FROM people_participations WHERE id = $1", [UUID.dump!(r.part.id)]}

  defp operation(_f, r, :association_delete),
    do:
      {"DELETE FROM people_staff_account_associations WHERE id = $1",
       [UUID.dump!(r.association.id)]}

  defp hold_source(f) do
    parent = self()

    source =
      Task.async(fn ->
        StaffAudience.capture(f.audience, f.request, draft(), fn _ ->
          [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
          send(parent, {:source_held, backend})
          receive do: (:release -> {:ok, :captured})
        end)
      end)

    assert_receive {:source_held, backend}, 1_000
    {source, backend}
  end

  defp release_source(source) do
    send(source.pid, :release)
    assert {:ok, :captured} = Task.await(source)
  end

  defp writer(f, sql, params, mode \\ :commit) do
    parent = self()

    Task.async(fn ->
      query(
        f,
        sql,
        params,
        Fixture.context_a(),
        fn ->
          [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
          send(parent, {:writer_started, backend})
        end,
        mode
      )
    end)
  end

  defp query(
         f,
         sql,
         params,
         context \\ Fixture.context_a(),
         barrier \\ fn -> :ok end,
         mode \\ :commit
       ) do
    Persistence.with_writer(f.persistence, context, fn ->
      Repo.transaction(fn ->
        barrier.()
        sql_result(Repo.query(sql, params), mode)
      end)
    end)
  end

  defp sql_result({:error, %Postgrex.Error{postgres: %{code: code}}}, _), do: Repo.rollback(code)
  defp sql_result({:ok, _}, :always_rollback), do: Repo.rollback(:probe_rollback)
  defp sql_result({:ok, _}, :commit), do: :written

  defp wait_blocked(f, writer, source, kind),
    do: wait_blocked(f, writer, source, kind, System.monotonic_time(:millisecond) + 700)

  defp wait_blocked(f, writer, source, kind, deadline) do
    %{rows: [[blocked, event]]} =
      sql!(
        f,
        "SELECT $2 = ANY(pg_blocking_pids($1)), wait_event FROM pg_stat_activity WHERE pid = $1",
        [writer, source]
      )

    cond do
      blocked and (kind == :any or event == "advisory") ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(2)
        wait_blocked(f, writer, source, kind, deadline)
    end
  end

  defp tenant(_f), do: UUID.dump!(TrustedActor.tenant_id(Fixture.context_a().actor))

  defp tables,
    do: ["people_persons", "people_participations", "people_staff_account_associations"]

  defp person_insert_sql,
    do:
      "INSERT INTO people_persons (id, tenant_id, display_name, lock_version, inserted_at) VALUES ($1,$2,'Synthetic fence person',1,NOW())"
end
