# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :zcms,
  ecto_repos: [Zcms.Repo]

# Configures the endpoint
config :zcms, ZcmsWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "b4mnfA1qWYES568NKQpkiE1a5Eqj+k3sbKdV3y9QevWMj+/jcDMtSxOvRFwAzDJB",
  render_errors: [view: ZcmsWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Zcms.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configures Ueberauth
# config :ueberauth, Ueberauth,
#  providers: [
#    auth0: { Ueberauth.Strategy.Auth0, [] },
#  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
