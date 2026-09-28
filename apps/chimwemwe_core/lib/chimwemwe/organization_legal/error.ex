defmodule Chimwemwe.OrganizationLegal.Error do
  @moduledoc """
  Stable, non-disclosing error returned by the corporate/legal boundary.

  Errors do not reveal whether an identifier belongs to another tenant or
  whether a capability, entitlement, activation, or record was absent.
  """

  @enforce_keys [:code]
  defexception [:code]

  @type code ::
          :conflict
          | :forbidden
          | :idempotency_conflict
          | :invalid_input
          | :module_unavailable
          | :not_found
          | :retryable_dependency
          | :stale

  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "corporate/legal action failed: #{code}"
end
