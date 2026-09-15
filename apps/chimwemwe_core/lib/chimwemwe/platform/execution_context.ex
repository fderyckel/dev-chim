defmodule Chimwemwe.Platform.ExecutionContext do
  @moduledoc """
  The validated actor, tenant, placement, and request metadata required by core work.

  Establishment accepts only the two trusted platform types. It does not accept a request
  map or caller-selected placement coordinates.
  """

  alias Ash.Type.UUID
  alias Chimwemwe.Platform.{ContextError, TrustedActor, TrustedPlacement}

  @enforce_keys [:actor, :placement, :correlation_id, :purpose, :locale]
  defstruct [:actor, :placement, :correlation_id, :purpose, :locale]

  @opaque t :: %__MODULE__{
            actor: TrustedActor.t(),
            placement: TrustedPlacement.t(),
            correlation_id: String.t(),
            purpose: String.t(),
            locale: String.t()
          }

  @spec establish(TrustedActor.t(), TrustedPlacement.t(), keyword()) ::
          {:ok, t()} | {:error, ContextError.t()}
  def establish(actor, placement, metadata) when is_list(metadata) do
    with :ok <- TrustedActor.validate(actor),
         :ok <- TrustedPlacement.validate(placement),
         :ok <- same_tenant(actor, placement),
         {:ok, correlation_id} <-
           cast_uuid(:correlation_id, Keyword.get(metadata, :correlation_id)),
         {:ok, purpose} <- non_empty(:purpose, Keyword.get(metadata, :purpose)),
         {:ok, locale} <- non_empty(:locale, Keyword.get(metadata, :locale)) do
      {:ok,
       %__MODULE__{
         actor: actor,
         placement: placement,
         correlation_id: correlation_id,
         purpose: purpose,
         locale: locale
       }}
    end
  end

  def establish(_actor, _placement, _metadata), do: error(:missing_trusted_context, nil)

  @spec validate(term()) :: :ok | {:error, ContextError.t()}
  def validate(%__MODULE__{} = context) do
    with :ok <- TrustedActor.validate(context.actor),
         :ok <- TrustedPlacement.validate(context.placement),
         :ok <- same_tenant(context.actor, context.placement),
         {:ok, _correlation_id} <- cast_uuid(:correlation_id, context.correlation_id),
         {:ok, _purpose} <- non_empty(:purpose, context.purpose),
         {:ok, _locale} <- non_empty(:locale, context.locale) do
      :ok
    end
  end

  def validate(_context), do: error(:missing_trusted_context, nil)

  @spec with_validated(term(), (t() -> result)) :: result | {:error, ContextError.t()}
        when result: term()
  def with_validated(context, operation) when is_function(operation, 1) do
    with :ok <- validate(context), do: operation.(context)
  end

  @spec same_tenant(TrustedActor.t(), TrustedPlacement.t()) ::
          :ok | {:error, ContextError.t()}
  defp same_tenant(actor, placement) do
    if TrustedActor.tenant_id(actor) == TrustedPlacement.tenant_id(placement) do
      :ok
    else
      error(:tenant_mismatch, :tenant_id)
    end
  end

  defp cast_uuid(field, value) do
    case UUID.cast_input(value, []) do
      {:ok, uuid} -> {:ok, uuid}
      _error -> error(:invalid_execution_metadata, field)
    end
  end

  defp non_empty(field, value) when is_binary(value) do
    case String.trim(value) do
      "" -> error(:invalid_execution_metadata, field)
      trimmed -> {:ok, trimmed}
    end
  end

  defp non_empty(field, _value), do: error(:invalid_execution_metadata, field)

  defp error(code, field), do: {:error, %ContextError{code: code, field: field}}
end
