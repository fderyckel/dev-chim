defmodule Chimwemwe.Platform.GovernedExtension do
  @moduledoc """
  Trusted publication and exact resolution boundary for tenant-owned governed
  presentation definitions.

  Slice 1I-A validates an immutable code-owned registry and module release,
  then invokes one private named action. Slice 1I-B resolves one exact compatible
  definition for an internal consumer. Neither slice renders metadata or executes
  its referenced action.
  """

  alias Chimwemwe.Platform.{ExecutionContext, GovernedExtensionError, Persistence, TrustedActor}

  alias Chimwemwe.Platform.GovernedExtension.{
    DefinitionResolver,
    DefinitionView,
    ExtensionDefinition,
    PublishResult,
    Registry
  }

  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Ecto.UUID

  @input_keys [
    :causation_id,
    :content,
    :definition_id,
    :definition_key,
    :descriptor_revision,
    :expected_version,
    :idempotency_key,
    :schema_key
  ]
  @string_input_keys Map.new(@input_keys, &{Atom.to_string(&1), &1})
  @key_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @maximum_key_length 120

  @doc "Publishes or revises one compatible tenant-owned presentation definition."
  @spec publish_definition(
          Supervisor.supervisor(),
          ReleaseManifest.t(),
          Registry.t(),
          term(),
          map()
        ) :: {:ok, PublishResult.t()} | {:error, term()}
  def publish_definition(runtime, manifest, registry, context, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, validated_manifest} <- validate_manifest(manifest),
           {:ok, validated_registry} <- validate_registry(registry),
           {:ok, normalized_input} <- normalize_input(input),
           {:ok, declaration} <-
             fetch_declaration(validated_registry, normalized_input.schema_key),
           :ok <- require_released_contract(validated_manifest, declaration),
           :ok <- require_descriptor_revision(declaration, normalized_input.descriptor_revision),
           {:ok, action_input} <-
             action_input(
               validated_context,
               validated_manifest,
               validated_registry,
               normalized_input
             ) do
        run_action(runtime, validated_context, action_input)
      end
    end)
  end

  @doc "Resolves one exact compatible definition without executing its action reference."
  @spec resolve_definition(
          Supervisor.supervisor(),
          ReleaseManifest.t(),
          Registry.t(),
          term(),
          term()
        ) :: {:ok, DefinitionView.t()} | {:error, term()}
  def resolve_definition(runtime, manifest, registry, context, definition_id) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, validated_manifest} <- validate_manifest(manifest),
           {:ok, validated_registry} <- validate_registry(registry),
           {:ok, definition_id} <- cast_uuid(definition_id) do
        DefinitionResolver.resolve(
          runtime,
          validated_manifest,
          validated_registry,
          validated_context,
          definition_id
        )
      end
    end)
  end

  defp action_input(context, manifest, registry, input) do
    ash_input =
      Ash.ActionInput.for_action(ExtensionDefinition, :publish_definition, input,
        actor: context.actor,
        authorize?: true,
        context: action_context(context, manifest, registry),
        domain: Chimwemwe.Platform,
        tenant: TrustedActor.tenant_id(context.actor)
      )

    if ash_input.valid? do
      {:ok, ash_input}
    else
      extension_error(:invalid_input)
    end
  rescue
    _error -> extension_error(:internal)
  end

  defp run_action(runtime, context, action_input) do
    case Persistence.with_writer(runtime, context, fn ->
           Ash.run_action(action_input,
             actor: context.actor,
             authorize?: true,
             domain: Chimwemwe.Platform,
             tenant: TrustedActor.tenant_id(context.actor)
           )
         end) do
      {:ok, {:ok, %PublishResult{} = result}} -> {:ok, result}
      {:ok, {:error, error}} -> map_action_error(error)
      {:ok, _unexpected} -> extension_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> extension_error(:retryable_dependency)
  catch
    :exit, _reason -> extension_error(:retryable_dependency)
  end

  defp validate_manifest(manifest) do
    case ReleaseManifest.revalidate(manifest) do
      {:ok, validated} -> {:ok, validated}
      {:error, :invalid_manifest} -> extension_error(:invalid_manifest)
    end
  end

  defp validate_registry(registry) do
    case Registry.revalidate(registry) do
      {:ok, validated} -> {:ok, validated}
      {:error, :invalid_registry} -> extension_error(:invalid_registry)
    end
  end

  defp fetch_declaration(registry, schema_key) do
    case Registry.fetch(registry, schema_key) do
      {:ok, declaration} -> {:ok, declaration}
      {:error, :schema_not_available} -> extension_error(:schema_not_available)
    end
  end

  defp require_released_contract(manifest, declaration) do
    case ReleaseManifest.fetch_extension(manifest, declaration.module_key, declaration.schema_key) do
      {:ok, %{schema_version: version}} when version == declaration.schema_version -> :ok
      _missing_or_incompatible -> extension_error(:schema_not_available)
    end
  end

  defp require_descriptor_revision(declaration, revision) do
    if declaration.descriptor["revision"] == revision do
      :ok
    else
      extension_error(:stale_descriptor)
    end
  end

  defp normalize_input(input) when is_map(input) and not is_struct(input) do
    with {:ok, normalized} <- normalize_input_keys(input),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(@input_keys),
         {:ok, definition_id} <- cast_uuid(normalized.definition_id),
         {:ok, definition_key} <- normalize_key(normalized.definition_key),
         {:ok, schema_key} <- normalize_key(normalized.schema_key),
         true <- Registry.valid_revision?(normalized.descriptor_revision),
         true <- is_map(normalized.content) and not is_struct(normalized.content),
         true <- is_integer(normalized.expected_version) and normalized.expected_version >= 0,
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         causation_id: causation_id,
         content: normalized.content,
         definition_id: definition_id,
         definition_key: definition_key,
         descriptor_revision: normalized.descriptor_revision,
         expected_version: normalized.expected_version,
         idempotency_key: idempotency_key,
         schema_key: schema_key
       }}
    else
      {:error, %GovernedExtensionError{}} = error -> error
      _invalid -> extension_error(:invalid_input)
    end
  end

  defp normalize_input(_input), do: extension_error(:invalid_input)

  defp normalize_input_keys(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      with {:ok, normalized_key} <- input_key(key),
           false <- Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        _invalid_or_duplicate -> {:halt, extension_error(:invalid_input)}
      end
    end)
  end

  defp input_key(key) when is_atom(key) do
    if key in @input_keys, do: {:ok, key}, else: extension_error(:invalid_input)
  end

  defp input_key(key) when is_binary(key) do
    case Map.fetch(@string_input_keys, key) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> extension_error(:invalid_input)
    end
  end

  defp input_key(_key), do: extension_error(:invalid_input)

  defp normalize_key(key) when is_binary(key) do
    normalized = String.trim(key)

    if byte_size(normalized) <= @maximum_key_length and Regex.match?(@key_pattern, normalized) do
      {:ok, normalized}
    else
      extension_error(:invalid_input)
    end
  end

  defp normalize_key(_key), do: extension_error(:invalid_input)

  defp action_context(context, manifest, registry) do
    %{
      chimwemwe: %{
        correlation_id: context.correlation_id,
        governed_extension: %{
          execution_context: context,
          manifest: manifest,
          registry: registry
        },
        locale: context.locale,
        purpose: context.purpose,
        routing_version: context.placement.routing_version
      }
    }
  end

  defp map_action_error(error) do
    case find_extension_error(error) do
      %GovernedExtensionError{} = extension_error -> {:error, extension_error}
      nil when is_struct(error, Ash.Error.Forbidden) -> extension_error(:forbidden)
      nil when is_struct(error, Ash.Error.Invalid) -> extension_error(:invalid_input)
      nil -> extension_error(:internal)
    end
  end

  defp find_extension_error(%GovernedExtensionError{} = error), do: error

  defp find_extension_error(%{errors: errors}) when is_list(errors) do
    Enum.find_value(errors, &find_extension_error/1)
  end

  defp find_extension_error(%{error: error}), do: find_extension_error(error)
  defp find_extension_error(_error), do: nil

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> extension_error(:invalid_input)
    end
  end

  defp extension_error(code), do: {:error, %GovernedExtensionError{code: code}}
end
