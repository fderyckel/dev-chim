defmodule Chimwemwe.Identity.AccountSourceFence do
  @moduledoc false

  alias Chimwemwe.Platform.{ExecutionContext, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @maximum_actors 25
  @budget_ms 2_000

  # Private synchronization only. The source owner supplies domain authorization,
  # trusted writer routing and the complete actor set, then uses plain MVCC reads.
  # Account row locks after this fence can deadlock against a waiting writer.
  @spec lock_current_transaction(term(), term()) ::
          :ok | {:error, :invalid_context | :invalid_input | :forbidden | :retryable_dependency}
  def lock_current_transaction(context, actor_ids) do
    with :ok <- valid_context(context),
         {:ok, actors} <- normalize_actors(actor_ids),
         :ok <- budget_transaction(),
         :ok <- check_memberships(context, actors),
         {:ok, _result} <-
           Repo.query("SELECT identity_account_source_lock($1::uuid[])", [
             Enum.map(actors, &UUID.dump!/1)
           ]) do
      :ok
    else
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _unavailable -> {:error, :retryable_dependency}
    end
  rescue
    _error -> {:error, :retryable_dependency}
  catch
    :exit, _reason -> {:error, :retryable_dependency}
  end

  defp valid_context(context) do
    if ExecutionContext.validate(context) == :ok and Repo.in_transaction?(),
      do: :ok,
      else: {:error, :invalid_context}
  end

  defp normalize_actors(actors) when is_list(actors) and length(actors) <= @maximum_actors do
    Enum.reduce_while(actors, {:ok, []}, fn value, {:ok, normalized} ->
      case UUID.cast(value) do
        {:ok, actor} -> {:cont, {:ok, [actor | normalized]}}
        :error -> {:halt, {:error, :invalid_input}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, normalized |> Enum.uniq() |> Enum.sort()}
      error -> error
    end
  end

  defp normalize_actors(_actors), do: {:error, :invalid_input}

  defp budget_transaction do
    case Repo.query("""
         SELECT current_setting('transaction_isolation'),
                (extract(epoch FROM current_setting('transaction_timeout')::interval) * 1000)::bigint,
                2000 - ceil(extract(epoch FROM (clock_timestamp() - transaction_timestamp())) * 1000)::bigint
         """) do
      {:ok, %{rows: [["read committed", timeout, remaining]]}} when remaining > 0 ->
        set_budget(timeout, remaining)

      _unavailable ->
        {:error, :retryable_dependency}
    end
  end

  defp set_budget(timeout, _remaining) when timeout > 0 and timeout <= @budget_ms, do: :ok

  defp set_budget(_timeout, remaining) do
    case Repo.query("SELECT set_config('transaction_timeout', $1, true)", ["#{remaining}ms"]) do
      {:ok, _result} -> :ok
      _unavailable -> {:error, :retryable_dependency}
    end
  end

  defp check_memberships(context, actors) do
    tenant = UUID.dump!(TrustedActor.tenant_id(context.actor))
    caller = UUID.dump!(TrustedActor.actor_id(context.actor))

    case Repo.query(
           """
           SELECT EXISTS (
                    SELECT 1 FROM platform_tenant_memberships WHERE tenant_id = $1 AND actor_id = $2
                  ), count(DISTINCT actor_id)
           FROM platform_tenant_memberships WHERE tenant_id = $1 AND actor_id = ANY($3::uuid[])
           """,
           [tenant, caller, Enum.map(actors, &UUID.dump!/1)]
         ) do
      {:ok, %{rows: [[true, count]]}} when count == length(actors) -> :ok
      {:ok, _denied} -> {:error, :forbidden}
      _unavailable -> {:error, :retryable_dependency}
    end
  end
end
