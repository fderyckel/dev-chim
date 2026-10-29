defmodule Chimwemwe.Platform.Persistence do
  @moduledoc """
  Runs synchronous writer work through trusted routing and admission.

  The caller supplies only a persistence runtime, a validated execution context,
  and a zero-argument operation. The runtime owns repository selection. Dynamic
  repository state is restored after success or failure and is not inherited by
  spawned work. Synchronous nesting can reuse admission only with the exact same
  validated scope inside that writer's active transaction; routing is rechecked.
  """

  alias Chimwemwe.Platform.{
    DatabaseAdmission,
    ExecutionContext,
    PersistenceError,
    PersistenceRuntime,
    PlacementRegistry
  }

  alias Chimwemwe.Repo

  @writer_scope_key {__MODULE__, :writer_scope}

  @doc "Runs writer work only after current-route validation and pre-checkout admission."
  @spec with_writer(Supervisor.supervisor(), term(), (-> result)) ::
          {:ok, result} | {:error, term()}
        when result: term()
  def with_writer(runtime, context, operation) when is_function(operation, 0) do
    ExecutionContext.with_validated(
      context,
      &run_with_validated_context(runtime, &1, operation)
    )
  end

  defp run_with_validated_context(runtime, context, operation) do
    with {:ok, registry} <- PersistenceRuntime.child_pid(runtime, PlacementRegistry),
         {:ok, repository_ref} <- PlacementRegistry.resolve(registry, context),
         {:ok, admission} <- PersistenceRuntime.child_pid(runtime, DatabaseAdmission),
         {:ok, repository} <-
           PersistenceRuntime.child_pid(runtime, {:repository, repository_ref}) do
      scope = %{
        owner: self(),
        context: context,
        registry: registry,
        admission: admission,
        repository: repository
      }

      admit_or_reuse(scope, operation)
    end
  end

  defp admit_or_reuse(scope, operation) do
    case Process.get(@writer_scope_key) do
      nil ->
        DatabaseAdmission.with_permit(scope.admission, scope.context, fn ->
          with_repository(scope, operation)
        end)

      ^scope ->
        reuse_current_writer(scope, operation)

      _different_scope ->
        dependency_error()
    end
  end

  defp reuse_current_writer(scope, operation) do
    if Repo.get_dynamic_repo() == scope.repository and Repo.in_transaction?() do
      {:ok, with_repository(scope, operation)}
    else
      dependency_error()
    end
  end

  defp with_repository(scope, operation) do
    previous_repository = Repo.put_dynamic_repo(scope.repository)
    previous_scope = Process.put(@writer_scope_key, scope)

    try do
      operation.()
    after
      Repo.put_dynamic_repo(previous_repository)
      restore_scope(previous_scope)
    end
  end

  defp restore_scope(nil), do: Process.delete(@writer_scope_key)
  defp restore_scope(scope), do: Process.put(@writer_scope_key, scope)

  defp dependency_error, do: {:error, %PersistenceError{code: :retryable_dependency}}
end
