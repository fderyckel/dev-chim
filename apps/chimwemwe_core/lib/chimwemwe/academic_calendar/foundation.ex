defmodule Chimwemwe.AcademicCalendar.Foundation do
  @moduledoc """
  Private CF-2B writer for one exact institution-owned academic calendar.

  The boundary exposes named transitions and exact reads only. Tenant, actor,
  placement, repository, module state and capabilities come from trusted
  execution context; no active-unit, ancestor, default or latest-row selector
  is accepted.
  """

  alias Chimwemwe.AcademicCalendar.{
    ActionResult,
    Contract,
    Error,
    Evidence,
    InternalWriter,
    Runtime,
    YearView
  }

  alias Chimwemwe.Identity.{PublicRequestSession, SessionFoundation}
  alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
  alias Chimwemwe.Platform.{ModuleLifecycle, ModuleLifecycleError}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @module_key "academics.calendar"
  @aggregate_calendar "academics.calendar.calendar"
  @aggregate_year "academics.calendar.academic_year"
  @base_keys [:idempotency_key, :causation_id]
  @definition_keys [
    :academic_year_id,
    :calendar_id,
    :closures,
    :code,
    :end_on,
    :instructional_weekdays,
    :label,
    :periods,
    :start_on,
    :time_zone
  ]
  @capabilities %{
    manage: "academics.calendar.definition.manage",
    publish: "academics.calendar.publication.publish",
    read: "academics.calendar.read"
  }
  @actions %{
    register: "academics.calendar.register_academic_calendar",
    define: "academics.calendar.define_draft_academic_year",
    replace: "academics.calendar.replace_draft_calendar_definition",
    publish: "academics.calendar.publish_academic_year"
  }

  @spec release_manifest() :: ReleaseManifest.t()
  def release_manifest do
    declarations = Institutions.release_manifest() |> ReleaseManifest.declarations()

    {:ok, manifest} =
      ReleaseManifest.new(
        declarations ++
          [
            %{
              key: @module_key,
              version: "1.0.0",
              owner: "Academic calendar",
              dependencies: ["institution.structure"]
            }
          ]
      )

    manifest
  end

  @spec register_academic_calendar(Runtime.t(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def register_academic_calendar(runtime, context, input),
    do: mutate(runtime, context, :register, input)

  @spec define_draft_academic_year(Runtime.t(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def define_draft_academic_year(runtime, context, input),
    do: mutate(runtime, context, :define, input)

  @spec replace_draft_calendar_definition(Runtime.t(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def replace_draft_calendar_definition(
        runtime,
        %PublicRequestSession{} = request,
        input
      ),
      do: mutate_from_session(runtime, request, :replace, input)

  def replace_draft_calendar_definition(runtime, context, input),
    do: mutate(runtime, context, :replace, input)

  @spec publish_academic_year(Runtime.t(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def publish_academic_year(runtime, %PublicRequestSession{} = request, input),
    do: mutate_from_session(runtime, request, :publish, input)

  def publish_academic_year(runtime, context, input),
    do: mutate(runtime, context, :publish, input)

  @spec preview_academic_year_publication(Runtime.t(), term(), term(), term()) ::
          {:ok, YearView.t()} | {:error, term()}
  def preview_academic_year_publication(
        runtime,
        %PublicRequestSession{} = request,
        calendar_id,
        academic_year_id
      ),
      do: read_year_from_session(runtime, request, calendar_id, academic_year_id, :draft, :manage)

  def preview_academic_year_publication(runtime, context, calendar_id, academic_year_id),
    do: read_year(runtime, context, calendar_id, academic_year_id, :draft, :manage)

  @spec read_published_academic_year(Runtime.t(), term(), term(), term()) ::
          {:ok, YearView.t()} | {:error, term()}
  def read_published_academic_year(
        runtime,
        %PublicRequestSession{} = request,
        calendar_id,
        academic_year_id
      ),
      do:
        read_year_from_session(runtime, request, calendar_id, academic_year_id, :published, :read)

  def read_published_academic_year(runtime, context, calendar_id, academic_year_id),
    do: read_year(runtime, context, calendar_id, academic_year_id, :published, :read)

  @spec resolve_instructional_context(Runtime.t(), term(), term(), Date.t()) ::
          {:ok, Chimwemwe.AcademicCalendar.Resolution.t()} | {:error, term()}
  def resolve_instructional_context(
        runtime,
        %PublicRequestSession{} = request,
        calendar_id,
        %Date{} = local_date
      ),
      do: resolve_from_session(runtime, request, calendar_id, local_date)

  def resolve_instructional_context(runtime, context, calendar_id, %Date{} = local_date) do
    with {:ok, persistence} <- Runtime.persistence(runtime),
         {:ok, calendar_id} <- uuid(calendar_id) do
      InternalWriter.run(
        persistence,
        context,
        &resolve_authorized(&1, &2, calendar_id, local_date)
      )
    end
  end

  def resolve_instructional_context(_runtime, _context, _calendar_id, _local_date),
    do: error(:invalid_input, :local_date)

  defp mutate(runtime, context, operation, input) do
    with {:ok, persistence} <- Runtime.persistence(runtime) do
      InternalWriter.run(
        persistence,
        context,
        &mutate_authorized(&1, &2, operation, input)
      )
    end
  end

  defp mutate_from_session(runtime, request, operation, input) do
    with {:ok, persistence} <- Runtime.persistence(runtime) do
      InternalWriter.run(
        persistence,
        request.context,
        &with_current_session(persistence, &1, &2, request, fn actor, validated ->
          mutate_authorized(actor, validated, operation, input)
        end)
      )
    end
  end

  defp resolve_from_session(runtime, request, calendar_id, local_date) do
    with {:ok, persistence} <- Runtime.persistence(runtime),
         {:ok, calendar_id} <- uuid(calendar_id) do
      InternalWriter.run(
        persistence,
        request.context,
        &with_current_session(persistence, &1, &2, request, fn actor, validated ->
          resolve_authorized(actor, validated, calendar_id, local_date)
        end)
      )
    end
  end

  defp mutate_authorized(actor, validated, operation, input) do
    with :ok <- authorize(validated, capability(operation)),
         {:ok, prepared} <- prepare(operation, actor, input),
         do: transition(actor, operation, prepared)
  end

  defp resolve_authorized(actor, validated, calendar_id, local_date) do
    with :ok <- authorize(validated, :read),
         {:ok, academic_year_id} <- year_for_date(actor.tenant_id, calendar_id, local_date),
         {:ok, view} <- load_year(actor.tenant_id, calendar_id, academic_year_id, :published),
         do: Contract.resolve_date(view.preview, local_date)
  end

  defp transition(actor, operation, prepared) do
    id = target(operation, prepared)
    action = Map.fetch!(@actions, operation)
    aggregate = aggregate(operation)

    request_hash =
      :crypto.hash(
        :sha256,
        :erlang.term_to_binary({action, request_fingerprint(prepared)}, [:deterministic])
      )

    with {:ok, claim} <-
           Evidence.claim(
             actor,
             action,
             aggregate,
             prepared.idempotency_key,
             request_hash,
             id
           ) do
      resolve_claim(claim, actor, operation, prepared, id, action, aggregate, request_hash)
    end
  end

  defp resolve_claim(
         {:existing, stored},
         actor,
         _operation,
         _prepared,
         _id,
         _action,
         _aggregate,
         request_hash
       ) do
    with {:ok, replay} <- Evidence.replay(stored, actor.actor_id, request_hash),
         do: action_result(replay.result_payload, replay.audit_reference, replay.event_id)
  end

  defp resolve_claim({:new, claim_id}, actor, operation, prepared, id, action, aggregate, _hash) do
    with {:ok, outcome} <- perform(actor, operation, prepared, id),
         payload = result_payload(id, outcome),
         {:ok, evidence} <-
           Evidence.record(actor, %{
             action_name: action,
             aggregate_type: aggregate,
             aggregate_id: id,
             idempotency_key: prepared.idempotency_key,
             causation_id: prepared.causation_id,
             before_version: outcome.before_version,
             after_version: outcome.lock_version,
             change_summary: %{
               "transition" => Atom.to_string(operation),
               "candidate_revision" => outcome.candidate_revision
             },
             event_type: action <> ".completed",
             event_payload: payload,
             result_payload: payload,
             claim_id: claim_id
           }) do
      action_result(payload, evidence.audit_reference, evidence.event_id)
    end
  end

  defp perform(actor, :register, input, id) do
    with {:ok, _unit} <- eligible_institution(actor.tenant_id, input.institutional_unit_id),
         :ok <-
           write_one(
             """
             INSERT INTO academic_calendars
               (id, tenant_id, institutional_unit_id, code, status, lock_version, inserted_at, updated_at)
             VALUES ($1, $2, $3, $4, 'active', 1,
                     (statement_timestamp() AT TIME ZONE 'utc'),
                     (statement_timestamp() AT TIME ZONE 'utc'))
             """,
             [
               dump(id),
               dump(actor.tenant_id),
               dump(input.institutional_unit_id),
               input.code
             ]
           ) do
      {:ok, outcome(:calendar, :active, 0, 1, nil)}
    end
  end

  defp perform(actor, :define, input, _id) do
    definition = input.preview.definition

    with {:ok, _owner} <- calendar_owner(actor.tenant_id, definition.calendar_id),
         :ok <- valid_zone(definition.time_zone),
         :ok <- insert_year(actor.tenant_id, input.preview),
         :ok <- insert_children(actor.tenant_id, input.preview) do
      {:ok, outcome(:academic_year, :draft, 0, 1, input.preview.candidate_revision)}
    end
  end

  defp perform(actor, :replace, input, _id) do
    definition = input.preview.definition

    with {:ok, year} <-
           lock_year(actor.tenant_id, definition.calendar_id, definition.academic_year_id),
         :ok <- ensure(year.status == "draft", :conflict),
         :ok <- ensure(year.lock_version == input.expected_version, :stale),
         {:ok, _owner} <- calendar_owner(actor.tenant_id, definition.calendar_id),
         :ok <- valid_zone(definition.time_zone),
         :ok <- update_year(actor.tenant_id, input.preview, input.expected_version),
         :ok <- replace_children(actor.tenant_id, input.preview) do
      {:ok,
       outcome(
         :academic_year,
         :draft,
         input.expected_version,
         input.expected_version + 1,
         input.preview.candidate_revision
       )}
    end
  end

  defp perform(actor, :publish, input, _id) do
    with {:ok, year} <- lock_year(actor.tenant_id, input.calendar_id, input.academic_year_id),
         :ok <- ensure(year.status == "draft", :conflict),
         :ok <- ensure(year.lock_version == input.expected_version, :stale),
         {:ok, _owner} <- calendar_owner(actor.tenant_id, input.calendar_id),
         {:ok, view} <-
           load_year(actor.tenant_id, input.calendar_id, input.academic_year_id, :draft),
         :ok <- valid_zone(view.preview.definition.time_zone),
         :ok <-
           ensure(view.preview.candidate_revision == year.candidate_revision, :conflict),
         :ok <- no_published_overlap(actor.tenant_id, view.preview),
         :ok <- publish_year(actor.tenant_id, input, year.candidate_revision) do
      {:ok,
       outcome(
         :academic_year,
         :published,
         input.expected_version,
         input.expected_version + 1,
         year.candidate_revision
       )}
    end
  end

  defp read_year(runtime, context, calendar_id, academic_year_id, status, capability) do
    with {:ok, persistence} <- Runtime.persistence(runtime),
         {:ok, calendar_id} <- uuid(calendar_id),
         {:ok, academic_year_id} <- uuid(academic_year_id) do
      InternalWriter.run(
        persistence,
        context,
        &read_year_authorized(&1, &2, calendar_id, academic_year_id, status, capability)
      )
    end
  end

  defp read_year_from_session(
         runtime,
         request,
         calendar_id,
         academic_year_id,
         status,
         capability
       ) do
    with {:ok, persistence} <- Runtime.persistence(runtime),
         {:ok, calendar_id} <- uuid(calendar_id),
         {:ok, academic_year_id} <- uuid(academic_year_id) do
      InternalWriter.run(
        persistence,
        request.context,
        &with_current_session(persistence, &1, &2, request, fn actor, validated ->
          read_year_authorized(
            actor,
            validated,
            calendar_id,
            academic_year_id,
            status,
            capability
          )
        end)
      )
    end
  end

  defp with_current_session(
         persistence,
         actor,
         validated,
         %PublicRequestSession{support: nil} = request,
         operation
       ) do
    with %{rows: [["read committed"]]} <- Repo.query!("SHOW transaction_isolation"),
         {:ok, current} <-
           SessionFoundation.validate(persistence, validated, %{token: request.session_token}),
         true <-
           current.id == request.session.id and current.actor_id == actor.actor_id and
             current.tenant_id == actor.tenant_id and
             current.membership_id == request.session.membership_id do
      operation.(actor, validated)
    else
      _denied -> error(:forbidden)
    end
  end

  defp with_current_session(_persistence, _actor, _validated, _request, _operation),
    do: error(:forbidden)

  defp read_year_authorized(actor, validated, calendar_id, academic_year_id, status, capability) do
    with :ok <- authorize(validated, capability),
         do: load_year(actor.tenant_id, calendar_id, academic_year_id, status)
  end

  defp prepare(:register, actor, input) do
    with :ok <- exact_keys(input, @base_keys ++ [:institutional_unit_id, :code]),
         {:ok, base} <- base(input),
         {:ok, institutional_unit_id} <- uuid(input.institutional_unit_id),
         {:ok, code} <- code(input.code),
         {:ok, _unit} <- eligible_institution(actor.tenant_id, institutional_unit_id) do
      {:ok, Map.merge(base, %{institutional_unit_id: institutional_unit_id, code: code})}
    end
  end

  defp prepare(operation, actor, input) when operation in [:define, :replace] do
    expected_keys =
      @base_keys ++
        @definition_keys ++ if(operation == :replace, do: [:expected_version], else: [])

    with :ok <- exact_keys(input, expected_keys),
         {:ok, base} <- base(input),
         {:ok, calendar_id} <- uuid(input.calendar_id),
         {:ok, academic_year_id} <- uuid(input.academic_year_id),
         {:ok, owner} <- calendar_owner(actor.tenant_id, calendar_id),
         {:ok, preview} <-
           input
           |> Map.take(@definition_keys)
           |> Map.merge(%{
             calendar_id: calendar_id,
             academic_year_id: academic_year_id,
             institutional_unit_id: owner.institutional_unit_id
           })
           |> Contract.preview_publication(),
         :ok <- valid_zone(preview.definition.time_zone),
         {:ok, expected_version} <- expected_version(operation, input) do
      {:ok,
       base
       |> Map.merge(%{
         calendar_id: calendar_id,
         academic_year_id: academic_year_id,
         preview: preview
       })
       |> maybe_put_version(operation, expected_version)}
    end
  end

  defp prepare(:publish, _actor, input) do
    with :ok <-
           exact_keys(
             input,
             @base_keys ++ [:calendar_id, :academic_year_id, :expected_version]
           ),
         {:ok, base} <- base(input),
         {:ok, calendar_id} <- uuid(input.calendar_id),
         {:ok, academic_year_id} <- uuid(input.academic_year_id),
         {:ok, expected_version} <- positive_integer(input.expected_version) do
      {:ok,
       Map.merge(base, %{
         calendar_id: calendar_id,
         academic_year_id: academic_year_id,
         expected_version: expected_version
       })}
    end
  end

  defp prepare(_operation, _actor, _input), do: error(:invalid_input)

  defp insert_year(tenant_id, preview) do
    d = preview.definition

    write_one(
      """
      INSERT INTO academic_years
        (id, tenant_id, calendar_id, code, label, start_on, end_on, time_zone,
         instructional_weekdays, candidate_revision, status, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'draft', 1,
              (statement_timestamp() AT TIME ZONE 'utc'),
              (statement_timestamp() AT TIME ZONE 'utc'))
      """,
      [
        dump(d.academic_year_id),
        dump(tenant_id),
        dump(d.calendar_id),
        d.code,
        d.label,
        d.start_on,
        d.end_on,
        d.time_zone,
        d.instructional_weekdays,
        preview.candidate_revision
      ]
    )
  end

  defp update_year(tenant_id, preview, expected_version) do
    d = preview.definition

    write_one(
      """
      UPDATE academic_years
      SET code = $5, label = $6, start_on = $7, end_on = $8, time_zone = $9,
          instructional_weekdays = $10, candidate_revision = $11,
          lock_version = lock_version + 1,
          updated_at = (statement_timestamp() AT TIME ZONE 'utc')
      WHERE tenant_id = $1 AND calendar_id = $2 AND id = $3
        AND status = 'draft' AND lock_version = $4
      """,
      [
        dump(tenant_id),
        dump(d.calendar_id),
        dump(d.academic_year_id),
        expected_version,
        d.code,
        d.label,
        d.start_on,
        d.end_on,
        d.time_zone,
        d.instructional_weekdays,
        preview.candidate_revision
      ]
    )
  end

  defp publish_year(tenant_id, input, revision) do
    write_one(
      """
      UPDATE academic_years
      SET status = 'published', lock_version = lock_version + 1,
          updated_at = (statement_timestamp() AT TIME ZONE 'utc')
      WHERE tenant_id = $1 AND calendar_id = $2 AND id = $3
        AND status = 'draft' AND lock_version = $4 AND candidate_revision = $5
      """,
      [
        dump(tenant_id),
        dump(input.calendar_id),
        dump(input.academic_year_id),
        input.expected_version,
        revision
      ]
    )
  end

  defp insert_children(tenant_id, preview) do
    d = preview.definition

    with :ok <-
           write_many(d.periods, fn period ->
             Repo.query(
               """
               INSERT INTO academic_periods
                 (id, tenant_id, academic_year_id, period_type_key, label, sequence,
                  start_on, end_on, inserted_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8,
                       (statement_timestamp() AT TIME ZONE 'utc'))
               """,
               [
                 dump(period.id),
                 dump(tenant_id),
                 dump(d.academic_year_id),
                 period.period_type_key,
                 period.label,
                 period.sequence,
                 period.start_on,
                 period.end_on
               ]
             )
           end) do
      write_many(d.closures, fn closure ->
        Repo.query(
          """
          INSERT INTO academic_calendar_closures
            (id, tenant_id, academic_year_id, date, reason_key, label, inserted_at)
          VALUES ($1, $2, $3, $4, $5, $6,
                  (statement_timestamp() AT TIME ZONE 'utc'))
          """,
          [
            dump(closure.id),
            dump(tenant_id),
            dump(d.academic_year_id),
            closure.date,
            closure.reason_key,
            closure.label
          ]
        )
      end)
    end
  end

  defp replace_children(tenant_id, preview) do
    year_id = preview.definition.academic_year_id

    with {:ok, _} <-
           Repo.query(
             "DELETE FROM academic_calendar_closures WHERE tenant_id = $1 AND academic_year_id = $2",
             [dump(tenant_id), dump(year_id)]
           ),
         {:ok, _} <-
           Repo.query(
             "DELETE FROM academic_periods WHERE tenant_id = $1 AND academic_year_id = $2",
             [dump(tenant_id), dump(year_id)]
           ),
         do: insert_children(tenant_id, preview)
  end

  defp load_year(tenant_id, calendar_id, academic_year_id, required_status) do
    with {:ok, row} <-
           one(
             """
             SELECT y.id::text, y.code, y.label, y.start_on, y.end_on, y.time_zone,
                    y.instructional_weekdays, y.candidate_revision, y.status, y.lock_version,
                    c.institutional_unit_id::text
             FROM academic_years y
             JOIN academic_calendars c
               ON c.id = y.calendar_id AND c.tenant_id = y.tenant_id
             WHERE y.tenant_id = $1 AND y.calendar_id = $2 AND y.id = $3 AND y.status = $4
             """,
             [
               dump(tenant_id),
               dump(calendar_id),
               dump(academic_year_id),
               Atom.to_string(required_status)
             ],
             [
               :id,
               :code,
               :label,
               :start_on,
               :end_on,
               :time_zone,
               :instructional_weekdays,
               :candidate_revision,
               :status,
               :lock_version,
               :institutional_unit_id
             ]
           ),
         {:ok, periods} <- load_periods(tenant_id, academic_year_id),
         {:ok, closures} <- load_closures(tenant_id, academic_year_id),
         {:ok, preview} <-
           Contract.preview_publication(%{
             academic_year_id: row.id,
             calendar_id: calendar_id,
             closures: closures,
             code: row.code,
             end_on: row.end_on,
             institutional_unit_id: row.institutional_unit_id,
             instructional_weekdays: row.instructional_weekdays,
             label: row.label,
             periods: periods,
             start_on: row.start_on,
             time_zone: row.time_zone
           }),
         :ok <- ensure(preview.candidate_revision == row.candidate_revision, :conflict) do
      {:ok,
       %YearView{
         preview: preview,
         status: status_atom(row.status),
         lock_version: row.lock_version
       }}
    end
  end

  defp load_periods(tenant_id, academic_year_id) do
    many(
      """
      SELECT id::text, period_type_key, label, sequence, start_on, end_on
      FROM academic_periods
      WHERE tenant_id = $1 AND academic_year_id = $2
      ORDER BY sequence
      """,
      [dump(tenant_id), dump(academic_year_id)],
      [:id, :period_type_key, :label, :sequence, :start_on, :end_on]
    )
  end

  defp load_closures(tenant_id, academic_year_id) do
    many(
      """
      SELECT id::text, date, reason_key, label
      FROM academic_calendar_closures
      WHERE tenant_id = $1 AND academic_year_id = $2
      ORDER BY date
      """,
      [dump(tenant_id), dump(academic_year_id)],
      [:id, :date, :reason_key, :label]
    )
  end

  defp eligible_institution(tenant_id, institutional_unit_id) do
    one(
      """
      SELECT u.id::text
      FROM institutional_units u
      JOIN institution_publications p
        ON p.tenant_id = u.tenant_id AND p.institutional_unit_id = u.id
      JOIN institution_initial_operator_assignments a
        ON a.tenant_id = p.tenant_id AND a.id = p.operator_assignment_id
       AND a.institutional_unit_id = p.institutional_unit_id
      WHERE u.tenant_id = $1 AND u.id = $2
        AND u.classification = 'institution' AND u.status = 'published'
      FOR SHARE OF u, p, a
      """,
      [dump(tenant_id), dump(institutional_unit_id)],
      [:id]
    )
  end

  defp calendar_owner(tenant_id, calendar_id) do
    one(
      """
      SELECT c.institutional_unit_id::text
      FROM academic_calendars c
      JOIN institutional_units u
        ON u.tenant_id = c.tenant_id AND u.id = c.institutional_unit_id
      JOIN institution_publications p
        ON p.tenant_id = u.tenant_id AND p.institutional_unit_id = u.id
      JOIN institution_initial_operator_assignments a
        ON a.tenant_id = p.tenant_id AND a.id = p.operator_assignment_id
       AND a.institutional_unit_id = p.institutional_unit_id
      WHERE c.tenant_id = $1 AND c.id = $2 AND c.status = 'active'
        AND u.classification = 'institution' AND u.status = 'published'
      FOR SHARE OF c, u, p, a
      """,
      [dump(tenant_id), dump(calendar_id)],
      [:institutional_unit_id]
    )
  end

  defp lock_year(tenant_id, calendar_id, academic_year_id) do
    one(
      """
      SELECT status, lock_version, candidate_revision
      FROM academic_years
      WHERE tenant_id = $1 AND calendar_id = $2 AND id = $3
      FOR UPDATE
      """,
      [dump(tenant_id), dump(calendar_id), dump(academic_year_id)],
      [:status, :lock_version, :candidate_revision]
    )
  end

  defp no_published_overlap(tenant_id, preview) do
    d = preview.definition

    case Repo.query(
           """
           SELECT 1 FROM academic_years
           WHERE tenant_id = $1 AND calendar_id = $2 AND status = 'published'
             AND id <> $3 AND daterange(start_on, end_on, '[]') && daterange($4, $5, '[]')
           LIMIT 1
           """,
           [dump(tenant_id), dump(d.calendar_id), dump(d.academic_year_id), d.start_on, d.end_on]
         ) do
      {:ok, %{rows: []}} -> :ok
      {:ok, %{rows: [_row]}} -> error(:overlap, :academic_year)
      _failed -> error(:retryable_dependency)
    end
  end

  defp year_for_date(tenant_id, calendar_id, date) do
    case Repo.query(
           """
           SELECT id::text FROM academic_years
           WHERE tenant_id = $1 AND calendar_id = $2 AND status = 'published'
             AND start_on <= $3 AND end_on >= $3
           ORDER BY id LIMIT 2
           """,
           [dump(tenant_id), dump(calendar_id), date]
         ) do
      {:ok, %{rows: [[id]]}} -> {:ok, id}
      {:ok, %{rows: []}} -> error(:not_found, :local_date)
      {:ok, %{rows: _conflict}} -> error(:conflict, :local_date)
      _failed -> error(:retryable_dependency)
    end
  end

  defp valid_zone(zone) do
    case Repo.query("SELECT 1 FROM pg_timezone_names WHERE name = $1 LIMIT 1", [zone]) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, %{rows: []}} -> error(:unsupported_time_zone, :time_zone)
      _failed -> error(:retryable_dependency)
    end
  end

  defp authorize(context, capability) do
    case ModuleLifecycle.authorize_current_transaction(
           release_manifest(),
           context,
           @module_key,
           Map.fetch!(@capabilities, capability)
         ) do
      :ok ->
        :ok

      {:error, %ModuleLifecycleError{code: :forbidden}} ->
        error(:forbidden)

      {:error, %ModuleLifecycleError{code: :retryable_dependency}} ->
        error(:retryable_dependency)

      {:error, %ModuleLifecycleError{}} ->
        error(:module_unavailable)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp action_result(payload, audit, event) when is_map(payload) do
    with {:ok, id} <- uuid(payload["id"]),
         {:ok, audit} <- uuid(audit),
         {:ok, event} <- uuid(event),
         {:ok, kind} <- result_kind(payload["kind"]),
         {:ok, status} <- result_status(payload["status"]),
         true <- is_integer(payload["lock_version"]) and payload["lock_version"] > 0,
         true <-
           is_nil(payload["candidate_revision"]) or
             (is_binary(payload["candidate_revision"]) and
                String.match?(payload["candidate_revision"], ~r/^[0-9a-f]{64}$/)) do
      {:ok,
       %ActionResult{
         id: id,
         kind: kind,
         status: status,
         lock_version: payload["lock_version"],
         candidate_revision: payload["candidate_revision"],
         audit_reference: audit,
         event_id: event
       }}
    else
      _invalid -> error(:retryable_dependency)
    end
  end

  defp result_payload(id, outcome),
    do: %{
      "id" => id,
      "kind" => Atom.to_string(outcome.kind),
      "status" => Atom.to_string(outcome.status),
      "lock_version" => outcome.lock_version,
      "candidate_revision" => outcome.candidate_revision
    }

  defp outcome(kind, status, before, after_version, revision),
    do: %{
      kind: kind,
      status: status,
      before_version: before,
      lock_version: after_version,
      candidate_revision: revision
    }

  defp request_fingerprint(%{preview: preview} = input),
    do:
      input
      |> Map.drop([:preview])
      |> Map.put(:candidate_revision, preview.candidate_revision)

  defp request_fingerprint(input), do: input

  defp base(input) do
    with {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok, %{idempotency_key: idempotency_key, causation_id: causation_id}}
    end
  end

  defp expected_version(:define, _input), do: {:ok, nil}
  defp expected_version(:replace, input), do: positive_integer(input.expected_version)

  defp maybe_put_version(input, :define, _version), do: input
  defp maybe_put_version(input, :replace, version), do: Map.put(input, :expected_version, version)

  defp exact_keys(input, keys) when is_map(input) and not is_struct(input) do
    ensure(Enum.sort(Map.keys(input)) == Enum.sort(keys), :invalid_input)
  end

  defp exact_keys(_input, _keys), do: error(:invalid_input)

  defp code(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    if String.match?(normalized, ~r/^[a-z][a-z0-9_]{0,79}$/),
      do: {:ok, normalized},
      else: error(:invalid_input, :code)
  end

  defp code(_value), do: error(:invalid_input, :code)

  defp positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp positive_integer(_value), do: error(:invalid_input, :expected_version)

  defp write_many(values, writer) do
    Enum.reduce_while(values, :ok, fn value, :ok ->
      case writer.(value) do
        {:ok, %{num_rows: 1}} ->
          {:cont, :ok}

        {:error, %Postgrex.Error{postgres: %{code: code}}}
        when code in [:unique_violation, :check_violation, :foreign_key_violation] ->
          {:halt, error(:conflict)}

        _failed ->
          {:halt, error(:retryable_dependency)}
      end
    end)
  end

  defp write_one(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{num_rows: 1}} ->
        :ok

      {:error, %Postgrex.Error{postgres: %{code: code}}}
      when code in [
             :unique_violation,
             :check_violation,
             :foreign_key_violation,
             :exclusion_violation
           ] ->
        error(:conflict)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp one(sql, params, keys) do
    case Repo.query(sql, params) do
      {:ok, %{rows: [row]}} -> {:ok, Map.new(Enum.zip(keys, row))}
      {:ok, %{rows: []}} -> error(:not_found)
      _failed -> error(:retryable_dependency)
    end
  end

  defp many(sql, params, keys) do
    case Repo.query(sql, params) do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, &Map.new(Enum.zip(keys, &1)))}
      _failed -> error(:retryable_dependency)
    end
  end

  defp target(:register, _input), do: UUID.generate()
  defp target(_operation, input), do: input.academic_year_id
  defp aggregate(:register), do: @aggregate_calendar
  defp aggregate(_operation), do: @aggregate_year
  defp capability(:publish), do: :publish
  defp capability(_operation), do: :manage
  defp status_atom("draft"), do: :draft
  defp status_atom("published"), do: :published
  defp result_kind("calendar"), do: {:ok, :calendar}
  defp result_kind("academic_year"), do: {:ok, :academic_year}
  defp result_kind(_kind), do: error(:retryable_dependency)
  defp result_status("active"), do: {:ok, :active}
  defp result_status("draft"), do: {:ok, :draft}
  defp result_status("published"), do: {:ok, :published}
  defp result_status(_status), do: error(:retryable_dependency)
  defp ensure(true, _code), do: :ok
  defp ensure(_not_true, code), do: error(code)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> error(:invalid_input)
    end
  end

  defp dump(value), do: UUID.dump!(value)
  defp error(code, field \\ nil), do: {:error, %Error{code: code, field: field}}
end
