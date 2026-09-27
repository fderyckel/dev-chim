alias Chimwemwe.Platform.{
  ExecutionContext,
  Persistence,
  PersistenceRuntime,
  TemporalQualification,
  TrustedActor,
  TrustedPlacement
}

alias Chimwemwe.Platform.TemporalQualification.ProjectionResult
alias Chimwemwe.Repo

tenant_id = "11111111-1111-4111-8111-111111111111"
actor_id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
module_key = "synthetic.temporal"

{:ok, actor} =
  TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

{:ok, placement} =
  TrustedPlacement.establish(
    tenant_id: tenant_id,
    routing_version: 7,
    profile: :pooled,
    placement_ref: "pooled-temporal-completion"
  )

{:ok, context} =
  ExecutionContext.establish(
    actor,
    placement,
    correlation_id: Ecto.UUID.generate(),
    purpose: "platform.temporal_qualification.restore_rehearsal",
    locale: "en"
  )

{:ok, runtime} =
  PersistenceRuntime.start_link(
    repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 2]],
    placements: [
      [
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-temporal-completion",
        repository: :pooled
      ]
    ],
    per_tenant_limit: 2,
    per_placement_limit: 2
  )

{:ok, [[aggregate_id]]} =
  Persistence.with_writer(runtime, context, fn ->
    Repo.query!(
      """
      SELECT aggregate_id::text
      FROM platform_temporal_qualification_current_projections
      WHERE tenant_id = $1
      ORDER BY aggregate_id
      LIMIT 1
      """,
      [Ecto.UUID.dump!(tenant_id)]
    ).rows
  end)

{:ok, %{num_rows: 1}} =
  Persistence.with_writer(runtime, context, fn ->
    Repo.query!(
      """
      DELETE FROM platform_temporal_qualification_current_projections
      WHERE tenant_id = $1 AND aggregate_id = $2
      """,
      [Ecto.UUID.dump!(tenant_id), Ecto.UUID.dump!(aggregate_id)]
    )
  end)

{:ok, %ProjectionResult{aggregate_id: ^aggregate_id, converged: true} = rebuilt} =
  TemporalQualification.rebuild_current_projection(
    runtime,
    context,
    %{aggregate_id: aggregate_id, module_key: module_key}
  )

{:ok, [[2, 3, 5, 1, 2, 3, 1, 0, 0, 0, 0]]} =
  Persistence.with_writer(runtime, context, fn ->
    Repo.query!(
      """
      SELECT
        (SELECT count(*) FROM platform_temporal_qualification_aggregates WHERE tenant_id = $1),
        (SELECT count(*) FROM platform_temporal_qualification_revisions WHERE tenant_id = $1),
        (SELECT count(*) FROM platform_temporal_qualification_segments WHERE tenant_id = $1),
        (SELECT count(*) FROM platform_temporal_qualification_current_projections WHERE tenant_id = $1),
        (SELECT count(*) FROM platform_temporal_qualification_retention_controls WHERE tenant_id = $1),
        (SELECT count(*) FROM platform_temporal_qualification_retention_receipts WHERE tenant_id = $1),
        (SELECT count(*) FROM platform_temporal_qualification_import_records WHERE tenant_id = $1),
        (SELECT count(*) FROM platform_temporal_qualification_revisions AS revision
         WHERE revision.tenant_id = $1
           AND revision.predecessor_revision_id IS NOT NULL
           AND NOT EXISTS (
             SELECT 1 FROM platform_temporal_qualification_revisions AS predecessor
             WHERE predecessor.tenant_id = revision.tenant_id
               AND predecessor.id = revision.predecessor_revision_id
               AND predecessor.aggregate_id = revision.aggregate_id
           )),
        (SELECT count(*) FROM platform_temporal_qualification_current_projections AS projection
         JOIN platform_temporal_qualification_aggregates AS aggregate
           ON aggregate.tenant_id = projection.tenant_id
          AND aggregate.id = projection.aggregate_id
         WHERE projection.tenant_id = $1
           AND projection.revision_id <> aggregate.current_revision_id),
        (SELECT count(*) FROM platform_temporal_qualification_import_records AS imported
         WHERE imported.tenant_id = $1
           AND imported.revision_id IS NOT NULL
           AND NOT EXISTS (
             SELECT 1 FROM platform_temporal_qualification_revisions AS revision
             WHERE revision.tenant_id = imported.tenant_id
               AND revision.id = imported.revision_id
               AND revision.aggregate_id = imported.aggregate_id
           )),
        (SELECT count(*) FROM platform_temporal_qualification_segments
         WHERE tenant_id = $1 AND redacted_at IS NOT NULL AND value <> '[redacted]')
      """,
      [Ecto.UUID.dump!(tenant_id)]
    ).rows
  end)

IO.puts(
  "temporal_restore_verified aggregate=#{aggregate_id} revision=#{rebuilt.revision_id} " <>
    "projection_version=#{rebuilt.projection_version}"
)
