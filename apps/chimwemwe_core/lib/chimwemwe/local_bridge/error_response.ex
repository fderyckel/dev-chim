defmodule Chimwemwe.LocalBridge.ErrorResponse do
  @moduledoc false

  import Plug.Conn

  @api_version "v1"

  @doc false
  def send(conn, status, code, detail) do
    body = Jason.encode!(%{"errors" => [%{"code" => code, "detail" => detail}]})

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("x-api-version", @api_version)
    |> send_resp(status, body)
  end
end
