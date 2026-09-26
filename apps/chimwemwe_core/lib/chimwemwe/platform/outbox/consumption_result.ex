defmodule Chimwemwe.Platform.Outbox.ConsumptionResult do
  @moduledoc "Immutable outcome of one database-local consumer transaction."

  @enforce_keys [:consumer_key, :event_id, :handler_revision, :result_digest, :state]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          consumer_key: String.t(),
          event_id: String.t(),
          handler_revision: pos_integer(),
          result_digest: binary(),
          state: :processed | :already_processed
        }
end
