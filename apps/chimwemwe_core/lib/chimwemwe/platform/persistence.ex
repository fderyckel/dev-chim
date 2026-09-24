defmodule Chimwemwe.Platform.Persistence do
  @moduledoc """
  Runs synchronous writer work through trusted routing and admission.

  The caller supplies only a persistence runtime, a validated execution context,
  and a zero-argument operation. The runtime owns repository selection. Dynamic
  repository state is restored after success or failure and is not inherited by
  spawned work.
  """

  alias Chimwemwe.Platform.{
    DatabaseAdmission,
    ExecutionContext,
    PersistenceRuntime,
    PlacementRegistry
  }

  alias Chimwemwe.Repo

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
      DatabaseAdmission.with_permit(admission, context, fn ->
        with_repository(repository, operation)
      end)
    end
  end

  defp with_repository(repository, operation) do
    previous_repository = Repo.put_dynamic_repo(repository)

    try do
      operation.()
    after
      Repo.put_dynamic_repo(previous_repository)
    end
  end
end
