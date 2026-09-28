import Config

config :ash, default_string_length_count: :codepoints

config :phoenix,
  filter_parameters: [
    "assertion",
    "code",
    "csrf_token",
    "password",
    "secret",
    "state",
    "token"
  ]

config :chimwemwe_core,
  ash_domains: [Chimwemwe.Platform, Chimwemwe.Identity, Chimwemwe.OrganizationLegal],
  base_resources: [Chimwemwe.Platform.Resource],
  ecto_repos: [Chimwemwe.Repo]

config :chimwemwe_core, Chimwemwe.LocalBridge.Endpoint, adapter: Bandit.PhoenixAdapter

config :chimwemwe_core, Chimwemwe.AuthDemo.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  live_view: [signing_salt: "auth-demo-live-view-signing-salt"],
  render_errors: [formats: [html: Chimwemwe.AuthDemo.ErrorHTML], layout: false]

config :chimwemwe_core, Chimwemwe.PublicApi.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: Chimwemwe.PublicApi.ErrorJSON], layout: false]

if config_env() == :dev and
     (System.get_env("CHIMWEMWE_UI1_LOCAL") == "true" or
        System.get_env("CHIMWEMWE_UI1_SETUP") == "true" or
        System.get_env("CHIMWEMWE_AUTH_DEMO") == "true" or
        System.get_env("CHIMWEMWE_AUTH_SETUP") == "true") do
  database_connection =
    case System.get_env("PGHOST") do
      nil -> [socket_dir: "/tmp"]
      "/" <> _rest = socket_dir -> [socket_dir: socket_dir]
      hostname -> [hostname: hostname]
    end

  repo_config = [
    database:
      System.get_env(
        "CHIMWEMWE_AUTH_DATABASE",
        System.get_env("CHIMWEMWE_UI1_DATABASE", "chimwemwe_ui1_local")
      ),
    password: System.get_env("PGPASSWORD"),
    pool: DBConnection.ConnectionPool,
    pool_size: 4,
    port: String.to_integer(System.get_env("PGPORT", "5432")),
    log: false,
    show_sensitive_data_on_connection_error: false,
    username: System.get_env("PGUSER") || System.get_env("USER") || "postgres"
  ]

  config :chimwemwe_core, Chimwemwe.Repo, Keyword.merge(repo_config, database_connection)
end

if config_env() == :test do
  database_connection =
    case System.get_env("PGHOST") do
      nil -> [socket_dir: "/tmp"]
      "/" <> _rest = socket_dir -> [socket_dir: socket_dir]
      hostname -> [hostname: hostname]
    end

  repo_config = [
    database: System.get_env("CHIMWEMWE_TEST_DATABASE", "chimwemwe_core_test"),
    password: System.get_env("PGPASSWORD"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 4,
    port: String.to_integer(System.get_env("PGPORT", "5432")),
    log: false,
    show_sensitive_data_on_connection_error: false,
    username: System.get_env("PGUSER") || System.get_env("USER") || "postgres"
  ]

  config :chimwemwe_core, Chimwemwe.Repo, Keyword.merge(repo_config, database_connection)

  config :chimwemwe_core,
         :identity_token_signing_secret,
         String.duplicate("test-token-secret-", 4)

  config :chimwemwe_core,
         :identity_invitation_hmac_secret,
         String.duplicate("test-invitation-secret-", 3)

  config :chimwemwe_core,
         :identity_session_hmac_secret,
         String.duplicate("test-session-secret-", 3)

  config :bcrypt_elixir, log_rounds: 1
end
