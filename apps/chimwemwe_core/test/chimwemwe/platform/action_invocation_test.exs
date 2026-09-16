defmodule Chimwemwe.Platform.ActionInvocationTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    ActionInvocation,
    ContextError,
    ExecutionContext,
    InvocationError,
    TrustedActor,
    TrustedPlacement
  }

  alias __MODULE__.{Domain, GlobalReference, TenantRecord}

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @denied_actor "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @correlation_a "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
  @correlation_b "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"

  setup_all do
    actor_a = trusted_actor(@actor_a, @tenant_a, "mfa")
    actor_b = trusted_actor(@actor_b, @tenant_b, "mfa")
    denied_actor = trusted_actor(@denied_actor, @tenant_a, "password")

    context_a = execution_context(actor_a, @tenant_a, @correlation_a)
    context_b = execution_context(actor_b, @tenant_b, @correlation_b)
    denied_context = execution_context(denied_actor, @tenant_a, @correlation_a)

    Ash.create!(TenantRecord, %{name: "Tenant A record"},
      action: :seed_record,
      actor: actor_a,
      tenant: @tenant_a,
      domain: Domain
    )

    Ash.create!(TenantRecord, %{name: "Tenant B record"},
      action: :seed_record,
      actor: actor_b,
      tenant: @tenant_b,
      domain: Domain
    )

    Ash.create!(GlobalReference, %{code: "GLOBAL"},
      action: :seed_reference,
      actor: actor_a,
      domain: Domain
    )

    {:ok, context_a: context_a, context_b: context_b, denied_context: denied_context}
  end

  test "invokes a public named read with real actor and tenant policy", fixture do
    assert {:ok, records} =
             ActionInvocation.read(fixture.context_a, TenantRecord, :list_records)

    assert Enum.map(records, & &1.name) == ["Tenant A record"]
  end

  test "the same read remains isolated for another trusted tenant", fixture do
    assert {:ok, records} =
             ActionInvocation.read(fixture.context_b, TenantRecord, :list_records)

    assert Enum.map(records, & &1.name) == ["Tenant B record"]
  end

  test "a policy-denied actor remains forbidden", fixture do
    assert {:error, %Ash.Error.Forbidden{}} =
             ActionInvocation.read(fixture.denied_context, TenantRecord, :list_records)
  end

  test "global reference reads retain actor policy without tenant multitenancy", fixture do
    assert {:ok, records} =
             ActionInvocation.read(
               fixture.context_a,
               GlobalReference,
               :list_reference_values
             )

    assert Enum.map(records, & &1.code) == ["GLOBAL"]
  end

  test "invalid context fails before resource and action discovery", fixture do
    assert {:error, %ContextError{code: :missing_trusted_context}} =
             ActionInvocation.read(%{tenant_id: @tenant_a}, String, :missing)

    context_a = fixture.context_a
    invalid_routing = put_in(context_a.placement.routing_version, 0)

    assert {:error, %ContextError{code: :invalid_placement_context}} =
             ActionInvocation.read(invalid_routing, String, :missing)

    mismatched_tenant = put_in(context_a.placement.tenant_id, @tenant_b)

    assert {:error, %ContextError{code: :tenant_mismatch}} =
             ActionInvocation.read(mismatched_tenant, String, :missing)
  end

  test "unregistered resources fail without exposing model details", fixture do
    unregistered = Chimwemwe.Platform.ResourceContractTest.ValidTenantResource

    for resource <- [String, unregistered] do
      assert {:error, %InvocationError{code: :resource_not_available}} =
               ActionInvocation.read(fixture.context_a, resource, :list_records)
    end
  end

  test "private, missing, non-read, and non-atom actions share one denial", fixture do
    for action <- [:private_records, :missing, :seed_record, "list_records"] do
      assert {:error, %InvocationError{code: :read_action_not_available}} =
               ActionInvocation.read(fixture.context_a, TenantRecord, action)
    end
  end

  test "reserved context and authority input fails before Ash executes", fixture do
    reserved_inputs = [
      %{tenant_id: @tenant_b},
      %{"actor" => @actor_b},
      %{authorize?: false},
      %{"repository" => "request-selected"},
      %{routing_version: 999},
      %{correlation_id: @correlation_b},
      %{purpose: "replace-trusted-purpose"}
    ]

    for input <- reserved_inputs do
      assert {:error, %InvocationError{code: :invalid_input}} =
               ActionInvocation.read(fixture.context_a, TenantRecord, :list_records, input)
    end

    assert {:error, %InvocationError{code: :invalid_input}} =
             ActionInvocation.read(fixture.context_a, TenantRecord, :list_records, [])

    assert {:error, %InvocationError{code: :invalid_input}} =
             ActionInvocation.read(fixture.context_a, TenantRecord, :list_records, %URI{})

    assert {:error, %InvocationError{code: :invalid_input}} =
             ActionInvocation.read(
               fixture.context_a,
               TenantRecord,
               :list_records,
               %{{:invalid, :key} => "value"}
             )
  end

  test "the bounded invocation module exports no write path" do
    refute function_exported?(ActionInvocation, :create, 4)
    refute function_exported?(ActionInvocation, :update, 5)
    refute function_exported?(ActionInvocation, :destroy, 4)
  end

  defp trusted_actor(actor_id, tenant_id, assurance) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: assurance)

    actor
  end

  defp execution_context(actor, tenant_id, correlation_id) do
    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "trusted-placement"
      )

    {:ok, context} =
      ExecutionContext.establish(actor, placement,
        correlation_id: correlation_id,
        purpose: "platform.named_read",
        locale: "en-MW"
      )

    context
  end
end
