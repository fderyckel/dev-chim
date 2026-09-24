defmodule Chimwemwe.Platform.PersistenceTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    AdmissionError,
    ContextError,
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
