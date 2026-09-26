defmodule Chimwemwe.Platform.TemporalQualification.RecordFactEntry do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.TemporalQualification.FactAction

  @impl true
  def run(input, options, context), do: FactAction.run(:record, input, options, context)
end
