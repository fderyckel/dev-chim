defmodule Chimwemwe.OrganizationLegal.Foundation do
  @moduledoc """
  Minimal governed `LegalEntity` state-transition and exact-read boundary.

  Every operation derives tenant and placement from validated context, checks
  the immutable release declaration plus current entitlement/activation and a
  tenant-defined capability, and runs on the current authoritative writer.
  There is no collection read, generic mutation, caller-selected repository,
  public route, migration intake, or educational structure here. ADR 0031 and
  ADR 0033 keep relationship, corporate-unit, and bounded lifecycle actions in
  a separate boundary while sharing this release declaration.
  """

  alias Chimwemwe.OrganizationLegal.{
    ActionResult,
    Error,
    Evidence,
    InternalWriter,
    LegalEntityView
  }

  alias Chimwemwe.Platform.{ModuleLifecycle, ModuleLifecycleError}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @module_key "organization.legal"
  @manage_capability "organization.legal.entities.manage"
  @read_capability "organization.legal.entities.read"
  @aggregate_type "organization.legal.entity"
  @register_action "organization.legal.entity.register"
  @revise_action "organization.legal.entity.profile.revise"
  @register_keys [:causation_id, :display_name, :idempotency_key, :official_name]
  @revise_keys @register_keys ++ [:expected_version, :legal_entity_id]

  @release_declaration %{
    key: @module_key,
    version: "1.2.0",
    owner: "Corporate/legal structure",
    dependencies: []
  }

  @doc "Returns the immutable release declaration used by every module gate."
  @spec release_manifest() :: ReleaseManifest.t()
  def release_manifest do
    {:ok, manifest} = ReleaseManifest.new([@release_declaration])
    manifest
  end

  @doc "Registers one synthetic tenant-owned legal entity and its first immutable profile."
  @spec register_legal_entity(Supervisor.supervisor(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def register_legal_entity(runtime, context, input) do
    with {:ok, input} <- normalize_register_input(input) do
      InternalWriter.run(runtime, context, &register_authorized(&1, &2, input))
    end
  end

  @doc "Revises the current profile while preserving entity identity and earlier revisions."
  @spec revise_legal_entity_profile(Supervisor.supervisor(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def revise_legal_entity_profile(runtime, context, input) do
    with {:ok, input} <- normalize_revise_input(input) do
      InternalWriter.run(runtime, context, &revise_authorized(&1, &2, input))
    end
  end

  @doc "Returns one exact current legal-entity profile or a non-disclosing absence."
  @spec current_legal_entity(Supervisor.supervisor(), term(), term()) ::
          {:ok, LegalEntityView.t()} | {:error, term()}
  def current_legal_entity(runtime, context, legal_entity_id) do
    with {:ok, legal_entity_id} <- cast_uuid(legal_entity_id) do
      InternalWriter.run(runtime, context, &read_authorized(&1, &2, legal_entity_id))
    end
  end

  defp register_authorized(action_context, validated_context, input) do
    with :ok <- authorize(validated_context, @manage_capability) do
      register_transaction(action_context, input)
    end
  end

  defp revise_authorized(action_context, validated_context, input) do
    with :ok <- authorize(validated_context, @manage_capability) do
      revise_transaction(action_context, input)
    end
  end

  defp read_authorized(action_context, validated_context, legal_entity_id) do
    with :ok <- authorize(validated_context, @read_capability) do
      read_current(action_context.tenant_id, legal_entity_id)
    end
  end

  defp register_transaction(context, input) do
    legal_entity_id = UUID.generate()
    request_hash = request_hash(@register_action, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             @register_action,
             @aggregate_type,
             input.idempotency_key,
             request_hash,
             legal_entity_id
           ) do
      case claim do
        {:existing, stored} -> replay(stored, context.actor_id, request_hash)
        {:new, claim_id} -> create_entity(context, input, legal_entity_id, claim_id)
      end
    end
  end

  defp create_entity(context, input, legal_entity_id, claim_id) do
    profile_id = UUID.generate()

    with :ok <- insert_entity(context.tenant_id, legal_entity_id),
         :ok <- insert_profile(context, input, legal_entity_id, profile_id, 1),
         result_payload <- result_payload(legal_entity_id, 1),
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: @register_action,
             aggregate_type: @aggregate_type,
             aggregate_id: legal_entity_id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: 0,
             after_version: 1,
             change_summary: %{"changed_fields" => ["display_name", "official_name"]},
             event_type: "organization.legal.entity.registered",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      action_result(result_payload, evidence)
    end
  end

  defp revise_transaction(context, input) do
    request_hash = request_hash(@revise_action, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             @revise_action,
             @aggregate_type,
             input.idempotency_key,
             request_hash,
             input.legal_entity_id
           ) do
      case claim do
        {:existing, stored} -> replay(stored, context.actor_id, request_hash)
        {:new, claim_id} -> revise_entity(context, input, claim_id)
      end
    end
  end

  defp revise_entity(context, input, claim_id) do
    with {:ok, current} <- lock_current(context.tenant_id, input.legal_entity_id),
         :ok <- ensure(current.lock_version == input.expected_version, :stale),
         {:ok, changed_fields} <- changed_fields(current, input),
         next_version = current.lock_version + 1,
         :ok <- update_entity(context.tenant_id, input.legal_entity_id, current.lock_version),
         :ok <-
           insert_profile(
             context,
             input,
             input.legal_entity_id,
             UUID.generate(),
             next_version
           ),
         result_payload <- result_payload(input.legal_entity_id, next_version),
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: @revise_action,
             aggregate_type: @aggregate_type,
             aggregate_id: input.legal_entity_id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: current.lock_version,
             after_version: next_version,
             change_summary: %{"changed_fields" => changed_fields},
             event_type: "organization.legal.entity.profile_revised",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      action_result(result_payload, evidence)
    end
  end

  defp insert_entity(tenant_id, legal_entity_id) do
    case Repo.query(
           """
           INSERT INTO organization_legal_entities (
             id, tenant_id, status, lock_version, inserted_at, updated_at
           )
           VALUES ($1, $2, 'active', 1,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           """,
           [dump_uuid(legal_entity_id), dump_uuid(tenant_id)]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_profile(context, input, legal_entity_id, profile_id, revision_number) do
    case Repo.query(
           """
           INSERT INTO organization_legal_entity_profile_revisions (
             id, tenant_id, legal_entity_id, revision_number, official_name,
             display_name, recorded_by_actor_id, recorded_at, inserted_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           """,
           [
             dump_uuid(profile_id),
             dump_uuid(context.tenant_id),
             dump_uuid(legal_entity_id),
             revision_number,
             input.official_name,
             input.display_name,
             dump_uuid(context.actor_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp lock_current(tenant_id, legal_entity_id) do
    case Repo.query(
           """
           SELECT entity.status, entity.lock_version,
                  profile.official_name, profile.display_name
           FROM organization_legal_entities AS entity
           JOIN organization_legal_entity_profile_revisions AS profile
             ON profile.tenant_id = entity.tenant_id
            AND profile.legal_entity_id = entity.id
            AND profile.revision_number = entity.lock_version
           WHERE entity.tenant_id = $1 AND entity.id = $2
           FOR UPDATE OF entity
           """,
           [dump_uuid(tenant_id), dump_uuid(legal_entity_id)]
         ) do
      {:ok, %{rows: [["active", lock_version, official_name, display_name]]}} ->
        {:ok,
         %{
           lock_version: lock_version,
           official_name: official_name,
           display_name: display_name
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp update_entity(tenant_id, legal_entity_id, expected_version) do
    case Repo.query(
           """
           UPDATE organization_legal_entities
           SET lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND lock_version = $3
           """,
           [dump_uuid(tenant_id), dump_uuid(legal_entity_id), expected_version]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _not_updated} -> error(:stale)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp read_current(tenant_id, legal_entity_id) do
    case Repo.query(
           """
           SELECT entity.id::text, entity.status, entity.lock_version,
                  profile.official_name, profile.display_name, profile.recorded_at
           FROM organization_legal_entities AS entity
           JOIN organization_legal_entity_profile_revisions AS profile
             ON profile.tenant_id = entity.tenant_id
            AND profile.legal_entity_id = entity.id
            AND profile.revision_number = entity.lock_version
           WHERE entity.tenant_id = $1 AND entity.id = $2
           """,
           [dump_uuid(tenant_id), dump_uuid(legal_entity_id)]
         ) do
      {:ok,
       %{
         rows: [
           [id, "active", lock_version, official_name, display_name, recorded_at]
         ]
       }} ->
        {:ok,
         %LegalEntityView{
           id: id,
           official_name: official_name,
           display_name: display_name,
           status: :active,
           lock_version: lock_version,
           recorded_at: utc_datetime(recorded_at)
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      {:ok, _inconsistent} ->
        error(:retryable_dependency)

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp replay(stored, actor_id, request_hash) do
    with {:ok, replay} <- Evidence.replay(stored, actor_id, request_hash),
         {:ok, id} <- cast_uuid(replay.aggregate_id),
         %{"legal_entity_id" => ^id, "lock_version" => lock_version, "status" => "active"} <-
           replay.result_payload,
         true <- is_integer(lock_version) and lock_version > 0,
         {:ok, audit_reference} <- cast_uuid(replay.audit_reference),
         {:ok, event_id} <- cast_uuid(replay.event_id) do
      {:ok,
       %ActionResult{
         id: id,
         status: :active,
         lock_version: lock_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{}} = error -> error
      _invalid_stored_result -> error(:retryable_dependency)
    end
  end

  defp action_result(result_payload, evidence) do
    {:ok,
     %ActionResult{
       id: result_payload["legal_entity_id"],
       status: :active,
       lock_version: result_payload["lock_version"],
       audit_reference: evidence.audit_reference,
       event_id: evidence.event_id
     }}
  end

  defp result_payload(legal_entity_id, lock_version) do
    %{
      "legal_entity_id" => legal_entity_id,
      "lock_version" => lock_version,
      "status" => "active"
    }
  end

  defp changed_fields(current, input) do
    fields =
      []
      |> add_changed(current.official_name != input.official_name, "official_name")
      |> add_changed(current.display_name != input.display_name, "display_name")
      |> Enum.reverse()

    case fields do
      [] -> error(:conflict)
      changed -> {:ok, changed}
    end
  end

  defp add_changed(fields, true, field), do: [field | fields]
  defp add_changed(fields, false, _field), do: fields

  defp authorize(context, capability) do
    case ModuleLifecycle.authorize_current_transaction(
           release_manifest(),
           context,
           @module_key,
           capability
         ) do
      :ok ->
        :ok

      {:error, %ModuleLifecycleError{code: :forbidden}} ->
        error(:forbidden)

      {:error, %ModuleLifecycleError{code: :retryable_dependency}} ->
        error(:retryable_dependency)

      {:error, %ModuleLifecycleError{code: :invalid_input}} ->
        error(:invalid_input)

      {:error, %ModuleLifecycleError{}} ->
        error(:module_unavailable)

      _unexpected ->
        error(:retryable_dependency)
    end
  end

  defp normalize_register_input(input) do
    with {:ok, normalized} <- normalize_keys(input, @register_keys),
         {:ok, official_name} <- normalized_name(normalized.official_name),
         {:ok, display_name} <- normalized_name(normalized.display_name),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         official_name: official_name,
         display_name: display_name,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_revise_input(input) do
    with {:ok, normalized} <- normalize_keys(input, @revise_keys),
         {:ok, legal_entity_id} <- cast_uuid(normalized.legal_entity_id),
         true <- is_integer(normalized.expected_version) and normalized.expected_version > 0,
         {:ok, official_name} <- normalized_name(normalized.official_name),
         {:ok, display_name} <- normalized_name(normalized.display_name),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         legal_entity_id: legal_entity_id,
         expected_version: normalized.expected_version,
         official_name: official_name,
         display_name: display_name,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      false -> error(:invalid_input)
      {:error, %Error{}} = error -> error
    end
  end

  defp normalize_keys(input, expected_keys) when is_map(input) and not is_struct(input) do
    normalized =
      Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
        case normalize_key(key, expected_keys) do
          {:ok, normalized_key} when not is_map_key(acc, normalized_key) ->
            {:cont, {:ok, Map.put(acc, normalized_key, value)}}

          _invalid_or_duplicate ->
            {:halt, error(:invalid_input)}
        end
      end)

    with {:ok, values} <- normalized,
         true <- Enum.sort(Map.keys(values)) == Enum.sort(expected_keys) do
      {:ok, values}
    else
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_keys(_input, _expected_keys), do: error(:invalid_input)

  defp normalize_key(key, expected_keys) when is_atom(key) do
    if key in expected_keys, do: {:ok, key}, else: :error
  end

  defp normalize_key(key, expected_keys) when is_binary(key) do
    case Enum.find(expected_keys, &(Atom.to_string(&1) == key)) do
      nil -> :error
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_key(_key, _expected_keys), do: :error

  defp normalized_name(value) when is_binary(value) do
    normalized = String.trim(value)

    if String.length(normalized) in 1..200 do
      {:ok, normalized}
    else
      error(:invalid_input)
    end
  end

  defp normalized_name(_value), do: error(:invalid_input)

  defp request_hash(action_name, input) do
    {action_name, input}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              "organization_legal_entity_profiles_revision_index",
              :organization_legal_entity_profiles_revision_index
            ],
       do: error(:stale)

  defp translate_query_error(%PostgrexError{postgres: %{code: :foreign_key_violation}}),
    do: error(:not_found)

  defp translate_query_error(%PostgrexError{postgres: %{code: :check_violation}}),
    do: error(:invalid_input)

  defp translate_query_error(_error), do: error(:retryable_dependency)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> error(:invalid_input)
    end
  end

  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)

  defp utc_datetime(%DateTime{} = value), do: value
  defp utc_datetime(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")

  defp dump_uuid(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
