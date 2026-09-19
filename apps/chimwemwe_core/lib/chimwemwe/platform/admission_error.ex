defmodule Chimwemwe.Platform.AdmissionError do
  @moduledoc """
  A non-disclosing capacity rejection from the pre-checkout admission boundary.

  `:rate_limited` means the trusted tenant reached its configured local limit.
  `:retryable_dependency` means the trusted placement reached its configured
  local limit. Retry guidance is present only when the gate was configured with
  a bounded interval.
  """

  @enforce_keys [:code]
  defstruct [:code, :retry_after_ms]

  @type code :: :rate_limited | :retryable_dependency
  @type t :: %__MODULE__{code: code(), retry_after_ms: pos_integer() | nil}
end
