defmodule AshFoundationLab.JsonApiContract do
  @moduledoc """
  Version and error contract for the disposable Phase 0 generated interface.

  The stable codes are transport evidence only. They do not establish a production
  API or prevent the Phase 0 review from selecting the explicit-adapter fallback.
  """

  import Plug.Conn, only: [put_resp_header: 3]

  alias AshFoundationLab.Telemetry
  alias AshJsonApi.Error

  @api_version "v1"
  @maximum_page_size 3
  @list_path "/api/v1/foundation-records"
  @validation_codes ~w(invalid invalid_argument invalid_attribute no_such_input required)

  @doc "Returns the URL and metadata version exercised by this spike."
  def api_version, do: @api_version

  @doc "Returns the maximum public page size exercised by this spike."
  def maximum_page_size, do: @maximum_page_size

  @doc "Adds version metadata and preserves the existing allowlisted telemetry hook."
  def before_dispatch(conn, route_info) do
    conn
    |> Telemetry.before_json_api_dispatch(route_info)
    |> put_resp_header("x-api-version", @api_version)
  end

  @doc "Normalizes generated errors to the bounded public taxonomy."
  def handle_error(%Error{} = error, _context) do
    error
    |> normalize_error()
    |> Map.put(:meta, %{"api_version" => @api_version})
  end

  @doc "Adds the edge-enforced page maximum omitted by the generated schema."
  def modify_open_api(spec, _conn, _options) do
    path_item = Map.fetch!(spec.paths, @list_path)
    operation = path_item.get

    parameters =
      Enum.map(operation.parameters, fn
        %{name: "page"} = parameter ->
          limit = Map.fetch!(parameter.schema.properties, :limit)

          properties =
            Map.put(parameter.schema.properties, :limit, %{limit | maximum: @maximum_page_size})

          %{parameter | schema: %{parameter.schema | properties: properties}}

        parameter ->
          parameter
      end)

    updated_path = %{path_item | get: %{operation | parameters: parameters}}
    %{spec | paths: Map.put(spec.paths, @list_path, updated_path)}
  end

  @doc false
  def tenant_required_error do
    stable_error(
      400,
      "missing_tenant_context",
      "MissingTenantContext",
      "Trusted tenant context is required."
    )
  end

  @doc false
  def stale_record_error do
    stable_error(
      409,
      "conflict",
      "Conflict",
      "The resource changed before this action completed."
    )
  end

  @doc false
  def idempotency_conflict_error do
    stable_error(
      409,
      "idempotency_conflict",
      "IdempotencyConflict",
      "The idempotency key was already used for a different request."
    )
  end

  defp normalize_error(%Error{code: code} = error) when code in @validation_codes do
    %{
      error
      | status_code: 422,
        code: "validation_failed",
        title: "ValidationFailed",
        detail: "The request failed validation."
    }
  end

  defp normalize_error(%Error{code: "forbidden"} = error) do
    %{
      error
      | status_code: 403,
        code: "forbidden",
        title: "Forbidden",
        detail: "The request is not authorized."
    }
  end

  defp normalize_error(%Error{code: "not_found"} = error) do
    %{
      error
      | status_code: 404,
        code: "not_found",
        title: "NotFound",
        detail: "The requested resource was not found."
    }
  end

  defp normalize_error(%Error{code: "missing_tenant_context"} = error) do
    %{
      error
      | status_code: 400,
        title: "MissingTenantContext",
        detail: "Trusted tenant context is required."
    }
  end

  defp normalize_error(%Error{code: "conflict"} = error) do
    %{
      error
      | status_code: 409,
        title: "Conflict",
        detail: "The resource changed before this action completed."
    }
  end

  defp normalize_error(%Error{code: "idempotency_conflict"} = error) do
    %{
      error
      | status_code: 409,
        title: "IdempotencyConflict",
        detail: "The idempotency key was already used for a different request."
    }
  end

  defp normalize_error(%Error{status_code: status_code} = error) when status_code >= 500 do
    %{
      error
      | status_code: 500,
        code: "internal_error",
        title: "InternalError",
        detail: "An internal error occurred."
    }
  end

  defp normalize_error(error) do
    %{
      error
      | status_code: 500,
        code: "internal_error",
        title: "InternalError",
        detail: "An internal error occurred."
    }
  end

  defp stable_error(status_code, code, title, detail) do
    %Error{
      id: Ash.UUID.generate(),
      status_code: status_code,
      code: code,
      title: title,
      detail: detail,
      meta: %{}
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Invalid.TenantRequired do
  def to_json_api_error(_error), do: AshFoundationLab.JsonApiContract.tenant_required_error()
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Changes.StaleRecord do
  def to_json_api_error(_error), do: AshFoundationLab.JsonApiContract.stale_record_error()
end

defimpl AshJsonApi.ToJsonApiError, for: AshFoundationLab.Error.IdempotencyConflict do
  def to_json_api_error(_error),
    do: AshFoundationLab.JsonApiContract.idempotency_conflict_error()
end
