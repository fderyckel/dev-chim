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
  defp purpose("GET", "/api/v1/classroom/classes"), do: {:ok, :classroom_read}
  defp purpose("POST", "/api/v1/classroom/prepare-attendance"), do: {:ok, :classroom_read}
  defp purpose("POST", "/api/v1/classroom/submit-attendance"), do: {:ok, :classroom_submit}
  defp purpose(_method, _path), do: :error

  defp locale(conn) do
    # Browser language ranges are preferences, not exact application locale codes.
    conn
    |> get_req_header("accept-language")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.find_value("en", &supported_locale/1)
  end

  defp supported_locale(range) do
    value = range |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase()

    case String.split(value, "-", parts: 2) do
      ["en", "mw"] -> "en-MW"
      ["en" | _] -> "en"
      ["fr" | _] -> "fr"
      _ -> nil
    end
  end

  defp request_id(conn) do
    case get_resp_header(conn, "x-request-id") do
      [request_id] ->
        # Plug's default request IDs (and incoming trace IDs) are not necessarily UUIDs.
        case Ecto.UUID.cast(request_id) do
          {:ok, uuid} -> uuid
          :error -> Ecto.UUID.generate()
        end

      _missing ->
        Ecto.UUID.generate()
    end
  end
end
