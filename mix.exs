defmodule Octocon.MixProject do
  use Mix.Project

  def project do
    [
      app: :octocon,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Octocon.Application, []},
      included_applications: [:nostrum],
      extra_applications: [
        :logger,
        :runtime_tools,
        :os_mon,
        :timex,
        :certifi,
        :gun,
        :inets,
        :jason,
        :mime,
        :jose
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix boilerplate
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_psql_extras, "~> 0.8"},
      {:postgrex, "~> 0.20"},
      {:phoenix_live_dashboard, "~> 0.8"},

      # Use Bandit instead of Cowboy
      {:bandit, "~> 1.6"},
      {:websock_adapter, "~> 0.5"},

      # Authentication
      {:guardian, "~> 2.3"},
      {:guardian_db, "~> 3.0"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_google, "~> 0.10"},
      {:ueberauth_discord, "~> 0.6"},
      {:ueberauth_apple, "~> 0.6"},
      {:argon2_elixir, "~> 4.0"},
      {:jose, "~> 1.11"},

      # Push notifications
      {:pigeon, "2.0.0-rc.1"},

      # Discord
      # {:nostrum, github: "Kraigie/nostrum", branch: "master", override: true, runtime: false},
      {:nostrum, "~> 0.10", override: true, runtime: false},
      {:certifi, "~> 2.13", override: true},
      # Use zstd for gateway compression
      {:ezstd, "~> 1.1"},
      # {:nosedrum, "~> 0.6"},
      # {:nosedrum,
      # github: "jchristgit/nosedrum", branch: "master", override: true},

      # Caching
      {:cachex, "~> 3.6"},
      # Background jobs
      {:oban, "~> 2.19.4"},
      # Object storage
      {:waffle, "~> 1.1"},
      {:image, "~> 0.59"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},

      # Analytics
      {:sentry, "~> 10.6.1"},

      # Rate limiting
      {:hammer, "~> 6.2"},
      {:hammer_plug, "~> 3.0"},

      # Utils
      {:timex, "~> 3.7"},

      # Distribution
      {:fly_postgres, "~> 0.3"},
      {:horde, "~> 0.9.0"},
      {:dns_cluster, "~> 0.2"},

      # Time-series data
      {:timescale, "~> 0.1"},

      # Metrics
      {:prom_ex, "~> 1.11"},
      {:telemetry_metrics, "~> 1.0", override: true},
      {:telemetry_poller, "~> 1.2"},

      # Utilities
      {:sweet_xml, "~> 0.7.4"},
      {:hackney, "~> 1.20"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.19"},
      {:nanoid, "~> 2.1.0"},

      # Dev-only
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        "run priv/repo/seeds.exs",
        "run priv/msg_repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.deploy": [
        "phx.digest"
      ]
    ]
  end
end
