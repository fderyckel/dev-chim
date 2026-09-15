defmodule Chimwemwe.Platform.TrustedPlacement do
  @moduledoc """
  A tenant placement selected by the platform-owned routing boundary.

  The reference is intentionally opaque. Request-controlled database, repository, cell,
  queue, or storage coordinates are not part of this public constructor.
  """

  alias Ash.Type.UUID
  alias Chimwemwe.Platform.ContextError

  @profiles [:pooled, :dedicated_database, :dedicated_cell]

  @enforce_keys [:tenant_id, :routing_version, :profile, :placement_ref]
  defstruct [:tenant_id, :routing_version, :profile, :placement_ref]

  @opaque t :: %__MODULE__{
            tenant_id: String.t(),
            routing_version: pos_integer(),
            profile: :pooled | :dedicated_database | :dedicated_cell,
            placement_ref: String.t()
          }

  @spec establish(keyword()) :: {:ok, t()} | {:error, ContextError.t()}
  def establish(attributes) when is_list(attributes) do
    with {:ok, tenant_id} <- cast_uuid(:tenant_id, Keyword.get(attributes, :tenant_id)),
         {:ok, routing_version} <-
           positive_integer(:routing_version, Keyword.get(attributes, :routing_version)),
         {:ok, profile} <- profile(Keyword.get(attributes, :profile)),
         {:ok, placement_ref} <-
           non_empty(:placement_ref, Keyword.get(attributes, :placement_ref)) do
      {:ok,
       %__MODULE__{
         tenant_id: tenant_id,
         routing_version: routing_version,
         profile: profile,
         placement_ref: placement_ref
       }}
    end
  end

  def establish(_attributes), do: error(:invalid_placement_context, nil)

  @spec validate(term()) :: :ok | {:error, ContextError.t()}
  def validate(%__MODULE__{} = placement) do
    with {:ok, _tenant_id} <- cast_uuid(:tenant_id, placement.tenant_id),
         {:ok, _routing_version} <-
           positive_integer(:routing_version, placement.routing_version),
         {:ok, _profile} <- profile(placement.profile),
         {:ok, _placement_ref} <- non_empty(:placement_ref, placement.placement_ref) do
      :ok
    end
  end

  def validate(_placement), do: error(:invalid_placement_context, nil)

  @doc false
  @spec tenant_id(t()) :: String.t()
  def tenant_id(%__MODULE__{tenant_id: tenant_id}), do: tenant_id

  defp cast_uuid(field, value) do
    case UUID.cast_input(value, []) do
      {:ok, uuid} -> {:ok, uuid}
      _error -> error(:invalid_placement_context, field)
    end
  end

  defp positive_integer(_field, value) when is_integer(value) and value > 0, do: {:ok, value}
  defp positive_integer(field, _value), do: error(:invalid_placement_context, field)

  defp profile(value) when value in @profiles, do: {:ok, value}
  defp profile(_value), do: error(:invalid_placement_context, :profile)

  defp non_empty(field, value) when is_binary(value) do
    case String.trim(value) do
      "" -> error(:invalid_placement_context, field)
      trimmed -> {:ok, trimmed}
    end
  end

  defp non_empty(field, _value), do: error(:invalid_placement_context, field)

  defp error(code, field), do: {:error, %ContextError{code: code, field: field}}
end
