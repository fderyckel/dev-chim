defmodule Chimwemwe.People.StaffAudience.Proof do
  @moduledoc false
  @enforce_keys [
    :tenant_id,
    :institution_id,
    :actor_id,
    :draft_digest,
    :basis_digest,
    :subjects,
    :resolved_at,
    :expires_at,
    :local_date
  ]
  defstruct @enforce_keys

  defimpl Inspect do
    def inspect(_proof, _options), do: "#StaffAudience.Proof<[REDACTED]>"
  end
end
