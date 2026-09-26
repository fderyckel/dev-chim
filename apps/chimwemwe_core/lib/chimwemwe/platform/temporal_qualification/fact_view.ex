defmodule Chimwemwe.Platform.TemporalQualification.FactView do
  @moduledoc """
  One immutable fact returned by the neutral append-only qualification boundary.
  """

  @enforce_keys [
    :id,
    :operation_id,
    :kind,
    :effective_on,
    :quantity,
    :recorded_at
  ]
  defstruct [
    :id,
    :operation_id,
    :kind,
    :reverses_fact_id,
    :effective_on,
    :quantity,
    :recorded_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          operation_id: String.t(),
          kind: :entry | :reversal,
          reverses_fact_id: String.t() | nil,
          effective_on: Date.t(),
          quantity: integer(),
          recorded_at: NaiveDateTime.t()
        }
end
