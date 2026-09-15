defmodule AshFoundationLab.JsonApiContract do
  @moduledoc """
  Version and error contract for the disposable Phase 0 generated interface.

  The stable codes are transport evidence only. They do not establish a production
  API or prevent the Phase 0 review from selecting the explicit-adapter fallback.
  """

  import Plug.Conn, only: [put_resp_header: 3]

  alias AshFoundationLab.Telemetry
  alias AshJsonApi.Error
  alias OpenApiSpex.Header
  alias OpenApiSpex.Schema

  @api_version "v1"
  @maximum_page_size 3
  @list_path "/api/v1/foundation-records"
  @transition_path "/api/v1/foundation-records/{id}/submit-for-review"
  @rate_limit_retry_after_seconds 5
  @dependency_retry_after_seconds 2
  @validation_codes ~w(invalid invalid_argument invalid_attribute invalid_body no_such_input required)

  @doc "Returns the URL and metadata version exercised by this spike."
  def api_version, do: @api_version

  @doc "Returns the maximum public page size exercised by this spike."
  def maximum_page_size, do: @maximum_page_size

  @doc "Returns bounded retry guidance for one synthetic transient failure category."
  def retry_after_seconds(:rate_limited), do: @rate_limit_retry_after_seconds
  def retry_after_seconds(:dependency_unavailable), do: @dependency_retry_after_seconds

  @doc "Adds version metadata and preserves the existing allowlisted telemetry hook."
  def before_dispatch(conn, route_info) do
    conn
    |> Telemetry.before_json_api_dispatch(route_info)
    |> put_resp_header("x-api-version", @api_version)
  end

  @doc "Normalizes generated errors to the bounded public taxonomy."
  def handle_error(%Error{} = error, _context) do
    normalized = normalize_error(error)
    %{normalized | meta: public_meta(normalized)}
  end

  @doc "Adds the edge-enforced page maximum omitted by the generated schema."
  def modify_open_api(spec, _conn, _options) do
    spec
    |> document_page_limit()
    |> document_action_failures()
  end

  defp document_page_limit(spec) do
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

  defp document_action_failures(spec) do
    path_item = Map.fetch!(spec.paths, @transition_path)
    operation = path_item.patch
    error_response = Map.fetch!(spec.components.responses, "errors")

    responses =
      operation.responses
      |> Map.put(
        429,
        transient_response(
          error_response,
          "Request capacity is temporarily unavailable",
          @rate_limit_retry_after_seconds
        )
      )
      |> Map.put(500, %{error_response | description: "Internal failure"})
      |> Map.put(
        503,
        transient_response(
          error_response,
          "Required dependency is temporarily unavailable",
          @dependency_retry_after_seconds
        )
      )

    updated_path = %{path_item | patch: %{operation | responses: responses}}
    %{spec | paths: Map.put(spec.paths, @transition_path, updated_path)}
  end

  defp transient_response(error_response, description, retry_after_seconds) do
    retry_after = %Header{
      description: "Minimum whole seconds before a caller-controlled retry",
      required: true,
      schema: %Schema{type: :integer, minimum: 0, example: retry_after_seconds}
    }

    %{error_response | description: description, headers: %{"Retry-After" => retry_after}}
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

  @doc false
  def rate_limited_error do
    stable_error(
      429,
      "rate_limited",
      "RateLimited",
      "Request capacity is temporarily unavailable."
    )
  end

  @doc false
  def dependency_unavailable_error do
    stable_error(
      503,
      "dependency_unavailable",
      "DependencyUnavailable",
      "A required dependency is temporarily unavailable."
    )
  end

  @doc false
  def internal_failure_error do
    stable_error(500, "internal_error", "InternalError", "An internal error occurred.")
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

  defp normalize_error(%Error{code: "rate_limited"} = error) do
    %{
      error
      | status_code: 429,
        title: "RateLimited",
        detail: "Request capacity is temporarily unavailable."
    }
  end

  defp normalize_error(%Error{code: "dependency_unavailable"} = error) do
    %{
      error
      | status_code: 503,
        title: "DependencyUnavailable",
        detail: "A required dependency is temporarily unavailable."
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

  defp public_meta(%Error{code: "rate_limited"}) do
    %{
      "api_version" => @api_version,
      "retry_after_seconds" => @rate_limit_retry_after_seconds,
      "retryable" => true
    }
  end

  defp public_meta(%Error{code: "dependency_unavailable"}) do
    %{
      "api_version" => @api_version,
      "retry_after_seconds" => @dependency_retry_after_seconds,
      "retryable" => true
    }
  end

  defp public_meta(_error), do: %{"api_version" => @api_version}

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

defimpl AshJsonApi.ToJsonApiError, for: AshFoundationLab.Error.RateLimited do
  def to_json_api_error(_error), do: AshFoundationLab.JsonApiContract.rate_limited_error()
end

defimpl AshJsonApi.ToJsonApiError, for: AshFoundationLab.Error.DependencyUnavailable do
  def to_json_api_error(_error),
    do: AshFoundationLab.JsonApiContract.dependency_unavailable_error()
end

defimpl AshJsonApi.ToJsonApiError, for: AshFoundationLab.Error.ForcedInternal do
  def to_json_api_error(_error), do: AshFoundationLab.JsonApiContract.internal_failure_error()
end
