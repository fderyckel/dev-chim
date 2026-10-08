defmodule Chimwemwe.Identity.LocalCredentialsTest do
  use ExUnit.Case, async: false

  alias AshAuthentication.BcryptProvider
  alias Chimwemwe.AuthDemo.{Admin, Config}
  alias Chimwemwe.Identity.{Account, LocalCredentials, PasswordPolicy}
  alias Chimwemwe.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID

  @actor_a "10000000-0000-4000-8000-000000000001"
  @actor_b "10000000-0000-4000-8000-000000000002"
  @password "Quiet river lantern 2048!"

  setup do
    start_supervised!({Repo, []})
    :ok = Sandbox.checkout(Repo)
    Repo.query!("DELETE FROM identity_tokens")
    Repo.query!("DELETE FROM identity_accounts")
    :ok
  end

  test "provisions a normalized account and returns its random temporary password once" do
    assert {:ok, %{account: account, temporary_password: temporary_password}} =
             LocalCredentials.provision("  Staff.One@Example.TEST ", @actor_a)

    assert account.actor_id == @actor_a
    assert account.email == "staff.one@example.test"
    assert account.status == :pending_first_login
    assert account.failed_attempt_count == 0
    assert account.lock_version == 1

    assert DateTime.diff(account.temporary_password_expires_at, DateTime.utc_now(), :second) in 86_390..86_400

    assert byte_size(temporary_password) == 32
    refute temporary_password == account.hashed_password
    assert BcryptProvider.valid?(temporary_password, account.hashed_password)

    assert %{rows: [[stored_hash]]} =
             Repo.query!("SELECT hashed_password FROM identity_accounts WHERE id = $1", [
               UUID.dump!(account.id)
             ])

    assert stored_hash == account.hashed_password
    refute stored_hash == temporary_password
  end

  test "temporary credentials establish only first-login state, then a permanent password signs in" do
    %{account: account, temporary_password: temporary_password} = provision!(@actor_a)

    assert {:ok, {:first_login, pending}} =
             LocalCredentials.authenticate(account.email, temporary_password)

    assert pending.id == account.id
    refute Map.get(pending.__metadata__, :token)

    assert {:error, :invalid_password} =
             LocalCredentials.complete_first_login(
               account.id,
               pending.lock_version,
               temporary_password,
               temporary_password
             )

    assert {:ok, active} =
             LocalCredentials.complete_first_login(
               account.id,
               pending.lock_version,
               @password,
               @password
             )

    assert active.status == :active
    assert active.temporary_password_expires_at == nil
    assert %DateTime{} = active.password_changed_at

    assert {:error, :invalid_login} =
             LocalCredentials.authenticate(account.email, temporary_password)

    assert {:ok, {:active, signed_in}} =
             LocalCredentials.authenticate(account.email, @password)

    assert signed_in.id == account.id
    assert is_binary(Map.fetch!(signed_in.__metadata__, :token))
  end

  test "reissuing a temporary password invalidates both the old password and old first-login state" do
    %{account: account, temporary_password: temporary_password} = provision!(@actor_a)

    assert {:ok, {:first_login, pending}} =
             LocalCredentials.authenticate(account.email, temporary_password)

    assert {:ok, %{account: reissued, temporary_password: replacement}} =
             LocalCredentials.reissue(account.id)

    refute replacement == temporary_password
    assert reissued.lock_version > pending.lock_version

    assert {:error, :invalid_login} =
             LocalCredentials.authenticate(account.email, temporary_password)

    assert {:error, :invalid_password} =
             LocalCredentials.complete_first_login(
               account.id,
               pending.lock_version,
               @password,
               @password
             )

    assert {:ok, {:first_login, refreshed}} =
             LocalCredentials.authenticate(account.email, replacement)

    assert refreshed.lock_version == reissued.lock_version
  end

  test "reissue and suspension revoke active account tokens" do
    %{account: account, temporary_password: temporary_password} = provision!(@actor_a)

    assert {:ok, {:first_login, pending}} =
             LocalCredentials.authenticate(account.email, temporary_password)

    assert {:ok, _active} =
             LocalCredentials.complete_first_login(
               account.id,
               pending.lock_version,
               @password,
               @password
             )

    assert {:ok, {:active, _signed_in}} =
             LocalCredentials.authenticate(account.email, @password)

    assert active_token_count() == 1
    assert revoked_token_count() == 0

    assert {:ok, %{account: reissued, temporary_password: replacement}} =
             LocalCredentials.reissue(account.id)

    assert active_token_count() == 0
    assert revoked_token_count() == 1

    assert {:ok, {:first_login, refreshed}} =
             LocalCredentials.authenticate(account.email, replacement)

    next_password = "Apricot theatre compass 2050!"

    assert {:ok, _active} =
             LocalCredentials.complete_first_login(
               reissued.id,
               refreshed.lock_version,
               next_password,
               next_password
             )

    assert {:ok, {:active, _signed_in}} =
             LocalCredentials.authenticate(account.email, next_password)

    assert active_token_count() == 1
    assert {:ok, suspended} = LocalCredentials.suspend(account.id)
    assert suspended.status == :suspended
    assert active_token_count() == 0
    assert revoked_token_count() == 2
  end

  test "expired, suspended and locked credentials fail closed with the same public result" do
    %{account: account, temporary_password: temporary_password} = provision!(@actor_a)

    Repo.query!(
      "UPDATE identity_accounts SET temporary_password_expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1",
      [UUID.dump!(account.id)]
    )

    assert {:error, :invalid_login} =
             LocalCredentials.authenticate(account.email, temporary_password)

    assert {:ok, %{account: reset, temporary_password: replacement}} =
             LocalCredentials.reissue(account.id)

    for _attempt <- 1..5 do
      assert {:error, :invalid_login} =
               LocalCredentials.authenticate(account.email, "incorrect temporary password")
    end

    assert {:error, :invalid_login} = LocalCredentials.authenticate(account.email, replacement)

    Repo.query!("UPDATE identity_accounts SET locked_until = NULL WHERE id = $1", [
      UUID.dump!(account.id)
    ])

    assert {:ok, suspended} = LocalCredentials.suspend(reset.id)
    assert suspended.status == :suspended
    assert suspended.temporary_password_expires_at == nil
    assert {:error, :invalid_login} = LocalCredentials.authenticate(account.email, replacement)

    assert {:error, :invalid_login} =
             LocalCredentials.authenticate("missing@example.test", replacement)
  end

  test "email and staff actor remain independently unique" do
    provision!(@actor_a, "person.one@example.test")

    assert {:error, _error} = LocalCredentials.provision("person.one@example.test", @actor_b)
    assert {:error, _error} = LocalCredentials.provision("person.two@example.test", @actor_a)
  end

  test "the administration boundary denies an unauthorised account and unknown staff record" do
    denied = %Account{id: Ecto.UUID.generate(), actor_id: @actor_b, status: :active}

    attributes = %{
      "actor_id" => Config.staff_candidates() |> hd() |> Map.fetch!(:actor_id),
      "email" => "prepared.staff@example.test"
    }

    assert {:error, :forbidden} = Admin.provision_local_account(denied, attributes)
    assert {:ok, []} = LocalCredentials.list()

    administrator = %Account{
      id: Ecto.UUID.generate(),
      actor_id: Config.admin_actor_id(),
      status: :active
    }

    assert {:error, :forbidden} =
             Admin.provision_local_account(administrator, %{
               "actor_id" => @actor_a,
               "email" => "unprepared.staff@example.test"
             })

    assert {:ok, %{account: account}} =
             Admin.provision_local_account(administrator, attributes)

    assert account.actor_id == attributes["actor_id"]
  end

  test "the router exposes explicit local lifecycle routes and no generated public registration" do
    routes = Phoenix.Router.routes(Chimwemwe.AuthDemo.Router)
    route_pairs = MapSet.new(routes, &{&1.verb, &1.path})

    assert MapSet.member?(route_pairs, {:get, "/sign-in"})
    assert MapSet.member?(route_pairs, {:post, "/sign-in"})
    assert MapSet.member?(route_pairs, {:post, "/sign-out"})
    assert MapSet.member?(route_pairs, {:get, "/first-login/password"})
    assert MapSet.member?(route_pairs, {:post, "/admin/accounts"})

    refute Enum.any?(routes, &String.starts_with?(&1.path, "/auth/"))
    refute Enum.any?(routes, &String.contains?(&1.path, "register"))
    refute Enum.any?(routes, &String.contains?(&1.path, "reset"))
  end

  test "password policy favours length and rejects contextual or predictable values" do
    assert {:error, :password_too_short} =
             PasswordPolicy.validate("short", "member@example.test")

    assert {:error, :blocked_password} =
             PasswordPolicy.validate("member has a password", "member@example.test")

    assert {:error, :blocked_password} =
             PasswordPolicy.validate("passwordpassword", "member@example.test")

    assert :ok = PasswordPolicy.validate(@password, "member@example.test")
  end

  defp provision!(actor_id, email \\ "staff.one@example.test") do
    assert {:ok, provisioned} = LocalCredentials.provision(email, actor_id)
    provisioned
  end

  defp active_token_count do
    %{rows: [[count]]} =
      Repo.query!("SELECT count(*) FROM identity_tokens WHERE purpose <> 'revocation'")

    count
  end

  defp revoked_token_count do
    %{rows: [[count]]} =
      Repo.query!("SELECT count(*) FROM identity_tokens WHERE purpose = 'revocation'")

    count
  end
end
