defmodule Chimwemwe.InstitutionalStructure.Runtime do
  @moduledoc """
  Trusted startup configuration for the private synthetic CF-1 boundary.

  This value is established by application composition, never deserialized from
  action input. The verifier is a trusted records adapter, not a client-selected
  plugin. There is no default verifier and no production records connector.
  """
  @enforce_keys [:persistence, :verifier, :source]
  defstruct [:persistence, :verifier, :source]

  @opaque t :: %__MODULE__{
            persistence: Supervisor.supervisor(),
            verifier: module(),
            source: term()
          }

  @spec new(Supervisor.supervisor(), module(), term()) :: {:ok, t()} | {:error, :invalid_runtime}
  def new(persistence, verifier, source) when is_atom(verifier) do
    if Code.ensure_loaded?(verifier) and function_exported?(verifier, :verify, 2) do
      {:ok, %__MODULE__{persistence: persistence, verifier: verifier, source: source}}
    else
      {:error, :invalid_runtime}
    end
  end

  def new(_persistence, _verifier, _source), do: {:error, :invalid_runtime}

  @doc false
  @spec persistence(t()) :: {:ok, Supervisor.supervisor()} | {:error, :invalid_runtime}
  def persistence(%__MODULE__{persistence: persistence}), do: {:ok, persistence}
  def persistence(_runtime), do: {:error, :invalid_runtime}

  @doc false
  @spec verify(t(), map()) :: {:ok, map()} | {:error, term()}
  def verify(%__MODULE__{verifier: verifier, source: source}, request),
    do: verifier.verify(source, request)

  def verify(_runtime, _request), do: {:error, :invalid_runtime}
end
