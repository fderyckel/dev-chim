defmodule Chimwemwe.Platform.TemporalQualificationCompletionTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    ContextError,
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    TemporalQualification,
    TemporalQualificationError,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.TemporalQualification.{ImportResult, ProjectionResult, RetentionResult}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_a_peer "abababab-abab-4bab-8bab-abababababab"
  @actor_a_denied "adadadad-adad-4dad-8dad-adadadadadad"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @module_key "synthetic.temporal"

  @capabilities [
    "platform.temporal_qualification.revisions.publish",
    "platform.temporal_qualification.revisions.correct",
    "platform.temporal_qualification.revisions.read_current",
    "platform.temporal_qualification.revisions.read_history",
    "platform.temporal_qualification.facts.record",
    "platform.temporal_qualification.facts.read_history",
    "platform.temporal_qualification.retention.declare",
    "platform.temporal_qualification.legal_hold.place",
    "platform.temporal_qualification.legal_hold.release",
    "platform.temporal_qualification.retention.erase",
    "platform.temporal_qualification.import.register",
    "platform.temporal_qualification.import.reconcile",
    "platform.temporal_qualification.projections.rebuild"
  ]

  @tables [
    "people_staff_account_associations",
    "people_participations",
    "people_persons",
    "identity_support_access_grants",
    "identity_application_sessions",
    "identity_invitations",
    "identity_external_identity_links",
    "identity_connections",
    "platform_temporal_qualification_current_projections",
    "platform_temporal_qualification_retention_receipts",
    "platform_temporal_qualification_retention_controls",
    "platform_temporal_qualification_import_records",
    "platform_temporal_qualification_consumer_bases",
    "platform_temporal_qualification_segments",
    "platform_temporal_qualification_revisions",
    "platform_temporal_qualification_facts",
    "platform_temporal_qualification_fact_operations",
    "platform_temporal_qualification_aggregates",
    "platform_governed_extension_definitions",
    "platform_module_work_items",
    "platform_module_activations",
    "platform_module_entitlements",
    "platform_authority_action_idempotency",
    "platform_outbox_consumer_receipts",
    "platform_outbox_deliveries",
    "platform_outbox_events",
    "platform_authority_audit_events",
    "platform_role_inclusions",
    "platform_role_capability_grants",
    "platform_actor_role_assignments",
    "platform_capabilities",
    "platform_roles",
    "platform_tenant_memberships"
  ]

  setup do
    runtime = start_supervised!({PersistenceRuntime, runtime_options()})

    assert {:ok, :cleared} = truncate_tables(runtime)
    on_exit(&truncate_tables_after_test/0)

    seed_tenant(runtime, context_a(), @tenant_a, [@actor_a, @actor_a_peer], @actor_a_denied)
    seed_tenant(runtime, context_b(), @tenant_b, [@actor_b], nil)
    {:ok, runtime: runtime}
  end

  defp truncate_tables(runtime) do
    Persistence.with_writer(runtime, context_a(), fn ->
      Repo.query!("TRUNCATE " <> Enum.join(@tables, ", "))
      :cleared
    end)
  end

  defp truncate_tables_after_test do
    {:ok, runtime} = PersistenceRuntime.start_link(runtime_options())

    try do
      assert {:ok, :cleared} = truncate_tables(runtime)
    after
      Supervisor.stop(runtime)
    end
  end

  test "legal hold blocks erasure and mandatory erasure remains available after deactivation", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    scope_id = UUID.generate()
    revision = publish(runtime, context_a(), aggregate_id, scope_id)
    _fact = record_fact(runtime, context_a(), scope_id)

    assert {:ok, %RetentionResult{state: :retained, version: 1} = declared} =
             TemporalQualification.declare_retention(
               runtime,
               context_a(),
               retention_input(aggregate_id)
             )

    assert {:ok, %ProjectionResult{projection_version: 1, converged: true}} =
             TemporalQualification.rebuild_current_projection(
               runtime,
               context_a(),
               %{aggregate_id: aggregate_id, module_key: @module_key}
             )

    hold_digest = :crypto.hash(:sha256, "synthetic-hold-ticket-42")

    assert {:ok, %RetentionResult{state: :held, version: 2} = held} =
             TemporalQualification.place_legal_hold(
               runtime,
               context_a(),
               hold_input(declared.control_id, 1, hold_digest)
             )

    assert {:error, %TemporalQualificationError{code: :legal_hold_conflict}} =
             TemporalQualification.erase_retained_content(
               runtime,
               context_a(),
               erase_input(declared.control_id, 2)
             )

    deactivate_module(runtime, context_a(), @tenant_a)

    assert {:ok, %RetentionResult{state: :retained, version: 3}} =
             TemporalQualification.release_legal_hold(
               runtime,
               context_a(),
               hold_input(declared.control_id, held.version, hold_digest)
             )

    assert {:ok,
            %RetentionResult{
              state: :erased,
              version: 4,
              redacted_segment_count: 2,
              redacted_fact_count: 1,
              purged_projection_count: 1
            } = erased} =
             TemporalQualification.erase_retained_content(
               runtime,
               context_a(),
               erase_input(declared.control_id, 3)
             )

    assert {:ok, current} =
             TemporalQualification.get_current(runtime, context_a(), aggregate_id)

    assert current.revision_id == revision.revision_id
    assert Enum.map(current.segments, & &1.value) == ["[redacted]", "[redacted]"]
    receipt_id = erased.receipt_id

    assert {:ok, [[0, 4, 0, "erased", ^receipt_id]]} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 """
                 SELECT
                   (SELECT quantity FROM platform_temporal_qualification_facts
                    WHERE tenant_id = $1 AND scope_id = $2),
                   (SELECT count(*) FROM platform_temporal_qualification_retention_receipts
                    WHERE tenant_id = $1 AND control_id = $3),
                   (SELECT count(*) FROM platform_temporal_qualification_current_projections
                    WHERE tenant_id = $1 AND aggregate_id = $4),
                   (SELECT state FROM platform_temporal_qualification_retention_controls
                    WHERE tenant_id = $1 AND id = $3),
                   (SELECT current_receipt_id::text
                    FROM platform_temporal_qualification_retention_controls
                    WHERE tenant_id = $1 AND id = $3)
                 """,
                 [dump(@tenant_a), dump(scope_id), dump(declared.control_id), dump(aggregate_id)]
               ).rows
             end)

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.rebuild_current_projection(
               runtime,
               context_a(),
               %{aggregate_id: aggregate_id, module_key: @module_key}
             )

    assert_minimized_erasure_evidence(runtime)
  end

  test "retention replay, authority, tenant isolation, and racing hold fail closed", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    publish(runtime, context_a(), aggregate_id, UUID.generate())
    input = retention_input(aggregate_id)

    assert {:ok, first} = TemporalQualification.declare_retention(runtime, context_a(), input)
    assert {:ok, ^first} = TemporalQualification.declare_retention(runtime, context_a(), input)

    assert {:error, %TemporalQualificationError{code: :idempotency_conflict}} =
             TemporalQualification.declare_retention(
               runtime,
               context_a(),
               %{input | policy_key: "synthetic.changed_policy"}
             )

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.declare_retention(runtime, context_a_denied(), %{
               input
               | idempotency_key: UUID.generate()
             })

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             TemporalQualification.declare_retention(
               runtime,
               %{tenant_id: @tenant_a},
               %{input | idempotency_key: UUID.generate()}
             )

    assert {:error, %TemporalQualificationError{code: :not_found}} =
             TemporalQualification.place_legal_hold(
               runtime,
               context_b(),
               hold_input(first.control_id, 1, :crypto.hash(:sha256, "tenant-b"))
             )

    results =
      ["race-one", "race-two"]
      |> Enum.map(fn reference ->
        Task.async(fn ->
          TemporalQualification.place_legal_hold(
            runtime,
            context_a_peer(),
            hold_input(first.control_id, 1, :crypto.hash(:sha256, reference))
          )
        end)
      end)
      |> Enum.map(&Task.await(&1, 10_000))

    assert 1 == Enum.count(results, &match?({:ok, %RetentionResult{state: :held}}, &1))

    assert 1 ==
             Enum.count(
               results,
               &match?({:error, %TemporalQualificationError{code: :conflict}}, &1)
             )
  end

  test "database guards reject alternate retention, receipt, import, and redaction writes", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    revision = publish(runtime, context_a(), aggregate_id, UUID.generate())

    assert {:ok, retained} =
             TemporalQualification.declare_retention(
               runtime,
               context_a(),
               retention_input(aggregate_id)
             )

    assert_constraint(
      Persistence.with_writer(runtime, context_a(), fn ->
        Repo.query(
          """
          UPDATE platform_temporal_qualification_retention_controls
          SET state = 'erased', version = version + 1, erased_at = NOW()
          WHERE tenant_id = $1 AND id = $2
          """,
          [dump(@tenant_a), dump(retained.control_id)]
        )
      end),
      "platform_temporal_retention_control_transition_invalid"
    )

    assert_constraint(
      Persistence.with_writer(runtime, context_a(), fn ->
        Repo.query(
          "DELETE FROM platform_temporal_qualification_retention_receipts WHERE tenant_id = $1 AND id = $2",
          [dump(@tenant_a), dump(retained.receipt_id)]
        )
      end),
      "platform_temporal_retention_receipt_immutable"
    )

    assert {:ok, imported} =
             TemporalQualification.register_baseline_import(
               runtime,
               context_a(),
               import_input(aggregate_id, revision.revision_id)
             )

    assert_constraint(
      Persistence.with_writer(runtime, context_a(), fn ->
        Repo.query(
          "UPDATE platform_temporal_qualification_import_records SET mapping_revision = 'tampered' WHERE tenant_id = $1 AND id = $2",
          [dump(@tenant_a), dump(imported.record_id)]
        )
      end),
      "platform_temporal_import_record_immutable"
    )

    assert {:ok, %RetentionResult{state: :erased}} =
             TemporalQualification.erase_retained_content(
               runtime,
               context_a(),
               erase_input(retained.control_id, retained.version)
             )

    assert_constraint(
      Persistence.with_writer(runtime, context_a(), fn ->
        Repo.query(
          "UPDATE platform_temporal_qualification_segments SET value = 'restored' WHERE tenant_id = $1 AND aggregate_id = $2",
          [dump(@tenant_a), dump(aggregate_id)]
        )
      end),
      "platform_temporal_qualification_segment_immutable"
    )

    future_aggregate_id = UUID.generate()
    publish(runtime, context_a(), future_aggregate_id, UUID.generate())

    future_input = %{
      retention_input(future_aggregate_id)
      | retain_until: Date.add(Date.utc_today(), 30)
    }

    assert {:ok, future_retention} =
             TemporalQualification.declare_retention(runtime, context_a(), future_input)

    assert {:error, %TemporalQualificationError{code: :retention_conflict}} =
             TemporalQualification.erase_retained_content(
               runtime,
               context_a(),
               erase_input(future_retention.control_id, future_retention.version)
             )

    forged_receipt_id = UUID.generate()

    assert_constraint(
      Persistence.with_writer(runtime, context_a(), fn ->
        Repo.query(
          """
          WITH forged_receipt AS (
            INSERT INTO platform_temporal_qualification_retention_receipts (
              id, tenant_id, control_id, aggregate_id, scope_id, operation, version,
              reason_code, redacted_segment_count, redacted_fact_count,
              purged_projection_count, recorded_at
            )
            VALUES ($1, $2, $3, $4, $5, 'erased', 2,
                    'forged_early_erasure', 0, 0, 0, NOW())
            RETURNING id
          )
          UPDATE platform_temporal_qualification_retention_controls AS control
          SET state = 'erased', version = 2, current_receipt_id = $1,
              erased_at = NOW(), updated_at = NOW()
          FROM forged_receipt
          WHERE control.tenant_id = $2 AND control.id = $3
          """,
          [
            dump(forged_receipt_id),
            dump(@tenant_a),
            dump(future_retention.control_id),
            dump(future_aggregate_id),
            dump(future_retention.scope_id)
          ]
        )
      end),
      "platform_temporal_retention_control_transition_invalid"
    )
  end

  test "baseline import records provenance and conflicts require explicit reconciliation", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    revision = publish(runtime, context_a(), aggregate_id, UUID.generate())
    snapshot_digest = :crypto.hash(:sha256, "source-snapshot-v1")
    identifier_digest = :crypto.hash(:sha256, "source-id-7")

    baseline_input =
      import_input(aggregate_id, revision.revision_id, snapshot_digest, identifier_digest)

    assert {:ok, %ImportResult{state: :baseline, version: 1} = baseline} =
             TemporalQualification.register_baseline_import(runtime, context_a(), baseline_input)

    assert {:ok, ^baseline} =
             TemporalQualification.register_baseline_import(runtime, context_a(), baseline_input)

    conflict_input = conflict_input(:crypto.hash(:sha256, "source-id-conflict"))

    assert {:ok, %ImportResult{state: :reconciliation_required} = conflict} =
             TemporalQualification.register_import_conflict(
               runtime,
               context_a(),
               conflict_input
             )

    assert is_nil(conflict.aggregate_id)
    assert is_nil(conflict.revision_id)

    assert {:error, %TemporalQualificationError{code: :conflict}} =
             TemporalQualification.reconcile_import_conflict(
               runtime,
               context_a(),
               reconcile_input(
                 conflict.import_id,
                 UUID.generate(),
                 aggregate_id,
                 revision.revision_id
               )
             )

    reconcile =
      reconcile_input(conflict.import_id, conflict.record_id, aggregate_id, revision.revision_id)

    assert {:ok,
            %ImportResult{
              state: :reconciled,
              version: 2,
              predecessor_record_id: predecessor
            }} = TemporalQualification.reconcile_import_conflict(runtime, context_a(), reconcile)

    assert predecessor == conflict.record_id

    duplicate_source = %{
      baseline_input
      | import_id: UUID.generate(),
        idempotency_key: UUID.generate()
    }

    assert {:error, %TemporalQualificationError{code: :conflict}} =
             TemporalQualification.register_baseline_import(
               runtime,
               context_a(),
               duplicate_source
             )

    assert {:ok, [[32, 32, 1, 2]]} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 """
                 SELECT min(octet_length(source_snapshot_digest)),
                        min(octet_length(source_identifier_digest)),
                        count(*) FILTER (WHERE state = 'baseline'),
                        count(*) FILTER (WHERE import_id = $2)
                 FROM platform_temporal_qualification_import_records
                 WHERE tenant_id = $1
                 """,
                 [dump(@tenant_a), dump(conflict.import_id)]
               ).rows
             end)

    deactivate_module(runtime, context_a(), @tenant_a)

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.register_import_conflict(runtime, context_a(), %{
               conflict_input
               | import_id: UUID.generate(),
                 source_identifier_digest: :crypto.hash(:sha256, "inactive-source"),
                 idempotency_key: UUID.generate()
             })
  end

  test "projection rebuild converges after correction and remains disposable", %{runtime: runtime} do
    aggregate_id = UUID.generate()
    revision = publish(runtime, context_a(), aggregate_id, UUID.generate())

    assert {:ok, %RetentionResult{}} =
             TemporalQualification.declare_retention(
               runtime,
               context_a(),
               retention_input(aggregate_id)
             )

    assert {:ok, %ProjectionResult{projection_version: 1, converged: true}} =
             TemporalQualification.rebuild_current_projection(
               runtime,
               context_a(),
               %{aggregate_id: aggregate_id, module_key: @module_key}
             )

    assert {:ok, corrected} =
             TemporalQualification.correct_revision(
               runtime,
               context_a(),
               correction_input(aggregate_id, revision.revision_id)
             )

    assert {:ok, [[old_revision, current_revision]]} =
             projection_and_current(runtime, aggregate_id)

    assert old_revision == revision.revision_id
    assert current_revision == corrected.revision_id

    assert {:ok,
            %ProjectionResult{
              projection_version: 2,
              revision_id: corrected_revision,
              converged: true
            }} =
             TemporalQualification.rebuild_current_projection(
               runtime,
               context_a(),
               %{aggregate_id: aggregate_id, module_key: @module_key}
             )

    assert corrected_revision == corrected.revision_id
  end

  test "recovery fixture preserves correction, provenance, erasure, and projection invariants", %{
    runtime: runtime
  } do
    projected_aggregate_id = UUID.generate()
    projected = publish(runtime, context_a(), projected_aggregate_id, UUID.generate())

    assert {:ok, corrected} =
             TemporalQualification.correct_revision(
               runtime,
               context_a(),
               correction_input(projected_aggregate_id, projected.revision_id)
             )

    assert {:ok, %RetentionResult{}} =
             TemporalQualification.declare_retention(
               runtime,
               context_a(),
               retention_input(projected_aggregate_id)
             )

    assert {:ok, %ImportResult{}} =
             TemporalQualification.register_baseline_import(
               runtime,
               context_a(),
               import_input(projected_aggregate_id, corrected.revision_id)
             )

    assert {:ok, %ProjectionResult{converged: true}} =
             TemporalQualification.rebuild_current_projection(
               runtime,
               context_a(),
               %{aggregate_id: projected_aggregate_id, module_key: @module_key}
             )

    erased_aggregate_id = UUID.generate()
    erased_scope_id = UUID.generate()
    _erased = publish(runtime, context_a(), erased_aggregate_id, erased_scope_id)
    _fact = record_fact(runtime, context_a(), erased_scope_id)

    assert {:ok, retained} =
             TemporalQualification.declare_retention(
               runtime,
               context_a(),
               retention_input(erased_aggregate_id)
             )

    assert {:ok, %RetentionResult{state: :erased}} =
             TemporalQualification.erase_retained_content(
               runtime,
               context_a(),
               erase_input(retained.control_id, retained.version)
             )

    assert {:ok, [[2, 3, 5, 1, 1, 2, 3, 1, 2, 1, 0, 0, 0]]} =
             recovery_manifest(runtime)
  end

  test "late completion failure rolls back retention and import state with all evidence", %{
    runtime: runtime
  } do
    aggregate_id = UUID.generate()
    revision = publish(runtime, context_a(), aggregate_id, UUID.generate())
    retention = retention_input(aggregate_id)
    import = import_input(aggregate_id, revision.revision_id)
    install_completion_failure(runtime)

    try do
      assert {:error, %TemporalQualificationError{code: :retryable_dependency}} =
               TemporalQualification.declare_retention(runtime, context_a(), retention)

      assert {:error, %TemporalQualificationError{code: :retryable_dependency}} =
               TemporalQualification.register_baseline_import(runtime, context_a(), import)

      assert {:ok, [[0, 0, 0, 0, 0]]} = completion_counts(runtime)
    after
      remove_completion_failure(runtime)
    end

    assert {:ok, %RetentionResult{}} =
             TemporalQualification.declare_retention(runtime, context_a(), retention)

    assert {:ok, %ImportResult{}} =
             TemporalQualification.register_baseline_import(runtime, context_a(), import)
  end

  defp seed_tenant(runtime, context, tenant_id, granted_actors, denied_actor) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               role_id = UUID.generate()
               insert_role(role_id, tenant_id)

               Enum.each(granted_actors, fn actor_id ->
                 membership_id = UUID.generate()
                 insert_membership(membership_id, tenant_id, actor_id)
                 insert_assignment(tenant_id, membership_id, role_id)
               end)

               if denied_actor do
                 insert_membership(UUID.generate(), tenant_id, denied_actor)
               end

               Enum.each(@capabilities, fn key ->
                 capability_id = UUID.generate()
                 insert_capability(capability_id, tenant_id, key)
                 insert_grant(tenant_id, role_id, capability_id)
               end)

               entitlement_id = UUID.generate()
               insert_module(entitlement_id, tenant_id)
               :seeded
             end)
  end

  defp insert_module(entitlement_id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_module_entitlements (id, tenant_id, module_key, inserted_at)
      VALUES ($1, $2, $3, NOW())
      """,
      [dump(entitlement_id), dump(tenant_id), @module_key]
    )

    Repo.query!(
      """
      INSERT INTO platform_module_activations (
        id, tenant_id, entitlement_id, module_version, state, lock_version,
        activated_at, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, '1.0.0', 'active', 1, NOW(), NOW(), NOW())
      """,
      [dump(UUID.generate()), dump(tenant_id), dump(entitlement_id)]
    )
  end

  defp deactivate_module(runtime, context, tenant_id) do
    assert {:ok, %{num_rows: 1}} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_module_activations
                 SET state = 'inactive', deactivated_at = NOW(), replay_from_cursor = 0,
                     projection_ready = false, reconciliation_required = true,
                     lock_version = lock_version + 1, updated_at = NOW()
                 WHERE tenant_id = $1
                 """,
                 [dump(tenant_id)]
               )
             end)
  end

  defp publish(runtime, context, aggregate_id, scope_id) do
    assert {:ok, result} =
             TemporalQualification.publish_revision(runtime, context, %{
               aggregate_id: aggregate_id,
               scope_id: scope_id,
               reason_code: "synthetic_baseline",
               segments: [
                 %{
                   effective_from: ~D[2024-01-01],
                   effective_until: ~D[2025-01-01],
                   value: "alpha"
                 },
                 %{effective_from: ~D[2025-01-01], effective_until: ~D[2026-01-01], value: "beta"}
               ],
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    result
  end

  defp record_fact(runtime, context, scope_id) do
    assert {:ok, result} =
             TemporalQualification.record_fact_entry(runtime, context, %{
               scope_id: scope_id,
               effective_on: ~D[2025-01-01],
               quantity: 9,
               reason_code: "synthetic_entry",
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    result
  end

  defp retention_input(aggregate_id) do
    %{
      aggregate_id: aggregate_id,
      module_key: @module_key,
      policy_key: "synthetic.temporal_policy",
      classification: :restricted,
      retention_started_on: ~D[2024-01-01],
      retain_until: Date.add(Date.utc_today(), -1),
      reason_code: "synthetic_retention",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp hold_input(control_id, expected_version, digest) do
    %{
      control_id: control_id,
      expected_version: expected_version,
      hold_reference_digest: digest,
      reason_code: "synthetic_legal_hold",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp erase_input(control_id, expected_version) do
    %{
      control_id: control_id,
      expected_version: expected_version,
      reason_code: "synthetic_erasure",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp import_input(
         aggregate_id,
         revision_id,
         snapshot_digest \\ :crypto.hash(:sha256, "snapshot"),
         identifier_digest \\ :crypto.hash(:sha256, "source-id")
       ) do
    %{
      import_id: UUID.generate(),
      module_key: @module_key,
      source_snapshot_digest: snapshot_digest,
      source_identifier_digest: identifier_digest,
      mapping_revision: "mapping-v1",
      aggregate_id: aggregate_id,
      revision_id: revision_id,
      reason_code: "synthetic_import",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp conflict_input(identifier_digest) do
    %{
      import_id: UUID.generate(),
      module_key: @module_key,
      source_snapshot_digest: :crypto.hash(:sha256, "conflict-snapshot"),
      source_identifier_digest: identifier_digest,
      mapping_revision: "mapping-v1",
      conflict_code: "missing_predecessor",
      reason_code: "synthetic_conflict",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp reconcile_input(import_id, expected_record_id, aggregate_id, revision_id) do
    %{
      import_id: import_id,
      expected_record_id: expected_record_id,
      module_key: @module_key,
      aggregate_id: aggregate_id,
      revision_id: revision_id,
      reason_code: "synthetic_reconciliation",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp correction_input(aggregate_id, expected_revision_id) do
    %{
      aggregate_id: aggregate_id,
      expected_revision_id: expected_revision_id,
      reason_code: "synthetic_correction",
      segments: [
        %{effective_from: ~D[2024-01-01], effective_until: ~D[2026-01-01], value: "corrected"}
      ],
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp projection_and_current(runtime, aggregate_id) do
    Persistence.with_writer(runtime, context_a(), fn ->
      Repo.query!(
        """
        SELECT projection.revision_id::text, aggregate.current_revision_id::text
        FROM platform_temporal_qualification_current_projections AS projection
        JOIN platform_temporal_qualification_aggregates AS aggregate
          ON aggregate.tenant_id = projection.tenant_id
         AND aggregate.id = projection.aggregate_id
        WHERE projection.tenant_id = $1 AND projection.aggregate_id = $2
        """,
        [dump(@tenant_a), dump(aggregate_id)]
      ).rows
    end)
  end

  defp assert_minimized_erasure_evidence(runtime) do
    assert {:ok, [[false, false]]} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 """
                 SELECT
                   EXISTS (
                     SELECT 1 FROM platform_authority_audit_events
                     WHERE tenant_id = $1 AND change_summary::text LIKE '%alpha%'
                   ),
                   EXISTS (
                     SELECT 1 FROM platform_outbox_events
                     WHERE tenant_id = $1 AND payload::text LIKE '%alpha%'
                   )
                 """,
                 [dump(@tenant_a)]
               ).rows
             end)
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("""
               CREATE FUNCTION test_fail_temporal_completion()
               RETURNS trigger LANGUAGE plpgsql AS $$
               BEGIN
                 IF NEW.status = 'completed' AND NEW.aggregate_type IN (
                   'platform.temporal_qualification.retention',
                   'platform.temporal_qualification.import'
                 ) THEN
                   RAISE EXCEPTION USING ERRCODE = '40001',
                     MESSAGE = 'synthetic temporal completion failure';
                 END IF;
                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_temporal_completion
               BEFORE UPDATE OF status ON platform_authority_action_idempotency
               FOR EACH ROW EXECUTE FUNCTION test_fail_temporal_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_temporal_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_temporal_completion()")
               :removed
             end)
  end

  defp completion_counts(runtime) do
    Persistence.with_writer(runtime, context_a(), fn ->
      Repo.query!("""
      SELECT
        (SELECT count(*) FROM platform_temporal_qualification_retention_controls),
        (SELECT count(*) FROM platform_temporal_qualification_retention_receipts),
        (SELECT count(*) FROM platform_temporal_qualification_import_records),
        (SELECT count(*) FROM platform_authority_audit_events
         WHERE aggregate_type IN ('platform.temporal_qualification.retention', 'platform.temporal_qualification.import')),
        (SELECT count(*) FROM platform_outbox_events
         WHERE aggregate_type IN ('platform.temporal_qualification.retention', 'platform.temporal_qualification.import'))
      """).rows
    end)
  end

  defp recovery_manifest(runtime) do
    Persistence.with_writer(runtime, context_a(), fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_temporal_qualification_aggregates WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_revisions WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_segments WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_facts WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_current_projections WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_retention_controls WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_retention_receipts WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_import_records WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_temporal_qualification_segments
           WHERE tenant_id = $1 AND redacted_at IS NOT NULL),
          (SELECT count(*) FROM platform_temporal_qualification_facts
           WHERE tenant_id = $1 AND redacted_at IS NOT NULL),
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
             ))
        """,
        [dump(@tenant_a)]
      ).rows
    end)
  end

  defp assert_constraint(
         {:ok, {:error, %Postgrex.Error{postgres: %{constraint: actual}}}},
         expected
       ) do
    assert to_string(actual) == expected
  end

  defp insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      "INSERT INTO platform_tenant_memberships (id, tenant_id, actor_id, inserted_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  defp insert_role(id, tenant_id) do
    Repo.query!(
      "INSERT INTO platform_roles (id, tenant_id, name, lock_version, inserted_at, updated_at) VALUES ($1, $2, 'Temporal completion operator', 1, NOW(), NOW())",
      [dump(id), dump(tenant_id)]
    )
  end

  defp insert_capability(id, tenant_id, key) do
    Repo.query!(
      "INSERT INTO platform_capabilities (id, tenant_id, key, inserted_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
      [dump(id), dump(tenant_id), key]
    )
  end

  defp insert_assignment(tenant_id, membership_id, role_id) do
    Repo.query!(
      "INSERT INTO platform_actor_role_assignments (id, tenant_id, membership_id, role_id, inserted_at) VALUES ($1, $2, $3, $4, NOW())",
      Enum.map([UUID.generate(), tenant_id, membership_id, role_id], &dump/1)
    )
  end

  defp insert_grant(tenant_id, role_id, capability_id) do
    Repo.query!(
      "INSERT INTO platform_role_capability_grants (id, tenant_id, role_id, capability_id, inserted_at) VALUES ($1, $2, $3, $4, NOW())",
      Enum.map([UUID.generate(), tenant_id, role_id, capability_id], &dump/1)
    )
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 6]],
      placements: [
        placement(@tenant_a, "pooled-temporal-completion", :pooled),
        placement(@tenant_b, "pooled-temporal-completion", :pooled)
      ],
      per_tenant_limit: 6,
      per_placement_limit: 12
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
  defp context_a_peer, do: context(@actor_a_peer, @tenant_a)
  defp context_a_denied, do: context(@actor_a_denied, @tenant_a)
  defp context_b, do: context(@actor_b, @tenant_b)

  defp context(actor_id, tenant_id) do
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
        correlation_id: UUID.generate(),
        purpose: "platform.temporal_qualification.completion",
        locale: "en"
      )

    context
  end

  defp dump(value), do: UUID.dump!(value)
end
