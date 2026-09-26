defmodule Chimwemwe.Platform.TemporalQualification.ConsumerHistoryView do
  @moduledoc """
  Bounded immutable basis history for one deliberate-reconciliation consumer.
  """

  alias Chimwemwe.Platform.TemporalQualification.ConsumerBasisView

  @enforce_keys [:consumer_id, :bases, :truncated?]
  defstruct [:consumer_id, :bases, :truncated?]

  @type t :: %__MODULE__{
          consumer_id: String.t(),
          bases: [ConsumerBasisView.t()],
          truncated?: boolean()
        }
end
