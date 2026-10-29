defmodule Chimwemwe.PublicApi.CalendarPlug do
  @moduledoc false

  import Plug.Conn

  alias Chimwemwe.AcademicCalendar.ConnectedPreparation
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  def init(options), do: options

  def call(conn, _options) do
    with true <- Application.get_env(:chimwemwe_core, :local_calendar_enabled) === true,
         true <- conn.host in ["localhost", "127.0.0.1"],
         true <- conn.remote_ip in [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}],
         {:ok, config} <- Config.fetch(),
         %URI{scheme: "https", host: host} when host in ["localhost", "127.0.0.1"] <-
           URI.parse(config.origin),
         {:ok, target} <-
           :chimwemwe_core
           |> Application.get_env(:local_calendar_target)
           |> ConnectedPreparation.target() do
      assign(conn, :local_calendar_target, target)
    else
      _unavailable ->
        conn
        |> ErrorResponse.send(
          404,
          "not_available",
          "The local calendar workflow is unavailable."
        )
        |> halt()
    end
  end
end
