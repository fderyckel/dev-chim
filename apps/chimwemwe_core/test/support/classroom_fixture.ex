defmodule Chimwemwe.Classroom.Fixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Chimwemwe.Classroom.Foundation
  alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
  alias Chimwemwe.OrganizationLegal.Foundation, as: LegalFoundation
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.People.{Runtime, TestVerifier}

  alias Chimwemwe.Platform.{
    ExecutionContext,
    Persistence,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID
  @tenant_a "41414141-4141-4141-8141-414141414141"
  @tenant_b "42424242-4242-4242-8242-424242424242"
  @actor_a "a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1"
  @actor_a_peer "a2a2a2a2-a2a2-42a2-82a2-a2a2a2a2a2a2"
  @actor_a_denied "a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3"
  @actor_b "b1b1b1b1-b1b1-41b1-81b1-b1b1b1b1b1b1"
  @manage_capability "institution.structure.institutions.register"
  @read_capability "institution.structure.institutions.read"
  @assign_capability "institution.structure.operators.assign_initial"
  @publish_capability "institution.structure.institutions.publish"

  @people_capabilities [
    "persons.register",
    "persons.revise_name",
    "persons.read",
    "participations.record_student",
    "participations.record_staff",
    "participations.end",
    "participations.read",
    "accounts.associate_staff",
    "accounts.revoke",
    "accounts.read"
  ]
  def seed!(persistence) do
    clear_fixture(persistence)
    ids = seed_foundation(persistence)
    {:ok, source} = Agent.start_link(fn -> %{records: %{}, overrides: %{}, calls: 0} end)

    {:ok, institution_runtime} =
      Chimwemwe.InstitutionalStructure.Runtime.new(
        persistence,
        Chimwemwe.InstitutionalStructure.TestVerifier,
        source
      )

    {:ok, account_source} = Agent.start_link(fn -> %{records: %{}, overrides: %{}, calls: 0} end)
    {:ok, runtime} = Runtime.new(persistence, TestVerifier, account_source)

    f =
      Map.merge(ids, %{
        persistence: persistence,
        institution_runtime: institution_runtime,
        runtime: runtime,
        source: source,
        account_source: account_source
      })

    unit = institution!(f)
    assignment = assignment_input(f, unit)

    assert {:ok, _} =
             Institutions.assign_initial_operator(institution_runtime, context_a(), assignment)

    assert {:ok, _} =
             Institutions.publish_institution(
               institution_runtime,
               context_a(),
               publish_input(unit.id)
             )

    f = Map.put(f, :unit, unit)
    calendar = calendar!(f)
    student = participation!(f, person!(f), :student)
    staff = participation!(f, person!(f), :staff)
    {:ok, Map.merge(f, %{calendar: calendar, student: student, staff: staff})}
  end

  def classroom!(f) do
    class = class!(f)
    enrolment = enrolment!(f)

    assert {:ok, assignment} =
             Foundation.assign_teacher(f.persistence, context_a(), teacher_input(f, class))

    assert {:ok, placement} =
             Foundation.place_student(
               f.persistence,
               context_a(),
               placement_input(enrolment, class)
             )

    {class, enrolment, assignment, placement}
  end

  def class!(f) do
    assert {:ok, class} = Foundation.create_class(f.persistence, context_a(), class_input(f))
    class
  end

  def enrolment!(f) do
    assert {:ok, enrolment} = Foundation.enrol_student(f.persistence, context_a(), enrol_input(f))
    enrolment
  end

  def class_input(f),
    do:
      Map.merge(keys(), %{
        institutional_unit_id: f.unit.id,
        calendar_id: f.calendar.id,
        academic_year_id: f.calendar.year_id,
        calendar_revision: f.calendar.revision,
        code: "class_" <> String.replace(UUID.generate(), "-", ""),
        label: "Synthetic class"
      })

  def enrol_input(f),
    do:
      Map.merge(keys(), %{
        participation_id: f.student.id,
        expected_participation_version: 1,
        academic_year_id: f.calendar.year_id,
        calendar_revision: f.calendar.revision,
        effective_from: Date.utc_today(),
        effective_until: Date.add(Date.utc_today(), 200)
      })

  def teacher_input(f, class),
    do:
      Map.merge(keys(), %{
        participation_id: f.staff.id,
        expected_participation_version: 1,
        class_id: class.id,
        expected_class_version: 1,
        effective_from: Date.utc_today(),
        effective_until: Date.add(Date.utc_today(), 100)
      })

  def placement_input(enrolment, class),
    do:
      Map.merge(keys(), %{
        enrolment_id: enrolment.id,
        expected_enrolment_version: 1,
        class_id: class.id,
        expected_class_version: 1,
        effective_from: Date.utc_today(),
        effective_until: Date.add(Date.utc_today(), 100)
      })

  def ending(key, id),
    do:
      Map.merge(keys(), %{
        key => id,
        :expected_version => 1,
        :effective_until => Date.add(Date.utc_today(), 30)
      })

  # Exercise the calendar agent's real named writer, using only synthetic records.
  def calendar!(f, status \\ "published", options \\ []) do
    alias Chimwemwe.AcademicCalendar.Foundation, as: Calendar
    {:ok, runtime} = Chimwemwe.AcademicCalendar.Runtime.new(f.persistence)

    assert {:ok, calendar} =
             Calendar.register_academic_calendar(
               runtime,
               context_a(),
               Map.merge(keys(), %{
                 institutional_unit_id: f.unit.id,
                 code: "calendar_" <> String.replace(UUID.generate(), "-", "")
               })
             )

    year_id = UUID.generate()
    start_on = Keyword.get(options, :start_on, Date.utc_today())

    definition =
      Map.merge(keys(), %{
        academic_year_id: year_id,
        calendar_id: calendar.id,
        code: "year",
        label: "Synthetic year",
        start_on: start_on,
        end_on: Date.add(Date.utc_today(), 365),
        time_zone: Keyword.get(options, :time_zone, "Etc/UTC"),
        instructional_weekdays: Keyword.get(options, :weekdays, [1, 2, 3, 4, 5, 6, 7]),
        closures: [],
        periods: [
          %{
            id: UUID.generate(),
            period_type_key: "term",
            sequence: 1,
            label: "Synthetic term",
            start_on: start_on,
            end_on: Date.add(Date.utc_today(), 365)
          }
        ]
      })

    assert {:ok, draft} = Calendar.define_draft_academic_year(runtime, context_a(), definition)

    if status == "published" do
      assert {:ok, _} =
               Calendar.publish_academic_year(
                 runtime,
                 context_a(),
                 Map.merge(keys(), %{
                   calendar_id: calendar.id,
                   academic_year_id: year_id,
                   expected_version: draft.lock_version
                 })
               )
    end

    %{id: calendar.id, year_id: year_id, revision: draft.candidate_revision}
  end

  def keys, do: %{idempotency_key: UUID.generate(), causation_id: UUID.generate()}
  def person_input, do: Map.put(keys(), :display_name, "Synthetic Person")

  def person!(f) do
    assert {:ok, person} = People.register_person(f.runtime, context_a(), person_input())
    person
  end

  def participation_input(f, person),
    do:
      Map.merge(keys(), %{
        person_id: person.id,
        expected_person_version: person.lock_version,
        institutional_unit_id: f.unit.id,
        effective_from: Date.utc_today(),
        effective_until: nil,
        source_reference: UUID.generate()
      })

  def participation!(f, person, kind) do
    action = if kind == :staff, do: :record_staff_affiliation, else: :record_student_participation

    assert {:ok, part} =
             apply(People, action, [f.runtime, context_a(), participation_input(f, person)])

    part
  end

  def deny(f, capability) do
    assert {:ok, _} =
             query(
               f,
               "DELETE FROM platform_role_capability_grants g USING platform_capabilities c WHERE g.capability_id = c.id AND g.tenant_id = c.tenant_id AND c.tenant_id = $1 AND c.key = $2",
               [dump(@tenant_a), "classroom.core." <> capability]
             )
  end

  def register_input do
    %{
      display_name: "Synthetic Learning Institution",
      time_zone: "Etc/UTC",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  def institution!(f) do
    assert {:ok, unit} =
             Institutions.register_institution(
               f.institution_runtime,
               context_a(),
               register_input()
             )

    unit
  end

  def publish_input(id),
    do: %{
      institutional_unit_id: id,
      expected_version: 2,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

  def assignment_input(f, unit, context \\ context_a()) do
    assert {:ok, entity} =
             LegalFoundation.register_legal_entity(f.persistence, context, %{
               official_name: "Synthetic Operator",
               display_name: "Operator",
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    reference = UUID.generate()

    binding = %{
      tenant_id: TrustedActor.tenant_id(context.actor),
      institutional_unit_id: unit.id,
      legal_entity_id: entity.id
    }

    Agent.update(f.source, &put_in(&1, [:records, reference], binding))

    %{
      institutional_unit_id: unit.id,
      expected_version: 1,
      legal_entity_id: entity.id,
      legal_entity_version: entity.lock_version,
      evidence_reference: reference,
      effective_from: Date.utc_today(),
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  def query(f, sql, params \\ []) do
    {:ok, value} =
      Persistence.with_writer(f.persistence, context_a(), fn -> Repo.query(sql, params) end)

    value
  end

  def facts(f) do
    {:ok, %{rows: rows}} =
      query(
        f,
        "SELECT (SELECT count(*) FROM platform_authority_audit_events WHERE action_name LIKE 'classroom.core.%'), (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type LIKE 'classroom.core.%'), (SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name LIKE 'classroom.core.%')"
      )

    rows
  end

  def seed_foundation(runtime) do
    ids = %{
      membership_a: UUID.generate(),
      membership_a_peer: UUID.generate(),
      membership_a_denied: UUID.generate(),
      membership_b: UUID.generate(),
      role_a: UUID.generate(),
      role_b: UUID.generate(),
      manage_capability_a: UUID.generate(),
      read_capability_a: UUID.generate(),
      assign_capability_a: UUID.generate(),
      publish_capability_a: UUID.generate(),
      manage_capability_b: UUID.generate(),
      read_capability_b: UUID.generate(),
      assign_capability_b: UUID.generate(),
      publish_capability_b: UUID.generate()
    }

    seed_tenant(
      runtime,
      context_a(),
      @tenant_a,
      [
        {ids.membership_a, @actor_a, true},
        {ids.membership_a_peer, @actor_a_peer, true},
        {ids.membership_a_denied, @actor_a_denied, false}
      ],
      ids.role_a,
      %{
        manage: ids.manage_capability_a,
        read: ids.read_capability_a,
        relationships: ids.assign_capability_a,
        corporate_units: ids.publish_capability_a
      }
    )

    seed_tenant(
      runtime,
      context_b(),
      @tenant_b,
      [{ids.membership_b, @actor_b, true}],
      ids.role_b,
      %{
        manage: ids.manage_capability_b,
        read: ids.read_capability_b,
        relationships: ids.assign_capability_b,
        corporate_units: ids.publish_capability_b
      }
    )

    ids
  end

  def seed_tenant(
        runtime,
        context,
        tenant_id,
        memberships,
        role_id,
        capability_ids
      ) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_role(role_id, tenant_id)

               Enum.each(
                 memberships,
                 &seed_membership(&1, tenant_id, role_id)
               )

               insert_capability(capability_ids.manage, tenant_id, @manage_capability)
               insert_capability(capability_ids.read, tenant_id, @read_capability)

               insert_capability(
                 capability_ids.relationships,
                 tenant_id,
                 @assign_capability
               )

               insert_capability(
                 capability_ids.corporate_units,
                 tenant_id,
                 @publish_capability
               )

               insert_grant(tenant_id, role_id, capability_ids.manage)
               insert_grant(tenant_id, role_id, capability_ids.read)
               insert_grant(tenant_id, role_id, capability_ids.relationships)
               insert_grant(tenant_id, role_id, capability_ids.corporate_units)
               extra = UUID.generate()
               insert_capability(extra, tenant_id, "organization.legal.entities.manage")
               insert_grant(tenant_id, role_id, extra)

               for key <- @people_capabilities do
                 id = UUID.generate()
                 insert_capability(id, tenant_id, "people.core." <> key)
                 insert_grant(tenant_id, role_id, id)
               end

               for key <- [
                     "classes.create",
                     "classes.read",
                     "enrolments.record",
                     "enrolments.end",
                     "enrolments.read",
                     "assignments.record",
                     "assignments.end",
                     "assignments.read",
                     "placements.record",
                     "placements.end",
                     "placements.read"
                   ] do
                 id = UUID.generate()
                 insert_capability(id, tenant_id, "classroom.core." <> key)
                 insert_grant(tenant_id, role_id, id)
               end

               for key <- [
                     "academics.calendar.definition.manage",
                     "academics.calendar.publication.publish",
                     "academics.calendar.read",
                     "classroom.attendance.read",
                     "classroom.attendance.submit",
                     "classroom.attendance.correct",
                     "identity.connections.manage",
                     "identity.invitations.issue"
                   ] do
                 id = UUID.generate()
                 insert_capability(id, tenant_id, key)
                 insert_grant(tenant_id, role_id, id)
               end

               insert_active_module(tenant_id)
               :seeded
             end)
  end

  def seed_membership({membership_id, actor_id, assigned?}, tenant_id, role_id) do
    insert_membership(membership_id, tenant_id, actor_id)
    if assigned?, do: insert_assignment(tenant_id, membership_id, role_id)
  end

  def insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      """
      INSERT INTO platform_tenant_memberships
        (id, tenant_id, actor_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  def insert_role(id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, 'Synthetic people administrator', 1, NOW(), NOW())
      """,
      Enum.map([id, tenant_id], &dump/1)
    )
  end

  def insert_capability(id, tenant_id, key) do
    Repo.query!(
      """
      INSERT INTO platform_capabilities
        (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), key]
    )
  end

  def insert_assignment(tenant_id, membership_id, role_id) do
    Repo.query!(
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, lock_version, inserted_at)
      VALUES ($1, $2, $3, $4, 1, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, membership_id, role_id], &dump/1)
    )
  end

  def insert_grant(tenant_id, role_id, capability_id) do
    Repo.query!(
      """
      INSERT INTO platform_role_capability_grants
        (id, tenant_id, role_id, capability_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, role_id, capability_id], &dump/1)
    )
  end

  def insert_active_module(tenant_id) do
    for {key, version} <- [
          {"organization.legal", "1.2.0"},
          {"institution.structure", "1.0.0"},
          {"people.core", "1.0.0"},
          {"academics.calendar", "1.0.0"},
          {"classroom.core", "1.0.0"},
          {"classroom.attendance", "1.1.0"}
        ] do
      entitlement = UUID.generate()

      Repo.query!(
        "INSERT INTO platform_module_entitlements (id, tenant_id, module_key, inserted_at) VALUES ($1, $2, $3, NOW())",
        [dump(entitlement), dump(tenant_id), key]
      )

      Repo.query!(
        "INSERT INTO platform_module_activations (id, tenant_id, entitlement_id, module_version, state, lock_version, activated_at, inserted_at, updated_at) VALUES ($1, $2, $3, $4, 'active', 1, NOW(), NOW(), NOW())",
        [dump(UUID.generate()), dump(tenant_id), dump(entitlement), version]
      )
    end
  end

  def install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_classroom_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_classroom_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_classroom_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.action_name LIKE 'classroom.core.%' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic legal entity completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_classroom_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_classroom_completion();
               """)

               :installed
             end)
  end

  def remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_classroom_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_classroom_completion()")
               :removed
             end)
  end

  def clear_fixture(runtime) do
    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("""
               TRUNCATE
                 classroom_preparation_workspaces,
                 classroom_attendance_corrections,
                 classroom_attendance_submissions,
                 classroom_attendance_exposures,
                 classroom_placements,
                 classroom_teaching_assignments,
                 classroom_enrolments,
                 classroom_classes,
                 people_staff_account_associations,
                 people_participations,
                 people_persons,
                 academic_calendar_closures,
                 academic_periods,
                 academic_years,
                 academic_calendars,
                 institution_publications,
                 institution_initial_operator_assignments,
                 institutional_units,
                 organization_legal_entity_relationship_terminations,
                 organization_legal_corporate_unit_profile_revisions,
                 organization_legal_corporate_units,
                 organization_legal_entity_relationships,
                 organization_legal_entity_consolidation_parentages,
                 organization_legal_entity_profile_revisions,
                 organization_legal_entities
               """)

               :cleared
             end)

    Enum.each([context_a(), context_b()], fn context ->
      assert {:ok, :cleared} = clear_tenant(runtime, context)
    end)
  end

  def clear_tenant(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      for table <- [
            "identity_support_access_grants",
            "identity_application_sessions",
            "identity_invitations"
          ],
          do: Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [tenant_id])

      Repo.query!("DELETE FROM identity_external_identity_links WHERE origin_tenant_id = $1", [
        tenant_id
      ])

      Repo.query!("DELETE FROM identity_connections WHERE tenant_id = $1", [tenant_id])

      for table <- [
            "identity_support_access_grants",
            "identity_application_sessions",
            "identity_invitations",
            "platform_governed_extension_definitions",
            "platform_authority_action_idempotency",
            "platform_outbox_consumer_receipts",
            "platform_outbox_deliveries",
            "platform_outbox_events",
            "platform_authority_audit_events",
            "platform_module_work_items",
            "platform_module_activations",
            "platform_module_entitlements",
            "platform_role_inclusions",
            "platform_role_capability_grants",
            "platform_actor_role_assignments",
            "platform_capabilities",
            "platform_roles",
            "platform_tenant_memberships"
          ] do
        Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [tenant_id])
      end

      :cleared
    end)
  end

  def runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 6]],
      placements: [
        placement(@tenant_a, "pooled-organization-legal", :pooled),
        placement(@tenant_b, "pooled-organization-legal", :pooled)
      ],
      per_tenant_limit: 6,
      per_placement_limit: 12
    ]
  end

  def placement(tenant_id, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: 9,
      profile: :pooled,
      placement_ref: placement_ref,
      repository: repository
    ]
  end

  def context_a(correlation_id \\ UUID.generate()),
    do: context(@actor_a, @tenant_a, correlation_id)

  def context_a_peer, do: context(@actor_a_peer, @tenant_a, UUID.generate())
  def context_a_denied, do: context(@actor_a_denied, @tenant_a, UUID.generate())
  def context_b, do: context(@actor_b, @tenant_b, UUID.generate())

  def context(actor_id, tenant_id, correlation_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 9,
        profile: :pooled,
        placement_ref: "pooled-organization-legal"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: "organization.legal.entity",
        locale: "en"
      )

    context
  end

  def dump(uuid), do: UUID.dump!(uuid)
end
