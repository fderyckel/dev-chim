defmodule Chimwemwe.Platform.TemporalQualification.ReconcileConsumerRevision do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.TemporalQualification.ConsumerAction

  @impl true
  def run(input, options, context), do: ConsumerAction.run(:reconcile, input, options, context)
end
