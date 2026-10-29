# Test-only fixture persona seam; never part of the core router or a real login path.
alias Chimwemwe.Classroom.Fixture, as: Classroom
alias Chimwemwe.Communications.Fixture
alias Chimwemwe.Platform.PersistenceRuntime

unless Mix.env() == :test and System.get_env("CHIMWEMWE_COMM_DEMO") == "true" and
         String.starts_with?(
           System.get_env("CHIMWEMWE_TEST_DATABASE", ""),
           "chimwemwe_comm_demo_"
         ) do
  raise "Use bin/communications-demo with its fresh fictional database"
end

{:ok, runtime} = PersistenceRuntime.start_link(Classroom.runtime_options())

{:ok, %{rows: [[0]]}} =
  Classroom.query(%{persistence: runtime}, "SELECT count(*) FROM people_persons")

for key <- [:identity_session_hmac_secret, :identity_token_signing_secret],
    do: Application.put_env(:chimwemwe_core, key, Base.encode64(:crypto.strong_rand_bytes(48)))

Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
  Base.encode64(:crypto.strong_rand_bytes(48))
])

{:ok, fixture} = Classroom.seed!(runtime)
fixture = Fixture.connect!(fixture)

cookies =
  Map.new(
    [
      {"author", fixture.request},
      {"approver", fixture.approver},
      {"recipient", fixture.recipient_request}
    ],
    fn {name, request} -> {name, Fixture.cookie!(fixture, request)} end
  )

{:ok, _agent} =
  Agent.start_link(fn -> %{fixture: fixture, cookies: cookies, changed: false} end,
    name: :communications_demo_state
  )

Application.put_env(:chimwemwe_core, :local_communications, fixture.communications)

Application.put_env(:chimwemwe_core, :public_api,
  runtime: runtime,
  verifier: Fixture,
  origin: "https://localhost:3025"
)

defmodule Chimwemwe.Communications.DemoPlug do
  @moduledoc false
  import Plug.Conn
  alias Chimwemwe.Identity.PublicSessionAdapter
  alias Chimwemwe.People.StaffAudienceFixture

  def init(options), do: options

  def call(conn, _options) do
    conn =
      conn
      |> Plug.RequestId.call(Plug.RequestId.init([]))
      |> Plug.Parsers.call(
        Plug.Parsers.init(parsers: [:json], pass: [], json_decoder: Jason, length: 32_768)
      )

    if String.starts_with?(conn.request_path, "/proof/") do
      fixture_action(conn)
    else
      if String.starts_with?(conn.request_path, "/api/v1/communications/") do
        config = Application.fetch_env!(:chimwemwe_core, :local_communications)

        case Chimwemwe.Communications.LocalRequestGate.with_slot(
               config.request_gate,
               config.tenant_id,
               config.institution_id,
               fn ->
                 Chimwemwe.PublicApi.Router.call(conn, Chimwemwe.PublicApi.Router.init([]))
               end
             ) do
          %Plug.Conn{} = response ->
            response

          {:error, %{code: code}} ->
            Chimwemwe.PublicApi.ErrorResponse.send(
              conn,
              if(code == :rate_limited, do: 429, else: 503),
              Atom.to_string(code),
              "The local notice service is busy. Check this request before retrying."
            )
        end
      else
        Chimwemwe.PublicApi.Router.call(conn, Chimwemwe.PublicApi.Router.init([]))
      end
    end
  end

  defp fixture_action(conn) do
    if conn.method !=
         "POST" or
         conn.host !=
           "localhost" or
         conn.remote_ip !=
           {127, 0, 0, 1} or
         get_req_header(conn, "origin") != ["https://localhost:3025"] do
      send_resp(conn, 404, "")
    else
      fixture_action_current(conn)
    end
  end

  defp fixture_action_current(%{request_path: "/proof/persona/" <> name} = conn)
       when name in ["author", "approver", "recipient"] do
    cookie = Agent.get(:communications_demo_state, &Map.fetch!(&1.cookies, name))

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_cookie(
      PublicSessionAdapter.cookie_name(),
      cookie,
      PublicSessionAdapter.cookie_options()
    )
    |> send_resp(204, "")
  end

  defp fixture_action_current(%{request_path: "/proof/change-source"} = conn) do
    state = Agent.get(:communications_demo_state, & &1)

    unless state.changed do
      StaffAudienceFixture.staff!(state.fixture, linked: false)
      Agent.update(:communications_demo_state, &%{&1 | changed: true})
    end

    send_resp(conn, 204, "")
  end

  defp fixture_action_current(_conn), do: raise("Unsupported fictional fixture action")
end

{:ok, _server} =
  Bandit.start_link(
    plug: Chimwemwe.Communications.DemoPlug,
    ip: {127, 0, 0, 1},
    port: 4025,
    startup_log: false
  )

IO.puts("Fictional communications writer ready on loopback.")
Process.sleep(:infinity)
