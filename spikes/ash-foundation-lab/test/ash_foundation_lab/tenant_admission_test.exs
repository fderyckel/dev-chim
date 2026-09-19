defmodule AshFoundationLab.TenantAdmissionTest do
  use ExUnit.Case, async: true

  alias AshFoundationLab.TenantAdmission

  test "rejects a saturated tenant before invoking database work" do
    admission = start_supervised!({TenantAdmission, per_tenant_limit: 1, placement_limit: 2})
    {:ok, held_permit} = TenantAdmission.checkout(admission, "tenant-1")
    parent = self()

    assert {:error, %{kind: :rate_limited, http_status: 429, retry_after_ms: 20}} =
             TenantAdmission.with_permit(admission, "tenant-1", fn ->
               send(parent, :database_checkout_attempted)
             end)

    refute_received :database_checkout_attempted
    assert :ok = TenantAdmission.checkin(admission, held_permit)
  end

  test "admits another tenant while one tenant is saturated" do
    admission = start_supervised!({TenantAdmission, per_tenant_limit: 1, placement_limit: 2})
    {:ok, held_permit} = TenantAdmission.checkout(admission, "tenant-1")

    assert {:ok, :queried_after_admission} =
             TenantAdmission.with_permit(admission, "tenant-2", fn ->
               :queried_after_admission
             end)

    assert :ok = TenantAdmission.checkin(admission, held_permit)
  end

  test "classifies placement saturation as a retryable dependency failure" do
    admission = start_supervised!({TenantAdmission, per_tenant_limit: 2, placement_limit: 1})
    {:ok, held_permit} = TenantAdmission.checkout(admission, "tenant-1")

    assert {:error, %{kind: :retryable_dependency, http_status: 503}} =
             TenantAdmission.checkout(admission, "tenant-2")

    assert :ok = TenantAdmission.checkin(admission, held_permit)
  end

  test "fails closed when tenant context is absent or malformed" do
    admission = start_supervised!({TenantAdmission, per_tenant_limit: 1, placement_limit: 1})

    for tenant_id <- [nil, "", "  ", 0, -1, :untrusted] do
      assert {:error, %{kind: :invalid_tenant_context, http_status: 403, retry_after_ms: 0}} =
               TenantAdmission.checkout(admission, tenant_id)
    end

    assert %{rejected_invalid_context: 6, active_total: 0} =
             TenantAdmission.snapshot(admission)
  end

  test "always releases permits when admitted work raises" do
    admission = start_supervised!({TenantAdmission, per_tenant_limit: 1, placement_limit: 1})

    assert_raise RuntimeError, "synthetic failure", fn ->
      TenantAdmission.with_permit(admission, 1, fn -> raise "synthetic failure" end)
    end

    assert %{active_total: 0, active_by_tenant: %{}} = TenantAdmission.snapshot(admission)
    assert {:ok, _permit} = TenantAdmission.checkout(admission, 1)
  end

  test "reclaims a leaked permit when its caller terminates" do
    admission = start_supervised!({TenantAdmission, per_tenant_limit: 1, placement_limit: 1})
    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        {:ok, _permit} = TenantAdmission.checkout(admission, "tenant-1")
        send(parent, :permit_acquired)
        exit(:synthetic_crash)
      end)

    assert_receive :permit_acquired
    assert_receive {:DOWN, ^monitor, :process, ^caller, :synthetic_crash}

    assert_eventually(fn -> TenantAdmission.snapshot(admission).active_total == 0 end)
    assert {:ok, _permit} = TenantAdmission.checkout(admission, "tenant-1")
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
