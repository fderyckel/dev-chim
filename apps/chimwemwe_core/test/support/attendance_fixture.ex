defmodule Chimwemwe.Classroom.AttendanceFixture do
  @moduledoc false
  import ExUnit.Assertions
  import Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Identity.{Foundation, PublicSessionAdapter, VerifiedExternalIdentity}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.TrustedActor
  alias Ecto.UUID

  def connect!(f) do
    context = context_a()
    actor = TrustedActor.actor_id(context.actor)
    tenant = TrustedActor.tenant_id(context.actor)
    {:ok, part} = People.current_participation(f.runtime, context, f.staff.id)
    reference = UUID.generate()

    binding = %{
      tenant_id: tenant,
      person_id: part.person_id,
      participation_id: part.id,
      membership_id: f.membership_a,
      actor_id: actor
    }

    Agent.update(f.account_source, &put_in(&1, [:records, reference], binding))

    {:ok, account} =
      People.associate_staff_account(
        f.runtime,
        context,
        Map.merge(keys(), %{
          participation_id: part.id,
          expected_version: 1,
          expected_person_version: 1,
          membership_id: f.membership_a,
          evidence_reference: reference
        })
      )

    {:ok, connection} =
      Foundation.register_connection(
        f.persistence,
        context,
        Map.merge(keys(), %{
          name: "Synthetic attendance connection",
          protocol: :oidc,
          issuer: "https://identity.example.test/issuer",
          application_identifier: "synthetic-client",
          secret_reference: "identity/synthetic/sign-in-secret",
          assurance_mapping: %{"synthetic-mfa" => "mfa"}
        })
      )

    for {action, version} <- [{:qualify_connection, 1}, {:activate_connection, 2}] do
      assert {:ok, _} =
               apply(Foundation, action, [
                 f.persistence,
                 context,
                 Map.merge(keys(), %{connection_id: connection.id, expected_version: version})
               ])
    end

    {:ok, invitation} =
      Foundation.issue_invitation(
        f.persistence,
        context,
        Map.merge(keys(), %{
          actor_id: actor,
          membership_id: f.membership_a,
          role_id: f.role_a,
          connection_id: connection.id
        })
      )

    proof = proof!(connection.id)

    {:ok, link} =
      Foundation.accept_invitation(
        f.persistence,
        context,
        Map.merge(keys(), %{token: invitation.token, proof: proof})
      )

    Map.merge(f, %{account: account, connection_id: connection.id, link_id: link.id})
  end

  def login!(f) do
    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        Map.merge(keys(), %{
          actor_id: TrustedActor.actor_id(context_a().actor),
          tenant_id: TrustedActor.tenant_id(context_a().actor),
          membership_id: f.membership_a,
          external_identity_link_id: f.link_id,
          connection_id: f.connection_id,
          locale: "en",
          redirect_to: "/classroom"
        })
      )

    code = UUID.generate()
    Process.put({__MODULE__, code}, {f.connection_id, proof!(f.connection_id)})

    {:ok, callback} =
      PublicSessionAdapter.complete_callback(f.persistence, __MODULE__, %{
        code: code,
        state: state
      })

    {:ok, request} =
      PublicSessionAdapter.authenticate(
        f.persistence,
        callback.cookie_value,
        :classroom_read,
        "en",
        UUID.generate()
      )

    {callback.cookie_value, request}
  end

  @behaviour Chimwemwe.Identity.CallbackVerifier
  @impl true
  def verify_code(code, expected) do
    case Process.delete({__MODULE__, code}) do
      {^expected, proof} -> {:ok, proof}
      _ -> {:error, %Chimwemwe.Identity.Error{code: :forbidden}}
    end
  end

  defp proof!(id) do
    {:ok, proof} =
      VerifiedExternalIdentity.establish(
        connection_id: id,
        protocol: :oidc,
        issuer: "https://identity.example.test/issuer",
        subject: "synthetic-attendance-educator",
        assurance: "mfa",
        authenticated_at: DateTime.utc_now()
      )

    proof
  end
end
