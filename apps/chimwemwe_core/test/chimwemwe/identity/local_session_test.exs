defmodule Chimwemwe.Identity.LocalSessionTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Classroom.Fixture

  alias Chimwemwe.Identity.{
    Error,
    LocalCredentials,
    PasswordHash,
    PublicSessionAdapter,
    VerifiedLocalCredential
  }

  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.{Authority, Persistence, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @password "Quiet maple northern lantern 2048!"

  setup do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, f} = Fixture.seed!(persistence)
    staff_person = Fixture.person!(f)

    assert {:ok, staff} =
             People.record_staff_affiliation(
               f.runtime,
               Fixture.context_a(),
               %{
                 Fixture.participation_input(f, staff_person)
                 | effective_from: Date.add(Date.utc_today(), -1)
               }
             )

    assert {:ok, staff} = People.current_participation(f.runtime, Fixture.context_a(), staff.id)
    f = %{f | staff: staff}
    context = Fixture.context_a_denied()
    actor_id = TrustedActor.actor_id(context.actor)
    tenant_id = TrustedActor.tenant_id(context.actor)
    old_cookie_keys = Application.get_env(:chimwemwe_core, :public_session_cookie_keys)

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
      String.duplicate("synthetic-local-session-key-", 3)
    ])

    assert {:ok, :cleared} = run(f, fn -> clear_account(actor_id) end)
    evidence = UUID.generate()

    Agent.update(f.account_source, fn state ->
      put_in(state, [:records, evidence], %{
        tenant_id: tenant_id,
        person_id: f.staff.person_id,
        participation_id: f.staff.id,
        membership_id: f.membership_a_denied,
        actor_id: actor_id
      })
    end)

    assert {:ok, association} =
             People.associate_staff_account(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 participation_id: f.staff.id,
                 expected_version: f.staff.lock_version,
                 expected_person_version: 1,
                 membership_id: f.membership_a_denied,
                 evidence_reference: evidence
               })
             )

    {:ok, {:ok, provisioned}} =
      run(f, fn -> LocalCredentials.provision("local-session@example.test", actor_id) end)

    {:ok, {:ok, account}} =
      run(f, fn ->
        LocalCredentials.complete_first_login(
          provisioned.account.id,
          provisioned.account.lock_version,
          @password,
          @password
        )
      end)

    entry_id = UUID.generate()

    assert {:ok, _} =
             Fixture.query(
               f,
               """
               INSERT INTO identity_staff_directory_entries
                 (id, tenant_id, association_id, membership_id, actor_id, account_id,
                  display_name, locale, enabled, lock_version, inserted_at, updated_at)
               VALUES ($1, $2, $3, $4, $5, $6, 'Fictional staff member', 'en', TRUE, 1, NOW(), NOW())
               """,
               Enum.map(
                 [
                   entry_id,
                   tenant_id,
                   association.id,
                   f.membership_a_denied,
                   actor_id,
                   account.id
                 ],
                 &UUID.dump!/1
               )
             )

    on_exit(fn ->
      for source <- [f.source, f.account_source],
          do: if(Process.alive?(source), do: Agent.stop(source))

      if old_cookie_keys,
        do: Application.put_env(:chimwemwe_core, :public_session_cookie_keys, old_cookie_keys),
        else: Application.delete_env(:chimwemwe_core, :public_session_cookie_keys)

      {:ok, cleanup} = PersistenceRuntime.start_link(Fixture.runtime_options())

      try do
        Fixture.clear_fixture(cleanup)
        Persistence.with_writer(cleanup, Fixture.context_a(), fn -> clear_account(actor_id) end)
      after
        Supervisor.stop(cleanup)
      end
    end)

    Map.merge(f, %{
      account: account,
      association: association,
      context: context,
      entry_id: entry_id,
      target: %{tenant_id: tenant_id, membership_id: f.membership_a_denied, locale: "en"}
    })
  end

  test "a verified permanent credential establishes a local-origin opaque session and logout",
       f do
    proof = proof!(f)
    assert :ok = VerifiedLocalCredential.validate(proof)
    refute inspect(proof) =~ "seal"

    assert {:ok, cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    assert {:ok, request} = authenticate(f, cookie)
    assert request.session.actor_id == f.account.actor_id
    assert request.session.assurance == "local_password"

    assert {:error, _denied} =
             Authority.authorize(f.persistence, request.context, "identity.staff_accounts.read")

    assert {:ok, %{rows: [[nil, id, version]]}} =
             Fixture.query(
               f,
               "SELECT external_identity_link_id, local_account_id::text, local_credential_version FROM identity_application_sessions WHERE id = $1",
               [UUID.dump!(request.session.id)]
             )

    assert id == f.account.id
    assert version == f.account.lock_version
    assert {:ok, :logged_out} = PublicSessionAdapter.logout(f.persistence, request)
    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)
  end

  test "account structs, altered or expired proof and browser authority fields cannot establish sessions",
       f do
    proof = proof!(f)

    for forged <- [
          f.account,
          Map.from_struct(proof),
          %{proof | actor_id: UUID.generate()},
          %{proof | credential_version: proof.credential_version + 1},
          expired_proof(proof)
        ] do
      assert {:error, %Error{code: :forbidden}} =
               PublicSessionAdapter.complete_local_sign_in(f.persistence, forged, f.target)
    end

    assert {:error, %Error{code: :invalid_input}} =
             PublicSessionAdapter.complete_local_sign_in(
               f.persistence,
               proof,
               Map.put(f.target, :capabilities, ["*"])
             )

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, %{
               f.target
               | membership_id: f.membership_a
             })

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, %{
               f.target
               | tenant_id: TrustedActor.tenant_id(Fixture.context_b().actor),
                 membership_id: f.membership_b
             })
  end

  test "temporary credentials cannot become proof or enter a normal application session", f do
    assert {:ok, {:ok, reissued}} = run(f, fn -> LocalCredentials.reissue(f.account.id) end)

    assert {:ok, {:first_login, pending}} =
             run(f, fn ->
               VerifiedLocalCredential.authenticate(f.account.email, reissued.temporary_password)
             end)

    assert pending.status == :pending_first_login

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, pending, f.target)
  end

  test "reissue and suspension invalidate prior proof and already-open application sessions", f do
    proof = proof!(f)

    assert {:ok, cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    assert {:ok, _} = authenticate(f, cookie)
    assert {:ok, {:ok, reissued}} = run(f, fn -> LocalCredentials.reissue(f.account.id) end)
    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    assert {:ok, {:ok, _}} =
             run(f, fn ->
               LocalCredentials.complete_first_login(
                 f.account.id,
                 reissued.account.lock_version,
                 @password,
                 @password
               )
             end)

    next_proof = proof!(f)

    assert {:ok, next_cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, next_proof, f.target)

    assert {:ok, {:ok, _}} = run(f, fn -> LocalCredentials.suspend(f.account.id) end)
    assert {:error, %Error{code: :forbidden}} = authenticate(f, next_cookie)
  end

  test "institution suspension and source revocation block current sessions immediately", f do
    proof = proof!(f)

    assert {:ok, cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    assert {:ok, _} =
             Fixture.query(
               f,
               "UPDATE identity_staff_directory_entries SET enabled = FALSE, lock_version = lock_version + 1, access_version = access_version + 1, updated_at = NOW() WHERE id = $1",
               [UUID.dump!(f.entry_id)]
             )

    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)

    assert {:ok, _} =
             Fixture.query(
               f,
               "UPDATE identity_staff_directory_entries SET enabled = TRUE, lock_version = lock_version + 1, access_version = access_version + 1, updated_at = NOW() WHERE id = $1",
               [UUID.dump!(f.entry_id)]
             )

    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)

    assert {:ok, fresh_cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof!(f), f.target)

    assert {:ok, _} =
             People.revoke_staff_account_association(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{association_id: f.association.id, expected_version: 1})
             )

    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)
    assert {:error, %Error{code: :forbidden}} = authenticate(f, fresh_cookie)
  end

  test "a password-verification race with reissue never preserves access after replacement", f do
    proof = proof!(f)

    login =
      Task.async(fn ->
        PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)
      end)

    replacement = Task.async(fn -> run(f, fn -> LocalCredentials.reissue(f.account.id) end) end)
    assert {:ok, {:ok, _}} = Task.await(replacement)

    case Task.await(login) do
      {:ok, cookie} -> assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)
      {:error, %Error{code: code}} -> assert code in [:forbidden, :retryable_dependency]
    end
  end

  test "ending staff participation denies both current sessions and fresh login admission", f do
    proof = proof!(f)

    assert {:ok, cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    assert {:ok, _} =
             People.end_participation(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 participation_id: f.staff.id,
                 expected_version: 1,
                 effective_until: Date.utc_today()
               })
             )

    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof!(f), f.target)
  end

  test "the database refuses absent, ambiguous and incomplete session origin", f do
    assert {:ok, cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof!(f), f.target)

    assert {:ok, request} = authenticate(f, cookie)

    for change <- [
          "local_account_id = NULL, local_credential_version = NULL, local_access_version = NULL",
          "local_credential_version = NULL",
          "local_credential_fingerprint = NULL",
          "local_credential_fingerprint = decode('00', 'hex')",
          "local_access_version = NULL",
          "external_identity_link_id = '#{UUID.generate()}'::uuid"
        ] do
      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
               Fixture.query(
                 f,
                 "UPDATE identity_application_sessions SET #{change} WHERE id = $1",
                 [UUID.dump!(request.session.id)]
               )
    end
  end

  test "alternate SQL password replacement invalidates proof and session without a version bump",
       f do
    proof = proof!(f)

    assert {:ok, cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    replacement_password = "Different mountain silver lantern 2049!"
    assert {:ok, replacement_hash} = PasswordHash.hash(replacement_password)

    assert {:ok, _} =
             Fixture.query(f, "UPDATE identity_accounts SET hashed_password = $2 WHERE id = $1", [
               UUID.dump!(f.account.id),
               replacement_hash
             ])

    assert {:ok, %{rows: [[unchanged_version]]}} =
             Fixture.query(f, "SELECT lock_version FROM identity_accounts WHERE id = $1", [
               UUID.dump!(f.account.id)
             ])

    assert unchanged_version == proof.credential_version
    assert :ok = VerifiedLocalCredential.validate(proof)
    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    assert {:ok, {:ok, replacement_proof}} =
             run(f, fn ->
               VerifiedLocalCredential.authenticate(f.account.email, replacement_password)
             end)

    assert {:ok, replacement_cookie} =
             PublicSessionAdapter.complete_local_sign_in(
               f.persistence,
               replacement_proof,
               f.target
             )

    assert {:ok, _} = authenticate(f, replacement_cookie)
  end

  test "an alternate SQL actor round trip never restores old proof or session admission", f do
    proof = proof!(f)

    assert {:ok, cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    for actor_id <- [UUID.generate(), f.account.actor_id] do
      assert {:ok, _} =
               Fixture.query(f, "UPDATE identity_accounts SET actor_id = $2 WHERE id = $1", [
                 UUID.dump!(f.account.id),
                 UUID.dump!(actor_id)
               ])
    end

    assert {:ok, %{rows: [[unchanged_version]]}} =
             Fixture.query(f, "SELECT lock_version FROM identity_accounts WHERE id = $1", [
               UUID.dump!(f.account.id)
             ])

    assert unchanged_version == proof.credential_version
    assert :ok = VerifiedLocalCredential.validate(proof)
    assert {:error, %Error{code: :forbidden}} = authenticate(f, cookie)

    assert {:error, %Error{code: :forbidden}} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof, f.target)

    assert {:ok, fresh_cookie} =
             PublicSessionAdapter.complete_local_sign_in(f.persistence, proof!(f), f.target)

    assert {:ok, _} = authenticate(f, fresh_cookie)
  end

  defp proof!(f) do
    assert {:ok, {:ok, proof}} =
             run(f, fn -> VerifiedLocalCredential.authenticate(f.account.email, @password) end)

    proof
  end

  defp expired_proof(proof) do
    expired = %{proof | authenticated_at: DateTime.add(DateTime.utc_now(), -61, :second)}

    fields = [
      :id,
      :account_id,
      :actor_id,
      :credential_version,
      :credential_fingerprint,
      :assurance,
      :authenticated_at
    ]

    seal =
      :crypto.mac(
        :hmac,
        :sha256,
        Application.fetch_env!(:chimwemwe_core, :identity_session_hmac_secret),
        :erlang.term_to_binary(
          {"chimwemwe-local-credential-v1", Map.take(expired, fields)},
          [:deterministic]
        )
      )

    %{expired | seal: seal}
  end

  defp authenticate(f, cookie),
    do:
      PublicSessionAdapter.authenticate(
        f.persistence,
        cookie,
        :session_read,
        "en",
        UUID.generate()
      )

  defp run(f, function),
    do: Persistence.with_writer(f.persistence, Fixture.context_a(), function)

  defp clear_account(actor_id) do
    Repo.query!(
      "DELETE FROM identity_tokens WHERE subject IN (SELECT 'account?id=' || id::text FROM identity_accounts WHERE actor_id = $1)",
      [UUID.dump!(actor_id)]
    )

    Repo.query!("DELETE FROM identity_accounts WHERE actor_id = $1", [UUID.dump!(actor_id)])
    :cleared
  end
end
