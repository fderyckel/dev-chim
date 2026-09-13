defmodule AshFoundationLab.Policy.TenantMatchesActor do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor tenant matches the trusted action tenant"

  @impl true
  def match?(%{tenant_id: actor_tenant_id}, %{subject: %{tenant: tenant}}, _opts)
      when is_binary(actor_tenant_id) and is_binary(tenant) do
    actor_tenant_id == tenant
  end

  def match?(_actor, _context, _opts), do: false
end
