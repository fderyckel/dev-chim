defmodule Chimwemwe.PublicApi.ClassroomController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]
  alias Chimwemwe.Classroom.Attendance
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  def classes(conn, params) when map_size(params) == 0,
    do: execute(conn, &Attendance.assigned_classes/2)

  def classes(conn, _params), do: invalid(conn)

  def prepare(conn, %{"class_id" => id} = params) when map_size(params) == 1,
    do: execute(conn, &Attendance.prepare(&1, &2, id))

  def prepare(conn, _params), do: invalid(conn)

  def submit(conn, params) do
    keys = [
      :class_id,
      :local_date,
      :calendar_revision,
      :roster_basis,
      :marks,
      :idempotency_key,
      :causation_id
    ]

    if Enum.sort(Map.keys(params)) == Enum.sort(Enum.map(keys, &Atom.to_string/1)) do
      input = Map.new(keys, &{&1, Map.fetch!(params, Atom.to_string(&1))})
      marks = if is_list(input.marks), do: Enum.map(input.marks, &mark/1), else: nil
      execute(conn, &Attendance.submit(&1, &2, %{input | marks: marks}))
    else
      invalid(conn)
    end
  end

  defp mark(%{"person_id" => id, "mark" => mark} = input) when map_size(input) == 2,
    do: %{person_id: id, mark: mark}

  defp mark(_), do: nil

  defp execute(conn, action) do
    {:ok, config} = Config.fetch()

    case action.(config.runtime, conn.assigns.public_request_session) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, %{code: code}} ->
        status =
          cond do
            code == :invalid_input ->
              400

            code in [:conflict, :stale, :idempotency_conflict, :non_instructional, :scope_limit] ->
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
          "Attendance could not be completed. Reload your class or sign in again."
        )
    end
  end

  defp invalid(conn),
    do: ErrorResponse.send(conn, 400, "invalid_input", "Use the exact classroom action fields.")
end
