defmodule Chimwemwe.PublicApi.StaffLoginController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]

  alias Chimwemwe.Identity.{
    Error,
    LocalCredentials,
    PublicSessionAdapter,
    StaffDirectory,
    VerifiedLocalCredential
  }

  alias Chimwemwe.Platform.Persistence
  alias Chimwemwe.PublicApi.{ErrorResponse, StaffConfig}
  alias Chimwemwe.Repo
  @cookie "__Host-chimwemwe-staff-login"
  @salt "staff-restricted-login-v1"
  @options [secure: true, http_only: true, same_site: "Lax", path: "/", max_age: 600]

  def show(conn, params) when map_size(params) == 0 do
    conn = fetch_cookies(conn)
    state = current_state(conn) || anonymous("en")
    respond(conn, state)
  end

  def show(conn, _params), do: denied(conn)

  def create(conn, params) do
    with true <- exact?(params, ~w(email password csrf_token locale)),
         true <- params["locale"] in ["en", "en-MW", "fr"],
         {:ok, state} <- accepted_state(conn, params["csrf_token"]),
         true <- state.stage == :anonymous do
      case end_previous_session(conn, params["locale"]) do
        {:ok, cleared_conn} ->
          authenticate(cleared_conn, params["email"], params["password"], params["locale"])

        _unconfirmed ->
          denied(conn)
      end
    else
      _ -> denied(conn)
    end
  end

  def replace_password(conn, params) do
    with true <- exact?(params, ~w(password confirmation csrf_token)),
         {:ok, %{stage: :first_login} = state} <- accepted_state(conn, params["csrf_token"]),
         {:ok, _account} <-
           credentials(conn, fn ->
             LocalCredentials.complete_first_login(
               state.account_id,
               state.lock_version,
               params["password"],
               params["confirmation"]
             )
           end) do
      respond(conn, anonymous(state.locale))
    else
      _ -> denied(conn)
    end
  end

  def cancel(conn, params) do
    with true <- exact?(params, ~w(csrf_token)),
         {:ok, state} <- accepted_state(conn, params["csrf_token"]) do
      respond(conn, anonymous(state.locale))
    else
      _ -> denied(conn)
    end
  end

  defp authenticate(conn, email, password, locale) do
    case credentials(conn, fn -> VerifiedLocalCredential.authenticate(email, password) end) do
      {:ok, proof} -> establish_session(conn, proof, locale)
      {:first_login, account} -> first_login(conn, account, locale)
      _ -> denied(conn)
    end
  end

  # A credential attempt replaces the browser's identity context. In particular,
  # restricted first-login state must never coexist with an earlier administrator
  # session. An unconfirmed logout cannot be treated as a successful switch.
  defp end_previous_session(conn, locale) do
    conn = fetch_cookies(conn)

    case conn.req_cookies[PublicSessionAdapter.cookie_name()] do
      nil ->
        {:ok, clear_application_cookie(conn)}

      cookie when is_binary(cookie) ->
        end_existing_session(conn, cookie, locale)

      _invalid ->
        {:error, :unconfirmed_logout}
    end
  end

  defp end_existing_session(conn, cookie, locale) do
    runtime = conn.assigns.staff_config.runtime

    case PublicSessionAdapter.authenticate(
           runtime,
           cookie,
           :session_logout,
           locale,
           Ecto.UUID.generate()
         ) do
      {:ok, request} ->
        with {:ok, :logged_out} <- PublicSessionAdapter.logout(runtime, request),
             do: {:ok, clear_application_cookie(conn)}

      {:error, %Error{code: code}}
      when code in [:forbidden, :invalid_input, :expired, :not_found] ->
        {:ok, clear_application_cookie(conn)}

      _unconfirmed ->
        {:error, :unconfirmed_logout}
    end
  end

  defp clear_application_cookie(conn),
    do:
      delete_resp_cookie(
        conn,
        PublicSessionAdapter.cookie_name(),
        PublicSessionAdapter.cookie_options()
      )

  defp first_login(conn, account, locale) do
    respond(conn, %{
      stage: :first_login,
      account_id: account.id,
      lock_version: account.lock_version,
      expires_at: System.system_time(:second) + 600,
      locale: locale,
      csrf_token: random()
    })
  end

  defp establish_session(conn, proof, locale) do
    config = conn.assigns.staff_config

    with {:ok, context} <-
           StaffConfig.context(config, proof.actor_id, locale, "staff.local.sign_in"),
         {:ok, {:ok, target}} <-
           Persistence.with_writer(config.runtime, context, fn ->
             target(config.tenant_id, proof.actor_id, locale)
           end),
         {:ok, presentation} <- StaffDirectory.preferences(config.runtime, context),
         {:ok, cookie} <-
           PublicSessionAdapter.complete_local_sign_in(config.runtime, proof, target) do
      next_path =
        cond do
          presentation.navigation.accounts -> "/accounts"
          presentation.navigation.classroom -> "/classroom"
          true -> "/my-preferences"
        end

      conn
      |> put_resp_cookie(
        PublicSessionAdapter.cookie_name(),
        cookie,
        PublicSessionAdapter.cookie_options()
      )
      |> delete_resp_cookie(@cookie, @options)
      |> json(%{
        data: %{stage: "authenticated", csrf_token: "", locale: locale, next_path: next_path}
      })
    else
      _ -> denied(conn)
    end
  end

  defp target(tenant, actor, locale) do
    case Repo.query(
           "SELECT membership_id FROM identity_staff_directory_entries WHERE tenant_id=$1 AND actor_id=$2 AND enabled=true",
           [Ecto.UUID.dump!(tenant), Ecto.UUID.dump!(actor)]
         ) do
      {:ok, %{rows: [[membership]]}} ->
        {:ok, %{tenant_id: tenant, membership_id: Ecto.UUID.load!(membership), locale: locale}}

      _ ->
        {:error, :denied}
    end
  end

  # Startup-owned writer routing for the global credential lookup conveys no tenant authority.
  defp credentials(conn, operation) do
    config = conn.assigns.staff_config

    with {:ok, context} <-
           StaffConfig.context(config, config.bootstrap_actor_id, "en", "staff.credential.verify"),
         {:ok, result} <- Persistence.with_writer(config.runtime, context, operation) do
      result
    else
      _ -> {:error, :denied}
    end
  end

  defp respond(conn, state) do
    case key() do
      {:ok, key} ->
        conn
        |> put_resp_cookie(@cookie, Phoenix.Token.encrypt(key, @salt, state), @options)
        |> json(%{
          data: %{
            stage: Atom.to_string(state.stage),
            csrf_token: state.csrf_token,
            locale: state.locale,
            next_path:
              if(state.stage == :first_login, do: "/first-login/password", else: "/sign-in")
          }
        })

      _unavailable ->
        denied(conn)
    end
  end

  defp accepted_state(conn, csrf) when is_binary(csrf) do
    conn = fetch_cookies(conn)

    with [origin] <- get_req_header(conn, "origin"),
         true <- origin == conn.assigns.staff_config.origin,
         [type] <- get_req_header(conn, "content-type"),
         true <- String.starts_with?(type, "application/json"),
         %{csrf_token: expected} = state <- current_state(conn),
         true <- Plug.Crypto.secure_compare(csrf, expected) do
      {:ok, state}
    else
      _ -> {:error, :denied}
    end
  end

  defp accepted_state(_conn, _csrf), do: {:error, :denied}

  defp current_state(conn) do
    with {:ok, key} <- key(),
         value when is_binary(value) <- conn.req_cookies[@cookie],
         {:ok, %{stage: stage, csrf_token: csrf, locale: locale} = state} <-
           Phoenix.Token.decrypt(key, @salt, value, max_age: 600),
         true <- stage in [:anonymous, :first_login],
         true <- is_binary(csrf) and locale in ["en", "en-MW", "fr"] do
      if stage == :anonymous or
           (is_integer(state[:expires_at]) and state.expires_at > System.system_time(:second)),
         do: state,
         else: nil
    else
      _ -> nil
    end
  end

  defp key do
    case Application.get_env(:chimwemwe_core, :public_session_cookie_keys) do
      [key | _] when is_binary(key) and byte_size(key) >= 32 -> {:ok, key}
      _ -> {:error, :unavailable}
    end
  end

  defp anonymous(locale), do: %{stage: :anonymous, csrf_token: random(), locale: locale}
  defp random, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  defp exact?(params, keys), do: is_map(params) and Enum.sort(Map.keys(params)) == Enum.sort(keys)

  defp denied(conn),
    do:
      ErrorResponse.send(
        conn,
        401,
        "invalid_login",
        "We couldn’t sign you in. Check your details or contact your account administrator."
      )
end
