defmodule Chimwemwe.Platform.Outbox.ReplayPage do
  @moduledoc "Sanitized bounded page of exact dead-letter references."

  @enforce_keys [:items, :next_cursor, :through_cursor]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          items: [Chimwemwe.Platform.Outbox.ReplayCandidate.t()],
          next_cursor: non_neg_integer(),
          through_cursor: pos_integer()
        }
end
