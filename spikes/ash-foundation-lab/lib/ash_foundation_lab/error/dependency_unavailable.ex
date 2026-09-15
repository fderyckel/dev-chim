defmodule AshFoundationLab.Error.DependencyUnavailable do
  @moduledoc "Synthetic Phase 0 dependency failure used to pressure-test retry semantics."

  use Splode.Error, fields: [:reason], class: :framework

  @impl true
  def message(error), do: "synthetic dependency unavailable: #{error.reason}"
end
