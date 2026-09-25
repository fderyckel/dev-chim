defmodule Chimwemwe.Platform.ModuleLifecycle do
  @moduledoc """
  Trusted release, entitlement, activation, dependency, and actor gate.

  Slice 1H-A exposes one private initial-activation action and one ordinary
  authorization check. It owns no commercial entitlement workflow, deactivation,
  drain, reactivation, public interface, or business module.
  """

  alias Chimwemwe.Platform.{
    Authority,
    ExecutionContext,
    ModuleLifecycleError,
    Persistence,
    TrustedActor
  }

  alias Chimwemwe.Platform.ModuleLifecycle.{
    ActivateModuleResult,
    ModuleActivation,
    ReleaseManifest
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID

  @activate_input_keys [:causation_id, :expected_version, :idempotency_key, :module_key]
  @module_key_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @capability_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @maximum_key_length 120

  @doc "Activates one entitled released module through the private governed action."
  @spec activate(Supervisor.supervisor(), ReleaseManifest.t(), term(), map()) ::
          {:ok, ActivateModuleResult.t()} | {:error, term()}
  def activate(runtime, manifest, context, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, validated_manifest} <- validate_manifest(manifest),
           {:ok, normalized_input} <- normalize_activate_input(input),
           {:ok, _declaration} <- fetch_release(validated_manifest, normalized_input.module_key),
           {:ok, action_input} <-
             activation_input(
               validated_context,
               validated_manifest,
               normalized_input
             ) do
        run_activation(runtime, validated_context, action_input)
      end
    end)
  end

  @doc "Requires release, entitlement, activation, dependencies, and actor capability independently."
  @spec authorize(Supervisor.supervisor(), ReleaseManifest.t(), term(), term(), term()) ::
          :ok | {:error, term()}
  def authorize(runtime, manifest, context, module_key, capability) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, validated_manifest} <- validate_manifest(manifest),
           {:ok, module_key} <- normalize_module_key(module_key),
           {:ok, capability} <- normalize_capability(capability),
           {:ok, declaration} <- fetch_release(validated_manifest, module_key) do
        run_gates(
          runtime,
          validated_context,
          validated_manifest,
          declaration,
          capability
        )
      end
    end)
  end

  defp activation_input(context, manifest, input) do
    action_input =
      Ash.ActionInput.for_action(ModuleActivation, :activate_module, input,
        actor: context.actor,
        authorize?: true,
        context: action_context(context, manifest),
        domain: Chimwemwe.Platform,
        tenant: TrustedActor.tenant_id(context.actor)
      )

    if action_input.valid? do
      {:ok, action_input}
    else
      lifecycle_error(:invalid_input)
    end
  rescue
    _error -> lifecycle_error(:internal)
  end

  defp run_activation(runtime, context, action_input) do
    case Persistence.with_writer(runtime, context, fn ->
           Ash.run_action(action_input,
             actor: context.actor,
             authorize?: true,
             domain: Chimwemwe.Platform,
             tenant: TrustedActor.tenant_id(context.actor)
           )
         end) do
      {:ok, {:ok, %ActivateModuleResult{} = result}} -> {:ok, result}
      {:ok, {:error, error}} -> map_action_error(error)
      {:ok, _unexpected} -> lifecycle_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> lifecycle_error(:retryable_dependency)
  catch
    :exit, _reason -> lifecycle_error(:retryable_dependency)
  end

  defp run_gates(runtime, context, manifest, declaration, capability) do
    case Persistence.with_writer(runtime, context, fn ->
           evaluate_gates(context, manifest, declaration, capability)
         end) do
      {:ok, :ok} -> :ok
      {:ok, {:error, %ModuleLifecycleError{}} = error} -> error
      {:ok, _unexpected} -> lifecycle_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> lifecycle_error(:retryable_dependency)
  catch
    :exit, _reason -> lifecycle_error(:retryable_dependency)
  end

  defp evaluate_gates(context, manifest, declaration, capability) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    with :ok <- require_entitlement(tenant_id, declaration.key),
         :ok <- require_active_version(tenant_id, declaration),
         :ok <- require_active_dependencies(tenant_id, manifest, declaration),
         true <- Authority.actor_has_capability?(context.actor, capability) do
      :ok
    else
      false -> lifecycle_error(:forbidden)
      {:error, %ModuleLifecycleError{}} = error -> error
    end
  end

  defp require_entitlement(tenant_id, module_key) do
    case Repo.query(
           """
           SELECT id::text
           FROM platform_module_entitlements
           WHERE tenant_id = $1 AND module_key = $2
           """,
           [UUID.dump!(tenant_id), module_key]
         ) do
      {:ok, %{rows: [[_entitlement_id]]}} -> :ok
      {:ok, %{rows: []}} -> lifecycle_error(:module_not_entitled)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp require_active_version(tenant_id, declaration) do
    case Repo.query(
           """
           SELECT activation.state, activation.module_version
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1
             AND entitlement.module_key = $2
           """,
           [UUID.dump!(tenant_id), declaration.key]
         ) do
      {:ok, %{rows: [["active", version]]}} when version == declaration.version -> :ok
      {:ok, %{rows: _missing_or_incompatible}} -> lifecycle_error(:module_inactive)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp require_active_dependencies(tenant_id, manifest, declaration) do
    Enum.reduce_while(declaration.dependencies, :ok, fn dependency_key, :ok ->
      with {:ok, dependency} <- fetch_release(manifest, dependency_key),
           :ok <- require_active_version(tenant_id, dependency) do
        {:cont, :ok}
      else
        {:error, %ModuleLifecycleError{code: :retryable_dependency}} = error ->
          {:halt, error}

        _missing_or_inactive ->
          {:halt, lifecycle_error(:required_dependency_inactive)}
      end
    end)
  end

  defp normalize_activate_input(input) when is_map(input) and not is_struct(input) do
    with {:ok, normalized} <- normalize_input_keys(input),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(@activate_input_keys),
         {:ok, module_key} <- normalize_module_key(normalized.module_key),
         true <- normalized.expected_version == 0,
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         module_key: module_key,
         expected_version: 0,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      {:error, %ModuleLifecycleError{}} = error -> error
      _invalid -> lifecycle_error(:invalid_input)
    end
  end

  defp normalize_activate_input(_input), do: lifecycle_error(:invalid_input)

  defp normalize_input_keys(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      with {:ok, normalized_key} <- activate_input_key(key),
           false <- Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        _invalid_or_duplicate -> {:halt, lifecycle_error(:invalid_input)}
      end
    end)
  end

  defp activate_input_key(key) when key in @activate_input_keys, do: {:ok, key}
  defp activate_input_key("causation_id"), do: {:ok, :causation_id}
  defp activate_input_key("expected_version"), do: {:ok, :expected_version}
  defp activate_input_key("idempotency_key"), do: {:ok, :idempotency_key}
  defp activate_input_key("module_key"), do: {:ok, :module_key}
  defp activate_input_key(_key), do: lifecycle_error(:invalid_input)

  defp normalize_module_key(module_key) when is_binary(module_key) do
    normalized = String.trim(module_key)

    if byte_size(normalized) <= @maximum_key_length and
         Regex.match?(@module_key_pattern, normalized) do
      {:ok, normalized}
    else
      lifecycle_error(:invalid_input)
    end
  end

  defp normalize_module_key(_module_key), do: lifecycle_error(:invalid_input)

  defp normalize_capability(capability) when is_binary(capability) do
    normalized = String.trim(capability)

    if byte_size(normalized) <= @maximum_key_length and
         Regex.match?(@capability_pattern, normalized) do
      {:ok, normalized}
    else
      lifecycle_error(:invalid_input)
    end
  end

  defp normalize_capability(_capability), do: lifecycle_error(:invalid_input)

  defp validate_manifest(manifest) do
    case ReleaseManifest.revalidate(manifest) do
      {:ok, validated} -> {:ok, validated}
      {:error, :invalid_manifest} -> lifecycle_error(:invalid_manifest)
    end
  end

  defp fetch_release(manifest, module_key) do
    case ReleaseManifest.fetch(manifest, module_key) do
      {:ok, declaration} -> {:ok, declaration}
      {:error, :module_not_released} -> lifecycle_error(:module_not_released)
    end
  end

  defp action_context(context, manifest) do
    %{
      chimwemwe: %{
        correlation_id: context.correlation_id,
        locale: context.locale,
        module_release_manifest: manifest,
        purpose: context.purpose,
        routing_version: context.placement.routing_version
      }
    }
  end

  defp map_action_error(error) do
    case find_lifecycle_error(error) do
      %ModuleLifecycleError{} = lifecycle_error -> {:error, lifecycle_error}
      nil when is_struct(error, Ash.Error.Forbidden) -> lifecycle_error(:forbidden)
      nil when is_struct(error, Ash.Error.Invalid) -> lifecycle_error(:invalid_input)
      nil -> lifecycle_error(:internal)
    end
  end

  defp find_lifecycle_error(%ModuleLifecycleError{} = error), do: error

  defp find_lifecycle_error(%{errors: errors}) when is_list(errors) do
    Enum.find_value(errors, &find_lifecycle_error/1)
  end

  defp find_lifecycle_error(%{error: error}), do: find_lifecycle_error(error)
  defp find_lifecycle_error(_error), do: nil

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> lifecycle_error(:invalid_input)
    end
  end

  defp lifecycle_error(code), do: {:error, %ModuleLifecycleError{code: code}}
end
