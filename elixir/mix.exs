defmodule LoadTester.MixProject do
  use Mix.Project

  def project do
    [
      app: :load_tester,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript_config()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :httpoison, :dotenv]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 2.0"},
      {:dotenv, "~> 3.0"},
      {:jason, "~> 1.4"}
      # For JSON parsing Elixir (>= 1.12) ships with Jason,
      # but if you need a different library you can add it here.
      # {:jason, "~> 1.2"} # Example if you wanted to pin Jason explicitly
    ]
  end

  defp escript_config do
    [
      main_module: LoadTester
    ]
  end
end
