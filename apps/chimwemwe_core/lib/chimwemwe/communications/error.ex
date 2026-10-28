defmodule Chimwemwe.Communications.Error do
  @moduledoc "Non-disclosing local communications failure."
  @type t :: %__MODULE__{code: atom()}
  defexception [:code]
  def message(%{code: code}), do: "Communication action failed: #{code}"
end
