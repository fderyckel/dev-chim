# Explicit fresh local synthetic retention/restore proof. Never drop a database.
ExUnit.start()

defmodule Chimwemwe.Communications.RetentionQualificationTest do
  use ExUnit.Case, async: false
  alias Chimwemwe.Classroom.Fixture, as: Classroom
  alias Chimwemwe.Communications.{Fixture, LocalRequestGate, Publication}
  alias Chimwemwe.People.StaffAudienceFixture, as: Audience
  alias Chimwemwe.Platform.{DatabaseAdmission, PersistenceRuntime}

  @tag timeout: 180_000
  test "published correction, receipts and terminal withdrawal converge after backup/restore" do
    database = System.fetch_env!("CHIMWEMWE_TEST_DATABASE")
    target = System.fetch_env!("COMM1_RESTORE_DB")
    archive = System.fetch_env!("COMM1_ARCHIVE")
    assert String.starts_with?(database, "chimwemwe_comm1_retention_")
    assert String.starts_with?(target, "chimwemwe_comm1_restore_")
    persistence = start_supervised!({PersistenceRuntime, Classroom.runtime_options()})
    assert Mix.env() == :test
    assert String.starts_with?(System.fetch_env!("PGHOST"), "/")

    assert {:ok, %{rows: [[0]]}} =
             Classroom.query(%{persistence: persistence}, """
             SELECT (SELECT count(*) FROM platform_tenant_memberships) +
               (SELECT count(*) FROM platform_authority_audit_events) +
               (SELECT count(*) FROM people_persons) + (SELECT count(*) FROM identity_accounts)
             """)

    {:ok, seeded} = Classroom.seed!(persistence)
    f = Fixture.connect!(seeded)
    {v1, _} = Fixture.publish!(f)

    assert {:ok, _} =
             Publication.open_notice(f.communications, f.recipient_request, engagement(v1))

    receipt1 = engagement(v1)
    assert {:ok, _} = Publication.confirm_receipt(f.communications, f.recipient_request, receipt1)
    v2 = advance(f, v1, "correct")
    receipt2 = engagement(v2)
    assert {:ok, _} = Publication.confirm_receipt(f.communications, f.recipient_request, receipt2)
    withdrawn = advance(f, v2, "withdraw")
    assert withdrawn.state == "withdrawn"

    assert {:ok, %{state: "withdrawn", number: 2}} =
             Publication.recipient_status(f.communications, f.recipient_request, v2.notice_id)

    before_state = snapshot(f)

    {output, 0} =
      System.cmd("pg_dump", ["--format=custom", "--file", archive, "--dbname", database],
        stderr_to_stdout: true
      )

    assert output == ""
    {output, 0} = System.cmd("createdb", [target], stderr_to_stdout: true)
    assert output == ""

    {output, 0} =
      System.cmd("pg_restore", ["--exit-on-error", "--dbname", target, archive],
        stderr_to_stdout: true
      )

    assert output == ""

    options =
      Classroom.runtime_options()
      |> Keyword.update!(:repositories, fn repos ->
        Keyword.update!(repos, :pooled, &Keyword.put(&1, :database, target))
      end)

    restored =
      start_supervised!(
        Supervisor.child_spec({PersistenceRuntime, options}, id: :restored_runtime)
      )

    {:ok, admission} = PersistenceRuntime.child_pid(restored, DatabaseAdmission)

    spec =
      Supervisor.child_spec({LocalRequestGate, {Fixture.tenant(f), f.unit.id, admission}},
        id: {LocalRequestGate, f.unit.id},
        restart: :temporary
      )

    {:ok, gate} = Supervisor.start_child(restored, spec)

    {:ok, config} =
      Publication.new(restored, Fixture.tenant(f), f.unit.id, "Northstar Fictional School", gate)

    restored_f = %{f | persistence: restored, communications: config}
    assert before_state == snapshot(restored_f)

    assert {:ok, %{state: "withdrawn"}} =
             Publication.recipient_status(config, f.recipient_request, v1.notice_id)

    assert {:ok, %{own_receipt: %{statement: "I acknowledge receipt of this notice."}}} =
             Publication.inspect_own_receipt(
               config,
               f.recipient_request,
               v1.notice_id,
               v1.revision_id
             )

    assert {:ok, %{own_receipt: %{statement: "I acknowledge receipt of this notice."}}} =
             Publication.inspect_own_receipt(
               config,
               f.recipient_request,
               v2.notice_id,
               v2.revision_id
             )

    assert {:ok, %{status: "committed", result: result}} =
             Publication.command_outcome(config, f.recipient_request, %{
               notice_id: v2.notice_id,
               action: "confirm_receipt",
               idempotency_key: receipt2.idempotency_key
             })

    refute Map.has_key?(result, "body")
    refute Map.has_key?(result, "source_proof")
    assert result["revision_id"] == v2.revision_id
    assert {:error, _} = Publication.open_notice(config, f.recipient_request, engagement(v2))
    assert {:error, _} = Publication.confirm_receipt(config, f.recipient_request, engagement(v2))
    assert before_state == snapshot(restored_f)

    IO.puts(
      "COMM1_RETENTION " <>
        Jason.encode!(%{
          database: database,
          restored_database: target,
          archive_sha256:
            :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower),
          state: before_state,
          withdrawn: true,
          own_history: true,
          receipt_outcome: true,
          no_new_engagement_after_withdrawal: true
        })
    )
  end

  defp advance(f, notice, operation) do
    {prepared, _} = Fixture.prepare!(f, notice, operation)
    {submitted, _} = Fixture.submit!(f, notice, prepared)

    input =
      Map.merge(Classroom.keys(), %{
        notice_id: notice.notice_id,
        expected_version: submitted.version,
        preparation_id: prepared.preparation_id
      })

    assert {:ok, result} = Publication.approve_operation(f.communications, f.approver, input)
    result
  end

  defp engagement(notice),
    do:
      Map.merge(Classroom.keys(), %{notice_id: notice.notice_id, revision_id: notice.revision_id})

  defp snapshot(f) do
    for table <- [
          "communications_notices",
          "communications_preparations",
          "communications_revisions",
          "communications_engagements",
          "platform_authority_audit_events",
          "platform_outbox_events",
          "platform_authority_action_idempotency"
        ],
        into: %{} do
      [[count, digest]] =
        Audience.sql!(
          f,
          "SELECT count(*),md5(COALESCE(string_agg(row_to_json(t)::text,'' ORDER BY id::text),'')) FROM " <>
            table <> " t"
        ).rows

      {table, %{count: count, digest: digest}}
    end
  end
end
