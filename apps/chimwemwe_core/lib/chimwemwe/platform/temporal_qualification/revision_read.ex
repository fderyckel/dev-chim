defmodule Chimwemwe.Platform.TemporalQualification.RevisionRead do
  @moduledoc false

  alias Chimwemwe.Platform.TemporalQualification.{HistoryView, RevisionView, SegmentView}
  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @history_limit 100

  @spec get_current(String.t(), String.t()) ::
          {:ok, RevisionView.t()} | {:error, TemporalQualificationError.t()}
  def get_current(tenant_id, aggregate_id) do
    query_revision(
      """
      SELECT
        revision.aggregate_id::text,
        revision.id::text,
        revision.operation_id::text,
        revision.aggregate_revision,
        revision.predecessor_revision_id::text,
        revision.reason_code,
        revision.recorded_at,
        segment.id::text,
        segment.effective_from,
        segment.effective_until,
        segment.value
      FROM platform_temporal_qualification_aggregates AS aggregate
      JOIN platform_temporal_qualification_revisions AS revision
        ON revision.tenant_id = aggregate.tenant_id
       AND revision.aggregate_id = aggregate.id
       AND revision.id = aggregate.current_revision_id
      LEFT JOIN platform_temporal_qualification_segments AS segment
        ON segment.tenant_id = revision.tenant_id
       AND segment.aggregate_id = revision.aggregate_id
       AND segment.revision_id = revision.id
      WHERE aggregate.tenant_id = $1 AND aggregate.id = $2
      ORDER BY segment.effective_from, segment.effective_until, segment.id
      """,
      [dump_uuid(tenant_id), dump_uuid(aggregate_id)]
    )
  end

  @spec get_revision(String.t(), String.t()) ::
          {:ok, RevisionView.t()} | {:error, TemporalQualificationError.t()}
  def get_revision(tenant_id, revision_id) do
    query_revision(
      """
      SELECT
        revision.aggregate_id::text,
        revision.id::text,
        revision.operation_id::text,
        revision.aggregate_revision,
        revision.predecessor_revision_id::text,
        revision.reason_code,
        revision.recorded_at,
        segment.id::text,
        segment.effective_from,
        segment.effective_until,
        segment.value
      FROM platform_temporal_qualification_revisions AS revision
      LEFT JOIN platform_temporal_qualification_segments AS segment
        ON segment.tenant_id = revision.tenant_id
       AND segment.aggregate_id = revision.aggregate_id
       AND segment.revision_id = revision.id
      WHERE revision.tenant_id = $1 AND revision.id = $2
      ORDER BY segment.effective_from, segment.effective_until, segment.id
      """,
      [dump_uuid(tenant_id), dump_uuid(revision_id)]
    )
  end

  @spec get_effective(String.t(), String.t(), Date.t()) ::
          {:ok, RevisionView.t()} | {:error, TemporalQualificationError.t()}
  def get_effective(tenant_id, aggregate_id, as_of) do
    case Repo.query(
           """
           SELECT
             revision.aggregate_id::text,
             revision.id::text,
             revision.operation_id::text,
             revision.aggregate_revision,
             revision.predecessor_revision_id::text,
             revision.reason_code,
             revision.recorded_at,
             segment.id::text,
             segment.effective_from,
             segment.effective_until,
             segment.value
           FROM platform_temporal_qualification_aggregates AS aggregate
           JOIN platform_temporal_qualification_revisions AS revision
             ON revision.tenant_id = aggregate.tenant_id
            AND revision.aggregate_id = aggregate.id
            AND revision.id = aggregate.current_revision_id
           JOIN platform_temporal_qualification_segments AS segment
             ON segment.tenant_id = revision.tenant_id
            AND segment.aggregate_id = revision.aggregate_id
            AND segment.revision_id = revision.id
           WHERE aggregate.tenant_id = $1
             AND aggregate.id = $2
             AND segment.effective_from <= $3
             AND $3 < segment.effective_until
           ORDER BY segment.effective_from, segment.id
           """,
           [dump_uuid(tenant_id), dump_uuid(aggregate_id), as_of]
         ) do
      {:ok, %{rows: []}} -> temporal_error(:not_found)
      {:ok, %{rows: [_row] = rows}} -> {:ok, rows |> rows_to_revisions() |> hd()}
      {:ok, %{rows: _ambiguous}} -> temporal_error(:effective_time_conflict)
      {:error, _error} -> temporal_error(:retryable_dependency)
    end
  end

  @spec list_history(String.t(), String.t()) ::
          {:ok, HistoryView.t()} | {:error, TemporalQualificationError.t()}
  def list_history(tenant_id, aggregate_id) do
    case Repo.query(
           """
           WITH selected_revisions AS (
             SELECT
               revision.*,
               count(*) OVER () AS total_count
             FROM platform_temporal_qualification_revisions AS revision
             WHERE revision.tenant_id = $1 AND revision.aggregate_id = $2
             ORDER BY revision.aggregate_revision
             LIMIT $3
           )
           SELECT
             revision.aggregate_id::text,
             revision.id::text,
             revision.operation_id::text,
             revision.aggregate_revision,
             revision.predecessor_revision_id::text,
             revision.reason_code,
             revision.recorded_at,
             segment.id::text,
             segment.effective_from,
             segment.effective_until,
             segment.value,
             revision.total_count
           FROM selected_revisions AS revision
           LEFT JOIN platform_temporal_qualification_segments AS segment
             ON segment.tenant_id = revision.tenant_id
            AND segment.aggregate_id = revision.aggregate_id
            AND segment.revision_id = revision.id
           ORDER BY revision.aggregate_revision, segment.effective_from, segment.id
           """,
           [dump_uuid(tenant_id), dump_uuid(aggregate_id), @history_limit]
         ) do
      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:ok, %{rows: rows}} ->
        total_count = rows |> hd() |> List.last()
        revision_rows = Enum.map(rows, &Enum.drop(&1, -1))

        {:ok,
         %HistoryView{
           aggregate_id: aggregate_id,
           revisions: rows_to_revisions(revision_rows),
           truncated?: total_count > @history_limit
         }}

      {:error, _error} ->
        temporal_error(:retryable_dependency)
    end
  end

  defp query_revision(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{rows: []}} -> temporal_error(:not_found)
      {:ok, %{rows: rows}} -> {:ok, rows |> rows_to_revisions() |> hd()}
      {:error, _error} -> temporal_error(:retryable_dependency)
    end
  end

  defp rows_to_revisions(rows) do
    rows
    |> Enum.reduce([], fn
      [
        _aggregate_id,
        revision_id,
        _operation_id,
        _aggregate_revision,
        _predecessor_revision_id,
        _reason_code,
        _recorded_at,
        segment_id,
        effective_from,
        effective_until,
        value
      ],
      [%RevisionView{} = current | rest]
      when current.revision_id == revision_id ->
        [
          %{
            current
            | segments:
                append_segment(
                  current.segments,
                  segment_id,
                  effective_from,
                  effective_until,
                  value
                )
          }
          | rest
        ]

      [
        aggregate_id,
        revision_id,
        operation_id,
        aggregate_revision,
        predecessor_revision_id,
        reason_code,
        recorded_at,
        segment_id,
        effective_from,
        effective_until,
        value
      ],
      revisions ->
        [
          %RevisionView{
            aggregate_id: aggregate_id,
            revision_id: revision_id,
            operation_id: operation_id,
            aggregate_revision: aggregate_revision,
            predecessor_revision_id: predecessor_revision_id,
            reason_code: reason_code,
            recorded_at: recorded_at,
            segments: append_segment([], segment_id, effective_from, effective_until, value)
          }
          | revisions
        ]
    end)
    |> Enum.reverse()
    |> Enum.map(fn revision -> %{revision | segments: Enum.reverse(revision.segments)} end)
  end

  defp append_segment(segments, nil, _effective_from, _effective_until, _value), do: segments

  defp append_segment(segments, id, effective_from, effective_until, value) do
    [
      %SegmentView{
        id: id,
        effective_from: effective_from,
        effective_until: effective_until,
        value: value
      }
      | segments
    ]
  end

  defp dump_uuid(value), do: UUID.dump!(value)
  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
