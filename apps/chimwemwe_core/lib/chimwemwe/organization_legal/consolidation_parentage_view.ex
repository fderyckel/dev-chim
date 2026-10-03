defmodule Chimwemwe.OrganizationLegal.ConsolidationParentageView do
  @moduledoc "Exact current management-reporting parentage for one legal entity."

  @enforce_keys [
    :id,
    :child_legal_entity_id,
    :parent_legal_entity_id,
    :reporting_basis,
    :effective_from,
    :status,
    :lock_version
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          child_legal_entity_id: String.t(),
          parent_legal_entity_id: String.t(),
          reporting_basis: :management_reporting,
          effective_from: Date.t(),
          status: :active,
          lock_version: pos_integer()
        }
end
