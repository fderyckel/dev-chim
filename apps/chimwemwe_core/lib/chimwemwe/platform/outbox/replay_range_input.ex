defmodule Chimwemwe.Platform.Outbox.ReplayRangeInput do
  @moduledoc "Bounded ordered composition of exact replay inputs from one cursor page."

  @enforce_keys [:items]
  defstruct @enforce_keys

  @type t :: %__MODULE__{items: [Chimwemwe.Platform.Outbox.ReplayInput.t()]}
end
