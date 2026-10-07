defmodule Chimwemwe.PublicApi.ClassroomController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]
  alias Chimwemwe.Classroom.{Attendance, Preparation}
  alias Chimwemwe.PublicApi.{Config, ErrorResponse}

  def classes(conn, params) when map_size(params) == 0,
    do: execute(conn, &Attendance.assigned_classes/2)

  def classes(conn, _params), do: invalid(conn)

  def preparation(conn, params) when map_size(params) == 0 do
    execute_preparation(conn, fn config, request, preparation ->
      Preparation.view(config.runtime, request, preparation.workspace_id)
    end)
  end

  def preparation(conn, _params), do: invalid(conn)

  def prepare_class(conn, params) do
    keys = [:code, :label, :idempotency_key, :causation_id]

    if exact_keys?(params, keys) do
      input = Map.new(keys, &{&1, Map.fetch!(params, Atom.to_string(&1))})

      execute_preparation(conn, fn config, request, preparation ->
        Preparation.prepare_class(config.runtime, request, preparation.workspace_id, input)
      end)
    else
      invalid(conn)
    end
  end

  def add_student(conn, params) do
    keys = [:display_name, :idempotency_key, :causation_id]

    if exact_keys?(params, keys) do
      input = Map.new(keys, &{&1, Map.fetch!(params, Atom.to_string(&1))})

      execute_preparation(conn, fn config, request, preparation ->
        Preparation.add_student(
          config.runtime,
          preparation.people_runtime,
          request,
          preparation.workspace_id,
          input
        )
      end)
    else
      invalid(conn)
    end
  end

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

    if exact_keys?(params, keys) do
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

  defp execute_preparation(conn, action) do
    with {:ok, config} <- Config.fetch(),
         preparation when is_map(preparation) <- config.preparation do
      execute_preparation_action(conn, action, config, preparation)
    else
      _unavailable ->
        ErrorResponse.send(
          conn,
          404,
          "not_available",
          "The local classroom preparation workflow is unavailable."
        )
    end
  end

  defp execute_preparation_action(conn, action, config, preparation) do
    case action.(config, conn.assigns.public_request_session, preparation) do
      {:ok, result} -> json(conn, %{data: result})
      {:error, %{code: code}} -> preparation_error(conn, code)
    end
  end

  defp preparation_error(conn, code) do
    status =
      cond do
        code == :invalid_input -> 400
        code in [:conflict, :stale, :idempotency_conflict, :scope_limit] -> 409
        code == :retryable_dependency -> 503
        true -> 403
      end

    ErrorResponse.send(
      conn,
      status,
      Atom.to_string(code),
      "Class preparation could not be completed. Reload the workspace or sign in again."
    )
  end

  defp exact_keys?(params, keys),
    do: Enum.sort(Map.keys(params)) == Enum.sort(Enum.map(keys, &Atom.to_string/1))

  defp invalid(conn),
    do: ErrorResponse.send(conn, 400, "invalid_input", "Use the exact classroom action fields.")
end
