# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :mon,
  ecto_repos: [Mon.Repo]

# Configures the endpoint
config :mon, MonWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "AVfscx5hsiz1HckaUJIgxv6ktBijsTtN37Wyyi8f0AUzhFLMX39TJ60NFc8G3KWf",
  render_errors: [view: MonWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Mon.PubSub,
  live_view: [signing_salt: "D2TzBXfS"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# context declarations
config :marketing_web, :generators, context_app: :marketing

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
