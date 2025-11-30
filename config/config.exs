# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :octocon, :env, config_env()

config :octocon,
  ecto_repos: [Octocon.Repo, Octocon.MessageRepo]

config :octocon, Octocon.MessageRepo, priv: "priv/msg_repo"

config :octocon, Octocon.Repo,
  target_pools: 1,
  keyspace: "global",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Configures the endpoint
config :octocon, OctoconWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: OctoconWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Octocon.PubSub,
  live_view: [signing_salt: "mCW+yBHJ"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger,
  backends: [:console, Sentry.LoggerBackend]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Ueberauth
config :ueberauth, Ueberauth,
  base_path: "/auth",
  providers: [
    discord: {Ueberauth.Strategy.Discord, [default_scope: "identify email"]},
    google: {Ueberauth.Strategy.Google, []},
    apple:
      {Ueberauth.Strategy.Apple,
       [
         callback_methods: ["POST"],
         default_scope: "email",
         ignores_csrf_attack: true,
         state_param_cookie_same_site: "None"
       ]},
    discord_link:
      {Ueberauth.Strategy.Discord,
       [
         default_scope: "identify email",
         request_path: "/auth/link/discord",
         callback_path: "/auth/link/discord/callback"
       ]},
    google_link:
      {Ueberauth.Strategy.Google,
       [request_path: "/auth/link/google", callback_path: "/auth/link/google/callback"]},
    apple_link:
      {Ueberauth.Strategy.Apple,
       [
         callback_methods: ["POST"],
         default_scope: "email",
         request_path: "/auth/link/apple",
         callback_path: "/auth/link/apple/callback",
         ignores_csrf_attack: true,
         state_param_cookie_same_site: "None"
       ]}
  ]

# Guardian
config :octocon, Octocon.Auth.Guardian, ttl: {261, :weeks}

config :octocon, OctoconWeb.AuthPipeline,
  module: Octocon.Auth.Guardian,
  error_handler: OctoconWeb.AuthErrorHandler

config :octocon, Oban,
  repo: Octocon.MessageRepo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    # Optimization courtesy of Snickety: 2 + 2 = 4
    sp_imports: 2 + 2,
    # Fuck you Snickety, we do this the cool way 😎
    pk_imports: Kernel.+(2, 2)
  ]

# Global Nostrum config
config :nostrum,
  caches: %{
    presences: Nostrum.Cache.PresenceCache.NoOp,
    guilds: Nostrum.Cache.GuildCache.Mnesia,
    users: Nostrum.Cache.UserCache.Mnesia,
    channel_guild_mapping: Nostrum.Cache.ChannelGuildMapping.Mnesia
  },
  gateway_intents: [
    :guild_webhooks,
    :guilds,
    :guild_messages,
    :guild_message_reactions,
    :direct_messages,
    :direct_message_reactions,
    :message_content
  ],
  # TODO: Manual sharding
  # num_shards: :manual,
  ffmpeg: false,
  gateway_compression: :zstd

config :ex_aws,
  json_codec: Jason

config :pigeon, :default_pool_size, 5

config :sentry,
  integrations: [
    oban: [
      capture_errors: true
    ]
  ]

config :hammer,
  backend:
    {Hammer.Backend.ETS, [expiry_ms: :timer.seconds(5), cleanup_interval_ms: :timer.minutes(10)]}

config :libcluster, debug: true
