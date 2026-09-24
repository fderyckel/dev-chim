defmodule Chimwemwe.Platform.TrustedActor do
  @moduledoc """
  Actor and tenant identity established by a trusted authentication adapter.

  This type contains no school role constants. Later authorization resolves tenant-defined
  capabilities from authoritative data.
  """

  alias Ash.Type.UUID
  alias Chimwemwe.Platform.ContextError

  @enforce_keys [:actor_id, :tenant_id, :assurance]
  defstruct [:actor_id, :tenant_id, :assurance]

  @opaque t :: %__MODULE__{
            actor_id: String.t(),
            tenant_id: String.t(),
            assurance: String.t()
          }

  @spec establish(keyword()) :: {:ok, t()} | {:error, ContextError.t()}
  def establish(attributes) when is_list(attributes) do
    with {:ok, actor_id} <- cast_uuid(:actor_id, Keyword.get(attributes, :actor_id)),
         {:ok, tenant_id} <- cast_uuid(:tenant_id, Keyword.get(attributes, :tenant_id)),
         {:ok, assurance} <- non_empty(:assurance, Keyword.get(attributes, :assurance)) do
      {:ok,
       %__MODULE__{
         actor_id: actor_id,
         tenant_id: tenant_id,
         assurance: assurance
       }}
    end
  end

  def establish(_attributes), do: error(:invalid_actor_context, nil)

  @spec validate(term()) :: :ok | {:error, ContextError.t()}
  def validate(%__MODULE__{} = actor) do
    with {:ok, _actor_id} <- cast_uuid(:actor_id, actor.actor_id),
         {:ok, _tenant_id} <- cast_uuid(:tenant_id, actor.tenant_id),
         {:ok, _assurance} <- non_empty(:assurance, actor.assurance) do
      :ok
    end
  end

  def validate(_actor), do: error(:invalid_actor_context, nil)

  @doc false
  @spec revalidate(term()) :: {:ok, t()} | {:error, ContextError.t()}
  def revalidate(%__MODULE__{} = actor) do
    with :ok <- validate(actor), do: {:ok, actor}
  end

  def revalidate(_actor), do: error(:invalid_actor_context, nil)

  @doc false
  @spec actor_id(t()) :: String.t()
  def actor_id(%__MODULE__{actor_id: actor_id}), do: actor_id

  @doc false
  @spec tenant_id(t()) :: String.t()
  def tenant_id(%__MODULE__{tenant_id: tenant_id}), do: tenant_id

  defp cast_uuid(field, value) do
    case UUID.cast_input(value, []) do
      {:ok, uuid} -> {:ok, uuid}
      _error -> error(:invalid_actor_context, field)
    end
  end

  defp non_empty(field, value) when is_binary(value) do
    case String.trim(value) do
      "" -> error(:invalid_actor_context, field)
      trimmed -> {:ok, trimmed}
    end
  end

  defp non_empty(field, _value), do: error(:invalid_actor_context, field)

  defp error(code, field), do: {:error, %ContextError{code: code, field: field}}
end
