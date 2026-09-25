import Config

config :ash, default_string_length_count: :codepoints

config :chimwemwe_core,
  ash_domains: [Chimwemwe.Platform],
  base_resources: [Chimwemwe.Platform.Resource],
  ecto_repos: [Chimwemwe.Repo]

config :chimwemwe_core, Chimwemwe.LocalBridge.Endpoint, adapter: Bandit.PhoenixAdapter

if config_env() == :dev and
     (System.get_env("CHIMWEMWE_UI1_LOCAL") == "true" or
        System.get_env("CHIMWEMWE_UI1_SETUP") == "true") do
  database_connection =
    case System.get_env("PGHOST") do
      nil -> [socket_dir: "/tmp"]
      "/" <> _rest = socket_dir -> [socket_dir: socket_dir]
      hostname -> [hostname: hostname]
    end

  repo_config = [
    database: System.get_env("CHIMWEMWE_UI1_DATABASE", "chimwemwe_ui1_local"),
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
end
