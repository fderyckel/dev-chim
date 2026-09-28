defmodule Chimwemwe.PublicApi.CallbackController do
  @moduledoc false

  use Phoenix.Controller, formats: [:json]

  alias Chimwemwe.Identity.{Error, PublicSessionAdapter}
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  @doc false
  def show(conn, params) do
    with {:ok, config} <- Config.fetch(),
         {:ok, result} <-
           PublicSessionAdapter.complete_callback(config.runtime, config.verifier, params) do
      conn
      |> put_resp_cookie(
        PublicSessionAdapter.cookie_name(),
        result.cookie_value,
        PublicSessionAdapter.cookie_options()
      )
      |> put_resp_header("location", result.redirect_to)
      |> send_resp(303, "")
    else
      {:error, %Error{code: :retryable_dependency}} ->
        ErrorResponse.send(
          conn,
          503,
          "retryable_dependency",
          "Sign-in is temporarily unavailable."
        )

      _invalid_or_denied ->
        ErrorResponse.send(conn, 401, "unauthenticated", "Sign-in was not accepted.")
    end
  end
end
