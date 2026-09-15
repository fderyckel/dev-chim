defmodule Chimwemwe.Platform.ContextError do
  @moduledoc """
  A non-disclosing failure returned while establishing trusted execution context.
  """

  @type code ::
          :invalid_actor_context
          | :invalid_execution_metadata
          | :invalid_placement_context
          | :missing_trusted_context
          | :tenant_mismatch

  @type t :: %__MODULE__{code: code(), field: atom() | nil}

  defexception [:code, :field]

  @impl true
  def message(%__MODULE__{code: code, field: field}) do
    suffix = if field, do: " for #{field}", else: ""
    "trusted execution context failed: #{code}#{suffix}"
  end
end
