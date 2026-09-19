defmodule Chimwemwe.Platform.DatabaseAdmissionTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.Platform.{
    AdmissionError,
    ContextError,
    DatabaseAdmission,
    ExecutionContext,
    TrustedActor,
    TrustedPlacement
  }

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @tenant_c "33333333-3333-4333-8333-333333333333"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @actor_c "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @correlation_id "cccccccc-cccc-4ccc-8ccc-cccccccccccc"

  test "runs admitted work only after trusted context acquires capacity" do
    admission = start_admission(per_tenant_limit: 1, per_placement_limit: 2)

    assert {:ok, :database_callback} =
             DatabaseAdmission.with_permit(admission, context_a(), fn -> :database_callback end)

    assert %{
             active_permits: 0,
             admitted: 1,
             placement_rejections: 0,
             tenant_rejections: 0
           } = DatabaseAdmission.statistics(admission)
  end

  test "rejects a saturated tenant before callback and admits another tenant" do
    admission = start_admission(per_tenant_limit: 1, per_placement_limit: 2)
    holder = hold_permit(admission, context_a())

    assert {:error, %AdmissionError{code: :rate_limited, retry_after_ms: nil}} =
             DatabaseAdmission.with_permit(admission, context_a(), fn ->
               flunk("rejected work must not reach a database callback")
             end)

    assert {:ok, :other_tenant_admitted} =
             DatabaseAdmission.with_permit(admission, context_b(), fn ->
               :other_tenant_admitted
             end)

    release_holder(holder)

    assert %{active_permits: 0, admitted: 2, tenant_rejections: 1} =
             DatabaseAdmission.statistics(admission)
  end

  test "classifies placement saturation separately and isolates another placement" do
    admission = start_admission(per_tenant_limit: 2, per_placement_limit: 1)
    holder = hold_permit(admission, context_a())

    assert {:error, %AdmissionError{code: :retryable_dependency, retry_after_ms: nil}} =
             DatabaseAdmission.with_permit(admission, context_b(), fn ->
               flunk("saturated placement work must not run")
             end)

    assert {:ok, :other_placement_admitted} =
             DatabaseAdmission.with_permit(admission, context_c(), fn ->
               :other_placement_admitted
             end)

    release_holder(holder)

    assert %{active_permits: 0, admitted: 2, placement_rejections: 1} =
             DatabaseAdmission.statistics(admission)
  end

  test "fails closed on raw, invalid-routing, and tenant-mismatched context" do
    admission = start_admission(per_tenant_limit: 1, per_placement_limit: 1)
    callback = fn -> flunk("invalid context must fail before callback") end

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             DatabaseAdmission.with_permit(admission, %{tenant_id: @tenant_a}, callback)

    context = context_a()
    invalid_routing = put_in(context.placement.routing_version, 0)

    assert {:error, %ContextError{code: :invalid_placement_context}} =
             DatabaseAdmission.with_permit(admission, invalid_routing, callback)

    mismatched_tenant = put_in(context.placement.tenant_id, @tenant_b)

    assert {:error, %ContextError{code: :tenant_mismatch}} =
             DatabaseAdmission.with_permit(admission, mismatched_tenant, callback)

    assert %{active_permits: 0, admitted: 0} = DatabaseAdmission.statistics(admission)
  end

  test "releases capacity after exception, throw, and exit" do
    admission = start_admission(per_tenant_limit: 1, per_placement_limit: 1)

    assert_raise RuntimeError, "synthetic exception", fn ->
      DatabaseAdmission.with_permit(admission, context_a(), fn ->
        raise "synthetic exception"
      end)
    end

    assert catch_throw(
             DatabaseAdmission.with_permit(admission, context_a(), fn ->
               throw(:synthetic_throw)
             end)
           ) == :synthetic_throw

    assert catch_exit(
             DatabaseAdmission.with_permit(admission, context_a(), fn ->
               exit(:synthetic_exit)
             end)
           ) == :synthetic_exit

    assert {:ok, :capacity_reused} =
             DatabaseAdmission.with_permit(admission, context_a(), fn -> :capacity_reused end)

    assert %{active_permits: 0, admitted: 4} = DatabaseAdmission.statistics(admission)
  end

  test "reclaims capacity when an admitted caller terminates" do
    admission = start_admission(per_tenant_limit: 1, per_placement_limit: 1)
    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        DatabaseAdmission.with_permit(admission, context_a(), fn ->
          send(parent, :permit_acquired)
          Process.sleep(:infinity)
        end)
      end)

    assert_receive :permit_acquired
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :killed}

    assert_eventually(fn ->
      DatabaseAdmission.with_permit(admission, context_a(), fn -> :reclaimed end) ==
        {:ok, :reclaimed}
    end)

    assert %{active_permits: 0, admitted: 2} = DatabaseAdmission.statistics(admission)
  end

  test "emits retry guidance only when configured explicitly" do
    admission =
      start_admission(
        per_tenant_limit: 1,
        per_placement_limit: 1,
        retry_after_ms: 25
      )

    holder = hold_permit(admission, context_a())

    assert {:error, %AdmissionError{code: :rate_limited, retry_after_ms: 25}} =
             DatabaseAdmission.with_permit(admission, context_a(), fn -> :unreachable end)

    assert {:error, %AdmissionError{code: :retryable_dependency, retry_after_ms: 25}} =
             DatabaseAdmission.with_permit(admission, context_b(), fn -> :unreachable end)

    release_holder(holder)
  end

  test "fails closed before callback when the admission process is unavailable" do
    {:ok, admission} =
      DatabaseAdmission.start_link(per_tenant_limit: 1, per_placement_limit: 1)

    Process.unlink(admission)
    :ok = GenServer.stop(admission)

    assert {:error, %AdmissionError{code: :retryable_dependency, retry_after_ms: nil}} =
             DatabaseAdmission.with_permit(admission, context_a(), fn ->
               flunk("an unavailable admission gate must not run database work")
             end)
  end

  test "requires explicit positive limits and is not installed in the application tree" do
    assert {:error, {{:invalid_admission_option, :per_tenant_limit}, _child}} =
             start_supervised({DatabaseAdmission, per_placement_limit: 1})

    assert {:error, {{:invalid_admission_option, :per_placement_limit}, _child}} =
             start_supervised({DatabaseAdmission, per_tenant_limit: 1, per_placement_limit: 0})

    assert {:error, {{:invalid_admission_option, :retry_after_ms}, _child}} =
             start_supervised(
               {DatabaseAdmission, per_tenant_limit: 1, per_placement_limit: 1, retry_after_ms: 0}
             )

    assert {:error, {{:invalid_admission_option, :unknown}, _child}} =
             start_supervised(
               {DatabaseAdmission,
                per_tenant_limit: 1, per_placement_limit: 1, database: :caller_selected}
             )

    assert Supervisor.which_children(Chimwemwe.Supervisor) == []
  end

  defp start_admission(options) do
    start_supervised!({DatabaseAdmission, options})
  end

  defp hold_permit(admission, context) do
    parent = self()

    task =
      Task.async(fn ->
        DatabaseAdmission.with_permit(admission, context, fn ->
          send(parent, {:permit_acquired, self()})

          receive do
            :release_permit -> :released
          end
        end)
      end)

    assert_receive {:permit_acquired, owner}
    {task, owner}
  end

  defp release_holder({task, owner}) do
    send(owner, :release_permit)
    assert {:ok, :released} = Task.await(task)
  end

  defp context_a, do: execution_context(@actor_a, @tenant_a, "pooled-a")
  defp context_b, do: execution_context(@actor_b, @tenant_b, "pooled-a")
  defp context_c, do: execution_context(@actor_c, @tenant_c, "pooled-b")

  defp execution_context(actor_id, tenant_id, placement_ref) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: placement_ref
      )

    {:ok, context} =
      ExecutionContext.establish(actor, placement,
        correlation_id: @correlation_id,
        purpose: "platform.database_admission",
        locale: "en-MW"
      )

    context
  end

  defp assert_eventually(predicate, attempts \\ 20)

  defp assert_eventually(predicate, attempts) when attempts > 0 do
    if predicate.() do
      :ok
    else
      Process.sleep(5)
      assert_eventually(predicate, attempts - 1)
    end
  end

  defp assert_eventually(_predicate, 0), do: flunk("condition did not become true")
end
