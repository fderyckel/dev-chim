defmodule AshFoundationLab.JsonApiFailureHeaders do
  @moduledoc """
  Adds bounded retry and cache headers to the Phase 0 public error contract.

  The values describe only the synthetic failure probes. A production limiter or
  dependency adapter must calculate its own trusted retry guidance.
  """

  import Plug.Conn

  alias AshFoundationLab.JsonApiContract

  @doc false
  def init(options), do: options

  @doc false
  def call(conn, _options) do
    register_before_send(conn, &put_failure_headers/1)
  end

  defp put_failure_headers(%Plug.Conn{status: status} = conn)
       when status in [429, 500, 503] do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> maybe_put_retry_after(status)
  end

  defp put_failure_headers(conn), do: conn

  defp maybe_put_retry_after(conn, 429) do
    put_retry_after(conn, JsonApiContract.retry_after_seconds(:rate_limited))
  end

  defp maybe_put_retry_after(conn, 503) do
    put_retry_after(conn, JsonApiContract.retry_after_seconds(:dependency_unavailable))
  end

  defp maybe_put_retry_after(conn, _status), do: conn

  defp put_retry_after(conn, seconds) do
    put_resp_header(conn, "retry-after", Integer.to_string(seconds))
  end
end
