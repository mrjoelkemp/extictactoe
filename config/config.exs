# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :tictactoe, TictactoeWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "hktw8K9loqm8EDunFQBB2oLVqrTw2KkaEBly+DJ/fcrzC3Y30GAHHS9epdhTFt/D",
  render_errors: [view: TictactoeWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Tictactoe.PubSub,
  live_view: [signing_salt: "y9AOWKez"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
