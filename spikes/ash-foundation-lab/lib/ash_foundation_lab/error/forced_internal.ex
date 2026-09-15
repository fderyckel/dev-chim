defmodule AshFoundationLab.Error.ForcedInternal do
  @moduledoc "Synthetic Phase 0 internal failure used to pressure-test non-disclosure."

  use Splode.Error, fields: [:reason], class: :unknown

  @impl true
  def message(error), do: "synthetic internal failure: #{error.reason}"
end
