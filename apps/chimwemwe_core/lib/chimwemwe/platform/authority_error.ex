defmodule Chimwemwe.Platform.AuthorityError do
  @moduledoc """
  Stable, non-disclosing failure returned by the tenant-authority boundary.
  """

  use Splode.Error, fields: [:code], class: :invalid

  @type code ::
          :conflict
          | :forbidden
          | :idempotency_conflict
          | :internal
          | :invalid_capability
          | :invalid_input
          | :not_found
          | :retryable_dependency
  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "tenant authority failed: #{code}"
end
