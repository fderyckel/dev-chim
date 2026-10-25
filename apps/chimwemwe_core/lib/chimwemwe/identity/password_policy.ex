defmodule Chimwemwe.Identity.PasswordPolicy do
  @moduledoc """
  Server-owned password policy for Chimwemwe local credentials.

  The policy counts NFC-normalized Unicode code points and screens whole
  passwords rather than words within a passphrase. The bundled local blocklist
  is deterministic; a deployed compromised-password corpus remains a separate
  qualification obligation.
  It deliberately returns only stable reason atoms and never records the
  proposed password.
  """

  @minimum_length 15
  @maximum_length 128
  @blocked MapSet.new([
             "123456789012345",
             "letmeinletmein",
             "12345678901234567890",
             "111111111111111",
             "aaaaaaaaaaaaaaa",
             "passwordpassword",
             "password123456789",
             "password1234567890",
             "passwordpassword123",
             "passwordpassword1",
             "passwordpassword!",
             "qwertyuiopasdfgh",
             "qwertyqwertyqwerty",
             "adminadminadmin",
             "administrator123",
             "changemechangeme",
             "letmeinletmeinletmein",
             "welcome12345678",
             "welcomewelcome1",
             "welcome123456789"
           ])

  @spec validate(String.t(), String.t()) :: :ok | {:error, atom()}
  def validate(password, email) when is_binary(password) and is_binary(email) do
    with {:ok, normalized} <- normalize(password) do
      codepoints = normalized |> String.codepoints() |> length()
      screened = String.downcase(normalized)

      cond do
        codepoints < @minimum_length -> {:error, :password_too_short}
        codepoints > @maximum_length -> {:error, :password_too_long}
        MapSet.member?(@blocked, screened) -> {:error, :blocked_password}
        MapSet.member?(contextual_blocklist(email), screened) -> {:error, :blocked_password}
        true -> :ok
      end
    end
  end

  def validate(_password, _email), do: {:error, :invalid_password}

  @doc "Canonical input for new hashes; never trims or changes password case."
  @spec normalize(term()) :: {:ok, String.t()} | {:error, :invalid_password}
  def normalize(password) when is_binary(password) and byte_size(password) <= 4096 do
    if String.valid?(password) and not String.contains?(password, <<0>>) do
      {:ok, String.normalize(password, :nfc)}
    else
      {:error, :invalid_password}
    end
  end

  def normalize(_password), do: {:error, :invalid_password}

  @spec minimum_length() :: pos_integer()
  def minimum_length, do: @minimum_length

  @spec maximum_length() :: pos_integer()
  def maximum_length, do: @maximum_length

  defp contextual_blocklist(email) do
    normalized_email = email |> String.normalize(:nfc) |> String.downcase()
    local_part = normalized_email |> String.split("@", parts: 2) |> hd()

    [normalized_email, local_part, "chimwemwe", "northstar"]
    |> Enum.flat_map(fn value ->
      [value, value <> "123", value <> "123456789", value <> value]
    end)
    |> MapSet.new()
  end
end
