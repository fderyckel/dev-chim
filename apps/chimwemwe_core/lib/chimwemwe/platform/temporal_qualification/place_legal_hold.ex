defmodule Chimwemwe.Platform.TemporalQualification.PlaceLegalHold do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Chimwemwe.Platform.TemporalQualification.RetentionAction
  @impl true
  def run(input, options, context), do: RetentionAction.run(:place_hold, input, options, context)
end
