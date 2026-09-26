defmodule Chimwemwe.Platform.OutboxError do
  @moduledoc "Stable, non-disclosing failure returned by the outbox delivery boundary."

  use Splode.Error, fields: [:code], class: :invalid

  @type code ::
          :conflict
          | :consumer_rejected
          | :consumer_not_available
          | :forbidden
          | :internal
          | :invalid_contract
          | :invalid_input
          | :invalid_registry
          | :not_found
          | :retryable_dependency
  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "outbox delivery failed: #{code}"
end
