import Config

config :ash_foundation_lab,
  ash_domains: [AshFoundationLab.Foundation],
  ecto_repos: [AshFoundationLab.Repo]

config :ash, default_string_length_count: :codepoints

database_connection =
  case System.get_env("PGHOST") do
    nil -> [socket_dir: "/tmp"]
    "/" <> _rest = socket_dir -> [socket_dir: socket_dir]
    hostname -> [hostname: hostname]
  end

repo_config = [
  database: System.get_env("PGDATABASE", "ash_foundation_lab_#{config_env()}"),
  password: System.get_env("PGPASSWORD"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  show_sensitive_data_on_connection_error: config_env() != :prod,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres"
]

config :ash_foundation_lab, AshFoundationLab.Repo, Keyword.merge(repo_config, database_connection)

config :logger, level: :warning
