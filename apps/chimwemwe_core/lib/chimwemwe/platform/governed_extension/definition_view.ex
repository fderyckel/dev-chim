defmodule Chimwemwe.Platform.GovernedExtension.DefinitionView do
  @moduledoc """
  Compatible internal view of one tenant-owned governed presentation definition.

  The view contains no tenant, actor, activation, entitlement, placement,
  repository, authority-graph, or publication-evidence identifiers. It is not a
  rendered view and does not execute the referenced action.
  """

  @enforce_keys [
    :id,
    :definition_key,
    :schema_key,
    :schema_version,
    :module_key,
    :published_module_version,
    :active_module_version,
    :resource_ref,
    :descriptor_revision,
    :classification,
    :content,
    :lock_version,
    :compatibility
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          definition_key: String.t(),
          schema_key: String.t(),
          schema_version: pos_integer(),
          module_key: String.t(),
          published_module_version: String.t(),
          active_module_version: String.t(),
          resource_ref: String.t(),
          descriptor_revision: String.t(),
          classification: :public | :internal | :confidential | :restricted,
          content: map(),
          lock_version: pos_integer(),
          compatibility: :exact | :compatible
        }
end
