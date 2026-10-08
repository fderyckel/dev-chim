defmodule Chimwemwe.InstitutionalStructure.InternalWriter do
  @moduledoc false

  alias Chimwemwe.InstitutionalStructure.Error
  alias Chimwemwe.Platform.{ExecutionContext, Persistence, TrustedActor}
  alias Chimwemwe.Repo

  @spec run(Supervisor.supervisor(), term(), (map(), ExecutionContext.t() -> term())) ::
          {:ok, term()} | {:error, term()}
  def run(runtime, context, operation) when is_function(operation, 2) do
    ExecutionContext.with_validated(context, fn validated_context ->
      execute(runtime, validated_context, operation)
    end)
  rescue
    _error -> dependency_error()
  catch
    :exit, _reason -> dependency_error()
  end

  defp execute(runtime, validated_context, operation) do
    action_context = action_context(validated_context)

    runtime
    |> Persistence.with_writer(validated_context, fn ->
      Repo.transaction(fn -> operation.(action_context, validated_context) |> unwrap() end)
    end)
    |> normalize_result()
  end

  defp action_context(validated_context) do
    %{
      actor: validated_context.actor,
      actor_id: TrustedActor.actor_id(validated_context.actor),
      tenant_id: TrustedActor.tenant_id(validated_context.actor),
      correlation_id: validated_context.correlation_id,
      routing_version: validated_context.placement.routing_version
    }
  end

  defp unwrap({:ok, result}), do: result
  defp unwrap({:error, error}), do: Repo.rollback(error)
  defp unwrap(_unexpected), do: Repo.rollback(%Error{code: :retryable_dependency})

  defp normalize_result({:ok, {:ok, result}}), do: {:ok, result}
  defp normalize_result({:ok, {:error, error}}), do: {:error, error}
  defp normalize_result({:error, error}), do: {:error, error}
  defp normalize_result(_unexpected), do: dependency_error()

  defp dependency_error, do: {:error, %Error{code: :retryable_dependency}}
end
