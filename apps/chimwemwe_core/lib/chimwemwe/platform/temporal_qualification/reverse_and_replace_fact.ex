defmodule Chimwemwe.Platform.TemporalQualification.ReverseAndReplaceFact do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.TemporalQualification.FactAction

  @impl true
  def run(input, options, context),
    do: FactAction.run(:reverse_and_replace, input, options, context)
end
