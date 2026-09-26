defmodule Chimwemwe.Platform.TemporalQualification.FactOperationResult do
  @moduledoc """
  Complete committed append-only fact result, including safe evidence identifiers.
  """

  alias Chimwemwe.Platform.TemporalQualification.FactOperationView

  @enforce_keys [:operation, :audit_reference, :event_id]
  defstruct [:operation, :audit_reference, :event_id]

  @type t :: %__MODULE__{
          operation: FactOperationView.t(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
