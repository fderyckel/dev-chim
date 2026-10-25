defmodule Chimwemwe.PublicApi.StaffLoginTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  alias Chimwemwe.Classroom.{AttendanceFixture, Fixture}
  alias Chimwemwe.Identity.{PublicSessionAdapter, StaffDirectory, StaffDirectoryFixture}
  alias Chimwemwe.Platform.{PersistenceRuntime, TrustedActor}
  alias Chimwemwe.PublicApi.Router

  @origin "https://localhost:3015"
  @login_cookie "__Host-chimwemwe-staff-login"
  @environment_keys [
    :public_api,
    :public_session_cookie_keys,
    :local_staff_directory,
    :local_classroom_enabled
  ]

  setup do
    old = Map.new(@environment_keys, &{&1, Application.get_env(:chimwemwe_core, &1)})
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, fixture} = StaffDirectoryFixture.seed!(persistence)
    password = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    fixture = StaffDirectoryFixture.bootstrap!(fixture, password)
    context = Fixture.context_a()

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
      Base.encode64(:crypto.strong_rand_bytes(48))
    ])

    Application.put_env(:chimwemwe_core, :local_staff_directory, %{
      tenant_id: TrustedActor.tenant_id(context.actor),
      bootstrap_actor_id: TrustedActor.actor_id(context.actor),
      institution_label: "Northstar Synthetic School"
    })

    Application.put_env(:chimwemwe_core, :local_classroom_enabled, true)

    Application.put_env(:chimwemwe_core, :public_api,
      runtime: persistence,
      verifier: AttendanceFixture,
      origin: @origin
    )

    on_exit(fn ->
      for {key, value} <- old do
        if is_nil(value),
          do: Application.delete_env(:chimwemwe_core, key),
          else: Application.put_env(:chimwemwe_core, key, value)
      end

      for source <- [fixture.source, fixture.account_source],
          do: if(Process.alive?(source), do: Agent.stop(source))

      {:ok, cleanup} = PersistenceRuntime.start_link(Fixture.runtime_options())

      try do
        Fixture.clear_fixture(cleanup)
        StaffDirectoryFixture.cleanup_accounts!(cleanup, fixture.teacher_actor_id)
      after
        Supervisor.stop(cleanup)
      end
    end)

    Map.put(fixture, :bootstrap_password, password)
  end

  test "real local credentials connect staff access and suspension blocks an already-open session",
       f do
    admin_login = sign_in(StaffDirectoryFixture.admin_email(), f.bootstrap_password)
    assert admin_login.status == 200
    assert data(admin_login)["stage"] == "authenticated"
    assert data(admin_login)["next_path"] == "/accounts"
    admin_cookie = application_cookie(admin_login)
    assert_safe_cookie(admin_login, PublicSessionAdapter.cookie_name())

    inventory = request(:get, "/api/v1/staff-accounts", nil, admin_cookie)
    assert inventory.status == 200
    assert [%{"display_name" => "Synthetic Teacher"}] = data(inventory)["eligible_staff"]
    assert [%{"label" => "Classroom teacher"}] = data(inventory)["profiles"]
    refute inventory.resp_body =~ "hashed_password"
    refute inventory.resp_body =~ f.bootstrap_password

    csrf = session_csrf(admin_cookie)

    created =
      request(
        :post,
        "/api/v1/staff-accounts/provision",
        Map.merge(Fixture.keys(), %{
          association_id: f.teacher_association.id,
          email: "teacher@northstar-school.test",
          given_name: "Synthetic",
          family_name: "Teacher",
          display_name: "Synthetic Teacher",
          locale: "en"
        }),
        admin_cookie,
        [{"x-csrf-token", csrf}]
      )

    assert created.status == 200
    receipt = data(created)
    temporary_password = receipt["temporary_password"]
    assert is_binary(temporary_password)

    access =
      request(
        :post,
        "/api/v1/staff-accounts/set-access",
        Map.merge(Fixture.keys(), %{
          id: receipt["id"],
          expected_version: receipt["lock_version"],
          profile_id: f.teacher_role_id
        }),
        admin_cookie,
        [{"x-csrf-token", csrf}]
      )

    assert access.status == 200
    first_login = sign_in("teacher@northstar-school.test", temporary_password)
    assert first_login.status == 200
    assert data(first_login)["stage"] == "first_login"
    assert first_login.resp_cookies[PublicSessionAdapter.cookie_name()].max_age == 0
    restricted_cookie = response_cookie(first_login, @login_cookie)
    assert_safe_cookie(first_login, @login_cookie)
    assert request(:get, "/api/v1/staff-accounts", nil, restricted_cookie).status == 401
    assert request(:get, "/api/v1/classroom/classes", nil, restricted_cookie).status == 401

    permanent_password = Base.url_encode64(:crypto.strong_rand_bytes(40), padding: false)

    replaced =
      request(
        :post,
        "/api/v1/staff-login/replace-password",
        %{
          password: permanent_password,
          confirmation: permanent_password,
          csrf_token: data(first_login)["csrf_token"]
        },
        restricted_cookie
      )

    assert replaced.status == 200
    assert data(replaced)["stage"] == "anonymous"
    refute Map.has_key?(replaced.resp_cookies, PublicSessionAdapter.cookie_name())
    assert sign_in("teacher@northstar-school.test", temporary_password).status == 401

    teacher_login = sign_in("teacher@northstar-school.test", permanent_password)
    assert teacher_login.status == 200
    assert data(teacher_login)["next_path"] == "/classroom"
    teacher_cookie = application_cookie(teacher_login)
    classes = request(:get, "/api/v1/classroom/classes", nil, teacher_cookie)
    assert classes.status == 200
    assert [%{"id" => id}] = data(classes)
    assert id == f.class.id
    assert request(:get, "/api/v1/staff-accounts", nil, teacher_cookie).status == 403

    suspended =
      request(
        :post,
        "/api/v1/staff-accounts/suspend-access",
        Map.merge(Fixture.keys(), %{
          id: receipt["id"],
          expected_version: data(access)["lock_version"]
        }),
        admin_cookie,
        [{"x-csrf-token", csrf}]
      )

    assert suspended.status == 200
    assert request(:get, "/api/v1/classroom/classes", nil, teacher_cookie).status == 401
    assert sign_in("teacher@northstar-school.test", permanent_password).status == 401
    assert request(:get, "/api/v1/staff-accounts", nil, admin_cookie).status == 200

    assert {:ok, %{rows: [[0]]}} =
             Fixture.query(f, "SELECT count(*) FROM identity_external_identity_links")
  end

  test "pre-authentication requires origin and bound CSRF and keeps public denial neutral", f do
    initial = request(:get, "/api/v1/staff-login")
    assert initial.status == 200
    assert get_resp_header(initial, "cache-control") == ["no-store"]
    login_cookie = response_cookie(initial, @login_cookie)

    input = %{
      email: StaffDirectoryFixture.admin_email(),
      password: f.bootstrap_password,
      locale: "en",
      csrf_token: data(initial)["csrf_token"]
    }

    assert request(:post, "/api/v1/staff-login", input).status == 401

    assert request(:post, "/api/v1/staff-login", %{input | csrf_token: "unbound"}, login_cookie).status ==
             401

    assert request(:post, "/api/v1/staff-login", input, login_cookie, [
             {"origin", "https://attacker.example.test"}
           ]).status == 401

    unknown = sign_in("unknown@northstar-school.test", f.bootstrap_password)
    wrong = sign_in(StaffDirectoryFixture.admin_email(), f.bootstrap_password <> "wrong")
    assert unknown.status == wrong.status
    assert unknown.resp_body == wrong.resp_body
    assert get_resp_header(wrong, "cache-control") == ["no-store"]
    refute wrong.resp_body =~ StaffDirectoryFixture.admin_email()
  end

  test "the staff candidate fails closed without startup configuration or with a foreign host" do
    assert request(:get, "/api/v1/staff-login", nil, %{}, [{"host", "attacker.example.test"}]).status ==
             404

    Application.delete_env(:chimwemwe_core, :local_staff_directory)
    assert request(:get, "/api/v1/staff-login").status == 404
    assert request(:get, "/api/v1/staff-accounts").status == 404
  end

  test "a new temporary login ends the existing application session before restricted replacement",
       f do
    admin_login = sign_in(StaffDirectoryFixture.admin_email(), f.bootstrap_password)
    admin_cookie = application_cookie(admin_login)
    provisioned = provision_teacher(f)

    first_login =
      sign_in("teacher@northstar-school.test", provisioned.temporary_password, admin_cookie)

    assert first_login.status == 200
    assert data(first_login)["stage"] == "first_login"
    assert first_login.resp_cookies[PublicSessionAdapter.cookie_name()].max_age == 0
    assert request(:get, "/api/v1/session", nil, admin_cookie).status == 401

    assert request(
             :get,
             "/api/v1/staff-accounts",
             nil,
             response_cookie(first_login, @login_cookie)
           ).status ==
             401
  end

  test "permanent login and a denied credential attempt cannot retain an earlier application session",
       f do
    first = sign_in(StaffDirectoryFixture.admin_email(), f.bootstrap_password)
    first_cookie = application_cookie(first)
    second = sign_in(StaffDirectoryFixture.admin_email(), f.bootstrap_password, first_cookie)
    second_cookie = application_cookie(second)

    assert second.status == 200
    refute first_cookie == second_cookie
    assert request(:get, "/api/v1/session", nil, first_cookie).status == 401
    assert request(:get, "/api/v1/session", nil, second_cookie).status == 200

    assert {:ok, _} =
             Fixture.query(
               f,
               """
               UPDATE identity_application_sessions
               SET inserted_at=(NOW() AT TIME ZONE 'utc')-INTERVAL '2 minutes',
                 idle_expires_at=(NOW() AT TIME ZONE 'utc')-INTERVAL '1 minute',
                 absolute_expires_at=(NOW() AT TIME ZONE 'utc')+INTERVAL '11 hours'
               WHERE actor_id=$1 AND status='active'
               """,
               [Ecto.UUID.dump!(f.admin_account.actor_id)]
             )

    renewed = sign_in(StaffDirectoryFixture.admin_email(), f.bootstrap_password, second_cookie)
    assert renewed.status == 200
    renewed_cookie = application_cookie(renewed)

    denied = sign_in("missing@northstar-school.test", f.bootstrap_password, renewed_cookie)
    assert denied.status == 401
    assert denied.resp_cookies[PublicSessionAdapter.cookie_name()].max_age == 0
    assert request(:get, "/api/v1/session", nil, renewed_cookie).status == 401
  end

  test "a sealed first-login deadline is absolute across refresh and expired state is refused" do
    [key | _] = Application.fetch_env!(:chimwemwe_core, :public_session_cookie_keys)

    state = %{
      stage: :first_login,
      account_id: Ecto.UUID.generate(),
      lock_version: 1,
      locale: "fr",
      csrf_token: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
      expires_at: System.system_time(:second) + 60
    }

    cookie = %{@login_cookie => Phoenix.Token.encrypt(key, "staff-restricted-login-v1", state)}
    refreshed = request(:get, "/api/v1/staff-login", nil, cookie)
    assert data(refreshed)["stage"] == "first_login"

    assert {:ok, refreshed_state} =
             Phoenix.Token.decrypt(
               key,
               "staff-restricted-login-v1",
               response_cookie(refreshed, @login_cookie)[@login_cookie],
               max_age: 600
             )

    assert refreshed_state.expires_at == state.expires_at
    expired_state = %{state | expires_at: System.system_time(:second) - 1}

    expired_cookie = %{
      @login_cookie => Phoenix.Token.encrypt(key, "staff-restricted-login-v1", expired_state)
    }

    expired_refresh = request(:get, "/api/v1/staff-login", nil, expired_cookie)
    assert data(expired_refresh)["stage"] == "anonymous"

    assert request(
             :post,
             "/api/v1/staff-login/replace-password",
             %{
               password: "Fictional maple river 2048!",
               confirmation: "Fictional maple river 2048!",
               csrf_token: state.csrf_token
             },
             expired_cookie
           ).status == 401
  end

  test "a localhost Host does not admit a non-loopback caller and IPv6 loopback is accepted" do
    assert request(:get, "/api/v1/staff-login", nil, %{}, [], {203, 0, 113, 9}).status == 404
    assert request(:get, "/api/v1/staff-accounts", nil, %{}, [], {203, 0, 113, 9}).status == 404

    assert request(:get, "/api/v1/staff-login", nil, %{}, [], {0, 0, 0, 0, 0, 0, 0, 1}).status ==
             200
  end

  defp provision_teacher(f) do
    assert {:ok, result} =
             StaffDirectory.provision(
               f.persistence,
               Fixture.context_a(),
               Map.merge(Fixture.keys(), %{
                 association_id: f.teacher_association.id,
                 email: "teacher@northstar-school.test",
                 given_name: "Synthetic",
                 family_name: "Teacher",
                 display_name: "Synthetic Teacher",
                 locale: "en"
               })
             )

    result
  end

  defp sign_in(email, password, existing_cookies \\ %{}) do
    initial = request(:get, "/api/v1/staff-login", nil, existing_cookies)

    request(
      :post,
      "/api/v1/staff-login",
      %{email: email, password: password, csrf_token: data(initial)["csrf_token"], locale: "en"},
      Map.merge(existing_cookies, response_cookie(initial, @login_cookie))
    )
  end

  defp request(
         method,
         path,
         params \\ nil,
         cookies \\ %{},
         headers \\ [],
         remote_ip \\ {127, 0, 0, 1}
       ) do
    conn =
      Plug.Test.conn(
        method,
        @origin <> path,
        if(is_nil(params), do: nil, else: Jason.encode!(params))
      )
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("origin", @origin)

    conn =
      if map_size(cookies) == 0,
        do: conn,
        else:
          put_req_header(
            conn,
            "cookie",
            Enum.map_join(cookies, "; ", fn {key, value} -> "#{key}=#{value}" end)
          )

    conn =
      Enum.reduce(headers, conn, fn
        {"host", value}, acc ->
          uri = URI.parse("https://" <> value)
          %{acc | host: uri.host, port: uri.port}

        {key, value}, acc ->
          put_req_header(acc, key, value)
      end)

    %{conn | remote_ip: remote_ip}
    |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], pass: [], json_decoder: Jason))
    |> Router.call(Router.init([]))
  end

  defp data(conn), do: Jason.decode!(conn.resp_body)["data"]
  defp response_cookie(conn, name), do: %{name => Map.fetch!(conn.resp_cookies, name).value}
  defp application_cookie(conn), do: response_cookie(conn, PublicSessionAdapter.cookie_name())

  defp session_csrf(cookies),
    do: request(:get, "/api/v1/session", nil, cookies) |> data() |> Map.fetch!("csrf_token")

  defp assert_safe_cookie(conn, name) do
    assert %{secure: true, http_only: true, same_site: "Lax", path: "/"} = conn.resp_cookies[name]
    refute Map.has_key?(conn.resp_cookies[name], :domain)
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end
end
