defmodule Chimwemwe.AuthDemo.AdminController do
  @moduledoc false

  use Phoenix.Controller, formats: [:html]

  alias Chimwemwe.AuthDemo.{Admin, Config}

  plug(:require_administrator)

  def index(conn, _params), do: render_current(conn)

  def create_account(conn, %{"account" => attributes}) do
    case Admin.provision_local_account(current_account(conn), attributes) do
      {:ok, provisioned} ->
        render_current(conn, provisioned)

      {:error, _error} ->
        conn
        |> put_flash(
          :error,
          "The account could not be created. Check the email and prepared staff record."
        )
        |> render_current()
    end
  end

  def create_account(conn, _params), do: redirect(conn, to: "/admin")

  def reissue_account(conn, %{"id" => account_id}) do
    case Admin.reissue_local_account(current_account(conn), account_id) do
      {:ok, provisioned} ->
        render_current(conn, provisioned)

      {:error, _error} ->
        conn
        |> put_flash(:error, "A new temporary password could not be issued.")
        |> render_current()
    end
  end

  def suspend_account(conn, %{"id" => account_id}) do
    case Admin.suspend_local_account(current_account(conn), account_id) do
      {:ok, _account} ->
        conn
        |> put_flash(:info, "The local account was suspended and its sessions were revoked.")
        |> redirect(to: "/admin")

      {:error, _error} ->
        conn
        |> put_flash(:error, "The local account could not be suspended.")
        |> redirect(to: "/admin")
    end
  end

  def create_connection(conn, %{"connection" => attributes}) do
    case Admin.register(current_account(conn), attributes) do
      {:ok, _connection} ->
        conn
        |> put_flash(:info, "The SSO connection was saved as a draft.")
        |> redirect(to: "/admin")

      {:error, _error} ->
        conn
        |> put_flash(:error, "The connection could not be saved. Check the required fields.")
        |> redirect(to: "/admin")
    end
  end

  def create_connection(conn, _params), do: redirect(conn, to: "/admin")

  def activate_connection(conn, %{"id" => connection_id}) do
    transition(
      conn,
      Admin.activate(current_account(conn), connection_id),
      "The SSO connection is active."
    )
  end

  def disable_connection(conn, %{"id" => connection_id}) do
    transition(
      conn,
      Admin.disable(current_account(conn), connection_id),
      "The SSO connection is disabled."
    )
  end

  defp transition(conn, {:ok, _connection}, message) do
    conn
    |> put_flash(:info, message)
    |> redirect(to: "/admin")
  end

  defp transition(conn, {:error, _error}, _message) do
    conn
    |> put_flash(:error, "That SSO connection could not be changed.")
    |> redirect(to: "/admin")
  end

  defp require_administrator(conn, _options) do
    cond do
      is_nil(current_account(conn)) ->
        conn |> redirect(to: "/sign-in") |> halt()

      not Admin.authorized?(current_account(conn)) ->
        conn |> send_resp(403, "Administrator access is required.") |> halt()

      true ->
        conn
    end
  end

  defp render_current(conn, provisioned \\ nil) do
    with {:ok, accounts} <- Admin.list_local_accounts(current_account(conn)),
         {:ok, connections} <- Admin.list(current_account(conn)) do
      render_page(conn, accounts, connections, provisioned)
    else
      _error ->
        conn
        |> put_status(503)
        |> html("Authentication administration is temporarily unavailable.")
    end
  end

  defp current_account(conn), do: conn.assigns[:current_account]

  defp render_page(conn, accounts, connections, provisioned) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> html(page_html(conn, accounts, connections, provisioned))
  end

  defp page_html(conn, accounts, connections, provisioned) do
    csrf_token = Plug.CSRFProtection.get_csrf_token()
    notice = flash_html(conn)
    credential = credential_html(provisioned)
    account_rows = Enum.map_join(accounts, "", &account_row(&1, csrf_token))
    connection_rows = Enum.map_join(connections, "", &connection_row(&1, csrf_token))

    candidate_options =
      Enum.map_join(Config.staff_candidates(), "", fn candidate ->
        "<option value=\"#{escape(candidate.actor_id)}\">#{escape(candidate.label)}</option>"
      end)

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Account administration</title>
        <style>
          :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #172033; background: #f5f7fb; }
          body { margin: 0; } main { max-width: 1120px; margin: 0 auto; padding: 48px 24px 72px; }
          h1 { margin: 0; font-size: clamp(2rem, 4vw, 3rem); letter-spacing: -0.04em; }
          h2 { font-size: 1.25rem; margin: 0 0 18px; } p { line-height: 1.55; color: #55627a; }
          .eyebrow { color: #4361ee; font-weight: 700; font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; }
          .lead { max-width: 760px; font-size: 1.06rem; }
          .notice { padding: 12px 16px; margin: 24px 0; border-radius: 10px; background: #eef3ff; color: #173b8f; }
          .notice.error { background: #fff0f1; color: #9e1c2b; }
          .credential { border: 2px solid #335cff; background: #f2f5ff; }
          .credential code { display: block; overflow-wrap: anywhere; margin: 12px 0; padding: 14px; border-radius: 8px; background: #172033; color: white; font-size: 1rem; }
          .grid { display: grid; grid-template-columns: minmax(0, 1.35fr) minmax(300px, .9fr); gap: 24px; margin-top: 24px; }
          section { background: white; border: 1px solid #e4e9f2; border-radius: 16px; padding: 26px; box-shadow: 0 8px 28px rgba(33, 54, 93, .05); }
          table { width: 100%; border-collapse: collapse; font-size: .92rem; }
          th, td { text-align: left; vertical-align: top; padding: 14px 10px; border-bottom: 1px solid #edf0f5; }
          th { color: #66748b; font-size: .72rem; letter-spacing: .07em; text-transform: uppercase; }
          .status { display: inline-block; border-radius: 999px; padding: 4px 9px; background: #e8f7ef; color: #17603a; font-size: .75rem; font-weight: 700; }
          .status.pending_first_login { background: #fff6dc; color: #8b6200; }
          .status.suspended, .status.disabled { background: #f1f2f5; color: #5d6676; }
          .status.draft { background: #fff6dc; color: #8b6200; }
          form { display: grid; gap: 13px; }
          label { display: grid; gap: 6px; font-size: .83rem; font-weight: 650; color: #334055; }
          input, select { box-sizing: border-box; width: 100%; border: 1px solid #cbd4e2; border-radius: 8px; padding: 10px 11px; font: inherit; }
          button { border: 0; border-radius: 8px; padding: 9px 12px; background: #335cff; color: white; font: inherit; font-weight: 700; cursor: pointer; }
          button.secondary { background: #e8edf7; color: #334055; } button.danger { background: #a91f32; }
          .inline { display: inline; } .actions { display: flex; gap: 8px; flex-wrap: wrap; } .muted { font-size: .84rem; }
          .signout { margin-top: 20px; color: #52627d; }
          @media (max-width: 840px) { .grid { grid-template-columns: 1fr; } table { display: block; overflow-x: auto; } }
        </style>
      </head>
      <body>
        <main>
          <div class="eyebrow">Administrator-provisioned local credentials</div>
          <h1>Account administration</h1>
          <p class="lead">Create a staff login using an email address. Chimwemwe generates one temporary password that must be replaced at first login. The email identifies the account; it does not grant a school role or permission.</p>
          #{notice}
          #{credential}
          <div class="grid">
            <section>
              <h2>Local staff accounts</h2>
              <table>
                <thead><tr><th>Staff record</th><th>Email</th><th>Status</th><th>Temporary expiry</th><th>Actions</th></tr></thead>
                <tbody>#{account_rows}</tbody>
              </table>
            </section>
            <section>
              <h2>Create an account</h2>
              <form method="post" action="/admin/accounts">
                <input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}">
                <label>Prepared staff record<select name="account[actor_id]">#{candidate_options}</select></label>
                <label>Username (email)<input type="email" name="account[email]" required maxlength="320" autocomplete="off" placeholder="educator@example.test"></label>
                <button type="submit">Create account and temporary password</button>
              </form>
              <p class="muted">The generated password is shown once and expires after 24 hours. Give it to the staff member through an appropriate private channel.</p>
            </section>
          </div>
          <div class="grid">
            <section>
              <h2>Future institutional sign-in connections</h2>
              <p class="muted">OIDC remains optional. It is not required for this initial local-account path.</p>
              <table>
                <thead><tr><th>Connection</th><th>Protocol</th><th>Issuer</th><th>Status</th><th>Change</th></tr></thead>
                <tbody>#{connection_rows}</tbody>
              </table>
            </section>
            <section>
              <h2>Add a future connection</h2>
              <form method="post" action="/admin/connections">
                <input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}">
                <label>Name<input name="connection[name]" required maxlength="120"></label>
                <label>Protocol<select name="connection[protocol]"><option value="oidc">OpenID Connect</option><option value="saml">SAML through a gateway</option></select></label>
                <label>Issuer URL<input name="connection[issuer_url]" required maxlength="500"></label>
                <label>Client ID<input name="connection[client_id]" required maxlength="500"></label>
                <label>Secret reference<input name="connection[secret_reference]" required maxlength="500"></label>
                <label>Routing domains<input name="connection[allowed_domains]" maxlength="1000"></label>
                <button type="submit">Save as draft</button>
              </form>
            </section>
          </div>
          <form class="signout" method="post" action="/sign-out"><input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}"><button class="secondary" type="submit">Sign out</button></form>
        </main>
      </body>
    </html>
    """
  end

  defp credential_html(nil), do: ""

  defp credential_html(%{account: account, temporary_password: temporary_password}) do
    """
    <section class="credential" role="status" aria-live="polite">
      <h2>Copy this temporary password now</h2>
      <p>Account: <strong>#{escape(account.email)}</strong></p>
      <code>#{escape(temporary_password)}</code>
      <p class="muted">This value will not be shown again. It expires at #{escape(format_time(account.temporary_password_expires_at))} and can only start the password-replacement flow.</p>
    </section>
    """
  end

  defp account_row(account, csrf_token) do
    candidate = Enum.find(Config.staff_candidates(), &(&1.actor_id == account.actor_id))
    staff_label = if candidate, do: candidate.label, else: "Bootstrap administrator"
    status = Atom.to_string(account.status)

    actions =
      if account.actor_id == Config.admin_actor_id() do
        "<span class=\"muted\">Bootstrap-managed</span>"
      else
        """
        <div class="actions">
          <form class="inline" method="post" action="/admin/accounts/#{escape(account.id)}/reissue"><input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}"><button class="secondary" type="submit">Issue new password</button></form>
          <form class="inline" method="post" action="/admin/accounts/#{escape(account.id)}/suspend"><input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}"><button class="danger" type="submit">Suspend</button></form>
        </div>
        """
      end

    """
    <tr>
      <td>#{escape(staff_label)}</td>
      <td>#{escape(account.email)}</td>
      <td><span class="status #{escape(status)}">#{escape(status_label(account.status))}</span></td>
      <td>#{escape(format_time(account.temporary_password_expires_at))}</td>
      <td>#{actions}</td>
    </tr>
    """
  end

  defp connection_row(connection, csrf_token) do
    status = Atom.to_string(connection.connection_status)
    action = if connection.connection_status == :active, do: "disable", else: "activate"
    label = if action == "disable", do: "Disable", else: "Activate"

    """
    <tr>
      <td><strong>#{escape(connection.name)}</strong></td>
      <td>#{escape(connection.protocol |> Atom.to_string() |> String.upcase())}</td>
      <td>#{escape(connection.issuer_url)}</td>
      <td><span class="status #{escape(status)}">#{escape(status)}</span></td>
      <td><form class="inline" method="post" action="/admin/connections/#{escape(connection.id)}/#{action}"><input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}"><button class="secondary" type="submit">#{label}</button></form></td>
    </tr>
    """
  end

  defp status_label(:pending_first_login), do: "First login required"
  defp status_label(:active), do: "Active"
  defp status_label(:suspended), do: "Suspended"

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M UTC")

  defp flash_html(conn) do
    flash = conn.assigns[:flash] || %{}

    case {Phoenix.Flash.get(flash, :info), Phoenix.Flash.get(flash, :error)} do
      {message, _} when is_binary(message) ->
        "<div class=\"notice\">#{escape(message)}</div>"

      {_, message} when is_binary(message) ->
        "<div class=\"notice error\">#{escape(message)}</div>"

      _none ->
        ""
    end
  end

  defp escape(value) do
    value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end
end
