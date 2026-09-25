defmodule Chimwemwe.Platform.TemporalQualificationError do
  @moduledoc """
  Stable, non-disclosing failure returned by the neutral temporal proof boundary.
  """

  use Splode.Error, fields: [:code], class: :invalid

  @type code ::
          :conflict
          | :effective_time_conflict
          | :forbidden
          | :idempotency_conflict
          | :internal
          | :invalid_input
          | :not_found
          | :retryable_dependency
          | :unsupported_query
  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "temporal qualification failed: #{code}"
end
