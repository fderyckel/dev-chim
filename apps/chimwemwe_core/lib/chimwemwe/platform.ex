defmodule Chimwemwe.Platform do
  @moduledoc """
  The mandatory platform domain shared by later business modules.

  Slice 1F adds the closed tenant-authority graph. The first Slice 1G increment
  adds one private, governed role-rename action plus closed audit, outbox, and
  idempotency manifests. The base-resource, resource-audit, trusted invocation,
  admission, persistence, and authority boundaries remain the supported paths
  into this domain.
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
  end
end
