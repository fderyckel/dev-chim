# Read-only account drift check. A temporary snapshot tree excludes concurrent resources.
defmodule AccountBindingSnapshotDomain do
  @moduledoc false
  use Ash.Domain, otp_app: :chimwemwe_core, validate_config_inclusion?: false

  resources do
    resource(Chimwemwe.Identity.Account)
  end
end

root = Path.expand("../apps/chimwemwe_core/priv/resource_snapshots", __DIR__)

scratch =
  Path.join(System.tmp_dir!(), "chimwemwe-binding-snapshot-#{System.unique_integer([:positive])}")

File.mkdir_p!(Path.join(scratch, "repo"))

try do
  File.cp_r!(
    Path.join(root, "repo/identity_accounts"),
    Path.join(scratch, "repo/identity_accounts")
  )

  AshPostgres.MigrationGenerator.generate([AccountBindingSnapshotDomain],
    snapshot_path: scratch,
    migration_path: Path.join(scratch, "migrations"),
    check: true
  )

  IO.puts("Account-only generated snapshot drift: passed")
after
  File.rm_rf!(scratch)
end
