defmodule Chimwemwe.Identity.PasswordHash do
  @moduledoc """
  Versioned password hashing for local credentials.

  New hashes use Argon2id with NFC-normalized input. The encoded hash records its
  algorithm, version, cost and random salt. Legacy bcrypt is verified without
  changing its original input semantics, and only below its 72-byte truncation
  boundary. A legacy password at that boundary requires administrator reissue.
  """

  @behaviour AshAuthentication.HashProvider

  alias Chimwemwe.Identity.PasswordPolicy

  @argon2_options [argon2_type: 2, m_cost: 15, t_cost: 2, parallelism: 1, salt_len: 16]

  @impl true
  def hash(input) do
    case PasswordPolicy.normalize(input) do
      {:ok, normalized} -> {:ok, Argon2.hash_pwd_salt(normalized, @argon2_options)}
      _invalid -> :error
    end
  end

  @impl true
  def valid?(input, "$argon2id$v=19$" <> _parameters = encoded_hash) do
    case PasswordPolicy.normalize(input) do
      {:ok, normalized} -> Argon2.verify_pass(normalized, encoded_hash)
      _invalid -> false
    end
  rescue
    ArgumentError -> false
  end

  def valid?(input, <<"$2", version, "$", _parameters::binary>> = encoded_hash)
      when version in [?a, ?b, ?y] and is_binary(input) and byte_size(input) < 72 do
    String.valid?(input) and not String.contains?(input, <<0>>) and
      AshAuthentication.BcryptProvider.valid?(input, encoded_hash)
  rescue
    ArgumentError -> false
  end

  def valid?(_input, _encoded_hash), do: false

  @impl true
  def simulate, do: Argon2.no_user_verify(@argon2_options)

  @impl true
  def minimum_entropy, do: 0

  @impl true
  def deterministic?, do: false
end
