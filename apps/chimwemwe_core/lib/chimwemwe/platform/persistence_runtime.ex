defmodule Chimwemwe.Platform.PersistenceRuntime do
  @moduledoc """
  Supervises explicitly configured repository pools, route state, and admission.

  Repository and placement configuration is supplied only at application startup.
  No request-facing API can add a pool, alter a route, or select a repository.
  """

  use Supervisor

  alias Chimwemwe.Platform.{DatabaseAdmission, PersistenceError, PlacementRegistry}
  alias Chimwemwe.Repo

  @allowed_options [
    :name,
    :per_placement_limit,
    :per_tenant_limit,
    :placements,
    :repositories,
    :retry_after_ms
  ]

  @type option ::
          {:name, Supervisor.name()}
          | {:per_placement_limit, pos_integer()}
          | {:per_tenant_limit, pos_integer()}
          | {:placements, [keyword()]}
          | {:repositories, keyword(keyword())}
          | {:retry_after_ms, pos_integer() | nil}

  @spec start_link([option()]) :: Supervisor.on_start()
  def start_link(options) when is_list(options) do
    {name, init_options} = Keyword.pop(options, :name)
    Supervisor.start_link(__MODULE__, init_options, name: name)
  end

  @doc false
  @spec child_pid(Supervisor.supervisor(), term()) ::
          {:ok, pid()} | {:error, PersistenceError.t()}
  def child_pid(runtime, child_id) do
    runtime
    |> Supervisor.which_children()
    |> Enum.find_value(fn
      {^child_id, pid, _type, _modules} when is_pid(pid) -> {:ok, pid}
      _other -> nil
    end)
    |> case do
      {:ok, _pid} = found -> found
      nil -> persistence_error(:retryable_dependency)
    end
  catch
    :exit, _reason -> persistence_error(:retryable_dependency)
  end

  @impl true
  def init(options) do
    with :ok <- validate_option_keys(options),
         {:ok, repositories} <- validate_repositories(options),
         {:ok, placements} <- required_list(options, :placements),
         {:ok, admission_options} <- admission_options(options) do
      repository_ids = Keyword.keys(repositories)

      children =
        Enum.map(repositories, &repository_child/1) ++
          [
            Supervisor.child_spec(
              {PlacementRegistry, placements: placements, repository_ids: repository_ids},
              id: PlacementRegistry
            ),
            Supervisor.child_spec({DatabaseAdmission, admission_options}, id: DatabaseAdmission)
          ]

      Supervisor.init(children, strategy: :one_for_all)
    else
      {:error, field} -> {:stop, {:invalid_persistence_runtime, field}}
    end
  end

  defp repository_child({repository_id, options}) do
    child = {Repo, Keyword.put(options, :name, nil)}
    Supervisor.child_spec(child, id: {:repository, repository_id})
  end

  defp validate_option_keys(options) do
    case Keyword.keys(options) -- @allowed_options do
      [] -> :ok
      _unknown -> {:error, :unknown}
    end
  end

  defp validate_repositories(options) do
    case Keyword.fetch(options, :repositories) do
      {:ok, repositories} when is_list(repositories) and repositories != [] ->
        validate_repository_keyword(repositories)

      _missing_or_invalid ->
        {:error, :repositories}
    end
  end

  defp validate_repository_keyword(repositories) do
    if Keyword.keyword?(repositories) do
      valid_ids? =
        Enum.all?(repositories, fn {id, _config} -> is_atom(id) and not is_nil(id) end)

      valid_configs? = Enum.all?(repositories, fn {_id, config} -> Keyword.keyword?(config) end)
      unique_ids? = repositories |> Keyword.keys() |> Enum.uniq() == Keyword.keys(repositories)

      if valid_ids? and valid_configs? and unique_ids? do
        {:ok, repositories}
      else
        {:error, :repositories}
      end
    else
      {:error, :repositories}
    end
  end

  defp required_list(options, field) do
    case Keyword.fetch(options, field) do
      {:ok, value} when is_list(value) and value != [] -> {:ok, value}
      _missing_or_invalid -> {:error, field}
    end
  end

  defp admission_options(options) do
    fields = [:per_tenant_limit, :per_placement_limit, :retry_after_ms]
    {:ok, Keyword.take(options, fields)}
  end

  defp persistence_error(code), do: {:error, %PersistenceError{code: code}}
end
