defmodule Chimwemwe.Platform.Outbox.Envelope do
  @moduledoc """
  Immutable internal handoff for one currently leased outbox event.

  The envelope is delivery evidence, never authority or a repository destination.
  Consumers must re-enter their own trusted tenant-aware boundary.
  """

  @enforce_keys [
    :attempt_count,
    :actor_id,
    :causation_id,
    :classification,
    :correlation_id,
    :event_id,
    :event_type,
    :lease_expires_at,
    :lease_token,
    :occurred_at,
    :payload,
    :routing_version,
    :schema_version,
    :tenant_id
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          attempt_count: pos_integer(),
          actor_id: String.t(),
          causation_id: String.t(),
          classification: :internal,
          correlation_id: String.t(),
          event_id: String.t(),
          event_type: String.t(),
          lease_expires_at: DateTime.t(),
          lease_token: String.t(),
          occurred_at: DateTime.t(),
          payload: map(),
          routing_version: pos_integer(),
          schema_version: pos_integer(),
          tenant_id: String.t()
        }
end
