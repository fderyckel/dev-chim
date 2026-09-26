defmodule Chimwemwe.Platform.TemporalQualification.FactOperationView do
  @moduledoc """
  Exact immutable result of one neutral fact-domain operation.
  """

  alias Chimwemwe.Platform.TemporalQualification.FactView

  @enforce_keys [:operation_id, :scope_id, :kind, :reason_code, :recorded_at, :facts]
  defstruct [
    :operation_id,
    :scope_id,
    :kind,
    :target_fact_id,
    :reason_code,
    :recorded_at,
    :facts
  ]

  @type t :: %__MODULE__{
          operation_id: String.t(),
          scope_id: String.t(),
          kind: :record | :reverse_and_replace,
          target_fact_id: String.t() | nil,
          reason_code: String.t(),
          recorded_at: NaiveDateTime.t(),
          facts: [FactView.t()]
        }
end
