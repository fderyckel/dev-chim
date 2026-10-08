defmodule Chimwemwe.Identity.LocalCredentials do
  @moduledoc """
  Server-owned local credential lifecycle used by the bounded administration proof.

  Plaintext temporary and permanent passwords exist only in the request process.
  This module returns a generated temporary password exactly once to its caller;
  PostgreSQL receives only the slow password hash.
  """

  alias AshAuthentication.{BcryptProvider, Info, Strategy}
  alias Chimwemwe.Identity.{Account, PasswordPolicy}
  alias Ecto.UUID

  @temporary_lifetime_seconds 24 * 60 * 60
  @first_login_session_seconds 10 * 60

  @type provisioned :: %{account: Account.t(), temporary_password: String.t()}

  @spec list() :: {:ok, [Account.t()]} | {:error, term()}
  def list do
    Ash.read(Account, action: :list_local_accounts, authorize?: false)
  end

  @spec provision(String.t(), String.t()) :: {:ok, provisioned()} | {:error, term()}
  def provision(email, actor_id) do
    with {:ok, email} <- normalize_email(email),
         {:ok, actor_id} <- uuid(actor_id),
         {:ok, temporary_password, hashed_password} <- generated_password(),
         expires_at = DateTime.add(now(), @temporary_lifetime_seconds, :second),
         {:ok, account} <-
           Account
           |> Ash.Changeset.for_create(:provision_local_account, %{
             actor_id: actor_id,
             email: email,
             hashed_password: hashed_password,
             temporary_password_expires_at: expires_at
           })
           |> Ash.create(authorize?: false) do
      {:ok, %{account: account, temporary_password: temporary_password}}
    end
  end

  @spec reissue(String.t()) :: {:ok, provisioned()} | {:error, term()}
  def reissue(account_id) do
    with {:ok, account} <- get(account_id),
         {:ok, temporary_password, hashed_password} <- generated_password(),
         expires_at = DateTime.add(now(), @temporary_lifetime_seconds, :second),
         {:ok, account} <-
           account
           |> Ash.Changeset.for_update(:reissue_temporary_password, %{
             hashed_password: hashed_password,
             temporary_password_expires_at: expires_at
           })
           |> Ash.update(authorize?: false),
         :ok <- revoke_tokens(account) do
      {:ok, %{account: account, temporary_password: temporary_password}}
    end
  end

  @spec suspend(String.t()) :: {:ok, Account.t()} | {:error, term()}
  def suspend(account_id) do
    with {:ok, account} <- get(account_id),
         {:ok, suspended} <-
           account
           |> Ash.Changeset.for_update(:suspend_local_account, %{})
           |> Ash.update(authorize?: false),
         :ok <- revoke_tokens(suspended) do
      {:ok, suspended}
    end
  end

  @doc "Authenticates an active password or establishes restricted first-login state."
  @spec authenticate(String.t(), String.t()) ::
          {:ok, {:active, Account.t()} | {:first_login, Account.t()}} | {:error, :invalid_login}
  def authenticate(email, password) do
    with {:ok, email} <- normalize_email(email),
         true <- is_binary(password),
         {:ok, account} <- lookup(email),
         false <- locked?(account),
         result <- authenticate_account(account, email, password) do
      finish_attempt(account, result)
    else
      _invalid ->
        BcryptProvider.simulate()
        {:error, :invalid_login}
    end
  end

  @spec complete_first_login(String.t(), pos_integer(), String.t(), String.t()) ::
          {:ok, Account.t()} | {:error, term()}
  def complete_first_login(account_id, expected_lock_version, password, confirmation) do
    with true <- password == confirmation,
         {:ok, account} <- get(account_id),
         true <- account.status == :pending_first_login,
         true <- account.lock_version == expected_lock_version,
         true <- future?(account.temporary_password_expires_at),
         false <- BcryptProvider.valid?(password, account.hashed_password),
         :ok <- PasswordPolicy.validate(password, account.email),
         {:ok, hashed_password} <- BcryptProvider.hash(password),
         {:ok, active} <-
           account
           |> Ash.Changeset.for_update(:activate_permanent_password, %{
             hashed_password: hashed_password,
             password_changed_at: now()
           })
           |> Ash.update(authorize?: false),
         :ok <- revoke_tokens(active) do
      {:ok, active}
    else
      false -> {:error, :invalid_password}
      {:error, _reason} = error -> error
      _invalid -> {:error, :invalid_password}
    end
  end

  @spec first_login_session_seconds() :: pos_integer()
  def first_login_session_seconds, do: @first_login_session_seconds

  defp authenticate_account(%Account{status: :pending_first_login} = account, _email, password) do
    if future?(account.temporary_password_expires_at) and
         BcryptProvider.valid?(password, account.hashed_password) do
      {:ok, {:first_login, account}}
    else
      {:error, :invalid_login}
    end
  end

  defp authenticate_account(%Account{status: :active}, email, password) do
    Account
    |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: password})
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [signed_in]} -> {:ok, {:active, signed_in}}
      _invalid -> {:error, :invalid_login}
    end
  end

  defp authenticate_account(_account, _email, _password), do: {:error, :invalid_login}

  defp finish_attempt(account, {:ok, _result} = success) do
    reset_attempts(account.id)
    success
  end

  defp finish_attempt(account, _failure) do
    record_failure(account.id)
    {:error, :invalid_login}
  end

  defp record_failure(account_id) do
    update_attempt_state(account_id, :record_failed_password_attempt)
    :ok
  end

  defp reset_attempts(account_id) do
    update_attempt_state(account_id, :clear_failed_password_attempts)
    :ok
  end

  defp update_attempt_state(account_id, action) do
    with {:ok, account} <- get(account_id) do
      account
      |> Ash.Changeset.for_update(action, %{})
      |> Ash.update(authorize?: false)
    end
  end

  defp revoke_tokens(account) do
    strategy = Info.strategy!(Account, :log_out_everywhere)

    case Strategy.action(strategy, :log_out_everywhere, %{user: account}, authorize?: false) do
      :ok -> :ok
      {:ok, _result} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp lookup(email) do
    Account
    |> Ash.Query.for_read(:lookup_local_account, %{email: email})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Account{} = account} -> {:ok, account}
      _missing -> {:error, :invalid_login}
    end
  end

  defp get(account_id) do
    with {:ok, account_id} <- uuid(account_id) do
      Account
      |> Ash.Query.for_read(:get_local_account, %{id: account_id})
      |> Ash.read_one(authorize?: false)
      |> case do
        {:ok, %Account{} = account} -> {:ok, account}
        {:ok, nil} -> {:error, :not_found}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp generated_password do
    password = :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

    case BcryptProvider.hash(password) do
      {:ok, hashed_password} -> {:ok, password, hashed_password}
      :error -> {:error, :password_hash_unavailable}
    end
  end

  defp normalize_email(value) when is_binary(value) do
    email = value |> String.trim() |> String.downcase()

    if String.valid?(email) and String.length(email) in 3..320 and
         Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/u, email) do
      {:ok, email}
    else
      {:error, :invalid_email}
    end
  end

  defp normalize_email(_value), do: {:error, :invalid_email}

  defp locked?(%Account{locked_until: nil}), do: false
  defp locked?(%Account{locked_until: locked_until}), do: future?(locked_until)

  defp future?(%DateTime{} = value), do: DateTime.compare(value, now()) == :gt
  defp future?(_value), do: false

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_id}
    end
  end
end
