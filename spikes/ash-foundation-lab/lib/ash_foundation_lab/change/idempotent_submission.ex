defmodule AshFoundationLab.Change.IdempotentSubmission do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Error.Changes.InvalidChanges
  alias Ash.Error.Changes.StaleRecord
  alias AshFoundationLab.Error.IdempotencyConflict
  alias AshFoundationLab.Repo
  alias Ecto.UUID

  @action_name "foundation_record.submit_for_review"
  @aggregate_type "foundation_record"

  @impl true
  def change(changeset, _options, _context) do
    Ash.Changeset.around_action(changeset, &run/2)
  end

  defp run(changeset, callback) do
    actor = changeset.context[:private][:actor]
    request_hash = request_hash(changeset)

    case claim(changeset, actor, request_hash) do
      {:new, claim_id} ->
        maybe_pause_after_claim(changeset)

        case validate_first_execution(changeset) do
          :ok ->
            changeset
            |> callback.()
            |> complete_after_success(claim_id)

          {:error, error} ->
            {:error, error}
        end

      {:existing, claim} ->
        replay_or_reject(changeset, callback, actor, request_hash, claim)
    end
  end

  defp validate_first_execution(changeset) do
    expected_version = Ash.Changeset.get_argument(changeset, :expected_version)

    cond do
      changeset.data.lock_version != expected_version ->
        {:error, StaleRecord.exception(resource: changeset.resource, field: :lock_version)}

      changeset.data.status != :draft ->
        {:error, InvalidChanges.exception(message: "record must be in draft state")}

      true ->
        :ok
    end
  end

  defp complete_after_success(
         {:ok, record, _returned_changeset, _instructions} = result,
         claim_id
       ) do
    case complete_claim(claim_id, record) do
      :ok -> result
      {:error, error} -> {:error, error}
    end
  end

  defp complete_after_success(result, _claim_id), do: result

  defp replay_or_reject(changeset, callback, actor, request_hash, claim) do
    if matching_completed_claim?(changeset, actor, request_hash, claim) do
      replay_record = %{
        changeset.data
        | status: :in_review,
          lock_version: claim.result_lock_version,
          audit_reference: claim.result_audit_reference
      }

      changeset
      |> Ash.Changeset.set_context(%{idempotent_replay?: true})
      |> Ash.Changeset.set_result({:ok, replay_record})
      |> callback.()
    else
      {:error, IdempotencyConflict.exception()}
    end
  end

  defp matching_completed_claim?(changeset, actor, request_hash, claim) do
    claim.status == "completed" and
      claim.actor_id == actor.id and
      claim.aggregate_id == changeset.data.id and
      claim.request_hash == request_hash
  end

  defp claim(changeset, actor, request_hash) do
    claim_id = UUID.generate()
    idempotency_key = Ash.Changeset.get_argument(changeset, :idempotency_key)

    result =
      Repo.query!(
        """
        INSERT INTO action_idempotency_keys (
          id,
          tenant_id,
          actor_id,
          action_name,
          idempotency_key,
          aggregate_type,
          aggregate_id,
          request_hash,
          status,
          inserted_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'started', NOW(), NOW())
        ON CONFLICT (tenant_id, action_name, idempotency_key) DO NOTHING
        """,
        [
          dump_uuid(claim_id),
          dump_uuid(changeset.tenant),
          dump_uuid(actor.id),
          @action_name,
          dump_uuid(idempotency_key),
          @aggregate_type,
          dump_uuid(changeset.data.id),
          request_hash
        ]
      )

    if result.num_rows == 1 do
      {:new, claim_id}
    else
      {:existing, load_claim!(changeset.tenant, idempotency_key)}
    end
  end

  defp load_claim!(tenant_id, idempotency_key) do
    assert_single_row!(
      Repo.query!(
        """
        SELECT
          actor_id::text,
          aggregate_id::text,
          request_hash,
          status,
          result_lock_version,
          result_audit_reference::text
        FROM action_idempotency_keys
        WHERE tenant_id = $1 AND action_name = $2 AND idempotency_key = $3
        FOR UPDATE
        """,
        [dump_uuid(tenant_id), @action_name, dump_uuid(idempotency_key)]
      ).rows
    )
  end

  defp assert_single_row!([
         [
           actor_id,
           aggregate_id,
           request_hash,
           status,
           result_lock_version,
           result_audit_reference
         ]
       ]) do
    %{
      actor_id: actor_id,
      aggregate_id: aggregate_id,
      request_hash: request_hash,
      status: status,
      result_lock_version: result_lock_version,
      result_audit_reference: result_audit_reference
    }
  end

  defp assert_single_row!(_rows) do
    raise "idempotency claim disappeared after conflict resolution"
  end

  defp complete_claim(claim_id, record) do
    result =
      Repo.query!(
        """
        UPDATE action_idempotency_keys
        SET
          status = 'completed',
          result_lock_version = $2,
          result_audit_reference = $3,
          completed_at = NOW(),
          updated_at = NOW()
        WHERE id = $1 AND status = 'started'
        """,
        [dump_uuid(claim_id), record.lock_version, dump_uuid(record.audit_reference)]
      )

    if result.num_rows == 1 do
      :ok
    else
      {:error, InvalidChanges.exception(message: "idempotency claim could not be completed")}
    end
  end

  defp request_hash(changeset) do
    arguments =
      [:expected_version, :correlation_id, :causation_id]
      |> Enum.map(&{&1, Ash.Changeset.get_argument(changeset, &1)})

    {@action_name, changeset.data.id, arguments}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp maybe_pause_after_claim(changeset) do
    case changeset.context[:after_idempotency_claim] do
      callback when is_function(callback, 0) -> callback.()
      _other -> :ok
    end
  end

  defp dump_uuid(value), do: UUID.dump!(value)
end
