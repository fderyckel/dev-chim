defmodule Chimwemwe.Platform.Outbox.ReplayResult do
  @moduledoc "Immutable exact result of one governed dead-letter replay."

  @enforce_keys [
    :audit_reference,
    :consumer_key,
    :event_id,
    :lock_version,
    :replay_count,
    :status
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          audit_reference: String.t(),
          consumer_key: String.t(),
          event_id: String.t(),
          lock_version: pos_integer(),
          replay_count: pos_integer(),
          status: :available
        }
end
