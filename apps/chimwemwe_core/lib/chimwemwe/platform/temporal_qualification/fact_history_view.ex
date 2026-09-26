defmodule Chimwemwe.Platform.TemporalQualification.FactHistoryView do
  @moduledoc """
  Bounded ordered fact-operation history for one synthetic scope.
  """

  alias Chimwemwe.Platform.TemporalQualification.FactOperationView

  @enforce_keys [:scope_id, :operations, :truncated?]
  defstruct [:scope_id, :operations, :truncated?]

  @type t :: %__MODULE__{
          scope_id: String.t(),
          operations: [FactOperationView.t()],
          truncated?: boolean()
        }
end
