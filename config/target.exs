import Config

config :logger, backends: [RingLogger]

config :shoehorn, init: [:nerves_runtime]

config :nerves, :erlinit, update_clock: true
