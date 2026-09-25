defmodule Chimwemwe.LocalBridge.Config do
  @moduledoc """
  Parses the explicit environment guard for the local UI-1A bridge.

  The bridge has no default token and cannot start outside the guarded local
  mode. Production authentication is deliberately absent.
  """

  @minimum_token_bytes 32
  @default_port 4001

  @spec application_children() :: {:ok, [Supervisor.child_spec()]} | {:error, term()}
  def application_children do
    case parse(System.get_env()) do
      :disabled -> {:ok, []}
      {:ok, options} -> {:ok, [{Chimwemwe.LocalBridge.Supervisor, options}]}
      {:error, reason} -> {:error, {:invalid_local_bridge_configuration, reason}}
    end
  end

  @doc false
  @spec parse(map()) :: :disabled | {:ok, keyword()} | {:error, atom()}
  def parse(environment) when is_map(environment) do
    if Map.get(environment, "CHIMWEMWE_UI1_LOCAL") == "true" do
      with {:ok, token} <- token(Map.get(environment, "CHIMWEMWE_UI1_BRIDGE_TOKEN")),
           {:ok, port} <- port(Map.get(environment, "CHIMWEMWE_UI1_PORT")) do
        {:ok,
         [
           port: port,
           repository_options: Application.get_env(:chimwemwe_core, Chimwemwe.Repo, []),
           token: token
         ]}
      end
    else
      :disabled
    end
  end

  def parse(_environment), do: {:error, :environment}

  defp token(value) when is_binary(value) and byte_size(value) >= @minimum_token_bytes,
    do: {:ok, value}

  defp token(_value), do: {:error, :bridge_token}

  defp port(nil), do: {:ok, @default_port}

  defp port(value) when is_binary(value) do
    case Integer.parse(value) do
      {port, ""} when port in 1..65_535 -> {:ok, port}
      _invalid -> {:error, :port}
    end
  end

  defp port(_value), do: {:error, :port}
end
