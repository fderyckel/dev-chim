defmodule Chimwemwe.Platform.TemporalQualificationTest do
  use ExUnit.Case, async: false

  alias Ash.Resource.Info, as: ResourceInfo

  alias Chimwemwe.Platform.{
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    ResourceContract,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.TemporalQualification.{Aggregate, Fact, Revision, Segment}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

  @tables [
    "platform_temporal_qualification_segments",
    "platform_temporal_qualification_revisions",
    "platform_temporal_qualification_facts",
    "platform_temporal_qualification_aggregates"
  ]

  setup do
    runtime = start_supervised!({PersistenceRuntime, runtime_options()})

    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("TRUNCATE " <> Enum.join(@tables, ", "))
               :cleared
             end)

    {:ok, runtime: runtime}
  end

  test "qualification resources are tenant-owned, contract-valid, and action-bounded" do
    assert :ok = ResourceContract.validate_domain(Chimwemwe.Platform)

    for resource <- [Aggregate, Revision, Segment, Fact] do
      assert :tenant_owned == resource.__chimwemwe_resource_ownership__()
      assert false == ResourceInfo.multitenancy_global?(resource)
    end

    assert Enum.map(ResourceInfo.actions(Aggregate), & &1.name) == [
             :publish_revision,
             :correct_revision
           ]

    for action <- ResourceInfo.actions(Aggregate), do: refute(action.public?)
    for resource <- [Revision, Segment, Fact], do: assert([] == ResourceInfo.actions(resource))
  end

  test "preserves exact revisions while current and effective reads follow the selector", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    scope_id = UUID.generate()
    revision_1 = UUID.generate()
    revision_2 = UUID.generate()
    before_insert = DateTime.utc_now() |> DateTime.add(-5, :second) |> DateTime.to_naive()

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_a(), fn ->
               insert_aggregate(aggregate_id, @tenant_a, scope_id)

               recorded_1 =
                 insert_revision(
                   revision_1,
                   @tenant_a,
                   aggregate_id,
                   1,
                   nil,
                   "baseline"
                 )

               assert NaiveDateTime.compare(recorded_1, before_insert) in [:gt, :eq]
               refute recorded_1 == ~N[2000-01-01 00:00:00.000000]

               insert_segment(
                 @tenant_a,
                 aggregate_id,
                 revision_1,
                 ~D[2026-01-01],
                 ~D[2026-06-01],
                 "alpha"
               )

               insert_segment(
                 @tenant_a,
                 aggregate_id,
                 revision_1,
                 ~D[2026-06-01],
                 ~D[2027-01-01],
                 "beta"
               )

               select_current(aggregate_id, @tenant_a, revision_1)

               insert_revision(
                 revision_2,
                 @tenant_a,
                 aggregate_id,
                 2,
                 revision_1,
                 "synthetic_correction"
               )

               insert_segment(
                 @tenant_a,
                 aggregate_id,
                 revision_2,
                 ~D[2026-01-01],
                 ~D[2027-01-01],
                 "corrected"
               )

               select_current(aggregate_id, @tenant_a, revision_2)
               :seeded
             end)

    assert {:ok, %{rows: [[1, "alpha"]]}} =
             query(runtime, context_a(), exact_effective_sql(), [
               dump(@tenant_a),
               dump(revision_1),
               ~D[2026-03-01]
             ])

    assert {:ok, %{rows: [[2, "corrected"]]}} =
             query(runtime, context_a(), current_effective_sql(), [
               dump(@tenant_a),
               dump(aggregate_id),
               ~D[2026-03-01]
             ])

    assert {:ok, %{rows: [[1], [2]]}} =
             query(
               runtime,
               context_a(),
               """
               SELECT aggregate_revision
               FROM platform_temporal_qualification_revisions
               WHERE tenant_id = $1 AND aggregate_id = $2
               ORDER BY aggregate_revision
               """,
               [dump(@tenant_a), dump(aggregate_id)]
             )
  end

  test "serializes effective segments and rejects overlap only inside one revision", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    scope_id = UUID.generate()
    revision_id = UUID.generate()

    seed_revision(runtime, context_a(), @tenant_a, aggregate_id, scope_id, revision_id)

    parent = self()

    tasks =
      for {from, until, value} <- [
            {~D[2026-01-01], ~D[2026-08-01], "first"},
            {~D[2026-04-01], ~D[2027-01-01], "second"}
          ] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              query(runtime, context_a(), insert_segment_sql(), [
                dump(UUID.generate()),
                dump(@tenant_a),
                dump(aggregate_id),
                dump(revision_id),
                from,
                until,
                value
              ])
          end
        end)
      end

    task_pids =
      for _index <- 1..2 do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :go))
    results = Enum.map(tasks, &Task.await(&1, 10_000))

    assert 1 == Enum.count(results, &match?({:ok, %Postgrex.Result{}}, &1))

    assert 1 ==
             Enum.count(results, fn
               {:error,
                %Postgrex.Error{
                  postgres: %{constraint: "platform_temporal_qualification_segment_no_overlap"}
                }} ->
                 true

               _other ->
                 false
             end)

    assert {:ok, %{rows: [[1]]}} =
             query(
               runtime,
               context_a(),
               "SELECT count(*) FROM platform_temporal_qualification_segments WHERE revision_id = $1",
               [dump(revision_id)]
             )
  end

  test "compound keys reject cross-tenant, cross-aggregate, and cross-scope links", %{
    runtime: runtime
  } do
    aggregate_a = UUID.generate()
    aggregate_a_peer = UUID.generate()
    aggregate_b = UUID.generate()
    scope_a = UUID.generate()
    scope_a_peer = UUID.generate()
    scope_b = UUID.generate()
    revision_a = UUID.generate()
    revision_a_peer = UUID.generate()
    revision_b = UUID.generate()
    fact_a = UUID.generate()
    fact_b = UUID.generate()

    seed_revision(runtime, context_a(), @tenant_a, aggregate_a, scope_a, revision_a)

    seed_revision(
      runtime,
      context_a(),
      @tenant_a,
      aggregate_a_peer,
      scope_a_peer,
      revision_a_peer
    )

    seed_revision(runtime, context_b(), @tenant_b, aggregate_b, scope_b, revision_b)
    seed_fact(runtime, context_a(), fact_a, @tenant_a, scope_a, "entry", nil, 10)
    seed_fact(runtime, context_b(), fact_b, @tenant_b, scope_b, "entry", nil, 10)

    assert_constraint(
      query(runtime, context_a(), insert_revision_sql(), [
        dump(UUID.generate()),
        dump(@tenant_a),
        dump(aggregate_b),
        dump(UUID.generate()),
        1,
        nil,
        "baseline",
        ~N[2000-01-01 00:00:00.000000]
      ]),
      "platform_temporal_revision_aggregate_tenant_fkey"
    )

    assert_constraint(
      query(runtime, context_a(), insert_revision_sql(), [
        dump(UUID.generate()),
        dump(@tenant_a),
        dump(aggregate_a),
        dump(UUID.generate()),
        2,
        dump(revision_a_peer),
        "wrong_predecessor",
        ~N[2000-01-01 00:00:00.000000]
      ]),
      "platform_temporal_qualification_revision_chain"
    )

    assert_constraint(
      query(runtime, context_a(), insert_segment_sql(), [
        dump(UUID.generate()),
        dump(@tenant_a),
        dump(aggregate_a),
        dump(revision_a_peer),
        ~D[2026-01-01],
        ~D[2027-01-01],
        "wrong aggregate"
      ]),
      "platform_temporal_segment_revision_tenant_fkey"
    )

    assert_constraint(
      query(runtime, context_a(), update_current_sql(), [
        dump(revision_a_peer),
        dump(@tenant_a),
        dump(aggregate_a)
      ]),
      "platform_temporal_qualification_current_revision_monotonic"
    )

    assert_constraint(
      query(runtime, context_a(), insert_fact_sql(), [
        dump(UUID.generate()),
        dump(@tenant_a),
        dump(scope_a_peer),
        dump(UUID.generate()),
        "reversal",
        dump(fact_a),
        ~D[2026-01-01],
        -10,
        ~N[2000-01-01 00:00:00.000000]
      ]),
      "platform_temporal_qualification_fact_reversal_target"
    )

    assert_constraint(
      query(runtime, context_a(), insert_fact_sql(), [
        dump(UUID.generate()),
        dump(@tenant_a),
        dump(scope_a),
        dump(UUID.generate()),
        "reversal",
        dump(fact_b),
        ~D[2026-01-01],
        -10,
        ~N[2000-01-01 00:00:00.000000]
      ]),
      "platform_temporal_qualification_fact_reversal_target"
    )
  end

  test "revision, segment, fact, and aggregate identity cannot be rewritten or deleted", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    scope_id = UUID.generate()
    revision_1 = UUID.generate()
    revision_2 = UUID.generate()
    fact_id = UUID.generate()
    segment_id = UUID.generate()

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_a(), fn ->
               insert_aggregate(aggregate_id, @tenant_a, scope_id)
               insert_revision(revision_1, @tenant_a, aggregate_id, 1, nil, "baseline")

               insert_segment(
                 @tenant_a,
                 aggregate_id,
                 revision_1,
                 ~D[2026-01-01],
                 ~D[2027-01-01],
                 "baseline",
                 segment_id
               )

               select_current(aggregate_id, @tenant_a, revision_1)

               insert_revision(
                 revision_2,
                 @tenant_a,
                 aggregate_id,
                 2,
                 revision_1,
                 "correction"
               )

               select_current(aggregate_id, @tenant_a, revision_2)
               insert_fact(fact_id, @tenant_a, scope_id, "entry", nil, 10)
               :seeded
             end)

    for {sql, params, constraint} <- [
          {"UPDATE platform_temporal_qualification_revisions SET reason_code = 'changed' WHERE id = $1",
           [dump(revision_1)], "platform_temporal_qualification_revision_immutable"},
          {"DELETE FROM platform_temporal_qualification_revisions WHERE id = $1",
           [dump(revision_1)], "platform_temporal_qualification_revision_delete_forbidden"},
          {"UPDATE platform_temporal_qualification_segments SET value = 'changed' WHERE id = $1",
           [dump(segment_id)], "platform_temporal_qualification_segment_immutable"},
          {"DELETE FROM platform_temporal_qualification_facts WHERE id = $1", [dump(fact_id)],
           "platform_temporal_qualification_fact_delete_forbidden"},
          {"UPDATE platform_temporal_qualification_aggregates SET scope_id = $1 WHERE id = $2",
           [dump(UUID.generate()), dump(aggregate_id)],
           "platform_temporal_qualification_aggregate_identity_immutable"},
          {update_current_sql(), [dump(revision_1), dump(@tenant_a), dump(aggregate_id)],
           "platform_temporal_qualification_current_revision_monotonic"}
        ] do
      assert_constraint(query(runtime, context_a(), sql, params), constraint)
    end
  end

  test "append-only reversal and replacement preserve the original and net meaning", %{
    runtime: runtime
  } do
    scope_id = UUID.generate()
    original_id = UUID.generate()
    reversal_id = UUID.generate()
    replacement_id = UUID.generate()
    correction_operation = UUID.generate()
    before_insert = DateTime.utc_now() |> DateTime.add(-5, :second) |> DateTime.to_naive()

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_a(), fn ->
               original_recorded =
                 insert_fact(original_id, @tenant_a, scope_id, "entry", nil, 10)

               assert NaiveDateTime.compare(original_recorded, before_insert) in [:gt, :eq]
               refute original_recorded == ~N[2000-01-01 00:00:00.000000]

               insert_fact(
                 reversal_id,
                 @tenant_a,
                 scope_id,
                 "reversal",
                 original_id,
                 -10,
                 correction_operation
               )

               insert_fact(
                 replacement_id,
                 @tenant_a,
                 scope_id,
                 "entry",
                 nil,
                 12,
                 correction_operation
               )

               :seeded
             end)

    assert {:ok, %{rows: [[3, 12, 2]]}} =
             query(
               runtime,
               context_a(),
               """
               SELECT count(*), sum(quantity)::bigint, count(DISTINCT operation_id)
               FROM platform_temporal_qualification_facts
               WHERE tenant_id = $1 AND scope_id = $2
               """,
               [dump(@tenant_a), dump(scope_id)]
             )

    assert_constraint(
      query(runtime, context_a(), insert_fact_sql(), [
        dump(UUID.generate()),
        dump(@tenant_a),
        dump(scope_id),
        dump(UUID.generate()),
        "reversal",
        dump(original_id),
        ~D[2026-01-01],
        -10,
        ~N[2000-01-01 00:00:00.000000]
      ]),
      "platform_temporal_qualification_fact_reversal_index"
    )

    assert_constraint(
      query(runtime, context_a(), insert_fact_sql(), [
        dump(UUID.generate()),
        dump(@tenant_a),
        dump(scope_id),
        dump(UUID.generate()),
        "reversal",
        dump(reversal_id),
        ~D[2026-01-01],
        10,
        ~N[2000-01-01 00:00:00.000000]
      ]),
      "platform_temporal_qualification_fact_reversal_target"
    )
  end

  defp seed_revision(runtime, context, tenant_id, aggregate_id, scope_id, revision_id) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_aggregate(aggregate_id, tenant_id, scope_id)
               insert_revision(revision_id, tenant_id, aggregate_id, 1, nil, "baseline")
               select_current(aggregate_id, tenant_id, revision_id)
               :seeded
             end)
  end

  defp seed_fact(runtime, context, fact_id, tenant_id, scope_id, kind, reversed_id, quantity) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_fact(fact_id, tenant_id, scope_id, kind, reversed_id, quantity)
               :seeded
             end)
  end

  defp insert_aggregate(id, tenant_id, scope_id) do
    Repo.query!(
      """
      INSERT INTO platform_temporal_qualification_aggregates
        (id, tenant_id, scope_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      Enum.map([id, tenant_id, scope_id], &dump/1)
    )
  end

  defp insert_revision(id, tenant_id, aggregate_id, number, predecessor_id, reason) do
    %{rows: [[recorded_at]]} =
      Repo.query!(insert_revision_sql(), [
        dump(id),
        dump(tenant_id),
        dump(aggregate_id),
        dump(UUID.generate()),
        number,
        dump_optional(predecessor_id),
        reason,
        ~N[2000-01-01 00:00:00.000000]
      ])

    recorded_at
  end

  defp insert_segment(
         tenant_id,
         aggregate_id,
         revision_id,
         effective_from,
         effective_until,
         value,
         id \\ UUID.generate()
       ) do
    Repo.query!(insert_segment_sql(), [
      dump(id),
      dump(tenant_id),
      dump(aggregate_id),
      dump(revision_id),
      effective_from,
      effective_until,
      value
    ])
  end

  defp insert_fact(
         id,
         tenant_id,
         scope_id,
         kind,
         reversed_id,
         quantity,
         operation_id \\ UUID.generate()
       ) do
    %{rows: [[recorded_at]]} =
      Repo.query!(insert_fact_sql(), [
        dump(id),
        dump(tenant_id),
        dump(scope_id),
        dump(operation_id),
        kind,
        dump_optional(reversed_id),
        ~D[2026-01-01],
        quantity,
        ~N[2000-01-01 00:00:00.000000]
      ])

    recorded_at
  end

  defp select_current(aggregate_id, tenant_id, revision_id) do
    Repo.query!(update_current_sql(), [dump(revision_id), dump(tenant_id), dump(aggregate_id)])
  end

  defp query(runtime, context, sql, params) do
    assert {:ok, result} =
             Persistence.with_writer(runtime, context, fn -> Repo.query(sql, params) end)

    result
  end

  defp assert_constraint(
         {:error, %Postgrex.Error{postgres: %{constraint: actual}}},
         expected
       ) do
    assert actual == expected
  end

  defp insert_revision_sql do
    """
    INSERT INTO platform_temporal_qualification_revisions
      (id, tenant_id, aggregate_id, operation_id, aggregate_revision,
       predecessor_revision_id, reason_code, recorded_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING recorded_at
    """
  end

  defp insert_segment_sql do
    """
    INSERT INTO platform_temporal_qualification_segments
      (id, tenant_id, aggregate_id, revision_id, effective_from, effective_until, value)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    """
  end

  defp insert_fact_sql do
    """
    INSERT INTO platform_temporal_qualification_facts
      (id, tenant_id, scope_id, operation_id, kind, reverses_fact_id,
       effective_on, quantity, recorded_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING recorded_at
    """
  end

  defp update_current_sql do
    """
    UPDATE platform_temporal_qualification_aggregates
    SET current_revision_id = $1, updated_at = NOW()
    WHERE tenant_id = $2 AND id = $3
    """
  end

  defp exact_effective_sql do
    """
    SELECT revision.aggregate_revision, segment.value
    FROM platform_temporal_qualification_revisions AS revision
    JOIN platform_temporal_qualification_segments AS segment
      ON segment.tenant_id = revision.tenant_id
     AND segment.aggregate_id = revision.aggregate_id
     AND segment.revision_id = revision.id
    WHERE revision.tenant_id = $1
      AND revision.id = $2
      AND segment.effective_from <= $3
      AND $3 < segment.effective_until
    """
  end

  defp current_effective_sql do
    """
    SELECT revision.aggregate_revision, segment.value
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
    """
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 4]],
      placements: [
        placement(@tenant_a, "pooled-temporal-qualification", :pooled),
        placement(@tenant_b, "pooled-temporal-qualification", :pooled)
      ],
      per_tenant_limit: 4,
      per_placement_limit: 8
    ]
  end

  defp placement(tenant_id, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: 7,
      profile: :pooled,
      placement_ref: placement_ref,
      repository: repository
    ]
  end

  defp context_a, do: context(@actor_a, @tenant_a)
  defp context_b, do: context(@actor_b, @tenant_b)

  defp context(actor_id, tenant_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-temporal-qualification"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: UUID.generate(),
        purpose: "platform.temporal_qualification",
        locale: "en"
      )

    context
  end

  defp dump(nil), do: nil
  defp dump(uuid), do: UUID.dump!(uuid)
  defp dump_optional(uuid), do: dump(uuid)
end
