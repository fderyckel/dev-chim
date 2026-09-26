defmodule Chimwemwe.Platform.TemporalQualification.FactRead do
  @moduledoc false

  alias Chimwemwe.Platform.TemporalQualification.{
    FactHistoryView,
    FactOperationView,
    FactView,
    OperationEvidence
  }

  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo

  @history_limit 100

  @spec get_fact(String.t(), String.t()) ::
          {:ok, FactView.t()} | {:error, TemporalQualificationError.t()}
  def get_fact(tenant_id, fact_id) do
    case Repo.query(
           """
           SELECT
             id::text,
             operation_id::text,
             kind,
             reverses_fact_id::text,
             effective_on,
             quantity,
             recorded_at
           FROM platform_temporal_qualification_facts
           WHERE tenant_id = $1 AND id = $2
           """,
           [OperationEvidence.dump_uuid(tenant_id), OperationEvidence.dump_uuid(fact_id)]
         ) do
      {:ok, %{rows: [row]}} -> row_to_fact(row)
      {:ok, %{rows: []}} -> temporal_error(:not_found)
      {:error, _error} -> temporal_error(:retryable_dependency)
    end
  end

  @spec get_operation(String.t(), String.t()) ::
          {:ok, FactOperationView.t()} | {:error, TemporalQualificationError.t()}
  def get_operation(tenant_id, operation_id) do
    query_operations(
      """
      SELECT
        operation.id::text,
        operation.scope_id::text,
        operation.kind,
        operation.target_fact_id::text,
        operation.reason_code,
        operation.recorded_at,
        fact.id::text,
        fact.operation_id::text,
        fact.kind,
        fact.reverses_fact_id::text,
        fact.effective_on,
        fact.quantity,
        fact.recorded_at
      FROM platform_temporal_qualification_fact_operations AS operation
      LEFT JOIN platform_temporal_qualification_facts AS fact
        ON fact.tenant_id = operation.tenant_id
       AND fact.scope_id = operation.scope_id
       AND fact.operation_id = operation.id
      WHERE operation.tenant_id = $1 AND operation.id = $2
      ORDER BY
        CASE fact.kind WHEN 'reversal' THEN 0 ELSE 1 END,
        fact.id
      """,
      [OperationEvidence.dump_uuid(tenant_id), OperationEvidence.dump_uuid(operation_id)]
    )
    |> case do
      {:ok, [operation]} -> {:ok, operation}
      {:ok, []} -> temporal_error(:not_found)
      {:error, _reason} = error -> error
    end
  end

  @spec list_history(String.t(), String.t()) ::
          {:ok, FactHistoryView.t()} | {:error, TemporalQualificationError.t()}
  def list_history(tenant_id, scope_id) do
    case Repo.query(
           """
           WITH selected_operations AS (
             SELECT operation.*, count(*) OVER () AS total_count
             FROM platform_temporal_qualification_fact_operations AS operation
             WHERE operation.tenant_id = $1 AND operation.scope_id = $2
             ORDER BY operation.recorded_at, operation.id
             LIMIT $3
           )
           SELECT
             operation.id::text,
             operation.scope_id::text,
             operation.kind,
             operation.target_fact_id::text,
             operation.reason_code,
             operation.recorded_at,
             fact.id::text,
             fact.operation_id::text,
             fact.kind,
             fact.reverses_fact_id::text,
             fact.effective_on,
             fact.quantity,
             fact.recorded_at,
             operation.total_count
           FROM selected_operations AS operation
           LEFT JOIN platform_temporal_qualification_facts AS fact
             ON fact.tenant_id = operation.tenant_id
            AND fact.scope_id = operation.scope_id
            AND fact.operation_id = operation.id
           ORDER BY
             operation.recorded_at,
             operation.id,
             CASE fact.kind WHEN 'reversal' THEN 0 ELSE 1 END,
             fact.id
           """,
           [
             OperationEvidence.dump_uuid(tenant_id),
             OperationEvidence.dump_uuid(scope_id),
             @history_limit
           ]
         ) do
      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:ok, %{rows: rows}} ->
        total_count = rows |> hd() |> List.last()
        operation_rows = Enum.map(rows, &Enum.drop(&1, -1))

        with {:ok, operations} <- rows_to_operations(operation_rows) do
          {:ok,
           %FactHistoryView{
             scope_id: scope_id,
             operations: operations,
             truncated?: total_count > @history_limit
           }}
        end

      {:error, _error} ->
        temporal_error(:retryable_dependency)
    end
  end

  defp query_operations(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{rows: rows}} -> rows_to_operations(rows)
      {:error, _error} -> temporal_error(:retryable_dependency)
    end
  end

  defp rows_to_operations(rows) do
    rows
    |> Enum.reduce_while({:ok, []}, fn row, {:ok, operations} ->
      reduce_operation_row(row, operations)
    end)
    |> case do
      {:ok, operations} ->
        {:ok,
         operations
         |> Enum.reverse()
         |> Enum.map(fn operation -> %{operation | facts: Enum.reverse(operation.facts)} end)}

      error ->
        error
    end
  end

  defp reduce_operation_row(row, [operation | rest] = operations) do
    if operation.operation_id == Enum.at(row, 0) do
      append_fact_row(row, operation, rest)
    else
      prepend_operation_row(row, operations)
    end
  end

  defp reduce_operation_row(row, operations), do: prepend_operation_row(row, operations)

  defp append_fact_row(row, operation, rest) do
    case row_to_optional_fact(Enum.drop(row, 6)) do
      {:ok, nil} -> {:cont, {:ok, [operation | rest]}}
      {:ok, fact} -> {:cont, {:ok, [%{operation | facts: [fact | operation.facts]} | rest]}}
      {:error, _reason} = error -> {:halt, error}
    end
  end

  defp prepend_operation_row(row, operations) do
    case row_to_operation(row) do
      {:ok, operation} -> {:cont, {:ok, [operation | operations]}}
      {:error, _reason} = error -> {:halt, error}
    end
  end

  defp row_to_operation([
         operation_id,
         scope_id,
         kind,
         target_fact_id,
         reason_code,
         recorded_at
         | fact_fields
       ]) do
    with {:ok, kind} <- cast_operation_kind(kind),
         {:ok, fact} <- row_to_optional_fact(fact_fields) do
      {:ok,
       %FactOperationView{
         operation_id: operation_id,
         scope_id: scope_id,
         kind: kind,
         target_fact_id: target_fact_id,
         reason_code: reason_code,
         recorded_at: recorded_at,
         facts: if(fact, do: [fact], else: [])
       }}
    end
  end

  defp row_to_optional_fact([nil, nil, nil, nil, nil, nil, nil]), do: {:ok, nil}
  defp row_to_optional_fact(fields), do: row_to_fact(fields)

  defp row_to_fact([
         id,
         operation_id,
         kind,
         reverses_fact_id,
         effective_on,
         quantity,
         recorded_at
       ]) do
    with {:ok, kind} <- cast_fact_kind(kind) do
      {:ok,
       %FactView{
         id: id,
         operation_id: operation_id,
         kind: kind,
         reverses_fact_id: reverses_fact_id,
         effective_on: effective_on,
         quantity: quantity,
         recorded_at: recorded_at
       }}
    end
  end

  defp row_to_fact(_row), do: temporal_error(:retryable_dependency)

  defp cast_operation_kind("record"), do: {:ok, :record}
  defp cast_operation_kind("reverse_and_replace"), do: {:ok, :reverse_and_replace}
  defp cast_operation_kind(_kind), do: temporal_error(:retryable_dependency)

  defp cast_fact_kind("entry"), do: {:ok, :entry}
  defp cast_fact_kind("reversal"), do: {:ok, :reversal}
  defp cast_fact_kind(_kind), do: temporal_error(:retryable_dependency)

  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
