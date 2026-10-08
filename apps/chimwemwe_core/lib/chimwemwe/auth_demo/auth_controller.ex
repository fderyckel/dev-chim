defmodule Chimwemwe.AuthDemo.AuthController do
  @moduledoc false

  use Phoenix.Controller, formats: [:html]
  use AshAuthentication.Phoenix.Controller

  alias Chimwemwe.AuthDemo.Admin
  alias Chimwemwe.Identity.LocalCredentials

  def new(conn, _params) do
    if conn.assigns[:current_account] do
      redirect_after_sign_in(conn, conn.assigns.current_account)
    else
      render_sign_in(conn)
    end
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    case LocalCredentials.authenticate(email, password) do
      {:ok, {:active, account}} ->
        conn
        |> delete_session(:pending_local_account_id)
        |> delete_session(:pending_local_account_lock_version)
        |> delete_session(:pending_local_account_verified_at)
        |> store_in_session(account)
        |> redirect_after_sign_in(account)

      {:ok, {:first_login, account}} ->
        conn
        |> clear_session(:chimwemwe_core)
        |> configure_session(renew: true)
        |> put_session(:pending_local_account_id, account.id)
        |> put_session(:pending_local_account_lock_version, account.lock_version)
        |> put_session(:pending_local_account_verified_at, System.system_time(:second))
        |> redirect(to: "/first-login/password")

      {:error, :invalid_login} ->
        conn
        |> put_flash(:error, "Sign-in was not accepted.")
        |> render_sign_in(401)
    end
  end

  def create(conn, _params) do
    conn |> put_flash(:error, "Sign-in was not accepted.") |> render_sign_in(400)
  end

  def home(conn, _params) do
    case conn.assigns[:current_account] do
      nil ->
        redirect(conn, to: "/sign-in")

      account ->
        if Admin.authorized?(account) do
          redirect(conn, to: "/admin")
        else
          csrf_token = Plug.CSRFProtection.get_csrf_token()

          conn
          |> put_resp_header("cache-control", "no-store")
          |> html(staff_home(account.email, csrf_token))
        end
    end
  end

  @impl true
  def success(conn, _activity, user, _token) do
    conn |> store_in_session(user) |> redirect_after_sign_in(user)
  end

  @impl true
  def failure(conn, _activity, _reason) do
    conn |> put_flash(:error, "Sign-in was not accepted.") |> render_sign_in(401)
  end

  @impl true
  def sign_out(conn, _params) do
    conn
    |> clear_session(:chimwemwe_core)
    |> configure_session(renew: true)
    |> redirect(to: "/sign-in")
  end

  defp redirect_after_sign_in(conn, account) do
    redirect(conn, to: if(Admin.authorized?(account), do: "/admin", else: "/"))
  end

  defp render_sign_in(conn, status \\ 200) do
    csrf_token = Plug.CSRFProtection.get_csrf_token()
    error = Phoenix.Flash.get(conn.assigns[:flash] || %{}, :error)
    info = Phoenix.Flash.get(conn.assigns[:flash] || %{}, :info)

    notice =
      cond do
        is_binary(error) ->
          "<p class=\"error\" role=\"alert\">#{escape(error)}</p>"

        is_binary(info) ->
          "<p class=\"info\" role=\"status\">#{escape(info)}</p>"

        true ->
          ""
      end

    conn
    |> put_status(status)
    |> put_resp_header("cache-control", "no-store")
    |> html("""
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sign in to Chimwemwe</title>#{styles()}</head>
    <body><main><section><p class="eyebrow">Chimwemwe</p><h1>Sign in</h1>
    <p>Use your email and password. A new account's temporary password will take you directly to password replacement.</p>
    #{notice}
    <form method="post" action="/sign-in">
      <input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}">
      <label>Email<input type="email" name="session[email]" autocomplete="username" required maxlength="320"></label>
      <label>Password<input type="password" name="session[password]" autocomplete="current-password" required maxlength="128"></label>
      <button type="submit">Sign in</button>
    </form>
    <p class="muted">There is no public registration or email password reset. Ask an administrator to create or reset the account.</p>
    </section></main></body></html>
    """)
  end

  defp staff_home(email, csrf_token) do
    """
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Local account verified</title>#{styles()}</head>
    <body><main><section><p class="eyebrow">Local credential proof</p><h1>Sign-in successful</h1>
    <p><strong>#{escape(email)}</strong> authenticated with the permanent password.</p>
    <p>This proves the credential lifecycle only. The email did not create a school membership, role, class assignment, or permission.</p>
    <form method="post" action="/sign-out"><input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}"><button type="submit">Sign out</button></form>
    </section></main></body></html>
    """
  end

  defp styles do
    """
    <style>
      :root { font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #172033; background: #f5f7fb; }
      body { margin: 0; } main { min-height: 100vh; display: grid; place-items: center; padding: 24px; box-sizing: border-box; }
      section { width: min(100%, 460px); background: white; border: 1px solid #e4e9f2; border-radius: 18px; padding: 32px; box-shadow: 0 16px 48px rgba(33,54,93,.1); }
      .eyebrow { color: #4361ee; font-weight: 750; font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; }
      h1 { margin: 0 0 16px; font-size: 2.35rem; letter-spacing: -.04em; } p { line-height: 1.55; color: #55627a; }
      form { display: grid; gap: 14px; margin-top: 22px; } label { display: grid; gap: 6px; font-weight: 650; font-size: .88rem; }
      input { box-sizing: border-box; width: 100%; border: 1px solid #bcc8d8; border-radius: 9px; padding: 11px 12px; font: inherit; }
      button { border: 0; border-radius: 9px; padding: 11px 14px; background: #335cff; color: white; font: inherit; font-weight: 750; cursor: pointer; }
      .error, .info { padding: 10px 12px; border-radius: 8px; } .error { background: #fff0f1; color: #9e1c2b; }
      .info { background: #eef3ff; color: #173b8f; } .muted { font-size: .86rem; }
    </style>
    """
  end

  defp escape(value) do
    value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end
end
