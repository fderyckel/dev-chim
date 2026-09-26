defmodule Chimwemwe.Platform.ExecutionContextTest do
  use ExUnit.Case, async: true

  alias Ash.Domain.Info

  alias Chimwemwe.Platform.Authority.{
    ActionIdempotency,
    ActorRoleAssignment,
    AuditEvent,
    Capability,
    Membership,
    Role,
    RoleCapabilityGrant,
    RoleInclusion
  }

  alias Chimwemwe.Platform.{
    ContextError,
    ExecutionContext,
    OutboxEvent,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.TemporalQualification.{
    Aggregate,
    ConsumerBasis,
    Fact,
    FactOperation,
    Revision,
    Segment
  }

  alias Chimwemwe.Platform.ModuleLifecycle.{
    ModuleActivation,
    ModuleEntitlement,
    ModuleWorkItem
  }

  alias Chimwemwe.Platform.GovernedExtension.ExtensionDefinition

  @tenant_id "11111111-1111-4111-8111-111111111111"
  @other_tenant_id "22222222-2222-4222-8222-222222222222"
  @actor_id "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @correlation_id "cccccccc-cccc-4ccc-8ccc-cccccccccccc"

  test "establishes a complete execution context from separate trusted sources" do
    actor = trusted_actor(@tenant_id)
    placement = trusted_placement(@tenant_id)

    assert {:ok, context} =
             ExecutionContext.establish(actor, placement,
               correlation_id: @correlation_id,
               purpose: "platform.foundation",
               locale: "en-MW"
             )

    assert :ok = ExecutionContext.validate(context)
    assert :executed = ExecutionContext.with_validated(context, fn _context -> :executed end)
  end

  test "fails closed when the authenticated and routed tenants differ" do
    actor = trusted_actor(@tenant_id)
    placement = trusted_placement(@other_tenant_id)

    assert {:error, %ContextError{code: :tenant_mismatch, field: :tenant_id}} =
             ExecutionContext.establish(actor, placement,
               correlation_id: @correlation_id,
               purpose: "platform.foundation",
               locale: "en-MW"
             )
  end

  test "does not run core work without established trusted context" do
    assert {:error, %ContextError{code: :missing_trusted_context}} =
             ExecutionContext.with_validated(nil, fn _context ->
               flunk("operation must not run")
             end)

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             ExecutionContext.with_validated(%{tenant_id: @tenant_id}, fn _context ->
               flunk("raw request maps must not be accepted")
             end)
  end

  test "revalidates context before work and rejects an invalid routing version" do
    actor = trusted_actor(@tenant_id)
    placement = trusted_placement(@tenant_id)

    {:ok, context} =
      ExecutionContext.establish(actor, placement,
        correlation_id: @correlation_id,
        purpose: "platform.foundation",
        locale: "en-MW"
      )

    invalid_context = put_in(context.placement.routing_version, 0)

    assert {:error, %ContextError{code: :invalid_placement_context, field: :routing_version}} =
             ExecutionContext.with_validated(invalid_context, fn _context ->
               flunk("invalid placement must fail before operation")
             end)
  end

  test "rejects missing or malformed actor, placement, and execution fields" do
    assert {:error, %ContextError{code: :invalid_actor_context, field: :actor_id}} =
             TrustedActor.establish(
               actor_id: "request-controlled",
               tenant_id: @tenant_id,
               assurance: "mfa"
             )

    assert {:error, %ContextError{code: :invalid_placement_context, field: :profile}} =
             TrustedPlacement.establish(
               tenant_id: @tenant_id,
               routing_version: 1,
               profile: :request_selected,
               placement_ref: "placement-a"
             )

    assert {:error, %ContextError{code: :invalid_execution_metadata, field: :purpose}} =
             ExecutionContext.establish(trusted_actor(@tenant_id), trusted_placement(@tenant_id),
               correlation_id: @correlation_id,
               purpose: "",
               locale: "en-MW"
             )
  end

  test "the production Ash domain always runs authorization" do
    assert Application.fetch_env!(:chimwemwe_core, :ash_domains) == [Chimwemwe.Platform]

    assert Application.fetch_env!(:chimwemwe_core, :base_resources) == [
             Chimwemwe.Platform.Resource
           ]

    assert Info.authorize(Chimwemwe.Platform) == :always
    assert Info.require_actor?(Chimwemwe.Platform)

    assert MapSet.new(Info.resources(Chimwemwe.Platform)) ==
             MapSet.new([
               Membership,
               Role,
               Capability,
               ActorRoleAssignment,
               RoleCapabilityGrant,
               RoleInclusion,
               AuditEvent,
               OutboxEvent,
               ActionIdempotency,
               Aggregate,
               Revision,
               Segment,
               FactOperation,
               Fact,
               ConsumerBasis,
               ModuleEntitlement,
               ModuleActivation,
               ModuleWorkItem,
               ExtensionDefinition
             ])
  end

  defp trusted_actor(tenant_id) do
    assert {:ok, actor} =
             TrustedActor.establish(
               actor_id: @actor_id,
               tenant_id: tenant_id,
               assurance: "mfa"
             )

    actor
  end

  defp trusted_placement(tenant_id) do
    assert {:ok, placement} =
             TrustedPlacement.establish(
               tenant_id: tenant_id,
               routing_version: 7,
               profile: :pooled,
               placement_ref: "placement-a"
             )

    placement
  end
end
