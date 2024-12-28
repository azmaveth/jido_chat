defmodule JidoChat.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_chat,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {JidoChat.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:jido, path: "../jido"},
      {:phoenix_pubsub, "~> 2.1"},

      # Testing
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:mimic, "~> 1.7", only: [:dev, :test]},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end
end
