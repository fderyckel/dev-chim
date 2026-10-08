defmodule Chimwemwe.Identity.OidcCallbackVerifier do
  @moduledoc """
  Selected-connection OIDC authorization-code verifier for ADR 0042.

  The authoritative connection record supplies issuer, client identifier,
  secret reference, assurance mapping and configuration version. Provider
  tokens and all profile claims are discarded after normalized proof.
  """

  @behaviour Chimwemwe.Identity.CallbackVerifier

  alias Assent.{
    HTTPAdapter,
    InvalidResponseError,
    ServerUnreachableError,
    UnexpectedResponseError
  }

  alias Assent.HTTPAdapter.HTTPResponse
  alias Assent.Strategy.OIDC
  alias Chimwemwe.Identity.{EnvironmentOidcSecretResolver, Error, VerifiedExternalIdentity}

  @maximum_code_bytes 4096
  @maximum_authentication_age 10 * 60
  @maximum_clock_skew 60
  @verifier_keys [:http_adapter, :secret_resolver]
  @connection_keys [
    :application_identifier,
    :assurance_mapping,
    :configuration_version,
    :id,
    :issuer,
    :secret_reference
  ]
  @context_keys [:code_verifier, :configuration_version, :nonce, :redirect_uri, :state]

  @impl true
  def verify_code(_code, _expected_connection_id), do: error(:forbidden)

  @impl true
  def authorization_url(state, connection, context) do
    with {:ok, connection} <- connection(connection),
         {:ok, context} <- authorization_context(context, state, connection.configuration_version),
         {:ok, options} <- runtime_options(),
         {:ok, metadata} <- discovery(connection.issuer, options.http_adapter),
         {:ok, secret} <- client_secret(connection.secret_reference, options.secret_resolver),
         config <-
           assent_config(connection, context, metadata, secret, options.http_adapter, false),
         {:ok, %{url: url, session_params: session_params}} <- OIDC.authorize_url(config),
         true <- session_params.state == state and session_params.nonce == context.nonce do
      {:ok, url}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid_or_unavailable -> error(:retryable_dependency)
    end
  end

  @impl true
  def verify_code(code, expected_connection_id, %{connection: raw_connection, oidc: raw_context}) do
    with {:ok, code} <- code(code),
         {:ok, connection} <- connection(raw_connection),
         true <- connection.id == expected_connection_id,
         {:ok, context} <- callback_context(raw_context, connection.configuration_version),
         {:ok, options} <- runtime_options(),
         {:ok, metadata} <- discovery(connection.issuer, options.http_adapter),
         {:ok, secret} <- client_secret(connection.secret_reference, options.secret_resolver),
         config <-
           assent_config(connection, context, metadata, secret, options.http_adapter, true),
         {:ok, %{token: %{"id_token" => id_token}}} <-
           OIDC.callback(config, %{"code" => code, "state" => context.state}),
         {:ok, jwt} <- OIDC.validate_id_token(config, id_token),
         {:ok, claims} <- claims(jwt),
         {:ok, subject} <- claim_text(claims, "sub", 500),
         {:ok, assurance} <- assurance(claims, connection.assurance_mapping),
         {:ok, authenticated_at} <- authentication_time(claims["auth_time"]),
         {:ok, proof} <-
           VerifiedExternalIdentity.establish(
             connection_id: connection.id,
             protocol: :oidc,
             issuer: connection.issuer,
             subject: subject,
             assurance: assurance,
             authenticated_at: authenticated_at
           ) do
      {:ok, proof}
    else
      {:error, %Error{} = identity_error} ->
        {:error, identity_error}

      {:error, %ServerUnreachableError{}} ->
        error(:retryable_dependency)

      {:error, %HTTPResponse{status: status}} when status >= 500 ->
        error(:retryable_dependency)

      {:error, %InvalidResponseError{response: %{status: status}}} when status >= 500 ->
        error(:retryable_dependency)

      {:error, %UnexpectedResponseError{response: %{status: status}}} when status >= 500 ->
        error(:retryable_dependency)

      _invalid_or_denied ->
        error(:forbidden)
    end
  end

  def verify_code(_code, _expected_connection_id, _context), do: error(:forbidden)

  defp discovery(issuer, http_adapter) do
    with {:ok, issuer_uri} <- https_uri(issuer),
         url <-
           String.trim_trailing(URI.to_string(issuer_uri), "/") <>
             "/.well-known/openid-configuration",
         {:ok, %HTTPResponse{status: 200, body: metadata}} when is_map(metadata) <-
           HTTPAdapter.request(:get, url, nil, [], http_options(http_adapter)),
         true <- metadata["issuer"] == issuer,
         {:ok, _authorization} <- https_uri(metadata["authorization_endpoint"]),
         {:ok, _token} <- https_uri(metadata["token_endpoint"]),
         {:ok, _jwks} <- https_uri(metadata["jwks_uri"]),
         true <- supported?(metadata["code_challenge_methods_supported"], "S256"),
         true <- supported?(metadata["id_token_signing_alg_values_supported"], "RS256"),
         true <-
           optional_supported?(
             metadata["token_endpoint_auth_methods_supported"],
             "client_secret_basic"
           ) do
      {:ok, metadata}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _unavailable_or_unqualified -> error(:retryable_dependency)
    end
  end

  defp assent_config(connection, context, metadata, secret, http_adapter, callback?) do
    base = [
      base_url: connection.issuer,
      client_id: connection.application_identifier,
      client_secret: secret,
      client_authentication_method: "client_secret_basic",
      id_token_signed_response_alg: "RS256",
      redirect_uri: context.redirect_uri,
      openid_configuration: metadata,
      nonce: context.nonce,
      state: context.state,
      http_adapter: http_adapter,
      json_library: Jason
    ]

    if callback? do
      Keyword.merge(base,
        code_verifier: true,
        session_params: %{
          state: context.state,
          nonce: context.nonce,
          code_verifier: context.code_verifier
        }
      )
    else
      Keyword.merge(base,
        code_verifier: false,
        authorization_params: [
          max_age: @maximum_authentication_age,
          code_challenge: challenge(context.code_verifier),
          code_challenge_method: "S256"
        ]
      )
    end
  end

  defp authorization_context(raw, state, version) when is_map(raw) do
    raw
    |> Map.put(:state, state)
    |> callback_context(version)
  end

  defp authorization_context(_raw, _state, _version), do: error(:forbidden)

  defp callback_context(raw, version) when is_map(raw) do
    with {:ok, normalized} <- exact_map(raw, @context_keys),
         {:ok, state} <- bounded(normalized.state, 20, 16_384),
         {:ok, nonce} <- bounded(normalized.nonce, 32, 500),
         {:ok, verifier} <- bounded(normalized.code_verifier, 43, 200),
         {:ok, redirect_uri} <- exact_redirect(normalized.redirect_uri),
         true <- normalized.configuration_version == version do
      {:ok,
       %{
         state: state,
         nonce: nonce,
         code_verifier: verifier,
         redirect_uri: redirect_uri,
         configuration_version: version
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:forbidden)
    end
  end

  defp callback_context(_raw, _version), do: error(:forbidden)

  defp connection(raw) when is_map(raw) do
    with {:ok, normalized} <- exact_map(raw, @connection_keys),
         {:ok, id} <- Ecto.UUID.cast(normalized.id),
         {:ok, issuer_uri} <- https_uri(normalized.issuer),
         true <- URI.to_string(issuer_uri) == normalized.issuer,
         {:ok, client_id} <- bounded(normalized.application_identifier, 1, 500),
         {:ok, secret_reference} <- bounded(normalized.secret_reference, 3, 500),
         true <-
           is_integer(normalized.configuration_version) and normalized.configuration_version > 0,
         {:ok, mapping} <- assurance_mapping(normalized.assurance_mapping) do
      {:ok,
       %{
         id: id,
         issuer: normalized.issuer,
         application_identifier: client_id,
         secret_reference: secret_reference,
         configuration_version: normalized.configuration_version,
         assurance_mapping: mapping
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:forbidden)
    end
  end

  defp connection(_raw), do: error(:forbidden)

  defp client_secret(reference, resolver) do
    if function_exported?(resolver, :fetch_secret, 1) and
         Chimwemwe.Identity.OidcSecretResolver in (resolver.module_info(:attributes)[:behaviour] ||
                                                     []) do
      resolver.fetch_secret(reference)
    else
      error(:retryable_dependency)
    end
  end

  defp runtime_options do
    with options when is_list(options) <-
           Application.get_env(:chimwemwe_core, :oidc_verifier, []),
         true <- Keyword.keyword?(options),
         [] <- Keyword.keys(options) -- @verifier_keys,
         http_adapter <- Keyword.get(options, :http_adapter, Assent.HTTPAdapter.Httpc),
         true <- http_adapter?(http_adapter) do
      {:ok,
       %{
         http_adapter: http_adapter,
         secret_resolver: Keyword.get(options, :secret_resolver, EnvironmentOidcSecretResolver)
       }}
    else
      _invalid -> error(:retryable_dependency)
    end
  end

  defp http_options(http_adapter), do: [http_adapter: http_adapter, json_library: Jason]

  defp http_adapter?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :request, 5) and
      Assent.HTTPAdapter in (module.module_info(:attributes)[:behaviour] || [])
  end

  defp http_adapter?(_module), do: false

  defp supported?(values, required) when is_list(values),
    do: Enum.all?(values, &is_binary/1) and required in values

  defp supported?(_values, _required), do: false

  defp optional_supported?(nil, _required), do: true
  defp optional_supported?(values, required), do: supported?(values, required)

  defp assurance(claims, mapping) do
    candidates =
      [claims["acr"] | List.wrap(claims["amr"])]
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    mapped =
      candidates
      |> Enum.flat_map(fn candidate ->
        case Map.fetch(mapping, candidate) do
          {:ok, value} -> [value]
          :error -> []
        end
      end)
      |> Enum.uniq()

    case mapped do
      [value] -> bounded(value, 1, 120)
      _missing_or_ambiguous -> error(:forbidden)
    end
  end

  defp assurance_mapping(value) when is_map(value) and not is_struct(value) do
    valid? =
      map_size(value) in 1..20 and
        Enum.all?(value, fn {key, mapped} ->
          is_binary(key) and is_binary(mapped) and String.length(key) in 1..120 and
            String.length(mapped) in 1..120
        end)

    if valid?, do: {:ok, value}, else: error(:forbidden)
  end

  defp assurance_mapping(_value), do: error(:forbidden)

  defp authentication_time(value) when is_integer(value) do
    with {:ok, timestamp} <- DateTime.from_unix(value),
         now <- DateTime.utc_now(),
         true <-
           DateTime.compare(timestamp, DateTime.add(now, -@maximum_authentication_age, :second)) in [
             :eq,
             :gt
           ],
         true <-
           DateTime.compare(timestamp, DateTime.add(now, @maximum_clock_skew, :second)) in [
             :eq,
             :lt
           ] do
      {:ok, timestamp}
    else
      _stale_or_invalid -> error(:forbidden)
    end
  end

  defp authentication_time(_value), do: error(:forbidden)

  defp claims(%{claims: claims}) when is_map(claims), do: {:ok, claims}
  defp claims(_jwt), do: error(:forbidden)

  defp claim_text(claims, key, maximum), do: bounded(claims[key], 1, maximum)

  defp code(value), do: bounded(value, 1, @maximum_code_bytes)

  defp exact_redirect(value) do
    with {:ok, uri} <- URI.new(value),
         true <-
           uri.scheme == "https" and is_binary(uri.host) and uri.path == "/auth/callback" and
             is_nil(uri.query) and is_nil(uri.fragment) and is_nil(uri.userinfo) do
      {:ok, URI.to_string(uri)}
    else
      _invalid -> error(:forbidden)
    end
  end

  defp https_uri(value) when is_binary(value) do
    with {:ok, uri} <- URI.new(value),
         true <-
           uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and
             is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment) do
      {:ok, uri}
    else
      _invalid -> error(:forbidden)
    end
  end

  defp https_uri(_value), do: error(:forbidden)

  defp exact_map(input, keys) do
    if Enum.sort(Map.keys(input)) == Enum.sort(keys) do
      {:ok, input}
    else
      error(:forbidden)
    end
  end

  defp bounded(value, minimum, maximum) when is_binary(value) do
    trimmed = String.trim(value)
    size = byte_size(trimmed)

    if value == trimmed and size in minimum..maximum,
      do: {:ok, trimmed},
      else: error(:forbidden)
  end

  defp bounded(_value, _minimum, _maximum), do: error(:forbidden)

  defp challenge(verifier),
    do: verifier |> then(&:crypto.hash(:sha256, &1)) |> Base.url_encode64(padding: false)

  defp error(code), do: {:error, %Error{code: code}}
end
