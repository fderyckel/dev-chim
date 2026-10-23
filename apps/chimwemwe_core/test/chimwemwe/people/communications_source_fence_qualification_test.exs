defmodule Chimwemwe.People.CommunicationsSourceFenceQualificationTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Identity.{AccountSourceFence, LocalCredentials}
  alias Chimwemwe.People.{Foundation, Runtime, TestVerifier}
  alias Chimwemwe.Platform.{ModuleLifecycle, Persistence, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  # Qualification probes only: no audience API, communication state or publication exists.
  # A passing counterexample test means the candidate fence is insufficient.
  setup_all do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, fixture} = Fixture.seed!(persistence)
    {:ok, account_source} = Agent.start_link(fn -> %{records: %{}, overrides: %{}, calls: 0} end)
    {:ok, runtime} = Runtime.new(persistence, TestVerifier, account_source)
    {:ok, Map.merge(fixture, %{runtime: runtime, account_source: account_source})}
  end

  test "locking returned participation rows does not fence a new staff phantom", f do
    person = Fixture.person!(f)

    holder =
      hold(f, fn ->
        Repo.query!(
          "SELECT id FROM people_participations WHERE tenant_id = $1 AND institutional_unit_id = $2 FOR UPDATE",
          scope(f)
        )
      end)

    before_count = staff_count(f)
    writer = writer(f, fn -> record_staff(f, person) end)
    assert {:ok, {:ok, _part}} = Task.await(writer)
    assert staff_count(f) == before_count + 1
    release(holder)
  end

  test "the existing people lifecycle lock orders a named staff insert after release", f do
    person = Fixture.person!(f)
    {holder, holder_backend} = hold_with_backend(f, &lock_people/0)
    writer = writer(f, fn -> record_staff(f, person) end)
    assert_receive {:writer_backend, writer_pid, writer_backend}, 1_000
    assert writer_pid == writer.pid
    assert_blocked_by(f, writer_backend, holder_backend)
    release(holder)
    assert {:ok, {:ok, _part}} = Task.await(writer)
  end

  test "people lifecycle and existing-account row locks do not fence absent-account provisioning",
       f do
    {person, part, membership, actor} = linked_staff!(f)

    assert {:ok, %{person_id: person_id}} =
             Foundation.current_staff_account(f.runtime, Fixture.context_a(), membership)

    assert person_id == person.id

    holder =
      hold(f, fn ->
        lock_people()
        assert %{rows: []} = lock_account(actor)
      end)

    # This real named credential operation commits before the candidate fence is released.
    # Its generated password is discarded inside the request process, never logged or returned.
    writer = writer(f, fn -> provision(actor) end)
    assert {:ok, {:ok, account_id}} = Task.await(writer)

    assert {:ok, %{id: association_id, participation_id: participation_id}} =
             read_link_while_held(f, holder, membership)

    assert is_binary(association_id)
    assert participation_id == part.id

    assert {:ok, %{rows: [[^account_id, "pending_first_login"]]}} =
             Fixture.query(
               f,
               "SELECT id::text, status FROM identity_accounts WHERE actor_id = $1",
               [UUID.dump!(actor)]
             )

    release(holder)

    # A People association is still not an account-status or session eligibility API.
    assert {:ok, _association} =
             Foundation.current_staff_account(f.runtime, Fixture.context_a(), membership)
  end

  test "an existing account row can be fenced against named suspension", f do
    actor = UUID.generate()

    assert {:ok, {:ok, account_id}} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               provision(actor)
             end)

    {holder, holder_backend} = hold_with_backend(f, fn -> lock_account(actor) end)

    writer =
      writer(f, fn ->
        case LocalCredentials.suspend(account_id) do
          {:ok, account} -> {:ok, account.status}
          {:error, error} -> {:error, error}
        end
      end)

    assert_receive {:writer_backend, writer_pid, writer_backend}, 1_000
    assert writer_pid == writer.pid
    assert_blocked_by(f, writer_backend, holder_backend)
    release(holder)
    assert {:ok, {:ok, :suspended}} = Task.await(writer)
  end

  test "people lifecycle plus account source fence orders previously absent account provisioning",
       f do
    {_person, _part, membership, actor} = linked_staff!(f)

    {holder, holder_backend} =
      hold_with_backend(f, fn ->
        lock_people()
        :ok = AccountSourceFence.lock_current_transaction(Fixture.context_a(), [actor])

        assert %{rows: []} =
                 Repo.query!("SELECT id FROM identity_accounts WHERE actor_id = $1", [
                   UUID.dump!(actor)
                 ])
      end)

    writer = writer(f, fn -> provision(actor) end)
    assert_receive {:writer_backend, writer_pid, writer_backend}, 1_000
    assert writer_pid == writer.pid
    assert_blocked_by(f, writer_backend, holder_backend)
    assert {:ok, _association} = read_link_while_held(f, holder, membership)
    release(holder)
    assert {:ok, {:ok, _account_id}} = Task.await(writer)
  end

  defp linked_staff!(f) do
    person = Fixture.person!(f)
    part = Fixture.participation!(f, person, :staff)
    actor = UUID.generate()
    membership = UUID.generate()
    tenant = TrustedActor.tenant_id(Fixture.context_a().actor)

    assert {:ok, _} =
             Fixture.query(
               f,
               "INSERT INTO platform_tenant_memberships (id, tenant_id, actor_id, inserted_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
               Enum.map([membership, tenant, actor], &UUID.dump!/1)
             )

    evidence = UUID.generate()

    Agent.update(f.account_source, fn source ->
      put_in(source, [:records, evidence], %{
        tenant_id: tenant,
        person_id: person.id,
        participation_id: part.id,
        membership_id: membership,
        actor_id: actor
      })
    end)

    assert {:ok, _association} =
             Foundation.associate_staff_account(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 participation_id: part.id,
                 expected_version: part.lock_version,
                 expected_person_version: person.lock_version,
                 membership_id: membership,
                 evidence_reference: evidence
               })
             )

    {person, part, membership, actor}
  end

  defp record_staff(f, person),
    do:
      Foundation.record_staff_affiliation(
        f.runtime,
        Fixture.context_a(),
        Fixture.participation_input(f, person)
      )

  defp provision(actor) do
    case LocalCredentials.provision("fence-#{actor}@example.test", actor) do
      {:ok, %{account: account}} -> {:ok, account.id}
      {:error, error} -> {:error, error}
    end
  end

  defp lock_people do
    :ok =
      ModuleLifecycle.authorize_current_transaction(
        Foundation.release_manifest(),
        Fixture.context_a(),
        "people.core",
        "people.core.participations.read"
      )
  end

  defp lock_account(actor),
    do:
      Repo.query!("SELECT id FROM identity_accounts WHERE actor_id = $1 FOR SHARE", [
        UUID.dump!(actor)
      ])

  defp hold(f, lock) do
    {holder, _backend} = hold_with_backend(f, lock)
    holder
  end

  defp hold_with_backend(f, lock) do
    parent = self()
    holder = Task.async(fn -> hold_fence(f, parent, lock) end)

    assert_receive {:fence_held, holder_pid, backend}, 1_000
    assert holder_pid == holder.pid
    {holder, backend}
  end

  defp hold_fence(f, parent, lock) do
    Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
      Repo.transaction(fn -> run_held_fence(f, parent, lock) end)
    end)
  end

  defp run_held_fence(f, parent, lock) do
    Repo.query!("SET LOCAL statement_timeout = '2000ms'")
    lock.()
    %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
    send(parent, {:fence_held, self(), backend})
    serve_fence(f)
  end

  defp serve_fence(f) do
    receive do
      :release ->
        :released

      {:read_link, from, membership} ->
        send(
          from,
          {:held_link,
           Foundation.current_staff_account(f.runtime, Fixture.context_a(), membership)}
        )

        serve_fence(f)
    after
      5_000 -> Repo.rollback(:qualification_barrier_timeout)
    end
  end

  defp read_link_while_held(_f, holder, membership) do
    send(holder.pid, {:read_link, self(), membership})
    assert_receive {:held_link, result}, 1_000
    result
  end

  defp release(holder) do
    send(holder.pid, :release)
    assert {:ok, {:ok, :released}} = Task.await(holder)
  end

  defp writer(f, operation) do
    parent = self()
    Task.async(fn -> run_writer(f, parent, operation) end)
  end

  defp run_writer(f, parent, operation) do
    Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
      writer_transaction(parent, operation)
    end)
  end

  defp writer_transaction(parent, operation) do
    # Pin the observed backend through the operation: a standalone PID query
    # would release its connection before the named writer checks one out.
    case Repo.transaction(fn -> run_writer_operation(parent, operation) end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_writer_operation(parent, operation) do
    %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
    send(parent, {:writer_backend, self(), backend})
    operation.()
  end

  defp assert_blocked_by(f, writer_backend, holder_backend) do
    deadline = System.monotonic_time(:millisecond) + 1_000
    assert wait_for_block(f, writer_backend, holder_backend, deadline)
  end

  defp wait_for_block(f, writer_backend, holder_backend, deadline) do
    {:ok, %{rows: [[blockers]]}} =
      Fixture.query(f, "SELECT pg_blocking_pids($1)", [writer_backend])

    cond do
      holder_backend in blockers ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(5)
        wait_for_block(f, writer_backend, holder_backend, deadline)
    end
  end

  defp staff_count(f) do
    {:ok, %{rows: [[count]]}} =
      Fixture.query(
        f,
        "SELECT count(*) FROM people_participations WHERE tenant_id = $1 AND institutional_unit_id = $2 AND kind = 'staff'",
        scope(f)
      )

    count
  end

  defp scope(f),
    do: Enum.map([TrustedActor.tenant_id(Fixture.context_a().actor), f.unit.id], &UUID.dump!/1)
end
