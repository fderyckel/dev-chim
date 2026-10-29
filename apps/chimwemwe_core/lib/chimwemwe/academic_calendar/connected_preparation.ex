defmodule Chimwemwe.AcademicCalendar.ConnectedPreparation do
  @moduledoc """
  Disabled local CF-3 adapter for one server-selected synthetic calendar.

  Calendar and institution identities come from startup-owned configuration,
  never from browser input. Every read and transition delegates to the exact
  session-aware academic-calendar writer action.
  """

  alias Chimwemwe.AcademicCalendar.{Error, Foundation, Runtime}
  alias Ecto.UUID

  @target_keys [:academic_year_id, :calendar_id, :institutional_unit_id]
  @save_keys [
    :causation_id,
    :closures,
    :code,
    :end_on,
    :expected_version,
    :idempotency_key,
    :instructional_weekdays,
    :label,
    :periods,
    :start_on,
    :time_zone
  ]
  @publish_keys [:causation_id, :expected_version, :idempotency_key]

  @spec target(term()) :: {:ok, map()} | {:error, Error.t()}
  def target(value) when is_list(value), do: value |> Map.new() |> target()

  def target(value) when is_map(value) and not is_struct(value) do
    with true <- Enum.sort(Map.keys(value)) == Enum.sort(@target_keys),
         {:ok, calendar_id} <- uuid(value.calendar_id),
         {:ok, academic_year_id} <- uuid(value.academic_year_id),
         {:ok, institutional_unit_id} <- uuid(value.institutional_unit_id) do
      {:ok,
       %{
         calendar_id: calendar_id,
         academic_year_id: academic_year_id,
         institutional_unit_id: institutional_unit_id
       }}
    else
      _invalid -> error(:invalid_input)
    end
  end

  def target(_value), do: error(:invalid_input)

  @spec read(Supervisor.supervisor(), term(), map()) :: {:ok, map()} | {:error, term()}
  def read(persistence, request, target) do
    with {:ok, runtime} <- Runtime.new(persistence),
         {:ok, target} <- target(target),
         {:ok, view} <- read_exact(runtime, request, target),
         :ok <- correct_owner(view, target) do
      {:ok, render_view(view)}
    end
  end

  @spec save(Supervisor.supervisor(), term(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  def save(persistence, request, target, input) do
    with {:ok, runtime} <- Runtime.new(persistence),
         {:ok, target} <- target(target),
         {:ok, input} <- normalize_save(input, target),
         {:ok, _result} <- Foundation.replace_draft_calendar_definition(runtime, request, input),
         {:ok, view} <-
           Foundation.preview_academic_year_publication(
             runtime,
             request,
             target.calendar_id,
             target.academic_year_id
           ),
         :ok <- correct_owner(view, target) do
      {:ok, render_view(view)}
    end
  end

  @spec publish(Supervisor.supervisor(), term(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  def publish(persistence, request, target, input) do
    with {:ok, runtime} <- Runtime.new(persistence),
         {:ok, target} <- target(target),
         {:ok, input} <- normalize_publish(input, target),
         {:ok, _result} <- Foundation.publish_academic_year(runtime, request, input),
         {:ok, view} <-
           Foundation.read_published_academic_year(
             runtime,
             request,
             target.calendar_id,
             target.academic_year_id
           ),
         :ok <- correct_owner(view, target) do
      {:ok, render_view(view)}
    end
  end

  @spec resolve(Supervisor.supervisor(), term(), map(), term()) ::
          {:ok, map()} | {:error, term()}
  def resolve(persistence, request, target, local_date) do
    with {:ok, runtime} <- Runtime.new(persistence),
         {:ok, target} <- target(target),
         {:ok, local_date} <- date(local_date),
         {:ok, resolution} <-
           Foundation.resolve_instructional_context(
             runtime,
             request,
             target.calendar_id,
             local_date
           ),
         true <- resolution.academic_year_id == target.academic_year_id,
         true <- resolution.institutional_unit_id == target.institutional_unit_id do
      {:ok,
       %{
         academic_period_id: resolution.academic_period_id,
         candidate_revision: resolution.candidate_revision,
         closure_id: resolution.closure_id,
         closure_reason_key: resolution.closure_reason_key,
         local_date: Date.to_iso8601(resolution.local_date),
         reason: Atom.to_string(resolution.reason),
         status: Atom.to_string(resolution.status)
       }}
    else
      false -> error(:forbidden)
      other -> other
    end
  end

  defp read_exact(runtime, request, target) do
    case Foundation.read_published_academic_year(
           runtime,
           request,
           target.calendar_id,
           target.academic_year_id
         ) do
      {:ok, view} ->
        {:ok, view}

      {:error, %Error{code: :not_found}} ->
        Foundation.preview_academic_year_publication(
          runtime,
          request,
          target.calendar_id,
          target.academic_year_id
        )

      other ->
        other
    end
  end

  defp normalize_save(input, target) when is_map(input) and not is_struct(input) do
    with true <- Enum.sort(Map.keys(input)) == Enum.sort(@save_keys),
         {:ok, start_on} <- date(input.start_on),
         {:ok, end_on} <- date(input.end_on),
         {:ok, periods} <- normalize_periods(input.periods),
         {:ok, closures} <- normalize_closures(input.closures) do
      {:ok,
       input
       |> Map.merge(Map.take(target, [:calendar_id, :academic_year_id]))
       |> Map.put(:start_on, start_on)
       |> Map.put(:end_on, end_on)
       |> Map.put(:periods, periods)
       |> Map.put(:closures, closures)}
    else
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_save(_input, _target), do: error(:invalid_input)

  defp normalize_publish(input, target) when is_map(input) and not is_struct(input) do
    if Enum.sort(Map.keys(input)) == Enum.sort(@publish_keys),
      do: {:ok, Map.merge(input, Map.take(target, [:calendar_id, :academic_year_id]))},
      else: error(:invalid_input)
  end

  defp normalize_publish(_input, _target), do: error(:invalid_input)

  defp normalize_periods(periods) when is_list(periods),
    do:
      map_all(periods, fn
        %{start_on: start_on, end_on: end_on} = period ->
          with {:ok, start_on} <- date(start_on), {:ok, end_on} <- date(end_on) do
            {:ok, %{period | start_on: start_on, end_on: end_on}}
          end

        _invalid ->
          error(:invalid_input)
      end)

  defp normalize_periods(_periods), do: error(:invalid_input)

  defp normalize_closures(closures) when is_list(closures),
    do:
      map_all(closures, fn
        %{date: value} = closure ->
          with {:ok, value} <- date(value), do: {:ok, %{closure | date: value}}

        _invalid ->
          error(:invalid_input)
      end)

  defp normalize_closures(_closures), do: error(:invalid_input)

  defp map_all(values, mapper) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case mapper.(value) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, %Error{}} = failure -> {:halt, failure}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      failure -> failure
    end
  end

  defp correct_owner(view, target) do
    if view.preview.definition.institutional_unit_id == target.institutional_unit_id,
      do: :ok,
      else: error(:forbidden)
  end

  defp render_view(view) do
    preview = view.preview
    definition = preview.definition

    %{
      candidate_revision: preview.candidate_revision,
      instructional_date_count: preview.instructional_date_count,
      lock_version: view.lock_version,
      status: Atom.to_string(view.status),
      definition: %{
        code: definition.code,
        closures:
          Enum.map(definition.closures, fn closure ->
            %{
              date: Date.to_iso8601(closure.date),
              id: closure.id,
              label: closure.label,
              reason_key: closure.reason_key
            }
          end),
        end_on: Date.to_iso8601(definition.end_on),
        instructional_weekdays: definition.instructional_weekdays,
        label: definition.label,
        periods:
          Enum.map(definition.periods, fn period ->
            %{
              end_on: Date.to_iso8601(period.end_on),
              id: period.id,
              label: period.label,
              period_type_key: period.period_type_key,
              sequence: period.sequence,
              start_on: Date.to_iso8601(period.start_on)
            }
          end),
        start_on: Date.to_iso8601(definition.start_on),
        time_zone: definition.time_zone
      }
    }
  end

  defp date(%Date{} = value), do: {:ok, value}

  defp date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _invalid -> error(:invalid_input)
    end
  end

  defp date(_value), do: error(:invalid_input)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> error(:invalid_input)
    end
  end

  defp error(code), do: {:error, %Error{code: code}}
end
