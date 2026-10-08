defmodule Chimwemwe.AuthDemo.FirstLoginController do
  @moduledoc false

  use Phoenix.Controller, formats: [:html]

  alias Chimwemwe.Identity.{LocalCredentials, PasswordPolicy}

  plug(:require_recent_temporary_password)

  def edit(conn, _params), do: render_form(conn)

  def update(conn, %{
        "password" => %{"new" => password, "confirmation" => confirmation}
      }) do
    account_id = get_session(conn, :pending_local_account_id)
    lock_version = get_session(conn, :pending_local_account_lock_version)

    case LocalCredentials.complete_first_login(account_id, lock_version, password, confirmation) do
      {:ok, _account} ->
        conn
        |> delete_session(:pending_local_account_id)
        |> delete_session(:pending_local_account_lock_version)
        |> delete_session(:pending_local_account_verified_at)
        |> configure_session(renew: true)
        |> put_flash(:info, "Your password was set. Sign in with the new password.")
        |> redirect(to: "/sign-in")

      {:error, reason} ->
        conn
        |> put_flash(:error, password_message(reason))
        |> render_form(422)
    end
  end

  def update(conn, _params) do
    conn |> put_flash(:error, "Enter and confirm a new password.") |> render_form(400)
  end

  defp require_recent_temporary_password(conn, _options) do
    account_id = get_session(conn, :pending_local_account_id)
    lock_version = get_session(conn, :pending_local_account_lock_version)
    verified_at = get_session(conn, :pending_local_account_verified_at)
    now = System.system_time(:second)

    if is_binary(account_id) and is_integer(lock_version) and is_integer(verified_at) and
         verified_at <= now and
         now - verified_at <= LocalCredentials.first_login_session_seconds() do
      conn
    else
      conn
      |> delete_session(:pending_local_account_id)
      |> delete_session(:pending_local_account_lock_version)
      |> delete_session(:pending_local_account_verified_at)
      |> put_flash(:error, "Sign in again with the temporary password.")
      |> redirect(to: "/sign-in")
      |> halt()
    end
  end

  defp render_form(conn, status \\ 200) do
    csrf_token = Plug.CSRFProtection.get_csrf_token()
    error = Phoenix.Flash.get(conn.assigns[:flash] || %{}, :error)

    notice =
      if is_binary(error),
        do: "<p class=\"error\" role=\"alert\">#{escape(error)}</p>",
        else: ""

    conn
    |> put_status(status)
    |> put_resp_header("cache-control", "no-store")
    |> html("""
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Choose your password</title><style>
      :root { font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #172033; background: #f5f7fb; }
      body { margin: 0; } main { min-height: 100vh; display: grid; place-items: center; padding: 24px; box-sizing: border-box; }
      section { width: min(100%, 480px); background: white; border: 1px solid #e4e9f2; border-radius: 18px; padding: 32px; box-shadow: 0 16px 48px rgba(33,54,93,.1); }
      .eyebrow { color: #4361ee; font-weight: 750; font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; }
      h1 { margin: 0 0 16px; font-size: 2.2rem; letter-spacing: -.04em; } p { line-height: 1.55; color: #55627a; }
      form { display: grid; gap: 14px; margin-top: 22px; } label { display: grid; gap: 6px; font-weight: 650; font-size: .88rem; }
      input { box-sizing: border-box; width: 100%; border: 1px solid #bcc8d8; border-radius: 9px; padding: 11px 12px; font: inherit; }
      button { border: 0; border-radius: 9px; padding: 11px 14px; background: #335cff; color: white; font: inherit; font-weight: 750; cursor: pointer; }
      .error { padding: 10px 12px; border-radius: 8px; background: #fff0f1; color: #9e1c2b; }
    </style></head>
    <body><main><section><p class="eyebrow">First login</p><h1>Create your permanent password</h1>
    <p>Use at least #{PasswordPolicy.minimum_length()} characters. Spaces and passphrases are allowed; special-character rules are not required.</p>
    #{notice}
    <form method="post" action="/first-login/password">
      <input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}">
      <label>New password<input type="password" name="password[new]" autocomplete="new-password" required minlength="#{PasswordPolicy.minimum_length()}" maxlength="#{PasswordPolicy.maximum_length()}"></label>
      <label>Confirm new password<input type="password" name="password[confirmation]" autocomplete="new-password" required minlength="#{PasswordPolicy.minimum_length()}" maxlength="#{PasswordPolicy.maximum_length()}"></label>
      <button type="submit">Set password</button>
    </form></section></main></body></html>
    """)
  end

  defp password_message(:password_too_short),
    do: "Use at least #{PasswordPolicy.minimum_length()} characters."

  defp password_message(:password_too_long),
    do: "Use no more than #{PasswordPolicy.maximum_length()} characters."

  defp password_message(:blocked_password), do: "Choose a less predictable password."

  defp password_message(_reason),
    do: "The password could not be changed. Sign in again if needed."

  defp escape(value) do
    value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end
end
