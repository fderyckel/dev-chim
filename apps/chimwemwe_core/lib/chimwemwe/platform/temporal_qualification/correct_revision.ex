defmodule Chimwemwe.Platform.TemporalQualification.CorrectRevision do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.TemporalQualification.RevisionAction

  @impl true
  def run(input, options, context), do: RevisionAction.run(:correct, input, options, context)
end
