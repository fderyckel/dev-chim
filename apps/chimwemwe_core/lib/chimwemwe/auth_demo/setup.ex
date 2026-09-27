defmodule Chimwemwe.AuthDemo.Setup do
  @moduledoc false

  @migration_version 20_260_926_202_954
  @migration Chimwemwe.Repo.Migrations.IdentityAuthenticationFoundation

  @spec migrate() :: :ok
  def migrate do
    Code.require_file(migration_path())

    {:ok, _result, _started} =
      Ecto.Migrator.with_repo(Chimwemwe.Repo, fn repo ->
        Ecto.Migrator.up(repo, @migration_version, @migration, log: false)
      end)

    :ok
  end

  defp migration_path do
    Application.app_dir(
      :chimwemwe_core,
      "priv/repo/migrations/20260926202954_identity_authentication_foundation.exs"
    )
  end
end
