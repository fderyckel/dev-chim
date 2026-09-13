defmodule AshFoundationLab.Repo do
  @moduledoc false

  use AshPostgres.Repo,
    otp_app: :ash_foundation_lab,
    warn_on_missing_ash_functions?: false

  def installed_extensions, do: []

  def min_pg_version do
    %Version{major: 18, minor: 0, patch: 0}
  end
end
