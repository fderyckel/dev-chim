defmodule Chimwemwe.Platform.Authority.AssignmentOption do
  @moduledoc """
  Minimal browser-safe reference used by the UI-1A assignment-options read.
  """

  @enforce_keys [:id, :label]
  defstruct [:id, :label]

  @type t :: %__MODULE__{id: String.t(), label: String.t()}
end
