defmodule Chimwemwe.OrganizationLegal.LegalEntityRelationshipView do
  @moduledoc "Exact current view of one direct legal-entity relationship."

  @enforce_keys [
    :id,
    :source_legal_entity_id,
    :target_legal_entity_id,
    :relationship_type,
    :basis_key,
    :interest_bps,
    :effective_from,
    :effective_until,
    :status,
    :lock_version
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          source_legal_entity_id: String.t(),
          target_legal_entity_id: String.t(),
          relationship_type: atom(),
          basis_key: atom(),
          interest_bps: pos_integer() | nil,
          effective_from: Date.t(),
          effective_until: Date.t() | nil,
          status: :active | :ended,
          lock_version: pos_integer()
        }
end
