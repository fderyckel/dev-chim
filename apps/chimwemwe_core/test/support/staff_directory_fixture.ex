defmodule Chimwemwe.Identity.StaffDirectoryFixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Chimwemwe.Classroom.{Fixture, ReviewFixture}
  alias Chimwemwe.Identity.{Account, PasswordHash}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.{Persistence, TrustedActor}
  alias Ecto.UUID

  @admin_email "accounts-admin@northstar-school.test"
  @capabilities [
    "identity.staff_accounts.read",
    "identity.staff_accounts.provision",
    "identity.staff_accounts.manage",
    "identity.staff_accounts.access",
    "identity.account_security.manage"
  ]
  @teacher_capabilities [
    "classroom.attendance.read",
    "classroom.attendance.submit",
    "classroom.attendance.correct",
    "classroom.core.classes.read"
  ]

  def admin_email, do: @admin_email

  def seed!(persistence, options \\ []) do
    {:ok, f} = Fixture.seed!(persistence)
    cleanup_accounts!(persistence)
    teacher_actor_id = UUID.generate()
    tenant = TrustedActor.tenant_id(Fixture.context_a().actor)
    teacher_context = Fixture.context(teacher_actor_id, tenant, UUID.generate())

    assert {:ok, _} =
             Fixture.query(f, "UPDATE platform_tenant_memberships SET actor_id=$2 WHERE id=$1", [
               Fixture.dump(f.membership_a_peer),
               Fixture.dump(teacher_actor_id)
             ])

    {:ok, admin_staff} = People.current_participation(f.runtime, Fixture.context_a(), f.staff.id)

    {:ok, admin_person} =
      People.current_person(f.runtime, Fixture.context_a(), admin_staff.person_id)

    assert {:ok, admin_person} =
             People.revise_person_name(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 person_id: admin_person.id,
                 expected_version: admin_person.lock_version,
                 display_name: "Synthetic Account Administrator",
                 reason: :name_correction
               })
             )

    admin_association = associate!(f, f.staff, admin_person, f.membership_a, Fixture.context_a())

    assert {:ok, teacher_person} =
             People.register_person(
               f.runtime,
               Fixture.context_a(),
               Map.put(Fixture.keys(), :display_name, "Synthetic Teacher")
             )

    teacher_staff = Fixture.participation!(f, teacher_person, :staff)

    teacher_association =
      associate!(f, teacher_staff, teacher_person, f.membership_a_peer, teacher_context)

    classroom_fixture = %{f | staff: teacher_staff}

    {class, enrolment, assignment, placement} =
      if Keyword.get(options, :review_rosters, false),
        do: ReviewFixture.staff_classrooms!(classroom_fixture),
        else: Fixture.classroom!(classroom_fixture)

    teacher_role_id = grant_directory_capabilities!(f)

    {:ok,
     Map.merge(f, %{
       account: admin_association,
       admin_association: admin_association,
       admin_person: admin_person,
       teacher_person: teacher_person,
       teacher_staff: teacher_staff,
       teacher_association: teacher_association,
       teacher_actor_id: teacher_actor_id,
       teacher_context: teacher_context,
       teacher_role_id: teacher_role_id,
       class: class,
       enrolment: enrolment,
       assignment: assignment,
       placement: placement
     })}
  end

  def cleanup_accounts!(persistence, teacher_actor_id \\ nil) do
    # Call only after the owning tenant's sessions/directory have been cleared.
    # Account identity is global, so remove only this fixture's known bootstrap
    # email and fresh staff principal, never every account in the shared database.
    assert {:ok, :cleared} =
             Persistence.with_writer(persistence, Fixture.context_a(), fn ->
               params = [
                 @admin_email,
                 "teacher@northstar-school.test",
                 teacher_actor_id && Fixture.dump(teacher_actor_id)
               ]

               Chimwemwe.Repo.query!(
                 "DELETE FROM identity_tokens WHERE subject IN (SELECT 'account?id=' || id::text FROM identity_accounts WHERE email IN ($1,$2) OR actor_id=$3::uuid)",
                 params
               )

               Chimwemwe.Repo.query!(
                 "DELETE FROM identity_accounts WHERE email IN ($1,$2) OR actor_id=$3::uuid",
                 params
               )

               :cleared
             end)
  end

  def bootstrap!(f, password) do
    assert {:ok, {:ok, account, entry_id}} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               {:ok, hash} = PasswordHash.hash(password)

               account =
                 Account
                 |> Ash.Changeset.for_create(:bootstrap_local_account, %{
                   actor_id: TrustedActor.actor_id(Fixture.context_a().actor),
                   email: @admin_email,
                   hashed_password: hash,
                   status: :active,
                   temporary_password_expires_at: nil,
                   password_changed_at: DateTime.utc_now()
                 })
                 |> Ash.create!(authorize?: false)

               entry_id = UUID.generate()

               Chimwemwe.Repo.query!(
                 """
                 INSERT INTO identity_staff_directory_entries
                   (id,tenant_id,association_id,membership_id,actor_id,account_id,
                    given_name,family_name,display_name,locale,enabled,lock_version,access_version,
                    inserted_at,updated_at)
                 VALUES ($1,$2,$3,$4,$5,$6,'Synthetic','Administrator',
                   'Synthetic Account Administrator','en',true,1,1,NOW(),NOW())
                 """,
                 Enum.map(
                   [
                     entry_id,
                     TrustedActor.tenant_id(Fixture.context_a().actor),
                     f.admin_association.id,
                     f.membership_a,
                     account.actor_id,
                     account.id
                   ],
                   &Fixture.dump/1
                 )
               )

               {:ok, account, entry_id}
             end)

    Map.merge(f, %{admin_account: account, admin_entry_id: entry_id})
  end

  defp associate!(f, participation, person, membership_id, member_context) do
    reference = UUID.generate()

    binding = %{
      tenant_id: TrustedActor.tenant_id(member_context.actor),
      person_id: person.id,
      participation_id: participation.id,
      membership_id: membership_id,
      actor_id: TrustedActor.actor_id(member_context.actor)
    }

    Agent.update(f.account_source, &put_in(&1, [:records, reference], binding))

    assert {:ok, association} =
             People.associate_staff_account(
               f.runtime,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 participation_id: participation.id,
                 expected_version: participation.lock_version,
                 expected_person_version: person.lock_version,
                 membership_id: membership_id,
                 evidence_reference: reference
               })
             )

    association
  end

  defp grant_directory_capabilities!(f) do
    tenant = TrustedActor.tenant_id(Fixture.context_a().actor)
    teacher_role_id = UUID.generate()

    assert {:ok, :seeded} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               # The eligible staff member has no authority until a separate access action.
               Chimwemwe.Repo.query!(
                 "DELETE FROM platform_actor_role_assignments WHERE tenant_id=$1 AND membership_id=$2",
                 Enum.map([tenant, f.membership_a_peer], &Fixture.dump/1)
               )

               for key <- @capabilities do
                 id = UUID.generate()
                 Fixture.insert_capability(id, tenant, key)
                 Fixture.insert_grant(tenant, f.role_a, id)
               end

               Chimwemwe.Repo.query!(
                 """
                 INSERT INTO platform_roles (id,tenant_id,name,lock_version,inserted_at,updated_at)
                 VALUES ($1,$2,'Classroom teacher',1,NOW(),NOW())
                 """,
                 Enum.map([teacher_role_id, tenant], &Fixture.dump/1)
               )

               for key <- @teacher_capabilities do
                 %{rows: [[id]]} =
                   Chimwemwe.Repo.query!(
                     "SELECT id FROM platform_capabilities WHERE tenant_id=$1 AND key=$2",
                     [Fixture.dump(tenant), key]
                   )

                 Fixture.insert_grant(tenant, teacher_role_id, UUID.load!(id))
               end

               :seeded
             end)

    teacher_role_id
  end
end
