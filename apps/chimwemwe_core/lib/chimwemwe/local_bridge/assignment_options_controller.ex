defmodule Chimwemwe.LocalBridge.AssignmentOptionsController do
  @moduledoc false

  use Phoenix.Controller, formats: [:json]

  alias Chimwemwe.LocalBridge.ErrorResponse
  alias Chimwemwe.Platform.{Authority, AuthorityError, PersistenceError}
  alias Chimwemwe.Platform.Authority.AssignmentOption

  @runtime Chimwemwe.LocalBridge.PersistenceRuntime
  @api_version "v1"

  @doc false
  def index(conn, _params) do
    case Authority.assignment_options(@runtime, conn.assigns.execution_context) do
      {:ok, options} -> send_options(conn, options)
      {:error, %AuthorityError{code: :forbidden}} -> forbidden(conn)
      {:error, %PersistenceError{}} -> retryable(conn)
      {:error, %AuthorityError{code: :retryable_dependency}} -> retryable(conn)
      {:error, _error} -> internal(conn)
    end
  end

  defp send_options(conn, options) do
    body = %{
      "data" => %{
        "connection" => "local_core",
        "contract_version" => options.contract_version,
        "memberships" => Enum.map(options.memberships, &option/1),
        "roles" => Enum.map(options.roles, &option/1)
      }
    }

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("x-api-version", @api_version)
    |> json(body)
  end

  defp option(%AssignmentOption{id: id, label: label}),
    do: %{"id" => id, "label" => label}

  defp forbidden(conn) do
    ErrorResponse.send(conn, 403, "forbidden", "The request is not authorized.")
  end

  defp retryable(conn) do
    ErrorResponse.send(
      conn,
      503,
      "retryable_dependency",
      "The local core is temporarily unavailable."
    )
  end

  defp internal(conn) do
    ErrorResponse.send(conn, 500, "internal_error", "The local core request failed.")
  end
end
