defmodule Chimwemwe.Identity.StaffDirectoryTest do
  use ExUnit.Case, async: false
  alias Ash.Resource.Info, as: ResourceInfo
  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Identity.{Error, StaffDirectory, StaffDirectoryEntry, StaffDirectoryFixture}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.{Authority, PersistenceRuntime, TrustedActor}
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, f} = StaffDirectoryFixture.seed!(persistence)
    password = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    on_exit(fn ->
      for source <- [f.source, f.account_source],
          do: if(Process.alive?(source), do: Agent.stop(source))

      {:ok, cleanup} = PersistenceRuntime.start_link(Fixture.runtime_options())

      try do
        Fixture.clear_fixture(cleanup)
        StaffDirectoryFixture.cleanup_accounts!(cleanup, f.teacher_actor_id)
      after
        Supervisor.stop(cleanup)
      end
    end)

    {:ok, StaffDirectoryFixture.bootstrap!(f, password)}
  end

  test "privileged inventory minimizes profiles and excludes an ordinary staff caller", f do
    assert {:ok,
            %{
              accounts: [account],
              eligible_staff: [candidate],
              profiles: [profile],
              truncated: false
            }} = StaffDirectory.inventory(f.persistence, Fixture.context_a())

    assert account.id == f.admin_entry_id
    assert candidate.association_id == f.teacher_association.id
    assert profile.id == f.teacher_role_id
    refute Map.has_key?(account, :hashed_password)
    refute Map.has_key?(account, :temporary_password)

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.inventory(f.persistence, f.teacher_context)

    assert {:error, _} = StaffDirectory.inventory(f.persistence, nil)
    assert {:error, _} = StaffDirectory.inventory(f.persistence, Fixture.context_b())
    assert ResourceInfo.actions(StaffDirectoryEntry) == []
    assert {:error, _} = Ash.read(StaffDirectoryEntry, tenant: tenant(), authorize?: true)
  end

  test "provisioning binds the exact staff source, grants no role, and retains no secret evidence",
       f do
    input = provision_input(f)
    assert {:ok, result} = StaffDirectory.provision(f.persistence, Fixture.context_a(), input)
    assert is_binary(result.temporary_password)
    assert String.length(result.temporary_password) >= 24
    assert is_binary(result.temporary_password_expires_at)

    assert {:ok, %{accounts: accounts, eligible_staff: []}} =
             StaffDirectory.inventory(f.persistence, Fixture.context_a())

    target = Enum.find(accounts, &(&1.id == result.id))
    assert target.email == String.downcase(String.trim(input.email))
    assert target.membership_id == f.membership_a_peer
    assert target.roles == []
    assert target.status == "pending_first_login"
    assert target.source_current
    assert target.access_state == "first_login_required"

    assert %{rows: [[hash]]} =
             query(f, "SELECT hashed_password FROM identity_accounts WHERE id=$1", [
               dump(result.account_id)
             ])

    assert hash != result.temporary_password
    assert String.starts_with?(hash, "$argon2id$")

    assert %{rows: [["restricted", payload, receipt]]} =
             query(
               f,
               "SELECT e.classification,e.payload,i.result_payload FROM platform_outbox_events e JOIN platform_authority_action_idempotency i ON i.event_id=e.id WHERE e.id=$1",
               [dump(result.event_id)]
             )

    assert Map.keys(payload) |> Enum.sort() == ["account_id", "id", "lock_version"]
    serialized = Jason.encode!(%{payload: payload, receipt: receipt})
    refute serialized =~ result.temporary_password
    refute serialized =~ target.email
    refute serialized =~ target.display_name
    assert counts(f) == [1, 1, 1]
  end

  test "exact replay returns a safe receipt once and changed input conflicts", f do
    input = provision_input(f)
    assert {:ok, first} = StaffDirectory.provision(f.persistence, Fixture.context_a(), input)
    assert {:ok, replay} = StaffDirectory.provision(f.persistence, Fixture.context_a(), input)
    assert replay.id == first.id
    assert replay.audit_reference == first.audit_reference
    assert replay.temporary_password == nil
    assert replay.temporary_password_expires_at == nil

    assert {:error, %Error{code: :idempotency_conflict}} =
             StaffDirectory.provision(f.persistence, Fixture.context_a(), %{
               input
               | display_name: "Changed synthetic name"
             })

    assert counts(f) == [1, 1, 1]
  end

  test "provisioning rejects unknown fields, missing authority and foreign or absent sources",
       f do
    input = provision_input(f)

    assert {:error, %Error{code: :invalid_input}} =
             StaffDirectory.provision(
               f.persistence,
               Fixture.context_a(),
               Map.put(input, :role, "administrator")
             )

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.provision(f.persistence, f.teacher_context, input)

    assert {:error, _} = StaffDirectory.provision(f.persistence, nil, input)

    assert {:error, %Error{code: :not_found}} =
             StaffDirectory.provision(f.persistence, Fixture.context_a(), %{
               input
               | association_id: UUID.generate()
             })

    deny(f, "identity.staff_accounts.provision")
    assert {:ok, _} = StaffDirectory.inventory(f.persistence, Fixture.context_a())

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.provision(f.persistence, Fixture.context_a(), input)

    assert counts(f) == [0, 0, 0]
  end

  test "revoked staff cannot be provisioned", f do
    assert {:ok, _} =
             People.revoke_staff_account_association(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 association_id: f.teacher_association.id,
                 expected_version: 1
               })
             )

    assert {:ok, %{eligible_staff: []}} =
             StaffDirectory.inventory(f.persistence, Fixture.context_a())

    assert {:error, %Error{code: :not_found}} =
             StaffDirectory.provision(f.persistence, Fixture.context_a(), provision_input(f))

    assert counts(f) == [0, 0, 0]
  end

  test "access assignment and removal use current tenant-defined roles and independent authority",
       f do
    result = provision!(f)

    assert {:error, _} =
             Authority.authorize(
               f.persistence,
               f.teacher_context,
               "classroom.attendance.read"
             )

    assert {:ok, granted} =
             StaffDirectory.set_access(
               f.persistence,
               Fixture.context_a(),
               access_input(f, result)
             )

    assert :ok =
             Authority.authorize(
               f.persistence,
               f.teacher_context,
               "classroom.attendance.read"
             )

    assert %{rows: [[2]]} =
             query(f, "SELECT access_version FROM identity_staff_directory_entries WHERE id=$1", [
               dump(result.id)
             ])

    assert {:ok, removed} =
             StaffDirectory.revoke_access_profile(
               f.persistence,
               Fixture.context_a(),
               access_input(f, granted)
             )

    assert removed.lock_version == 3

    assert {:error, _} =
             Authority.authorize(
               f.persistence,
               f.teacher_context,
               "classroom.attendance.read"
             )

    assert {:error, %Error{code: :stale}} =
             StaffDirectory.set_access(
               f.persistence,
               Fixture.context_a(),
               access_input(f, result)
             )
  end

  test "profile ceiling refuses direct and composed privileges and administrative self changes",
       f do
    result = provision!(f)

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.set_access(f.persistence, Fixture.context_a(), %{
               access_input(f, result)
               | profile_id: f.role_a
             })

    assert {:ok, _} =
             Fixture.query(
               f,
               "INSERT INTO platform_role_inclusions(id,tenant_id,role_id,included_role_id,inserted_at) VALUES($1,$2,$3,$4,NOW())",
               Enum.map([UUID.generate(), tenant(), f.teacher_role_id, f.role_a], &dump/1)
             )

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.set_access(
               f.persistence,
               Fixture.context_a(),
               access_input(f, result)
             )

    own = %{id: f.admin_entry_id, lock_version: 1}

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.set_access(f.persistence, Fixture.context_a(), access_input(f, own))

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.suspend_access(f.persistence, Fixture.context_a(), versioned(own))
  end

  test "tenant suspension preserves the global credential and increments access incarnation", f do
    result = provision!(f)

    assert {:ok, suspended} =
             StaffDirectory.suspend_access(f.persistence, Fixture.context_a(), versioned(result))

    assert suspended.lock_version == 2

    assert %{rows: [[false, 2, "pending_first_login"]]} =
             query(
               f,
               "SELECT d.enabled,d.access_version,a.status FROM identity_staff_directory_entries d JOIN identity_accounts a ON a.id=d.account_id WHERE d.id=$1",
               [dump(result.id)]
             )

    assert {:ok, changed} =
             StaffDirectory.set_access(
               f.persistence,
               Fixture.context_a(),
               access_input(f, suspended)
             )

    assert %{rows: [[false, 3]]} =
             query(
               f,
               "SELECT enabled,access_version FROM identity_staff_directory_entries WHERE id=$1",
               [dump(result.id)]
             )

    assert {:ok, _} =
             StaffDirectory.revoke_access_profile(
               f.persistence,
               Fixture.context_a(),
               access_input(f, changed)
             )

    assert %{rows: [[false, 4]]} =
             query(
               f,
               "SELECT enabled,access_version FROM identity_staff_directory_entries WHERE id=$1",
               [dump(result.id)]
             )
  end

  test "retained directory entries distinguish revoked source eligibility from enabled login state",
       f do
    result = provision!(f)

    assert {:ok, _} =
             People.revoke_staff_account_association(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 association_id: f.teacher_association.id,
                 expected_version: 1
               })
             )

    assert {:ok, %{accounts: accounts}} =
             StaffDirectory.inventory(f.persistence, Fixture.context_a())

    retained = Enum.find(accounts, &(&1.id == result.id))
    assert retained.enabled
    refute retained.source_current
    assert retained.status == "pending_first_login"
    assert retained.access_state == "source_unavailable"

    assert {:error, %Error{code: :not_found}} =
             StaffDirectory.set_access(
               f.persistence,
               Fixture.context_a(),
               access_input(f, result)
             )
  end

  test "profile edits preserve identity and access while stale and foreign targets fail", f do
    result = provision!(f)

    input =
      Map.merge(versioned(result), %{
        given_name: nil,
        family_name: nil,
        display_name: "Single synthetic name",
        locale: "fr"
      })

    assert {:ok, revised} =
             StaffDirectory.revise_details(f.persistence, Fixture.context_a(), input)

    assert revised.lock_version == 2

    assert %{rows: [[nil, nil, "Single synthetic name", "fr", 1]]} =
             query(
               f,
               "SELECT given_name,family_name,display_name,locale,access_version FROM identity_staff_directory_entries WHERE id=$1",
               [dump(result.id)]
             )

    assert {:error, %Error{code: :stale}} =
             StaffDirectory.revise_details(
               f.persistence,
               Fixture.context_a(),
               Map.merge(input, Fixture.keys())
             )

    assert {:error, %Error{code: :not_found}} =
             StaffDirectory.revise_details(
               f.persistence,
               Fixture.context_a(),
               Map.merge(input, %{id: UUID.generate(), idempotency_key: UUID.generate()})
             )

    assert {:error, %Error{code: :invalid_input}} =
             StaffDirectory.revise_details(
               f.persistence,
               Fixture.context_a(),
               Map.put(input, :email, "other@synthetic.test")
             )
  end

  test "self presentation contains only the caller identity and fixed navigation hints", f do
    assert {:ok, self} = StaffDirectory.preferences(f.persistence, Fixture.context_a())
    assert self.display_name == "Synthetic Account Administrator"
    assert self.navigation == %{accounts: true, classroom: true}

    assert Enum.sort(Map.keys(self)) ==
             Enum.sort([
               :id,
               :given_name,
               :family_name,
               :display_name,
               :locale,
               :lock_version,
               :navigation
             ])

    assert {:error, _} = StaffDirectory.preferences(f.persistence, nil)
    assert {:error, _} = StaffDirectory.preferences(f.persistence, Fixture.context_b())
    assert {:error, _} = StaffDirectory.preferences(f.persistence, f.teacher_context)
  end

  test "staff labels do not grant destinations and hints track profile grant and revocation", f do
    result = provision!(f)

    assert {:ok,
            %{display_name: "Synthetic Teacher", navigation: %{accounts: false, classroom: false}}} =
             StaffDirectory.preferences(f.persistence, f.teacher_context)

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.inventory(f.persistence, f.teacher_context)

    assert {:ok, granted} =
             StaffDirectory.set_access(
               f.persistence,
               Fixture.context_a(),
               access_input(f, result)
             )

    assert {:ok, %{navigation: %{accounts: false, classroom: true}}} =
             StaffDirectory.preferences(f.persistence, f.teacher_context)

    assert {:ok, _} =
             StaffDirectory.revoke_access_profile(
               f.persistence,
               Fixture.context_a(),
               access_input(f, granted)
             )

    assert {:ok, %{navigation: %{accounts: false, classroom: false}}} =
             StaffDirectory.preferences(f.persistence, f.teacher_context)
  end

  test "navigation follows module and current capability gates without allowing submitted hints",
       f do
    provision!(f)

    forged =
      Map.merge(Fixture.keys(), %{
        locale: "en",
        expected_version: 1,
        navigation: %{accounts: true, classroom: true}
      })

    assert {:error, %Error{code: :invalid_input}} =
             StaffDirectory.set_preferences(f.persistence, f.teacher_context, forged)

    deny(f, "identity.staff_accounts.read")

    assert {:ok, %{navigation: %{accounts: false, classroom: true}}} =
             StaffDirectory.preferences(f.persistence, Fixture.context_a())

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.inventory(f.persistence, Fixture.context_a())

    query(
      f,
      "UPDATE platform_module_activations a SET state='inactive',replay_from_cursor=0,projection_ready=false,reconciliation_required=true,deactivated_at=NOW() FROM platform_module_entitlements e WHERE a.entitlement_id=e.id AND e.tenant_id=$1 AND e.module_key='classroom.attendance'",
      [dump(tenant())]
    )

    assert {:ok, %{navigation: %{accounts: false, classroom: false}}} =
             StaffDirectory.preferences(f.persistence, Fixture.context_a())
  end

  test "personal language preference requires exact self eligibility and current modules, no directory permission",
       f do
    result = provision!(f)

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.inventory(f.persistence, f.teacher_context)

    assert {:ok, %{id: id, locale: "en"}} =
             StaffDirectory.preferences(f.persistence, f.teacher_context)

    assert id == result.id
    input = Map.merge(Fixture.keys(), %{locale: "fr", expected_version: 1})

    assert {:ok, _} =
             StaffDirectory.set_preferences(f.persistence, f.teacher_context, input)

    assert {:ok, %{locale: "fr", lock_version: 2}} =
             StaffDirectory.preferences(f.persistence, f.teacher_context)

    assert %{rows: [[1]]} =
             query(f, "SELECT access_version FROM identity_staff_directory_entries WHERE id=$1", [
               dump(id)
             ])

    assert {:ok, _} =
             Fixture.query(
               f,
               "UPDATE platform_module_activations a SET state='inactive',replay_from_cursor=0,projection_ready=false,reconciliation_required=true,deactivated_at=NOW() FROM platform_module_entitlements e WHERE a.entitlement_id=e.id AND e.tenant_id=$1 AND e.module_key='people.core'",
               [dump(tenant())]
             )

    assert {:error, %Error{code: :module_unavailable}} =
             StaffDirectory.preferences(f.persistence, f.teacher_context)
  end

  test "credential reissue has separate global security authority and safe replay", f do
    result = provision!(f)
    input = versioned(result)
    assert {:ok, reissued} = StaffDirectory.reissue(f.persistence, Fixture.context_a(), input)
    assert reissued.temporary_password != result.temporary_password
    assert {:ok, replay} = StaffDirectory.reissue(f.persistence, Fixture.context_a(), input)
    assert replay.temporary_password == nil
    deny(f, "identity.account_security.manage")

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.reissue(f.persistence, Fixture.context_a(), versioned(reissued))
  end

  test "administrative self-reissue is denied without changing credentials or durable evidence",
       f do
    input = versioned(%{id: f.admin_entry_id, lock_version: 1})

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.reissue(f.persistence, Fixture.context_a(), input)

    assert %{rows: [[1, "active", 1]]} =
             query(
               f,
               "SELECT a.lock_version,a.status,d.lock_version FROM identity_staff_directory_entries d JOIN identity_accounts a ON a.id=d.account_id WHERE d.id=$1",
               [dump(f.admin_entry_id)]
             )

    assert counts(f) == [0, 0, 0]
  end

  test "a tenant cannot reissue a global identity linked to a second tenant", f do
    result = provision!(f)
    other_tenant = TrustedActor.tenant_id(Fixture.context_b().actor)
    actor = TrustedActor.actor_id(f.teacher_context.actor)

    assert {:ok, _} =
             Fixture.query(
               f,
               "INSERT INTO platform_tenant_memberships(id,tenant_id,actor_id,inserted_at,updated_at) VALUES($1,$2,$3,NOW(),NOW())",
               Enum.map([UUID.generate(), other_tenant, actor], &dump/1)
             )

    assert {:error, %Error{code: :forbidden}} =
             StaffDirectory.reissue(f.persistence, Fixture.context_a(), versioned(result))

    assert %{rows: [[1]]} =
             query(f, "SELECT lock_version FROM identity_staff_directory_entries WHERE id=$1", [
               dump(result.id)
             ])
  end

  test "database guards reject identity rebinding, invalid locale and access incarnation rollback",
       f do
    result = provision!(f)

    for {sql, params} <- [
          {"UPDATE identity_staff_directory_entries SET actor_id=$2,lock_version=lock_version+1 WHERE id=$1",
           [dump(result.id), dump(UUID.generate())]},
          {"UPDATE identity_staff_directory_entries SET locale='xx',lock_version=lock_version+1 WHERE id=$1",
           [dump(result.id)]},
          {"UPDATE identity_staff_directory_entries SET enabled=false,lock_version=lock_version+1 WHERE id=$1",
           [dump(result.id)]}
        ] do
      assert {:error, %Postgrex.Error{}} = raw_query(f, sql, params)
    end

    assert %{rows: [[true, 1, 1]]} =
             query(
               f,
               "SELECT enabled,lock_version,access_version FROM identity_staff_directory_entries WHERE id=$1",
               [dump(result.id)]
             )
  end

  test "inventory access records a minimized observation and refuses an oversized set", f do
    assert {:ok, _} = StaffDirectory.inventory(f.persistence, Fixture.context_a())

    assert %{rows: [[summary]]} =
             query(
               f,
               "SELECT change_summary FROM platform_authority_audit_events WHERE action_name='identity.staff_accounts.inventory'"
             )

    assert summary == %{
             "action" => "inventory_observed",
             "account_count" => 1,
             "candidate_count" => 1
           }

    for index <- 1..25 do
      assert {:ok, _} =
               Fixture.query(
                 f,
                 "INSERT INTO platform_roles(id,tenant_id,name,lock_version,inserted_at,updated_at) VALUES($1,$2,$3,1,NOW(),NOW())",
                 [dump(UUID.generate()), dump(tenant()), "Synthetic additional role #{index}"]
               )
    end

    assert {:error, %Error{code: :scope_limit}} =
             StaffDirectory.inventory(f.persistence, Fixture.context_a())
  end

  test "failed durable evidence rolls back the credential, entry and request claim", f do
    assert {:ok, _} =
             Fixture.query(f, """
             CREATE FUNCTION test_staff_directory_completion_failure() RETURNS trigger LANGUAGE plpgsql AS $$
             BEGIN
               IF NEW.action_name='identity.staff_accounts.provision' AND NEW.status='completed' THEN
                 RAISE EXCEPTION USING ERRCODE='40001', MESSAGE='synthetic staff directory completion failure';
               END IF;
               RETURN NEW;
             END $$;
             """)

    assert {:ok, _} =
             Fixture.query(
               f,
               "CREATE TRIGGER test_staff_directory_completion_failure BEFORE UPDATE ON platform_authority_action_idempotency FOR EACH ROW EXECUTE FUNCTION test_staff_directory_completion_failure()"
             )

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               StaffDirectory.provision(f.persistence, Fixture.context_a(), provision_input(f))

      assert counts(f) == [0, 0, 0]
      actor_id = TrustedActor.actor_id(f.teacher_context.actor)

      assert %{rows: [[0]]} =
               query(f, "SELECT count(*) FROM identity_accounts WHERE actor_id=$1", [
                 dump(actor_id)
               ])

      assert {:ok, %{eligible_staff: [_]}} =
               StaffDirectory.inventory(f.persistence, Fixture.context_a())
    after
      Fixture.query(
        f,
        "DROP TRIGGER test_staff_directory_completion_failure ON platform_authority_action_idempotency"
      )

      Fixture.query(f, "DROP FUNCTION test_staff_directory_completion_failure()")
    end
  end

  defp provision!(f) do
    assert {:ok, result} =
             StaffDirectory.provision(f.persistence, Fixture.context_a(), provision_input(f))

    result
  end

  defp provision_input(f),
    do:
      Map.merge(Fixture.keys(), %{
        association_id: f.teacher_association.id,
        given_name: "Synthetic",
        family_name: "Teacher",
        display_name: "Synthetic Teacher",
        email: " Teacher@Northstar-School.test ",
        locale: "en"
      })

  defp access_input(f, result), do: Map.put(versioned(result), :profile_id, f.teacher_role_id)

  defp versioned(result),
    do: Map.merge(Fixture.keys(), %{id: result.id, expected_version: result.lock_version})

  defp tenant, do: TrustedActor.tenant_id(Fixture.context_a().actor)
  defp dump(id), do: UUID.dump!(id)

  defp query(f, sql, params \\ []) do
    assert {:ok, result} = Fixture.query(f, sql, params)
    result
  end

  defp raw_query(f, sql, params), do: Fixture.query(f, sql, params)

  defp deny(f, capability) do
    assert {:ok, _} =
             Fixture.query(
               f,
               "DELETE FROM platform_role_capability_grants g USING platform_capabilities c WHERE c.id=g.capability_id AND c.tenant_id=g.tenant_id AND c.tenant_id=$1 AND c.key=$2",
               [dump(tenant()), capability]
             )
  end

  defp counts(f) do
    %{rows: [counts]} =
      query(
        f,
        "SELECT (SELECT count(*) FROM platform_authority_audit_events WHERE aggregate_type='identity.staff_accounts.entry'),(SELECT count(*) FROM platform_outbox_events WHERE aggregate_type='identity.staff_accounts.entry'),(SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name LIKE 'identity.staff_accounts.%')"
      )

    counts
  end
end
