defmodule Chimwemwe.Platform.Outbox.ReplayRangeResult do
  @moduledoc "Ordered exact results from one bounded replay range."

  @enforce_keys [:results]
  defstruct @enforce_keys

  @type t :: %__MODULE__{results: [Chimwemwe.Platform.Outbox.ReplayResult.t()]}
end
