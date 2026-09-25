defmodule Chimwemwe.LocalBridge.SessionPlug do
  @moduledoc false

  import Plug.Conn

  alias Chimwemwe.LocalBridge.{ErrorResponse, SessionStore}
  alias Chimwemwe.Platform.ExecutionContext

  @doc false
  def init(options), do: options

  @doc false
  def call(conn, _options) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, {actor, placement}} <- SessionStore.authenticate(token),
         {:ok, context} <-
           ExecutionContext.establish(
             actor,
             placement,
             correlation_id: Ecto.UUID.generate(),
             purpose: "ui1.local.assignment_options.read",
             locale: "en"
           ) do
      assign(conn, :execution_context, context)
    else
      _missing_or_invalid ->
        conn
        |> ErrorResponse.send(401, "unauthenticated", "A valid local session is required.")
        |> halt()
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _missing_or_invalid -> :error
    end
  end
end
