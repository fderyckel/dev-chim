defmodule Chimwemwe.Platform.Outbox.Status do
  @moduledoc "Sanitized count-only operational status for one code-owned consumer."

  @enforce_keys [
    :available,
    :completed,
    :dead_letter,
    :expired_lease,
    :leased,
    :oldest_pending_at,
    :stale_route,
    :unclaimed
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          available: non_neg_integer(),
          completed: non_neg_integer(),
          dead_letter: non_neg_integer(),
          expired_lease: non_neg_integer(),
          leased: non_neg_integer(),
          oldest_pending_at: DateTime.t() | nil,
          stale_route: non_neg_integer(),
          unclaimed: non_neg_integer()
        }
end
