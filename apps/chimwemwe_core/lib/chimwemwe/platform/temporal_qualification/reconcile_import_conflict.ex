defmodule Chimwemwe.Platform.TemporalQualification.ReconcileImportConflict do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Chimwemwe.Platform.TemporalQualification.ImportAction
  @impl true
  def run(input, options, context), do: ImportAction.run(:reconcile, input, options, context)
end
