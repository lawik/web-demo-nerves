import Config

# Default to not starting so that the console logger is not started. See
# runtime.exs for logger configuration.
config :logger, :default_handler, false

config :shoehorn, init: [:nerves_runtime]

config :nerves, :erlinit, update_clock: true
