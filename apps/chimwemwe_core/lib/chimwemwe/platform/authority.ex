defmodule Chimwemwe.Platform.Authority do
  @moduledoc """
  Resolves tenant-defined capability grants and owns governed authority writes.

  Callers provide a persistence runtime, validated execution context, and one
  code-known capability key. Role identifiers, assignments, repository selection,
  and graph traversal remain internal. `rename_role/3` and `assign_role/3` are
  resource-specific and expose no generic write or caller-controlled Ash options.
  """

  alias Chimwemwe.Platform.{
    AuthorityError,
    ExecutionContext,
    Persistence,
    TrustedActor
  }

  alias Chimwemwe.Platform.Authority.{
    ActorRoleAssignment,
    AssignRoleResult,
    RenameRoleResult,
    Role
  }

  alias Chimwemwe.Repo

  @capability_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @maximum_capability_length 120
  @assign_input_keys [:causation_id, :idempotency_key, :membership_id, :role_id]
  @rename_input_keys [:causation_id, :expected_version, :idempotency_key, :name, :role_id]

  @doc "Authorizes one code-known capability against current tenant-owned authority data."
  @spec authorize(Supervisor.supervisor(), term(), term()) :: :ok | {:error, term()}
  def authorize(runtime, context, capability) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, capability} <- validate_capability(capability) do
        resolve(runtime, validated_context, capability)
      end
    end)
  end

  @doc "Renames one tenant-defined role through the private governed Ash action."
  @spec rename_role(Supervisor.supervisor(), term(), map()) ::
          {:ok, RenameRoleResult.t()} | {:error, term()}
  def rename_role(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, normalized_input} <- normalize_rename_input(input),
           {:ok, action_input} <- rename_action_input(validated_context, normalized_input) do
        run_rename(runtime, validated_context, action_input)
      end
    end)
  end

  @doc "Assigns one tenant membership to one tenant-defined role through a private action."
  @spec assign_role(Supervisor.supervisor(), term(), map()) ::
          {:ok, AssignRoleResult.t()} | {:error, term()}
  def assign_role(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, normalized_input} <- normalize_assign_input(input),
           {:ok, action_input} <- assign_action_input(validated_context, normalized_input) do
        run_assign(runtime, validated_context, action_input)
      end
    end)
  end

  @doc false
  @spec actor_has_capability?(TrustedActor.t(), String.t()) :: boolean()
  def actor_has_capability?(%TrustedActor{} = actor, capability) do
    with :ok <- TrustedActor.validate(actor),
         {:ok, capability} <- validate_capability(capability),
         {:ok, granted?} <- query_grant(actor, capability) do
      granted?
    else
      _invalid_or_unavailable -> false
    end
  end

  def actor_has_capability?(_actor, _capability), do: false

  defp assign_action_input(context, input) do
    action_input =
      Ash.ActionInput.for_action(ActorRoleAssignment, :assign_role, input,
        actor: context.actor,
        authorize?: true,
        context: action_context(context),
        domain: Chimwemwe.Platform,
        tenant: TrustedActor.tenant_id(context.actor)
      )

    if action_input.valid? do
      {:ok, action_input}
    else
      authority_error(:invalid_input)
    end
  rescue
    _error -> authority_error(:internal)
  end

  defp rename_action_input(context, input) do
    action_input =
      Ash.ActionInput.for_action(Role, :rename_role, input,
        actor: context.actor,
        authorize?: true,
        context: action_context(context),
        domain: Chimwemwe.Platform,
        tenant: TrustedActor.tenant_id(context.actor)
      )

    if action_input.valid? do
      {:ok, action_input}
    else
      authority_error(:invalid_input)
    end
  rescue
    _error -> authority_error(:internal)
  end

  defp run_rename(runtime, context, action_input) do
    case Persistence.with_writer(runtime, context, fn ->
           Ash.run_action(action_input,
             actor: context.actor,
             authorize?: true,
             domain: Chimwemwe.Platform,
             tenant: TrustedActor.tenant_id(context.actor)
           )
         end) do
      {:ok, {:ok, %RenameRoleResult{} = result}} -> {:ok, result}
      {:ok, {:error, error}} -> map_action_error(error)
      {:ok, _unexpected} -> authority_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> authority_error(:retryable_dependency)
  catch
    :exit, _reason -> authority_error(:retryable_dependency)
  end

  defp run_assign(runtime, context, action_input) do
    case Persistence.with_writer(runtime, context, fn ->
           Ash.run_action(action_input,
             actor: context.actor,
             authorize?: true,
             domain: Chimwemwe.Platform,
             tenant: TrustedActor.tenant_id(context.actor)
           )
         end) do
      {:ok, {:ok, %AssignRoleResult{} = result}} -> {:ok, result}
      {:ok, {:error, error}} -> map_action_error(error)
      {:ok, _unexpected} -> authority_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> authority_error(:retryable_dependency)
  catch
    :exit, _reason -> authority_error(:retryable_dependency)
  end

  defp normalize_assign_input(input) when is_map(input) and not is_struct(input) do
    with {:ok, normalized} <- normalize_input_keys(input, &assign_input_key/1),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(@assign_input_keys) do
      {:ok, normalized}
    else
      _invalid -> authority_error(:invalid_input)
    end
  end

  defp normalize_assign_input(_input), do: authority_error(:invalid_input)

  defp normalize_rename_input(input) when is_map(input) and not is_struct(input) do
    with {:ok, normalized} <- normalize_input_keys(input, &rename_input_key/1),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(@rename_input_keys) do
      {:ok, normalized}
    else
      _invalid -> authority_error(:invalid_input)
    end
  end

  defp normalize_rename_input(_input), do: authority_error(:invalid_input)

  defp normalize_input_keys(input, key_normalizer) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      with {:ok, normalized_key} <- key_normalizer.(key),
           false <- Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        _invalid_or_duplicate -> {:halt, authority_error(:invalid_input)}
      end
    end)
  end

  defp assign_input_key(key) when key in @assign_input_keys, do: {:ok, key}
  defp assign_input_key("causation_id"), do: {:ok, :causation_id}
  defp assign_input_key("idempotency_key"), do: {:ok, :idempotency_key}
  defp assign_input_key("membership_id"), do: {:ok, :membership_id}
  defp assign_input_key("role_id"), do: {:ok, :role_id}
  defp assign_input_key(_key), do: authority_error(:invalid_input)

  defp rename_input_key(key) when key in @rename_input_keys, do: {:ok, key}
  defp rename_input_key("causation_id"), do: {:ok, :causation_id}
  defp rename_input_key("expected_version"), do: {:ok, :expected_version}
  defp rename_input_key("idempotency_key"), do: {:ok, :idempotency_key}
  defp rename_input_key("name"), do: {:ok, :name}
  defp rename_input_key("role_id"), do: {:ok, :role_id}
  defp rename_input_key(_key), do: authority_error(:invalid_input)

  defp action_context(context) do
    %{
      chimwemwe: %{
        correlation_id: context.correlation_id,
        locale: context.locale,
        purpose: context.purpose,
        routing_version: context.placement.routing_version
      }
    }
  end

  defp map_action_error(error) do
    case find_authority_error(error) do
      %AuthorityError{} = authority_error -> {:error, authority_error}
      nil when is_struct(error, Ash.Error.Forbidden) -> authority_error(:forbidden)
      nil when is_struct(error, Ash.Error.Invalid) -> authority_error(:invalid_input)
      nil -> authority_error(:internal)
    end
  end

  defp find_authority_error(%AuthorityError{} = error), do: error

  defp find_authority_error(%{errors: errors}) when is_list(errors) do
    Enum.find_value(errors, &find_authority_error/1)
  end

  defp find_authority_error(%{error: error}), do: find_authority_error(error)
  defp find_authority_error(_error), do: nil

  defp resolve(runtime, context, capability) do
    case Persistence.with_writer(runtime, context, fn ->
           query_grant(context.actor, capability)
         end) do
      {:ok, {:ok, true}} -> :ok
      {:ok, {:ok, false}} -> authority_error(:forbidden)
      {:ok, {:error, _reason}} -> authority_error(:retryable_dependency)
      {:error, _reason} = error -> error
    end
  end

  defp query_grant(actor, capability) do
    Repo.query(
      """
      WITH RECURSIVE granted_roles(role_id) AS (
        SELECT assignment.role_id
        FROM platform_tenant_memberships AS membership
        JOIN platform_actor_role_assignments AS assignment
          ON assignment.tenant_id = membership.tenant_id
         AND assignment.membership_id = membership.id
        WHERE membership.tenant_id = $1
          AND membership.actor_id = $2

        UNION

        SELECT inclusion.included_role_id
        FROM platform_role_inclusions AS inclusion
        JOIN granted_roles
          ON granted_roles.role_id = inclusion.role_id
        WHERE inclusion.tenant_id = $1
      )
      SELECT EXISTS (
        SELECT 1
        FROM granted_roles
        JOIN platform_role_capability_grants AS role_grant
          ON role_grant.tenant_id = $1
         AND role_grant.role_id = granted_roles.role_id
        JOIN platform_capabilities AS capability
          ON capability.tenant_id = role_grant.tenant_id
         AND capability.id = role_grant.capability_id
        WHERE capability.key = $3
      )
      """,
      [
        Ecto.UUID.dump!(TrustedActor.tenant_id(actor)),
        Ecto.UUID.dump!(TrustedActor.actor_id(actor)),
        capability
      ]
    )
    |> case do
      {:ok, %{rows: [[granted?]]}} when is_boolean(granted?) -> {:ok, granted?}
      _unexpected -> authority_error(:retryable_dependency)
    end
  rescue
    _error -> authority_error(:retryable_dependency)
  catch
    :exit, _reason -> authority_error(:retryable_dependency)
  end

  defp validate_capability(capability) when is_binary(capability) do
    if byte_size(capability) <= @maximum_capability_length and
         Regex.match?(@capability_pattern, capability) do
      {:ok, capability}
    else
      authority_error(:invalid_capability)
    end
  end

  defp validate_capability(_capability), do: authority_error(:invalid_capability)

  defp authority_error(code), do: {:error, %AuthorityError{code: code}}
end
