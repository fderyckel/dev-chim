defmodule Chimwemwe.Identity.VerifiedLocalCredential do
  @moduledoc """
  Short-lived local credential evidence, created only by password verification.

  The sealed fields are candidate identity references, never tenant authority.
  The application-session writer must recheck their current authoritative state.
  """

  alias Chimwemwe.Identity.{Error, LocalCredentials}
  alias Ecto.UUID

  @assurance "local_password"
  @lifetime_seconds 60
  @fields [
    :id,
    :account_id,
    :actor_id,
    :credential_version,
    :credential_fingerprint,
    :assurance,
    :authenticated_at
  ]
  @enforce_keys @fields ++ [:seal]
  @derive {Inspect, only: [:account_id, :actor_id]}
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{
            id: String.t(),
            account_id: String.t(),
            actor_id: String.t(),
            credential_version: pos_integer(),
            credential_fingerprint: binary(),
            assurance: String.t(),
            authenticated_at: DateTime.t(),
            seal: binary()
          }

  @doc "Verifies a password; temporary credentials retain only their restricted first-login path."
  @spec authenticate(term(), term()) ::
          {:ok, t()} | {:first_login, Chimwemwe.Identity.Account.t()} | {:error, term()}
  def authenticate(email, password) do
    case LocalCredentials.authenticate_for_application(email, password) do
      {:ok, {:active, account}} -> establish(account)
      {:ok, {:first_login, account}} -> {:first_login, account}
      _denied -> error(:forbidden)
    end
  end

  @doc false
  @spec validate(term()) :: :ok | {:error, Error.t()}
  def validate(%__MODULE__{} = proof) do
    with {:ok, secret} <- secret(),
         true <- valid_fields?(proof),
         true <- is_binary(proof.seal) and byte_size(proof.seal) == 32,
         true <- Plug.Crypto.secure_compare(proof.seal, seal(secret, proof)) do
      :ok
    else
      {:error, _error} = failed -> failed
      _invalid -> error(:forbidden)
    end
  end

  def validate(_proof), do: error(:forbidden)

  @doc false
  @spec credential_fingerprint(map()) :: {:ok, binary()} | {:error, Error.t()}
  def credential_fingerprint(%{
        id: account_id,
        actor_id: actor_id,
        hashed_password: hashed_password,
        status: status,
        principal_binding_id: binding_id
      })
      when is_binary(account_id) and is_binary(actor_id) and is_binary(hashed_password) and
             is_integer(binding_id) and binding_id > 0 and
             status in [
               :pending_first_login,
               :active,
               :suspended,
               "pending_first_login",
               "active",
               "suspended"
             ] do
    with {:ok, secret} <- secret() do
      basis = {
        "chimwemwe-local-credential-basis-v1",
        account_id,
        actor_id,
        hashed_password,
        to_string(status),
        binding_id
      }

      {:ok, :crypto.mac(:hmac, :sha256, secret, :erlang.term_to_binary(basis, [:deterministic]))}
    end
  end

  def credential_fingerprint(_account), do: error(:forbidden)

  defp establish(account) do
    with {:ok, secret} <- secret(),
         {:ok, fingerprint} <- credential_fingerprint(account) do
      fields = %{
        id: UUID.generate(),
        account_id: account.id,
        actor_id: account.actor_id,
        credential_version: account.lock_version,
        credential_fingerprint: fingerprint,
        assurance: @assurance,
        authenticated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      }

      {:ok, struct!(__MODULE__, Map.put(fields, :seal, seal(secret, fields)))}
    end
  end

  defp valid_fields?(proof) do
    Enum.all?([proof.id, proof.account_id, proof.actor_id], &(UUID.cast(&1) == {:ok, &1})) and
      is_integer(proof.credential_version) and proof.credential_version > 0 and
      is_binary(proof.credential_fingerprint) and byte_size(proof.credential_fingerprint) == 32 and
      proof.assurance == @assurance and fresh?(proof.authenticated_at)
  end

  defp fresh?(%DateTime{} = authenticated_at) do
    age = DateTime.diff(DateTime.utc_now(), authenticated_at, :second)
    age >= 0 and age <= @lifetime_seconds
  end

  defp fresh?(_value), do: false

  defp seal(secret, proof) do
    payload = {"chimwemwe-local-credential-v1", Map.take(proof, @fields)}
    :crypto.mac(:hmac, :sha256, secret, :erlang.term_to_binary(payload, [:deterministic]))
  end

  defp secret do
    case Application.get_env(:chimwemwe_core, :identity_session_hmac_secret) do
      secret when is_binary(secret) and byte_size(secret) >= 32 -> {:ok, secret}
      _missing_or_invalid -> error(:retryable_dependency)
    end
  end

  defp error(code), do: {:error, %Error{code: code}}
end
