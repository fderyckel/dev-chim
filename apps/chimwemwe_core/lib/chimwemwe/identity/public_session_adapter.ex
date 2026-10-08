defmodule Chimwemwe.Identity.PublicSessionAdapter do
  @moduledoc """
  Provider-neutral callback, opaque-cookie, and current-session adapter.

  Decrypted cookie and sign-in intent values are candidate locators only. The
  startup-owned placement registry and authoritative writer must re-establish
  the route, actor, membership, session, and optional support grant before use.
  """

  alias Chimwemwe.Identity.{
    CallbackVerifier,
    Error,
    PublicCallbackResult,
    PublicRequestSession,
    SessionFoundation,
    SessionResult,
    SessionView,
    SupportFoundation,
    SupportGrantResult,
    VerifiedExternalIdentity
  }

  alias Chimwemwe.Platform.{
    ExecutionContext,
    PersistenceRuntime,
    PlacementRegistry,
    TrustedActor
  }

  alias Ecto.UUID

  @behaviour_salt "chimwemwe-public-session-v1"
  @intent_salt "chimwemwe-public-sign-in-intent-v1"
  @session_max_age 12 * 60 * 60
  @intent_max_age 5 * 60
  @cookie_name "__Host-chimwemwe-session"
  @intent_keys [
    :actor_id,
    :causation_id,
    :connection_id,
    :external_identity_link_id,
    :idempotency_key,
    :locale,
    :membership_id,
    :redirect_to,
    :tenant_id
  ]
  @sign_in_keys [
    :actor_id,
    :connection_id,
    :external_identity_link_id,
    :locale,
    :membership_id,
    :redirect_to,
    :tenant_id
  ]
  @oidc_keys [:code_verifier, :configuration_version, :nonce, :redirect_uri]
  @callback_keys [:code, :state]
  @purpose_names %{
    calendar_manage: "public.calendar.manage",
    calendar_read: "public.calendar.read",
    classroom_prepare: "public.classroom.prepare",
    classroom_read: "public.classroom.read",
    classroom_correct: "public.classroom.correct",
    classroom_submit: "public.classroom.submit",
    session_start: "public.session.start",
    session_read: "public.session.read",
    session_logout: "public.session.logout",
    support_elevate: "public.support.elevate",
    support_use: "public.support.use"
  }
  @locales MapSet.new(["en", "en-MW", "fr"])

  @doc "Creates a short-lived encrypted state value from server-owned sign-in intent."
  @spec issue_sign_in_intent(map()) :: {:ok, String.t()} | {:error, Error.t()}
  def issue_sign_in_intent(input) do
    with {:ok, intent} <- normalize_intent(input),
         {:ok, current, _previous} <- keyring() do
      {:ok, Phoenix.Token.encrypt(current, @intent_salt, intent, max_age: @intent_max_age)}
    end
  end

  @doc "Starts one startup-selected, pre-linked OIDC sign-in attempt."
  @spec start_oidc_sign_in(Supervisor.supervisor(), module(), map(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def start_oidc_sign_in(runtime, verifier, input, redirect_uri) do
    with true <- oidc_verifier?(verifier),
         {:ok, intent} <- normalize_sign_in(input),
         {:ok, redirect_uri} <- callback_redirect(redirect_uri),
         {:ok, context} <-
           context(runtime, intent, "preauthentication", :session_start,
             correlation_id: UUID.generate(),
             locale: intent.locale
           ),
         {:ok, connection} <- sign_in_connection(runtime, context, intent),
         oidc <- oidc_context(connection, redirect_uri),
         {:ok, state} <- issue_sign_in_intent(Map.put(intent, :oidc, oidc)),
         {:ok, url} <- verifier.authorization_url(state, connection, oidc),
         {:ok, url} <- authorization_redirect(url) do
      {:ok, url}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      {:error, error} -> {:error, error}
      _invalid -> error(:retryable_dependency)
    end
  end

  @doc "Completes one qualified callback and returns an encrypted application-session cookie."
  @spec complete_callback(Supervisor.supervisor(), module(), map()) ::
          {:ok, PublicCallbackResult.t()} | {:error, term()}
  def complete_callback(runtime, verifier, input) do
    with true <- callback_verifier?(verifier),
         {:ok, callback} <- exact_input(input, @callback_keys),
         {:ok, intent} <- decrypt(callback.state, @intent_salt, @intent_max_age),
         {:ok, intent} <- normalize_intent(intent),
         {:ok, proof} <- verify_callback(runtime, verifier, callback, intent),
         :ok <- VerifiedExternalIdentity.validate(proof),
         :ok <- ensure(proof.connection_id == intent.connection_id, :forbidden),
         {:ok, context} <-
           context(runtime, intent, proof.assurance, :session_read,
             correlation_id: UUID.generate(),
             locale: intent.locale
           ),
         {:ok, session} <-
           SessionFoundation.create(runtime, context, %{
             external_identity_link_id: intent.external_identity_link_id,
             membership_id: intent.membership_id,
             proof: proof,
             idempotency_key: intent.idempotency_key,
             causation_id: intent.causation_id
           }),
         {:ok, cookie_value} <- session_cookie(session, nil),
         {:ok, session_view} <- view(session) do
      {:ok,
       %PublicCallbackResult{
         cookie_value: cookie_value,
         redirect_to: intent.redirect_to,
         session: session_view
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      {:error, error} -> {:error, error}
      _invalid -> error(:forbidden)
    end
  end

  @doc "Authenticates one opaque cookie and establishes current writer-backed request context."
  @spec authenticate(Supervisor.supervisor(), String.t(), atom(), String.t(), String.t()) ::
          {:ok, PublicRequestSession.t()} | {:error, term()}
  def authenticate(runtime, cookie_value, purpose, locale, correlation_id) do
    with {:ok, locale} <- locale(locale),
         {:ok, envelope} <- decrypt(cookie_value, @behaviour_salt, @session_max_age),
         {:ok, envelope} <- normalize_envelope(envelope),
         {:ok, context} <-
           context(runtime, envelope, envelope.assurance, purpose,
             correlation_id: correlation_id,
             locale: locale
           ),
         {:ok, session} <-
           SessionFoundation.validate(runtime, context, %{token: envelope.session_token}),
         :ok <- envelope_matches(envelope, session),
         {:ok, support} <- validate_support(runtime, context, envelope) do
      {:ok,
       %PublicRequestSession{
         context: context,
         csrf_token: envelope.csrf_token,
         session: session,
         session_token: envelope.session_token,
         support: support
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Invalidates the authoritative session. Clearing the cookie alone is not logout."
  @spec logout(Supervisor.supervisor(), PublicRequestSession.t()) ::
          {:ok, :logged_out} | {:error, term()}
  def logout(runtime, %PublicRequestSession{} = request) do
    SessionFoundation.logout(runtime, request.context, %{
      token: request.session_token,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    })
  end

  @doc "Activates one approved support grant and returns a replacement elevated cookie."
  @spec elevate_support(Supervisor.supervisor(), PublicRequestSession.t(), String.t()) ::
          {:ok, String.t(), SupportGrantResult.t()} | {:error, term()}
  def elevate_support(runtime, %PublicRequestSession{support: nil} = request, grant_id) do
    with {:ok, grant_id} <- uuid(grant_id),
         {:ok, grant} <-
           SupportFoundation.activate(runtime, request.context, %{
             grant_id: grant_id,
             session_token: request.session_token,
             idempotency_key: UUID.generate(),
             causation_id: UUID.generate()
           }),
         {:ok, cookie_value} <-
           session_cookie(
             request.session,
             %{
               grant_id: grant.id,
               purpose: grant.purpose,
               expires_at: DateTime.to_iso8601(grant.expires_at)
             },
             request.session_token,
             request.csrf_token
           ) do
      {:ok, cookie_value, grant}
    end
  end

  def elevate_support(_runtime, %PublicRequestSession{}, _grant_id), do: error(:conflict)

  @doc "Rechecks and records one interactive elevated support use."
  def use_support(runtime, %PublicRequestSession{support: support} = request, capability)
      when not is_nil(support) do
    if is_binary(capability) and capability in support.capability_scope do
      SupportFoundation.use_grant(runtime, request.context, %{
        grant_id: support.grant_id,
        session_token: request.session_token,
        capability: capability,
        purpose: support.purpose,
        mode: :interactive,
        idempotency_key: UUID.generate(),
        causation_id: UUID.generate()
      })
    else
      error(:forbidden)
    end
  end

  def use_support(_runtime, %PublicRequestSession{}, _capability), do: error(:forbidden)

  @doc false
  def cookie_name, do: @cookie_name

  @doc false
  def cookie_options do
    [
      secure: true,
      http_only: true,
      same_site: "Lax",
      path: "/",
      max_age: @session_max_age
    ]
  end

  defp validate_support(_runtime, _context, %{support: nil}), do: {:ok, nil}

  defp validate_support(runtime, context, envelope) do
    SupportFoundation.validate_active(runtime, context, %{
      grant_id: envelope.support.grant_id,
      session_token: envelope.session_token,
      purpose: envelope.support.purpose
    })
  end

  defp session_cookie(%SessionResult{} = session, support) do
    session_cookie(session, support, session.token, random_token())
  end

  defp session_cookie(session, support, session_token, csrf_token) do
    with {:ok, current, _previous} <- keyring() do
      envelope = %{
        version: 1,
        session_id: session.id,
        session_token: session_token,
        tenant_id: session.tenant_id,
        actor_id: session.actor_id,
        membership_id: session.membership_id,
        assurance: session.assurance,
        csrf_token: csrf_token,
        support: support
      }

      {:ok, Phoenix.Token.encrypt(current, @behaviour_salt, envelope, max_age: @session_max_age)}
    end
  end

  defp decrypt(value, salt, max_age) when is_binary(value) do
    with {:ok, current, previous} <- keyring() do
      decrypt_with_keys([current | previous], salt, value, max_age)
    end
  end

  defp decrypt(_value, _salt, _max_age), do: error(:forbidden)

  defp decrypt_with_keys(keys, salt, value, max_age) do
    result =
      Enum.reduce_while(keys, {:error, :invalid}, fn key, _failure ->
        case Phoenix.Token.decrypt(key, salt, value, max_age: max_age) do
          {:ok, decoded} -> {:halt, {:ok, decoded}}
          {:error, reason} -> {:cont, {:error, reason}}
        end
      end)

    case result do
      {:ok, decoded} -> {:ok, decoded}
      {:error, :expired} -> error(:expired)
      _invalid -> error(:forbidden)
    end
  end

  defp keyring do
    case Application.get_env(:chimwemwe_core, :public_session_cookie_keys) do
      [current | previous]
      when is_binary(current) and byte_size(current) >= 32 and length(previous) <= 2 ->
        if Enum.all?(previous, &(is_binary(&1) and byte_size(&1) >= 32)) and
             Enum.uniq([current | previous]) == [current | previous] do
          {:ok, current, previous}
        else
          error(:retryable_dependency)
        end

      _missing_or_invalid ->
        error(:retryable_dependency)
    end
  end

  defp context(runtime, candidate, assurance, purpose, metadata) do
    with {:ok, registry} <- PersistenceRuntime.child_pid(runtime, PlacementRegistry),
         {:ok, placement} <- PlacementRegistry.current_placement(registry, candidate.tenant_id),
         {:ok, actor} <-
           TrustedActor.establish(
             actor_id: candidate.actor_id,
             tenant_id: candidate.tenant_id,
             assurance: assurance
           ),
         {:ok, purpose_name} <- purpose(purpose) do
      ExecutionContext.establish(actor, placement,
        correlation_id: Keyword.fetch!(metadata, :correlation_id),
        purpose: purpose_name,
        locale: Keyword.fetch!(metadata, :locale)
      )
    end
  end

  defp verify_callback(_runtime, verifier, callback, %{oidc: nil} = intent) do
    verifier.verify_code(callback.code, intent.connection_id)
  end

  defp verify_callback(runtime, verifier, callback, %{oidc: oidc} = intent) do
    with true <- oidc_verifier?(verifier),
         {:ok, context} <-
           context(runtime, intent, "preauthentication", :session_start,
             correlation_id: UUID.generate(),
             locale: intent.locale
           ),
         {:ok, connection} <- sign_in_connection(runtime, context, intent),
         :ok <- ensure(connection.configuration_version == oidc.configuration_version, :forbidden) do
      verifier.verify_code(callback.code, intent.connection_id, %{
        connection: connection,
        oidc: Map.put(oidc, :state, callback.state)
      })
    else
      false -> error(:forbidden)
      {:error, _error} = error_result -> error_result
    end
  end

  defp sign_in_connection(runtime, context, intent) do
    SessionFoundation.authorize_sign_in(runtime, context, %{
      connection_id: intent.connection_id,
      external_identity_link_id: intent.external_identity_link_id,
      membership_id: intent.membership_id
    })
  end

  defp normalize_sign_in(input) do
    with {:ok, input} <- exact_input(input, @sign_in_keys) do
      input
      |> Map.merge(%{
        causation_id: UUID.generate(),
        idempotency_key: UUID.generate()
      })
      |> normalize_intent()
    end
  end

  defp normalize_intent(input) do
    with {:ok, input, oidc} <- intent_input(input),
         {:ok, actor_id} <- uuid(input.actor_id),
         {:ok, tenant_id} <- uuid(input.tenant_id),
         {:ok, membership_id} <- uuid(input.membership_id),
         {:ok, link_id} <- uuid(input.external_identity_link_id),
         {:ok, connection_id} <- uuid(input.connection_id),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id),
         {:ok, locale} <- locale(input.locale),
         {:ok, redirect_to} <- redirect(input.redirect_to),
         {:ok, oidc} <- normalize_oidc(oidc) do
      {:ok,
       %{
         actor_id: actor_id,
         tenant_id: tenant_id,
         membership_id: membership_id,
         external_identity_link_id: link_id,
         connection_id: connection_id,
         idempotency_key: idempotency_key,
         causation_id: causation_id,
         locale: locale,
         redirect_to: redirect_to,
         oidc: oidc
       }}
    end
  end

  defp intent_input(input) do
    case exact_input(input, @intent_keys) do
      {:ok, normalized} ->
        {:ok, normalized, nil}

      {:error, _error} ->
        with {:ok, normalized} <- exact_input(input, @intent_keys ++ [:oidc]) do
          {:ok, Map.delete(normalized, :oidc), normalized.oidc}
        end
    end
  end

  defp normalize_oidc(nil), do: {:ok, nil}

  defp normalize_oidc(input) do
    with {:ok, input} <- exact_input(input, @oidc_keys),
         {:ok, code_verifier} <- text(input.code_verifier, 200),
         true <- byte_size(code_verifier) >= 43,
         true <- is_integer(input.configuration_version) and input.configuration_version > 0,
         {:ok, nonce} <- text(input.nonce, 500),
         true <- byte_size(nonce) >= 32,
         {:ok, redirect_uri} <- callback_redirect(input.redirect_uri) do
      {:ok,
       %{
         code_verifier: code_verifier,
         configuration_version: input.configuration_version,
         nonce: nonce,
         redirect_uri: redirect_uri
       }}
    else
      {:error, _error} = error_result -> error_result
      _invalid -> error(:forbidden)
    end
  end

  defp normalize_envelope(input) when is_map(input) do
    keys = [
      :actor_id,
      :assurance,
      :csrf_token,
      :membership_id,
      :session_id,
      :session_token,
      :support,
      :tenant_id,
      :version
    ]

    with {:ok, input} <- exact_input(input, keys),
         true <- input.version == 1,
         {:ok, actor_id} <- uuid(input.actor_id),
         {:ok, tenant_id} <- uuid(input.tenant_id),
         {:ok, membership_id} <- uuid(input.membership_id),
         {:ok, session_id} <- uuid(input.session_id),
         {:ok, assurance} <- text(input.assurance, 120),
         {:ok, session_token} <- text(input.session_token, 500),
         {:ok, csrf_token} <- text(input.csrf_token, 200),
         {:ok, support} <- normalize_support(input.support) do
      {:ok,
       %{
         actor_id: actor_id,
         tenant_id: tenant_id,
         membership_id: membership_id,
         session_id: session_id,
         assurance: assurance,
         session_token: session_token,
         csrf_token: csrf_token,
         support: support,
         locale: "en"
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:forbidden)
    end
  end

  defp normalize_envelope(_input), do: error(:forbidden)

  defp normalize_support(nil), do: {:ok, nil}

  defp normalize_support(input) do
    with {:ok, input} <- exact_input(input, [:expires_at, :grant_id, :purpose]),
         {:ok, grant_id} <- uuid(input.grant_id),
         {:ok, purpose} <- text(input.purpose, 500),
         {:ok, expires_at, 0} <- DateTime.from_iso8601(input.expires_at) do
      {:ok, %{grant_id: grant_id, purpose: purpose, expires_at: expires_at}}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:forbidden)
    end
  end

  defp envelope_matches(envelope, %SessionView{} = session) do
    ensure(
      envelope.session_id == session.id and envelope.tenant_id == session.tenant_id and
        envelope.actor_id == session.actor_id and envelope.membership_id == session.membership_id and
        envelope.assurance == session.assurance,
      :forbidden
    )
  end

  defp view(%SessionResult{} = session) do
    {:ok,
     %SessionView{
       id: session.id,
       tenant_id: session.tenant_id,
       actor_id: session.actor_id,
       membership_id: session.membership_id,
       assurance: session.assurance,
       assurance_at: session.assurance_at,
       idle_expires_at: session.idle_expires_at,
       absolute_expires_at: session.absolute_expires_at,
       lock_version: session.lock_version
     }}
  end

  defp callback_verifier?(verifier) when is_atom(verifier) do
    function_exported?(verifier, :verify_code, 2) and
      CallbackVerifier in (verifier.module_info(:attributes)[:behaviour] || [])
  end

  defp callback_verifier?(_verifier), do: false

  defp oidc_verifier?(verifier) do
    callback_verifier?(verifier) and function_exported?(verifier, :authorization_url, 3) and
      function_exported?(verifier, :verify_code, 3)
  end

  defp purpose(value) when is_atom(value) do
    case Map.fetch(@purpose_names, value) do
      {:ok, name} -> {:ok, name}
      :error -> error(:invalid_input)
    end
  end

  defp purpose(_value), do: error(:invalid_input)

  defp locale(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.replace("_", "-")
    if MapSet.member?(@locales, normalized), do: {:ok, normalized}, else: error(:invalid_input)
  end

  defp locale(_value), do: error(:invalid_input)

  defp redirect(value) when is_binary(value) do
    valid? =
      String.starts_with?(value, "/") and not String.starts_with?(value, "//") and
        not String.contains?(value, ["\\", "\r", "\n"]) and byte_size(value) <= 500

    if valid?, do: {:ok, value}, else: error(:invalid_input)
  end

  defp redirect(_value), do: error(:invalid_input)

  defp callback_redirect(value) when is_binary(value) do
    with {:ok, uri} <- URI.new(value),
         true <-
           uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and
             uri.path == "/auth/callback" and is_nil(uri.query) and is_nil(uri.fragment) and
             is_nil(uri.userinfo) do
      {:ok, URI.to_string(uri)}
    else
      _invalid -> error(:invalid_input)
    end
  end

  defp callback_redirect(_value), do: error(:invalid_input)

  defp authorization_redirect(value) when is_binary(value) and byte_size(value) <= 16_384 do
    with {:ok, uri} <- URI.new(value),
         true <-
           uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and
             is_nil(uri.userinfo) and is_nil(uri.fragment) do
      {:ok, URI.to_string(uri)}
    else
      _invalid -> error(:retryable_dependency)
    end
  end

  defp authorization_redirect(_value), do: error(:retryable_dependency)

  defp oidc_context(connection, redirect_uri) do
    %{
      code_verifier: random_token(96),
      configuration_version: connection.configuration_version,
      nonce: random_token(32),
      redirect_uri: redirect_uri
    }
  end

  defp exact_input(input, keys) when is_map(input) and not is_struct(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      normalized_key = normalize_key(key, keys)

      if normalized_key && not Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        {:halt, error(:invalid_input)}
      end
    end)
    |> case do
      {:ok, normalized} when map_size(normalized) == length(keys) -> {:ok, normalized}
      {:ok, _missing} -> error(:invalid_input)
      {:error, _error} = error_result -> error_result
    end
  end

  defp exact_input(_input, _keys), do: error(:invalid_input)
  defp normalize_key(key, keys) when is_atom(key), do: if(key in keys, do: key)

  defp normalize_key(key, keys) when is_binary(key),
    do: Enum.find(keys, &(Atom.to_string(&1) == key))

  defp normalize_key(_key, _keys), do: nil

  defp text(value, maximum) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed != "" and byte_size(trimmed) <= maximum,
      do: {:ok, trimmed},
      else: error(:forbidden)
  end

  defp text(_value, _maximum), do: error(:forbidden)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> error(:invalid_input)
    end
  end

  defp random_token(length \\ 32),
    do: length |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)
  defp error(code), do: {:error, %Error{code: code}}
end
