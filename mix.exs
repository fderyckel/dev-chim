defmodule Chimwemwe.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod
    ]
  end
end
