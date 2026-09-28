defmodule Chimwemwe.OrganizationLegal.LegalEntityView do
  @moduledoc """
  Exact current view of one permitted tenant-owned legal entity.

  This is not a collection item, hierarchy node, authority scope, placement
  selector, or proof of legal ownership or educational operation.
  """

  @enforce_keys [
    :id,
    :official_name,
    :display_name,
    :status,
    :lock_version,
    :recorded_at
  ]
  defstruct [
    :id,
    :official_name,
    :display_name,
    :status,
    :lock_version,
    :recorded_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          official_name: String.t(),
          display_name: String.t(),
          status: :active,
          lock_version: pos_integer(),
          recorded_at: DateTime.t()
        }
end
