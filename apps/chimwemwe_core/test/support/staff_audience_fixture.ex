defmodule Chimwemwe.People.StaffAudienceFixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Chimwemwe.Classroom.{AttendanceFixture, Fixture}

  alias Chimwemwe.Identity.{
    LocalCredentials,
    PublicRequestSession,
    SessionFoundation,
    VerifiedExternalIdentity
  }

  alias Chimwemwe.People.{Foundation, StaffAudience}
  alias Chimwemwe.Platform.{ExecutionContext, Persistence, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  def connect!(f) do
    f = AttendanceFixture.connect!(f)
    context = Fixture.context_a()
    tenant = TrustedActor.tenant_id(context.actor)

    # Other suites may retain a global account for this shared fictional actor.
    # Make the fixture's baseline staff member explicitly unlinked instead of
    # assuming account absence. Revoke only the association this fixture created;
    # never delete or alter another suite's retained credential account.
    {:ok, _} =
      Foundation.revoke_staff_account_association(
        f.runtime,
        context,
        Map.merge(Fixture.keys(), %{association_id: f.account.id, expected_version: 1})
      )

    {:ok, :granted} =
      Persistence.with_writer(f.persistence, context, fn ->
        for key <- ["people.core.audiences.prepare_staff", "communications.core.notices.read"] do
          id = UUID.generate()
          Fixture.insert_capability(id, tenant, key)
          Fixture.insert_grant(tenant, f.role_a, id)
        end

        :granted
      end)

    {:ok, proof} =
      VerifiedExternalIdentity.establish(
        connection_id: f.connection_id,
        protocol: :oidc,
        issuer: "https://identity.example.test/issuer",
        subject: "synthetic-attendance-educator",
        assurance: "mfa",
        authenticated_at: DateTime.utc_now()
      )

    {:ok, session} =
      SessionFoundation.create(
        f.persistence,
        context,
        Map.merge(Fixture.keys(), %{
          external_identity_link_id: f.link_id,
          membership_id: f.membership_a,
          proof: proof
        })
      )

    {:ok, view} = SessionFoundation.validate(f.persistence, context, %{token: session.token})

    {:ok, source_context} =
      ExecutionContext.establish(context.actor, context.placement,
        correlation_id: UUID.generate(),
        purpose: "communications.staff_audience",
        locale: "en"
      )

    request = %PublicRequestSession{
      context: source_context,
      csrf_token: "private-test-only",
      session: view,
      session_token: session.token,
      support: nil
    }

    {:ok, config} = StaffAudience.new(f.persistence, f.unit.id)
    Map.merge(f, %{audience: config, request: request})
  end

  def draft,
    do: %{
      title: "Synthetic notice",
      body: "Staff update",
      draft_version: 1,
      receipt_required: false
    }

  def cleanup! do
    {:ok, cleanup} = PersistenceRuntime.start_link(Fixture.runtime_options())

    try do
      # Remove the fixture's invitation/session/link chain before a later suite
      # deletes its tenant roles. Global retained credential accounts are untouched.
      Fixture.clear_fixture(cleanup)
    after
      Supervisor.stop(cleanup)
    end
  end

  def staff!(f, options \\ []) do
    person = Fixture.person!(f)
    input = Fixture.participation_input(f, person) |> Map.merge(Keyword.get(options, :dates, %{}))
    {:ok, part} = Foundation.record_staff_affiliation(f.runtime, Fixture.context_a(), input)

    if Keyword.get(options, :linked, true) do
      link!(f, person, part, options)
    else
      %{person: person, part: part}
    end
  end

  defp link!(f, person, part, options) do
    context = Fixture.context_a()
    tenant = TrustedActor.tenant_id(context.actor)
    actor = UUID.generate()
    member = UUID.generate()

    {:ok, :member} =
      Persistence.with_writer(f.persistence, context, fn ->
        Fixture.insert_membership(member, tenant, actor)
        Fixture.insert_assignment(tenant, member, f.role_a)
        :member
      end)

    reference = UUID.generate()

    binding = %{
      tenant_id: tenant,
      person_id: person.id,
      participation_id: part.id,
      membership_id: member,
      actor_id: actor
    }

    Agent.update(f.account_source, &put_in(&1, [:records, reference], binding))

    {:ok, association} =
      Foundation.associate_staff_account(
        f.runtime,
        context,
        Map.merge(Fixture.keys(), %{
          participation_id: part.id,
          expected_version: 1,
          expected_person_version: 1,
          membership_id: member,
          evidence_reference: reference
        })
      )

    account = account!(f, actor, Keyword.get(options, :account, :active))

    %{
      person: person,
      part: part,
      actor: actor,
      member: member,
      association: association,
      account: account
    }
  end

  def associate!(f, recipient, member, actor) do
    reference = UUID.generate()
    tenant = TrustedActor.tenant_id(f.request.context.actor)

    binding = %{
      tenant_id: tenant,
      person_id: recipient.person.id,
      participation_id: recipient.part.id,
      membership_id: member,
      actor_id: actor
    }

    Agent.update(f.account_source, &put_in(&1, [:records, reference], binding))

    Foundation.associate_staff_account(
      f.runtime,
      Fixture.context_a(),
      Map.merge(Fixture.keys(), %{
        participation_id: recipient.part.id,
        expected_version: 1,
        expected_person_version: 1,
        membership_id: member,
        evidence_reference: reference
      })
    )
  end

  def account!(_f, _actor, :absent), do: nil

  def account!(f, actor, status) do
    {:ok, {:ok, account}} =
      Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
        {:ok, %{account: pending}} =
          LocalCredentials.provision("audience-#{actor}@example.test", actor)

        if status == :pending do
          {:ok, pending.id}
        else
          password = Base.url_encode64(:crypto.strong_rand_bytes(24))
          {:ok, active} = LocalCredentials.complete_first_login(pending.id, 1, password, password)
          {:ok, active.id}
        end
      end)

    account
  end

  def capture!(f) do
    assert {:ok, proof} = StaffAudience.capture(f.audience, f.request, draft())
    proof
  end

  def sql!(f, sql, params \\ []) do
    assert {:ok, result} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               Repo.query!(sql, params)
             end)

    result
  end
end
