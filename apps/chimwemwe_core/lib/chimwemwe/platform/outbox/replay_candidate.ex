defmodule Chimwemwe.Platform.Outbox.ReplayCandidate do
  @moduledoc "Minimal exact dead-letter reference returned by cursor paging."

  @enforce_keys [:event_id, :expected_lock_version, :stream_position]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          event_id: String.t(),
          expected_lock_version: pos_integer(),
          stream_position: pos_integer()
        }
end
