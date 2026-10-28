# Test-only: a fresh, isolated database contains fictional staff and classroom records.
alias Chimwemwe.Classroom.{AttendanceFixture, Fixture}
alias Chimwemwe.Identity.StaffDirectoryFixture
alias Chimwemwe.Platform.{PersistenceRuntime, TrustedActor}
alias Ecto.UUID

unless Mix.env() == :test and System.get_env("CHIMWEMWE_STAFF_DEMO") == "true" and
         System.get_env("CHIMWEMWE_CLASSROOM_DEMO") == "true" and
         String.starts_with?(
           System.get_env("CHIMWEMWE_TEST_DATABASE", ""),
           "chimwemwe_staff_demo_"
         ) do
  raise "Use bin/staff-demo with its isolated fictional database"
end

{:ok, runtime} = PersistenceRuntime.start_link(Fixture.runtime_options())

{:ok, %{rows: [[0]]}} =
  Fixture.query(
    %{persistence: runtime},
    "SELECT (SELECT count(*) FROM people_persons) + " <>
      "(SELECT count(*) FROM platform_tenant_memberships) + " <>
      "(SELECT count(*) FROM identity_accounts)"
  )

for key <- [:identity_session_hmac_secret, :identity_token_signing_secret] do
  Application.put_env(:chimwemwe_core, key, Base.encode64(:crypto.strong_rand_bytes(48)))
end

Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
  Base.encode64(:crypto.strong_rand_bytes(48))
])

{:ok, fixture} = StaffDirectoryFixture.seed!(runtime, review_rosters: true)
password = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
fixture = StaffDirectoryFixture.bootstrap!(fixture, password)
context = Fixture.context_a()
workspace_id = UUID.generate()

{:ok, _} =
  Fixture.query(
    fixture,
    """
    INSERT INTO classroom_preparation_workspaces
      (id,tenant_id,actor_id,membership_id,institutional_unit_id,calendar_id,
       academic_year_id,calendar_revision,educator_participation_id,lock_version,inserted_at)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,1,NOW())
    """,
    [
      Fixture.dump(workspace_id),
      Fixture.dump(TrustedActor.tenant_id(context.actor)),
      Fixture.dump(TrustedActor.actor_id(context.actor)),
      Fixture.dump(fixture.membership_a),
      Fixture.dump(fixture.unit.id),
      Fixture.dump(fixture.calendar.id),
      Fixture.dump(fixture.calendar.year_id),
      fixture.calendar.revision,
      Fixture.dump(fixture.staff.id)
    ]
  )

Application.put_env(:chimwemwe_core, :local_classroom_enabled, true)

Application.put_env(:chimwemwe_core, :local_staff_directory, %{
  tenant_id: TrustedActor.tenant_id(context.actor),
  bootstrap_actor_id: TrustedActor.actor_id(context.actor),
  institution_label: "Synthetic Learning Institution"
})

Application.put_env(:chimwemwe_core, :public_api,
  runtime: runtime,
  verifier: AttendanceFixture,
  origin: "https://localhost:3015",
  preparation: [people_runtime: fixture.runtime, workspace_id: workspace_id]
)

defmodule Chimwemwe.Identity.StaffDemoPlug do
  @moduledoc false
  def init(options), do: options

  def call(conn, _options) do
    conn
    |> Plug.RequestId.call(Plug.RequestId.init([]))
    |> Plug.Parsers.call(
      Plug.Parsers.init(parsers: [:json], pass: [], json_decoder: Jason, length: 32_768)
    )
    |> Chimwemwe.PublicApi.Router.call(Chimwemwe.PublicApi.Router.init([]))
  end
end

{:ok, _server} =
  Bandit.start_link(
    plug: Chimwemwe.Identity.StaffDemoPlug,
    ip: {127, 0, 0, 1},
    port: 4015,
    startup_log: false
  )

case System.get_env("CHIMWEMWE_STAFF_CREDENTIAL_FILE") do
  nil ->
    # Explicit local bootstrap ceremony: display once to the invoking operator only.
    IO.puts("Fictional account administrator: " <> StaffDirectoryFixture.admin_email())
    IO.puts("Run-specific bootstrap password: " <> password)

  path ->
    unless Path.type(path) == :absolute do
      raise "The private credential-file path must be absolute"
    end

    {:ok, file} = File.open(path, [:write, :exclusive, :binary])

    try do
      :ok = File.chmod(path, 0o600)

      :ok =
        IO.binwrite(
          file,
          Jason.encode!(%{email: StaffDirectoryFixture.admin_email(), password: password})
        )
    after
      File.close(file)
    end
end

IO.puts("Fictional staff account and classroom writer ready on loopback.")
Process.sleep(:infinity)
