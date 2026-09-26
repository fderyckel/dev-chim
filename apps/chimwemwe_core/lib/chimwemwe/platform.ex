defmodule Chimwemwe.Platform do
  @moduledoc """
  The mandatory platform domain shared by later business modules.

  Slice 1F adds the closed tenant-authority graph. Slice 1G-A and 1G-B add two
  private governed actions for role rename and assignment plus closed audit,
  outbox, and idempotency manifests. ADR 0018 T1-A adds synthetic temporal
  qualification resources for physical-model pressure testing, T1-B adds two
  private revision actions and a qualification-owned named-read boundary, and
  T1-C adds private append-only fact and deliberate-reconciliation actions.
  Slice 1H adds closed module entitlement, activation, and modeled work state
  plus private governed activation, drain, mandatory-work, and reactivation
  actions. Slice 1I-A adds one closed tenant-owned governed presentation
  definition and its private publication action. Slice 1J-A adds closed
  tenant-owned outbox delivery state behind a code-owned consumer registry and
  internal lease boundary. Slice 1J-B adds a closed durable consumer receipt,
  database-local consumer execution, explicit supervision, and exact governed
  replay. The base-resource, resource-audit, trusted
  invocation, admission, persistence, and resource-specific governed boundaries
  remain the supported paths into this domain.
  """

  use Ash.Domain, otp_app: :chimwemwe_core

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.Platform.Authority.Membership
    resource Chimwemwe.Platform.Authority.Role
    resource Chimwemwe.Platform.Authority.Capability
    resource Chimwemwe.Platform.Authority.ActorRoleAssignment
    resource Chimwemwe.Platform.Authority.RoleCapabilityGrant
    resource Chimwemwe.Platform.Authority.RoleInclusion
    resource Chimwemwe.Platform.Authority.AuditEvent
    resource Chimwemwe.Platform.OutboxEvent
    resource Chimwemwe.Platform.Outbox.Delivery
    resource Chimwemwe.Platform.Outbox.ConsumerReceipt
    resource Chimwemwe.Platform.Authority.ActionIdempotency
    resource Chimwemwe.Platform.TemporalQualification.Aggregate
    resource Chimwemwe.Platform.TemporalQualification.Revision
    resource Chimwemwe.Platform.TemporalQualification.Segment
    resource Chimwemwe.Platform.TemporalQualification.FactOperation
    resource Chimwemwe.Platform.TemporalQualification.Fact
    resource Chimwemwe.Platform.TemporalQualification.ConsumerBasis
    resource Chimwemwe.Platform.ModuleLifecycle.ModuleEntitlement
    resource Chimwemwe.Platform.ModuleLifecycle.ModuleActivation
    resource Chimwemwe.Platform.ModuleLifecycle.ModuleWorkItem
    resource Chimwemwe.Platform.GovernedExtension.ExtensionDefinition
  end
end
