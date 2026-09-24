defmodule Chimwemwe.Repo do
  @moduledoc """
  PostgreSQL repository owned by the Chimwemwe platform core.

  Production pools are started only by an explicitly configured persistence
  runtime. The application has no default database or implicit fallback pool.
  """

  use AshPostgres.Repo,
    otp_app: :chimwemwe_core,
    warn_on_missing_ash_functions?: false

  @impl true
  def installed_extensions, do: []

  @impl true
  def min_pg_version do
    %Version{major: 18, minor: 0, patch: 0}
  end
end
