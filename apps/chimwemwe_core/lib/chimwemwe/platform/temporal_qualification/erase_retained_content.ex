defmodule Chimwemwe.Platform.TemporalQualification.EraseRetainedContent do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Chimwemwe.Platform.TemporalQualification.RetentionAction
  @impl true
  def run(input, options, context), do: RetentionAction.run(:erase, input, options, context)
end
