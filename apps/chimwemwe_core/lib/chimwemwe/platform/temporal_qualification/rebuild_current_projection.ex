defmodule Chimwemwe.Platform.TemporalQualification.RebuildCurrentProjection do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.TemporalQualification.{OperationEvidence, ProjectionResult}
  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @capability "platform.temporal_qualification.projections.rebuild"
  @lock_namespace "platform-temporal-qualification-projection"

  @impl true
  def run(input, _options, ash_context) do
    arguments = input.arguments

    with {:ok, context} <- OperationEvidence.context(ash_context),
         :ok <- OperationEvidence.lock(@lock_namespace, context.tenant_id, arguments.aggregate_id),
         :ok <- OperationEvidence.authorize(context, @capability),
         :ok <- require_active_module(context.tenant_id, arguments.module_key),
         :ok <- require_not_erased(context.tenant_id, arguments.aggregate_id),
         {:ok, source} <- load_source(context.tenant_id, arguments.aggregate_id) do
      rebuild(context.tenant_id, source)
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp require_active_module(tenant_id, module_key) do
    case Repo.query(
           """
           SELECT 1
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1 AND entitlement.module_key = $2
             AND activation.state = 'active'
             AND activation.retained_data_state = 'retained'
           FOR KEY SHARE
           """,
           [dump(tenant_id), module_key]
         ) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, %{rows: []}} -> temporal_error(:forbidden)
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp require_not_erased(tenant_id, aggregate_id) do
    case Repo.query(
           """
           SELECT state FROM platform_temporal_qualification_retention_controls
           WHERE tenant_id = $1 AND aggregate_id = $2
           FOR SHARE
           """,
           [dump(tenant_id), dump(aggregate_id)]
         ) do
      {:ok, %{rows: [["retained"]]}} -> :ok
      {:ok, %{rows: [["held"]]}} -> :ok
      {:ok, %{rows: [["erased"]]}} -> temporal_error(:retention_conflict)
      {:ok, %{rows: []}} -> temporal_error(:retention_conflict)
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp load_source(tenant_id, aggregate_id) do
    case Repo.query(
           """
           SELECT aggregate.id::text,
                  aggregate.current_revision_id::text,
                  (
                    SELECT count(*)::bigint
                    FROM platform_temporal_qualification_segments AS segment
                    WHERE segment.tenant_id = aggregate.tenant_id
                      AND segment.aggregate_id = aggregate.id
                      AND segment.revision_id = aggregate.current_revision_id
                  )
           FROM platform_temporal_qualification_aggregates AS aggregate
           WHERE aggregate.tenant_id = $1 AND aggregate.id = $2
           FOR SHARE OF aggregate
           """,
           [dump(tenant_id), dump(aggregate_id)]
         ) do
      {:ok, %{rows: [[aggregate_id, revision_id, segment_count]]}} ->
        {:ok,
         %{aggregate_id: aggregate_id, revision_id: revision_id, segment_count: segment_count}}

      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp rebuild(tenant_id, source) do
    projection_id = UUID.generate()

    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_current_projections (
             id, tenant_id, aggregate_id, revision_id, projection_version,
             segment_count, refreshed_at
           )
           VALUES ($1, $2, $3, $4, 1, $5, NOW())
           ON CONFLICT (tenant_id, aggregate_id) DO UPDATE
           SET revision_id = EXCLUDED.revision_id,
               projection_version = platform_temporal_qualification_current_projections.projection_version + 1,
               segment_count = EXCLUDED.segment_count,
               refreshed_at = NOW()
           RETURNING revision_id::text, projection_version, segment_count, refreshed_at
           """,
           [
             dump(projection_id),
             dump(tenant_id),
             dump(source.aggregate_id),
             dump(source.revision_id),
             source.segment_count
           ]
         ) do
      {:ok, %{rows: [[revision_id, version, segment_count, refreshed_at]]}} ->
        {:ok,
         %ProjectionResult{
           aggregate_id: source.aggregate_id,
           revision_id: revision_id,
           projection_version: version,
           segment_count: segment_count,
           converged: revision_id == source.revision_id and segment_count == source.segment_count,
           refreshed_at: refreshed_at
         }}

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp dump(value), do: OperationEvidence.dump_uuid(value)
  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
