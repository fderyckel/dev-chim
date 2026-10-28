defmodule Chimwemwe.Platform.PersistenceTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    AdmissionError,
    ContextError,
    DatabaseAdmission,
    ExecutionContext,
    Persistence,
    PersistenceError,
    PersistenceRuntime,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Repo

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @tenant_c "33333333-3333-4333-8333-333333333333"
  @tenant_unknown "44444444-4444-4444-8444-444444444444"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @actor_c "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @actor_unknown "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
  @correlation_id "cccccccc-cccc-4ccc-8ccc-cccccccccccc"

  test "resolves the current route, admits before checkout, and reaches PostgreSQL" do
    runtime = start_runtime()
    {:ok, expected_repository} = PersistenceRuntime.child_pid(runtime, {:repository, :pooled})
    default_repository = Repo.get_dynamic_repo()

    assert {:ok, {^expected_repository, [[1]]}} =
             Persistence.with_writer(runtime, context_a(), fn ->
               {Repo.get_dynamic_repo(), Repo.query!("SELECT 1").rows}
             end)

    assert Repo.get_dynamic_repo() == default_repository
  end

  test "selects dedicated and pooled pools only from startup-owned routes" do
    runtime = start_runtime()
    {:ok, pooled_repository} = PersistenceRuntime.child_pid(runtime, {:repository, :pooled})

    {:ok, dedicated_repository} =
      PersistenceRuntime.child_pid(runtime, {:repository, :dedicated})

    assert {:ok, ^pooled_repository} =
             Persistence.with_writer(runtime, context_a(), fn -> Repo.get_dynamic_repo() end)

    assert {:ok, ^dedicated_repository} =
             Persistence.with_writer(runtime, context_c(), fn -> Repo.get_dynamic_repo() end)

    refute function_exported?(Persistence, :with_writer, 4)
  end

  test "fails before database work for raw, mismatched, stale, forged, and unknown context" do
    runtime = start_runtime()
    callback = fn -> flunk("untrusted or stale context must fail before data access") end

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Persistence.with_writer(runtime, %{tenant_id: @tenant_a}, callback)

    mismatched = put_in(context_a().placement.tenant_id, @tenant_b)

    assert {:error, %ContextError{code: :tenant_mismatch}} =
             Persistence.with_writer(runtime, mismatched, callback)

    stale = put_in(context_a().placement.routing_version, 6)

    assert {:error, %PersistenceError{code: :route_not_available}} =
             Persistence.with_writer(runtime, stale, callback)

    forged = put_in(context_a().placement.placement_ref, "caller-selected")

    assert {:error, %PersistenceError{code: :route_not_available}} =
             Persistence.with_writer(runtime, forged, callback)

    assert {:error, %PersistenceError{code: :route_not_available}} =
             Persistence.with_writer(runtime, context_unknown(), callback)
  end

  test "restores repository state after failures and does not leak it into spawned work" do
    runtime = start_runtime()
    {:ok, expected_repository} = PersistenceRuntime.child_pid(runtime, {:repository, :pooled})
    default_repository = Repo.get_dynamic_repo()

    assert_raise RuntimeError, "synthetic persistence failure", fn ->
      Persistence.with_writer(runtime, context_a(), fn ->
        assert Repo.get_dynamic_repo() == expected_repository

        assert Repo ==
                 Task.async(fn -> Repo.get_dynamic_repo() end)
                 |> Task.await()

        raise "synthetic persistence failure"
      end)
    end

    assert Repo.get_dynamic_repo() == default_repository

    assert {:ok, [[2]]} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("SELECT 2").rows
             end)
  end

  test "wires tenant and placement admission ahead of repository checkout" do
    runtime = start_runtime(per_tenant_limit: 1, per_placement_limit: 2)
    parent = self()

    holder =
      Task.async(fn ->
        Persistence.with_writer(runtime, context_a(), fn ->
          send(parent, :writer_admitted)

          receive do
            :release_writer -> :released
          end
        end)
      end)

    assert_receive :writer_admitted

    assert {:error, %AdmissionError{code: :rate_limited}} =
             Persistence.with_writer(runtime, context_a(), fn ->
               flunk("tenant-saturated work must not reach the repository")
             end)

    assert {:ok, [[3]]} =
             Persistence.with_writer(runtime, context_b(), fn ->
               Repo.query!("SELECT 3").rows
             end)

    send(holder.pid, :release_writer)
    assert {:ok, :released} = Task.await(holder)
  end

  test "fails closed when the runtime is unavailable" do
    {:ok, runtime} = PersistenceRuntime.start_link(runtime_options())
    Process.unlink(runtime)
    :ok = Supervisor.stop(runtime)

    assert {:error, %PersistenceError{code: :retryable_dependency}} =
             Persistence.with_writer(runtime, context_a(), fn ->
               flunk("an unavailable runtime must not reach database work")
             end)
  end

  test "same-scope transaction nesting uses one permit, backend and transaction" do
    runtime = start_runtime(per_tenant_limit: 1)
    {:ok, admission} = PersistenceRuntime.child_pid(runtime, DatabaseAdmission)
    context = context_a()

    assert {:ok, {:ok, :complete}} =
             in_writer_transaction(runtime, context, fn ->
               before = DatabaseAdmission.statistics(admission)
               backend = Repo.query!("SELECT pg_backend_pid(), txid_current()").rows

               assert {:ok, ^backend} =
                        Persistence.with_writer(runtime, context, fn ->
                          Repo.query!("SELECT pg_backend_pid(), txid_current()").rows
                        end)

               assert DatabaseAdmission.statistics(admission) == before
               assert before.active_permits == 1 and before.admitted == 1
               :complete
             end)

    assert %{active_permits: 0, admitted: 1, tenant_rejections: 0} =
             DatabaseAdmission.statistics(admission)
  end

  test "nested calls outside a transaction cannot acquire or borrow another permit" do
    runtime = start_runtime()
    {:ok, admission} = PersistenceRuntime.child_pid(runtime, DatabaseAdmission)

    assert {:ok, :checked} =
             Persistence.with_writer(runtime, context_a(), fn ->
               assert_nested_refused(runtime, context_a())
               assert %{active_permits: 1, admitted: 1} = DatabaseAdmission.statistics(admission)
               :checked
             end)
  end

  test "nested reuse refuses every changed execution-context field" do
    runtime = start_runtime()
    context = context_a()

    {:ok, actor} =
      TrustedActor.establish(actor_id: @actor_b, tenant_id: @tenant_a, assurance: "mfa")

    different_contexts = [
      %{context | actor: actor},
      context_b(),
      context_c(),
      %{context | purpose: "another.purpose"},
      %{context | correlation_id: Ecto.UUID.generate()},
      %{context | locale: "fr"}
    ]

    assert {:ok, {:ok, :checked}} =
             in_writer_transaction(runtime, context, fn ->
               for different <- different_contexts, do: assert_nested_refused(runtime, different)
               :checked
             end)
  end

  test "nested reuse revalidates the current route before entering the operation" do
    runtime = start_runtime()
    {:ok, registry} = PersistenceRuntime.child_pid(runtime, Chimwemwe.Platform.PlacementRegistry)

    assert {:ok, {:ok, :checked}} =
             in_writer_transaction(runtime, context_a(), fn ->
               :sys.replace_state(registry, fn routes ->
                 put_in(routes, [@tenant_a, :placement, Access.key(:routing_version)], 8)
               end)

               assert {:error, %PersistenceError{code: :route_not_available}} =
                        Persistence.with_writer(runtime, context_a(), &never_called/0)

               :checked
             end)
  end

  test "nested reuse refuses another supervised runtime or a changed dynamic repository" do
    runtime = start_runtime()

    other =
      start_supervised!(
        Supervisor.child_spec({PersistenceRuntime, runtime_options()}, id: :other_runtime)
      )

    {:ok, admission} = PersistenceRuntime.child_pid(other, DatabaseAdmission)
    {:ok, dedicated} = PersistenceRuntime.child_pid(runtime, {:repository, :dedicated})

    assert {:ok, {:ok, :checked}} =
             in_writer_transaction(runtime, context_a(), fn ->
               assert_nested_refused(other, context_a())
               assert %{active_permits: 0, admitted: 0} = DatabaseAdmission.statistics(admission)
               previous = Repo.put_dynamic_repo(dedicated)

               try do
                 assert_nested_refused(runtime, context_a())
               after
                 Repo.put_dynamic_repo(previous)
               end

               :checked
             end)
  end

  test "spawned work cannot borrow the parent's writer permit" do
    runtime = start_runtime(per_tenant_limit: 1)

    assert {:ok, {:ok, :checked}} =
             in_writer_transaction(runtime, context_a(), fn ->
               task =
                 Task.async(fn ->
                   Persistence.with_writer(runtime, context_a(), &never_called/0)
                 end)

               assert {:error, %AdmissionError{code: :rate_limited}} = Task.await(task)
               :checked
             end)
  end

  test "outer rollback undoes both outer and nested writes and releases admission" do
    runtime = start_runtime(per_tenant_limit: 1)
    {:ok, admission} = PersistenceRuntime.child_pid(runtime, DatabaseAdmission)

    assert {:ok, :checked} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.checkout(fn -> rollback_nested_writes(runtime) end)
             end)

    assert %{active_permits: 0, admitted: 1} = DatabaseAdmission.statistics(admission)
    assert {:ok, {:ok, :fresh}} = in_writer_transaction(runtime, context_a(), fn -> :fresh end)
    assert %{active_permits: 0, admitted: 2} = DatabaseAdmission.statistics(admission)
  end

  test "exception and exit restore scope and release the outer permit" do
    runtime = start_runtime(per_tenant_limit: 1)
    {:ok, admission} = PersistenceRuntime.child_pid(runtime, DatabaseAdmission)
    previous = Repo.get_dynamic_repo()

    assert_raise RuntimeError, "synthetic nested failure", fn ->
      in_writer_transaction(runtime, context_a(), fn ->
        Persistence.with_writer(runtime, context_a(), fn -> raise "synthetic nested failure" end)
      end)
    end

    assert Repo.get_dynamic_repo() == previous
    assert %{active_permits: 0, admitted: 1} = DatabaseAdmission.statistics(admission)

    assert catch_exit(
             in_writer_transaction(runtime, context_a(), fn -> exit(:synthetic_exit) end)
           ) == :synthetic_exit

    assert Repo.get_dynamic_repo() == previous
    assert %{active_permits: 0, admitted: 2} = DatabaseAdmission.statistics(admission)
    assert {:ok, {:ok, :fresh}} = in_writer_transaction(runtime, context_a(), fn -> :fresh end)
  end

  test "requires explicit repositories, placements, and positive admission limits" do
    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime, Keyword.delete(runtime_options(), :repositories)}
             )

    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime, Keyword.delete(runtime_options(), :placements)}
             )

    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime, Keyword.delete(runtime_options(), :per_tenant_limit)}
             )

    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime, Keyword.put(runtime_options(), :repository, :caller_selected)}
             )
  end

  test "rejects duplicate, malformed, and unknown startup route ownership" do
    [first_placement | _rest] = runtime_options()[:placements]

    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime,
                Keyword.put(runtime_options(), :placements, [first_placement, first_placement])}
             )

    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime,
                Keyword.put(
                  runtime_options(),
                  :placements,
                  [Keyword.put(first_placement, :repository, :unknown)]
                )}
             )

    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime,
                Keyword.put(
                  runtime_options(),
                  :placements,
                  [first_placement ++ [tenant_id: @tenant_b]]
                )}
             )

    assert {:error, _reason} =
             start_supervised(
               {PersistenceRuntime, Keyword.put(runtime_options(), :repositories, [:malformed])}
             )
  end

  defp rollback_nested_writes(runtime) do
    Repo.query!("CREATE TEMP TABLE nested_admission_marker (value integer)")

    assert {:error, :synthetic_rollback} =
             Repo.transaction(fn ->
               Repo.query!("INSERT INTO nested_admission_marker VALUES (1)")

               assert {:ok, :written} =
                        Persistence.with_writer(runtime, context_a(), fn ->
                          Repo.query!("INSERT INTO nested_admission_marker VALUES (2)")
                          :written
                        end)

               Repo.rollback(:synthetic_rollback)
             end)

    assert [[0]] = Repo.query!("SELECT count(*) FROM nested_admission_marker").rows
    :checked
  end

  defp in_writer_transaction(runtime, context, operation),
    do: Persistence.with_writer(runtime, context, fn -> Repo.transaction(operation) end)

  defp assert_nested_refused(runtime, context) do
    assert {:error, %PersistenceError{code: :retryable_dependency}} =
             Persistence.with_writer(runtime, context, &never_called/0)
  end

  defp never_called, do: flunk("a mismatched writer must fail before its callback")

  defp start_runtime(overrides \\ []) do
    options = Keyword.merge(runtime_options(), overrides)
    start_supervised!({PersistenceRuntime, options})
  end

  defp runtime_options do
    [
      repositories: [
        pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 2],
        dedicated: [log: false, pool: DBConnection.ConnectionPool, pool_size: 1]
      ],
      placements: [
        placement(@tenant_a, 7, :pooled, "pooled-a", :pooled),
        placement(@tenant_b, 7, :pooled, "pooled-a", :pooled),
        placement(@tenant_c, 3, :dedicated_database, "dedicated-c", :dedicated)
      ],
      per_tenant_limit: 2,
      per_placement_limit: 3
    ]
  end

  defp placement(tenant_id, routing_version, profile, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: routing_version,
      profile: profile,
      placement_ref: placement_ref,
      repository: repository
    ]
  end

  defp context_a, do: context(@actor_a, @tenant_a, 7, :pooled, "pooled-a")
  defp context_b, do: context(@actor_b, @tenant_b, 7, :pooled, "pooled-a")

  defp context_c,
    do: context(@actor_c, @tenant_c, 3, :dedicated_database, "dedicated-c")

  defp context_unknown,
    do: context(@actor_unknown, @tenant_unknown, 1, :pooled, "unknown-placement")

  defp context(actor_id, tenant_id, routing_version, profile, placement_ref) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: routing_version,
        profile: profile,
        placement_ref: placement_ref
      )

    {:ok, context} =
      ExecutionContext.establish(actor, placement,
        correlation_id: @correlation_id,
        purpose: "platform.persistence",
        locale: "en-MW"
      )

    context
  end
end
