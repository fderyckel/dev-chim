defmodule Chimwemwe.PublicApi.CommunicationsPlug do
  @moduledoc false
  import Plug.Conn
  alias Chimwemwe.Communications.{LocalRequestGate, Publication}
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}
  def init(options), do: options

  def call(conn, _options) do
    with %Publication{} = publication <-
           Application.get_env(:chimwemwe_core, :local_communications),
         true <-
           LocalRequestGate.held?(
             publication.request_gate,
             publication.tenant_id,
             publication.institution_id
           ),
         true <- conn.host in ["localhost", "127.0.0.1"],
         true <- conn.remote_ip in [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}],
         {:ok, config} <- Config.fetch(),
         %URI{scheme: "https", host: host} when host in ["localhost", "127.0.0.1"] <-
           URI.parse(config.origin) do
      conn
    else
      _ ->
        conn
        |> ErrorResponse.send(404, "not_available", "The local notice workflow is unavailable.")
        |> halt()
    end
  end
end
