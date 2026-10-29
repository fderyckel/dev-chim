defmodule Chimwemwe.AcademicCalendar.Runtime do
  @moduledoc """
  Trusted startup configuration for the private synthetic calendar writer.

  The persistence runtime is established by application composition and is
  never accepted from action input.
  """

  @enforce_keys [:persistence]
  defstruct [:persistence]

  @opaque t :: %__MODULE__{persistence: Supervisor.supervisor()}

  @spec new(Supervisor.supervisor()) :: {:ok, t()} | {:error, :invalid_runtime}
  def new(persistence) when is_pid(persistence) or is_atom(persistence),
    do: {:ok, %__MODULE__{persistence: persistence}}

  def new(_persistence), do: {:error, :invalid_runtime}

  @doc false
  @spec persistence(t()) :: {:ok, Supervisor.supervisor()} | {:error, :invalid_runtime}
  def persistence(%__MODULE__{persistence: persistence}), do: {:ok, persistence}
  def persistence(_runtime), do: {:error, :invalid_runtime}
end
