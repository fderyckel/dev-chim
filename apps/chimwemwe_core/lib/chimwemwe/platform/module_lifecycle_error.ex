defmodule Chimwemwe.Platform.ModuleLifecycleError do
  @moduledoc """
  Stable, non-disclosing failure returned by the module-lifecycle boundary.
  """

  use Splode.Error, fields: [:code], class: :invalid

  @type code ::
          :active_dependents_present
          | :conflict
          | :forbidden
          | :idempotency_conflict
          | :internal
          | :invalid_input
          | :invalid_manifest
          | :lifecycle_conflict
          | :mandatory_work_not_available
          | :module_inactive
          | :module_not_inactive
          | :module_not_entitled
          | :module_not_released
          | :module_version_incompatible
          | :required_dependency_inactive
          | :retryable_dependency
  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "module lifecycle failed: #{code}"
end
