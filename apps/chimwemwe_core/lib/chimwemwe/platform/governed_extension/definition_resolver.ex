defmodule Chimwemwe.Platform.GovernedExtension.DefinitionResolver do
  @moduledoc false

  alias Chimwemwe.Platform.{
    Authority,
    GovernedExtensionError,
    ModuleLifecycle,
    ModuleLifecycleError,
    Persistence,
    TrustedActor
  }

  alias Chimwemwe.Platform.GovernedExtension.{DefinitionView, Registry}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @read_capability "platform.extensions.definitions.read"

  @spec resolve(
          Supervisor.supervisor(),
          ReleaseManifest.t(),
          Registry.t(),
          term(),
          String.t()
        ) :: {:ok, DefinitionView.t()} | {:error, term()}
  def resolve(runtime, manifest, registry, context, definition_id) do
    case Persistence.with_writer(runtime, context, fn ->
           run_transaction(manifest, registry, context, definition_id)
         end) do
      {:ok, {:ok, %DefinitionView{} = view}} -> {:ok, view}
      {:ok, {:error, %GovernedExtensionError{} = error}} -> {:error, error}
      {:ok, _unexpected} -> extension_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> extension_error(:retryable_dependency)
  catch
    :exit, _reason -> extension_error(:retryable_dependency)
  end

  defp run_transaction(manifest, registry, context, definition_id) do
    Repo.transaction(fn ->
      resolve_or_rollback(manifest, registry, context, definition_id)
    end)
  end

  defp resolve_or_rollback(manifest, registry, context, definition_id) do
    case resolve_current_transaction(manifest, registry, context, definition_id) do
      {:ok, %DefinitionView{} = view} -> view
      {:error, %GovernedExtensionError{} = error} -> Repo.rollback(error)
    end
  end

  defp resolve_current_transaction(manifest, registry, context, definition_id) do
    with :ok <- authorize_before_load(context),
         {:ok, stored} <- load_definition(context, definition_id),
         {:ok, declaration} <- load_contract(manifest, registry, stored),
         :ok <- authorize_module(manifest, context, declaration),
         {:ok, release} <- fetch_release(manifest, declaration.module_key),
         {:ok, compatibility} <- compatibility(release, stored.module_version),
         {:ok, content, classification} <- validate_stored_definition(declaration, stored),
         true <- normalized_contract?(declaration, stored, content, classification) do
      {:ok, definition_view(stored, declaration, release, content, classification, compatibility)}
    else
      false -> extension_error(:incompatible_definition)
      {:error, %GovernedExtensionError{}} = error -> error
    end
  end

  defp authorize_before_load(context) do
    if Authority.actor_has_capability?(context.actor, @read_capability) do
      :ok
    else
      extension_error(:forbidden)
    end
  end

  defp load_definition(context, definition_id) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    case Repo.query(
           """
           SELECT
             definition.id::text,
             definition.definition_key,
             definition.schema_key,
             definition.schema_version,
             definition.module_version,
             definition.resource_ref,
             definition.descriptor_revision,
             definition.classification,
             definition.content,
             definition.lock_version,
             entitlement.module_key
           FROM platform_governed_extension_definitions AS definition
           JOIN platform_module_activations AS activation
             ON activation.tenant_id = definition.tenant_id
            AND activation.id = definition.module_activation_id
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE definition.tenant_id = $1 AND definition.id = $2
           """,
           [UUID.dump!(tenant_id), UUID.dump!(definition_id)]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             definition_key,
             schema_key,
             schema_version,
             module_version,
             resource_ref,
             descriptor_revision,
             classification,
             content,
             lock_version,
             module_key
           ]
         ]
       }} ->
        {:ok,
         %{
           id: id,
           definition_key: definition_key,
           schema_key: schema_key,
           schema_version: schema_version,
           module_version: module_version,
           resource_ref: resource_ref,
           descriptor_revision: descriptor_revision,
           classification: classification,
           content: content,
           lock_version: lock_version,
           module_key: module_key
         }}

      {:ok, %{rows: []}} ->
        extension_error(:not_found)

      {:error, _error} ->
        extension_error(:retryable_dependency)
    end
  end

  defp load_contract(manifest, registry, stored) do
    with {:ok, declaration} <- Registry.fetch(registry, stored.schema_key),
         true <- declaration.module_key == stored.module_key,
         {:ok, released} <-
           ReleaseManifest.fetch_extension(
             manifest,
             declaration.module_key,
             declaration.schema_key
           ),
         true <- released.schema_version == declaration.schema_version do
      {:ok, declaration}
    else
      _missing_or_incompatible -> extension_error(:incompatible_definition)
    end
  end

  defp authorize_module(manifest, context, declaration) do
    case ModuleLifecycle.authorize_current_transaction(
           manifest,
           context,
           declaration.module_key,
           @read_capability
         ) do
      :ok ->
        :ok

      {:error, %ModuleLifecycleError{code: :forbidden}} ->
        extension_error(:forbidden)

      {:error, %ModuleLifecycleError{code: :retryable_dependency}} ->
        extension_error(:retryable_dependency)

      {:error, %ModuleLifecycleError{}} ->
        extension_error(:module_gate_failed)
    end
  end

  defp fetch_release(manifest, module_key) do
    case ReleaseManifest.fetch(manifest, module_key) do
      {:ok, release} -> {:ok, release}
      {:error, :module_not_released} -> extension_error(:incompatible_definition)
    end
  end

  defp compatibility(release, published_version) do
    cond do
      published_version == release.version -> {:ok, :exact}
      published_version in release.compatible_from -> {:ok, :compatible}
      true -> extension_error(:incompatible_definition)
    end
  end

  defp validate_stored_definition(declaration, stored) do
    case Registry.validate_content(declaration, stored.content) do
      {:ok, content, classification} -> {:ok, content, classification}
      {:error, _reason} -> extension_error(:incompatible_definition)
    end
  end

  defp normalized_contract?(declaration, stored, content, classification) do
    stored.schema_version == declaration.schema_version and
      stored.resource_ref == declaration.descriptor["resource_ref"] and
      stored.descriptor_revision == declaration.descriptor["revision"] and
      stored.content == content and
      stored.classification == Atom.to_string(classification)
  end

  defp definition_view(stored, declaration, release, content, classification, compatibility) do
    %DefinitionView{
      id: stored.id,
      definition_key: stored.definition_key,
      schema_key: stored.schema_key,
      schema_version: stored.schema_version,
      module_key: declaration.module_key,
      published_module_version: stored.module_version,
      active_module_version: release.version,
      resource_ref: stored.resource_ref,
      descriptor_revision: stored.descriptor_revision,
      classification: classification,
      content: content,
      lock_version: stored.lock_version,
      compatibility: compatibility
    }
  end

  defp extension_error(code), do: {:error, %GovernedExtensionError{code: code}}
end
