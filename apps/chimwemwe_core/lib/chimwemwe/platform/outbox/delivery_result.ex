defmodule Chimwemwe.Platform.Outbox.DeliveryResult do
  @moduledoc "Immutable result of an exact outbox delivery transition."

  @enforce_keys [:attempt_count, :consumer_key, :event_id, :lock_version, :status]
  defstruct [
    :attempt_count,
    :available_at,
    :completed_at,
    :consumer_key,
    :event_id,
    :lock_version,
    :status
  ]

  @type t :: %__MODULE__{
          attempt_count: pos_integer(),
          available_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          consumer_key: String.t(),
          event_id: String.t(),
          lock_version: pos_integer(),
          status: :available | :completed | :dead_letter | :leased
        }
end
