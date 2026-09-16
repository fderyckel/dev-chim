defmodule AshFoundationLab.TrustedRouting do
  @moduledoc """
  Disposable routing pressure-test for authenticated, versioned tenant placement.

  The registry is the trusted control-plane input. Request fields never select a
  repository or namespace, and process-local repository state is always restored.
  """

  alias AshFoundationLab.Repo

  @routing_context_key {__MODULE__, :resolved_placement}
  @missing_context :missing_routing_context
  @movement_capability "tenant_placement.manage"
  @movement_reason_codes ~w(
    isolation_change
    capacity_change
    residency_change
    recovery_change
    contract_change
    rollback_rehearsal
    reconciliation_failed
  )
  @non_http_interface_targets %{
    event: :queue_namespace,
    file: :storage_namespace,
    cache: :cache_namespace,
    search: :projection_namespace,
    realtime: :projection_namespace,
    export: :storage_namespace,
    analytics: :projection_namespace,
    telemetry: :cell,
    ai_tool: :cell,
    integration: :queue_namespace
  }
  @movement_snapshot_tables [
    {"tenants", "id"},
    {"actors", "tenant_id"},
    {"roles", "tenant_id"},
    {"capabilities", "tenant_id"},
    {"actor_roles", "tenant_id"},
    {"role_capabilities", "tenant_id"},
    {"role_inclusions", "tenant_id"},
    {"foundation_records", "tenant_id"},
    {"outbox_events", "tenant_id"},
    {"synthetic_module_instances", "tenant_id"},
    {"synthetic_module_records", "tenant_id"},
    {"synthetic_module_work_items", "tenant_id"},
    {"synthetic_module_lifecycle_events", "tenant_id"},
    {"role_administration_events", "tenant_id"},
    {"action_idempotency_keys", "tenant_id"}
  ]

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
    defstruct placements: nil, movements: %{}, movement_events: []
  end

  defmodule InterfaceRoute do
    @moduledoc """
    Tenant-qualified target derived for one non-HTTP interface invocation.
    """

    @enforce_keys [
      :interface,
      :tenant_id,
      :actor_id,
      :routing_version,
      :correlation_id,
      :target
    ]
    defstruct @enforce_keys
  end

  defmodule Movement do
    @moduledoc """
    Versioned, in-memory tenant-movement state used only by the Phase 0 rehearsal.
    """

    @enforce_keys [
      :id,
      :tenant_id,
      :actor_id,
      :correlation_id,
      :reason,
      :source,
      :destination,
      :phase
    ]
    defstruct @enforce_keys ++ [reconciliation_digest: nil]
  end

  defmodule MovementEvent do
    @moduledoc """
    Minimal, non-secret evidence emitted by a named movement transition.
    """

    @enforce_keys [
      :id,
      :movement_id,
      :tenant_id,
      :actor_id,
      :correlation_id,
      :event_type,
      :source_routing_version,
      :destination_routing_version,
      :reason,
      :occurred_at
    ]
    defstruct @enforce_keys
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

  @doc "Returns the bounded non-HTTP interfaces exercised by this routing proof."
  def non_http_interfaces do
    @non_http_interface_targets
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Re-resolves a non-HTTP invocation and derives its target from trusted placement.

  The untrusted input is deliberately ignored for tenant, repository, cell, and
  namespace selection. The operation runs with the resolved repository installed.
  """
  def perform_interface(interface, interface_args, _untrusted_input, registry, operation)
      when is_function(operation, 1) do
    with {:ok, target_field} <- Map.fetch(@non_http_interface_targets, interface),
         {:ok, authenticated_tenant} <- authenticated_tenant_from_job(interface_args) do
      with_route(authenticated_tenant, registry, fn placement ->
        route = interface_route(interface, target_field, authenticated_tenant, placement)
        operation.(route)
      end)
    else
      :error -> {:error, :unsupported_interface}
      {:error, reason} -> {:error, reason}
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

      movement_blocks_route?(registry, authenticated_tenant.tenant_id) ->
        {:error, :tenant_moving}

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

  @doc """
  Prepares an authorized movement while the source route remains authoritative.
  """
  def prepare_movement(
        %AuthenticatedTenant{} = authenticated_tenant,
        %Registry{} = registry,
        %Placement{} = destination,
        reason
      ) do
    with {:ok, source} <- resolve(authenticated_tenant, registry),
         :ok <- ensure_no_active_movement(registry, authenticated_tenant.tenant_id),
         :ok <- validate_movement_destination(source, destination, registry),
         :ok <- validate_reason(reason),
         :ok <- authorize_movement(authenticated_tenant, source) do
      movement = %Movement{
        id: Ecto.UUID.generate(),
        tenant_id: authenticated_tenant.tenant_id,
        actor_id: authenticated_tenant.actor_id,
        correlation_id: authenticated_tenant.correlation_id,
        reason: reason,
        source: source,
        destination: destination,
        phase: :copying
      }

      registry =
        registry
        |> put_movement(movement)
        |> append_movement_event(movement, :movement_prepared, reason)

      {:ok, registry, movement}
    end
  end

  def prepare_movement(_authenticated_tenant, _registry, _destination, _reason),
    do: {:error, :missing_authenticated_context}

  @doc "Quiesces ordinary tenant traffic before final reconciliation."
  def quiesce_movement(authenticated_tenant, registry, movement_id) do
    with {:ok, movement} <- authorized_movement(authenticated_tenant, registry, movement_id),
         :ok <- require_movement_phase(movement, :copying) do
      updated = %{movement | phase: :quiesced}

      registry =
        registry
        |> put_movement(updated)
        |> append_movement_event(updated, :movement_quiesced, movement.reason)

      {:ok, registry}
    end
  end

  @doc """
  Compares source and destination snapshots while ordinary tenant work is quiesced.

  Only a digest is retained in movement state; snapshot contents are not logged.
  """
  def reconcile_movement(authenticated_tenant, registry, movement_id) do
    with {:ok, movement} <- authorized_movement(authenticated_tenant, registry, movement_id),
         :ok <- require_movement_phase(movement, :quiesced),
         {:ok, source_snapshot} <-
           movement_snapshot(movement.source, movement.tenant_id),
         {:ok, destination_snapshot} <-
           movement_snapshot(movement.destination, movement.tenant_id),
         :ok <- compare_snapshots(source_snapshot, destination_snapshot) do
      updated = %{
        movement
        | phase: :reconciled,
          reconciliation_digest: snapshot_digest(source_snapshot)
      }

      registry =
        registry
        |> put_movement(updated)
        |> append_movement_event(updated, :movement_reconciled, movement.reason)

      {:ok, registry}
    end
  end

  @doc "Cuts over to the reconciled destination and increments routing version."
  def cutover_movement(authenticated_tenant, registry, movement_id) do
    with {:ok, movement} <- authorized_movement(authenticated_tenant, registry, movement_id),
         :ok <- require_movement_phase(movement, :reconciled),
         {:ok, _destination} <-
           validate_resolved_placement(
             movement.destination,
             movement.destination.routing_version
           ) do
      registry =
        registry
        |> put_in_placement(movement.destination)
        |> remove_movement(movement)
        |> append_movement_event(movement, :movement_cut_over, movement.reason)

      {:ok, registry}
    end
  end

  @doc "Abandons a pre-cutover movement and restores ordinary source routing."
  def rollback_movement(authenticated_tenant, registry, movement_id, reason) do
    with :ok <- validate_reason(reason),
         {:ok, movement} <- authorized_movement(authenticated_tenant, registry, movement_id) do
      registry =
        registry
        |> remove_movement(movement)
        |> append_movement_event(movement, :movement_rolled_back, reason)

      {:ok, registry}
    end
  end

  @doc "Returns authorized, tenant-scoped movement events in transition order."
  def movement_events(%AuthenticatedTenant{} = authenticated_tenant, %Registry{} = registry) do
    with {:ok, placement} <- resolve(authenticated_tenant, registry),
         :ok <- authorize_movement(authenticated_tenant, placement) do
      {:ok,
       Enum.filter(
         registry.movement_events,
         &(&1.tenant_id == authenticated_tenant.tenant_id)
       )}
    end
  end

  def movement_events(_authenticated_tenant, _registry),
    do: {:error, :missing_authenticated_context}

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

  defp interface_route(interface, target_field, authenticated_tenant, placement) do
    target_root = Map.fetch!(placement, target_field)

    target =
      Enum.join(
        [
          target_root,
          Atom.to_string(interface),
          tenant_reference(placement.tenant_id),
          "v#{placement.routing_version}"
        ],
        ":"
      )

    %InterfaceRoute{
      interface: interface,
      tenant_id: placement.tenant_id,
      actor_id: authenticated_tenant.actor_id,
      routing_version: placement.routing_version,
      correlation_id: authenticated_tenant.correlation_id,
      target: target
    }
  end

  defp tenant_reference(tenant_id) do
    tenant_id
    |> then(&:crypto.hash(:sha256, &1))
    |> binary_part(0, 12)
    |> Base.encode16(case: :lower)
  end

  defp movement_blocks_route?(registry, tenant_id) do
    case Map.get(registry.movements, tenant_id) do
      %Movement{phase: phase} when phase in [:quiesced, :reconciled] -> true
      _movement_or_nil -> false
    end
  end

  defp ensure_no_active_movement(registry, tenant_id) do
    if Map.has_key?(registry.movements, tenant_id) do
      {:error, :movement_in_progress}
    else
      :ok
    end
  end

  defp validate_movement_destination(source, destination, registry) do
    valid =
      placement_valid?(destination) and
        destination.tenant_id == source.tenant_id and
        destination.routing_version == source.routing_version + 1 and
        destination.repository != source.repository and
        destination.database != source.database and
        destination.profile in [:pooled, :dedicated] and
        repository_available?(destination.repository) and
        destination_membership_valid?(destination, registry)

    if valid, do: :ok, else: {:error, :invalid_movement_destination}
  end

  defp destination_membership_valid?(destination, registry) do
    occupants =
      Enum.filter(registry.placements, fn {tenant_id, placement} ->
        tenant_id != destination.tenant_id and
          (placement.repository == destination.repository or
             placement.database == destination.database)
      end)

    case destination.profile do
      :pooled ->
        Enum.all?(occupants, fn {_tenant_id, placement} -> placement.profile == :pooled end)

      :dedicated ->
        occupants == []
    end
  end

  defp validate_reason(reason) when reason in @movement_reason_codes, do: :ok

  defp validate_reason(_reason), do: {:error, :invalid_movement_reason}

  defp authorized_movement(
         %AuthenticatedTenant{} = authenticated_tenant,
         %Registry{} = registry,
         movement_id
       ) do
    movement = Map.get(registry.movements, authenticated_tenant.tenant_id)

    valid_context =
      not missing_authenticated_context?(authenticated_tenant) and
        match?(%Movement{}, movement) and
        movement.id == movement_id and
        movement.actor_id == authenticated_tenant.actor_id and
        movement.correlation_id == authenticated_tenant.correlation_id and
        movement.source.routing_version == authenticated_tenant.routing_version

    if valid_context do
      case authorize_movement(authenticated_tenant, movement.source) do
        :ok -> {:ok, movement}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :movement_not_available}
    end
  end

  defp authorized_movement(_authenticated_tenant, _registry, _movement_id),
    do: {:error, :movement_not_available}

  defp authorize_movement(authenticated_tenant, source) do
    actor = %{id: authenticated_tenant.actor_id, tenant_id: authenticated_tenant.tenant_id}

    case run_with_placement(source, fn _placement ->
           AshFoundationLab.AccessControl.actor_has_capability?(actor, @movement_capability)
         end) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :forbidden}
    end
  end

  defp require_movement_phase(%Movement{phase: expected}, expected), do: :ok
  defp require_movement_phase(_movement, _expected), do: {:error, :movement_not_ready}

  defp compare_snapshots(snapshot, snapshot), do: :ok
  defp compare_snapshots(_source, _destination), do: {:error, :reconciliation_failed}

  defp movement_snapshot(placement, tenant_id) do
    tenant_id = Ecto.UUID.dump!(tenant_id)

    run_with_placement(placement, fn _placement ->
      Map.new(@movement_snapshot_tables, fn {table, tenant_column} ->
        rows =
          Repo.query!(
            """
            SELECT to_jsonb(scoped_row) - 'inserted_at' - 'updated_at'
            FROM (
              SELECT * FROM #{table}
              WHERE #{tenant_column} = $1
              ORDER BY id
            ) AS scoped_row
            """,
            [tenant_id]
          ).rows

        {table, rows}
      end)
    end)
  end

  defp snapshot_digest(snapshot) do
    snapshot
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp put_movement(registry, movement) do
    %{registry | movements: Map.put(registry.movements, movement.tenant_id, movement)}
  end

  defp remove_movement(registry, movement) do
    %{registry | movements: Map.delete(registry.movements, movement.tenant_id)}
  end

  defp put_in_placement(registry, placement) do
    %{registry | placements: Map.put(registry.placements, placement.tenant_id, placement)}
  end

  defp append_movement_event(registry, movement, event_type, reason) do
    event = %MovementEvent{
      id: Ecto.UUID.generate(),
      movement_id: movement.id,
      tenant_id: movement.tenant_id,
      actor_id: movement.actor_id,
      correlation_id: movement.correlation_id,
      event_type: event_type,
      source_routing_version: movement.source.routing_version,
      destination_routing_version: movement.destination.routing_version,
      reason: reason,
      occurred_at: DateTime.utc_now()
    }

    %{registry | movement_events: registry.movement_events ++ [event]}
  end

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
    if not placement_valid?(placement) do
      raise ArgumentError, "invalid tenant placement"
    end
  end

  defp validate_placement!(_placement), do: raise(ArgumentError, "invalid tenant placement")

  defp placement_valid?(%Placement{} = placement) do
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
  end

  defp valid_identifier?(value), do: is_binary(value) and byte_size(value) > 0

  defp repository_available?(repository) when is_pid(repository) or is_atom(repository) do
    match?(%{repo: Repo}, Ecto.Adapter.lookup_meta(repository))
  rescue
    _error -> false
  catch
    :exit, _reason -> false
  end
end
