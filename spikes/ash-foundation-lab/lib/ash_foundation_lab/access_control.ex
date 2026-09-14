defmodule AshFoundationLab.AccessControl do
  @moduledoc """
  Resolves tenant-scoped capabilities from actor role assignments and role composition.

  This is intentionally spike-local evidence. It is not a production authorization API.
  """

  alias AshFoundationLab.Repo
  alias Ecto.UUID

  @spec actor_has_capability?(map(), String.t()) :: boolean()
  def actor_has_capability?(%{id: actor_id, tenant_id: tenant_id}, capability)
      when is_binary(actor_id) and is_binary(tenant_id) and is_binary(capability) do
    actor_id = UUID.dump!(actor_id)
    tenant_id = UUID.dump!(tenant_id)

    %{rows: [[granted?]]} =
      Repo.query!(
        """
        WITH RECURSIVE granted_roles(role_id) AS (
          SELECT actor_roles.role_id
          FROM actor_roles
          WHERE actor_roles.tenant_id = $1
            AND actor_roles.actor_id = $2

          UNION

          SELECT role_inclusions.included_role_id
          FROM role_inclusions
          JOIN granted_roles
            ON granted_roles.role_id = role_inclusions.role_id
          WHERE role_inclusions.tenant_id = $1
        )
        SELECT EXISTS (
          SELECT 1
          FROM granted_roles
          JOIN role_capabilities
            ON role_capabilities.tenant_id = $1
           AND role_capabilities.role_id = granted_roles.role_id
          JOIN capabilities
            ON capabilities.tenant_id = role_capabilities.tenant_id
           AND capabilities.id = role_capabilities.capability_id
          WHERE capabilities.key = $3
        )
        """,
        [tenant_id, actor_id, capability]
      )

    granted?
  end

  def actor_has_capability?(_actor, _capability), do: false
end
