defmodule Chimwemwe.PublicApi.CommunicationsTest do
  use ExUnit.Case, async: false
  alias Chimwemwe.PublicApi.CommunicationsOpenApi
  import Plug.Conn
  alias Chimwemwe.Classroom.Fixture, as: Classroom
  alias Chimwemwe.Communications.{Fixture, LocalRequestGate}
  alias Chimwemwe.Identity.PublicSessionAdapter
  alias Chimwemwe.People.StaffAudienceFixture
  alias Chimwemwe.Platform.PersistenceRuntime
  alias Chimwemwe.PublicApi.Router
  @origin "https://localhost:3025"
  @keys [
    :public_api,
    :local_communications,
    :public_session_cookie_keys,
    :identity_session_hmac_secret
  ]

  setup do
    old = Map.new(@keys, &{&1, Application.get_env(:chimwemwe_core, &1)})

    Application.put_env(
      :chimwemwe_core,
      :identity_session_hmac_secret,
      :crypto.strong_rand_bytes(48)
    )

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
      Base.encode64(:crypto.strong_rand_bytes(48))
    ])

    runtime = start_supervised!({PersistenceRuntime, Classroom.runtime_options()})
    {:ok, f} = Classroom.seed!(runtime)
    f = Fixture.connect!(f)
    Application.put_env(:chimwemwe_core, :local_communications, f.communications)

    Application.put_env(:chimwemwe_core, :public_api,
      runtime: runtime,
      verifier: Fixture,
      origin: @origin
    )

    cookie = Fixture.cookie!(f, f.request)

    on_exit(fn ->
      for {key, value} <- old,
          do:
            if(is_nil(value),
              do: Application.delete_env(:chimwemwe_core, key),
              else: Application.put_env(:chimwemwe_core, key, value)
            )

      for agent <- [f.source, f.account_source],
          do: if(Process.alive?(agent), do: Agent.stop(agent))

      StaffAudienceFixture.cleanup!()
    end)

    Map.put(f, :cookie, cookie)
  end

  test "named writes require current cookie, origin and CSRF; unsupported selection fields are rejected",
       f do
    input =
      Map.merge(Classroom.keys(), %{
        title: "Fictional notice",
        body: "Fictional staff only.",
        receipt_required: false
      })

    assert request(:post, "/api/v1/communications/create-draft", input).status == 401
    assert request(:post, "/api/v1/communications/create-draft", input, f.cookie).status == 403
    csrf = csrf(f.cookie)

    assert request(
             :post,
             "/api/v1/communications/create-draft",
             input,
             f.cookie,
             csrf,
             "https://foreign.example.test"
           ).status == 403

    assert request(
             :post,
             "/api/v1/communications/create-draft",
             Map.put(input, :institution_id, f.unit.id),
             f.cookie,
             csrf
           ).status == 400

    success = request(:post, "/api/v1/communications/create-draft", input, f.cookie, csrf)
    assert success.status == 200
    assert get_resp_header(success, "cache-control") == ["no-store"]
    data = Jason.decode!(success.resp_body)["data"]

    assert Map.keys(data) |> Enum.sort() == [
             "classification",
             "institution",
             "notice_id",
             "state",
             "version"
           ]

    refute success.resp_body =~ "source_proof"
  end

  test "loopback guard is disabled by default and rejects foreign peers and query traversal", f do
    Application.delete_env(:chimwemwe_core, :local_communications)

    assert request(:get, "/api/v1/communications/status?notice_id=missing", nil, f.cookie).status ==
             404

    Application.put_env(:chimwemwe_core, :local_communications, f.communications)

    assert request(
             :get,
             "/api/v1/communications/status?notice_id=missing&filter=all",
             nil,
             f.cookie
           ).status == 400

    assert_raise Phoenix.Router.NoRouteError, fn ->
      request(:get, "/api/v1/communications/open-notice?notice_id=missing", nil, f.cookie)
    end

    assert_raise Phoenix.Router.NoRouteError, fn ->
      request(:get, "/api/v1/communications", nil, f.cookie)
    end

    conn =
      Plug.Test.conn(:get, @origin <> "/api/v1/communications/status?notice_id=missing")
      |> Map.put(:remote_ip, {192, 0, 2, 20})
      |> put_req_header("cookie", PublicSessionAdapter.cookie_name() <> "=" <> f.cookie)
      |> Router.call(Router.init([]))

    assert conn.status == 404
  end

  test "author and approver previews never record openings and the checked contract has no audience selectors",
       f do
    notice = Fixture.create!(f)
    {prepared, _} = Fixture.prepare!(f, notice)
    Fixture.submit!(f, notice, prepared)
    approver = Fixture.cookie!(f, f.approver)

    response =
      request(:get, "/api/v1/communications/review?notice_id=" <> notice.notice_id, nil, approver)

    assert response.status == 200
    document = CommunicationsOpenApi.document()
    encoded = Jason.encode!(document)

    for forbidden <- [
          "tenant_id",
          "institution_id",
          "person_id",
          "actor_id",
          "membership_id",
          "source_proof",
          "basis_digest",
          "cursor",
          "filter",
          "sort"
        ],
        do: refute(encoded =~ "\"" <> forbidden <> "\"")

    [[0]] = StaffAudienceFixture.sql!(f, "SELECT count(*) FROM communications_engagements").rows
  end

  defp csrf(cookie),
    do:
      Jason.decode!(request(:get, "/api/v1/session", nil, cookie).resp_body)["data"]["csrf_token"]

  defp request(method, path, input, cookie \\ nil, csrf \\ nil, origin \\ @origin) do
    conn =
      Plug.Test.conn(method, @origin <> path, if(input, do: Jason.encode!(input), else: nil))
      |> put_req_header("accept", "application/json")

    conn = if input, do: put_req_header(conn, "content-type", "application/json"), else: conn

    conn =
      if cookie,
        do: put_req_header(conn, "cookie", PublicSessionAdapter.cookie_name() <> "=" <> cookie),
        else: conn

    conn =
      if csrf,
        do: conn |> put_req_header("origin", origin) |> put_req_header("x-csrf-token", csrf),
        else: conn

    conn =
      conn
      |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], pass: [], json_decoder: Jason))

    case Application.get_env(:chimwemwe_core, :local_communications) do
      %{request_gate: gate, tenant_id: tenant, institution_id: institution} ->
        LocalRequestGate.with_slot(gate, tenant, institution, fn ->
          Router.call(conn, Router.init([]))
        end)

      _ ->
        Router.call(conn, Router.init([]))
    end
  end
end
