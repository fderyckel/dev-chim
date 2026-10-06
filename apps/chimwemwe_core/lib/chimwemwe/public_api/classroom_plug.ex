defmodule Chimwemwe.PublicApi.ClassroomPlug do
  @moduledoc false
  import Plug.Conn
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}
  def init(options), do: options

  def call(conn, _) do
    with true <- Application.get_env(:chimwemwe_core, :local_classroom_enabled) === true,
         true <- conn.host in ["localhost", "127.0.0.1"],
         true <- conn.remote_ip in [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}],
         {:ok, config} <- Config.fetch(),
         %URI{scheme: "https", host: host} when host in ["localhost", "127.0.0.1"] <-
           URI.parse(config.origin) do
      conn
    else
      _ ->
        conn
        |> ErrorResponse.send(
          404,
          "not_available",
          "The local classroom workflow is unavailable."
        )
        |> halt()
    end
  end
end
