defmodule Chimwemwe.PublicApi.SignInController do
  @moduledoc false

  use Phoenix.Controller, formats: [:json]

  alias Chimwemwe.Identity.{Error, PublicSessionAdapter}
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  @doc false
  def show(conn, params) when map_size(params) == 0 do
    with {:ok, config} <- Config.fetch(),
         sign_in when is_map(sign_in) <- config.sign_in,
         {:ok, location} <-
           PublicSessionAdapter.start_oidc_sign_in(
             config.runtime,
             config.verifier,
             sign_in,
             config.origin <> "/auth/callback"
           ) do
      conn
      |> put_resp_header("location", location)
      |> send_resp(303, "")
    else
      {:error, %Error{code: :forbidden}} ->
        ErrorResponse.send(conn, 401, "unauthenticated", "Sign-in was not accepted.")

      _disabled_invalid_or_unavailable ->
        ErrorResponse.send(
          conn,
          503,
          "retryable_dependency",
          "Sign-in is temporarily unavailable."
        )
    end
  end

  def show(conn, _params) do
    ErrorResponse.send(conn, 400, "invalid_input", "Sign-in request was not accepted.")
  end
end
