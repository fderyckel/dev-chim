defmodule Chimwemwe.Platform.PlacementRegistry do
  @moduledoc """
  Immutable, startup-owned tenant placement registry for one runtime.

  The registry contains repository references, but returns one only after a
  validated execution context exactly matches the current tenant route. It is a
  bounded integration seam, not the later durable movement control plane.
  """

  use GenServer

  alias Chimwemwe.Platform.{ExecutionContext, PersistenceError, TrustedActor, TrustedPlacement}

  @placement_keys [:placement_ref, :profile, :repository, :routing_version, :tenant_id]

  @type repository_ref :: atom()
  @type option ::
          {:name, GenServer.name()}
          | {:placements, [keyword()]}
          | {:repository_ids, [repository_ref()]}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    {name, init_options} = Keyword.pop(options, :name)
    GenServer.start_link(__MODULE__, init_options, name: name)
  end

  @doc false
  @spec resolve(GenServer.server(), term()) ::
          {:ok, repository_ref()} | {:error, PersistenceError.t() | term()}
  def resolve(server, context) do
    ExecutionContext.with_validated(context, fn validated_context ->
      tenant_id = TrustedActor.tenant_id(validated_context.actor)

      try do
        GenServer.call(server, {:resolve, tenant_id, validated_context.placement})
      catch
        :exit, _reason -> persistence_error(:retryable_dependency)
      end
    end)
  end

  @impl true
  def init(options) do
    with :ok <- validate_option_keys(options),
         {:ok, repository_ids} <- validate_repository_ids(options),
         {:ok, placements} <- validate_placements(options, repository_ids) do
      {:ok, placements}
    else
      {:error, field} -> {:stop, {:invalid_placement_registry, field}}
    end
  end

  @impl true
  def handle_call({:resolve, tenant_id, placement}, _from, placements) do
    reply =
      case Map.fetch(placements, tenant_id) do
        {:ok, %{placement: current, repository: repository}}
        when current == placement ->
          {:ok, repository}

        _missing_stale_or_forged ->
          persistence_error(:route_not_available)
      end

    {:reply, reply, placements}
  end

  defp validate_option_keys(options) do
    case Keyword.keys(options) -- [:placements, :repository_ids] do
      [] -> :ok
      _unknown -> {:error, :unknown}
    end
  end

  defp validate_repository_ids(options) do
    case Keyword.fetch(options, :repository_ids) do
      {:ok, repository_ids} when is_list(repository_ids) and repository_ids != [] ->
        if Enum.all?(repository_ids, &(is_atom(&1) and not is_nil(&1))) and
             Enum.uniq(repository_ids) == repository_ids do
          {:ok, MapSet.new(repository_ids)}
        else
          {:error, :repository_ids}
        end

      _missing_or_invalid ->
        {:error, :repository_ids}
    end
  end

  defp validate_placements(options, repository_ids) do
    case Keyword.fetch(options, :placements) do
      {:ok, placements} when is_list(placements) and placements != [] ->
        Enum.reduce_while(placements, {:ok, %{}}, &add_placement(&1, &2, repository_ids))

      _missing_or_invalid ->
        {:error, :placements}
    end
  end

  defp add_placement(entry, {:ok, registry}, repository_ids) do
    case validate_placement(entry, repository_ids, registry) do
      {:ok, tenant_id, route} -> {:cont, {:ok, Map.put(registry, tenant_id, route)}}
      {:error, field} -> {:halt, {:error, field}}
    end
  end

  defp validate_placement(entry, repository_ids, registry) when is_list(entry) do
    with true <- Keyword.keyword?(entry),
         true <- Enum.sort(Keyword.keys(entry)) == Enum.sort(@placement_keys),
         repository when is_atom(repository) and not is_nil(repository) <-
           Keyword.fetch!(entry, :repository),
         true <- MapSet.member?(repository_ids, repository),
         {:ok, placement} <- TrustedPlacement.establish(Keyword.delete(entry, :repository)),
         tenant_id <- TrustedPlacement.tenant_id(placement),
         false <- Map.has_key?(registry, tenant_id) do
      {:ok, tenant_id, %{placement: placement, repository: repository}}
    else
      _invalid -> {:error, :placements}
    end
  end

  defp validate_placement(_entry, _repository_ids, _registry), do: {:error, :placements}

  defp persistence_error(code), do: {:error, %PersistenceError{code: code}}
end
