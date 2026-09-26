defmodule Chimwemwe.Platform.TemporalQualification.PinConsumerRevision do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.TemporalQualification.ConsumerAction

  @impl true
  def run(input, options, context), do: ConsumerAction.run(:pin, input, options, context)
end
