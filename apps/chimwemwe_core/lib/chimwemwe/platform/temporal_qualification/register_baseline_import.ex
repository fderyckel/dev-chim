defmodule Chimwemwe.Platform.TemporalQualification.RegisterBaselineImport do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Chimwemwe.Platform.TemporalQualification.ImportAction
  @impl true
  def run(input, options, context), do: ImportAction.run(:baseline, input, options, context)
end
