import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

config :nerves, source_date_epoch: "1774526989"

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
