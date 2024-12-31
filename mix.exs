defmodule JidoChat.MixProject do
  use Mix.Project

  @version "0.5.0"

  def project do
    [
      app: :jido_chat,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Docs
      name: "JidoChat",
      description:
        "A structured chat channel system supporting human and agent participants with customizable turn-taking strategies.",
      source_url: "https://github.com/agentjido/jido_chat",
      homepage_url: "https://github.com/agentjido/jido_chat",
      package: package(),
      docs: docs(),

      # Coverage
      test_coverage: [tool: ExCoveralls, export: "cov"],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.lcov": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {JidoChat.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "getting-started",
      source_ref: "v#{@version}",
      source_url: "https://github.com/agentjido/jido_chat",
      extra_section: "Guides",
      extras: [
        {"README.md", title: "Home"},
        {"guides/architecture.md", title: "Architecture"},
        {"guides/getting-started.md", title: "Getting Started"}
      ],
      groups_for_modules: [
        Core: [
          JidoChat,
          JidoChat.Channel,
          JidoChat.Message,
          JidoChat.Conversation,
          JidoChat.Participant
        ],
        "Channel Management": [
          JidoChat.Application
        ],
        "Turn-taking Strategies": [
          JidoChat.Channel.Strategy,
          JidoChat.Channel.Strategy.FreeForm,
          JidoChat.Channel.Strategy.RoundRobin,
          JidoChat.Channel.Strategy.PubSubRoundRobin
        ],
        Persistence: [
          JidoChat.Channel.Persistence,
          JidoChat.Channel.Persistence.ETS,
          JidoChat.Channel.Persistence.Memory
        ],
        PubSub: [
          JidoChat.PubSub.MessageBroker,
          JidoChat.PubSub.MessageBroker.State
        ]
      ],
      # Hide modules from the sidebar
      groups_for_extras: [
        Guides: [
          "guides/getting-started",
          "guides/architecture"
        ]
      ],
      sidebar_items: [
        Guides: [
          "guides/getting-started",
          "guides/architecture"
        ]
      ]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/agentjido/jido_chat"
      }
    ]
  end

  defp deps do
    [
      {:jido, path: "../jido"},
      {:phoenix_pubsub, "~> 2.1"},

      # Testing
      {:credo, "~> 1.7"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.3", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:mimic, "~> 1.7", only: [:dev, :test]},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      test: "test --trace",
      q: ["quality"],
      quality: [
        "format",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "dialyzer --format dialyxir",
        "credo --all"
      ]
    ]
  end
end
