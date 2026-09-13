defmodule AshFoundationLab.Telemetry do
  @moduledoc """
  Minimal, allowlisted telemetry for the disposable JSON:API pressure-test.

  The event deliberately excludes the connection, actor, request parameters,
  record identifiers, and payload. Tenant identity is represented by a stable
  one-way reference so operational correlation does not disclose the raw key.
  """

  @event_name [:ash_foundation_lab, :json_api, :dispatch]
  @event_version 1

  @doc "Returns the event name used by capture tests and future handlers."
  def event_name, do: @event_name

  @doc "Emits sanitized metadata immediately before JSON:API dispatch."
  def before_json_api_dispatch(conn, route_info) do
    context = Ash.PlugHelpers.get_context(conn) || %{}

    :telemetry.execute(
      @event_name,
      %{count: 1},
      %{
        action: action_name(route_info),
        classification: :internal,
        correlation_id: Map.get(context, :correlation_id),
        event_version: @event_version,
        tenant_reference: tenant_reference(Ash.PlugHelpers.get_tenant(conn)),
        transport: :json_api
      }
    )

    conn
  end

  defp action_name(%{route: %{action: action}}), do: action
  defp action_name(route_info) when is_atom(route_info), do: route_info

  defp tenant_reference(nil), do: :missing

  defp tenant_reference(tenant) do
    digest =
      tenant
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 24)

    "tenant-#{digest}"
  end
end
