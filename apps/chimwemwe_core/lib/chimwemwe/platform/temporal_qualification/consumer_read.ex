defmodule Chimwemwe.Platform.TemporalQualification.ConsumerRead do
  @moduledoc false

  alias Chimwemwe.Platform.TemporalQualification.{
    ConsumerBasisView,
    ConsumerHistoryView,
    OperationEvidence
  }

  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo

  @history_limit 100

  @spec get_current(String.t(), String.t()) ::
          {:ok, ConsumerBasisView.t()} | {:error, TemporalQualificationError.t()}
  def get_current(tenant_id, consumer_id) do
    case Repo.query(
           select_sql() <>
             """
             WHERE tenant_id = $1 AND consumer_id = $2
             ORDER BY basis_version DESC
             LIMIT 1
             """,
           [OperationEvidence.dump_uuid(tenant_id), OperationEvidence.dump_uuid(consumer_id)]
         ) do
      {:ok, %{rows: [row]}} -> row_to_basis(row)
      {:ok, %{rows: []}} -> temporal_error(:not_found)
      {:error, _error} -> temporal_error(:retryable_dependency)
    end
  end

  @spec list_history(String.t(), String.t()) ::
          {:ok, ConsumerHistoryView.t()} | {:error, TemporalQualificationError.t()}
  def list_history(tenant_id, consumer_id) do
    case Repo.query(
           """
           SELECT
             id::text,
             consumer_id::text,
             aggregate_id::text,
             revision_id::text,
             operation_id::text,
             basis_version,
             predecessor_basis_id::text,
             reason_code,
             recorded_at,
             count(*) OVER () AS total_count
           FROM platform_temporal_qualification_consumer_bases
           WHERE tenant_id = $1 AND consumer_id = $2
           ORDER BY basis_version
           LIMIT $3
           """,
           [
             OperationEvidence.dump_uuid(tenant_id),
             OperationEvidence.dump_uuid(consumer_id),
             @history_limit
           ]
         ) do
      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:ok, %{rows: rows}} ->
        total_count = rows |> hd() |> List.last()

        rows
        |> Enum.map(&Enum.drop(&1, -1))
        |> map_rows()
        |> case do
          {:ok, bases} ->
            {:ok,
             %ConsumerHistoryView{
               consumer_id: consumer_id,
               bases: bases,
               truncated?: total_count > @history_limit
             }}

          error ->
            error
        end

      {:error, _error} ->
        temporal_error(:retryable_dependency)
    end
  end

  defp select_sql do
    """
    SELECT
      id::text,
      consumer_id::text,
      aggregate_id::text,
      revision_id::text,
      operation_id::text,
      basis_version,
      predecessor_basis_id::text,
      reason_code,
      recorded_at
    FROM platform_temporal_qualification_consumer_bases
    """
  end

  defp map_rows(rows) do
    rows
    |> Enum.reduce_while({:ok, []}, fn row, {:ok, bases} ->
      case row_to_basis(row) do
        {:ok, basis} -> {:cont, {:ok, [basis | bases]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, bases} -> {:ok, Enum.reverse(bases)}
      error -> error
    end
  end

  defp row_to_basis([
         basis_id,
         consumer_id,
         aggregate_id,
         revision_id,
         operation_id,
         basis_version,
         predecessor_basis_id,
         reason_code,
         recorded_at
       ]) do
    {:ok,
     %ConsumerBasisView{
       basis_id: basis_id,
       consumer_id: consumer_id,
       aggregate_id: aggregate_id,
       revision_id: revision_id,
       operation_id: operation_id,
       basis_version: basis_version,
       predecessor_basis_id: predecessor_basis_id,
       reason_code: reason_code,
       recorded_at: recorded_at
     }}
  end

  defp row_to_basis(_row), do: temporal_error(:retryable_dependency)

  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
