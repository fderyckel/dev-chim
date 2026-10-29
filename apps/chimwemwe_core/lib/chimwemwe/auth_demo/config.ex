defmodule Chimwemwe.AuthDemo.Config do
  @moduledoc """
  Parses the explicit guard for the loopback-only authentication demonstration.

  It is never enabled by default and cannot share a runtime with the synthetic
  UI-1A bridge. This keeps a real password/session path out of that fixture-only
  browser surface.
  """

  @default_port 4012
  @minimum_secret_bytes 32
  @demo_tenant_id "99999999-9999-4999-8999-999999999999"
  @admin_actor_id "aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa"
  @staff_candidates [
    %{
      actor_id: "bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb",
      label: "Amara Phiri · educator"
    },
    %{
      actor_id: "cccccccc-3333-4333-8333-cccccccccccc",
      label: "Tadala Banda · registrar"
    }
  ]

  @spec application_children() :: {:ok, [Supervisor.child_spec()]} | {:error, term()}
  def application_children do
    case parse(System.get_env()) do
      :disabled -> {:ok, []}
      {:ok, options} -> {:ok, [{Chimwemwe.AuthDemo.Supervisor, options}]}
      {:error, reason} -> {:error, {:invalid_auth_demo_configuration, reason}}
    end
  end

  @doc false
  @spec parse(map()) :: :disabled | {:ok, keyword()} | {:error, atom()}
  def parse(environment) when is_map(environment) do
    case Map.get(environment, "CHIMWEMWE_AUTH_DEMO") do
      nil -> :disabled
      "false" -> :disabled
      "true" -> parse_enabled(environment)
      _other -> {:error, :auth_demo_guard}
    end
  end

  def parse(_environment), do: {:error, :environment}

  @doc false
  @spec tenant_id() :: String.t()
  def tenant_id, do: @demo_tenant_id

  @doc false
  @spec admin_actor_id() :: String.t()
  def admin_actor_id, do: @admin_actor_id

  @doc false
  @spec staff_candidates() :: [map()]
  def staff_candidates, do: @staff_candidates

  defp parse_enabled(environment) do
    with :ok <- independent_from_ui1(environment),
         {:ok, port} <- port(Map.get(environment, "CHIMWEMWE_AUTH_PORT")),
         {:ok, password} <- secret(Map.get(environment, "CHIMWEMWE_AUTH_DEMO_PASSWORD")),
         {:ok, signing_secret} <-
           secret(Map.get(environment, "CHIMWEMWE_AUTH_TOKEN_SIGNING_SECRET")) do
      {:ok,
       [
         port: port,
         password: password,
         repository_options: Application.get_env(:chimwemwe_core, Chimwemwe.Repo, []),
         signing_secret: signing_secret,
         tenant_id: @demo_tenant_id
       ]}
    end
  end

  defp independent_from_ui1(environment) do
    if Map.get(environment, "CHIMWEMWE_UI1_LOCAL") == "true" do
      {:error, :ui1_local_conflict}
    else
      :ok
    end
  end

  defp secret(value) when is_binary(value) and byte_size(value) >= @minimum_secret_bytes,
    do: {:ok, value}

  defp secret(_value), do: {:error, :local_secret}

  defp port(nil), do: {:ok, @default_port}

  defp port(value) when is_binary(value) do
    case Integer.parse(value) do
      {port, ""} when port in 1..65_535 -> {:ok, port}
      _invalid -> {:error, :port}
    end
  end

  defp port(_value), do: {:error, :port}
end
