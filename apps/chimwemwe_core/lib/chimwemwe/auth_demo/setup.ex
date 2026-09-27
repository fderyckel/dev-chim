defmodule Chimwemwe.AuthDemo.Setup do
  @moduledoc false

  @migrations [
    {20_260_926_202_954, Chimwemwe.Repo.Migrations.IdentityAuthenticationFoundation,
     "20260926202954_identity_authentication_foundation.exs"},
    {20_260_927_175_817, Chimwemwe.Repo.Migrations.ProviderNeutralIdentityConnection,
     "20260927175817_provider_neutral_identity_connection.exs"}
  ]

  @spec migrate() :: :ok
  def migrate do
    Enum.each(@migrations, fn {_version, _module, filename} ->
      Code.require_file(migration_path(filename))
    end)

    {:ok, _result, _started} =
      Ecto.Migrator.with_repo(Chimwemwe.Repo, fn repo ->
        Enum.each(@migrations, fn {version, module, _filename} ->
          Ecto.Migrator.up(repo, version, module, log: false)
        end)
      end)

    :ok
  end

  defp migration_path(filename) do
    Application.app_dir(
      :chimwemwe_core,
      "priv/repo/migrations/#{filename}"
    )
  end
end
