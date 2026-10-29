defmodule Chimwemwe.People.StaffAudience.Clock do
  @moduledoc false
  alias Chimwemwe.Repo

  def start do
    observed_at = System.monotonic_time(:microsecond)

    [[isolation, elapsed, existing]] =
      Repo.query!("""
      SELECT current_setting('transaction_isolation'),
        ceil(extract(epoch FROM (clock_timestamp() - transaction_timestamp())) * 1000)::bigint,
        (extract(epoch FROM current_setting('transaction_timeout')::interval) * 1000)::bigint
      """).rows

    budget = if existing > 0, do: min(2_000, existing), else: 2_000
    remaining = budget - elapsed

    if isolation != "read committed" or remaining <= 0,
      do: fail(:retryable_dependency)

    limit(remaining)
    observed_at + remaining * 1_000
  end

  # The server timeout interrupts blocked/idle transactions. This independent,
  # non-restartable deadline also refuses an over-budget callback result before
  # the owner can commit, even if the server timer did not interrupt that work.
  def within_budget(deadline) do
    if System.monotonic_time(:microsecond) < deadline,
      do: :ok,
      else: fail(:retryable_dependency)
  end

  def basis(zone), do: basis_at(zone, nil)

  # Internal deterministic temporal qualification only. The source always calls
  # basis/1, whose instant comes from the authoritative writer clock.
  def basis_at(zone, instant) do
    [[now, date, midnight]] =
      Repo.query!(
        """
        SELECT instant AT TIME ZONE 'UTC', (instant AT TIME ZONE $1)::date,
          (((instant AT TIME ZONE $1)::date + 1)::timestamp AT TIME ZONE $1) AT TIME ZONE 'UTC'
        FROM (SELECT COALESCE($2::timestamp AT TIME ZONE 'UTC', clock_timestamp()) AS instant) clock
        """,
        [zone, instant]
      ).rows

    %{
      now: now,
      date: date,
      midnight: midnight,
      expires_at: earlier(NaiveDateTime.add(now, 300), midnight)
    }
  end

  def bound(deadline) do
    [[remaining]] =
      Repo.query!(
        """
        SELECT floor(extract(epoch FROM ($1::timestamp - (clock_timestamp() AT TIME ZONE 'UTC'))) * 1000)::bigint
        """,
        [deadline]
      ).rows

    if remaining <= 0, do: fail(:stale)
    limit(remaining)
  end

  def current_before(deadline) do
    [[valid]] =
      Repo.query!("SELECT (clock_timestamp() AT TIME ZONE 'UTC') < $1::timestamp", [deadline]).rows

    if valid, do: :ok, else: fail(:stale)
  end

  def earlier(a, b), do: if(NaiveDateTime.compare(a, b) == :lt, do: a, else: b)

  defp limit(remaining) do
    [[existing]] =
      Repo.query!("""
      SELECT (extract(epoch FROM current_setting('transaction_timeout')::interval) * 1000)::bigint
      """).rows

    timeout = if existing > 0, do: min(existing, remaining), else: remaining
    Repo.query!("SELECT set_config('transaction_timeout', $1, true)", ["#{timeout}ms"])
    :ok
  end

  defp fail(code), do: Repo.rollback(%Chimwemwe.People.Error{code: code})
end
