defmodule Chimwemwe.Communications.PublicationTest do
  use ExUnit.Case, async: false
  alias Chimwemwe.Identity.LocalCredentials
  import Chimwemwe.Communications.Fixture
  alias Chimwemwe.Classroom.Fixture, as: Classroom
  alias Chimwemwe.Communications.{Error, LocalRequestGate, Publication}
  alias Chimwemwe.Identity.SessionFoundation
  alias Chimwemwe.People.{Foundation, StaffAudienceFixture}

  alias Chimwemwe.Platform.{
    DatabaseAdmission,
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    ResourceContract
  }

  alias Chimwemwe.Platform.Outbox
  alias Chimwemwe.Platform.Outbox.ConsumerRegistry
  alias Chimwemwe.Repo
  alias Chimwemwe.Test.OutboxConsumer
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, Classroom.runtime_options()})
    {:ok, fixture} = Classroom.seed!(persistence)
    old = Application.get_env(:chimwemwe_core, :identity_session_hmac_secret)

    Application.put_env(
      :chimwemwe_core,
      :identity_session_hmac_secret,
      :crypto.strong_rand_bytes(48)
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:chimwemwe_core, :identity_session_hmac_secret, old),
        else: Application.delete_env(:chimwemwe_core, :identity_session_hmac_secret)

      for agent <- [fixture.source, fixture.account_source],
          do: if(Process.alive?(agent), do: Agent.stop(agent))

      StaffAudienceFixture.cleanup!()
    end)

    {:ok, connect!(fixture)}
  end

  test "independent non-recipient approver publishes exact preparation without creating engagement",
       f do
    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)

    assert {:ok, review} =
             Publication.review_operation(f.communications, f.approver, notice.notice_id)

    assert review.title == "Staff collection time"
    assert review.eligibility.audience == 2
    assert review.eligibility.eligible == 1

    input =
      Map.merge(Classroom.keys(), %{
        notice_id: notice.notice_id,
        expected_version: submitted.version,
        preparation_id: prepared.preparation_id
      })

    assert {:ok, published} = Publication.approve_operation(f.communications, f.approver, input)
    assert published.number == 1

    assert {:ok, metrics} =
             Publication.metrics(
               f.communications,
               f.request,
               notice.notice_id,
               published.revision_id
             )

    assert metrics.opened == 0 and metrics.receipt_confirmed == 0

    assert {:ok, status} =
             Publication.recipient_status(f.communications, f.recipient_request, notice.notice_id)

    assert status.own_receipt == nil
    refute Map.has_key?(status, :body)
    assert counts(f, "communications_engagements") == 0
  end

  test "same actor in a different session cannot approve its own operation", f do
    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)

    input =
      Map.merge(Classroom.keys(), %{
        notice_id: notice.notice_id,
        expected_version: submitted.version,
        preparation_id: prepared.preparation_id
      })

    assert {:error, %Error{code: :forbidden}} =
             Publication.approve_operation(f.communications, f.request, input)

    assert counts(f, "communications_revisions") == 0
  end

  test "source insertion after preparation refuses approval without partial publication", f do
    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)
    StaffAudienceFixture.staff!(f, linked: false)

    input =
      Map.merge(Classroom.keys(), %{
        notice_id: notice.notice_id,
        expected_version: submitted.version,
        preparation_id: prepared.preparation_id
      })

    assert {:error, %Error{code: :stale}} =
             Publication.approve_operation(f.communications, f.approver, input)

    assert counts(f, "communications_revisions") == 0

    assert {:ok, %{state: "pending"}} =
             Publication.inspect_draft(f.communications, f.request, notice.notice_id)
  end

  test "exact receipt may precede opening and duplicates across keys remain one logical fact",
       f do
    {published, _} = publish!(f)
    input = engagement(published)

    assert {:ok, receipt} =
             Publication.confirm_receipt(f.communications, f.recipient_request, input)

    assert receipt.statement == "I acknowledge receipt of this notice."
    assert {:ok, _} = Publication.confirm_receipt(f.communications, f.recipient_request, input)

    assert {:ok, _} =
             Publication.confirm_receipt(
               f.communications,
               f.recipient_request,
               Map.merge(input, Classroom.keys())
             )

    assert {:ok, metrics} =
             Publication.metrics(
               f.communications,
               f.request,
               published.notice_id,
               published.revision_id
             )

    assert metrics.opened == 0 and metrics.receipt_confirmed == 1

    assert {:ok, opened} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(published))

    assert opened.body == "Collection is at 15:00."

    assert {:ok, _} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(published))

    assert {:ok, metrics} =
             Publication.metrics(
               f.communications,
               f.request,
               published.notice_id,
               published.revision_id
             )

    assert metrics.opened == 1 and metrics.receipt_confirmed == 1
    assert counts(f, "communications_engagements") == 2
  end

  test "receipt-off rejects confirmation and title/body render only in explicit opening", f do
    {published, _} = publish!(f, false)

    assert {:error, %Error{code: :conflict}} =
             Publication.confirm_receipt(
               f.communications,
               f.recipient_request,
               engagement(published)
             )

    assert {:ok, opened} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(published))

    refute opened.receipt_required
    assert counts(f, "communications_engagements") == 1
  end

  test "correction preserves N and original admission, requires fresh receipt, then terminal withdrawal",
       f do
    {v1, _} = publish!(f)

    assert {:ok, _} =
             Publication.confirm_receipt(f.communications, f.recipient_request, engagement(v1))

    newcomer = StaffAudienceFixture.staff!(f)
    newcomer_request = request!(f, newcomer.actor, newcomer.member)
    {prepared, _} = prepare!(f, v1, "correct")
    {submitted, _} = submit!(f, v1, prepared)

    assert {:ok, v2} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )

    assert v2.number == 2

    assert {:ok, status} =
             Publication.recipient_status(f.communications, f.recipient_request, v1.notice_id)

    assert status.own_receipt == nil

    assert {:error, %{code: :forbidden}} =
             Publication.recipient_status(f.communications, newcomer_request, v1.notice_id)

    assert {:error, %Error{code: :stale}} =
             Publication.confirm_receipt(f.communications, f.recipient_request, engagement(v1))

    assert {:ok, _} =
             Publication.confirm_receipt(f.communications, f.recipient_request, engagement(v2))

    assert {:ok, metrics} =
             Publication.metrics(f.communications, f.request, v2.notice_id, v2.revision_id)

    assert metrics.eligibility.audience == 2 and metrics.receipt_confirmed == 1

    assert {:ok, old} =
             Publication.metrics(f.communications, f.request, v1.notice_id, v1.revision_id)

    assert old.receipt_confirmed == 1

    third =
      Map.merge(Classroom.keys(), %{
        notice_id: v2.notice_id,
        expected_version: v2.version,
        operation: "correct",
        title: "Third",
        body: "Unsupported",
        reason: "Another correction"
      })

    assert {:error, %Error{code: :scope_limit}} =
             Publication.prepare_operation(f.communications, f.request, third)

    {withdraw, _} = prepare!(f, v2, "withdraw")
    {submitted, _} = submit!(f, v2, withdraw)

    assert {:ok, closed} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, withdraw)
             )

    assert closed.state == "withdrawn"
    assert counts(f, "communications_revisions") == 2

    assert {:error, %Error{code: :stale}} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(v2))

    assert {:error, %Error{code: :stale}} =
             Publication.confirm_receipt(f.communications, f.recipient_request, engagement(v2))

    assert {:ok, %{state: "withdrawn"}} =
             Publication.recipient_status(f.communications, f.recipient_request, v2.notice_id)
  end

  test "operation proposer cannot approve correction even when not original author", f do
    {v1, _} = publish!(f)
    {prepared, _} = prepare!(f, v1, "correct", f.approver)
    {submitted, _} = submit!(f, v1, prepared, f.approver)

    assert {:error, %Error{code: :forbidden}} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )

    assert {:ok, %{number: 2}} =
             Publication.approve_operation(
               f.communications,
               f.request,
               approval(submitted, prepared)
             )
  end

  test "late account activation is not admitted by a correction", f do
    pending = StaffAudienceFixture.staff!(f, account: :pending)
    pending_request = request!(f, pending.actor, pending.member)
    {v1, _} = publish!(f)

    assert {:ok, :activated} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               password = Base.url_encode64(:crypto.strong_rand_bytes(24))

               {:ok, _} =
                 LocalCredentials.complete_first_login(
                   pending.account,
                   1,
                   password,
                   password
                 )

               :activated
             end)

    {prepared, _} = prepare!(f, v1, "correct")
    {submitted, _} = submit!(f, v1, prepared)

    assert {:ok, v2} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )

    assert {:error, %{code: :forbidden}} =
             Publication.recipient_status(f.communications, pending_request, v1.notice_id)

    assert {:ok, metrics} =
             Publication.metrics(f.communications, f.request, v2.notice_id, v2.revision_id)

    assert metrics.eligibility.no_eligible_account == 2
  end

  test "ended staff and revoked association deny content, receipt and own command outcome", f do
    {published, _} = publish!(f)
    input = engagement(published)
    assert {:ok, _} = Publication.confirm_receipt(f.communications, f.recipient_request, input)

    assert {:ok, _} =
             Foundation.revoke_staff_account_association(
               f.runtime,
               Classroom.context_a(),
               Map.merge(Classroom.keys(), %{
                 association_id: f.recipient.association.id,
                 expected_version: 1
               })
             )

    assert {:error, %{code: :forbidden}} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(published))

    assert {:error, %{code: :forbidden}} =
             Publication.confirm_receipt(f.communications, f.recipient_request, input)

    assert {:error, %{code: :forbidden}} =
             Publication.command_outcome(f.communications, f.recipient_request, %{
               notice_id: published.notice_id,
               action: "confirm_receipt",
               idempotency_key: input.idempotency_key
             })

    assert counts(f, "communications_engagements") == 1
  end

  test "changed idempotency payload conflicts; actor-bound outcome never contains content", f do
    {published, _} = publish!(f)
    input = engagement(published)
    assert {:ok, _} = Publication.open_notice(f.communications, f.recipient_request, input)

    assert {:error, %{code: :idempotency_conflict}} =
             Publication.open_notice(f.communications, f.recipient_request, %{
               input
               | causation_id: UUID.generate()
             })

    outcome = %{
      notice_id: published.notice_id,
      action: "open_notice",
      idempotency_key: input.idempotency_key
    }

    assert {:ok, result} =
             Publication.command_outcome(f.communications, f.recipient_request, outcome)

    assert result.status == "committed"
    refute inspect(result) =~ "Collection"

    assert {:ok, %{status: "not_recorded"}} =
             Publication.command_outcome(f.communications, f.recipient_request, %{
               outcome
               | idempotency_key: UUID.generate()
             })

    assert {:error, %{code: :forbidden}} =
             Publication.command_outcome(f.communications, f.approver, outcome)
  end

  test "missing, forged, stale purpose and support context fail closed", f do
    input = Map.merge(Classroom.keys(), %{title: "A", body: "B", receipt_required: false})
    assert {:error, _} = Publication.create_draft(f.communications, nil, input)

    {:ok, context} =
      ExecutionContext.establish(f.request.context.actor, f.request.context.placement,
        correlation_id: UUID.generate(),
        purpose: "public.classroom.read",
        locale: "en"
      )

    assert {:error, %{code: :forbidden}} =
             Publication.create_draft(f.communications, %{f.request | context: context}, input)

    assert {:error, %{code: :forbidden}} =
             Publication.create_draft(f.communications, %{f.request | support: %{}}, input)

    assert {:error, _} =
             Publication.create_draft(
               f.communications,
               %{f.request | session_token: "forged-session"},
               input
             )

    assert counts(f, "communications_notices") == 0
  end

  test "wrong institution and cross-tenant context do not disclose notice existence", f do
    notice = create!(f)
    other_institution = UUID.generate()
    other_gate = start_supervised!({LocalRequestGate, {tenant(f), other_institution}})
    other = %{f.communications | institution_id: other_institution, request_gate: other_gate}

    assert {:error, %{code: :forbidden}} =
             Publication.inspect_draft(other, f.request, notice.notice_id)

    assert {:error, %{code: :forbidden}} =
             Publication.inspect_draft(f.communications, f.approver, notice.notice_id)

    wrong = %{f.communications | tenant_id: UUID.generate()}

    assert {:error, %{code: :forbidden}} =
             Publication.inspect_draft(wrong, f.request, notice.notice_id)
  end

  test "current session revocation and unavailable module deny even exact replay", f do
    {published, _} = publish!(f)

    assert {:ok, _} =
             SessionFoundation.logout(
               f.persistence,
               f.recipient_request.context,
               Map.merge(Classroom.keys(), %{token: f.recipient_request.session_token})
             )

    assert {:error, %{code: :forbidden}} =
             Publication.recipient_status(
               f.communications,
               f.recipient_request,
               published.notice_id
             )

    StaffAudienceFixture.sql!(f, """
    UPDATE platform_module_activations a SET state='inactive',replay_from_cursor=0,projection_ready=false,reconciliation_required=true,deactivated_at=NOW() FROM platform_module_entitlements e
    WHERE a.entitlement_id=e.id AND a.tenant_id=e.tenant_id AND e.module_key='communications.core'
    """)

    assert {:error, _} =
             Publication.metrics(
               f.communications,
               f.request,
               published.notice_id,
               published.revision_id
             )
  end

  test "five-notice and Unicode content bounds reject overflow without truncation", f do
    for _ <- 1..5, do: create!(f, false)
    input = Map.merge(Classroom.keys(), %{title: "A", body: "B", receipt_required: false})

    assert {:error, %{code: :scope_limit}} =
             Publication.create_draft(f.communications, f.request, input)

    assert {:error, %Error{code: :invalid_input}} =
             Publication.create_draft(f.communications, f.request, %{
               input
               | title: String.duplicate("é", 121)
             })

    assert {:error, %Error{code: :invalid_input}} =
             Publication.create_draft(f.communications, f.request, %{
               input
               | body: String.duplicate("x", 2001)
             })

    assert {:error, %Error{code: :invalid_input}} =
             Publication.create_draft(
               f.communications,
               f.request,
               Map.put(input, :tenant_id, tenant(f))
             )

    assert counts(f, "communications_notices") == 5
  end

  test "closed resources preserve authoring contract and immutable evidence", f do
    assert :ok = ResourceContract.validate_domain(Chimwemwe.Communications)
    {published, _} = publish!(f)

    assert {:error, _} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               Repo.query(
                 "UPDATE communications_revisions SET body='changed' WHERE tenant_id=$1 AND id=$2",
                 [Classroom.dump(tenant(f)), Classroom.dump(published.revision_id)]
               )
             end)
             |> unwrap_query()

    [[classification, payload]] =
      StaffAudienceFixture.sql!(
        f,
        """
        SELECT classification,payload FROM platform_outbox_events WHERE aggregate_id=$1
        AND event_type='communications.core.approve_operation.completed'
        """,
        [Classroom.dump(published.notice_id)]
      ).rows

    assert classification == "restricted"
    assert Map.keys(payload) == ["notice_id"]
  end

  test "failure after audit and outbox insertion rolls back revision, selector and command", f do
    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)
    input = approval(submitted, prepared)

    StaffAudienceFixture.sql!(f, """
    CREATE FUNCTION test_comm_completion_failure() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN IF NEW.status='completed' AND NEW.action_name='communications.core.approve_operation' THEN
      RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='synthetic completion failure'; END IF; RETURN NEW; END $$;
    """)

    StaffAudienceFixture.sql!(
      f,
      "CREATE TRIGGER test_comm_completion_failure BEFORE UPDATE ON platform_authority_action_idempotency FOR EACH ROW EXECUTE FUNCTION test_comm_completion_failure()"
    )

    try do
      assert {:error, %{code: :retryable_dependency}} =
               Publication.approve_operation(f.communications, f.approver, input)

      assert counts(f, "communications_revisions") == 0

      [[count]] =
        StaffAudienceFixture.sql!(
          f,
          "SELECT count(*) FROM platform_authority_action_idempotency WHERE idempotency_key=$1",
          [Classroom.dump(input.idempotency_key)]
        ).rows

      assert count == 0
    after
      StaffAudienceFixture.sql!(
        f,
        "DROP TRIGGER test_comm_completion_failure ON platform_authority_action_idempotency"
      )

      StaffAudienceFixture.sql!(f, "DROP FUNCTION test_comm_completion_failure()")
    end

    assert {:ok, _} = Publication.approve_operation(f.communications, f.approver, input)
  end

  test "simultaneous receipts and correction serialize with no duplicate logical facts", f do
    # Exercise the domain independently of the local dispatch policy.
    f = %{f | communications: %{f.communications | request_gate: nil}}
    {v1, _} = publish!(f)
    {prepared, _} = prepare!(f, v1, "correct")
    {submitted, _} = submit!(f, v1, prepared)
    inputs = for _ <- 1..3, do: engagement(v1)

    jobs =
      Enum.map(inputs, fn input ->
        Task.async(fn ->
          Publication.confirm_receipt(f.communications, f.recipient_request, input)
        end)
      end)

    correction =
      Task.async(fn ->
        Publication.approve_operation(f.communications, f.approver, approval(submitted, prepared))
      end)

    results = Enum.map(jobs, &Task.await(&1, 5000))

    assert Enum.all?(results, fn result ->
             match?({:ok, _}, result) or match?({:error, %{code: :stale}}, result)
           end)

    assert {:ok, v2} = Task.await(correction, 5000)
    assert counts(f, "communications_engagements") in 0..1
    assert v2.number == 2
  end

  test "independent correction, withdrawal and receipt attempts preserve one valid successor",
       f do
    f = %{f | communications: %{f.communications | request_gate: nil}}
    {v1, _} = publish!(f)
    {prepared, _} = prepare!(f, v1, "correct")
    {submitted, _} = submit!(f, v1, prepared)
    parent = self()

    worker = fn operation ->
      Task.async(fn ->
        send(parent, :race_ready)

        receive do
          :start -> operation.()
        end
      end)
    end

    correction =
      worker.(fn ->
        Publication.approve_operation(f.communications, f.approver, approval(submitted, prepared))
      end)

    withdrawal =
      worker.(fn ->
        input =
          Map.merge(Classroom.keys(), %{
            notice_id: v1.notice_id,
            expected_version: submitted.version,
            operation: "withdraw",
            title: "Staff collection time",
            body: "Collection is at 15:00.",
            reason: "Superseded arrangements"
          })

        with {:ok, prep} <- Publication.prepare_operation(f.communications, f.request, input),
             {:ok, pending} <-
               Publication.submit_for_approval(
                 f.communications,
                 f.request,
                 Map.merge(Classroom.keys(), %{
                   notice_id: v1.notice_id,
                   expected_version: prep.version,
                   preparation_id: prep.preparation_id
                 })
               ) do
          Publication.approve_operation(f.communications, f.approver, approval(pending, prep))
        end
      end)

    receipt =
      worker.(fn ->
        Publication.confirm_receipt(f.communications, f.recipient_request, engagement(v1))
      end)

    for _ <- 1..3, do: assert_receive(:race_ready)
    Enum.each([correction, withdrawal, receipt], &send(&1.pid, :start))
    successors = Enum.map([correction, withdrawal], &Task.await(&1))
    assert Enum.count(successors, &match?({:ok, _}, &1)) == 1
    assert Enum.all?(successors, &(match?({:ok, _}, &1) or match?({:error, %{code: :stale}}, &1)))
    receipt_result = Task.await(receipt)
    assert match?({:ok, _}, receipt_result) or match?({:error, %{code: :stale}}, receipt_result)

    assert {:ok, status} =
             Publication.recipient_status(f.communications, f.recipient_request, v1.notice_id)

    assert {status.state, status.number} in [{"withdrawn", 1}, {"published", 2}]
    assert counts(f, "communications_engagements") in 0..1
    assert counts(f, "communications_revisions") == status.number
  end

  test "disjoint non-recipient caller graphs compare by population, while caller-only changes retain authority",
       f do
    author_role =
      isolate_role!(f, f.request, [
        "people.core.audiences.prepare_staff",
        "communications.core.notices.draft",
        "communications.core.notices.metrics"
      ])

    isolate_role!(f, f.approver, [
      "people.core.audiences.prepare_staff",
      "communications.core.notices.approve"
    ])

    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)

    StaffAudienceFixture.sql!(
      f,
      "UPDATE platform_roles SET name='Fictional renamed author profile',lock_version=lock_version+1 WHERE tenant_id=$1 AND id=$2",
      [Classroom.dump(tenant(f)), Classroom.dump(author_role)]
    )

    assert {:ok, %{number: 1}} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )
  end

  test "revoked non-recipient proposer authority refuses approval without changing population",
       f do
    author_role =
      isolate_role!(f, f.request, [
        "people.core.audiences.prepare_staff",
        "communications.core.notices.draft"
      ])

    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)

    StaffAudienceFixture.sql!(
      f,
      """
      DELETE FROM platform_role_capability_grants g USING platform_capabilities c
      WHERE g.tenant_id=$1 AND g.role_id=$2 AND c.id=g.capability_id AND c.tenant_id=g.tenant_id
        AND c.key='communications.core.notices.draft'
      """,
      [Classroom.dump(tenant(f)), Classroom.dump(author_role)]
    )

    assert {:error, %{code: :forbidden}} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )

    assert counts(f, "communications_revisions") == 0
  end

  test "revoked approver permission refuses its already loaded approval", f do
    role =
      isolate_role!(f, f.approver, [
        "people.core.audiences.prepare_staff",
        "communications.core.notices.approve"
      ])

    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)

    StaffAudienceFixture.sql!(
      f,
      "DELETE FROM platform_role_capability_grants WHERE tenant_id=$1 AND role_id=$2",
      [Classroom.dump(tenant(f)), Classroom.dump(role)]
    )

    assert {:error, %{code: :forbidden}} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )

    assert counts(f, "communications_revisions") == 0
  end

  test "expired durable preparation refuses approval; fixture expiry injection does not relax immutable storage",
       f do
    notice = create!(f)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)
    # Test-only controlled fixture injection. Ordinary writes remain forbidden.
    StaffAudienceFixture.sql!(
      f,
      "ALTER TABLE communications_preparations DISABLE TRIGGER communications_preparations_immutable"
    )

    try do
      StaffAudienceFixture.sql!(
        f,
        "UPDATE communications_preparations SET expires_at=NOW()-interval '1 second' WHERE tenant_id=$1 AND id=$2",
        [Classroom.dump(tenant(f)), Classroom.dump(prepared.preparation_id)]
      )
    after
      StaffAudienceFixture.sql!(
        f,
        "ALTER TABLE communications_preparations ENABLE TRIGGER communications_preparations_immutable"
      )
    end

    assert {:error, %{code: :stale}} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )

    assert counts(f, "communications_revisions") == 0
  end

  test "account A to B to A rebinding cannot reopen the original publication or its own receipt",
       f do
    {published, _} = publish!(f)

    assert {:ok, _} =
             Publication.confirm_receipt(
               f.communications,
               f.recipient_request,
               engagement(published)
             )

    for actor <- [UUID.generate(), f.recipient.actor] do
      StaffAudienceFixture.sql!(f, "UPDATE identity_accounts SET actor_id=$2 WHERE id=$1", [
        Classroom.dump(f.recipient.account),
        Classroom.dump(actor)
      ])
    end

    assert {:error, %{code: :forbidden}} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(published))

    assert {:error, %{code: :forbidden}} =
             Publication.inspect_own_receipt(
               f.communications,
               f.recipient_request,
               published.notice_id,
               published.revision_id
             )

    assert counts(f, "communications_engagements") == 1
  end

  test "same-principal credential rotation preserves admission with current independent session checks",
       f do
    {published, _} = publish!(f)

    assert {:ok, :rotated} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               {:ok, %{account: account}} = LocalCredentials.reissue(f.recipient.account)
               password = Base.url_encode64(:crypto.strong_rand_bytes(24))

               {:ok, _} =
                 LocalCredentials.complete_first_login(
                   account.id,
                   account.lock_version,
                   password,
                   password
                 )

               :rotated
             end)

    assert {:ok, _} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(published))
  end

  test "retained exact own receipt is available after correction and withdrawal only while still authorized",
       f do
    {v1, _} = publish!(f)

    assert {:ok, receipt} =
             Publication.confirm_receipt(f.communications, f.recipient_request, engagement(v1))

    {prepared, _} = prepare!(f, v1, "correct")
    {submitted, _} = submit!(f, v1, prepared)

    assert {:ok, v2} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, prepared)
             )

    {withdraw, _} = prepare!(f, v2, "withdraw")
    {submitted, _} = submit!(f, v2, withdraw)

    assert {:ok, _} =
             Publication.approve_operation(
               f.communications,
               f.approver,
               approval(submitted, withdraw)
             )

    assert {:ok, %{own_receipt: own}} =
             Publication.inspect_own_receipt(
               f.communications,
               f.recipient_request,
               v1.notice_id,
               v1.revision_id
             )

    assert own.receipt_id == receipt.fact_id
    refute Map.has_key?(own, :person_id)
    refute Map.has_key?(own, :actor_id)
    refute Map.has_key?(own, :body)
  end

  test "lost create response resolves exact own command without a previously returned aggregate identifier",
       f do
    input =
      Map.merge(Classroom.keys(), %{
        title: "Fictional notice",
        body: "Fictional body",
        receipt_required: false
      })

    assert {:ok, created} = Publication.create_draft(f.communications, f.request, input)
    query = %{notice_id: nil, action: "create_draft", idempotency_key: input.idempotency_key}

    assert {:ok, %{status: "committed", result: result}} =
             Publication.command_outcome(f.communications, f.request, query)

    assert result["notice_id"] == created.notice_id

    assert {:error, %{code: :forbidden}} =
             Publication.command_outcome(f.communications, f.approver, query)

    assert {:ok, %{status: "not_recorded"}} =
             Publication.command_outcome(f.communications, f.request, %{
               query
               | idempotency_key: UUID.generate()
             })
  end

  test "Restricted communications events cannot be downgraded or consumed by the Internal-only dispatcher",
       f do
    {published, _} = publish!(f)
    id = UUID.generate()

    assert {:ok, :granted} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               Classroom.insert_capability(id, tenant(f), "platform.outbox.dispatch")
               Classroom.insert_grant(tenant(f), f.role_a, id)
               :granted
             end)

    assert {:ok, registry} =
             ConsumerRegistry.new([
               %{
                 key: "communications.synthetic.internal_sink",
                 events: [
                   %{
                     type: "communications.core.approve_operation.completed",
                     schema_versions: [1]
                   }
                 ],
                 handler: OutboxConsumer,
                 handler_revision: 1,
                 batch_size: 2,
                 lease_ms: 60_000,
                 max_attempts: 3,
                 retry_ms: 1_000
               }
             ])

    assert {:ok, []} =
             Outbox.claim(
               f.persistence,
               registry,
               Classroom.context_a(),
               "communications.synthetic.internal_sink"
             )

    assert {:error, %Postgrex.Error{}} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               Repo.query(
                 "UPDATE platform_outbox_events SET classification='internal' WHERE aggregate_id=$1 AND aggregate_type='communications.core.notice'",
                 [Classroom.dump(published.notice_id)]
               )
             end)
             |> unwrap_query()
  end

  defp isolate_role!(f, request, keys) do
    role = UUID.generate()

    assert {:ok, :created} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               Repo.query!(
                 "INSERT INTO platform_roles (id,tenant_id,name,lock_version,inserted_at,updated_at) VALUES ($1,$2,$3,1,NOW(),NOW())",
                 [
                   Classroom.dump(role),
                   Classroom.dump(tenant(f)),
                   "Fictional communications profile " <> role
                 ]
               )

               Repo.query!(
                 "DELETE FROM platform_actor_role_assignments WHERE tenant_id=$1 AND membership_id=$2",
                 [Classroom.dump(tenant(f)), Classroom.dump(request.session.membership_id)]
               )

               Classroom.insert_assignment(tenant(f), request.session.membership_id, role)

               for [id] <-
                     Repo.query!(
                       "SELECT id::text FROM platform_capabilities WHERE tenant_id=$1 AND key=ANY($2::text[])",
                       [Classroom.dump(tenant(f)), keys]
                     ).rows,
                   do: Classroom.insert_grant(tenant(f), role, id)

               :created
             end)

    role
  end

  test "same opening command replay returns metadata only; a fresh opening can return current text",
       f do
    {published, _} = publish!(f)
    input = engagement(published)
    assert {:ok, opened} = Publication.open_notice(f.communications, f.recipient_request, input)
    assert opened.body == "Collection is at 15:00."
    assert {:ok, replayed} = Publication.open_notice(f.communications, f.recipient_request, input)
    refute Map.has_key?(replayed, :title)
    refute Map.has_key?(replayed, :body)
    assert replayed.fact_id == opened.fact_id

    assert {:ok, fresh} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(published))

    assert fresh.body == opened.body
    assert counts(f, "communications_engagements") == 1
  end

  test "a different correction proposer can preview current publication and recover exact preparation and submission",
       f do
    {published, _} = publish!(f)

    assert {:ok, preview} =
             Publication.inspect_draft(f.communications, f.approver, published.notice_id)

    assert preview.body == "Collection is at 15:00."
    {prepared, prepare_input} = prepare!(f, published, "correct", f.approver)

    query = %{
      notice_id: published.notice_id,
      action: "prepare_operation",
      idempotency_key: prepare_input.idempotency_key
    }

    assert {:ok, %{status: "committed"}} =
             Publication.command_outcome(f.communications, f.approver, query)

    assert {:error, %{code: :forbidden}} =
             Publication.command_outcome(f.communications, f.request, query)

    {submitted, submit_input} = submit!(f, published, prepared, f.approver)

    query = %{
      query
      | action: "submit_for_approval",
        idempotency_key: submit_input.idempotency_key
    }

    assert {:ok, %{status: "committed"}} =
             Publication.command_outcome(f.communications, f.approver, query)

    assert {:error, %{code: :forbidden}} =
             Publication.command_outcome(f.communications, f.request, query)

    assert {:ok, %{state: "published", number: 1}} =
             Publication.recipient_status(
               f.communications,
               f.recipient_request,
               published.notice_id
             )

    assert {:ok, %{state: "published"}} =
             Publication.metrics(
               f.communications,
               f.request,
               published.notice_id,
               published.revision_id
             )

    assert {:ok, %{state: "pending"}} =
             Publication.review_operation(f.communications, f.request, published.notice_id)

    assert {:ok, v2} =
             Publication.approve_operation(
               f.communications,
               f.request,
               approval(submitted, prepared)
             )

    assert {:ok, opened} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(v2))

    assert opened.body == "Collection is at 12:00."
  end

  test "create replay cannot reveal another startup institution's notice", f do
    input =
      Map.merge(Classroom.keys(), %{
        title: "Fictional institution notice",
        body: "One institution.",
        receipt_required: false
      })

    assert {:ok, _} = Publication.create_draft(f.communications, f.request, input)
    other_institution = UUID.generate()
    other_gate = start_supervised!({LocalRequestGate, {tenant(f), other_institution}})
    other = %{f.communications | institution_id: other_institution, request_gate: other_gate}

    assert {:error, %{code: :idempotency_conflict}} =
             Publication.create_draft(other, f.request, input)

    assert {:error, %{code: :forbidden}} =
             Publication.command_outcome(other, f.request, %{
               notice_id: nil,
               action: "create_draft",
               idempotency_key: input.idempotency_key
             })

    assert counts(f, "communications_notices") == 1
  end

  test "outer publication transaction preserves pre-refresh session deadline and rolls back refresh plus notice",
       f do
    StaffAudienceFixture.sql!(f, """
    CREATE FUNCTION test_comm_slow_create() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN PERFORM pg_sleep(0.3); RETURN NEW; END $$;
    """)

    StaffAudienceFixture.sql!(
      f,
      "CREATE TRIGGER test_comm_slow_create BEFORE INSERT ON communications_notices FOR EACH ROW EXECUTE FUNCTION test_comm_slow_create()"
    )

    try do
      StaffAudienceFixture.sql!(
        f,
        "UPDATE identity_application_sessions SET idle_expires_at=clock_timestamp()+interval '150 milliseconds' WHERE id=$1",
        [Classroom.dump(f.request.session.id)]
      )

      before =
        StaffAudienceFixture.sql!(
          f,
          "SELECT lock_version,idle_expires_at FROM identity_application_sessions WHERE id=$1",
          [Classroom.dump(f.request.session.id)]
        ).rows

      input =
        Map.merge(Classroom.keys(), %{
          title: "Bounded deadline",
          body: "Must roll back.",
          receipt_required: false
        })

      assert {:error, %{code: code}} =
               Publication.create_draft(f.communications, f.request, input)

      assert code in [:stale, :retryable_dependency]
      assert counts(f, "communications_notices") == 0

      assert before ==
               StaffAudienceFixture.sql!(
                 f,
                 "SELECT lock_version,idle_expires_at FROM identity_application_sessions WHERE id=$1",
                 [Classroom.dump(f.request.session.id)]
               ).rows
    after
      StaffAudienceFixture.sql!(f, "DROP TRIGGER test_comm_slow_create ON communications_notices")
      StaffAudienceFixture.sql!(f, "DROP FUNCTION test_comm_slow_create()")
    end
  end

  test "recipient owner preserves pre-refresh deadline and rolls back refresh plus receipt",
       f do
    {published, _} = publish!(f)

    StaffAudienceFixture.sql!(f, """
    CREATE FUNCTION test_comm_slow_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN PERFORM pg_sleep(0.3); RETURN NEW; END $$;
    """)

    StaffAudienceFixture.sql!(
      f,
      "CREATE TRIGGER test_comm_slow_receipt BEFORE INSERT ON communications_engagements FOR EACH ROW EXECUTE FUNCTION test_comm_slow_receipt()"
    )

    try do
      StaffAudienceFixture.sql!(
        f,
        "UPDATE identity_application_sessions SET idle_expires_at=clock_timestamp()+interval '150 milliseconds' WHERE id=$1",
        [Classroom.dump(f.recipient_request.session.id)]
      )

      before =
        StaffAudienceFixture.sql!(
          f,
          "SELECT lock_version,idle_expires_at FROM identity_application_sessions WHERE id=$1",
          [Classroom.dump(f.recipient_request.session.id)]
        ).rows

      assert {:error, %{code: code}} =
               Publication.confirm_receipt(
                 f.communications,
                 f.recipient_request,
                 engagement(published)
               )

      assert code in [:stale, :retryable_dependency]
      assert counts(f, "communications_engagements") == 0

      assert before ==
               StaffAudienceFixture.sql!(
                 f,
                 "SELECT lock_version,idle_expires_at FROM identity_application_sessions WHERE id=$1",
                 [Classroom.dump(f.recipient_request.session.id)]
               ).rows
    after
      StaffAudienceFixture.sql!(
        f,
        "DROP TRIGGER test_comm_slow_receipt ON communications_engagements"
      )

      StaffAudienceFixture.sql!(f, "DROP FUNCTION test_comm_slow_receipt()")
    end
  end

  test "alternate receipt writes require exact non-null statement while opening permits null",
       f do
    {published, _} = publish!(f)

    for statement <- [nil, "I agree"] do
      assert {:error, %Postgrex.Error{}} = insert_engagement(f, published, "receipt", statement)
    end

    assert {:ok, _} = insert_engagement(f, published, "opening", nil)

    assert {:ok, _} =
             insert_engagement(f, published, "receipt", "I acknowledge receipt of this notice.")

    assert counts(f, "communications_engagements") == 2
  end

  defp insert_engagement(f, published, kind, statement) do
    Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
      Repo.query(
        """
        INSERT INTO communications_engagements
          (id,tenant_id,notice_id,revision_id,person_id,actor_id,kind,statement,recorded_at,inserted_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW(),NOW())
        """,
        [
          Classroom.dump(UUID.generate()),
          Classroom.dump(tenant(f)),
          Classroom.dump(published.notice_id),
          Classroom.dump(published.revision_id),
          Classroom.dump(f.recipient.person.id),
          Classroom.dump(f.recipient.actor),
          kind,
          statement
        ]
      )
    end)
    |> unwrap_query()
  end

  defp engagement(published),
    do:
      Map.merge(Classroom.keys(), %{
        notice_id: published.notice_id,
        revision_id: published.revision_id
      })

  defp approval(submitted, prepared),
    do:
      Map.merge(Classroom.keys(), %{
        notice_id: submitted.notice_id,
        expected_version: submitted.version,
        preparation_id: prepared.preparation_id
      })

  test "a real queued receipt rechecks a revoked session without a database permit while waiting",
       f do
    {published, _} = publish!(f)
    parent = self()
    gate = f.communications.request_gate

    holder =
      Task.async(fn ->
        LocalRequestGate.with_slot(gate, tenant(f), f.unit.id, fn ->
          send(parent, :held_without_database)

          receive do
            :release -> :ok
          end
        end)
      end)

    assert_receive :held_without_database

    queued =
      Task.async(fn ->
        Publication.confirm_receipt(f.communications, f.recipient_request, engagement(published))
      end)

    await_waiter(gate)

    {:ok, admission} =
      PersistenceRuntime.child_pid(f.persistence, DatabaseAdmission)

    assert %{active_permits: 0} = DatabaseAdmission.statistics(admission)

    assert {:ok, _} =
             SessionFoundation.revoke_actor_sessions(
               f.persistence,
               f.recipient_request.context,
               Classroom.keys()
             )

    send(holder.pid, :release)
    assert :ok = Task.await(holder)
    assert {:error, %{code: :forbidden}} = Task.await(queued)
    assert counts(f, "communications_engagements") == 0
    assert counts(f, "communications_revisions") == 1
    assert %{active_permits: 0} = DatabaseAdmission.statistics(admission)
  end

  test "an absent lookup and same-key retry cannot duplicate a delayed original create", f do
    parent = self()

    input =
      Map.merge(Classroom.keys(), %{
        title: "Delayed fictional notice",
        body: "Original exact text",
        receipt_required: false
      })

    original =
      Task.async(fn ->
        send(parent, :original_waiting)

        receive do
          :release -> Publication.create_draft(f.communications, f.request, input)
        end
      end)

    assert_receive :original_waiting

    assert {:ok, %{status: "not_recorded"}} =
             Publication.command_outcome(f.communications, f.request, %{
               notice_id: nil,
               action: "create_draft",
               idempotency_key: input.idempotency_key
             })

    assert {:ok, retry} = Publication.create_draft(f.communications, f.request, input)
    send(original.pid, :release)
    assert {:ok, ^retry} = Task.await(original)
    assert counts(f, "communications_notices") == 1
  end

  test "recipient owner validates once and refreshes only the current session", f do
    {published, _} = publish!(f)

    [[before]] =
      StaffAudienceFixture.sql!(
        f,
        "SELECT lock_version FROM identity_application_sessions WHERE id=$1",
        [Classroom.dump(f.recipient_request.session.id)]
      ).rows

    assert {:ok, _} =
             Publication.recipient_status(
               f.communications,
               f.recipient_request,
               published.notice_id
             )

    assert [[before + 1]] ==
             StaffAudienceFixture.sql!(
               f,
               "SELECT lock_version FROM identity_application_sessions WHERE id=$1",
               [Classroom.dump(f.recipient_request.session.id)]
             ).rows
  end

  test "recipient validation keeps identity before communications locks against an independent revocation and membership writer",
       f do
    {published, _} = publish!(f)
    parent = self()

    holder =
      Task.async(fn ->
        Persistence.with_writer(f.persistence, f.recipient_request.context, fn ->
          Repo.transaction(fn ->
            [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows

            assert {:ok, _} =
                     SessionFoundation.revoke_actor_sessions(
                       f.persistence,
                       f.recipient_request.context,
                       Classroom.keys()
                     )

            send(parent, {:revocation_held, backend})

            receive do
              :commit_membership_change -> :ok
            end

            Repo.query!("UPDATE platform_tenant_memberships SET actor_id=$2 WHERE id=$1", [
              Classroom.dump(f.recipient.member),
              Classroom.dump(UUID.generate())
            ])

            :changed
          end)
        end)
      end)

    assert_receive {:revocation_held, holder_backend}

    reader =
      Task.async(fn ->
        Persistence.with_writer(f.persistence, f.recipient_request.context, fn ->
          Repo.transaction(fn ->
            [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
            send(parent, {:reader_backend, backend})

            Publication.recipient_status(
              %{f.communications | request_gate: nil},
              f.recipient_request,
              published.notice_id
            )
          end)
        end)
      end)

    assert_receive {:reader_backend, reader_backend}

    assert blocked_by?(
             f,
             reader_backend,
             holder_backend,
             System.monotonic_time(:millisecond) + 1_000
           )

    assert [[0]] =
             StaffAudienceFixture.sql!(
               f,
               """
               WITH key AS (SELECT hashtextextended('platform-module-lifecycle:' || $2::text || ':communications.core',0) value)
               SELECT count(*) FROM pg_locks,key WHERE pid=$1 AND locktype='advisory' AND granted
               AND classid::bigint=((value >> 32) & 4294967295) AND objid::bigint=(value & 4294967295) AND objsubid=1
               """,
               [reader_backend, tenant(f)]
             ).rows

    send(holder.pid, :commit_membership_change)
    assert {:ok, {:ok, :changed}} = Task.await(holder)
    assert {:error, :rollback} = unwrap_query(Task.await(reader))

    assert {:error, %{code: :forbidden}} =
             Publication.recipient_status(
               f.communications,
               f.recipient_request,
               published.notice_id
             )

    assert counts(f, "communications_engagements") == 0
  end

  defp blocked_by?(f, reader, holder, deadline) do
    [[blockers]] = StaffAudienceFixture.sql!(f, "SELECT pg_blocking_pids($1)", [reader]).rows

    cond do
      holder in blockers ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(5)
        blocked_by?(f, reader, holder, deadline)
    end
  end

  for action <- [:status, :open, :receipt, :history],
      invalid <- [:missing, :forged, :expired, :revoked, :origin, :membership, :account] do
    test "#{action} denies #{invalid} without content or engagement", f do
      {published, _} = publish!(f)
      request = invalid_recipient(f, unquote(invalid))
      assert {:error, %{code: code}} = recipient_action(unquote(action), f, request, published)
      assert code in [:forbidden, :expired]
      assert counts(f, "communications_engagements") == 0
      assert counts(f, "communications_revisions") == 1
    end
  end

  defp invalid_recipient(_f, :missing), do: nil

  defp invalid_recipient(f, :forged),
    do: %{f.recipient_request | session_token: "unissued-fictional-token"}

  defp invalid_recipient(f, kind) do
    case kind do
      :expired ->
        StaffAudienceFixture.sql!(
          f,
          "UPDATE identity_application_sessions SET inserted_at=clock_timestamp()-interval '1 hour', absolute_expires_at=clock_timestamp()+interval '10 hours', idle_expires_at=clock_timestamp()-interval '1 second' WHERE id=$1",
          [Classroom.dump(f.recipient_request.session.id)]
        )

      :revoked ->
        assert {:ok, _} =
                 SessionFoundation.revoke_actor_sessions(
                   f.persistence,
                   f.recipient_request.context,
                   Classroom.keys()
                 )

      :origin ->
        [[version]] =
          StaffAudienceFixture.sql!(
            f,
            "SELECT lock_version FROM identity_connections WHERE id=$1",
            [Classroom.dump(f.connection_id)]
          ).rows

        assert {:ok, _} =
                 Chimwemwe.Identity.Foundation.suspend_connection(
                   f.persistence,
                   Classroom.context_a(),
                   Map.merge(Classroom.keys(), %{
                     connection_id: f.connection_id,
                     expected_version: version
                   })
                 )

      :membership ->
        StaffAudienceFixture.sql!(
          f,
          "UPDATE platform_tenant_memberships SET actor_id=$2 WHERE id=$1",
          [Classroom.dump(f.recipient.member), Classroom.dump(UUID.generate())]
        )

      :account ->
        assert {:ok, {:ok, _}} =
                 Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
                   LocalCredentials.suspend(f.recipient.account)
                 end)
    end

    f.recipient_request
  end

  defp recipient_action(:status, f, request, published),
    do: Publication.recipient_status(f.communications, request, published.notice_id)

  defp recipient_action(:open, f, request, published),
    do: Publication.open_notice(f.communications, request, engagement(published))

  defp recipient_action(:receipt, f, request, published),
    do: Publication.confirm_receipt(f.communications, request, engagement(published))

  defp recipient_action(:history, f, request, published),
    do:
      Publication.inspect_own_receipt(
        f.communications,
        request,
        published.notice_id,
        published.revision_id
      )

  defp await_waiter(gate, attempts \\ 100)
  defp await_waiter(_gate, 0), do: flunk("real receipt did not enter the bounded waiting lane")

  defp await_waiter(gate, attempts) do
    if LocalRequestGate.statistics(gate).waiting == 1,
      do: :ok,
      else:
        (
          Process.sleep(5)
          await_waiter(gate, attempts - 1)
        )
  end

  defp counts(f, table) do
    [[count]] =
      StaffAudienceFixture.sql!(f, "SELECT count(*) FROM " <> table <> " WHERE tenant_id=$1", [
        Classroom.dump(tenant(f))
      ]).rows

    count
  end

  defp unwrap_query({:ok, {:error, error}}), do: {:error, error}
  defp unwrap_query(other), do: other
end
