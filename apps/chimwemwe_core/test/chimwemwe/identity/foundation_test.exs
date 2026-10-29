defmodule Chimwemwe.Identity.TestCallbackVerifier do
  @behaviour Chimwemwe.Identity.CallbackVerifier

  alias Chimwemwe.Identity.Error

  @impl true
  def verify_code(code, expected_connection_id) do
    key = {__MODULE__, code}

    case Process.delete(key) do
      %{connection_id: ^expected_connection_id} = proof -> {:ok, proof}
      _missing_mismatch_or_replayed -> {:error, %Error{code: :forbidden}}
    end
  end

  @impl true
  def authorization_url(state, connection, oidc) do
    Process.put({__MODULE__, :authorization}, %{connection: connection, oidc: oidc, state: state})

    query =
      URI.encode_query(%{
        "code_challenge" =>
          oidc.code_verifier
          |> then(&:crypto.hash(:sha256, &1))
          |> Base.url_encode64(padding: false),
        "code_challenge_method" => "S256",
        "nonce" => oidc.nonce,
        "state" => state
      })

    {:ok, "https://identity.example.test/authorize?#{query}"}
  end

  @impl true
  def verify_code(code, expected_connection_id, context) do
    key = {__MODULE__, {:oidc, code}}

    case Process.delete(key) do
      %{connection_id: ^expected_connection_id} = proof ->
        Process.put({__MODULE__, :callback}, context)
        {:ok, proof}

      _missing_mismatch_or_replayed ->
        {:error, %Error{code: :forbidden}}
    end
  end

  def allow_once(code, proof), do: Process.put({__MODULE__, code}, proof)
  def allow_oidc_once(code, proof), do: Process.put({__MODULE__, {:oidc, code}}, proof)
end

defmodule Chimwemwe.Identity.FoundationTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias Ash.Resource.Info

  alias Chimwemwe.Identity.{
    ApplicationSession,
    ConnectionResult,
    Error,
    ExternalIdentityLink,
    Foundation,
    IdentityConnection,
    Invitation,
    InvitationResult,
    LinkResult,
    PublicCallbackResult,
    PublicRequestSession,
    PublicSessionAdapter,
    SessionFoundation,
    SessionResult,
    SessionView,
    SupportAccessGrant,
    SupportFoundation,
    SupportGrantResult,
    SupportUseResult
  }

  alias Chimwemwe.Identity.TestCallbackVerifier
  alias Chimwemwe.Identity.VerifiedExternalIdentity

  alias Chimwemwe.Platform.{
    ContextError,
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    ResourceContract,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.PublicApi.Router, as: PublicRouter
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @admin_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @target_a "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
  @target_a_peer "cececece-cece-4cec-8cec-cececececece"
  @target_b "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
  @connection_capability "identity.connections.manage"
  @invitation_capability "identity.invitations.issue"
  @support_capability "identity.support.grants.create"
  @support_use_capability "support.identity.connection.inspect"

  setup do
    previous_cookie_keys =
      Application.get_env(:chimwemwe_core, :public_session_cookie_keys)

    previous_public_api = Application.get_env(:chimwemwe_core, :public_api)

    Application.put_env(
      :chimwemwe_core,
      :public_session_cookie_keys,
      [String.duplicate("primary-public-cookie-key-", 2)]
    )

    runtime = start_supervised!({PersistenceRuntime, runtime_options()})

    Application.put_env(:chimwemwe_core, :public_api,
      runtime: runtime,
      verifier: TestCallbackVerifier,
      origin: "https://app.example.test"
    )

    clear(runtime)
    fixture = seed(runtime)

    on_exit(fn ->
      if previous_cookie_keys do
        Application.put_env(
          :chimwemwe_core,
          :public_session_cookie_keys,
          previous_cookie_keys
        )
      else
        Application.delete_env(:chimwemwe_core, :public_session_cookie_keys)
      end

      if previous_public_api do
        Application.put_env(:chimwemwe_core, :public_api, previous_public_api)
      else
        Application.delete_env(:chimwemwe_core, :public_api)
      end

      {:ok, cleanup_runtime} = PersistenceRuntime.start_link(runtime_options())
      clear(cleanup_runtime)
      Supervisor.stop(cleanup_runtime)
    end)

    {:ok, Map.put(fixture, :runtime, runtime)}
  end

  test "keeps every production identity resource closed to direct Ash writes" do
    for resource <- [
          IdentityConnection,
          ExternalIdentityLink,
          Invitation,
          ApplicationSession,
          SupportAccessGrant
        ] do
      assert [] == Info.actions(resource)

      assert :ok = ResourceContract.validate_resource(resource, Chimwemwe.Identity)
    end
  end

  test "qualifies and activates a provider-neutral connection with exact replay", fixture do
    input = connection_input()

    assert {:ok,
            %ConnectionResult{
              status: :draft,
              configuration_version: 1,
              lock_version: 1
            } = draft} =
             Foundation.register_connection(fixture.runtime, context_admin_a(), input)

    assert {:ok, ^draft} =
             Foundation.register_connection(fixture.runtime, context_admin_a(), input)

    assert {:ok, %ConnectionResult{status: :qualified, lock_version: 2} = qualified} =
             Foundation.qualify_connection(
               fixture.runtime,
               context_admin_a(),
               transition_input(draft.id, draft.lock_version)
             )

    assert {:ok, %ConnectionResult{status: :active, lock_version: 3}} =
             Foundation.activate_connection(
               fixture.runtime,
               context_admin_a(),
               transition_input(qualified.id, qualified.lock_version)
             )

    assert {:error, %Error{code: :stale}} =
             Foundation.suspend_connection(
               fixture.runtime,
               context_admin_a(),
               transition_input(qualified.id, qualified.lock_version)
             )

    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_connection(
               fixture.runtime,
               context_target_a(),
               connection_input()
             )

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.register_connection(
               fixture.runtime,
               context_admin_a(),
               Map.put(connection_input(), :provider, "microsoft")
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Foundation.register_connection(fixture.runtime, %{}, connection_input())
  end

  test "issues and atomically consumes one invitation into one identity link", fixture do
    connection = active_connection(fixture)
    invitation_input = invitation_input(fixture, connection.id)

    assert {:ok, %InvitationResult{} = invitation} =
             Foundation.issue_invitation(
               fixture.runtime,
               context_admin_a(),
               invitation_input
             )

    assert DateTime.diff(invitation.expires_at, DateTime.utc_now(), :second) in 1_790..1_800

    assert {:ok, ^invitation} =
             Foundation.issue_invitation(
               fixture.runtime,
               context_admin_a(),
               invitation_input
             )

    proof = proof(connection.id, "synthetic-subject-a")
    acceptance_input = acceptance_input(invitation.token, proof)

    assert {:ok,
            %LinkResult{
              actor_id: @target_a,
              invitation_id: invitation_id
            } = link} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input
             )

    assert invitation_id == invitation.id

    assert {:ok, ^link} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input
             )

    link_id = link.id

    assert {:ok,
            [
              [
                "accepted",
                ^link_id,
                @target_a,
                "oidc",
                "https://identity.example.test/issuer",
                "synthetic-subject-a",
                1,
                2,
                "identity.invitation.accept",
                "identity.external_identity_link.created",
                audit_change,
                outbox_payload
              ]
            ]} = committed_link(fixture.runtime, invitation.id, link.id)

    refute inspect(audit_change) =~ invitation.token
    refute inspect(outbox_payload) =~ invitation.token
    refute Map.has_key?(audit_change, "subject")
    refute Map.has_key?(outbox_payload, "subject")

    assert {:error, %Error{code: :conflict}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               %{acceptance_input | idempotency_key: UUID.generate()}
             )
  end

  test "fails closed for mismatched actor, tenant, connection, identity, and current authority",
       fixture do
    connection = active_connection(fixture)

    {:ok, invitation} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id)
      )

    assert {:error, %Error{code: :forbidden}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a_peer(),
               acceptance_input(invitation.token, proof(connection.id, "subject-a"))
             )

    assert {:error, %Error{code: :not_found}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_b(),
               acceptance_input(invitation.token, proof(connection.id, "subject-a"))
             )

    assert {:error, %Error{code: :forbidden}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input(invitation.token, proof(UUID.generate(), "subject-a"))
             )

    wrong_issuer =
      connection.id
      |> proof("subject-a")
      |> Map.replace!(:issuer, "https://other.example.test/issuer")

    assert {:error, %Error{code: :forbidden}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input(invitation.token, wrong_issuer)
             )

    remove_assignment(fixture.runtime, fixture.target_membership_a, fixture.target_role_a)

    assert {:error, %Error{code: :forbidden}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input(invitation.token, proof(connection.id, "subject-a"))
             )
  end

  test "rejects expired, revoked, duplicated, and provider-shaped authority attempts", fixture do
    connection = active_connection(fixture)

    {:ok, expired} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id)
      )

    set_invitation_expired(fixture.runtime, expired.id)

    assert {:error, %Error{code: :expired}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input(expired.token, proof(connection.id, "expired-subject"))
             )

    {:ok, revoked} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id)
      )

    revoke_invitation(fixture.runtime, revoked.id)

    assert {:error, %Error{code: :conflict}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input(revoked.token, proof(connection.id, "revoked-subject"))
             )

    {:ok, first} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id)
      )

    duplicate_proof = proof(connection.id, "stable-subject")

    assert {:ok, %LinkResult{}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input(first.token, duplicate_proof)
             )

    {:ok, second} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id,
          actor_id: @target_a_peer,
          membership_id: fixture.target_peer_membership_a,
          role_id: fixture.target_peer_role_a
        )
      )

    assert {:error, %Error{code: :conflict}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a_peer(),
               acceptance_input(second.token, duplicate_proof)
             )

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.accept_invitation(
               fixture.runtime,
               context_target_a(),
               acceptance_input(first.token, duplicate_proof)
               |> Map.put(:provider_roles, ["admin"])
             )
  end

  test "serializes concurrent exact acceptance and rolls back incomplete evidence", fixture do
    connection = active_connection(fixture)

    {:ok, invitation} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id)
      )

    input = acceptance_input(invitation.token, proof(connection.id, "concurrent-subject"))
    parent = self()

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do: (:go ->
                         Foundation.accept_invitation(fixture.runtime, context_target_a(), input))
        end)
      end

    task_pids =
      for _index <- 1..2,
          do:
            (
              assert_receive {:ready, task_pid}
              task_pid
            )

    Enum.each(task_pids, &send(&1, :go))

    assert [{:ok, first}, {:ok, second}] = Enum.map(tasks, &Task.await(&1, 10_000))
    assert first == second
    assert {:ok, [[1, 1, 1, 1]]} = identity_fact_counts(fixture.runtime, invitation.id)

    {:ok, rollback_invitation} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id)
      )

    install_completion_failure(fixture.runtime)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Foundation.accept_invitation(
                 fixture.runtime,
                 context_target_a(),
                 acceptance_input(
                   rollback_invitation.token,
                   proof(connection.id, "rollback-subject")
                 )
               )

      assert {:ok, [["pending", 0, 0, 0]]} =
               rollback_counts(fixture.runtime, rollback_invitation.id)
    after
      remove_completion_failure(fixture.runtime)
    end
  end

  test "creates, validates, and rotates an opaque session with exact replay", fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "session-subject")
    create_input = session_create_input(fixture, link.id, verified_proof)

    assert {:ok,
            %SessionResult{
              actor_id: @target_a,
              membership_id: membership_id,
              assurance: "mfa",
              lock_version: 1
            } = session} =
             SessionFoundation.create(fixture.runtime, context_target_a(), create_input)

    assert membership_id == fixture.target_membership_a

    assert {:ok, ^session} =
             SessionFoundation.create(fixture.runtime, context_target_a(), create_input)

    assert {:ok, %SessionView{id: session_id, lock_version: 2}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_a(),
               %{token: session.token}
             )

    assert session_id == session.id

    rotate_input = %{
      token: session.token,
      membership_id: fixture.target_membership_a,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

    assert {:ok, %SessionResult{} = rotated} =
             SessionFoundation.rotate_for_tenant(
               fixture.runtime,
               context_target_a(),
               rotate_input
             )

    refute rotated.id == session.id
    refute rotated.token == session.token

    assert {:ok, ^rotated} =
             SessionFoundation.rotate_for_tenant(
               fixture.runtime,
               context_target_a(),
               rotate_input
             )

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_a(),
               %{token: session.token}
             )

    assert {:ok, %SessionView{id: rotated_id}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_a(),
               %{token: rotated.token}
             )

    assert rotated_id == rotated.id

    assert {:ok, [["rotated", ^rotated_id, old_digest, new_digest, payload]]} =
             rotated_session_evidence(fixture.runtime, session.id, rotated.id)

    assert byte_size(old_digest) == 32
    assert byte_size(new_digest) == 32
    refute old_digest == new_digest
    refute inspect(payload) =~ session.token
    refute Map.has_key?(payload, "assurance")
  end

  test "fails closed for stale membership, wrong tenant, expiry, logout, and actor revocation",
       fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "session-denial-subject")

    {:ok, session} =
      SessionFoundation.create(
        fixture.runtime,
        context_target_a(),
        session_create_input(fixture, link.id, verified_proof)
      )

    assert {:error, %Error{code: :not_found}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_b(),
               %{token: session.token}
             )

    remove_membership(fixture.runtime, fixture.target_membership_a)

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_a(),
               %{token: session.token}
             )

    restore_target_membership(fixture.runtime, fixture)
    expire_session(fixture.runtime, session.id)

    assert {:error, %Error{code: :expired}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_a(),
               %{token: session.token}
             )

    %{link: logout_link, proof: logout_proof} = linked_identity(fixture, "logout-subject")

    {:ok, logout_session} =
      SessionFoundation.create(
        fixture.runtime,
        context_target_a(),
        session_create_input(fixture, logout_link.id, logout_proof)
      )

    logout_input = state_input(logout_session.token)

    assert {:ok, :logged_out} =
             SessionFoundation.logout(fixture.runtime, context_target_a(), logout_input)

    assert {:ok, :logged_out} =
             SessionFoundation.logout(fixture.runtime, context_target_a(), logout_input)

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_a(),
               %{token: logout_session.token}
             )

    %{link: revoke_link, proof: revoke_proof} = linked_identity(fixture, "revoke-subject")

    {:ok, revoked_session} =
      SessionFoundation.create(
        fixture.runtime,
        context_target_a(),
        session_create_input(fixture, revoke_link.id, revoke_proof)
      )

    revoke_input = %{idempotency_key: UUID.generate(), causation_id: UUID.generate()}

    assert {:ok, :revoked} =
             SessionFoundation.revoke_actor_sessions(
               fixture.runtime,
               context_target_a(),
               revoke_input
             )

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.validate(
               fixture.runtime,
               context_target_a(),
               %{token: revoked_session.token}
             )
  end

  test "rejects stale assurance and serializes exact session rotation", fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "session-concurrency-subject")
    stale_proof = %{verified_proof | authenticated_at: DateTime.add(DateTime.utc_now(), -601)}

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.create(
               fixture.runtime,
               context_target_a(),
               session_create_input(fixture, link.id, stale_proof)
             )

    {:ok, session} =
      SessionFoundation.create(
        fixture.runtime,
        context_target_a(),
        session_create_input(fixture, link.id, verified_proof)
      )

    input = %{
      token: session.token,
      membership_id: fixture.target_membership_a,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

    parent = self()

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          send(parent, {:session_ready, self()})

          receive do
            :go -> SessionFoundation.rotate_for_tenant(fixture.runtime, context_target_a(), input)
          end
        end)
      end

    pids =
      for _index <- 1..2 do
        assert_receive {:session_ready, pid}
        pid
      end

    Enum.each(pids, &send(&1, :go))
    assert [{:ok, first}, {:ok, second}] = Enum.map(tasks, &Task.await(&1, 10_000))
    assert first == second
  end

  test "completes one provider-neutral callback and revalidates the opaque browser cookie",
       fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "public-session-subject")
    callback_code = "single-use-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_once(callback_code, verified_proof)

    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        public_sign_in_intent(fixture, link.id, verified_proof.connection_id)
      )

    assert {:ok,
            %PublicCallbackResult{
              cookie_value: cookie,
              redirect_to: "/institutional-structure"
            } = callback} =
             PublicSessionAdapter.complete_callback(
               fixture.runtime,
               TestCallbackVerifier,
               %{code: callback_code, state: state}
             )

    refute inspect(callback) =~ cookie
    refute inspect(callback) =~ verified_proof.subject

    assert {:ok,
            %PublicRequestSession{
              session: %SessionView{
                actor_id: @target_a,
                membership_id: membership_id,
                tenant_id: @tenant_a
              },
              support: nil
            } = request} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               cookie,
               :session_read,
               "en",
               UUID.generate()
             )

    assert membership_id == fixture.target_membership_a
    refute inspect(request) =~ request.session_token
    refute inspect(request) =~ request.csrf_token

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_callback(
               fixture.runtime,
               TestCallbackVerifier,
               %{code: callback_code, state: state}
             )

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               cookie <> "tampered",
               :session_read,
               "en",
               UUID.generate()
             )

    assert {:ok, :logged_out} = PublicSessionAdapter.logout(fixture.runtime, request)

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               cookie,
               :session_read,
               "en",
               UUID.generate()
             )
  end

  test "starts one selected OIDC educator flow and completes it into an opaque session",
       fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "selected-oidc-subject")

    Application.put_env(:chimwemwe_core, :public_api,
      runtime: fixture.runtime,
      verifier: TestCallbackVerifier,
      origin: "https://app.example.test",
      sign_in: selected_sign_in(fixture, link.id, verified_proof.connection_id)
    )

    sign_in_conn =
      :get
      |> conn("/auth/sign-in")
      |> fetch_query_params()
      |> put_req_header("accept", "application/json")
      |> PublicRouter.call(PublicRouter.init([]))

    assert sign_in_conn.status == 303
    assert [location] = get_resp_header(sign_in_conn, "location")
    assert get_resp_header(sign_in_conn, "cache-control") == ["no-store"]
    assert get_resp_header(sign_in_conn, "referrer-policy") == ["no-referrer"]

    uri = URI.parse(location)
    query = URI.decode_query(uri.query)
    assert uri.scheme == "https"
    assert uri.host == "identity.example.test"
    assert query["code_challenge_method"] == "S256"
    assert byte_size(query["code_challenge"]) == 43
    assert byte_size(query["nonce"]) >= 32

    %{connection: connection, oidc: oidc, state: state} =
      Process.get({TestCallbackVerifier, :authorization})

    assert connection.id == verified_proof.connection_id
    assert connection.configuration_version == 1
    assert query["state"] == state
    assert query["nonce"] == oidc.nonce
    refute state =~ oidc.nonce
    refute state =~ oidc.code_verifier

    code = "selected-oidc-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_oidc_once(code, verified_proof)

    callback_conn =
      :get
      |> conn(
        "/auth/callback?code=#{URI.encode_www_form(code)}&state=#{URI.encode_www_form(state)}"
      )
      |> fetch_query_params()
      |> put_req_header("accept", "application/json")
      |> PublicRouter.call(PublicRouter.init([]))

    assert callback_conn.status == 303
    assert get_resp_header(callback_conn, "location") == ["/classroom"]
    assert [set_cookie] = get_resp_header(callback_conn, "set-cookie")
    assert set_cookie =~ "#{PublicSessionAdapter.cookie_name()}="

    %{connection: callback_connection, oidc: callback_oidc} =
      Process.get({TestCallbackVerifier, :callback})

    assert callback_connection == connection
    assert callback_oidc.state == state
    assert callback_oidc.code_verifier == oidc.code_verifier
    assert callback_oidc.nonce == oidc.nonce
  end

  test "keeps selected OIDC sign-in disabled and rejects caller or stale authority", fixture do
    disabled =
      :get
      |> conn("/auth/sign-in")
      |> fetch_query_params()
      |> put_req_header("accept", "application/json")
      |> PublicRouter.call(PublicRouter.init([]))

    assert disabled.status == 503

    caller_selected =
      :get
      |> conn("/auth/sign-in?tenant_id=#{@tenant_b}")
      |> fetch_query_params()
      |> put_req_header("accept", "application/json")
      |> PublicRouter.call(PublicRouter.init([]))

    assert caller_selected.status == 400

    %{link: link, proof: verified_proof} = linked_identity(fixture, "stale-oidc-subject")

    Application.put_env(:chimwemwe_core, :public_api,
      runtime: fixture.runtime,
      verifier: TestCallbackVerifier,
      origin: "https://app.example.test",
      sign_in: selected_sign_in(fixture, link.id, verified_proof.connection_id)
    )

    started =
      :get
      |> conn("/auth/sign-in")
      |> fetch_query_params()
      |> put_req_header("accept", "application/json")
      |> PublicRouter.call(PublicRouter.init([]))

    assert started.status == 303
    %{state: state} = Process.get({TestCallbackVerifier, :authorization})
    remove_membership(fixture.runtime, fixture.target_membership_a)
    Process.delete({TestCallbackVerifier, :callback})
    code = "stale-oidc-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_oidc_once(code, verified_proof)

    denied =
      :get
      |> conn(
        "/auth/callback?code=#{URI.encode_www_form(code)}&state=#{URI.encode_www_form(state)}"
      )
      |> fetch_query_params()
      |> put_req_header("accept", "application/json")
      |> PublicRouter.call(PublicRouter.init([]))

    assert denied.status == 401
    assert is_nil(Process.get({TestCallbackVerifier, :callback}))
  end

  test "rechecks the exact OIDC membership, link, and connection before redirect", fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "preflight-subject")

    assert {:ok, %{id: connection_id, configuration_version: 1}} =
             SessionFoundation.authorize_sign_in(
               fixture.runtime,
               context_target_a(),
               %{
                 connection_id: verified_proof.connection_id,
                 external_identity_link_id: link.id,
                 membership_id: fixture.target_membership_a
               }
             )

    assert connection_id == verified_proof.connection_id

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.authorize_sign_in(
               fixture.runtime,
               context_target_a(),
               %{
                 connection_id: verified_proof.connection_id,
                 external_identity_link_id: UUID.generate(),
                 membership_id: fixture.target_membership_a
               }
             )

    deactivate_link(fixture.runtime, link.id)

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.authorize_sign_in(
               fixture.runtime,
               context_target_a(),
               %{
                 connection_id: verified_proof.connection_id,
                 external_identity_link_id: link.id,
                 membership_id: fixture.target_membership_a
               }
             )

    %{link: other_link, proof: other_proof} = linked_identity(fixture, "suspended-subject")

    assert {:ok, %ConnectionResult{status: :suspended}} =
             Foundation.suspend_connection(
               fixture.runtime,
               context_admin_a(),
               transition_input(other_proof.connection_id, 3)
             )

    assert {:error, %Error{code: :forbidden}} =
             SessionFoundation.authorize_sign_in(
               fixture.runtime,
               context_target_a(),
               %{
                 connection_id: other_proof.connection_id,
                 external_identity_link_id: other_link.id,
                 membership_id: fixture.target_membership_a
               }
             )
  end

  test "rejects changed callback authority, unsafe redirects, and stale membership", fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "public-negative-subject")

    assert {:error, %Error{code: :invalid_input}} =
             fixture
             |> public_sign_in_intent(link.id, verified_proof.connection_id)
             |> Map.replace!(:redirect_to, "https://attacker.example.test/")
             |> PublicSessionAdapter.issue_sign_in_intent()

    callback_code = "changed-proof-code-#{UUID.generate()}"
    changed_proof = %{verified_proof | connection_id: UUID.generate()}
    TestCallbackVerifier.allow_once(callback_code, changed_proof)

    {:ok, changed_state} =
      PublicSessionAdapter.issue_sign_in_intent(
        public_sign_in_intent(fixture, link.id, verified_proof.connection_id)
      )

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_callback(
               fixture.runtime,
               TestCallbackVerifier,
               %{code: callback_code, state: changed_state}
             )

    valid_code = "stale-membership-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_once(valid_code, verified_proof)

    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        public_sign_in_intent(fixture, link.id, verified_proof.connection_id)
      )

    {:ok, callback} =
      PublicSessionAdapter.complete_callback(
        fixture.runtime,
        TestCallbackVerifier,
        %{code: valid_code, state: state}
      )

    remove_membership(fixture.runtime, fixture.target_membership_a)

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               callback.cookie_value,
               :session_read,
               "en",
               UUID.generate()
             )
  end

  test "accepts the bounded previous cookie key and fails after its removal", fixture do
    old_key = String.duplicate("old-public-cookie-key-", 2)
    new_key = String.duplicate("new-public-cookie-key-", 2)
    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [old_key])

    %{link: link, proof: verified_proof} = linked_identity(fixture, "rotated-cookie-subject")
    code = "old-key-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_once(code, verified_proof)

    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        public_sign_in_intent(fixture, link.id, verified_proof.connection_id)
      )

    {:ok, callback} =
      PublicSessionAdapter.complete_callback(
        fixture.runtime,
        TestCallbackVerifier,
        %{code: code, state: state}
      )

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [new_key, old_key])

    assert {:ok, %PublicRequestSession{}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               callback.cookie_value,
               :session_read,
               "en-MW",
               UUID.generate()
             )

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [new_key])

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               callback.cookie_value,
               :session_read,
               "en-MW",
               UUID.generate()
             )
  end

  test "rejects forged cookie locators and an expired authoritative session", fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "forged-cookie-subject")
    code = "forged-cookie-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_once(code, verified_proof)

    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        public_sign_in_intent(fixture, link.id, verified_proof.connection_id)
      )

    {:ok, callback} =
      PublicSessionAdapter.complete_callback(
        fixture.runtime,
        TestCallbackVerifier,
        %{code: code, state: state}
      )

    [cookie_key] = Application.fetch_env!(:chimwemwe_core, :public_session_cookie_keys)

    {:ok, envelope} =
      Phoenix.Token.decrypt(
        cookie_key,
        "chimwemwe-public-session-v1",
        callback.cookie_value,
        max_age: 12 * 60 * 60
      )

    forged_cookie =
      Phoenix.Token.encrypt(
        cookie_key,
        "chimwemwe-public-session-v1",
        %{envelope | actor_id: @target_a_peer},
        max_age: 12 * 60 * 60
      )

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               forged_cookie,
               :session_read,
               "en",
               UUID.generate()
             )

    expire_session(fixture.runtime, callback.session.id)

    assert {:error, %Error{code: :expired}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               callback.cookie_value,
               :session_read,
               "en",
               UUID.generate()
             )
  end

  test "connects callback, current-session, CSRF, and authoritative logout HTTP routes",
       fixture do
    %{link: link, proof: verified_proof} = linked_identity(fixture, "public-http-subject")
    code = "http-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_once(code, verified_proof)

    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        public_sign_in_intent(fixture, link.id, verified_proof.connection_id)
      )

    callback_conn =
      :get
      |> conn(
        "/auth/callback?code=#{URI.encode_www_form(code)}&state=#{URI.encode_www_form(state)}"
      )
      |> fetch_query_params()
      |> put_req_header("accept", "application/json")
      |> PublicRouter.call(PublicRouter.init([]))

    assert callback_conn.status == 303
    assert get_resp_header(callback_conn, "location") == ["/institutional-structure"]
    assert get_resp_header(callback_conn, "cache-control") == ["no-store"]
    assert get_resp_header(callback_conn, "x-frame-options") == ["DENY"]

    [set_cookie] = get_resp_header(callback_conn, "set-cookie")
    assert set_cookie =~ "#{PublicSessionAdapter.cookie_name()}="
    assert set_cookie =~ "; path=/"
    assert set_cookie =~ "; secure"
    assert set_cookie =~ "; HttpOnly"
    assert set_cookie =~ "; SameSite=Lax"
    refute set_cookie =~ "; domain="

    cookie_header = set_cookie |> String.split(";", parts: 2) |> hd()

    session_conn =
      :get
      |> conn("/api/v1/session")
      |> put_req_header("accept", "application/json")
      |> put_req_header("cookie", cookie_header)
      |> PublicRouter.call(PublicRouter.init([]))

    assert session_conn.status == 200

    assert %{
             "data" => %{
               "actor_id" => @target_a,
               "assurance" => "mfa",
               "csrf_token" => csrf_token,
               "support" => nil
             }
           } = Jason.decode!(session_conn.resp_body)

    denied_logout =
      :post
      |> conn("/api/v1/session/logout")
      |> put_req_header("accept", "application/json")
      |> put_req_header("cookie", cookie_header)
      |> PublicRouter.call(PublicRouter.init([]))

    assert denied_logout.status == 403

    logged_out =
      :post
      |> conn("/api/v1/session/logout")
      |> put_req_header("accept", "application/json")
      |> put_req_header("cookie", cookie_header)
      |> put_req_header("origin", "https://app.example.test")
      |> put_req_header("x-csrf-token", csrf_token)
      |> PublicRouter.call(PublicRouter.init([]))

    assert logged_out.status == 204
    assert Enum.any?(get_resp_header(logged_out, "set-cookie"), &(&1 =~ "max-age=0"))

    expired_conn =
      :get
      |> conn("/api/v1/session")
      |> put_req_header("accept", "application/json")
      |> put_req_header("cookie", cookie_header)
      |> PublicRouter.call(PublicRouter.init([]))

    assert expired_conn.status == 401
  end

  test "keeps elevated support visible and rechecks the grant on every request", fixture do
    grantor_session = actor_session(fixture, :admin, "public-support-grantor")

    {:ok, approved} =
      SupportFoundation.grant(
        fixture.runtime,
        context_admin_a(),
        support_grant_input(grantor_session.token)
      )

    %{link: link, proof: verified_proof} = linked_identity(fixture, "public-support-actor")
    code = "support-code-#{UUID.generate()}"
    TestCallbackVerifier.allow_once(code, verified_proof)

    {:ok, state} =
      PublicSessionAdapter.issue_sign_in_intent(
        public_sign_in_intent(fixture, link.id, verified_proof.connection_id)
      )

    {:ok, callback} =
      PublicSessionAdapter.complete_callback(
        fixture.runtime,
        TestCallbackVerifier,
        %{code: code, state: state}
      )

    {:ok, request} =
      PublicSessionAdapter.authenticate(
        fixture.runtime,
        callback.cookie_value,
        :support_elevate,
        "en",
        UUID.generate()
      )

    assert {:ok, elevated_cookie, %SupportGrantResult{status: :active}} =
             PublicSessionAdapter.elevate_support(fixture.runtime, request, approved.id)

    assert {:ok,
            %PublicRequestSession{
              support: %{
                grant_id: grant_id,
                support_actor_id: @target_a,
                purpose: "Investigate synthetic sign-in failure"
              }
            } = elevated} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               elevated_cookie,
               :support_use,
               "en",
               UUID.generate()
             )

    assert grant_id == approved.id

    assert {:ok, %SupportUseResult{grant_id: ^grant_id}} =
             PublicSessionAdapter.use_support(
               fixture.runtime,
               elevated,
               @support_use_capability
             )

    expire_support_grant(fixture.runtime, approved.id)

    assert {:error, %Error{code: :expired}} =
             PublicSessionAdapter.authenticate(
               fixture.runtime,
               elevated_cookie,
               :support_use,
               "en",
               UUID.generate()
             )
  end

  test "approves, activates, uses, replays, and ends one bounded support grant", fixture do
    grantor_session = actor_session(fixture, :admin, "grantor-support-subject")
    support_session = actor_session(fixture, :target, "support-actor-subject")
    grant_input = support_grant_input(grantor_session.token)

    assert {:ok,
            %SupportGrantResult{
              support_actor_id: @target_a,
              status: :approved,
              capability_scope: [@support_use_capability],
              lock_version: 1
            } = approved} =
             SupportFoundation.grant(fixture.runtime, context_admin_a(), grant_input)

    assert {:ok, ^approved} =
             SupportFoundation.grant(fixture.runtime, context_admin_a(), grant_input)

    activate_input = %{
      grant_id: approved.id,
      session_token: support_session.token,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

    assert {:ok, %SupportGrantResult{status: :active, lock_version: 2} = active} =
             SupportFoundation.activate(fixture.runtime, context_target_a(), activate_input)

    use_input = support_use_input(active.id, support_session.token)

    assert {:ok,
            %SupportUseResult{
              grant_id: grant_id,
              support_actor_id: @target_a,
              capability: @support_use_capability,
              purpose: "Investigate synthetic sign-in failure"
            } = first_use} =
             SupportFoundation.use_grant(fixture.runtime, context_target_a(), use_input)

    assert grant_id == active.id

    assert {:ok, ^first_use} =
             SupportFoundation.use_grant(fixture.runtime, context_target_a(), use_input)

    assert {:ok, [["active", 3, @target_a, @admin_a, scope, audit, outbox]]} =
             support_evidence(fixture.runtime, active.id)

    assert scope == [@support_use_capability]
    refute inspect(audit) =~ grantor_session.token
    refute inspect(outbox) =~ support_session.token
    refute Map.has_key?(outbox, "ticket_reference")

    end_input = %{
      grant_id: active.id,
      session_token: support_session.token,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

    assert {:ok, %SupportGrantResult{status: :ended, lock_version: 4}} =
             SupportFoundation.end_access(fixture.runtime, context_target_a(), end_input)

    assert {:error, %Error{code: :forbidden}} =
             SupportFoundation.use_grant(
               fixture.runtime,
               context_target_a(),
               support_use_input(active.id, support_session.token)
             )
  end

  test "rejects self approval, wildcard scope, stale assurance, background use, and wrong tenant",
       fixture do
    grantor_session = actor_session(fixture, :admin, "negative-grantor-subject")
    support_session = actor_session(fixture, :target, "negative-support-subject")

    assert {:error, %Error{code: :forbidden}} =
             SupportFoundation.grant(
               fixture.runtime,
               context_admin_a(),
               support_grant_input(grantor_session.token, support_actor_id: @admin_a)
             )

    assert {:error, %Error{code: :invalid_input}} =
             SupportFoundation.grant(
               fixture.runtime,
               context_admin_a(),
               support_grant_input(grantor_session.token, capability_scope: ["*"])
             )

    assert {:error, %Error{code: :invalid_input}} =
             SupportFoundation.grant(
               fixture.runtime,
               context_admin_a(),
               support_grant_input(grantor_session.token, duration_minutes: 61)
             )

    stale_session_assurance(fixture.runtime, grantor_session.id)

    assert {:error, %Error{code: :forbidden}} =
             SupportFoundation.grant(
               fixture.runtime,
               context_admin_a(),
               support_grant_input(grantor_session.token)
             )

    fresh_grantor = actor_session(fixture, :admin, "fresh-negative-grantor")

    {:ok, approved} =
      SupportFoundation.grant(
        fixture.runtime,
        context_admin_a(),
        support_grant_input(fresh_grantor.token)
      )

    activate_input = %{
      grant_id: approved.id,
      session_token: support_session.token,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

    assert {:error, %Error{code: :not_found}} =
             SupportFoundation.activate(fixture.runtime, context_target_b(), activate_input)

    {:ok, active} =
      SupportFoundation.activate(fixture.runtime, context_target_a(), activate_input)

    assert {:error, %Error{code: :invalid_input}} =
             SupportFoundation.use_grant(
               fixture.runtime,
               context_target_a(),
               support_use_input(active.id, support_session.token, mode: :background)
             )

    assert {:error, %Error{code: :invalid_input}} =
             SupportFoundation.use_grant(
               fixture.runtime,
               context_target_a(),
               support_use_input(active.id, support_session.token)
               |> Map.put(:impersonate_actor_id, @admin_a)
             )
  end

  test "revocation wins before later use and stale versions fail closed", fixture do
    grantor_session = actor_session(fixture, :admin, "revoke-grantor-subject")
    support_session = actor_session(fixture, :target, "revoke-support-subject")

    {:ok, approved} =
      SupportFoundation.grant(
        fixture.runtime,
        context_admin_a(),
        support_grant_input(grantor_session.token)
      )

    {:ok, active} =
      SupportFoundation.activate(fixture.runtime, context_target_a(), %{
        grant_id: approved.id,
        session_token: support_session.token,
        idempotency_key: UUID.generate(),
        causation_id: UUID.generate()
      })

    revoke_input = %{
      grant_id: active.id,
      expected_version: 2,
      grantor_session_token: grantor_session.token,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

    assert {:ok, %SupportGrantResult{status: :revoked, lock_version: 3}} =
             SupportFoundation.revoke(fixture.runtime, context_admin_a(), revoke_input)

    assert {:error, %Error{code: :forbidden}} =
             SupportFoundation.use_grant(
               fixture.runtime,
               context_target_a(),
               support_use_input(active.id, support_session.token)
             )

    assert {:error, %Error{code: :stale}} =
             SupportFoundation.revoke(
               fixture.runtime,
               context_admin_a(),
               %{revoke_input | idempotency_key: UUID.generate()}
             )
  end

  test "serializes concurrent support use and revocation and rolls back incomplete evidence",
       fixture do
    grantor_session = actor_session(fixture, :admin, "concurrent-grantor-subject")
    support_session = actor_session(fixture, :target, "concurrent-support-subject")

    {:ok, approved} =
      SupportFoundation.grant(
        fixture.runtime,
        context_admin_a(),
        support_grant_input(grantor_session.token)
      )

    {:ok, active} =
      SupportFoundation.activate(fixture.runtime, context_target_a(), %{
        grant_id: approved.id,
        session_token: support_session.token,
        idempotency_key: UUID.generate(),
        causation_id: UUID.generate()
      })

    use_input = support_use_input(active.id, support_session.token)

    revoke_input = %{
      grant_id: active.id,
      expected_version: active.lock_version,
      grantor_session_token: grantor_session.token,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

    parent = self()

    use_task =
      Task.async(fn ->
        send(parent, {:support_ready, self()})

        receive do: (:go ->
                       SupportFoundation.use_grant(fixture.runtime, context_target_a(), use_input))
      end)

    revoke_task =
      Task.async(fn ->
        send(parent, {:support_ready, self()})

        receive do
          :go -> SupportFoundation.revoke(fixture.runtime, context_admin_a(), revoke_input)
        end
      end)

    pids =
      for _index <- 1..2 do
        assert_receive {:support_ready, pid}
        pid
      end

    Enum.each(pids, &send(&1, :go))
    use_result = Task.await(use_task, 10_000)
    revoke_result = Task.await(revoke_task, 10_000)

    case {use_result, revoke_result} do
      {{:error, %Error{code: :forbidden}},
       {:ok, %SupportGrantResult{status: :revoked, lock_version: 3}}} ->
        :ok

      {{:ok, %SupportUseResult{}}, {:error, %Error{code: :stale}}} ->
        assert {:ok, %SupportGrantResult{status: :revoked, lock_version: 4}} =
                 SupportFoundation.revoke(
                   fixture.runtime,
                   context_admin_a(),
                   %{
                     revoke_input
                     | expected_version: 3,
                       idempotency_key: UUID.generate(),
                       causation_id: UUID.generate()
                   }
                 )
    end

    assert {:error, %Error{code: :forbidden}} =
             SupportFoundation.use_grant(
               fixture.runtime,
               context_target_a(),
               support_use_input(active.id, support_session.token)
             )

    rollback_grantor = actor_session(fixture, :admin, "rollback-grantor-subject")
    rollback_support = actor_session(fixture, :target, "rollback-support-subject")

    {:ok, rollback_approved} =
      SupportFoundation.grant(
        fixture.runtime,
        context_admin_a(),
        support_grant_input(rollback_grantor.token)
      )

    {:ok, rollback_active} =
      SupportFoundation.activate(fixture.runtime, context_target_a(), %{
        grant_id: rollback_approved.id,
        session_token: rollback_support.token,
        idempotency_key: UUID.generate(),
        causation_id: UUID.generate()
      })

    install_completion_failure(fixture.runtime, "identity.support_access_grant.use")

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               SupportFoundation.use_grant(
                 fixture.runtime,
                 context_target_a(),
                 support_use_input(rollback_active.id, rollback_support.token)
               )

      assert {:ok, [["active", 2, 0, 0, 0]]} =
               support_rollback_counts(fixture.runtime, rollback_active.id)
    after
      remove_completion_failure(fixture.runtime)
    end
  end

  test "expired support grants and sessions cannot be reused", fixture do
    grantor_session = actor_session(fixture, :admin, "expiry-grantor-subject")
    support_session = actor_session(fixture, :target, "expiry-support-subject")

    {:ok, approved} =
      SupportFoundation.grant(
        fixture.runtime,
        context_admin_a(),
        support_grant_input(grantor_session.token)
      )

    {:ok, active} =
      SupportFoundation.activate(fixture.runtime, context_target_a(), %{
        grant_id: approved.id,
        session_token: support_session.token,
        idempotency_key: UUID.generate(),
        causation_id: UUID.generate()
      })

    expire_support_grant(fixture.runtime, active.id)

    assert {:error, %Error{code: :expired}} =
             SupportFoundation.use_grant(
               fixture.runtime,
               context_target_a(),
               support_use_input(active.id, support_session.token)
             )

    expire_session(fixture.runtime, support_session.id)

    assert {:error, %Error{code: :expired}} =
             SupportFoundation.end_access(fixture.runtime, context_target_a(), %{
               grant_id: active.id,
               session_token: support_session.token,
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })
  end

  defp active_connection(fixture) do
    {:ok, draft} =
      Foundation.register_connection(fixture.runtime, context_admin_a(), connection_input())

    {:ok, qualified} =
      Foundation.qualify_connection(
        fixture.runtime,
        context_admin_a(),
        transition_input(draft.id, 1)
      )

    {:ok, active} =
      Foundation.activate_connection(
        fixture.runtime,
        context_admin_a(),
        transition_input(qualified.id, 2)
      )

    active
  end

  defp linked_identity(fixture, subject) do
    connection = active_connection(fixture)

    {:ok, invitation} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id)
      )

    verified_proof = proof(connection.id, subject)

    {:ok, link} =
      Foundation.accept_invitation(
        fixture.runtime,
        context_target_a(),
        acceptance_input(invitation.token, verified_proof)
      )

    %{link: link, proof: verified_proof}
  end

  defp session_create_input(fixture, link_id, verified_proof) do
    %{
      external_identity_link_id: link_id,
      membership_id: fixture.target_membership_a,
      proof: verified_proof,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp state_input(token) do
    %{token: token, idempotency_key: UUID.generate(), causation_id: UUID.generate()}
  end

  defp actor_session(fixture, actor, subject) do
    {actor_id, membership_id, role_id, context} =
      case actor do
        :admin ->
          {@admin_a, fixture.admin_membership_a, fixture.admin_role_a, context_admin_a()}

        :target ->
          {@target_a, fixture.target_membership_a, fixture.target_role_a, context_target_a()}
      end

    connection = active_connection(fixture)

    {:ok, invitation} =
      Foundation.issue_invitation(
        fixture.runtime,
        context_admin_a(),
        invitation_input(fixture, connection.id,
          actor_id: actor_id,
          membership_id: membership_id,
          role_id: role_id
        )
      )

    verified_proof = proof(connection.id, subject)

    {:ok, link} =
      Foundation.accept_invitation(
        fixture.runtime,
        context,
        acceptance_input(invitation.token, verified_proof)
      )

    {:ok, session} =
      SessionFoundation.create(fixture.runtime, context, %{
        external_identity_link_id: link.id,
        membership_id: membership_id,
        proof: verified_proof,
        idempotency_key: UUID.generate(),
        causation_id: UUID.generate()
      })

    session
  end

  defp support_grant_input(grantor_session_token, overrides \\ []) do
    %{
      support_actor_id: Keyword.get(overrides, :support_actor_id, @target_a),
      grantor_session_token: grantor_session_token,
      purpose: "Investigate synthetic sign-in failure",
      ticket_reference: "SUP-2026-0001",
      capability_scope: Keyword.get(overrides, :capability_scope, [@support_use_capability]),
      duration_minutes: Keyword.get(overrides, :duration_minutes, 60),
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp support_use_input(grant_id, session_token, overrides \\ []) do
    %{
      grant_id: grant_id,
      session_token: session_token,
      capability: Keyword.get(overrides, :capability, @support_use_capability),
      purpose: Keyword.get(overrides, :purpose, "Investigate synthetic sign-in failure"),
      mode: Keyword.get(overrides, :mode, :interactive),
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp public_sign_in_intent(fixture, link_id, connection_id) do
    %{
      actor_id: @target_a,
      tenant_id: @tenant_a,
      membership_id: fixture.target_membership_a,
      external_identity_link_id: link_id,
      connection_id: connection_id,
      locale: "en",
      redirect_to: "/institutional-structure",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp selected_sign_in(fixture, link_id, connection_id) do
    [
      actor_id: @target_a,
      tenant_id: @tenant_a,
      membership_id: fixture.target_membership_a,
      external_identity_link_id: link_id,
      connection_id: connection_id,
      locale: "en",
      redirect_to: "/classroom"
    ]
  end

  defp connection_input do
    %{
      name: "Synthetic institution #{UUID.generate()}",
      protocol: :oidc,
      issuer: "https://identity.example.test/issuer",
      application_identifier: "synthetic-client",
      secret_reference: "identity/synthetic/sign-in-secret",
      assurance_mapping: %{"synthetic-mfa" => "mfa"},
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp transition_input(connection_id, version) do
    %{
      connection_id: connection_id,
      expected_version: version,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp invitation_input(fixture, connection_id, overrides \\ []) do
    %{
      actor_id: Keyword.get(overrides, :actor_id, @target_a),
      membership_id: Keyword.get(overrides, :membership_id, fixture.target_membership_a),
      role_id: Keyword.get(overrides, :role_id, fixture.target_role_a),
      connection_id: connection_id,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp acceptance_input(token, proof) do
    %{
      token: token,
      proof: proof,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp proof(connection_id, subject) do
    {:ok, proof} =
      VerifiedExternalIdentity.establish(
        connection_id: connection_id,
        protocol: :oidc,
        issuer: "https://identity.example.test/issuer",
        subject: subject,
        assurance: "mfa",
        authenticated_at: DateTime.utc_now()
      )

    proof
  end

  defp seed(runtime) do
    ids = %{
      admin_role_a: UUID.generate(),
      target_role_a: UUID.generate(),
      target_peer_role_a: UUID.generate(),
      admin_membership_a: UUID.generate(),
      target_membership_a: UUID.generate(),
      target_peer_membership_a: UUID.generate(),
      target_membership_b: UUID.generate()
    }

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               insert_membership(ids.admin_membership_a, @tenant_a, @admin_a)
               insert_membership(ids.target_membership_a, @tenant_a, @target_a)
               insert_membership(ids.target_peer_membership_a, @tenant_a, @target_a_peer)
               insert_role(ids.admin_role_a, @tenant_a, "Identity manager")
               insert_role(ids.target_role_a, @tenant_a, "Invited role")
               insert_role(ids.target_peer_role_a, @tenant_a, "Peer invited role")

               for key <- [@connection_capability, @invitation_capability, @support_capability] do
                 capability_id = UUID.generate()
                 insert_capability(capability_id, @tenant_a, key)
                 insert_grant(@tenant_a, ids.admin_role_a, capability_id)
               end

               insert_assignment(@tenant_a, ids.admin_membership_a, ids.admin_role_a)
               insert_assignment(@tenant_a, ids.target_membership_a, ids.target_role_a)
               insert_assignment(@tenant_a, ids.target_peer_membership_a, ids.target_peer_role_a)
               :seeded
             end)

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_target_b(), fn ->
               insert_membership(ids.target_membership_b, @tenant_b, @target_b)
               :seeded
             end)

    ids
  end

  defp clear(runtime) do
    Enum.each([context_admin_a(), context_target_b()], &clear_context(runtime, &1))
  end

  defp clear_context(runtime, context) do
    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context, fn ->
               tenant_id = TrustedActor.tenant_id(context.actor)
               clear_identity_records(tenant_id)
               clear_platform_records(tenant_id)
               :cleared
             end)
  end

  defp clear_identity_records(tenant_id) do
    Repo.query!("DELETE FROM identity_support_access_grants WHERE tenant_id = $1", [
      dump(tenant_id)
    ])

    Repo.query!("DELETE FROM identity_application_sessions WHERE tenant_id = $1", [
      dump(tenant_id)
    ])

    Repo.query!("DELETE FROM identity_invitations WHERE tenant_id = $1", [dump(tenant_id)])

    Repo.query!("DELETE FROM identity_external_identity_links WHERE origin_tenant_id = $1", [
      dump(tenant_id)
    ])

    Repo.query!("DELETE FROM identity_connections WHERE tenant_id = $1", [dump(tenant_id)])
  end

  defp clear_platform_records(tenant_id) do
    Enum.each(
      [
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
      ],
      fn table ->
        Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [dump(tenant_id)])
      end
    )
  end

  defp insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      "INSERT INTO platform_tenant_memberships (id, tenant_id, actor_id, inserted_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  defp insert_role(id, tenant_id, name) do
    Repo.query!(
      "INSERT INTO platform_roles (id, tenant_id, name, lock_version, inserted_at, updated_at) VALUES ($1, $2, $3, 1, NOW(), NOW())",
      [dump(id), dump(tenant_id), name]
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
      "INSERT INTO platform_actor_role_assignments (id, tenant_id, membership_id, role_id, lock_version, inserted_at) VALUES ($1, $2, $3, $4, 1, NOW())",
      Enum.map([UUID.generate(), tenant_id, membership_id, role_id], &dump/1)
    )
  end

  defp insert_grant(tenant_id, role_id, capability_id) do
    Repo.query!(
      "INSERT INTO platform_role_capability_grants (id, tenant_id, role_id, capability_id, inserted_at) VALUES ($1, $2, $3, $4, NOW())",
      Enum.map([UUID.generate(), tenant_id, role_id, capability_id], &dump/1)
    )
  end

  defp remove_assignment(runtime, membership_id, role_id) do
    assert {:ok, _result} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "DELETE FROM platform_actor_role_assignments WHERE tenant_id = $1 AND membership_id = $2 AND role_id = $3",
                 Enum.map([@tenant_a, membership_id, role_id], &dump/1)
               )
             end)
  end

  defp remove_membership(runtime, membership_id) do
    assert {:ok, _result} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "UPDATE platform_tenant_memberships SET actor_id = $3, updated_at = NOW() WHERE tenant_id = $1 AND id = $2",
                 Enum.map([@tenant_a, membership_id, UUID.generate()], &dump/1)
               )
             end)
  end

  defp deactivate_link(runtime, link_id) do
    assert {:ok, _result} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "UPDATE identity_external_identity_links SET status = 'revoked', updated_at = NOW() WHERE origin_tenant_id = $1 AND id = $2",
                 Enum.map([@tenant_a, link_id], &dump/1)
               )
             end)
  end

  defp restore_target_membership(runtime, fixture) do
    assert {:ok, :restored} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "UPDATE platform_tenant_memberships SET actor_id = $3, updated_at = NOW() WHERE tenant_id = $1 AND id = $2",
                 Enum.map([@tenant_a, fixture.target_membership_a, @target_a], &dump/1)
               )

               :restored
             end)
  end

  defp expire_session(runtime, session_id) do
    assert {:ok, _result} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 """
                 UPDATE identity_application_sessions
                 SET inserted_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '13 hours',
                     idle_expires_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '12 hours 30 minutes',
                     absolute_expires_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '1 hour',
                     updated_at = (NOW() AT TIME ZONE 'utc')
                 WHERE tenant_id = $1 AND id = $2
                 """,
                 Enum.map([@tenant_a, session_id], &dump/1)
               )
             end)
  end

  defp stale_session_assurance(runtime, session_id) do
    assert {:ok, _result} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 """
                 UPDATE identity_application_sessions
                 SET assurance_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '6 minutes',
                     updated_at = (NOW() AT TIME ZONE 'utc')
                 WHERE tenant_id = $1 AND id = $2
                 """,
                 Enum.map([@tenant_a, session_id], &dump/1)
               )
             end)
  end

  defp expire_support_grant(runtime, grant_id) do
    assert {:ok, _result} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 """
                 UPDATE identity_support_access_grants
                 SET inserted_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '61 minutes',
                     expires_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '1 minute',
                     updated_at = (NOW() AT TIME ZONE 'utc')
                 WHERE tenant_id = $1 AND id = $2
                 """,
                 Enum.map([@tenant_a, grant_id], &dump/1)
               )
             end)
  end

  defp set_invitation_expired(runtime, invitation_id) do
    update_invitation(
      runtime,
      invitation_id,
      "inserted_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '31 minutes', " <>
        "expires_at = (NOW() AT TIME ZONE 'utc') - INTERVAL '1 minute'"
    )
  end

  defp revoke_invitation(runtime, invitation_id) do
    update_invitation(runtime, invitation_id, "status = 'revoked'")
  end

  defp update_invitation(runtime, invitation_id, update) do
    assert {:ok, _result} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "UPDATE identity_invitations SET #{update}, updated_at = NOW() WHERE tenant_id = $1 AND id = $2",
                 Enum.map([@tenant_a, invitation_id], &dump/1)
               )
             end)
  end

  defp committed_link(runtime, invitation_id, link_id) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        """
        SELECT invitation.status, link.id::text, link.actor_id::text, link.protocol,
               link.issuer, link.subject, link.connection_configuration_version,
               invitation.lock_version, audit.action_name, outbox.event_type,
               audit.change_summary, outbox.payload
        FROM identity_invitations AS invitation
        JOIN identity_external_identity_links AS link
          ON link.id = invitation.external_identity_link_id
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = invitation.tenant_id AND audit.aggregate_id = link.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        WHERE invitation.tenant_id = $1 AND invitation.id = $2 AND link.id = $3
        """,
        Enum.map([@tenant_a, invitation_id, link_id], &dump/1)
      ).rows
    end)
  end

  defp rotated_session_evidence(runtime, old_session_id, new_session_id) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        """
        SELECT old_session.status, old_session.rotated_to_session_id::text,
               old_session.token_digest, new_session.token_digest, outbox.payload
        FROM identity_application_sessions AS old_session
        JOIN identity_application_sessions AS new_session
          ON new_session.id = old_session.rotated_to_session_id
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = new_session.tenant_id AND audit.aggregate_id = new_session.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        WHERE old_session.tenant_id = $1 AND old_session.id = $2 AND new_session.id = $3
          AND audit.action_name = 'identity.application_session.rotate_for_tenant'
        """,
        Enum.map([@tenant_a, old_session_id, new_session_id], &dump/1)
      ).rows
    end)
  end

  defp support_evidence(runtime, grant_id) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        """
        SELECT support_grant.status, support_grant.lock_version,
               support_grant.support_actor_id::text,
               support_grant.grantor_actor_id::text, support_grant.capability_scope,
               audit.change_summary, outbox.payload
        FROM identity_support_access_grants AS support_grant
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = support_grant.tenant_id
         AND audit.aggregate_id = support_grant.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        WHERE support_grant.tenant_id = $1 AND support_grant.id = $2
          AND audit.action_name = 'identity.support_access_grant.use'
        """,
        Enum.map([@tenant_a, grant_id], &dump/1)
      ).rows
    end)
  end

  defp identity_fact_counts(runtime, invitation_id) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM identity_invitations WHERE tenant_id = $1 AND id = $2 AND status = 'accepted'),
          (SELECT count(*) FROM identity_external_identity_links WHERE origin_tenant_id = $1),
          (SELECT count(*) FROM platform_authority_audit_events WHERE tenant_id = $1 AND action_name = 'identity.invitation.accept'),
          (SELECT count(*) FROM platform_authority_action_idempotency WHERE tenant_id = $1 AND action_name = 'identity.invitation.accept')
        """,
        Enum.map([@tenant_a, invitation_id], &dump/1)
      ).rows
    end)
  end

  defp rollback_counts(runtime, invitation_id) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        """
        SELECT invitation.status,
          (SELECT count(*) FROM identity_external_identity_links WHERE origin_tenant_id = $1 AND subject = 'rollback-subject'),
          (SELECT count(*) FROM platform_authority_audit_events WHERE tenant_id = $1 AND action_name = 'identity.invitation.accept' AND aggregate_id NOT IN (SELECT id FROM identity_external_identity_links)),
          (SELECT count(*) FROM platform_authority_action_idempotency WHERE tenant_id = $1 AND action_name = 'identity.invitation.accept' AND status = 'started')
        FROM identity_invitations AS invitation
        WHERE invitation.tenant_id = $1 AND invitation.id = $2
        """,
        Enum.map([@tenant_a, invitation_id], &dump/1)
      ).rows
    end)
  end

  defp support_rollback_counts(runtime, grant_id) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        """
        SELECT support_grant.status, support_grant.lock_version,
          (SELECT count(*) FROM platform_authority_audit_events WHERE tenant_id = $1 AND action_name = 'identity.support_access_grant.use' AND aggregate_id = $2),
          (SELECT count(*) FROM platform_outbox_events AS outbox JOIN platform_authority_audit_events AS audit ON audit.id = outbox.audit_reference WHERE audit.tenant_id = $1 AND audit.action_name = 'identity.support_access_grant.use' AND audit.aggregate_id = $2),
          (SELECT count(*) FROM platform_authority_action_idempotency WHERE tenant_id = $1 AND action_name = 'identity.support_access_grant.use' AND aggregate_id = $2)
        FROM identity_support_access_grants AS support_grant
        WHERE support_grant.tenant_id = $1 AND support_grant.id = $2
        """,
        Enum.map([@tenant_a, grant_id], &dump/1)
      ).rows
    end)
  end

  defp install_completion_failure(runtime, action_name \\ "identity.invitation.accept") do
    assert action_name in [
             "identity.invitation.accept",
             "identity.support_access_grant.use"
           ]

    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_identity_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_identity_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_identity_completion()
               RETURNS trigger LANGUAGE plpgsql AS $$
               BEGIN
                 IF NEW.status = 'completed' AND NEW.action_name = '#{action_name}' THEN
                   RAISE EXCEPTION USING ERRCODE = '40001', MESSAGE = 'synthetic identity failure';
                 END IF;
                 RETURN NEW;
               END;
               $$
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_identity_completion
               BEFORE UPDATE OF status ON platform_authority_action_idempotency
               FOR EACH ROW EXECUTE FUNCTION test_fail_identity_completion()
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_identity_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_identity_completion()")
               :removed
             end)
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 6]],
      placements: [
        placement(@tenant_a, "pooled-identity"),
        placement(@tenant_b, "pooled-identity")
      ],
      per_tenant_limit: 6,
      per_placement_limit: 12
    ]
  end

  defp placement(tenant_id, placement_ref) do
    [
      tenant_id: tenant_id,
      routing_version: 11,
      profile: :pooled,
      placement_ref: placement_ref,
      repository: :pooled
    ]
  end

  defp context_admin_a, do: context(@admin_a, @tenant_a, "pooled-identity")
  defp context_target_a, do: context(@target_a, @tenant_a, "pooled-identity")
  defp context_target_a_peer, do: context(@target_a_peer, @tenant_a, "pooled-identity")
  defp context_target_b, do: context(@target_b, @tenant_b, "pooled-identity")

  defp context(actor_id, tenant_id, placement_ref) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 11,
        profile: :pooled,
        placement_ref: placement_ref
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: UUID.generate(),
        purpose: "identity.foundation.synthetic",
        locale: "en"
      )

    context
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
