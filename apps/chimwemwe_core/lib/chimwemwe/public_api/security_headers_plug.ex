defmodule Chimwemwe.PublicApi.SecurityHeadersPlug do
  @moduledoc false

  import Plug.Conn

  @doc false
  def init(options), do: options

  @doc false
  def call(conn, _options) do
    register_before_send(conn, fn response ->
      response
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("content-security-policy", "default-src 'none'; frame-ancestors 'none'")
      |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
      |> put_resp_header("referrer-policy", "no-referrer")
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("x-frame-options", "DENY")
      |> put_resp_header("x-api-version", "v1")
    end)
  end
end
