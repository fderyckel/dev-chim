defmodule Chimwemwe.Identity.PasswordHashTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.Identity.PasswordHash

  test "new hashes use salted versioned Argon2id at the reviewed local cost" do
    password = "Fictional river lantern 2048!"
    assert {:ok, first} = PasswordHash.hash(password)
    assert {:ok, second} = PasswordHash.hash(password)
    assert String.starts_with?(first, "$argon2id$v=19$m=32768,t=2,p=1$")
    refute first == second
    assert PasswordHash.valid?(password, first)
    refute PasswordHash.valid?("Fictional river lantern 2049!", first)
  end

  test "hashing and verification retain the complete long Unicode passphrase" do
    prefix = String.duplicate("\u{1F331}", 126)
    password = prefix <> "AB"
    assert {:ok, encoded} = PasswordHash.hash(password)
    assert PasswordHash.valid?(password, encoded)
    refute PasswordHash.valid?(prefix <> "AC", encoded)
    refute PasswordHash.valid?(prefix, encoded)
  end

  test "new Unicode passwords have explicit NFC equivalence without trimming or case folding" do
    composed = "Caf\u00E9 lantern maple 2048!"
    decomposed = "Cafe\u0301 lantern maple 2048!"
    assert {:ok, encoded} = PasswordHash.hash(composed)
    assert PasswordHash.valid?(decomposed, encoded)
    refute PasswordHash.valid?(String.downcase(composed), encoded)
    refute PasswordHash.valid?(composed <> " ", encoded)
    refute PasswordHash.valid?(" " <> composed, encoded)
  end

  test "legacy bcrypt verifies original bytes below its ambiguous truncation boundary" do
    password = String.duplicate("s", 71)
    assert {:ok, encoded} = AshAuthentication.BcryptProvider.hash(password)
    assert PasswordHash.valid?(password, encoded)
    refute PasswordHash.valid?(String.duplicate("s", 70), encoded)

    decomposed = "Cafe\u0301 lantern maple 2048!"
    assert {:ok, legacy_unicode} = AshAuthentication.BcryptProvider.hash(decomposed)
    assert PasswordHash.valid?(decomposed, legacy_unicode)
    refute PasswordHash.valid?(String.normalize(decomposed, :nfc), legacy_unicode)
  end

  test "legacy truncated or exactly boundary passwords require reissue" do
    prefix = String.duplicate("s", 72)
    assert {:ok, encoded} = AshAuthentication.BcryptProvider.hash(prefix <> "A")
    refute PasswordHash.valid?(prefix <> "A", encoded)
    refute PasswordHash.valid?(prefix <> "B", encoded)
    refute PasswordHash.valid?(prefix, encoded)
    refute PasswordHash.valid?(String.duplicate("s", 71), encoded)
  end

  test "malformed input and unsupported hash versions fail closed" do
    assert :error = PasswordHash.hash(<<255>>)
    assert :error = PasswordHash.hash("synthetic" <> <<0>>)
    assert :error = PasswordHash.hash(String.duplicate("x", 4097))
    refute PasswordHash.valid?(nil, "unknown")
    refute PasswordHash.valid?("synthetic", "$argon2id$v=19$malformed")
    refute PasswordHash.valid?("synthetic", "$argon2i$v=19$malformed")
    refute PasswordHash.valid?("synthetic", "$2b$malformed")
  end
end
