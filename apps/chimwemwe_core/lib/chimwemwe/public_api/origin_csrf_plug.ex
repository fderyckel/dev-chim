defmodule Chimwemwe.PublicApi.OriginCsrfPlug do
  @moduledoc false

  import Plug.Conn

  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  @doc false
  def init(options), do: options

  @doc false
  def call(conn, _options) do
    request = conn.assigns[:public_request_session]

    with {:ok, config} <- Config.fetch(),
         [origin] <- get_req_header(conn, "origin"),
         true <- Plug.Crypto.secure_compare(origin, config.origin),
         [csrf_token] <- get_req_header(conn, "x-csrf-token"),
         true <- Plug.Crypto.secure_compare(csrf_token, request.csrf_token) do
      conn
    else
      _missing_or_invalid ->
        conn
        |> ErrorResponse.send(
          403,
          "forbidden",
          "The request origin or CSRF proof was not accepted."
        )
        |> halt()
    end
  end
end
