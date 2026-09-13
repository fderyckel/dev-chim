defmodule AshFoundationLab.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_foundation_lab,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:ecto_sql]]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AshFoundationLab.Application, []}
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.33"},
      {:ash_json_api, "~> 1.7"},
      {:ash_postgres, "~> 2.13"},
      {:jason, "~> 1.4"},
      {:open_api_spex, "~> 3.16"},
      {:picosat_elixir, "~> 0.2.3"},
      {:telemetry, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.create", "ecto.migrate"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
