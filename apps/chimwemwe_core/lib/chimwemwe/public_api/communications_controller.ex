defmodule Chimwemwe.PublicApi.CommunicationsController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]
  alias Chimwemwe.Communications.Publication
  alias Chimwemwe.PublicApi.ErrorResponse

  def workspace(conn, params) when map_size(params) == 0,
    do: execute(conn, &Publication.workspace/2)

  def workspace(conn, _params), do: invalid(conn)

  @inputs %{
    create_draft: [:title, :body, :receipt_required, :idempotency_key, :causation_id],
    revise_draft: [
      :notice_id,
      :expected_version,
      :title,
      :body,
      :receipt_required,
      :idempotency_key,
      :causation_id
    ],
    prepare_operation: [
      :notice_id,
      :expected_version,
      :operation,
      :title,
      :body,
      :reason,
      :idempotency_key,
      :causation_id
    ],
    submit_for_approval: [
      :notice_id,
      :expected_version,
      :preparation_id,
      :idempotency_key,
      :causation_id
    ],
    approve_operation: [
      :notice_id,
      :expected_version,
      :preparation_id,
      :idempotency_key,
      :causation_id
    ],
    open_notice: [:notice_id, :revision_id, :idempotency_key, :causation_id],
    confirm_receipt: [:notice_id, :revision_id, :idempotency_key, :causation_id],
    command_outcome: [:notice_id, :action, :idempotency_key]
  }
  for {name, keys} <- @inputs do
    def unquote(name)(conn, params) do
      if Enum.sort(Map.keys(params)) == Enum.sort(Enum.map(unquote(keys), &Atom.to_string/1)) do
        input = Map.new(unquote(keys), &{&1, Map.fetch!(params, Atom.to_string(&1))})
        execute(conn, &Publication.unquote(name)(&1, &2, input))
      else
        invalid(conn)
      end
    end
  end

  for name <- [:inspect_draft, :review_operation, :recipient_status] do
    def unquote(name)(conn, %{"notice_id" => id} = params) when map_size(params) == 1,
      do: execute(conn, &Publication.unquote(name)(&1, &2, id))

    def unquote(name)(conn, _params), do: invalid(conn)
  end

  def metrics(conn, %{"notice_id" => id, "revision_id" => revision} = params)
      when map_size(params) == 2,
      do: execute(conn, &Publication.metrics(&1, &2, id, revision))

  def metrics(conn, _params), do: invalid(conn)

  def receipt(conn, %{"notice_id" => id, "revision_id" => revision} = params)
      when map_size(params) == 2,
      do: execute(conn, &Publication.inspect_own_receipt(&1, &2, id, revision))

  def receipt(conn, _params), do: invalid(conn)

  defp execute(conn, action) do
    config = Application.fetch_env!(:chimwemwe_core, :local_communications)

    case action.(config, conn.assigns.public_request_session) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, %{code: code}} ->
        status =
          cond do
            code == :invalid_input -> 400
            code in [:conflict, :stale, :idempotency_conflict, :scope_limit] -> 409
            code == :rate_limited -> 429
            code == :retryable_dependency -> 503
            true -> 403
          end

        ErrorResponse.send(
          conn,
          status,
          Atom.to_string(code),
          "The notice action was not confirmed. Check its current state or sign in again."
        )
    end
  end

  defp invalid(conn),
    do: ErrorResponse.send(conn, 400, "invalid_input", "Use the exact notice action fields.")
end
