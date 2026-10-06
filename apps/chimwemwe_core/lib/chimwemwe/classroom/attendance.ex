defmodule Chimwemwe.Classroom.Attendance do
  @moduledoc "Today's bounded, session-bound classroom register; ADR 0038."
  alias Chimwemwe.Classroom.{Error, Evidence, Foundation, InternalWriter}
  alias Chimwemwe.Identity.{PublicRequestSession, SessionFoundation}
  alias Chimwemwe.Platform.ModuleLifecycle
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID
  @module "classroom.attendance"
  @aggregate "classroom.attendance.submission"
  @action "classroom.attendance.submit"

  def release_manifest do
    {:ok, manifest} =
      ReleaseManifest.new(
        ReleaseManifest.declarations(Foundation.release_manifest()) ++
          [
            %{
              key: @module,
              version: "1.0.0",
              owner: "Classroom attendance",
              dependencies: ["classroom.core"]
            }
          ]
      )

    manifest
  end

  def assigned_classes(runtime, request) do
    run(runtime, request, "read", fn actor, session ->
      rows =
        Repo.query!(
          """
          SELECT c.id::text, c.label, (statement_timestamp() AT TIME ZONE y.time_zone)::date
          FROM classroom_classes c JOIN academic_years y ON y.id = c.academic_year_id AND y.tenant_id = c.tenant_id
          WHERE c.tenant_id = $1 AND EXISTS (
            SELECT 1 FROM classroom_teaching_assignments t
            JOIN people_participations p ON p.id = t.participation_id AND p.tenant_id = t.tenant_id
            JOIN people_staff_account_associations a ON a.participation_id = p.id AND a.tenant_id = p.tenant_id
            JOIN institutional_units u ON u.id = p.institutional_unit_id AND u.tenant_id = p.tenant_id
            WHERE t.tenant_id = c.tenant_id AND t.class_id = c.id AND a.membership_id = $2
              AND a.verification->>'actor_id' = $3 AND a.revoked_at IS NULL AND p.kind = 'staff' AND u.status = 'published'
              AND (statement_timestamp() AT TIME ZONE u.time_zone)::date >= p.effective_from
              AND (p.effective_until IS NULL OR (statement_timestamp() AT TIME ZONE u.time_zone)::date < p.effective_until)
              AND (statement_timestamp() AT TIME ZONE y.time_zone)::date >= t.effective_from
              AND (statement_timestamp() AT TIME ZONE y.time_zone)::date < t.effective_until)
          ORDER BY c.id LIMIT 13
          """,
          [dump(actor.tenant_id), dump(session.membership_id), actor.actor_id]
        ).rows

      with true <- length(rows) <= 12,
           :ok <- expose(actor, Enum.map(rows, &hd/1), []) do
        {:ok,
         Enum.map(rows, fn [id, label, date] ->
           %{id: id, label: label, local_date: Date.to_iso8601(date)}
         end)}
      else
        false -> error(:scope_limit)
        other -> other
      end
    end)
  end

  def prepare(runtime, request, class_id) do
    with {:ok, class_id} <- uuid(class_id),
         do: run(runtime, request, "read", &prepare_current(&1, &2, class_id))
  end

  defp prepare_current(actor, session, class_id) do
    with {:ok, class} <- authorized_class(actor, session, class_id),
         {:ok, view} <- load_view(actor, class),
         :ok <- expose(actor, [class.id], Enum.map(view.students, & &1.id)) do
      {:ok, view}
    end
  end

  def submit(runtime, request, input) do
    with {:ok, input} <- normalize(input),
         do: run(runtime, request, "submit", &submit_current(&1, &2, input))
  end

  defp submit_current(actor, session, input) do
    with {:ok, class} <- authorized_class(actor, session, input.class_id),
         true <- input.local_date == Date.to_iso8601(class.date),
         hash = :crypto.hash(:sha256, :erlang.term_to_binary(input, [:deterministic])),
         id = UUID.generate(),
         {:ok, claim} <-
           Evidence.claim(actor, @action, @aggregate, input.idempotency_key, hash, id) do
      submit_claim(claim, actor, class, input, hash, id)
    else
      false -> error(:stale)
      other -> other
    end
  end

  defp run(runtime, %PublicRequestSession{support: nil} = request, capability, operation) do
    InternalWriter.run(runtime, request.context, fn actor, context ->
      with %{rows: [["read committed"]]} <- Repo.query!("SHOW transaction_isolation"),
           {:ok, current} <-
             SessionFoundation.validate(runtime, context, %{token: request.session_token}),
           true <-
             current.id == request.session.id and current.actor_id == actor.actor_id and
               current.tenant_id == actor.tenant_id and
               current.membership_id == request.session.membership_id,
           :ok <-
             ModuleLifecycle.authorize_current_transaction(
               release_manifest(),
               context,
               @module,
               @module <> "." <> capability
             ) do
        operation.(actor, current)
      else
        _denied -> error(:forbidden)
      end
    end)
  end

  defp run(_runtime, _request, _capability, _operation), do: error(:forbidden)

  # Class locks serialize placement insertions with preparation and submission. Source locks
  # retain current account, assignment and roster authority until the transaction commits.
  defp authorized_class(actor, session, id) do
    case Repo.query!(
           """
           SELECT c.label, c.calendar_revision, c.academic_year_id::text,
             (statement_timestamp() AT TIME ZONE y.time_zone)::date,
             y.start_on, y.end_on, y.instructional_weekdays
           FROM classroom_classes c
           JOIN academic_years y ON y.id = c.academic_year_id AND y.tenant_id = c.tenant_id
           JOIN academic_calendars cal ON cal.id = c.calendar_id AND cal.tenant_id = c.tenant_id
           WHERE c.tenant_id = $1 AND c.id = $2 AND y.status = 'published' AND cal.status = 'active'
             AND y.candidate_revision = c.calendar_revision
           FOR UPDATE OF c
           """,
           [dump(actor.tenant_id), dump(id)]
         ).rows do
      [[label, revision, year, date, first, last, weekdays]] ->
        rows =
          Repo.query!(
            """
            SELECT t.id FROM classroom_teaching_assignments t
            JOIN people_participations p ON p.id = t.participation_id AND p.tenant_id = t.tenant_id
            JOIN people_staff_account_associations a ON a.participation_id = p.id AND a.tenant_id = p.tenant_id
            JOIN institutional_units u ON u.id = p.institutional_unit_id AND u.tenant_id = p.tenant_id
            WHERE t.tenant_id = $1 AND t.class_id = $2 AND a.membership_id = $3
              AND a.verification->>'actor_id' = $4 AND a.revoked_at IS NULL AND p.kind = 'staff' AND u.status = 'published'
              AND t.effective_from <= $5 AND t.effective_until > $5
              AND p.effective_from <= (statement_timestamp() AT TIME ZONE u.time_zone)::date
              AND (p.effective_until IS NULL OR p.effective_until > (statement_timestamp() AT TIME ZONE u.time_zone)::date)
            FOR SHARE OF t, p, a, u
            """,
            [dump(actor.tenant_id), dump(id), dump(session.membership_id), actor.actor_id, date]
          ).rows

        if rows == [],
          do: error(:forbidden),
          else:
            {:ok,
             %{
               id: id,
               label: label,
               revision: revision,
               year: year,
               date: date,
               first: first,
               last: last,
               weekdays: weekdays
             }}

      _ ->
        error(:forbidden)
    end
  end

  defp load_view(actor, class) do
    case Repo.query!(
           "SELECT id::text, roster, marks, roster_basis FROM classroom_attendance_submissions WHERE tenant_id = $1 AND class_id = $2 AND local_date = $3",
           [dump(actor.tenant_id), dump(class.id), class.date]
         ).rows do
      [[id, %{"students" => facts}, marks, basis]] ->
        ids = Enum.map(facts, &hd/1)

        names =
          Repo.query!(
            "SELECT id::text, display_name FROM people_persons WHERE tenant_id = $1 AND id = ANY($2::uuid[]) ORDER BY id FOR SHARE",
            [dump(actor.tenant_id), Enum.map(ids, &dump/1)]
          ).rows

        students =
          Enum.map(names, fn [id, name] -> %{id: id, name: name, mark: Map.fetch!(marks, id)} end)

        {:ok, view(class, students, basis, id)}

      [] ->
        with :ok <- instructional(actor, class), {:ok, facts, students} <- roster(actor, class) do
          {:ok, view(class, students, basis(class, facts), nil)}
        end
    end
  end

  defp view(class, students, basis, id),
    do: %{
      class_id: class.id,
      label: class.label,
      local_date: Date.to_iso8601(class.date),
      calendar_revision: class.revision,
      roster_basis: basis,
      students: students,
      submission_id: id
    }

  defp instructional(actor, class) do
    [[period, closure]] =
      Repo.query!(
        """
        SELECT EXISTS(SELECT 1 FROM academic_periods WHERE tenant_id = $1 AND academic_year_id = $2 AND start_on <= $3 AND end_on >= $3),
          EXISTS(SELECT 1 FROM academic_calendar_closures WHERE tenant_id = $1 AND academic_year_id = $2 AND date = $3)
        """,
        [dump(actor.tenant_id), dump(class.year), class.date]
      ).rows

    if Date.compare(class.date, class.first) != :lt and
         Date.compare(class.date, class.last) != :gt and
         Date.day_of_week(class.date) in class.weekdays and period and not closure,
       do: :ok,
       else: error(:non_instructional)
  end

  defp roster(actor, class) do
    rows =
      Repo.query!(
        """
        SELECT n.id::text, n.lock_version, p.id::text, p.lock_version,
          e.id::text, e.lock_version, r.id::text, r.lock_version, n.display_name
        FROM classroom_placements r
        JOIN classroom_enrolments e ON e.id = r.enrolment_id AND e.tenant_id = r.tenant_id
        JOIN people_participations p ON p.id = e.participation_id AND p.tenant_id = e.tenant_id
        JOIN people_persons n ON n.id = p.person_id AND n.tenant_id = p.tenant_id
        WHERE r.tenant_id = $1 AND r.class_id = $2 AND r.effective_from <= $3 AND r.effective_until > $3
          AND e.effective_from <= $3 AND e.effective_until > $3 AND p.effective_from <= $3
          AND (p.effective_until IS NULL OR p.effective_until > $3) AND p.kind = 'student'
        ORDER BY n.id LIMIT 61 FOR SHARE OF r, e, p, n
        """,
        [dump(actor.tenant_id), dump(class.id), class.date]
      ).rows

    if length(rows) in 1..60 and length(Enum.uniq_by(rows, &hd/1)) == length(rows) do
      {:ok, Enum.map(rows, &Enum.take(&1, 8)),
       Enum.map(rows, fn row -> %{id: hd(row), name: List.last(row), mark: nil} end)}
    else
      error(:scope_limit)
    end
  end

  defp basis(class, facts),
    do:
      :crypto.hash(
        :sha256,
        :erlang.term_to_binary({class.id, class.date, class.revision, facts}, [:deterministic])
      )
      |> Base.encode16(case: :lower)

  defp submit_claim({:existing, stored}, actor, _class, _input, hash, _id) do
    with {:ok, replay} <- Evidence.replay(stored, actor.actor_id, hash),
         do: {:ok, replay.result_payload}
  end

  defp submit_claim({:new, claim}, actor, class, input, _hash, id) do
    with :ok <- instructional(actor, class),
         {:ok, facts, _students} <- roster(actor, class),
         true <-
           input.roster_basis == basis(class, facts) and input.calendar_revision == class.revision,
         true <- Enum.sort(Map.keys(input.marks)) == Enum.sort(Enum.map(facts, &hd/1)),
         :ok <- insert(actor, class, input, facts, id),
         payload = %{"submission_id" => id},
         {:ok, _evidence} <-
           Evidence.record(actor, %{
             action_name: @action,
             aggregate_type: @aggregate,
             aggregate_id: id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: 0,
             after_version: 1,
             change_summary: %{"action" => "submit"},
             event_type: @action <> ".completed",
             event_payload: payload,
             result_payload: payload,
             claim_id: claim
           }) do
      {:ok, payload}
    else
      false -> error(:stale)
      other -> other
    end
  end

  defp insert(actor, class, input, facts, id) do
    case Repo.query!(
           """
           INSERT INTO classroom_attendance_submissions (id, tenant_id, class_id, local_date, calendar_revision, roster_basis, roster, marks)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT (tenant_id, class_id, local_date) DO NOTHING RETURNING id
           """,
           [
             dump(id),
             dump(actor.tenant_id),
             dump(class.id),
             class.date,
             class.revision,
             input.roster_basis,
             %{"students" => facts},
             input.marks
           ]
         ).rows do
      [_] -> :ok
      [] -> error(:conflict)
    end
  end

  defp expose(actor, classes, people) do
    params = [dump(actor.tenant_id), dump(actor.actor_id)]

    Repo.query!(
      """
      INSERT INTO classroom_attendance_exposures (tenant_id, actor_id, day, class_ids, person_ids)
      VALUES ($1,$2,(statement_timestamp() AT TIME ZONE 'UTC')::date,'{}','{}') ON CONFLICT DO NOTHING
      """,
      params
    )

    [[id, prior_classes, prior_people]] =
      Repo.query!(
        "SELECT id, class_ids, person_ids FROM classroom_attendance_exposures WHERE tenant_id = $1 AND actor_id = $2 AND day = (statement_timestamp() AT TIME ZONE 'UTC')::date FOR UPDATE",
        params
      ).rows

    class_ids = Enum.uniq(prior_classes ++ Enum.map(classes, &dump/1))
    person_ids = Enum.uniq(prior_people ++ Enum.map(people, &dump/1))

    if length(class_ids) <= 12 and length(person_ids) <= 720 do
      Repo.query!(
        "UPDATE classroom_attendance_exposures SET class_ids = $3, person_ids = $4 WHERE tenant_id = $1 AND id = $2",
        [hd(params), id, class_ids, person_ids]
      )

      :ok
    else
      error(:scope_limit)
    end
  end

  defp normalize(input) when is_map(input) and not is_struct(input) do
    keys = [
      :class_id,
      :local_date,
      :calendar_revision,
      :roster_basis,
      :marks,
      :idempotency_key,
      :causation_id
    ]

    with true <- Enum.sort(Map.keys(input)) == Enum.sort(keys),
         {:ok, class_id} <- uuid(input.class_id),
         {:ok, idem} <- uuid(input.idempotency_key),
         {:ok, cause} <- uuid(input.causation_id),
         true <- is_binary(input.local_date),
         {:ok, _date} <- Date.from_iso8601(input.local_date),
         true <- digest?(input.calendar_revision) and digest?(input.roster_basis),
         {:ok, marks} <- marks(input.marks) do
      {:ok,
       %{input | class_id: class_id, idempotency_key: idem, causation_id: cause, marks: marks}}
    else
      _ -> error(:invalid_input)
    end
  end

  defp normalize(_), do: error(:invalid_input)

  defp marks(marks) when is_list(marks) and length(marks) in 1..60 do
    Enum.reduce_while(marks, {:ok, %{}}, &add_mark/2)
  end

  defp marks(_), do: error(:invalid_input)

  defp add_mark(%{person_id: id, mark: value} = mark, {:ok, acc})
       when map_size(mark) == 2 and value in ["present", "absent", "late"] do
    with {:ok, id} <- uuid(id), false <- Map.has_key?(acc, id) do
      {:cont, {:ok, Map.put(acc, id, value)}}
    else
      _ -> {:halt, error(:invalid_input)}
    end
  end

  defp add_mark(_, _), do: {:halt, error(:invalid_input)}

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/\A[0-9a-f]{64}\z/, value)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, id} -> {:ok, id}
      _ -> error(:invalid_input)
    end
  end

  defp dump(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
