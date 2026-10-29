defmodule Chimwemwe.PublicApi.StaffAccountsController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]
  alias Chimwemwe.Identity.StaffDirectory
  alias Chimwemwe.PublicApi.ErrorResponse

  def index(conn, params) when map_size(params) == 0 do
    execute(conn, fn runtime, context ->
      with {:ok, result} <- StaffDirectory.inventory(runtime, context),
           {:ok, prefs} <- StaffDirectory.preferences(runtime, context) do
        {:ok,
         Map.merge(result, %{
           locale: prefs.locale,
           institution_label: conn.assigns.staff_config.institution_label
         })}
      end
    end)
  end

  def index(conn, _params), do: invalid(conn)

  def preferences(conn, params) when map_size(params) == 0,
    do: execute(conn, &StaffDirectory.preferences/2)

  def preferences(conn, _params), do: invalid(conn)

  def provision(conn, params), do: action(conn, params, :provision)
  def revise_details(conn, params), do: action(conn, params, :revise_details)
  def set_access(conn, params), do: action(conn, params, :set_access)
  def revoke_access_profile(conn, params), do: action(conn, params, :revoke_access_profile)
  def suspend_access(conn, params), do: action(conn, params, :suspend_access)
  def reissue(conn, params), do: action(conn, params, :reissue)
  def set_preferences(conn, params), do: action(conn, params, :set_preferences)

  defp action(conn, params, action) do
    keys = action_keys(action)

    if Enum.sort(Map.keys(params)) == Enum.sort(Enum.map(keys, &Atom.to_string/1)) do
      input = Map.new(keys, &{&1, Map.fetch!(params, Atom.to_string(&1))})

      execute(conn, fn runtime, context ->
        apply(StaffDirectory, action, [runtime, context, input])
      end)
    else
      invalid(conn)
    end
  end

  defp action_keys(:provision),
    do: [
      :association_id,
      :email,
      :given_name,
      :family_name,
      :display_name,
      :locale,
      :idempotency_key,
      :causation_id
    ]

  defp action_keys(:revise_details),
    do: [
      :id,
      :expected_version,
      :given_name,
      :family_name,
      :display_name,
      :locale,
      :idempotency_key,
      :causation_id
    ]

  defp action_keys(action) when action in [:set_access, :revoke_access_profile],
    do: [:id, :expected_version, :profile_id, :idempotency_key, :causation_id]

  defp action_keys(:set_preferences),
    do: [:locale, :expected_version, :idempotency_key, :causation_id]

  defp action_keys(_action), do: [:id, :expected_version, :idempotency_key, :causation_id]

  defp execute(conn, operation) do
    config = conn.assigns.staff_config
    request = conn.assigns.public_request_session

    if request.session.tenant_id == config.tenant_id do
      case operation.(config.runtime, request.context) do
        {:ok, result} -> json(conn, %{data: result})
        {:error, %{code: code}} -> failure(conn, code)
        {:error, code} when is_atom(code) -> failure(conn, code)
        _ -> failure(conn, :retryable_dependency)
      end
    else
      failure(conn, :forbidden)
    end
  end

  defp failure(conn, code)
       when code in [:conflict, :stale, :stale_version, :idempotency_conflict],
       do:
         ErrorResponse.send(
           conn,
           409,
           "conflict",
           "The account changed. Reload its current status before continuing."
         )

  defp failure(conn, code) when code in [:invalid_input, :invalid_request], do: invalid(conn)

  defp failure(conn, :retryable_dependency),
    do:
      ErrorResponse.send(
        conn,
        503,
        "retryable_dependency",
        "The account status could not be confirmed. Reload before trying again."
      )

  defp failure(conn, _code),
    do: ErrorResponse.send(conn, 403, "forbidden", "This account action is unavailable.")

  defp invalid(conn),
    do: ErrorResponse.send(conn, 400, "invalid_request", "The account request was not accepted.")
end
