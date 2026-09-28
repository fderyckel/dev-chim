defmodule Chimwemwe.PublicApi.SessionController do
  @moduledoc false

  use Phoenix.Controller, formats: [:json]

  alias Chimwemwe.Identity.{Error, PublicRequestSession, PublicSessionAdapter}
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  @doc false
  def show(conn, _params) do
    request = conn.assigns.public_request_session

    json(conn, %{
      "data" => %{
        "actor_id" => request.session.actor_id,
        "assurance" => request.session.assurance,
        "csrf_token" => request.csrf_token,
        "idle_expires_at" => DateTime.to_iso8601(request.session.idle_expires_at),
        "support" => support(request)
      }
    })
  end

  @doc false
  def logout(conn, _params) do
    request = conn.assigns.public_request_session

    with {:ok, config} <- Config.fetch(),
         {:ok, :logged_out} <- PublicSessionAdapter.logout(config.runtime, request) do
      conn
      |> delete_resp_cookie(
        PublicSessionAdapter.cookie_name(),
        PublicSessionAdapter.cookie_options()
      )
      |> send_resp(204, "")
    else
      {:error, %Error{code: :retryable_dependency}} ->
        ErrorResponse.send(
          conn,
          503,
          "retryable_dependency",
          "Logout is temporarily unavailable."
        )

      _failure ->
        ErrorResponse.send(conn, 401, "unauthenticated", "The session is no longer current.")
    end
  end

  @doc false
  def elevate(conn, %{"grant_id" => grant_id} = params) when map_size(params) == 1 do
    request = conn.assigns.public_request_session

    with {:ok, config} <- Config.fetch(),
         {:ok, cookie_value, grant} <-
           PublicSessionAdapter.elevate_support(config.runtime, request, grant_id) do
      conn
      |> put_resp_cookie(
        PublicSessionAdapter.cookie_name(),
        cookie_value,
        PublicSessionAdapter.cookie_options()
      )
      |> put_status(200)
      |> json(%{
        "data" => %{
          "mode" => "support",
          "purpose" => grant.purpose,
          "expires_at" => DateTime.to_iso8601(grant.expires_at),
          "capability_scope" => grant.capability_scope
        }
      })
    else
      {:error, %Error{code: :retryable_dependency}} ->
        ErrorResponse.send(conn, 503, "retryable_dependency", "Support access is unavailable.")

      _denied ->
        ErrorResponse.send(conn, 403, "forbidden", "Support access was not activated.")
    end
  end

  def elevate(conn, _params) do
    ErrorResponse.send(conn, 400, "invalid_request", "One exact grant reference is required.")
  end

  defp support(%PublicRequestSession{support: nil}), do: nil

  defp support(%PublicRequestSession{support: support}) do
    %{
      "mode" => "support",
      "support_actor_id" => support.support_actor_id,
      "purpose" => support.purpose,
      "expires_at" => DateTime.to_iso8601(support.expires_at),
      "capability_scope" => support.capability_scope
    }
  end
end
