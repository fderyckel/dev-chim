defmodule Chimwemwe.Platform.Outbox.ReplayCursor do
  @moduledoc "Bounded tenant-qualified cursor window for dead-letter recovery."

  @enforce_keys [:after_cursor, :limit, :through_cursor]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          after_cursor: non_neg_integer(),
          through_cursor: pos_integer(),
          limit: pos_integer()
        }
end
