defmodule Chimwemwe.Platform.Outbox.DispatcherStatus do
  @moduledoc "Sanitized count-and-time-only status for one supervised dispatcher."

  @enforce_keys [
    :acknowledged_count,
    :failed_count,
    :last_polled_at,
    :processed_count,
    :skipped_count
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          acknowledged_count: non_neg_integer(),
          failed_count: non_neg_integer(),
          last_polled_at: DateTime.t() | nil,
          processed_count: non_neg_integer(),
          skipped_count: non_neg_integer()
        }
end
