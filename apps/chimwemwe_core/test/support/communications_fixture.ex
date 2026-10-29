defmodule Chimwemwe.Communications.Fixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Chimwemwe.Classroom.Fixture, as: Classroom
  alias Chimwemwe.Communications.{LocalRequestGate, Publication}

  alias Chimwemwe.Identity.{
    Foundation,
    PublicRequestSession,
    PublicSessionAdapter,
    SessionFoundation,
    VerifiedExternalIdentity
  }

  alias Chimwemwe.People.StaffAudienceFixture, as: Audience

  alias Chimwemwe.Platform.{
    DatabaseAdmission,
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    TrustedActor
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID

  def connect!(fixture) do
    f = Audience.connect!(fixture)
    tenant = TrustedActor.tenant_id(f.request.context.actor)

    assert {:ok, :granted} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               for key <- ["draft", "approve", "metrics"] do
                 id = UUID.generate()
                 Classroom.insert_capability(id, tenant, "communications.core.notices." <> key)
                 Classroom.insert_grant(tenant, f.role_a, id)
               end

               entitlement = UUID.generate()

               Repo.query!(
                 "INSERT INTO platform_module_entitlements (id,tenant_id,module_key,inserted_at) VALUES ($1,$2,'communications.core',NOW())",
                 [Classroom.dump(entitlement), Classroom.dump(tenant)]
               )

               Repo.query!(
                 """
                 INSERT INTO platform_module_activations
                   (id,tenant_id,entitlement_id,module_version,state,lock_version,activated_at,inserted_at,updated_at)
                 VALUES ($1,$2,$3,'1.0.0','active',1,NOW(),NOW(),NOW())
                 """,
                 [
                   Classroom.dump(UUID.generate()),
                   Classroom.dump(tenant),
                   Classroom.dump(entitlement)
                 ]
               )

               :granted
             end)

    {:ok, admission} = PersistenceRuntime.child_pid(f.persistence, DatabaseAdmission)

    spec =
      Supervisor.child_spec({LocalRequestGate, {tenant, f.unit.id, admission}},
        id: {LocalRequestGate, f.unit.id},
        restart: :temporary
      )

    {:ok, gate} = Supervisor.start_child(f.persistence, spec)

    {:ok, config} =
      Publication.new(f.persistence, tenant, f.unit.id, "Northstar Fictional School", gate)

    approver = principal!(f)
    recipient = Audience.staff!(f)
    recipient_request = request!(f, recipient.actor, recipient.member)

    Map.merge(f, %{
      communications: config,
      approver: approver,
      recipient: recipient,
      recipient_request: recipient_request
    })
  end

  def principal!(f) do
    actor = UUID.generate()
    member = UUID.generate()
    tenant = TrustedActor.tenant_id(f.request.context.actor)

    assert {:ok, :created} =
             Persistence.with_writer(f.persistence, Classroom.context_a(), fn ->
               Classroom.insert_membership(member, tenant, actor)
               Classroom.insert_assignment(tenant, member, f.role_a)
               :created
             end)

    request!(f, actor, member)
  end

  def request!(f, actor, member) do
    subject = "fictional-comm-" <> actor

    {:ok, invitation} =
      Foundation.issue_invitation(
        f.persistence,
        Classroom.context_a(),
        Map.merge(Classroom.keys(), %{
          actor_id: actor,
          membership_id: member,
          role_id: f.role_a,
          connection_id: f.connection_id
        })
      )

    {:ok, proof} =
      VerifiedExternalIdentity.establish(
        connection_id: f.connection_id,
        protocol: :oidc,
        issuer: "https://identity.example.test/issuer",
        subject: subject,
        assurance: "mfa",
        authenticated_at: DateTime.utc_now()
      )

    {:ok, trusted} =
      TrustedActor.establish(actor_id: actor, tenant_id: tenant(f), assurance: "mfa")

    {:ok, context} =
      ExecutionContext.establish(trusted, f.request.context.placement,
        correlation_id: UUID.generate(),
        purpose: "communications.staff_audience",
        locale: "en"
      )

    {:ok, link} =
      Foundation.accept_invitation(
        f.persistence,
        context,
        Map.merge(Classroom.keys(), %{token: invitation.token, proof: proof})
      )

    {:ok, session} =
      SessionFoundation.create(
        f.persistence,
        context,
        Map.merge(Classroom.keys(), %{
          external_identity_link_id: link.id,
          membership_id: member,
          proof: proof
        })
      )

    {:ok, view} = SessionFoundation.validate(f.persistence, context, %{token: session.token})

    %PublicRequestSession{
      context: context,
      session: view,
      session_token: session.token,
      csrf_token: "private-test-only",
      support: nil
    }
  end

  def cookie!(f, request) do
    # A test-only verified callback uses the same already-linked fictional actor.
    actor = TrustedActor.actor_id(request.context.actor)

    [[link]] =
      Audience.sql!(
        f,
        "SELECT external_identity_link_id::text FROM identity_application_sessions WHERE id=$1",
        [Classroom.dump(request.session.id)]
      ).rows

    [[subject]] =
      Audience.sql!(f, "SELECT subject FROM identity_external_identity_links WHERE id=$1", [
        Classroom.dump(link)
      ]).rows

    {:ok, proof} =
      VerifiedExternalIdentity.establish(
        connection_id: f.connection_id,
        protocol: :oidc,
        issuer: "https://identity.example.test/issuer",
        subject: subject,
        assurance: "mfa",
        authenticated_at: DateTime.utc_now()
      )

    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        Map.merge(Classroom.keys(), %{
          actor_id: actor,
          tenant_id: tenant(f),
          membership_id: request.session.membership_id,
          external_identity_link_id: link,
          connection_id: f.connection_id,
          locale: "en",
          redirect_to: "/communications"
        })
      )

    code = UUID.generate()
    Process.put({__MODULE__, code}, {f.connection_id, proof})

    {:ok, callback} =
      PublicSessionAdapter.complete_callback(f.persistence, __MODULE__, %{
        state: state,
        code: code
      })

    callback.cookie_value
  end

  @behaviour Chimwemwe.Identity.CallbackVerifier
  @impl true
  def verify_code(code, expected) do
    case Process.delete({__MODULE__, code}) do
      {^expected, proof} -> {:ok, proof}
      _ -> {:error, %Chimwemwe.Identity.Error{code: :forbidden}}
    end
  end

  def create!(f, receipt \\ true) do
    input =
      Map.merge(Classroom.keys(), %{
        title: "Staff collection time",
        body: "Collection is at 15:00.",
        receipt_required: receipt
      })

    assert {:ok, result} = Publication.create_draft(f.communications, f.request, input)
    result
  end

  def prepare!(f, notice, operation \\ "publish", proposer \\ nil) do
    proposer = proposer || f.request

    input =
      Map.merge(Classroom.keys(), %{
        notice_id: notice.notice_id,
        expected_version: notice.version,
        operation: operation,
        title: "Staff collection time",
        body:
          if(operation == "correct" or Map.get(notice, :number, 0) == 2,
            do: "Collection is at 12:00.",
            else: "Collection is at 15:00."
          ),
        reason: if(operation == "publish", do: "", else: "Collection time correction")
      })

    assert {:ok, prepared} = Publication.prepare_operation(f.communications, proposer, input)
    {prepared, input}
  end

  def submit!(f, notice, prepared, proposer \\ nil) do
    input =
      Map.merge(Classroom.keys(), %{
        notice_id: notice.notice_id,
        expected_version: prepared.version,
        preparation_id: prepared.preparation_id
      })

    assert {:ok, result} =
             Publication.submit_for_approval(f.communications, proposer || f.request, input)

    {result, input}
  end

  def publish!(f, receipt \\ true) do
    notice = create!(f, receipt)
    {prepared, _} = prepare!(f, notice)
    {submitted, _} = submit!(f, notice, prepared)

    input =
      Map.merge(Classroom.keys(), %{
        notice_id: notice.notice_id,
        expected_version: submitted.version,
        preparation_id: prepared.preparation_id
      })

    assert {:ok, result} = Publication.approve_operation(f.communications, f.approver, input)
    {result, input}
  end

  def tenant(f), do: TrustedActor.tenant_id(f.request.context.actor)
end
