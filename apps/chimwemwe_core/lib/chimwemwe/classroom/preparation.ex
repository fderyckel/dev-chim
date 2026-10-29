defmodule Chimwemwe.Classroom.Preparation do
  @moduledoc """
  Exact, session-bound orchestration for the disabled local preparation screen.

  The server supplies one durable workspace identity. Browser input never selects
  a tenant, institution, calendar, year, educator, class, enrolment or placement.
  """

  alias Chimwemwe.Classroom.{Error, Foundation, InternalWriter}
  alias Chimwemwe.Identity.{PublicRequestSession, SessionFoundation}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.{ModuleLifecycle, ModuleLifecycleError}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @classroom_module "classroom.core"
  @people_module "people.core"
  @maximum_students 60

  def view(runtime, request, workspace_id) do
    with {:ok, workspace_id} <- uuid(workspace_id) do
      run(runtime, request, &view_current(&1, &2, &3, workspace_id))
    end
  end

  def prepare_class(runtime, request, workspace_id, input) do
    with {:ok, workspace_id} <- uuid(workspace_id),
         {:ok, input} <- normalize(input, [:causation_id, :code, :idempotency_key, :label]) do
      run(runtime, request, &prepare_class_current(&1, &2, &3, runtime, workspace_id, input))
    end
  end

  def add_student(runtime, people_runtime, request, workspace_id, input) do
    with {:ok, workspace_id} <- uuid(workspace_id),
         {:ok, input} <-
           normalize(input, [:causation_id, :display_name, :idempotency_key]) do
      run(
        runtime,
        request,
        &add_student_current(&1, &2, &3, runtime, people_runtime, workspace_id, input)
      )
    end
  end

  defp view_current(actor, session, context, workspace_id) do
    with :ok <- authorize_reads(context),
         {:ok, workspace} <- workspace(actor, session, workspace_id),
         do: load_view(actor, workspace)
  end

  defp prepare_class_current(actor, session, context, runtime, workspace_id, input) do
    with :ok <- authorize_reads(context),
         {:ok, workspace} <- workspace(actor, session, workspace_id),
         {:ok, class} <- create_class(runtime, context, workspace, input),
         {:ok, _assignment} <- assign_educator(runtime, context, workspace, class, input),
         :ok <- attach_class(actor, workspace, class.id),
         do: load_view(actor, %{workspace | class_id: class.id, lock_version: 2})
  end

  defp create_class(runtime, context, workspace, input) do
    Foundation.create_class(
      runtime,
      context,
      Map.merge(action_keys(input, "class"), %{
        institutional_unit_id: workspace.institutional_unit_id,
        calendar_id: workspace.calendar_id,
        academic_year_id: workspace.academic_year_id,
        calendar_revision: workspace.calendar_revision,
        code: input.code,
        label: input.label
      })
    )
  end

  defp assign_educator(runtime, context, workspace, class, input) do
    Foundation.assign_teacher(
      runtime,
      context,
      Map.merge(action_keys(input, "educator-assignment"), %{
        participation_id: workspace.educator_participation_id,
        expected_participation_version: workspace.educator_version,
        class_id: class.id,
        expected_class_version: class.lock_version,
        effective_from: workspace.local_date,
        effective_until: workspace.year_end_exclusive
      })
    )
  end

  defp add_student_current(
         actor,
         session,
         context,
         runtime,
         people_runtime,
         workspace_id,
         input
       ) do
    with :ok <- authorize_reads(context),
         {:ok, workspace} <- workspace(actor, session, workspace_id),
         true <- is_binary(workspace.class_id),
         {:ok, person} <- register_student(people_runtime, context, input),
         {:ok, participation} <-
           record_student(people_runtime, context, workspace, person, input),
         {:ok, enrolment} <- enrol_student(runtime, context, workspace, participation, input),
         {:ok, _placement} <- place_student(runtime, context, workspace, enrolment, input) do
      load_view(actor, workspace)
    else
      false -> error(:conflict)
      other -> other
    end
  end

  defp register_student(people_runtime, context, input) do
    People.register_person(
      people_runtime,
      context,
      Map.merge(action_keys(input, "person"), %{display_name: input.display_name})
    )
  end

  defp record_student(people_runtime, context, workspace, person, input) do
    People.record_student_participation(
      people_runtime,
      context,
      Map.merge(action_keys(input, "student-participation"), %{
        person_id: person.id,
        expected_person_version: person.lock_version,
        institutional_unit_id: workspace.institutional_unit_id,
        effective_from: workspace.local_date,
        effective_until: workspace.year_end_exclusive,
        source_reference: derived_uuid(input.idempotency_key, "student-source")
      })
    )
  end

  defp enrol_student(runtime, context, workspace, participation, input) do
    Foundation.enrol_student(
      runtime,
      context,
      Map.merge(action_keys(input, "year-enrolment"), %{
        participation_id: participation.id,
        expected_participation_version: participation.lock_version,
        academic_year_id: workspace.academic_year_id,
        calendar_revision: workspace.calendar_revision,
        effective_from: workspace.local_date,
        effective_until: workspace.year_end_exclusive
      })
    )
  end

  defp place_student(runtime, context, workspace, enrolment, input) do
    Foundation.place_student(
      runtime,
      context,
      Map.merge(action_keys(input, "class-placement"), %{
        enrolment_id: enrolment.id,
        expected_enrolment_version: enrolment.lock_version,
        class_id: workspace.class_id,
        expected_class_version: 1,
        effective_from: workspace.local_date,
        effective_until: workspace.year_end_exclusive
      })
    )
  end

  defp run(runtime, %PublicRequestSession{support: nil} = request, operation) do
    InternalWriter.run(runtime, request.context, fn actor, context ->
      with %{rows: [["read committed"]]} <- Repo.query!("SHOW transaction_isolation"),
           {:ok, current} <-
             SessionFoundation.validate(runtime, context, %{token: request.session_token}),
           true <-
             current.id == request.session.id and current.actor_id == actor.actor_id and
               current.tenant_id == actor.tenant_id and
               current.membership_id == request.session.membership_id do
        operation.(actor, current, context)
      else
        _denied -> error(:forbidden)
      end
    end)
  end

  defp run(_runtime, _request, _operation), do: error(:forbidden)

  defp workspace(actor, session, id) do
    case Repo.query(
           """
           SELECT w.membership_id::text, w.institutional_unit_id::text, w.calendar_id::text,
             w.academic_year_id::text, w.calendar_revision, w.educator_participation_id::text,
             w.class_id::text, w.lock_version, p.lock_version, u.display_name, y.label,
             staff.display_name, (statement_timestamp() AT TIME ZONE u.time_zone)::date,
             (y.end_on + 1)::date
           FROM classroom_preparation_workspaces w
           JOIN platform_tenant_memberships m
             ON m.id = w.membership_id AND m.tenant_id = w.tenant_id
           JOIN people_participations p
             ON p.id = w.educator_participation_id AND p.tenant_id = w.tenant_id
           JOIN people_persons staff
             ON staff.id = p.person_id AND staff.tenant_id = p.tenant_id
           JOIN people_staff_account_associations a
             ON a.participation_id = p.id AND a.tenant_id = p.tenant_id
           JOIN institutional_units u
             ON u.id = w.institutional_unit_id AND u.tenant_id = w.tenant_id
           JOIN academic_calendars c
             ON c.id = w.calendar_id AND c.tenant_id = w.tenant_id
           JOIN academic_years y
             ON y.id = w.academic_year_id AND y.tenant_id = w.tenant_id
           WHERE w.id = $1 AND w.tenant_id = $2 AND w.actor_id = $3
             AND w.membership_id = $4 AND m.actor_id = w.actor_id
             AND p.kind = 'staff' AND p.institutional_unit_id = w.institutional_unit_id
             AND a.membership_id = w.membership_id
             AND a.verification->>'actor_id' = w.actor_id::text AND a.revoked_at IS NULL
             AND u.status = 'published' AND c.status = 'active'
             AND c.institutional_unit_id = w.institutional_unit_id
             AND y.calendar_id = w.calendar_id AND y.status = 'published'
             AND y.candidate_revision = w.calendar_revision
             AND (statement_timestamp() AT TIME ZONE u.time_zone)::date BETWEEN y.start_on AND y.end_on
             AND (statement_timestamp() AT TIME ZONE u.time_zone)::date >= p.effective_from
             AND (p.effective_until IS NULL OR
               (statement_timestamp() AT TIME ZONE u.time_zone)::date < p.effective_until)
           FOR UPDATE OF w, m, p, staff, a, u, c, y
           """,
           [dump(id), dump(actor.tenant_id), dump(actor.actor_id), dump(session.membership_id)]
         ) do
      {:ok,
       %{
         rows: [
           [
             membership_id,
             institutional_unit_id,
             calendar_id,
             academic_year_id,
             revision,
             educator_participation_id,
             class_id,
             lock_version,
             educator_version,
             institution_name,
             academic_year_label,
             educator_name,
             local_date,
             year_end_exclusive
           ]
         ]
       }} ->
        {:ok,
         %{
           id: id,
           membership_id: membership_id,
           institutional_unit_id: institutional_unit_id,
           calendar_id: calendar_id,
           academic_year_id: academic_year_id,
           calendar_revision: revision,
           educator_participation_id: educator_participation_id,
           class_id: class_id,
           lock_version: lock_version,
           educator_version: educator_version,
           institution_name: institution_name,
           academic_year_label: academic_year_label,
           educator_name: educator_name,
           local_date: local_date,
           year_end_exclusive: year_end_exclusive
         }}

      {:ok, %{rows: []}} ->
        error(:forbidden)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp attach_class(actor, %{class_id: nil, id: workspace_id}, class_id) do
    case Repo.query(
           "UPDATE classroom_preparation_workspaces SET class_id = $3, lock_version = 2 WHERE id = $1 AND tenant_id = $2 AND class_id IS NULL AND lock_version = 1",
           [dump(workspace_id), dump(actor.tenant_id), dump(class_id)]
         ) do
      {:ok, %{num_rows: 1}} ->
        :ok

      {:error, %Postgrex.Error{postgres: %{code: code}}}
      when code in [:check_violation, :foreign_key_violation, :unique_violation] ->
        error(:conflict)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp attach_class(_actor, %{class_id: class_id}, class_id), do: :ok
  defp attach_class(_actor, _workspace, _class_id), do: error(:conflict)

  defp load_view(actor, workspace) do
    with {:ok, prepared_class} <- prepared_class(actor, workspace),
         {:ok, students} <- students(actor, workspace) do
      {:ok,
       %{
         institution_name: workspace.institution_name,
         academic_year_label: workspace.academic_year_label,
         educator_name: workspace.educator_name,
         class: prepared_class,
         students: students
       }}
    end
  end

  defp prepared_class(_actor, %{class_id: nil}), do: {:ok, nil}

  defp prepared_class(actor, workspace) do
    case Repo.query(
           """
           SELECT id::text, code, label
           FROM classroom_classes
           WHERE tenant_id = $1 AND id = $2 AND institutional_unit_id = $3
             AND calendar_id = $4 AND academic_year_id = $5 AND calendar_revision = $6
           """,
           [
             dump(actor.tenant_id),
             dump(workspace.class_id),
             dump(workspace.institutional_unit_id),
             dump(workspace.calendar_id),
             dump(workspace.academic_year_id),
             workspace.calendar_revision
           ]
         ) do
      {:ok, %{rows: [[id, code, label]]}} -> {:ok, %{id: id, code: code, label: label}}
      {:ok, %{rows: []}} -> error(:forbidden)
      _failed -> error(:retryable_dependency)
    end
  end

  defp students(_actor, %{class_id: nil}), do: {:ok, []}

  defp students(actor, workspace) do
    case Repo.query(
           """
           SELECT person.id::text, person.display_name
           FROM classroom_placements placement
           JOIN classroom_enrolments enrolment
             ON enrolment.id = placement.enrolment_id AND enrolment.tenant_id = placement.tenant_id
           JOIN people_participations participation
             ON participation.id = enrolment.participation_id AND participation.tenant_id = enrolment.tenant_id
           JOIN people_persons person
             ON person.id = participation.person_id AND person.tenant_id = participation.tenant_id
           WHERE placement.tenant_id = $1 AND placement.class_id = $2
             AND placement.effective_from <= $3 AND placement.effective_until > $3
             AND enrolment.effective_from <= $3 AND enrolment.effective_until > $3
             AND participation.kind = 'student' AND participation.effective_from <= $3
             AND (participation.effective_until IS NULL OR participation.effective_until > $3)
           ORDER BY person.id
           LIMIT 61
           """,
           [dump(actor.tenant_id), dump(workspace.class_id), workspace.local_date]
         ) do
      {:ok, %{rows: rows}} when length(rows) <= @maximum_students ->
        {:ok, Enum.map(rows, fn [id, name] -> %{id: id, name: name} end)}

      {:ok, %{rows: _too_many}} ->
        error(:scope_limit)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp authorize_reads(context) do
    with :ok <-
           authorize(
             Foundation.release_manifest(),
             context,
             @classroom_module,
             "classroom.core.classes.read"
           ),
         do:
           authorize(
             People.release_manifest(),
             context,
             @people_module,
             "people.core.persons.read"
           )
  end

  defp authorize(manifest, context, module, capability) do
    case ModuleLifecycle.authorize_current_transaction(manifest, context, module, capability) do
      :ok -> :ok
      {:error, %ModuleLifecycleError{code: :retryable_dependency}} -> error(:retryable_dependency)
      _denied -> error(:forbidden)
    end
  end

  defp normalize(input, keys) when is_map(input) and not is_struct(input) do
    with true <- Enum.sort(Map.keys(input)) == Enum.sort(keys),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok, %{input | idempotency_key: idempotency_key, causation_id: causation_id}}
    else
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize(_input, _keys), do: error(:invalid_input)

  defp action_keys(input, label),
    do: %{
      idempotency_key: derived_uuid(input.idempotency_key, label),
      causation_id: input.causation_id
    }

  defp derived_uuid(parent, label) do
    <<bytes::binary-size(16), _rest::binary>> =
      :crypto.hash(:sha256, UUID.dump!(parent) <> label)

    UUID.load!(bytes)
  end

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, value} -> {:ok, value}
      _invalid -> error(:invalid_input)
    end
  end

  defp dump(id), do: UUID.dump!(id)
  defp error(code), do: {:error, %Error{code: code}}
end
