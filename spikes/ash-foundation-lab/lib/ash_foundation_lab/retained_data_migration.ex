defmodule AshFoundationLab.RetainedDataMigration do
  @moduledoc """
  Tenant-scoped batch runner for the disposable retained-data migration rehearsal.

  The caller must resolve the database placement from trusted operator context
  before invoking this module. Request input never selects a repository or tenant.
  """

  alias AshFoundationLab.Repo
  alias Ecto.UUID

  @maximum_batch_size 100

  defmodule Context do
    @moduledoc "Trusted synthetic operator context for one tenant backfill."

    @enforce_keys [:actor_id, :tenant_id, :correlation_id]
    defstruct [:actor_id, :tenant_id, :correlation_id]

    @type t :: %__MODULE__{
            actor_id: UUID.t(),
            tenant_id: UUID.t(),
            correlation_id: UUID.t()
          }
  end

  @type failure ::
          :invalid_batch_size | :invalid_context | :missing_context | term()

  @doc "Builds the typed scope after trusted actor and placement resolution."
  @spec new_context(UUID.t(), UUID.t(), UUID.t()) ::
          {:ok, Context.t()} | {:error, :invalid_context | :missing_context}
  def new_context(actor_id, tenant_id, correlation_id) do
    with :ok <- require_context(actor_id, tenant_id, correlation_id),
         {:ok, actor_id} <- UUID.cast(actor_id),
         {:ok, tenant_id} <- UUID.cast(tenant_id),
         {:ok, correlation_id} <- UUID.cast(correlation_id) do
      {:ok,
       %Context{
         actor_id: actor_id,
         tenant_id: tenant_id,
         correlation_id: correlation_id
       }}
    else
      :missing -> {:error, :missing_context}
      :error -> {:error, :invalid_context}
    end
  end

  @doc "Copies at most `batch_size` legacy values for exactly one tenant."
  @spec backfill_batch(Context.t(), pos_integer()) ::
          {:ok, [UUID.t()]} | {:error, failure()}
  def backfill_batch(%Context{} = context, batch_size)
      when is_integer(batch_size) and batch_size > 0 and batch_size <= @maximum_batch_size do
    with :ok <- validate_context(context),
         do: Repo.transaction(fn -> run_backfill_batch(context.tenant_id, batch_size) end)
  end

  def backfill_batch(%Context{}, _batch_size), do: {:error, :invalid_batch_size}
  def backfill_batch(_context, _batch_size), do: {:error, :missing_context}

  @doc "Counts rows still requiring backfill for exactly one tenant."
  @spec remaining_count(Context.t()) :: {:ok, non_neg_integer()} | {:error, failure()}
  def remaining_count(%Context{} = context) do
    with :ok <- validate_context(context) do
      tenant_id = UUID.dump!(context.tenant_id)

      case Repo.query!(
             """
             SELECT count(*)
             FROM foundation_records
             WHERE tenant_id = $1 AND canonical_name IS NULL
             """,
             [tenant_id]
           ).rows do
        [[count]] -> {:ok, count}
      end
    end
  end

  def remaining_count(_context), do: {:error, :missing_context}

  defp run_backfill_batch(tenant_id, batch_size) do
    result =
      Repo.query!(
        """
        WITH candidates AS (
          SELECT id
          FROM foundation_records
          WHERE tenant_id = $1 AND canonical_name IS NULL
          ORDER BY inserted_at, id
          FOR UPDATE SKIP LOCKED
          LIMIT $2
        )
        UPDATE foundation_records AS record
        SET canonical_name = record.name
        FROM candidates
        WHERE record.tenant_id = $1 AND record.id = candidates.id
        RETURNING record.id
        """,
        [UUID.dump!(tenant_id), batch_size]
      )

    Enum.map(result.rows, fn [record_id] -> UUID.load!(record_id) end)
  end

  defp require_context(actor_id, tenant_id, correlation_id) do
    if actor_id && tenant_id && correlation_id, do: :ok, else: :missing
  end

  defp validate_context(%Context{} = context) do
    case new_context(context.actor_id, context.tenant_id, context.correlation_id) do
      {:ok, _context} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
