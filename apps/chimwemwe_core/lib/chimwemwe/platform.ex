defmodule Chimwemwe.Platform do
  @moduledoc """
  The mandatory platform domain shared by later business modules.

  Slice 1F adds the closed tenant-authority graph. Slice 1G-A and 1G-B add two
  private governed actions for role rename and assignment plus closed audit,
  outbox, and idempotency manifests. ADR 0018 T1-A adds synthetic temporal
  qualification resources for physical-model pressure testing, while T1-B adds
  two private revision actions and a qualification-owned named-read boundary.
  Slice 1H-A adds closed module-entitlement state and one private governed
  initial-activation action. The base-resource, resource-audit, trusted
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
    resource Chimwemwe.Platform.Authority.ActionIdempotency
    resource Chimwemwe.Platform.TemporalQualification.Aggregate
    resource Chimwemwe.Platform.TemporalQualification.Revision
    resource Chimwemwe.Platform.TemporalQualification.Segment
    resource Chimwemwe.Platform.TemporalQualification.Fact
    resource Chimwemwe.Platform.ModuleLifecycle.ModuleEntitlement
    resource Chimwemwe.Platform.ModuleLifecycle.ModuleActivation
  end
end
