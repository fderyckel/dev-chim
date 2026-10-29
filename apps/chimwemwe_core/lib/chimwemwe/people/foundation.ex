defmodule Chimwemwe.People.Foundation do
  @moduledoc """
  Private synthetic CF-4A people, participation and staff-account actions.
  No public routes, collection reads, provisioning or implicit authority.
  """
  alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
  alias Chimwemwe.People.{Error, Evidence, InternalWriter, Runtime}
  alias Chimwemwe.Platform.{ModuleLifecycle, ModuleLifecycleError}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @module "people.core"
  @keys [:idempotency_key, :causation_id]
  @actions %{
    register_person: {"persons.register", [:display_name]},
    revise_person_name:
      {"persons.revise_name", [:person_id, :expected_version, :display_name, :reason]},
    record_student_participation:
      {"participations.record_student",
       [
         :person_id,
         :expected_person_version,
         :institutional_unit_id,
         :effective_from,
         :effective_until,
         :source_reference
       ]},
    record_staff_affiliation:
      {"participations.record_staff",
       [
         :person_id,
         :expected_person_version,
         :institutional_unit_id,
         :effective_from,
         :effective_until,
         :source_reference
       ]},
    end_participation:
      {"participations.end", [:participation_id, :expected_version, :effective_until]},
    associate_staff_account:
      {"accounts.associate_staff",
       [
         :participation_id,
         :expected_version,
         :expected_person_version,
         :membership_id,
         :evidence_reference
       ]},
    revoke_staff_account_association: {"accounts.revoke", [:association_id, :expected_version]}
  }
  @tables %{
    person: "people_persons",
    participation: "people_participations",
    account: "people_staff_account_associations"
  }
  @uuid_keys [
    :idempotency_key,
    :causation_id,
    :person_id,
    :institutional_unit_id,
    :source_reference,
    :participation_id,
    :membership_id,
    :evidence_reference,
    :association_id
  ]
  @version_keys [:expected_version, :expected_person_version]

  @spec release_manifest() :: ReleaseManifest.t()
  def release_manifest do
    declarations = ReleaseManifest.declarations(Institutions.release_manifest())

    {:ok, manifest} =
      ReleaseManifest.new(
        declarations ++
          [
            %{
              key: @module,
              version: "1.0.0",
              owner: "Classroom people",
              dependencies: ["institution.structure"]
            }
          ]
      )

    manifest
  end

  def register_person(runtime, context, input),
    do: mutate(runtime, context, :register_person, input)

  def revise_person_name(runtime, context, input),
    do: mutate(runtime, context, :revise_person_name, input)

  def record_student_participation(runtime, context, input),
    do: mutate(runtime, context, :record_student_participation, input)

  def record_staff_affiliation(runtime, context, input),
    do: mutate(runtime, context, :record_staff_affiliation, input)

  def end_participation(runtime, context, input),
    do: mutate(runtime, context, :end_participation, input)

  def associate_staff_account(runtime, context, input),
    do: mutate(runtime, context, :associate_staff_account, input)

  def revoke_staff_account_association(runtime, context, input),
    do: mutate(runtime, context, :revoke_staff_account_association, input)

  def current_person(runtime, context, id), do: read(runtime, context, :person, id)
  def current_participation(runtime, context, id), do: read(runtime, context, :participation, id)

  def current_staff_account(runtime, context, membership_id),
    do: read(runtime, context, :account, membership_id)

  defp mutate(runtime, context, operation, input) do
    with {:ok, persistence} <- Runtime.persistence(runtime) do
      InternalWriter.run(
        persistence,
        context,
        &mutate_authorized(runtime, &1, &2, operation, input)
      )
    end
  end

  defp mutate_authorized(runtime, actor, validated, operation, input) do
    with :ok <- authorize(validated, capability(operation)),
         {:ok, input} <- normalize(operation, input) do
      transact(runtime, actor, operation, input)
    end
  end

  defp transact(runtime, actor, operation, input) do
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
      execute_claim(claim, runtime, actor, operation, input, id, action, hash)
    end
  end

  defp execute_claim({:existing, stored}, _runtime, actor, _operation, _input, _id, _action, hash) do
    with {:ok, replay} <- Evidence.replay(stored, actor.actor_id, hash) do
      result(replay.result_payload, replay.audit_reference, replay.event_id)
    end
  end

  defp execute_claim({:new, claim_id}, runtime, actor, operation, input, id, action, _hash) do
    with {:ok, version} <- perform(runtime, actor, operation, input, id),
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

  defp perform(_runtime, actor, :register_person, input, id) do
    with :ok <-
           write(
             "INSERT INTO people_persons (id, tenant_id, display_name, lock_version, inserted_at) VALUES ($1, $2, $3, 1, (statement_timestamp() AT TIME ZONE 'utc'))",
             [dump(id), dump(actor.tenant_id), input.display_name]
           ),
         do: {:ok, 1}
  end

  defp perform(_runtime, actor, :revise_person_name, input, id) do
    with {:ok, person} <- lock(:person, actor.tenant_id, id),
         :ok <- expect(person, input.expected_version),
         :ok <-
           write(
             "UPDATE people_persons SET display_name = $3, lock_version = lock_version + 1 WHERE id = $1 AND tenant_id = $2",
             [dump(id), dump(actor.tenant_id), input.display_name]
           ),
         do: {:ok, person.lock_version + 1}
  end

  defp perform(_runtime, actor, operation, input, id)
       when operation in [:record_student_participation, :record_staff_affiliation] do
    kind = if operation == :record_staff_affiliation, do: "staff", else: "student"

    with {:ok, person} <- lock(:person, actor.tenant_id, input.person_id),
         :ok <- expect(person, input.expected_person_version),
         {:ok, _unit} <- institution(actor.tenant_id, input.institutional_unit_id),
         :ok <-
           write(
             """
             INSERT INTO people_participations (id, tenant_id, person_id, institutional_unit_id, kind, effective_from, effective_until, source_reference, lock_version, inserted_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 1, (statement_timestamp() AT TIME ZONE 'utc'))
             """,
             [
               dump(id),
               dump(actor.tenant_id),
               dump(input.person_id),
               dump(input.institutional_unit_id),
               kind,
               input.effective_from,
               input.effective_until,
               dump(input.source_reference)
             ]
           ) do
      {:ok, 1}
    end
  end

  defp perform(_runtime, actor, :end_participation, input, id) do
    with {:ok, part} <- lock(:participation, actor.tenant_id, id),
         :ok <- expect(part, input.expected_version),
         :ok <- ensure(is_nil(part.effective_until), :conflict),
         {:ok, unit} <- institution(actor.tenant_id, part.institutional_unit_id),
         :ok <-
           ensure(
             Date.compare(input.effective_until, unit.local_date) != :lt and
               Date.compare(input.effective_until, part.effective_from) == :gt,
             :invalid_input
           ),
         :ok <-
           write(
             "UPDATE people_participations SET effective_until = $3, lock_version = 2 WHERE id = $1 AND tenant_id = $2",
             [dump(id), dump(actor.tenant_id), input.effective_until]
           ) do
      {:ok, 2}
    end
  end

  defp perform(runtime, actor, :associate_staff_account, input, id) do
    with {:ok, part} <- lock(:participation, actor.tenant_id, input.participation_id),
         :ok <- expect(part, input.expected_version),
         {:ok, person} <- lock(:person, actor.tenant_id, part.person_id),
         :ok <- expect(person, input.expected_person_version),
         {:ok, unit} <- institution(actor.tenant_id, part.institutional_unit_id),
         :ok <- ensure(current_staff?(part, unit.local_date), :conflict),
         {:ok, membership} <- membership(actor.tenant_id, input.membership_id),
         {:ok, proof} <- verify_account(runtime, actor, input, part, membership),
         :ok <-
           write(
             """
             INSERT INTO people_staff_account_associations (id, tenant_id, person_id, participation_id, membership_id, evidence_reference, verification, lock_version, inserted_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, 1, (statement_timestamp() AT TIME ZONE 'utc'))
             """,
             [
               dump(id),
               dump(actor.tenant_id),
               dump(part.person_id),
               dump(input.participation_id),
               dump(input.membership_id),
               dump(input.evidence_reference),
               proof
             ]
           ) do
      {:ok, 1}
    end
  end

  defp perform(_runtime, actor, :revoke_staff_account_association, input, id) do
    with {:ok, account} <- lock(:account, actor.tenant_id, id),
         :ok <- expect(account, input.expected_version),
         :ok <- ensure(is_nil(account.revoked_at), :conflict),
         :ok <-
           write(
             "UPDATE people_staff_account_associations SET revoked_at = (statement_timestamp() AT TIME ZONE 'utc'), revoked_by_actor_id = $3, lock_version = 2 WHERE id = $1 AND tenant_id = $2",
             [dump(id), dump(actor.tenant_id), dump(actor.actor_id)]
           ),
         do: {:ok, 2}
  end

  defp verify_account(runtime, actor, input, part, membership) do
    with {:ok, %{rows: [[checked_at]]}} <- Repo.query("SELECT statement_timestamp()"),
         request = %{
           tenant_id: actor.tenant_id,
           person_id: part.person_id,
           person_version: input.expected_person_version,
           participation_id: input.participation_id,
           participation_version: input.expected_version,
           membership_id: input.membership_id,
           actor_id: membership.actor_id,
           evidence_reference: input.evidence_reference,
           checked_at: checked_at
         },
         {:ok, proof} when is_map(proof) <- Runtime.verify(runtime, request),
         true <-
           proof ==
             Map.merge(request, %{
               policy: "synthetic.people.staff_account.v1",
               human_account: true,
               matched: true
             }) do
      {:ok,
       Map.new(proof, fn {key, value} ->
         {Atom.to_string(key),
          if(is_struct(value, DateTime), do: DateTime.to_iso8601(value), else: value)}
       end)}
    else
      _invalid -> error(:evidence_unavailable)
    end
  rescue
    _failed -> error(:evidence_unavailable)
  catch
    :exit, _reason -> error(:evidence_unavailable)
  end

  defp read(runtime, context, kind, id) do
    with {:ok, persistence} <- Runtime.persistence(runtime),
         {:ok, id} <- uuid(id) do
      InternalWriter.run(persistence, context, &read_authorized(&1, &2, kind, id))
    end
  end

  defp read_authorized(actor, validated, kind, id) do
    with :ok <- authorize(validated, read_capability(kind)),
         do: read_exact(kind, actor.tenant_id, id)
  end

  defp read_exact(:person, tenant, id),
    do:
      one(
        "SELECT id::text, display_name, lock_version FROM people_persons WHERE tenant_id = $1 AND id = $2",
        [dump(tenant), dump(id)],
        [:id, :display_name, :lock_version]
      )

  defp read_exact(:participation, tenant, id),
    do:
      one(
        "SELECT id::text, person_id::text, institutional_unit_id::text, kind, effective_from, effective_until, lock_version FROM people_participations WHERE tenant_id = $1 AND id = $2",
        [dump(tenant), dump(id)],
        [
          :id,
          :person_id,
          :institutional_unit_id,
          :kind,
          :effective_from,
          :effective_until,
          :lock_version
        ]
      )

  defp read_exact(:account, tenant, id) do
    one(
      """
      SELECT a.id::text, a.person_id::text, a.participation_id::text, a.membership_id::text, a.lock_version
      FROM people_staff_account_associations a
      JOIN people_participations p ON p.id = a.participation_id AND p.tenant_id = a.tenant_id AND p.person_id = a.person_id
      JOIN institutional_units u ON u.id = p.institutional_unit_id AND u.tenant_id = p.tenant_id
      JOIN platform_tenant_memberships m ON m.id = a.membership_id AND m.tenant_id = a.tenant_id
      WHERE a.tenant_id = $1 AND a.membership_id = $2 AND a.revoked_at IS NULL AND p.kind = 'staff' AND u.status = 'published' AND a.verification->>'actor_id' = m.actor_id::text
        AND p.effective_from <= (statement_timestamp() AT TIME ZONE u.time_zone)::date
        AND (p.effective_until IS NULL OR p.effective_until > (statement_timestamp() AT TIME ZONE u.time_zone)::date)
      """,
      [dump(tenant), dump(id)],
      [:id, :person_id, :participation_id, :membership_id, :lock_version]
    )
  end

  defp lock(kind, tenant, id) do
    fields =
      case kind do
        :person ->
          {"lock_version", [:lock_version]}

        :participation ->
          {"person_id::text, institutional_unit_id::text, kind, effective_from, effective_until, lock_version",
           [
             :person_id,
             :institutional_unit_id,
             :kind,
             :effective_from,
             :effective_until,
             :lock_version
           ]}

        :account ->
          {"revoked_at, lock_version", [:revoked_at, :lock_version]}
      end

    {columns, keys} = fields

    one(
      "SELECT #{columns} FROM #{Map.fetch!(@tables, kind)} WHERE tenant_id = $1 AND id = $2 FOR UPDATE",
      [dump(tenant), dump(id)],
      keys
    )
  end

  defp institution(tenant, id),
    do:
      one(
        "SELECT (statement_timestamp() AT TIME ZONE time_zone)::date FROM institutional_units WHERE tenant_id = $1 AND id = $2 AND status = 'published' FOR SHARE",
        [dump(tenant), dump(id)],
        [:local_date]
      )

  defp membership(tenant, id),
    do:
      one(
        "SELECT actor_id::text FROM platform_tenant_memberships WHERE tenant_id = $1 AND id = $2 FOR SHARE",
        [dump(tenant), dump(id)],
        [:actor_id]
      )

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

  defp normalize_value(:display_name, value) when is_binary(value) do
    name = String.trim(value)

    if String.valid?(name) and String.length(name) in 1..200,
      do: {:ok, name},
      else: error(:invalid_input)
  end

  defp normalize_value(key, %Date{} = value) when key in [:effective_from, :effective_until],
    do: {:ok, value}

  defp normalize_value(:effective_until, nil), do: {:ok, nil}
  defp normalize_value(:reason, :name_correction), do: {:ok, :name_correction}
  defp normalize_value(_key, _value), do: error(:invalid_input)

  defp valid_fields?(operation, input)
       when operation in [:record_student_participation, :record_staff_affiliation],
       do:
         is_nil(input.effective_until) or
           Date.compare(input.effective_until, input.effective_from) == :gt

  defp valid_fields?(:end_participation, input), do: is_struct(input.effective_until, Date)
  defp valid_fields?(_operation, _input), do: true

  defp current_staff?(part, today),
    do:
      part.kind == "staff" and Date.compare(part.effective_from, today) != :gt and
        (is_nil(part.effective_until) or Date.compare(part.effective_until, today) == :gt)

  defp capability(operation), do: elem(Map.fetch!(@actions, operation), 0)
  defp read_capability(:person), do: "persons.read"
  defp read_capability(:participation), do: "participations.read"
  defp read_capability(:account), do: "accounts.read"
  defp aggregate(operation) when operation in [:register_person, :revise_person_name], do: :person

  defp aggregate(operation)
       when operation in [:associate_staff_account, :revoke_staff_account_association],
       do: :account

  defp aggregate(_operation), do: :participation
  defp target(:revise_person_name, input), do: input.person_id
  defp target(:end_participation, input), do: input.participation_id
  defp target(:revoke_staff_account_association, input), do: input.association_id
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
