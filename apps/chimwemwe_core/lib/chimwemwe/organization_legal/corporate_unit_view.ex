defmodule Chimwemwe.OrganizationLegal.CorporateUnitView do
  @moduledoc "Exact current view of one corporate unit and its name profile."

  @enforce_keys [
    :id,
    :legal_entity_id,
    :parent_corporate_unit_id,
    :official_name,
    :display_name,
    :status,
    :lock_version,
    :recorded_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          legal_entity_id: String.t(),
          parent_corporate_unit_id: String.t() | nil,
          official_name: String.t(),
          display_name: String.t(),
          status: :active,
          lock_version: pos_integer(),
          recorded_at: DateTime.t()
        }
end
