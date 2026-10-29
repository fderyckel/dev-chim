defmodule Chimwemwe.AcademicCalendar.Contract do
  @moduledoc false

  alias Chimwemwe.AcademicCalendar.{Closure, Definition, Error, Period, Preview, Resolution}
  alias Ecto.UUID

  @definition_keys [
    :academic_year_id,
    :calendar_id,
    :closures,
    :code,
    :end_on,
    :institutional_unit_id,
    :instructional_weekdays,
    :label,
    :periods,
    :start_on,
    :time_zone
  ]
  @period_keys [:end_on, :id, :label, :period_type_key, :sequence, :start_on]
  @closure_keys [:date, :id, :label, :reason_key]
  @maximum_year_days 731
  @key_pattern ~r/\A[a-z][a-z0-9_]{0,79}\z/
  @time_zone_pattern ~r/\A(?:Etc\/UTC|[A-Za-z][A-Za-z0-9._+-]*\/[A-Za-z0-9._+-]+(?:\/[A-Za-z0-9._+-]+)*)\z/

  @spec preview_publication(map()) :: {:ok, Preview.t()} | {:error, Error.t()}
  def preview_publication(input) do
    with {:ok, normalized} <- exact_map(input, @definition_keys, :definition),
         {:ok, calendar_id} <- uuid(normalized.calendar_id, :calendar_id),
         {:ok, institutional_unit_id} <-
           uuid(normalized.institutional_unit_id, :institutional_unit_id),
         {:ok, academic_year_id} <- uuid(normalized.academic_year_id, :academic_year_id),
         {:ok, code} <- bounded_key(normalized.code, :code),
         {:ok, label} <- bounded_label(normalized.label, :label),
         {:ok, start_on, end_on} <- date_range(normalized.start_on, normalized.end_on, :year),
         :ok <- bounded_year(start_on, end_on),
         {:ok, time_zone} <- time_zone(normalized.time_zone),
         {:ok, weekdays} <- weekdays(normalized.instructional_weekdays),
         {:ok, periods} <- periods(normalized.periods, start_on, end_on),
         {:ok, closures} <- closures(normalized.closures, start_on, end_on) do
      definition = %Definition{
        academic_year_id: academic_year_id,
        calendar_id: calendar_id,
        closures: closures,
        code: code,
        end_on: end_on,
        institutional_unit_id: institutional_unit_id,
        instructional_weekdays: weekdays,
        label: label,
        periods: periods,
        start_on: start_on,
        time_zone: time_zone
      }

      instructional_dates = instructional_dates(definition)

      {:ok,
       %Preview{
         candidate_revision: candidate_revision(definition),
         definition: definition,
         instructional_date_count: length(instructional_dates),
         instructional_dates: instructional_dates
       }}
    end
  end

  @spec resolve_date(Preview.t(), Date.t()) ::
          {:ok, Resolution.t()} | {:error, Error.t()}
  def resolve_date(%Preview{definition: %Definition{} = definition} = preview, %Date{} = date) do
    if Date.before?(date, definition.start_on) or Date.after?(date, definition.end_on) do
      error(:not_found, :local_date)
    else
      period = Enum.find(definition.periods, &contains?(&1.start_on, &1.end_on, date))
      closure = Enum.find(definition.closures, &(&1.date == date))

      {status, reason} = resolution_status(period, closure, date, definition)

      {:ok,
       %Resolution{
         academic_period_id: period && period.id,
         academic_year_id: definition.academic_year_id,
         calendar_id: definition.calendar_id,
         candidate_revision: preview.candidate_revision,
         closure_id: closure && closure.id,
         closure_reason_key: closure && closure.reason_key,
         institutional_unit_id: definition.institutional_unit_id,
         local_date: date,
         reason: reason,
         status: status
       }}
    end
  end

  def resolve_date(%Preview{}, _date), do: error(:invalid_input, :local_date)
  def resolve_date(_preview, _date), do: error(:invalid_input, :preview)

  defp periods(value, year_start, year_end) when is_list(value) and value != [] do
    with {:ok, normalized} <- map_all(value, &period(&1, year_start, year_end)),
         :ok <- unique_by(normalized, & &1.id, :period_id),
         :ok <- unique_by(normalized, & &1.sequence, :period_sequence),
         sorted = Enum.sort_by(normalized, &{&1.start_on, &1.end_on, &1.sequence}),
         :ok <- non_overlapping(sorted) do
      {:ok, Enum.sort_by(normalized, & &1.sequence)}
    end
  end

  defp periods(_value, _year_start, _year_end), do: error(:invalid_input, :periods)

  defp period(value, year_start, year_end) do
    with {:ok, normalized} <- exact_map(value, @period_keys, :period),
         {:ok, id} <- uuid(normalized.id, :period_id),
         {:ok, label} <- bounded_label(normalized.label, :period_label),
         {:ok, period_type_key} <- bounded_key(normalized.period_type_key, :period_type_key),
         true <- is_integer(normalized.sequence) and normalized.sequence > 0,
         {:ok, start_on, end_on} <-
           date_range(normalized.start_on, normalized.end_on, :period),
         true <- not Date.before?(start_on, year_start) and not Date.after?(end_on, year_end) do
      {:ok,
       %Period{
         end_on: end_on,
         id: id,
         label: label,
         period_type_key: period_type_key,
         sequence: normalized.sequence,
         start_on: start_on
       }}
    else
      false -> error(:outside_year, :period)
      {:error, %Error{}} = error -> error
    end
  end

  defp closures(value, year_start, year_end) when is_list(value) do
    with {:ok, normalized} <- map_all(value, &closure(&1, year_start, year_end)),
         :ok <- unique_by(normalized, & &1.id, :closure_id),
         :ok <- unique_by(normalized, & &1.date, :closure_date) do
      {:ok, Enum.sort_by(normalized, & &1.date)}
    end
  end

  defp closures(_value, _year_start, _year_end), do: error(:invalid_input, :closures)

  defp closure(value, year_start, year_end) do
    with {:ok, normalized} <- exact_map(value, @closure_keys, :closure),
         {:ok, id} <- uuid(normalized.id, :closure_id),
         %Date{} = date <- normalized.date,
         true <- contains?(year_start, year_end, date),
         {:ok, reason_key} <- bounded_key(normalized.reason_key, :closure_reason_key),
         {:ok, label} <- bounded_label(normalized.label, :closure_label) do
      {:ok, %Closure{date: date, id: id, label: label, reason_key: reason_key}}
    else
      false -> error(:outside_year, :closure_date)
      {:error, %Error{}} = error -> error
      _invalid -> error(:invalid_input, :closure)
    end
  end

  defp weekdays(value) when is_list(value) and value != [] do
    if Enum.all?(value, &(is_integer(&1) and &1 in 1..7)) do
      normalized = Enum.sort(value)

      if Enum.uniq(normalized) == normalized do
        {:ok, normalized}
      else
        error(:duplicate, :instructional_weekdays)
      end
    else
      error(:invalid_input, :instructional_weekdays)
    end
  end

  defp weekdays(_value), do: error(:invalid_input, :instructional_weekdays)

  defp time_zone(value) when is_binary(value) do
    normalized = String.trim(value)

    if byte_size(normalized) <= 80 and Regex.match?(@time_zone_pattern, normalized) do
      {:ok, normalized}
    else
      error(:unsupported_time_zone, :time_zone)
    end
  end

  defp time_zone(_value), do: error(:unsupported_time_zone, :time_zone)

  defp date_range(%Date{} = start_on, %Date{} = end_on, field) do
    if Date.after?(start_on, end_on) do
      error(:invalid_date_range, field)
    else
      {:ok, start_on, end_on}
    end
  end

  defp date_range(_start_on, _end_on, field), do: error(:invalid_input, field)

  defp bounded_year(start_on, end_on) do
    if Date.diff(end_on, start_on) + 1 <= @maximum_year_days do
      :ok
    else
      error(:invalid_date_range, :year)
    end
  end

  defp bounded_key(value, field) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    if Regex.match?(@key_pattern, normalized) do
      {:ok, normalized}
    else
      error(:invalid_input, field)
    end
  end

  defp bounded_key(_value, field), do: error(:invalid_input, field)

  defp bounded_label(value, field) when is_binary(value) do
    normalized = String.trim(value)

    if String.length(normalized) in 1..160 do
      {:ok, normalized}
    else
      error(:invalid_input, field)
    end
  end

  defp bounded_label(_value, field), do: error(:invalid_input, field)

  defp uuid(value, field) do
    case UUID.cast(value) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> error(:invalid_input, field)
    end
  end

  defp exact_map(value, keys, field) when is_map(value) and not is_struct(value) do
    if Enum.sort(Map.keys(value)) == Enum.sort(keys) do
      {:ok, value}
    else
      error(:invalid_input, field)
    end
  end

  defp exact_map(_value, _keys, field), do: error(:invalid_input, field)

  defp map_all(values, mapper) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case mapper.(value) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, %Error{}} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp unique_by(values, mapper, field) do
    identities = Enum.map(values, mapper)

    if length(identities) == MapSet.size(MapSet.new(identities)) do
      :ok
    else
      error(:duplicate, field)
    end
  end

  defp non_overlapping([]), do: :ok
  defp non_overlapping([_period]), do: :ok

  defp non_overlapping([earlier, later | rest]) do
    if Date.before?(earlier.end_on, later.start_on) do
      non_overlapping([later | rest])
    else
      error(:overlap, :periods)
    end
  end

  defp instructional_dates(definition) do
    closures = MapSet.new(Enum.map(definition.closures, & &1.date))

    definition.periods
    |> Enum.flat_map(fn period -> Enum.to_list(Date.range(period.start_on, period.end_on)) end)
    |> Enum.filter(fn date ->
      Date.day_of_week(date) in definition.instructional_weekdays and
        not MapSet.member?(closures, date)
    end)
    |> Enum.uniq()
    |> Enum.sort(Date)
  end

  defp candidate_revision(definition) do
    definition
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(definition) do
    {
      definition.calendar_id,
      definition.institutional_unit_id,
      definition.academic_year_id,
      definition.code,
      definition.label,
      Date.to_iso8601(definition.start_on),
      Date.to_iso8601(definition.end_on),
      definition.time_zone,
      definition.instructional_weekdays,
      Enum.map(definition.periods, fn period ->
        {period.id, period.period_type_key, period.label, period.sequence,
         Date.to_iso8601(period.start_on), Date.to_iso8601(period.end_on)}
      end),
      Enum.map(definition.closures, fn closure ->
        {closure.id, Date.to_iso8601(closure.date), closure.reason_key, closure.label}
      end)
    }
  end

  defp contains?(start_on, end_on, date),
    do: not Date.before?(date, start_on) and not Date.after?(date, end_on)

  defp resolution_status(_period, %Closure{}, _date, _definition),
    do: {:non_instructional, :closure}

  defp resolution_status(nil, nil, _date, _definition),
    do: {:non_instructional, :outside_period}

  defp resolution_status(%Period{}, nil, date, definition) do
    if Date.day_of_week(date) in definition.instructional_weekdays do
      {:instructional, :instructional_weekday}
    else
      {:non_instructional, :ordinary_weekday_off}
    end
  end

  defp error(code, field), do: {:error, %Error{code: code, field: field}}
end
