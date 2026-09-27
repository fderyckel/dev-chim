defmodule Chimwemwe.AuthDemo.AdminController do
  @moduledoc false

  use Phoenix.Controller, formats: [:html]

  alias Chimwemwe.AuthDemo.Admin

  plug(:require_authenticated_account)

  def index(conn, _params) do
    case Admin.list(current_account(conn)) do
      {:ok, connections} ->
        render_page(conn, connections)

      _error ->
        conn
        |> put_flash(:error, "The institutional sign-in settings could not be loaded.")
        |> render_page([])
    end
  end

  def create(conn, %{"connection" => attributes}) do
    case Admin.register(current_account(conn), attributes) do
      {:ok, _connection} ->
        conn
        |> put_flash(:info, "The SSO connection was saved as a draft.")
        |> redirect(to: "/")

      {:error, _error} ->
        conn
        |> put_flash(:error, "The connection could not be saved. Check the required fields.")
        |> redirect(to: "/")
    end
  end

  def create(conn, _params), do: redirect(conn, to: "/")

  def activate(conn, %{"id" => connection_id}) do
    transition(
      conn,
      Admin.activate(current_account(conn), connection_id),
      "The SSO connection is active."
    )
  end

  def disable(conn, %{"id" => connection_id}) do
    transition(
      conn,
      Admin.disable(current_account(conn), connection_id),
      "The SSO connection is disabled."
    )
  end

  defp transition(conn, {:ok, _connection}, message) do
    conn
    |> put_flash(:info, message)
    |> redirect(to: "/")
  end

  defp transition(conn, {:error, _error}, _message) do
    conn
    |> put_flash(:error, "That SSO connection could not be changed.")
    |> redirect(to: "/")
  end

  defp require_authenticated_account(conn, _options) do
    if current_account(conn) do
      conn
    else
      conn
      |> redirect(to: "/sign-in")
      |> halt()
    end
  end

  defp current_account(conn), do: conn.assigns[:current_account]

  defp render_page(conn, connections) do
    html(conn, page_html(conn, connections))
  end

  defp page_html(conn, connections) do
    csrf_token = Plug.CSRFProtection.get_csrf_token()
    notice = flash_html(conn)
    connection_rows = Enum.map_join(connections, "", &connection_row(&1, csrf_token))

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Authentication administration</title>
        <style>
          :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #172033; background: #f5f7fb; }
          body { margin: 0; }
          main { max-width: 1120px; margin: 0 auto; padding: 48px 24px 72px; }
          h1 { margin: 0; font-size: clamp(2rem, 4vw, 3rem); letter-spacing: -0.04em; }
          h2 { font-size: 1.25rem; margin: 0 0 18px; }
          p { line-height: 1.55; color: #55627a; }
          .eyebrow { color: #4361ee; font-weight: 700; font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; }
          .lead { max-width: 760px; font-size: 1.06rem; }
          .notice { padding: 12px 16px; margin: 24px 0; border-radius: 10px; background: #eef3ff; color: #173b8f; }
          .notice.error { background: #fff0f1; color: #9e1c2b; }
          .grid { display: grid; grid-template-columns: minmax(0, 1.35fr) minmax(300px, .9fr); gap: 24px; margin-top: 32px; }
          section { background: white; border: 1px solid #e4e9f2; border-radius: 16px; padding: 26px; box-shadow: 0 8px 28px rgba(33, 54, 93, .05); }
          table { width: 100%; border-collapse: collapse; font-size: .92rem; }
          th, td { text-align: left; vertical-align: top; padding: 14px 10px; border-bottom: 1px solid #edf0f5; }
          th { color: #66748b; font-size: .72rem; letter-spacing: .07em; text-transform: uppercase; }
          .status { display: inline-block; border-radius: 999px; padding: 4px 9px; background: #eef2ff; color: #3446b5; font-size: .75rem; font-weight: 700; }
          .status.disabled { background: #f1f2f5; color: #5d6676; }
          .status.draft { background: #fff6dc; color: #8b6200; }
          form { display: grid; gap: 13px; }
          label { display: grid; gap: 6px; font-size: .83rem; font-weight: 650; color: #334055; }
          input, select { box-sizing: border-box; width: 100%; border: 1px solid #cbd4e2; border-radius: 8px; padding: 10px 11px; font: inherit; }
          button { border: 0; border-radius: 8px; padding: 9px 12px; background: #335cff; color: white; font: inherit; font-weight: 700; cursor: pointer; }
          button.secondary { background: #e8edf7; color: #334055; }
          .inline { display: inline; }
          .actions { display: flex; gap: 8px; flex-wrap: wrap; }
          .muted { font-size: .84rem; }
          .signout { margin-top: 20px; color: #52627d; }
          @media (max-width: 840px) { .grid { grid-template-columns: 1fr; } table { display: block; overflow-x: auto; } }
        </style>
      </head>
      <body>
        <main>
          <div class="eyebrow">Local database-backed proof</div>
          <h1>Authentication administration</h1>
          <p class="lead">Set up how this institution signs people in. These records are stored in PostgreSQL. The service accepts a reference to a deployment secret; it never stores or displays the secret, a certificate, access token, or refresh token.</p>
          #{notice}
          <div class="grid">
            <section>
              <h2>Institution sign-in connections</h2>
              <p class="muted">Use one provider-neutral contract for Microsoft Entra ID, Google Workspace, or another OIDC provider. Hybrid/on-premises Active Directory connects through Entra synchronization or a qualified AD FS/SAML gateway; SAML assertions are not processed directly by this proof.</p>
              <table>
                <thead><tr><th>Connection</th><th>Protocol</th><th>Issuer</th><th>Client ID</th><th>Routing domains</th><th>Status</th><th>Change</th></tr></thead>
                <tbody>#{connection_rows}</tbody>
              </table>
            </section>
            <section>
              <h2>Add a connection</h2>
              <form method="post" action="/connections">
                <input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}">
                <label>Name<input name="connection[name]" required maxlength="120" placeholder="Northstar Entra OIDC"></label>
                <label>Protocol<select name="connection[protocol]"><option value="oidc">OpenID Connect (direct or brokered)</option><option value="saml">SAML through a qualified gateway</option></select></label>
                <label>Issuer or entity URL<input name="connection[issuer_url]" required maxlength="500" placeholder="https://identity.example.test/issuer"></label>
                <label>Client or audience ID<input name="connection[client_id]" required maxlength="500" placeholder="Registered application identifier"></label>
                <label>Secret reference<input name="connection[secret_reference]" required maxlength="500" placeholder="identity/northstar/sign-in-secret"></label>
                <label>Routing email domains<input name="connection[allowed_domains]" maxlength="1000" placeholder="northstar-school.test, northstar.edu"></label>
                <button type="submit">Save as draft</button>
              </form>
              <p class="muted">An active connection still needs a verified redirect URI, issuer, client ID, secret reference, and domain policy before it can be used for sign-in.</p>
            </section>
          </div>
          <form class="signout" method="get" action="/sign-out"><button class="secondary" type="submit">Sign out</button></form>
        </main>
      </body>
    </html>
    """
  end

  defp connection_row(connection, csrf_token) do
    status = Atom.to_string(connection.connection_status)
    status_class = "status #{escape(status)}"
    action = if connection.connection_status == :active, do: "disable", else: "activate"
    label = if action == "disable", do: "Disable", else: "Activate"

    """
    <tr>
      <td><strong>#{escape(connection.name)}</strong><br><span class="muted">Secret ref: #{escape(connection.secret_reference)}</span></td>
      <td>#{escape(connection.protocol |> Atom.to_string() |> String.upcase())}</td>
      <td>#{escape(connection.issuer_url)}</td>
      <td>#{escape(connection.client_id)}</td>
      <td>#{escape(connection.allowed_domains)}</td>
      <td><span class="#{status_class}">#{escape(status)}</span></td>
      <td><form class="inline" method="post" action="/connections/#{escape(connection.id)}/#{action}"><input type="hidden" name="_csrf_token" value="#{escape(csrf_token)}"><button class="secondary" type="submit">#{label}</button></form></td>
    </tr>
    """
  end

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
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
