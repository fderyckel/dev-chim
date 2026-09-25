defmodule Chimwemwe.Platform.TemporalQualification.PublishRevision do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.TemporalQualification.RevisionAction

  @impl true
  def run(input, options, context), do: RevisionAction.run(:publish, input, options, context)
end
