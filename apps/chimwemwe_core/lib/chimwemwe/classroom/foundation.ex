defmodule Chimwemwe.Classroom.Foundation do
  @moduledoc """
  Private synthetic class setup. Exact published calendar references only.
  Administrative exact reads; no educator roster, public interface or implied access.
  """
  alias Chimwemwe.Classroom.{Error, Evidence, InternalWriter}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.{ModuleLifecycle, ModuleLifecycleError}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @module "classroom.core"
  @keys [:idempotency_key, :causation_id]
  @actions %{
    create_class:
      {"classes.create",
       [
         :institutional_unit_id,
         :calendar_id,
         :academic_year_id,
         :calendar_revision,
         :code,
         :label
       ]},
    enrol_student:
      {"enrolments.record",
       [
         :participation_id,
         :expected_participation_version,
         :academic_year_id,
         :calendar_revision,
         :effective_from,
         :effective_until
       ]},
    assign_teacher:
      {"assignments.record",
       [
         :participation_id,
         :expected_participation_version,
         :class_id,
         :expected_class_version,
         :effective_from,
         :effective_until
       ]},
    place_student:
      {"placements.record",
       [
         :enrolment_id,
         :expected_enrolment_version,
         :class_id,
         :expected_class_version,
         :effective_from,
         :effective_until
       ]},
    end_enrolment: {"enrolments.end", [:enrolment_id, :expected_version, :effective_until]},
    end_teaching_assignment:
      {"assignments.end", [:assignment_id, :expected_version, :effective_until]},
    end_placement: {"placements.end", [:placement_id, :expected_version, :effective_until]}
  }
  @tables %{
    class: "classroom_classes",
    enrolment: "classroom_enrolments",
    assignment: "classroom_teaching_assignments",
    placement: "classroom_placements"
  }
  @fields %{
    class: [
      :institutional_unit_id,
      :calendar_id,
      :academic_year_id,
      :calendar_revision,
      :code,
      :label
    ],
    enrolment: [
      :participation_id,
      :academic_year_id,
      :calendar_revision,
      :effective_from,
      :effective_until
    ],
    assignment: [:participation_id, :class_id, :effective_from, :effective_until],
    placement: [:enrolment_id, :class_id, :effective_from, :effective_until]
  }
  @uuid_keys [
    :idempotency_key,
    :causation_id,
    :institutional_unit_id,
    :calendar_id,
    :academic_year_id,
    :participation_id,
    :class_id,
    :enrolment_id,
    :assignment_id,
    :placement_id
  ]
  @version_keys [
    :expected_version,
    :expected_participation_version,
    :expected_class_version,
    :expected_enrolment_version
  ]

  @spec release_manifest() :: ReleaseManifest.t()
  def release_manifest do
    declarations =
      (ReleaseManifest.declarations(People.release_manifest()) ++
         ReleaseManifest.declarations(Chimwemwe.AcademicCalendar.Foundation.release_manifest()))
      |> Enum.uniq()

    {:ok, manifest} =
      ReleaseManifest.new(
        declarations ++
          [
            %{
              key: @module,
              version: "1.0.0",
              owner: "Classroom setup",
              dependencies: ["people.core", "academics.calendar"]
            }
          ]
      )

    manifest
  end

  def create_class(persistence, context, input),
    do: mutate(persistence, context, :create_class, input)

  def enrol_student(persistence, context, input),
    do: mutate(persistence, context, :enrol_student, input)

  def assign_teacher(persistence, context, input),
    do: mutate(persistence, context, :assign_teacher, input)

  def place_student(persistence, context, input),
    do: mutate(persistence, context, :place_student, input)

  def end_enrolment(persistence, context, input),
    do: mutate(persistence, context, :end_enrolment, input)

  def end_teaching_assignment(persistence, context, input),
    do: mutate(persistence, context, :end_teaching_assignment, input)

  def end_placement(persistence, context, input),
    do: mutate(persistence, context, :end_placement, input)

  def current_class(persistence, context, id), do: read(persistence, context, :class, id)
  def current_enrolment(persistence, context, id), do: read(persistence, context, :enrolment, id)

  def current_teaching_assignment(persistence, context, id),
    do: read(persistence, context, :assignment, id)

  def current_placement(persistence, context, id), do: read(persistence, context, :placement, id)

  defp mutate(persistence, context, operation, input) do
    InternalWriter.run(persistence, context, fn actor, validated ->
      with :ok <- authorize(validated, capability(operation)),
           {:ok, input} <- normalize(operation, input),
           do: transact(persistence, actor, operation, input)
    end)
  end

  defp transact(persistence, actor, operation, input) do
    action = @module <> "." <> capability(operation)
    kind = aggregate(operation)
    id = target(operation, input)
    hash = :crypto.hash(:sha256, :erlang.term_to_binary({action, input}, [:deterministic]))

    with {:ok, claim} <-
           Evidence.claim(
             actor,
             action,
             @module <> "." <> Atom.to_string(kind),
             input.idempotency_key,
             hash,
             id
           ) do
      execute_claim(claim, persistence, actor, operation, input, id, action, hash)
    end
  end

  defp execute_claim(
         {:existing, stored},
         _persistence,
         actor,
         _operation,
         _input,
         _id,
         _action,
         hash
       ) do
    with {:ok, replay} <- Evidence.replay(stored, actor.actor_id, hash) do
      result(replay.result_payload, replay.audit_reference, replay.event_id)
    end
  end

  defp execute_claim({:new, claim_id}, persistence, actor, operation, input, id, action, _hash) do
    with {:ok, version} <- perform(persistence, actor, operation, input, id),
         payload = %{"id" => id, "lock_version" => version},
         {:ok, evidence} <-
           Evidence.record(actor, %{
             action_name: action,
             aggregate_type: @module <> "." <> Atom.to_string(aggregate(operation)),
             aggregate_id: id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: version - 1,
             after_version: version,
             change_summary: %{"action" => Atom.to_string(operation)},
             event_type: action <> ".completed",
             event_payload: payload,
             result_payload: payload,
             claim_id: claim_id
           }) do
      result(payload, evidence.audit_reference, evidence.event_id)
    end
  end

  defp result(%{"id" => id, "lock_version" => version}, audit, event),
    do: {:ok, %{id: id, lock_version: version, audit_reference: audit, event_id: event}}

  defp perform(_persistence, actor, :create_class, input, id) do
    with {:ok, year} <- year(actor.tenant_id, input.academic_year_id),
         :ok <-
           ensure(
             year.calendar_revision == input.calendar_revision and
               year.calendar_id == input.calendar_id and
               year.institutional_unit_id == input.institutional_unit_id,
             :conflict
           ),
         do: insert(:class, actor.tenant_id, id, input)
  end

  defp perform(_persistence, actor, :enrol_student, input, id) do
    with {:ok, _part} <-
           participation(
             actor.tenant_id,
             input.participation_id,
             input.expected_participation_version
           ),
         {:ok, year} <- year(actor.tenant_id, input.academic_year_id),
         :ok <- ensure(year.calendar_revision == input.calendar_revision, :conflict),
         do: insert(:enrolment, actor.tenant_id, id, input)
  end

  defp perform(_persistence, actor, :assign_teacher, input, id) do
    with {:ok, _part} <-
           participation(
             actor.tenant_id,
             input.participation_id,
             input.expected_participation_version
           ),
         {:ok, class} <- lock(:class, actor.tenant_id, input.class_id),
         :ok <- expect(class, input.expected_class_version),
         do: insert(:assignment, actor.tenant_id, id, input)
  end

  defp perform(_persistence, actor, :place_student, input, id) do
    with {:ok, enrolment} <- lock(:enrolment, actor.tenant_id, input.enrolment_id),
         :ok <- expect(enrolment, input.expected_enrolment_version),
         {:ok, class} <- lock(:class, actor.tenant_id, input.class_id),
         :ok <- expect(class, input.expected_class_version),
         do: insert(:placement, actor.tenant_id, id, input)
  end

  defp perform(_persistence, actor, operation, input, id) do
    kind = aggregate(operation)

    with {:ok, row} <- lock(kind, actor.tenant_id, id),
         :ok <- expect(row, input.expected_version),
         :ok <-
           write(
             "UPDATE #{Map.fetch!(@tables, kind)} SET effective_until = $3, lock_version = 2 WHERE id = $1 AND tenant_id = $2",
             [dump(id), dump(actor.tenant_id), input.effective_until]
           ),
         do: {:ok, 2}
  end

  defp insert(kind, tenant, id, input) do
    fields = Map.fetch!(@fields, kind)

    values =
      Enum.map(fields, fn key ->
        value = Map.fetch!(input, key)
        if key in @uuid_keys, do: dump(value), else: value
      end)

    columns = Enum.join(fields, ", ")
    placeholders = Enum.map_join(3..(length(fields) + 2), ", ", &"$#{&1}")

    with :ok <-
           write(
             "INSERT INTO #{Map.fetch!(@tables, kind)} (id, tenant_id, #{columns}, lock_version, inserted_at) VALUES ($1, $2, #{placeholders}, 1, (statement_timestamp() AT TIME ZONE 'utc'))",
             [dump(id), dump(tenant) | values]
           ),
         do: {:ok, 1}
  end

  defp read(persistence, context, kind, id) do
    InternalWriter.run(persistence, context, fn actor, validated ->
      with :ok <- authorize(validated, read_capability(kind)),
           {:ok, id} <- uuid(id),
           do: exact(kind, actor.tenant_id, id, "")
    end)
  end

  defp lock(kind, tenant, id), do: exact(kind, tenant, id, " FOR UPDATE")

  defp exact(kind, tenant, id, suffix) do
    keys = [:id | Map.fetch!(@fields, kind)] ++ [:lock_version]

    columns =
      Enum.map_join(keys, ", ", fn key ->
        if key == :id or key in @uuid_keys, do: "#{key}::text", else: Atom.to_string(key)
      end)

    one(
      "SELECT #{columns} FROM #{Map.fetch!(@tables, kind)} WHERE tenant_id = $1 AND id = $2#{suffix}",
      [dump(tenant), dump(id)],
      keys
    )
  end

  defp participation(tenant, id, version) do
    with {:ok, row} <-
           one(
             "SELECT lock_version FROM people_participations WHERE tenant_id = $1 AND id = $2 FOR UPDATE",
             [dump(tenant), dump(id)],
             [:lock_version]
           ),
         :ok <- expect(row, version),
         do: {:ok, row}
  end

  defp year(tenant, id) do
    one(
      """
      SELECT y.candidate_revision, c.id::text, c.institutional_unit_id::text
      FROM academic_years y JOIN academic_calendars c ON c.id = y.calendar_id AND c.tenant_id = y.tenant_id
      JOIN institutional_units u ON u.id = c.institutional_unit_id AND u.tenant_id = c.tenant_id
      WHERE y.tenant_id = $1 AND y.id = $2 AND y.status = 'published' AND c.status = 'active' AND u.status = 'published'
      FOR SHARE OF y, c, u
      """,
      [dump(tenant), dump(id)],
      [:calendar_revision, :calendar_id, :institutional_unit_id]
    )
  end

  defp one(sql, params, keys) do
    case Repo.query(sql, params) do
      {:ok, %{rows: [row]}} -> {:ok, Map.new(Enum.zip(keys, row))}
      {:ok, %{rows: []}} -> error(:not_found)
      _failed -> error(:retryable_dependency)
    end
  end

  defp write(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{num_rows: 1}} ->
        :ok

      {:error, %Postgrex.Error{postgres: %{code: code}}}
      when code in [:unique_violation, :check_violation, :foreign_key_violation] ->
        error(:conflict)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp authorize(context, capability) do
    case ModuleLifecycle.authorize_current_transaction(
           release_manifest(),
           context,
           @module,
           @module <> "." <> capability
         ) do
      :ok -> :ok
      {:error, %ModuleLifecycleError{code: :forbidden}} -> error(:forbidden)
      {:error, %ModuleLifecycleError{code: :retryable_dependency}} -> error(:retryable_dependency)
      _denied -> error(:module_unavailable)
    end
  end

  defp normalize(operation, input) when is_map(input) and not is_struct(input) do
    {_capability, keys} = Map.fetch!(@actions, operation)

    with true <- Enum.sort(Map.keys(input)) == Enum.sort(@keys ++ keys),
         {:ok, normalized} <- normalize_values(input),
         true <- valid_fields?(operation, normalized) do
      {:ok, normalized}
    else
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize(_operation, _input), do: error(:invalid_input)

  defp normalize_values(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case normalize_value(key, value) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        _invalid -> {:halt, error(:invalid_input)}
      end
    end)
  end

  defp normalize_value(key, value) when key in @uuid_keys, do: uuid(value)

  defp normalize_value(key, value) when key in @version_keys and is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_value(key, value)
       when key in [:effective_from, :effective_until] and is_struct(value, Date),
       do: {:ok, value}

  defp normalize_value(:calendar_revision, value) when is_binary(value) do
    if Regex.match?(~r/^[0-9a-f]{64}$/, value), do: {:ok, value}, else: error(:invalid_input)
  end

  defp normalize_value(:code, value) when is_binary(value) do
    if Regex.match?(~r/^[a-z][a-z0-9_]{0,79}$/, value),
      do: {:ok, value},
      else: error(:invalid_input)
  end

  defp normalize_value(:label, value) when is_binary(value) do
    label = String.trim(value)

    if String.valid?(label) and String.length(label) in 1..160,
      do: {:ok, label},
      else: error(:invalid_input)
  end

  defp normalize_value(_key, _value), do: error(:invalid_input)

  defp valid_fields?(operation, input)
       when operation in [:enrol_student, :assign_teacher, :place_student],
       do: Date.compare(input.effective_until, input.effective_from) == :gt

  defp valid_fields?(_operation, _input), do: true
  defp capability(operation), do: elem(Map.fetch!(@actions, operation), 0)
  defp read_capability(:class), do: "classes.read"
  defp read_capability(:enrolment), do: "enrolments.read"
  defp read_capability(:assignment), do: "assignments.read"
  defp read_capability(:placement), do: "placements.read"
  defp aggregate(:create_class), do: :class
  defp aggregate(operation) when operation in [:enrol_student, :end_enrolment], do: :enrolment

  defp aggregate(operation) when operation in [:assign_teacher, :end_teaching_assignment],
    do: :assignment

  defp aggregate(_operation), do: :placement
  defp target(:end_enrolment, input), do: input.enrolment_id
  defp target(:end_teaching_assignment, input), do: input.assignment_id
  defp target(:end_placement, input), do: input.placement_id
  defp target(_operation, _input), do: UUID.generate()
  defp expect(row, expected), do: ensure(row.lock_version == expected, :stale)
  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, value} -> {:ok, value}
      _invalid -> error(:invalid_input)
    end
  end

  defp dump(id), do: UUID.dump!(id)
  defp error(code), do: {:error, %Error{code: code}}
end
