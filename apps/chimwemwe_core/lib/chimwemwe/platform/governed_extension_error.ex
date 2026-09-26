defmodule Chimwemwe.Platform.GovernedExtensionError do
  @moduledoc "Stable, non-disclosing error returned by the governed-extension boundary."

  use Splode.Error, fields: [:code], class: :invalid

  @type code ::
          :conflict
          | :forbidden
          | :idempotency_conflict
          | :internal
          | :invalid_definition
          | :invalid_input
          | :invalid_manifest
          | :invalid_registry
          | :module_gate_failed
          | :not_found
          | :reference_not_allowed
          | :retryable_dependency
          | :schema_not_available
          | :stale_descriptor
  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "governed extension failed: #{code}"
end
