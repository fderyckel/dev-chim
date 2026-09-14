defmodule AshFoundationLab.JsonApiPageLimit do
  @moduledoc """
  Enforces the public list-page limit before generated JSON:API dispatch.

  This is a bounded Phase 0 escape hatch for a verified framework limitation,
  not a production pagination abstraction.
  """

  import Plug.Conn

  alias AshFoundationLab.JsonApiContract

  @list_path ["api", "v1", "foundation-records"]

  @doc false
  def init(options), do: options

  @doc false
  def call(%Plug.Conn{method: "GET", path_info: @list_path} = conn, _options) do
    conn = fetch_query_params(conn)

    case get_in(conn.query_params, ["page", "limit"]) do
      nil -> conn
      limit when is_binary(limit) -> validate_limit(conn, Integer.parse(limit))
      _invalid -> reject(conn)
    end
  end

  def call(conn, _options), do: conn

  defp validate_limit(conn, {limit, ""}) when limit >= 1 do
    if limit <= JsonApiContract.maximum_page_size(), do: conn, else: reject(conn)
  end

  defp validate_limit(conn, _invalid), do: reject(conn)

  defp reject(conn) do
    body =
      Jason.encode!(%{
        "jsonapi" => %{"version" => "1.0"},
        "errors" => [
          %{
            "id" => Ash.UUID.generate(),
            "status" => "400",
            "code" => "invalid_pagination",
            "title" => "InvalidPagination",
            "detail" => "The requested page limit is invalid.",
            "source" => %{"parameter" => "page[limit]"},
            "meta" => %{"api_version" => JsonApiContract.api_version()}
          }
        ]
      })

    conn
    |> JsonApiContract.before_dispatch(:pagination_gate)
    |> put_resp_header("content-type", "application/vnd.api+json")
    |> send_resp(400, body)
    |> halt()
  end
end
