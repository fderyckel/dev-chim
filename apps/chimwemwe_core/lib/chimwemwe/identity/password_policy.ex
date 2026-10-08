defmodule Chimwemwe.Identity.PasswordPolicy do
  @moduledoc """
  Server-owned password policy for Chimwemwe local credentials.

  The policy favours length and a contextual blocklist over composition rules.
  It deliberately returns only stable reason atoms and never records the
  proposed password.
  """

  @minimum_length 15
  @maximum_length 128
  @blocked MapSet.new([
             "123456789012345",
             "letmeinletmein",
             "passwordpassword",
             "qwertyqwertyqwerty",
             "welcome123456789"
           ])

  @spec validate(String.t(), String.t()) :: :ok | {:error, atom()}
  def validate(password, email) when is_binary(password) and is_binary(email) do
    normalized = String.downcase(password)
    local_part = email |> String.downcase() |> String.split("@", parts: 2) |> hd()

    cond do
      not String.valid?(password) ->
        {:error, :invalid_password}

      String.length(password) < @minimum_length ->
        {:error, :password_too_short}

      String.length(password) > @maximum_length ->
        {:error, :password_too_long}

      MapSet.member?(@blocked, normalized) ->
        {:error, :blocked_password}

      String.length(local_part) >= 4 and String.contains?(normalized, local_part) ->
        {:error, :blocked_password}

      true ->
        :ok
    end
  end

  def validate(_password, _email), do: {:error, :invalid_password}

  @spec minimum_length() :: pos_integer()
  def minimum_length, do: @minimum_length

  @spec maximum_length() :: pos_integer()
  def maximum_length, do: @maximum_length
end
