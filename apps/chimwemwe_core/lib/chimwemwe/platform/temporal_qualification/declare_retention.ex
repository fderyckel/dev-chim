defmodule Chimwemwe.Platform.TemporalQualification.DeclareRetention do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Chimwemwe.Platform.TemporalQualification.RetentionAction
  @impl true
  def run(input, options, context), do: RetentionAction.run(:declare, input, options, context)
end
