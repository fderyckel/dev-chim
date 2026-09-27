defmodule Chimwemwe.Identity.Error do
  @moduledoc """
  Stable, non-disclosing error returned by the internal identity foundation.

  The boundary deliberately avoids returning provider assertions, invitation
  state, subjects, tokens, or database details to callers.
  """

  @enforce_keys [:code]
  defexception [:code]

  @type code ::
          :conflict
          | :expired
          | :forbidden
          | :idempotency_conflict
          | :invalid_input
          | :not_found
          | :retryable_dependency
          | :stale

  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "identity action failed: #{code}"
end
