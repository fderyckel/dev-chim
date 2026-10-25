defmodule Chimwemwe.Identity.PasswordPolicyTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.Identity.PasswordPolicy

  @email "member@example.test"

  test "accepts the full 15 through 128 Unicode code point range" do
    assert :ok = PasswordPolicy.validate(String.duplicate("\u{1F331}", 15), @email)
    assert :ok = PasswordPolicy.validate(String.duplicate("\u{1F331}", 128), @email)

    assert {:error, :password_too_short} =
             PasswordPolicy.validate(String.duplicate("\u{1F331}", 14), @email)

    assert {:error, :password_too_long} =
             PasswordPolicy.validate(String.duplicate("\u{1F331}", 129), @email)
  end

  test "normalizes before code point counting rather than counting grapheme clusters" do
    assert {:error, :password_too_short} =
             PasswordPolicy.validate(String.duplicate("e\u0301", 14), @email)

    assert :ok = PasswordPolicy.validate(String.duplicate("e\u0301", 15), @email)
    assert :ok = PasswordPolicy.validate(String.duplicate("\u{1F469}\u200D\u{1F4BB}", 5), @email)
  end

  test "screens whole common and contextual passwords without banning words in useful phrases" do
    for blocked <- ["PASSWORDPASSWORD", "administrator123", @email, "member123456789"] do
      assert {:error, :blocked_password} = PasswordPolicy.validate(blocked, @email)
    end

    assert :ok = PasswordPolicy.validate("member has a different long phrase", @email)
    assert :ok = PasswordPolicy.validate("a quiet password beside the river", @email)
    assert :ok = PasswordPolicy.validate("correct horse battery staple", @email)
  end

  test "rejects invalid encodings and NUL without transforming spaces or case" do
    assert {:error, :invalid_password} = PasswordPolicy.validate(<<255>>, @email)
    assert {:error, :invalid_password} = PasswordPolicy.validate("synthetic" <> <<0>>, @email)
    assert {:error, :invalid_password} = PasswordPolicy.validate(nil, @email)
    assert {:ok, " Caf\u00E9 Lantern "} = PasswordPolicy.normalize(" Cafe\u0301 Lantern ")
  end
end
