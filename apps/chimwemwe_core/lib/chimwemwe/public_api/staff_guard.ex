defmodule Chimwemwe.PublicApi.StaffGuard do
  @moduledoc false
  import Plug.Conn
  alias Chimwemwe.PublicApi.{ErrorResponse, StaffConfig}
  def init(options), do: options

  def call(conn, _options) do
    with {:ok, config} <- StaffConfig.fetch(),
         true <- conn.remote_ip in [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}],
         origin = URI.parse(config.origin),
         true <- conn.host == origin.host and conn.port == origin.port do
      assign(conn, :staff_config, config)
    else
      _ -> conn |> ErrorResponse.send(404, "not_found", "This workflow is unavailable.") |> halt()
    end
  end
end
