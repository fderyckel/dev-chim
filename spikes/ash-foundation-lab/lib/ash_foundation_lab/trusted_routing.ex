defmodule AshFoundationLab.TrustedRouting do
  @moduledoc """
  Disposable routing pressure-test for authenticated, versioned tenant placement.

  The registry is the trusted control-plane input. Request fields never select a
  repository or namespace, and process-local repository state is always restored.
  """

  alias AshFoundationLab.Repo

  @routing_context_key {__MODULE__, :resolved_placement}
  @missing_context :missing_routing_context

  defmodule AuthenticatedTenant do
    @moduledoc """
    Tenant and actor identity already established by a trusted authentication boundary.
    """

    @enforce_keys [:tenant_id, :actor_id, :routing_version, :correlation_id]
    defstruct [:tenant_id, :actor_id, :routing_version, :correlation_id]
  end

  defmodule Placement do
    @moduledoc """
    Trusted control-plane placement for one tenant.
    """

    @enforce_keys [
      :tenant_id,
      :routing_version,
      :profile,
      :repository,
      :database,
      :cell,
      :queue_namespace,
      :storage_namespace,
      :cache_namespace,
      :projection_namespace
    ]
    defstruct @enforce_keys
  end

  defmodule Registry do
    @moduledoc """
    Immutable stand-in for the platform-owned placement registry.
    """

    @enforce_keys [:placements]
    defstruct [:placements]
  end

  @doc """
  Builds a trusted registry and rejects duplicate or incomplete placement entries.
  """
  def new_registry!(placements) when is_list(placements) do
    placements_by_tenant =
      Enum.reduce(placements, %{}, fn placement, registry ->
        validate_placement!(placement)

        if Map.has_key?(registry, placement.tenant_id) do
          raise ArgumentError, "duplicate tenant placement"
        end

        Map.put(registry, placement.tenant_id, placement)
      end)

    %Registry{placements: placements_by_tenant}
  end

  @doc """
  Resolves a request from authenticated context only.

  The request map is deliberately not consulted for tenant, database, cell, or
  namespace selection.
  """
  def run_request(authenticated_tenant, _request, registry, operation) do
    with_route(authenticated_tenant, registry, operation)
  end

  @doc """
  Runs an operation with the trusted repository and route installed for this process.
  """
  def with_route(authenticated_tenant, registry, operation) when is_function(operation, 1) do
    with {:ok, placement} <- resolve(authenticated_tenant, registry) do
      run_with_placement(placement, operation)
    end
  end

  @doc """
  Starts a task that explicitly resolves and installs its own routing context.
  """
  def async(authenticated_tenant, registry, operation) when is_function(operation, 1) do
    Task.async(fn -> with_route(authenticated_tenant, registry, operation) end)
  end

  @doc """
  Produces the allowlisted, serializable routing context carried by a job.
  """
  def job_args(%AuthenticatedTenant{} = authenticated_tenant) do
    %{
      "tenant_id" => authenticated_tenant.tenant_id,
      "actor_id" => authenticated_tenant.actor_id,
      "routing_version" => authenticated_tenant.routing_version,
      "correlation_id" => authenticated_tenant.correlation_id
    }
  end

  @doc """
  Resolves a job against the current registry rather than trusting a repository in its arguments.
  """
  def perform_job(job_args, registry, operation) when is_function(operation, 1) do
    with {:ok, authenticated_tenant} <- authenticated_tenant_from_job(job_args) do
      with_route(authenticated_tenant, registry, operation)
    end
  end

  @doc """
  Returns the route installed in the current process, or a fail-closed error.
  """
  def current do
    case Process.get(@routing_context_key, @missing_context) do
      @missing_context -> {:error, :missing_routing_context}
      placement -> {:ok, placement}
    end
  end

  @doc """
  Resolves authenticated context through the trusted registry without changing process state.
  """
  def resolve(%AuthenticatedTenant{} = authenticated_tenant, %Registry{} = registry) do
    cond do
      missing_authenticated_context?(authenticated_tenant) ->
        {:error, :missing_authenticated_context}

      not Map.has_key?(registry.placements, authenticated_tenant.tenant_id) ->
        {:error, :placement_not_found}

      true ->
        validate_resolved_placement(
          Map.fetch!(registry.placements, authenticated_tenant.tenant_id),
          authenticated_tenant.routing_version
        )
    end
  end

  def resolve(_authenticated_tenant, _registry), do: {:error, :missing_authenticated_context}

  defp authenticated_tenant_from_job(%{
         "tenant_id" => tenant_id,
         "actor_id" => actor_id,
         "routing_version" => routing_version,
         "correlation_id" => correlation_id
       }) do
    {:ok,
     %AuthenticatedTenant{
       tenant_id: tenant_id,
       actor_id: actor_id,
       routing_version: routing_version,
       correlation_id: correlation_id
     }}
  end

  defp authenticated_tenant_from_job(_job_args), do: {:error, :missing_authenticated_context}

  defp missing_authenticated_context?(authenticated_tenant) do
    not valid_identifier?(authenticated_tenant.tenant_id) or
      not valid_identifier?(authenticated_tenant.actor_id) or
      not valid_identifier?(authenticated_tenant.correlation_id) or
      not (is_integer(authenticated_tenant.routing_version) and
             authenticated_tenant.routing_version > 0)
  end

  defp validate_resolved_placement(placement, routing_version) do
    cond do
      placement.routing_version != routing_version ->
        {:error, :stale_routing_version}

      not repository_available?(placement.repository) ->
        {:error, :placement_unavailable}

      true ->
        {:ok, placement}
    end
  end

  defp run_with_placement(placement, operation) do
    previous_repository = Repo.get_dynamic_repo()
    previous_context = Process.get(@routing_context_key, @missing_context)

    Repo.put_dynamic_repo(placement.repository)
    Process.put(@routing_context_key, placement)

    try do
      {:ok, operation.(placement)}
    after
      Repo.put_dynamic_repo(previous_repository)
      restore_context(previous_context)
    end
  end

  defp restore_context(@missing_context), do: Process.delete(@routing_context_key)
  defp restore_context(previous_context), do: Process.put(@routing_context_key, previous_context)

  defp validate_placement!(%Placement{} = placement) do
    valid =
      valid_identifier?(placement.tenant_id) and
        is_integer(placement.routing_version) and placement.routing_version > 0 and
        placement.profile in [:pooled, :dedicated] and
        (is_pid(placement.repository) or is_atom(placement.repository)) and
        Enum.all?(
          [
            placement.database,
            placement.cell,
            placement.queue_namespace,
            placement.storage_namespace,
            placement.cache_namespace,
            placement.projection_namespace
          ],
          &valid_identifier?/1
        )

    if not valid do
      raise ArgumentError, "invalid tenant placement"
    end
  end

  defp validate_placement!(_placement), do: raise(ArgumentError, "invalid tenant placement")

  defp valid_identifier?(value), do: is_binary(value) and byte_size(value) > 0

  defp repository_available?(repository) when is_pid(repository) or is_atom(repository) do
    match?(%{repo: Repo}, Ecto.Adapter.lookup_meta(repository))
  rescue
    _error -> false
  catch
    :exit, _reason -> false
  end
end
