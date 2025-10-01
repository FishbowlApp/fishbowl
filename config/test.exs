import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :octocon, OctoconWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "kDwC9vMAvvat7jUYEZ3F5WFhr9RnAci7dSyh3RhdNKpTmDamfB10TFC+npVP5FHh",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
