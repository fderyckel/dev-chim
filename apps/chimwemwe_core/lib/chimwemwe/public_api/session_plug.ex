defmodule Chimwemwe.PublicApi.SessionPlug do
  @moduledoc false

  import Plug.Conn

  alias Chimwemwe.Identity.{Error, PublicSessionAdapter}
  alias Chimwemwe.Platform.PersistenceError
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  @doc false
  def init(options), do: options

  @doc false
  def call(conn, _options) do
    with {:ok, config} <- Config.fetch(),
         {:ok, purpose} <- purpose(conn.method, conn.request_path),
         cookie when is_binary(cookie) <- conn.req_cookies[PublicSessionAdapter.cookie_name()],
         {:ok, request_session} <-
           PublicSessionAdapter.authenticate(
             config.runtime,
             cookie,
             purpose,
             locale(conn),
             request_id(conn)
           ) do
      assign(conn, :public_request_session, request_session)
    else
      {:error, %Error{code: :retryable_dependency}} ->
        unavailable(conn)

      {:error, %PersistenceError{}} ->
        unavailable(conn)

      _missing_or_invalid ->
        conn
        |> ErrorResponse.send(
          401,
          "unauthenticated",
          "A current application session is required."
        )
        |> halt()
    end
  end

  defp unavailable(conn) do
    conn
    |> ErrorResponse.send(503, "retryable_dependency", "The session service is unavailable.")
    |> halt()
  end

  defp purpose("GET", "/api/v1/session"), do: {:ok, :session_read}
  defp purpose("POST", "/api/v1/session/logout"), do: {:ok, :session_logout}
  defp purpose("POST", "/api/v1/session/support/elevate"), do: {:ok, :support_elevate}
  defp purpose(_method, _path), do: :error

  defp locale(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> case do
      nil -> "en"
      value -> value |> String.split([",", ";"], parts: 2) |> List.first()
    end
  end

  defp request_id(conn) do
    case get_resp_header(conn, "x-request-id") do
      [request_id] -> request_id
      _missing -> Ecto.UUID.generate()
    end
  end
end
