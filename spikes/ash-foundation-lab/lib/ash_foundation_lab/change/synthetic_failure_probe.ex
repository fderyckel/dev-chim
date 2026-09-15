defmodule AshFoundationLab.Change.SyntheticFailureProbe do
  @moduledoc """
  Injects bounded Phase 0 failures from trusted Ash context before a transaction.

  The generated request schema exposes no matching input. This probe is disposable
  framework evidence, not a production limiter or dependency integration.
  """

  use Ash.Resource.Change

  alias AshFoundationLab.Error.DependencyUnavailable
  alias AshFoundationLab.Error.ForcedInternal
  alias AshFoundationLab.Error.RateLimited

  @impl true
  def change(changeset, _options, _context) do
    Ash.Changeset.before_transaction(changeset, &inject_failure/1)
  end

  defp inject_failure(changeset) do
    case changeset.context[:phase0_failure_probe] do
      :rate_limited ->
        add_error(changeset, RateLimited, "phase0 capacity partition alpha")

      :dependency_unavailable ->
        add_error(changeset, DependencyUnavailable, "phase0 dependency pool beta")

      :forced_internal ->
        add_error(changeset, ForcedInternal, "phase0 restricted implementation marker")

      _other ->
        changeset
    end
  end

  defp add_error(changeset, error_module, reason) do
    Ash.Changeset.add_error(changeset, error_module.exception(reason: reason))
  end
end
