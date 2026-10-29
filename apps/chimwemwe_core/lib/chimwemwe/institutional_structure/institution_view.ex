defmodule Chimwemwe.InstitutionalStructure.InstitutionView do
  @moduledoc "Exact authorized institutional identity; protected operator evidence is excluded."
  @enforce_keys [:id, :display_name, :classification, :time_zone, :status, :lock_version]
  defstruct [
    :id,
    :display_name,
    :classification,
    :time_zone,
    :status,
    :lock_version,
    :legal_entity_id,
    :operator_assignment_id,
    :effective_from,
    :publication_id
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          display_name: String.t(),
          classification: :institution,
          time_zone: String.t(),
          status: :draft | :published,
          lock_version: pos_integer(),
          legal_entity_id: String.t() | nil,
          operator_assignment_id: String.t() | nil,
          effective_from: Date.t() | nil,
          publication_id: String.t() | nil
        }
end
