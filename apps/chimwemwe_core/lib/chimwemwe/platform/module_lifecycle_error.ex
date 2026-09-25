defmodule Chimwemwe.Platform.ModuleLifecycleError do
  @moduledoc """
  Stable, non-disclosing failure returned by the module-lifecycle boundary.
  """

  use Splode.Error, fields: [:code], class: :invalid

  @type code ::
          :conflict
          | :forbidden
          | :idempotency_conflict
          | :internal
          | :invalid_input
          | :invalid_manifest
          | :module_inactive
          | :module_not_entitled
          | :module_not_released
          | :required_dependency_inactive
          | :retryable_dependency
  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "module lifecycle failed: #{code}"
end
