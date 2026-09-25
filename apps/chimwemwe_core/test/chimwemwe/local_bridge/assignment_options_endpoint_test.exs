defmodule Chimwemwe.LocalBridge.AssignmentOptionsEndpointTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias Chimwemwe.LocalBridge.{Router, SessionStore, Supervisor, SyntheticData}

  @path "/api/v1/authority/assignment-options"
  @valid_token "valid-local-token-" <> String.duplicate("a", 32)
  @denied_token "denied-local-token-" <> String.duplicate("b", 32)
  @stale_token "stale-local-token-" <> String.duplicate("c", 32)

  setup do
    supervisor =
      start_supervised!(
        {Supervisor,
         token: @valid_token,
         port: 4001,
         repository_options: repository_options(),
         start_endpoint?: false,
         additional_sessions: [
           {@denied_token, SyntheticData.denied_session()},
           {@stale_token, SyntheticData.stale_session()}
         ]}
      )

    {:ok, supervisor: supervisor}
  end

  test "returns only tenant-qualified browser-safe assignment options" do
    conn = request(@valid_token)

    assert conn.status == 200
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "x-api-version") == ["v1"]

    assert %{
             "data" => %{
               "connection" => "local_core",
               "contract_version" => 1,
               "memberships" => memberships,
               "roles" => roles
             }
           } = Jason.decode!(conn.resp_body)

    assert Enum.map(memberships, & &1["label"]) == [
             "Synthetic membership 01",
             "Synthetic membership 02",
             "Synthetic membership 03"
           ]

    assert Enum.map(roles, & &1["label"]) == [
             "Assignment manager",
             "Library review",
             "Operations review"
           ]

    refute conn.resp_body =~ "Separate tenant role"

    for restricted <- [
          SyntheticData.tenant_a(),
          SyntheticData.tenant_b(),
          SyntheticData.manager_a(),
          SyntheticData.manager_b(),
          "capability",
          "placement",
          "repository",
          "routing"
        ] do
      refute conn.resp_body =~ restricted
    end
  end

  test "fails closed for missing and invalid local sessions" do
    for token <- [nil, "not-the-session-token"] do
      conn = request(token)

      assert conn.status == 401
      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert get_resp_header(conn, "x-api-version") == ["v1"]

      assert %{"errors" => [%{"code" => "unauthenticated"}]} =
               Jason.decode!(conn.resp_body)
    end
  end

  test "fails closed when the actor lacks the required capability" do
    conn = request(@denied_token)

    assert conn.status == 403
    assert %{"errors" => [%{"code" => "forbidden"}]} = Jason.decode!(conn.resp_body)
    refute conn.resp_body =~ "Assignment manager"
  end

  test "returns a stable retryable response for stale server-owned placement" do
    conn = request(@stale_token)

    assert conn.status == 503

    assert %{"errors" => [%{"code" => "retryable_dependency"}]} =
             Jason.decode!(conn.resp_body)

    refute conn.resp_body =~ SyntheticData.tenant_a()
  end

  test "keeps raw session tokens out of process state" do
    state = :sys.get_state(SessionStore)

    refute Map.has_key?(state, @valid_token)
    refute inspect(state) =~ @valid_token
    assert Map.has_key?(state, :crypto.hash(:sha256, @valid_token))
  end

  test "exposes a GET route and no browser write route" do
    routes = Router.__routes__()

    assert Enum.any?(routes, &(&1.verb == :get and &1.path == @path))

    refute Enum.any?(routes, fn route ->
             route.verb in [:post, :put, :patch, :delete] and route.path == @path
           end)
  end

  defp request(token) do
    :get
    |> conn(@path)
    |> put_req_header("accept", "application/json")
    |> maybe_authorize(token)
    |> Router.call(Router.init([]))
  end

  defp maybe_authorize(conn, nil), do: conn

  defp maybe_authorize(conn, token),
    do: put_req_header(conn, "authorization", "Bearer #{token}")

  defp repository_options do
    Application.fetch_env!(:chimwemwe_core, Chimwemwe.Repo)
    |> Keyword.put(:pool, DBConnection.ConnectionPool)
    |> Keyword.put(:pool_size, 4)
  end
end
