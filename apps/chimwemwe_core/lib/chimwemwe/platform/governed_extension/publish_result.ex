defmodule Chimwemwe.Platform.GovernedExtension.PublishResult do
  @moduledoc "Stable result for one committed governed presentation definition."

  @enforce_keys [
    :id,
    :definition_key,
    :schema_key,
    :descriptor_revision,
    :classification,
    :lock_version,
    :audit_reference,
    :event_id
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          definition_key: String.t(),
          schema_key: String.t(),
          descriptor_revision: String.t(),
          classification: :public | :internal | :confidential | :restricted,
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
