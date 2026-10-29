defmodule Chimwemwe.PublicApi.CalendarController do
  @moduledoc false

  use Phoenix.Controller, formats: [:json]

  alias Chimwemwe.AcademicCalendar.ConnectedPreparation
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

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
  @period_keys [:end_on, :id, :label, :period_type_key, :sequence, :start_on]
  @closure_keys [:date, :id, :label, :reason_key]
  @publish_keys [:causation_id, :expected_version, :idempotency_key]

  def show(conn, params) when map_size(params) == 0,
    do: execute(conn, &ConnectedPreparation.read/3)

  def show(conn, _params), do: invalid(conn)

  def save(conn, params) do
    with {:ok, input} <- exact(params, @save_keys),
         {:ok, periods} <- nested(input.periods, @period_keys),
         {:ok, closures} <- nested(input.closures, @closure_keys) do
      input = %{input | periods: periods, closures: closures}
      execute(conn, &ConnectedPreparation.save(&1, &2, &3, input))
    else
      _invalid -> invalid(conn)
    end
  end

  def publish(conn, params) do
    with {:ok, input} <- exact(params, @publish_keys),
         do: execute(conn, &ConnectedPreparation.publish(&1, &2, &3, input))
  end

  def resolve(conn, %{"local_date" => local_date} = params) when map_size(params) == 1,
    do: execute(conn, &ConnectedPreparation.resolve(&1, &2, &3, local_date))

  def resolve(conn, _params), do: invalid(conn)

  defp execute(conn, action) do
    {:ok, config} = Config.fetch()

    case action.(
           config.runtime,
           conn.assigns.public_request_session,
           conn.assigns.local_calendar_target
         ) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, %{code: code}} ->
        status =
          cond do
            code in [
              :duplicate,
              :invalid_date_range,
              :invalid_input,
              :not_found,
              :outside_year,
              :overlap,
              :unsupported_time_zone
            ] ->
              400

            code in [:conflict, :stale, :idempotency_conflict] ->
              409

            code == :retryable_dependency ->
              503

            true ->
              403
          end

        ErrorResponse.send(
          conn,
          status,
          Atom.to_string(code),
          "The calendar action could not be completed. Reload the calendar or sign in again."
        )
    end
  end

  defp exact(params, keys) when is_map(params) do
    string_keys = Enum.map(keys, &Atom.to_string/1)

    if Enum.sort(Map.keys(params)) == Enum.sort(string_keys),
      do: {:ok, Map.new(keys, &{&1, Map.fetch!(params, Atom.to_string(&1))})},
      else: :error
  end

  defp nested(values, keys) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case exact(value, keys) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      :error -> :error
    end
  end

  defp nested(_values, _keys), do: :error

  defp invalid(conn),
    do: ErrorResponse.send(conn, 400, "invalid_input", "Use the exact calendar action fields.")
end
