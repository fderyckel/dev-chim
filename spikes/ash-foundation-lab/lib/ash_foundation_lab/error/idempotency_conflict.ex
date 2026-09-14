defmodule AshFoundationLab.Error.IdempotencyConflict do
  @moduledoc "Raised when an idempotency key is reused for a different action request."

  use Splode.Error, fields: [], class: :invalid

  @impl true
  def message(_error), do: "The idempotency key was already used for a different request."
end
