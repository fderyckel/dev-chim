defmodule Chimwemwe.AuthDemo.AuthController do
  @moduledoc false

  require Logger

  use Phoenix.Controller, formats: [:html]
  use AshAuthentication.Phoenix.Controller

  @impl true
  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> redirect(to: "/")
  end

  @impl true
  def failure(conn, activity, reason) do
    Logger.warning(
      "Local authentication was rejected: #{inspect(activity)} #{reason_type(reason)}"
    )

    conn
    |> put_flash(:error, "Sign-in was not accepted.")
    |> redirect(to: "/sign-in")
  end

  @impl true
  def sign_out(conn, _params) do
    conn
    |> clear_session(:chimwemwe_core)
    |> redirect(to: "/sign-in")
  end

  defp reason_type(%{__struct__: module}), do: inspect(module)
  defp reason_type(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_type(_reason), do: "unknown"
end
