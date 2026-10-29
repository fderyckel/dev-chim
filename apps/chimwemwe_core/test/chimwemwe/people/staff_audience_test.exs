defmodule Chimwemwe.People.StaffAudienceTest do
  use ExUnit.Case, async: false
  import Chimwemwe.People.StaffAudienceFixture
  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Identity.{LocalCredentials, SessionFoundation}
  alias Chimwemwe.People.{Error, Foundation, StaffAudience}
  alias Chimwemwe.Platform.{Persistence, PersistenceRuntime}
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, f} = Fixture.seed!(persistence)
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

      for agent <- [f.source, f.account_source],
          do: if(Process.alive?(agent), do: Agent.stop(agent))

      cleanup!()
    end)

    {:ok, connect!(f)}
  end

  test "offline recipient is eligible; absent and pending accounts stay distinct", f do
    staff!(f)
    staff!(f, account: :pending)
    absent = staff!(f, account: :absent)
    original = capture!(f)

    assert {:ok, %{audience: 4, eligible: 1, no_eligible_account: 3, no_current_access: 0}} =
             StaffAudience.eligibility(original, original)

    assert inspect(original) == "#StaffAudience.Proof<[REDACTED]>"
    account!(f, absent.actor, :active)
    current = capture!(f)

    assert {:ok, %{audience: 4, eligible: 1, no_eligible_account: 3}} =
             StaffAudience.eligibility(original, current)

    assert {:error, %Error{code: :stale}} =
             StaffAudience.recheck(f.audience, f.request, draft(), original)
  end

  test "password replacement preserves admission but invalidates prepared source version", f do
    recipient = staff!(f)
    original = capture!(f)

    assert {:ok, :rotated} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               {:ok, %{account: pending}} = LocalCredentials.reissue(recipient.account)
               password = Base.url_encode64(:crypto.strong_rand_bytes(24))

               {:ok, _} =
                 LocalCredentials.complete_first_login(
                   pending.id,
                   pending.lock_version,
                   password,
                   password
                 )

               :rotated
             end)

    current = capture!(f)
    assert {:ok, %{eligible: 1}} = StaffAudience.eligibility(original, current)

    assert {:error, %Error{code: :stale}} =
             StaffAudience.recheck(f.audience, f.request, draft(), original)
  end

  test "account actor round trip never restores original admission", f do
    recipient = staff!(f)
    original = capture!(f)
    other = UUID.generate()

    sql!(f, "UPDATE identity_accounts SET actor_id = $2 WHERE id = $1", [
      UUID.dump!(recipient.account),
      UUID.dump!(other)
    ])

    sql!(f, "UPDATE identity_accounts SET actor_id = $2 WHERE id = $1", [
      UUID.dump!(recipient.account),
      UUID.dump!(recipient.actor)
    ])

    current = capture!(f)

    assert {:ok, %{audience: 2, eligible: 0, no_current_access: 1, no_eligible_account: 1}} =
             StaffAudience.eligibility(original, current)

    refute original.subjects[recipient.person.id].admission ==
             current.subjects[recipient.person.id].admission
  end

  test "ended staff and revoked associations lose access without changing original denominator",
       f do
    recipient = staff!(f, dates: %{effective_from: Date.add(Date.utc_today(), -1)})
    original = capture!(f)

    assert {:ok, _} =
             Foundation.revoke_staff_account_association(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 association_id: recipient.association.id,
                 expected_version: 1
               })
             )

    assert {:ok, %{audience: 2, eligible: 0, no_current_access: 1}} =
             StaffAudience.eligibility(original, capture!(f))

    assert {:ok, _} =
             Foundation.end_participation(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 participation_id: recipient.part.id,
                 expected_version: 1,
                 effective_until: Date.utc_today()
               })
             )

    assert {:ok, %{audience: 2, eligible: 0, no_current_access: 1}} =
             StaffAudience.eligibility(original, capture!(f))
  end

  test "canonical draft and receipt changes, expired basis and extra selectors fail closed", f do
    original = capture!(f)
    assert {:ok, _} = StaffAudience.recheck(f.audience, f.request, draft(), original)

    for change <- [
          %{title: "Changed"},
          %{body: "Changed"},
          %{draft_version: 2},
          %{receipt_required: true}
        ] do
      assert {:error, %Error{code: :stale}} =
               StaffAudience.recheck(f.audience, f.request, Map.merge(draft(), change), original)
    end

    expired = %{original | expires_at: NaiveDateTime.add(original.resolved_at, -1)}

    assert {:error, %Error{code: :stale}} =
             StaffAudience.recheck(f.audience, f.request, draft(), expired)

    assert {:error, %Error{code: :invalid_input}} =
             StaffAudience.capture(f.audience, f.request, Map.put(draft(), :person_ids, []))
  end

  test "missing, wrong-actor, cross-tenant, stale-route, wrong-purpose and support contexts deny",
       f do
    assert {:error, _} = StaffAudience.capture(f.audience, nil, draft())

    for context <- [
          nil,
          Fixture.context_b(),
          Fixture.context_a_peer(),
          %{f.request.context | purpose: "unrelated"},
          put_in(f.request.context.placement.routing_version, 8)
        ] do
      assert {:error, _} =
               StaffAudience.capture(f.audience, %{f.request | context: context}, draft())
    end

    assert {:error, _} =
             StaffAudience.capture(f.audience, %{f.request | support: :elevated}, draft())

    assert {:error, _} =
             StaffAudience.capture(f.audience, %{f.request | session_token: "wrong"}, draft())

    {:ok, other} = StaffAudience.new(f.persistence, UUID.generate())
    assert {:error, _} = StaffAudience.capture(other, f.request, draft())
  end

  test "dedicated capability, module dependency and acting session are independently current",
       f do
    sql!(
      f,
      "DELETE FROM platform_role_capability_grants g USING platform_capabilities c WHERE g.capability_id=c.id AND c.key=$1",
      ["people.core.audiences.prepare_staff"]
    )

    assert {:error, %Error{code: :forbidden}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end

  test "0, 1, 25, 26 intended subjects never truncate", f do
    one = capture!(f)
    assert map_size(one.subjects) == 1
    for _ <- 1..24, do: staff!(f, linked: false)
    assert map_size(capture!(f).subjects) == 25
    staff!(f, linked: false)

    assert {:error, %Error{code: :scope_limit}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end

  test "an exact empty institution has zero intended subjects", f do
    alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
    unit = Fixture.institution!(f)

    assert {:ok, _} =
             Institutions.assign_initial_operator(
               f.institution_runtime,
               Fixture.context_a(),
               Fixture.assignment_input(f, unit)
             )

    assert {:ok, _} =
             Institutions.publish_institution(
               f.institution_runtime,
               Fixture.context_a(),
               Fixture.publish_input(unit.id)
             )

    {:ok, config} = StaffAudience.new(f.persistence, unit.id)
    assert {:ok, proof} = StaffAudience.capture(config, f.request, draft())

    assert {:ok, %{audience: 0, eligible: 0, no_eligible_account: 0, no_current_access: 0}} =
             StaffAudience.eligibility(proof, proof)
  end

  test "future and ended staff do not enter current intended set; traversal overflow denies", f do
    for _ <- 1..99 do
      staff!(f, linked: false, dates: %{effective_from: Date.add(Date.utc_today(), 1)})
    end

    assert map_size(capture!(f).subjects) == 1
    staff!(f, linked: false, dates: %{effective_from: Date.add(Date.utc_today(), 1)})

    assert {:error, %Error{code: :scope_limit}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end

  test "current notice permission is independent from original active-account admission", f do
    recipient = staff!(f)
    original = capture!(f)

    sql!(f, "DELETE FROM platform_actor_role_assignments WHERE membership_id = $1", [
      UUID.dump!(recipient.member)
    ])

    current = capture!(f)

    assert current.subjects[recipient.person.id].admission ==
             original.subjects[recipient.person.id].admission

    assert {:ok, %{eligible: 0, no_current_access: 1}} =
             StaffAudience.eligibility(original, current)

    assert {:ok, _} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               Fixture.insert_assignment(
                 f.request.context.actor.tenant_id,
                 recipient.member,
                 f.role_a
               )
             end)

    assert {:ok, %{eligible: 1}} = StaffAudience.eligibility(original, capture!(f))
  end

  test "student participation adds no recipient or extra authority to eligible staff", f do
    recipient = staff!(f)

    assert {:ok, _} =
             Foundation.record_student_participation(
               f.runtime,
               Fixture.context_a(),
               Fixture.participation_input(f, recipient.person)
             )

    proof = capture!(f)
    assert {:ok, %{audience: 2, eligible: 1}} = StaffAudience.eligibility(proof, proof)
  end

  test "incompatible dependency version denies independently", f do
    sql!(
      f,
      "UPDATE platform_module_activations a SET module_version='0.0.0' FROM platform_module_entitlements e WHERE a.entitlement_id=e.id AND e.tenant_id=$1 AND e.module_key='institution.structure'",
      [UUID.dump!(f.request.context.actor.tenant_id)]
    )

    assert {:error, %Error{code: :module_unavailable}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end

  test "logout before capture denies the acting request", f do
    assert {:ok, _} =
             SessionFoundation.logout(
               f.persistence,
               f.request.context,
               Map.merge(Fixture.keys(), %{token: f.request.session_token})
             )

    assert {:error, %Error{code: :forbidden}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end

  test "a replacement caller membership cannot restore an old acting session", f do
    tenant = f.request.context.actor.tenant_id
    caller = f.request.context.actor.actor_id

    sql!(f, "UPDATE platform_tenant_memberships SET actor_id=$2 WHERE id=$1", [
      UUID.dump!(f.membership_a),
      UUID.dump!(UUID.generate())
    ])

    assert {:ok, :member} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               replacement = UUID.generate()
               Fixture.insert_membership(replacement, tenant, caller)
               Fixture.insert_assignment(tenant, replacement, f.role_a)
               :member
             end)

    assert {:error, %Error{code: :forbidden}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end

  test "ending alone removes an active still-linked recipient from current subjects", f do
    r = staff!(f, dates: %{effective_from: Date.add(Date.utc_today(), -1)})
    original = capture!(f)

    assert {:ok, _} =
             Foundation.end_participation(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 participation_id: r.part.id,
                 expected_version: 1,
                 effective_until: Date.utc_today()
               })
             )

    current = capture!(f)
    refute Map.has_key?(current.subjects, r.person.id)

    assert {:ok, %{audience: 2, eligible: 0, no_current_access: 1, no_eligible_account: 1}} =
             StaffAudience.eligibility(original, current)
  end

  test "initially pending activation cannot backfill old admission", f do
    r = staff!(f, account: :pending)
    original = capture!(f)

    assert {:ok, :activated} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               password = Base.url_encode64(:crypto.strong_rand_bytes(24))
               {:ok, _} = LocalCredentials.complete_first_login(r.account, 1, password, password)
               :activated
             end)

    current = capture!(f)
    assert current.subjects[r.person.id].eligible

    assert {:ok, %{audience: 2, eligible: 0, no_eligible_account: 2}} =
             StaffAudience.eligibility(original, current)
  end

  test "suspension removes current access and cannot admit an originally suspended account", f do
    r = staff!(f)
    original = capture!(f)

    assert {:ok, _} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               LocalCredentials.suspend(r.account)
             end)

    suspended = capture!(f)

    assert {:ok, %{eligible: 0, no_current_access: 1}} =
             StaffAudience.eligibility(original, suspended)

    assert {:ok, :restored} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               {:ok, %{account: pending}} = LocalCredentials.reissue(r.account)
               password = Base.url_encode64(:crypto.strong_rand_bytes(24))

               {:ok, _} =
                 LocalCredentials.complete_first_login(
                   pending.id,
                   pending.lock_version,
                   password,
                   password
                 )

               :restored
             end)

    current = capture!(f)
    assert {:ok, %{eligible: 1}} = StaffAudience.eligibility(original, current)

    assert {:ok, %{eligible: 0, no_eligible_account: 2}} =
             StaffAudience.eligibility(suspended, current)
  end

  test "reverified association and replacement membership need new original admission", f do
    r = staff!(f)
    original = capture!(f)

    assert {:ok, _} =
             Foundation.revoke_staff_account_association(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{association_id: r.association.id, expected_version: 1})
             )

    assert {:ok, replacement} = associate!(f, r, r.member, r.actor)
    current = capture!(f)
    assert current.subjects[r.person.id].eligible

    assert {:ok, %{eligible: 0, no_current_access: 1, audience: 2}} =
             StaffAudience.eligibility(original, current)

    assert {:ok, _} =
             Foundation.revoke_staff_account_association(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{association_id: replacement.id, expected_version: 1})
             )

    actor = UUID.generate()
    member = UUID.generate()

    assert {:ok, :member} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               Fixture.insert_membership(member, f.request.context.actor.tenant_id, actor)
               Fixture.insert_assignment(f.request.context.actor.tenant_id, member, f.role_a)
               :member
             end)

    account!(f, actor, :active)
    assert {:ok, _} = associate!(f, r, member, actor)

    assert {:ok, %{eligible: 0, no_current_access: 1, audience: 2}} =
             StaffAudience.eligibility(original, capture!(f))
  end

  test "permitted student-only account and other-institution staff are excluded", f do
    alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
    unit = Fixture.institution!(f)

    assert {:ok, _} =
             Institutions.assign_initial_operator(
               f.institution_runtime,
               Fixture.context_a(),
               Fixture.assignment_input(f, unit)
             )

    assert {:ok, _} =
             Institutions.publish_institution(
               f.institution_runtime,
               Fixture.context_a(),
               Fixture.publish_input(unit.id)
             )

    other = staff!(%{f | unit: unit})
    person = Fixture.person!(f)

    assert {:ok, _} =
             Foundation.record_student_participation(
               f.runtime,
               Fixture.context_a(),
               Fixture.participation_input(f, person)
             )

    actor = UUID.generate()

    assert {:ok, _} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               member = UUID.generate()
               Fixture.insert_membership(member, f.request.context.actor.tenant_id, actor)
               Fixture.insert_assignment(f.request.context.actor.tenant_id, member, f.role_a)
             end)

    account!(f, actor, :active)
    proof = capture!(f)
    refute Map.has_key?(proof.subjects, person.id)
    refute Map.has_key?(proof.subjects, other.person.id)
    assert map_size(proof.subjects) == 1
  end

  test "renamed composed roles grant current notice permission and removal denies", f do
    r = staff!(f)
    tenant = f.request.context.actor.tenant_id
    parent = UUID.generate()
    child = UUID.generate()

    assert {:ok, :roles} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               for role <- [parent, child] do
                 Chimwemwe.Repo.query!(
                   "INSERT INTO platform_roles (id,tenant_id,name,lock_version,inserted_at,updated_at) VALUES ($1,$2,$3,1,NOW(),NOW())",
                   [UUID.dump!(role), UUID.dump!(tenant), "Synthetic role #{role}"]
                 )
               end

               Chimwemwe.Repo.query!(
                 "DELETE FROM platform_actor_role_assignments WHERE membership_id=$1",
                 [UUID.dump!(r.member)]
               )

               Fixture.insert_assignment(tenant, r.member, parent)

               Chimwemwe.Repo.query!(
                 "INSERT INTO platform_role_inclusions (id,tenant_id,role_id,included_role_id,inserted_at) VALUES ($1,$2,$3,$4,NOW())",
                 Enum.map([UUID.generate(), tenant, parent, child], &UUID.dump!/1)
               )

               [[cap]] =
                 Chimwemwe.Repo.query!(
                   "SELECT id::text FROM platform_capabilities WHERE tenant_id=$1 AND key='communications.core.notices.read'",
                   [UUID.dump!(tenant)]
                 ).rows

               Fixture.insert_grant(tenant, child, cap)
               :roles
             end)

    original = capture!(f)
    assert original.subjects[r.person.id].eligible

    sql!(
      f,
      "UPDATE platform_roles SET name='Renamed synthetic team',lock_version=lock_version+1 WHERE id=$1",
      [UUID.dump!(parent)]
    )

    assert capture!(f).subjects[r.person.id].eligible
    sql!(f, "DELETE FROM platform_role_capability_grants WHERE role_id=$1", [UUID.dump!(child)])

    assert {:ok, %{eligible: 0, no_current_access: 1}} =
             StaffAudience.eligibility(original, capture!(f))
  end

  test "reachable role and grant traversal bounds refuse overflow without partial source", f do
    tenant = f.request.context.actor.tenant_id

    assert {:ok, :roles} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               for _ <- 1..63 do
                 child = UUID.generate()

                 Chimwemwe.Repo.query!(
                   "INSERT INTO platform_roles (id,tenant_id,name,lock_version,inserted_at,updated_at) VALUES ($1,$2,$3,1,NOW(),NOW())",
                   [UUID.dump!(child), UUID.dump!(tenant), "Synthetic bound #{child}"]
                 )

                 Chimwemwe.Repo.query!(
                   "INSERT INTO platform_role_inclusions (id,tenant_id,role_id,included_role_id,inserted_at) VALUES ($1,$2,$3,$4,NOW())",
                   Enum.map([UUID.generate(), tenant, f.role_a, child], &UUID.dump!/1)
                 )
               end

               :roles
             end)

    assert {:ok, _} = StaffAudience.capture(f.audience, f.request, draft())
    child = UUID.generate()

    sql!(
      f,
      "INSERT INTO platform_roles (id,tenant_id,name,lock_version,inserted_at,updated_at) VALUES ($1,$2,'Synthetic overflow',1,NOW(),NOW())",
      [UUID.dump!(child), UUID.dump!(tenant)]
    )

    sql!(
      f,
      "INSERT INTO platform_role_inclusions (id,tenant_id,role_id,included_role_id,inserted_at) VALUES ($1,$2,$3,$4,NOW())",
      Enum.map([UUID.generate(), tenant, f.role_a, child], &UUID.dump!/1)
    )

    assert {:error, %Error{code: :scope_limit}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end

  test "combined assignments edges and grants enforce the 256 traversal cap", f do
    tenant = f.request.context.actor.tenant_id

    assert {:ok, :grants} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               for _ <- 1..256 do
                 cap = UUID.generate()

                 Fixture.insert_capability(
                   cap,
                   tenant,
                   "synthetic.bound.cap_#{String.replace(cap, "-", "")}"
                 )

                 Fixture.insert_grant(tenant, f.role_a, cap)
               end

               :grants
             end)

    assert {:error, %Error{code: :scope_limit}} =
             StaffAudience.capture(f.audience, f.request, draft())
  end
end
