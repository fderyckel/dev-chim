defmodule Chimwemwe.Platform.TemporalQualificationActionTest do
  use ExUnit.Case, async: false

  alias Ash.Resource.Info, as: ResourceInfo

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

  alias Chimwemwe.Platform.TemporalQualification.{
    Aggregate,
    ConsumerHistoryView,
    ConsumerResult,
    FactHistoryView,
    FactOperationResult,
    FactView,
    HistoryView,
    RevisionResult,
    RevisionView
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_a_peer "abababab-abab-4bab-8bab-abababababab"
  @actor_a_current "acacacac-acac-4cac-8cac-acacacacacac"
  @actor_a_denied "adadadad-adad-4dad-8dad-adadadadadad"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

  @publish_capability "platform.temporal_qualification.revisions.publish"
  @correct_capability "platform.temporal_qualification.revisions.correct"
  @current_capability "platform.temporal_qualification.revisions.read_current"
  @history_capability "platform.temporal_qualification.revisions.read_history"
  @fact_record_capability "platform.temporal_qualification.facts.record"
  @fact_correct_capability "platform.temporal_qualification.facts.reverse_and_replace"
  @fact_read_capability "platform.temporal_qualification.facts.read_history"
  @consumer_pin_capability "platform.temporal_qualification.consumers.pin"
  @consumer_reconcile_capability "platform.temporal_qualification.consumers.reconcile"
  @consumer_read_capability "platform.temporal_qualification.consumers.read_history"

  @tables [
    "platform_temporal_qualification_consumer_bases",
    "platform_temporal_qualification_segments",
    "platform_temporal_qualification_revisions",
    "platform_temporal_qualification_facts",
    "platform_temporal_qualification_fact_operations",
    "platform_temporal_qualification_aggregates",
    "platform_authority_action_idempotency",
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

    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("TRUNCATE " <> Enum.join(@tables, ", "))
               :cleared
             end)

    seed_authority(runtime)
    {:ok, runtime: runtime}
  end

  test "keeps both revision actions private and exposes no generic mutation", %{runtime: runtime} do
    for action_name <- [:publish_revision, :correct_revision] do
      action = ResourceInfo.action(Aggregate, action_name)
      assert action.type == :action
      refute action.public?
      assert action.transaction?
    end

    assert Code.ensure_loaded?(TemporalQualification)
    assert function_exported?(TemporalQualification, :publish_revision, 3)
    assert function_exported?(TemporalQualification, :correct_revision, 3)
    refute function_exported?(TemporalQualification, :mutate, 4)

    aggregate_id = UUID.generate()

    assert {:ok, %RevisionResult{aggregate_revision: 1}} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id)
             )
  end

  test "publishes one complete revision and serves named current, exact, effective, and history reads",
       %{runtime: runtime} do
    aggregate_id = UUID.generate()
    idempotency_key = UUID.generate()
    before_insert = DateTime.utc_now() |> DateTime.add(-5, :second) |> DateTime.to_naive()

    assert {:ok, %RevisionResult{} = result} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id, idempotency_key)
             )

    assert result.aggregate_id == aggregate_id
    assert result.aggregate_revision == 1
    assert is_nil(result.predecessor_revision_id)
    assert length(result.segments) == 2
    assert NaiveDateTime.compare(result.recorded_at, before_insert) in [:gt, :eq]

    assert {:ok, %RevisionView{} = current} =
             TemporalQualification.get_current(runtime, context_a(), aggregate_id)

    assert current.revision_id == result.revision_id
    assert Enum.map(current.segments, & &1.value) == ["alpha", "beta"]

    assert {:ok, %RevisionView{} = exact} =
             TemporalQualification.get_revision(runtime, context_a(), result.revision_id)

    comparable_fields = [
      :aggregate_id,
      :revision_id,
      :operation_id,
      :aggregate_revision,
      :predecessor_revision_id,
      :reason_code,
      :recorded_at,
      :segments
    ]

    assert Map.take(Map.from_struct(exact), comparable_fields) ==
             Map.take(Map.from_struct(result), comparable_fields)

    assert {:ok, %RevisionView{segments: [effective]}} =
             TemporalQualification.get_effective(
               runtime,
               context_a(),
               aggregate_id,
               ~D[2026-08-01]
             )

    assert effective.value == "beta"

    assert {:ok, %HistoryView{revisions: [history_revision], truncated?: false}} =
             TemporalQualification.list_history(runtime, context_a(), aggregate_id)

    assert history_revision.revision_id == result.revision_id

    assert {:ok,
            [
              [
                "platform.temporal_qualification.revision.publish",
                0,
                1,
                audit_summary,
                "platform.temporal_qualification.revision.published",
                event_payload,
                "completed",
                claim_payload
              ]
            ]} = read_evidence(runtime, context_a(), result, idempotency_key)

    assert audit_summary["purpose"] == "platform.temporal_qualification"
    assert audit_summary["segment_count"] == 2
    assert event_payload["revision_id"] == result.revision_id
    assert event_payload["segment_count"] == 2
    refute Map.has_key?(event_payload, "segments")
    refute Map.has_key?(event_payload, "value")
    assert claim_payload["revision_id"] == result.revision_id
    assert length(claim_payload["segments"]) == 2
  end

  test "replays the exact result and rejects changed request or actor while isolating tenants",
       %{runtime: runtime} do
    aggregate_a = UUID.generate()
    aggregate_b = UUID.generate()
    idempotency_key = UUID.generate()
    input = publish_input(aggregate_a, idempotency_key)

    assert {:ok, first} =
             TemporalQualification.publish_revision(runtime, context_a(), input)

    assert {:ok, second} =
             TemporalQualification.publish_revision(runtime, context_a(), input)

    assert first == second

    concurrent_aggregate = UUID.generate()
    concurrent_input = publish_input(concurrent_aggregate)

    concurrent_results =
      1..2
      |> Enum.map(fn _index ->
        Task.async(fn ->
          TemporalQualification.publish_revision(runtime, context_a(), concurrent_input)
        end)
      end)
      |> Enum.map(&Task.await(&1, 10_000))

    assert [{:ok, concurrent_first}, {:ok, concurrent_second}] = concurrent_results
    assert concurrent_first == concurrent_second

    assert {:error, %TemporalQualificationError{code: :idempotency_conflict}} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               %{input | reason_code: "changed_request"}
             )

    assert {:error, %TemporalQualificationError{code: :idempotency_conflict}} =
             TemporalQualification.publish_revision(runtime, context_a_peer(), input)

    assert {:ok, %RevisionResult{aggregate_id: ^aggregate_b}} =
             TemporalQualification.publish_revision(
               runtime,
               context_b(),
               publish_input(aggregate_b, idempotency_key)
             )

    assert {:ok, [[1, 1, 2, 1, 1, 1]]} =
             qualification_counts(runtime, context_a(), aggregate_a)

    assert {:ok, [[1, 1, 2, 1, 1, 1]]} =
             qualification_counts(runtime, context_b(), aggregate_b)
  end

  test "corrects only the exact current revision and separates current from history authority",
       %{runtime: runtime} do
    aggregate_id = UUID.generate()

    assert {:ok, revision_1} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id)
             )

    correction_input = correct_input(aggregate_id, revision_1.revision_id)

    assert {:ok, %RevisionResult{} = revision_2} =
             TemporalQualification.correct_revision(
               runtime,
               context_a(),
               correction_input
             )

    assert {:ok, ^revision_2} =
             TemporalQualification.correct_revision(runtime, context_a(), correction_input)

    assert {:error, %TemporalQualificationError{code: :idempotency_conflict}} =
             TemporalQualification.correct_revision(
               runtime,
               context_a(),
               %{correction_input | reason_code: "changed_correction"}
             )

    assert revision_2.aggregate_revision == 2
    assert revision_2.predecessor_revision_id == revision_1.revision_id

    assert {:ok, %RevisionView{revision_id: current_id}} =
             TemporalQualification.get_current(runtime, context_a_current(), aggregate_id)

    assert current_id == revision_2.revision_id

    assert {:ok, %RevisionView{revision_id: first_id}} =
             TemporalQualification.get_revision(runtime, context_a(), revision_1.revision_id)

    assert first_id == revision_1.revision_id

    assert {:ok, %HistoryView{revisions: history}} =
             TemporalQualification.list_history(runtime, context_a(), aggregate_id)

    assert Enum.map(history, & &1.revision_id) == [revision_1.revision_id, revision_2.revision_id]

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.get_revision(
               runtime,
               context_a_current(),
               revision_1.revision_id
             )

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.list_history(runtime, context_a_current(), aggregate_id)

    assert {:error, %TemporalQualificationError{code: :unsupported_query}} =
             TemporalQualification.get_as_known(
               runtime,
               context_a(),
               aggregate_id,
               ~D[2026-01-01],
               DateTime.utc_now()
             )

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.get_as_known(
               runtime,
               context_a_current(),
               aggregate_id,
               ~D[2026-01-01],
               DateTime.utc_now()
             )

    assert {:error, %TemporalQualificationError{code: :conflict}} =
             TemporalQualification.correct_revision(
               runtime,
               context_a(),
               correct_input(aggregate_id, revision_1.revision_id)
             )
  end

  test "serializes racing corrections and creates no branch", %{runtime: runtime} do
    aggregate_id = UUID.generate()

    assert {:ok, baseline} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id)
             )

    parent = self()

    tasks =
      for value <- ["first_correction", "second_correction"] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              TemporalQualification.correct_revision(
                runtime,
                context_a(),
                correct_input(aggregate_id, baseline.revision_id, value)
              )
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

    assert 1 == Enum.count(results, &match?({:ok, %RevisionResult{}}, &1))

    assert 1 ==
             Enum.count(results, fn
               {:error, %TemporalQualificationError{code: :conflict}} -> true
               _other -> false
             end)

    assert {:ok, [[1, 2, 3, 2, 2, 2]]} =
             qualification_counts(runtime, context_a(), aggregate_id)
  end

  test "fails closed for missing capability, context, disclosure, and invalid intervals",
       %{runtime: runtime} do
    aggregate_id = UUID.generate()

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.publish_revision(
               runtime,
               context_a_denied(),
               publish_input(aggregate_id)
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             TemporalQualification.publish_revision(
               runtime,
               %{tenant_id: @tenant_a},
               publish_input(aggregate_id)
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             TemporalQualification.get_current(runtime, %{tenant_id: @tenant_a}, aggregate_id)

    overlapping =
      publish_input(aggregate_id)
      |> Map.put(:segments, [
        segment(~D[2026-01-01], ~D[2026-08-01], "first"),
        segment(~D[2026-04-01], ~D[2027-01-01], "second")
      ])

    assert {:error, %TemporalQualificationError{code: :effective_time_conflict}} =
             TemporalQualification.publish_revision(runtime, context_a(), overlapping)

    assert {:ok, [[0, 0, 0, 0, 0, 0]]} =
             qualification_counts(runtime, context_a(), aggregate_id)

    assert {:ok, published} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id)
             )

    assert {:error, %TemporalQualificationError{code: :not_found}} =
             TemporalQualification.get_current(runtime, context_b(), aggregate_id)

    assert {:error, %TemporalQualificationError{code: :not_found}} =
             TemporalQualification.get_revision(runtime, context_b(), published.revision_id)

    assert {:error, %TemporalQualificationError{code: :not_found}} =
             TemporalQualification.correct_revision(
               runtime,
               context_b(),
               correct_input(aggregate_id, published.revision_id)
             )

    assert {:error, %TemporalQualificationError{code: :invalid_input}} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               Map.put(publish_input(UUID.generate()), :tenant_id, @tenant_a)
             )
  end

  test "rolls back aggregate, revision, segments, audit, outbox, and claim after post-outbox failure",
       %{runtime: runtime} do
    aggregate_id = UUID.generate()
    input = publish_input(aggregate_id)
    install_completion_failure(runtime)

    try do
      assert {:error, %TemporalQualificationError{code: :retryable_dependency}} =
               TemporalQualification.publish_revision(runtime, context_a(), input)

      assert {:ok, [[0, 0, 0, 0, 0, 0]]} =
               qualification_counts(runtime, context_a(), aggregate_id)
    after
      remove_completion_failure(runtime)
    end

    assert {:ok, %RevisionResult{aggregate_revision: 1}} =
             TemporalQualification.publish_revision(runtime, context_a(), input)

    assert {:ok, [[1, 1, 2, 1, 1, 1]]} =
             qualification_counts(runtime, context_a(), aggregate_id)
  end

  test "records and reads an append-only fact operation with exact replay and redacted event evidence",
       %{runtime: runtime} do
    scope_id = UUID.generate()
    idempotency_key = UUID.generate()
    input = fact_input(scope_id, idempotency_key)

    assert {:ok, %FactOperationResult{} = first} =
             TemporalQualification.record_fact_entry(runtime, context_a(), input)

    assert {:ok, ^first} =
             TemporalQualification.record_fact_entry(runtime, context_a(), input)

    assert first.operation.kind == :record
    assert [%FactView{kind: :entry, quantity: 10} = entry] = first.operation.facts

    assert {:ok, ^entry} =
             TemporalQualification.get_fact(runtime, context_a(), entry.id)

    assert {:ok, operation} =
             TemporalQualification.get_fact_operation(
               runtime,
               context_a(),
               first.operation.operation_id
             )

    assert operation == first.operation

    assert {:ok, %FactHistoryView{operations: [^operation], truncated?: false}} =
             TemporalQualification.list_fact_history(runtime, context_a(), scope_id)

    assert {:ok, [[action_name, event_payload, result_payload]]} =
             fact_evidence(runtime, first, idempotency_key)

    assert action_name == "platform.temporal_qualification.fact.record"
    assert event_payload["fact_ids"] == [entry.id]
    refute Map.has_key?(event_payload, "quantity")
    refute Map.has_key?(event_payload, "effective_on")
    assert hd(result_payload["facts"])["quantity"] == 10

    assert {:error, %TemporalQualificationError{code: :idempotency_conflict}} =
             TemporalQualification.record_fact_entry(
               runtime,
               context_a(),
               %{input | quantity: 11}
             )

    assert {:error, %TemporalQualificationError{code: :idempotency_conflict}} =
             TemporalQualification.record_fact_entry(runtime, context_a_peer(), input)

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.record_fact_entry(runtime, context_a_denied(), input)

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             TemporalQualification.record_fact_entry(runtime, %{tenant_id: @tenant_a}, input)

    assert {:error, %TemporalQualificationError{code: :not_found}} =
             TemporalQualification.get_fact(runtime, context_b(), entry.id)

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.get_fact(runtime, context_a_current(), entry.id)
  end

  test "reverses and replaces exactly once while racing corrections create no branch",
       %{runtime: runtime} do
    assert {:ok, original} =
             TemporalQualification.record_fact_entry(
               runtime,
               context_a(),
               fact_input(UUID.generate())
             )

    [target] = original.operation.facts
    correction = fact_correction_input(target.id, 12)

    assert {:ok, %FactOperationResult{} = corrected} =
             TemporalQualification.reverse_and_replace_fact(
               runtime,
               context_a(),
               correction
             )

    assert {:ok, ^corrected} =
             TemporalQualification.reverse_and_replace_fact(
               runtime,
               context_a(),
               correction
             )

    assert [reversal, replacement] = corrected.operation.facts
    assert reversal.kind == :reversal
    assert reversal.reverses_fact_id == target.id
    assert reversal.quantity == -10
    assert replacement.kind == :entry
    assert replacement.quantity == 12

    assert {:ok, %FactHistoryView{operations: operations}} =
             TemporalQualification.list_fact_history(
               runtime,
               context_a(),
               original.operation.scope_id
             )

    assert Enum.map(operations, & &1.kind) == [:record, :reverse_and_replace]

    assert {:ok, racing_original} =
             TemporalQualification.record_fact_entry(
               runtime,
               context_a(),
               fact_input(UUID.generate())
             )

    [racing_target] = racing_original.operation.facts
    parent = self()

    tasks =
      for quantity <- [20, 30] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              TemporalQualification.reverse_and_replace_fact(
                runtime,
                context_a(),
                fact_correction_input(racing_target.id, quantity)
              )
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

    assert 1 == Enum.count(results, &match?({:ok, %FactOperationResult{}}, &1))

    assert 1 ==
             Enum.count(results, fn
               {:error, %TemporalQualificationError{code: :conflict}} -> true
               _other -> false
             end)

    assert {:error, %TemporalQualificationError{code: :not_found}} =
             TemporalQualification.reverse_and_replace_fact(
               runtime,
               context_b(),
               fact_correction_input(target.id, 14)
             )
  end

  test "keeps a consumer pinned until a separately authorized reconciliation",
       %{runtime: runtime} do
    aggregate_id = UUID.generate()
    consumer_id = UUID.generate()

    assert {:ok, revision_1} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id)
             )

    pin_input = consumer_pin_input(consumer_id, aggregate_id, revision_1.revision_id)

    assert {:ok, %ConsumerResult{} = pinned} =
             TemporalQualification.pin_consumer_revision(runtime, context_a(), pin_input)

    assert {:ok, ^pinned} =
             TemporalQualification.pin_consumer_revision(runtime, context_a(), pin_input)

    assert pinned.basis.basis_version == 1

    assert {:ok, revision_2} =
             TemporalQualification.correct_revision(
               runtime,
               context_a(),
               correct_input(aggregate_id, revision_1.revision_id)
             )

    assert {:ok, still_pinned} =
             TemporalQualification.get_consumer_current(runtime, context_a(), consumer_id)

    assert still_pinned.revision_id == revision_1.revision_id

    reconcile_input =
      consumer_reconcile_input(
        consumer_id,
        pinned.basis.basis_id,
        revision_2.revision_id,
        revision_2.event_id
      )

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.reconcile_consumer_revision(
               runtime,
               context_a_denied(),
               reconcile_input
             )

    assert {:ok, still_pinned} ==
             TemporalQualification.get_consumer_current(runtime, context_a(), consumer_id)

    assert {:ok, %ConsumerResult{} = reconciled} =
             TemporalQualification.reconcile_consumer_revision(
               runtime,
               context_a(),
               reconcile_input
             )

    assert reconciled.basis.basis_version == 2
    assert reconciled.basis.predecessor_basis_id == pinned.basis.basis_id
    assert reconciled.basis.revision_id == revision_2.revision_id

    assert {:ok, %ConsumerHistoryView{bases: [basis_1, basis_2], truncated?: false}} =
             TemporalQualification.list_consumer_history(runtime, context_a(), consumer_id)

    assert basis_1 == pinned.basis
    assert basis_2 == reconciled.basis

    assert {:error, %TemporalQualificationError{code: :forbidden}} =
             TemporalQualification.get_consumer_current(
               runtime,
               context_a_current(),
               consumer_id
             )

    assert {:error, %TemporalQualificationError{code: :not_found}} =
             TemporalQualification.get_consumer_current(runtime, context_b(), consumer_id)
  end

  test "serializes racing reconciliation from one exact consumer basis", %{runtime: runtime} do
    aggregate_id = UUID.generate()
    consumer_id = UUID.generate()

    assert {:ok, revision_1} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id)
             )

    assert {:ok, pinned} =
             TemporalQualification.pin_consumer_revision(
               runtime,
               context_a(),
               consumer_pin_input(consumer_id, aggregate_id, revision_1.revision_id)
             )

    assert {:ok, revision_2} =
             TemporalQualification.correct_revision(
               runtime,
               context_a(),
               correct_input(aggregate_id, revision_1.revision_id)
             )

    parent = self()

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              TemporalQualification.reconcile_consumer_revision(
                runtime,
                context_a(),
                consumer_reconcile_input(
                  consumer_id,
                  pinned.basis.basis_id,
                  revision_2.revision_id,
                  revision_2.event_id
                )
              )
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

    assert 1 == Enum.count(results, &match?({:ok, %ConsumerResult{}}, &1))

    assert 1 ==
             Enum.count(results, fn
               {:error, %TemporalQualificationError{code: :conflict}} -> true
               _other -> false
             end)

    assert {:ok, %ConsumerHistoryView{bases: [basis_1, basis_2]}} =
             TemporalQualification.list_consumer_history(runtime, context_a(), consumer_id)

    assert basis_1.basis_id == pinned.basis.basis_id
    assert basis_2.predecessor_basis_id == basis_1.basis_id
    assert basis_2.revision_id == revision_2.revision_id
  end

  test "rolls back fact and consumer state with durable evidence after a late failure",
       %{runtime: runtime} do
    aggregate_id = UUID.generate()

    assert {:ok, revision} =
             TemporalQualification.publish_revision(
               runtime,
               context_a(),
               publish_input(aggregate_id)
             )

    scope_id = UUID.generate()
    consumer_id = UUID.generate()
    fact_input = fact_input(scope_id)
    pin_input = consumer_pin_input(consumer_id, aggregate_id, revision.revision_id)
    install_t1c_completion_failure(runtime)

    try do
      assert {:error, %TemporalQualificationError{code: :retryable_dependency}} =
               TemporalQualification.record_fact_entry(runtime, context_a(), fact_input)

      assert {:error, %TemporalQualificationError{code: :retryable_dependency}} =
               TemporalQualification.pin_consumer_revision(runtime, context_a(), pin_input)

      assert {:ok, [[0, 0, 0, 0, 0]]} =
               t1c_counts(runtime, scope_id, consumer_id)
    after
      remove_t1c_completion_failure(runtime)
    end

    assert {:ok, %FactOperationResult{}} =
             TemporalQualification.record_fact_entry(runtime, context_a(), fact_input)

    assert {:ok, %ConsumerResult{}} =
             TemporalQualification.pin_consumer_revision(runtime, context_a(), pin_input)

    assert {:ok, [[1, 1, 1, 2, 2]]} = t1c_counts(runtime, scope_id, consumer_id)
  end

  defp seed_authority(runtime) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_a(), fn ->
               full_role = UUID.generate()
               current_role = UUID.generate()
               membership_a = UUID.generate()
               membership_peer = UUID.generate()
               membership_current = UUID.generate()
               membership_denied = UUID.generate()

               insert_membership(membership_a, @tenant_a, @actor_a)
               insert_membership(membership_peer, @tenant_a, @actor_a_peer)
               insert_membership(membership_current, @tenant_a, @actor_a_current)
               insert_membership(membership_denied, @tenant_a, @actor_a_denied)
               insert_role(full_role, @tenant_a, "Temporal qualifier")
               insert_role(current_role, @tenant_a, "Current reader")

               capabilities =
                 for key <- [
                       @publish_capability,
                       @correct_capability,
                       @current_capability,
                       @history_capability,
                       @fact_record_capability,
                       @fact_correct_capability,
                       @fact_read_capability,
                       @consumer_pin_capability,
                       @consumer_reconcile_capability,
                       @consumer_read_capability
                     ],
                     into: %{} do
                   id = UUID.generate()
                   insert_capability(id, @tenant_a, key)
                   {key, id}
                 end

               insert_assignment(@tenant_a, membership_a, full_role)
               insert_assignment(@tenant_a, membership_peer, full_role)
               insert_assignment(@tenant_a, membership_current, current_role)

               Enum.each(Map.values(capabilities), fn capability_id ->
                 insert_grant(@tenant_a, full_role, capability_id)
               end)

               insert_grant(@tenant_a, current_role, capabilities[@current_capability])
               :seeded
             end)

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_b(), fn ->
               full_role = UUID.generate()
               membership = UUID.generate()
               insert_membership(membership, @tenant_b, @actor_b)
               insert_role(full_role, @tenant_b, "Tenant B temporal qualifier")
               insert_assignment(@tenant_b, membership, full_role)

               for key <- [
                     @publish_capability,
                     @correct_capability,
                     @current_capability,
                     @history_capability,
                     @fact_record_capability,
                     @fact_correct_capability,
                     @fact_read_capability,
                     @consumer_pin_capability,
                     @consumer_reconcile_capability,
                     @consumer_read_capability
                   ] do
                 capability_id = UUID.generate()
                 insert_capability(capability_id, @tenant_b, key)
                 insert_grant(@tenant_b, full_role, capability_id)
               end

               :seeded
             end)
  end

  defp insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      """
      INSERT INTO platform_tenant_memberships
        (id, tenant_id, actor_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  defp insert_role(id, tenant_id, name) do
    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, $3, 1, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), name]
    )
  end

  defp insert_capability(id, tenant_id, key) do
    Repo.query!(
      """
      INSERT INTO platform_capabilities
        (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), key]
    )
  end

  defp insert_assignment(tenant_id, membership_id, role_id) do
    Repo.query!(
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, membership_id, role_id], &dump/1)
    )
  end

  defp insert_grant(tenant_id, role_id, capability_id) do
    Repo.query!(
      """
      INSERT INTO platform_role_capability_grants
        (id, tenant_id, role_id, capability_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, role_id, capability_id], &dump/1)
    )
  end

  defp publish_input(aggregate_id, idempotency_key \\ UUID.generate()) do
    %{
      aggregate_id: aggregate_id,
      scope_id: UUID.generate(),
      reason_code: "baseline",
      segments: [
        segment(~D[2026-01-01], ~D[2026-07-01], "alpha"),
        segment(~D[2026-07-01], ~D[2027-01-01], "beta")
      ],
      idempotency_key: idempotency_key,
      causation_id: UUID.generate()
    }
  end

  defp correct_input(aggregate_id, expected_revision_id, value \\ "corrected") do
    %{
      aggregate_id: aggregate_id,
      expected_revision_id: expected_revision_id,
      reason_code: "synthetic_correction",
      segments: [segment(~D[2026-01-01], ~D[2027-01-01], value)],
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp segment(effective_from, effective_until, value) do
    %{effective_from: effective_from, effective_until: effective_until, value: value}
  end

  defp fact_input(scope_id, idempotency_key \\ UUID.generate()) do
    %{
      scope_id: scope_id,
      effective_on: ~D[2026-01-01],
      quantity: 10,
      reason_code: "synthetic_entry",
      idempotency_key: idempotency_key,
      causation_id: UUID.generate()
    }
  end

  defp fact_correction_input(target_fact_id, replacement_quantity) do
    %{
      target_fact_id: target_fact_id,
      replacement_effective_on: ~D[2026-02-01],
      replacement_quantity: replacement_quantity,
      reason_code: "synthetic_correction",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp consumer_pin_input(consumer_id, aggregate_id, revision_id) do
    %{
      consumer_id: consumer_id,
      aggregate_id: aggregate_id,
      revision_id: revision_id,
      reason_code: "initial_basis",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp consumer_reconcile_input(
         consumer_id,
         expected_basis_id,
         target_revision_id,
         causation_id
       ) do
    %{
      consumer_id: consumer_id,
      expected_basis_id: expected_basis_id,
      target_revision_id: target_revision_id,
      reason_code: "deliberate_reconciliation",
      idempotency_key: UUID.generate(),
      causation_id: causation_id
    }
  end

  defp fact_evidence(runtime, result, idempotency_key) do
    Persistence.with_writer(runtime, context_a(), fn ->
      Repo.query!(
        """
        SELECT audit.action_name, outbox.payload, claim.result_payload
        FROM platform_authority_audit_events AS audit
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = audit.tenant_id AND claim.audit_reference = audit.id
        WHERE audit.tenant_id = $1
          AND audit.id = $2
          AND outbox.id = $3
          AND claim.idempotency_key = $4
        """,
        Enum.map(
          [@tenant_a, result.audit_reference, result.event_id, idempotency_key],
          &dump/1
        )
      ).rows
    end)
  end

  defp t1c_counts(runtime, scope_id, consumer_id) do
    Persistence.with_writer(runtime, context_a(), fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_temporal_qualification_fact_operations
           WHERE tenant_id = $1 AND scope_id = $2),
          (SELECT count(*) FROM platform_temporal_qualification_facts
           WHERE tenant_id = $1 AND scope_id = $2),
          (SELECT count(*) FROM platform_temporal_qualification_consumer_bases
           WHERE tenant_id = $1 AND consumer_id = $3),
          (SELECT count(*) FROM platform_authority_audit_events
           WHERE tenant_id = $1
             AND aggregate_type IN (
               'platform.temporal_qualification.fact_operation',
               'platform.temporal_qualification.reconciliation_consumer'
             )),
          (SELECT count(*) FROM platform_outbox_events
           WHERE tenant_id = $1
             AND aggregate_type IN (
               'platform.temporal_qualification.fact_operation',
               'platform.temporal_qualification.reconciliation_consumer'
             ))
        """,
        [dump(@tenant_a), dump(scope_id), dump(consumer_id)]
      ).rows
    end)
  end

  defp install_t1c_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_t1c_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_t1c_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_t1c_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.aggregate_type IN (
                      'platform.temporal_qualification.fact_scope',
                      'platform.temporal_qualification.fact',
                      'platform.temporal_qualification.reconciliation_consumer'
                    ) THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic T1-C completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_t1c_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_t1c_completion();
               """)

               :installed
             end)
  end

  defp remove_t1c_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_t1c_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_t1c_completion()")
               :removed
             end)
  end

  defp qualification_counts(runtime, context, aggregate_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_temporal_qualification_aggregates
           WHERE tenant_id = $1 AND id = $2),
          (SELECT count(*) FROM platform_temporal_qualification_revisions
           WHERE tenant_id = $1 AND aggregate_id = $2),
          (SELECT count(*) FROM platform_temporal_qualification_segments
           WHERE tenant_id = $1 AND aggregate_id = $2),
          (SELECT count(*) FROM platform_authority_audit_events
           WHERE tenant_id = $1 AND aggregate_id = $2
             AND aggregate_type = 'platform.temporal_qualification.aggregate'),
          (SELECT count(*) FROM platform_outbox_events
           WHERE tenant_id = $1 AND aggregate_id = $2
             AND aggregate_type = 'platform.temporal_qualification.aggregate'),
          (SELECT count(*) FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND aggregate_id = $2
             AND aggregate_type = 'platform.temporal_qualification.aggregate')
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(aggregate_id)]
      ).rows
    end)
  end

  defp read_evidence(runtime, context, result, idempotency_key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          audit.action_name,
          audit.before_version,
          audit.after_version,
          audit.change_summary,
          outbox.event_type,
          outbox.payload,
          claim.status,
          claim.result_payload
        FROM platform_authority_audit_events AS audit
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = audit.tenant_id AND claim.audit_reference = audit.id
        WHERE audit.tenant_id = $1
          AND audit.id = $2
          AND outbox.id = $3
          AND claim.idempotency_key = $4
        """,
        Enum.map(
          [
            TrustedActor.tenant_id(context.actor),
            result.audit_reference,
            result.event_id,
            idempotency_key
          ],
          &dump/1
        )
      ).rows
    end)
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_temporal_idempotency_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_temporal_idempotency_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_temporal_idempotency_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.aggregate_type = 'platform.temporal_qualification.aggregate' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic temporal completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_temporal_idempotency_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_temporal_idempotency_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_temporal_idempotency_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_temporal_idempotency_completion()")
               :removed
             end)
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
  defp context_a_peer, do: context(@actor_a_peer, @tenant_a)
  defp context_a_current, do: context(@actor_a_current, @tenant_a)
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

  defp dump(uuid), do: UUID.dump!(uuid)
end
