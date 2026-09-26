defmodule Chimwemwe.Platform.TemporalQualification.ConsumerBasisView do
  @moduledoc """
  One immutable source-revision basis in the neutral reconciliation-consumer chain.
  """

  @enforce_keys [
    :basis_id,
    :consumer_id,
    :aggregate_id,
    :revision_id,
    :operation_id,
    :basis_version,
    :reason_code,
    :recorded_at
  ]
  defstruct [
    :basis_id,
    :consumer_id,
    :aggregate_id,
    :revision_id,
    :operation_id,
    :basis_version,
    :predecessor_basis_id,
    :reason_code,
    :recorded_at
  ]

  @type t :: %__MODULE__{
          basis_id: String.t(),
          consumer_id: String.t(),
          aggregate_id: String.t(),
          revision_id: String.t(),
          operation_id: String.t(),
          basis_version: pos_integer(),
          predecessor_basis_id: String.t() | nil,
          reason_code: String.t(),
          recorded_at: NaiveDateTime.t()
        }
end
