defmodule Chimwemwe.Platform.TemporalQualification.RegisterImportConflict do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Chimwemwe.Platform.TemporalQualification.ImportAction
  @impl true
  def run(input, options, context), do: ImportAction.run(:conflict, input, options, context)
end
