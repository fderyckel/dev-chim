defmodule Chimwemwe.Platform.TemporalQualification.ConsumerResult do
  @moduledoc """
  Complete committed pin or deliberate-reconciliation result.
  """

  alias Chimwemwe.Platform.TemporalQualification.ConsumerBasisView

  @enforce_keys [:basis, :audit_reference, :event_id]
  defstruct [:basis, :audit_reference, :event_id]

  @type t :: %__MODULE__{
          basis: ConsumerBasisView.t(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
