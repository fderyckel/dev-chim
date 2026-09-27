defmodule Chimwemwe.Platform.TemporalQualification.ReleaseLegalHold do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Chimwemwe.Platform.TemporalQualification.RetentionAction
  @impl true
  def run(input, options, context),
    do: RetentionAction.run(:release_hold, input, options, context)
end
