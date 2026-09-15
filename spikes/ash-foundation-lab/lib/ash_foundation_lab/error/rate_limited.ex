defmodule AshFoundationLab.Error.RateLimited do
  @moduledoc "Synthetic Phase 0 capacity rejection used to pressure-test the public error contract."

  use Splode.Error, fields: [:reason], class: :invalid

  @impl true
  def message(error), do: "synthetic rate limit: #{error.reason}"
end
