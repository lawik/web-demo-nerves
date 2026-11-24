import Config

# Default to not starting so that the console logger is not started. See
# runtime.exs for logger configuration.
config :logger, :default_handler, false

config :shoehorn, init: [:nerves_runtime]

config :nerves, :erlinit, update_clock: true

# eth0 gets its address from the network the page provides (DHCP is
# answered in the browser, see jsnerves/net/nerves-net.js)
config :vintage_net,
  regulatory_domain: "00",
  config: [
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
  ]

# SSH with the public keys found in ~/.ssh when the firmware is built, or
# only the one in $NERVES_SSH_PUBKEY if that is set
keys =
  case System.get_env("NERVES_SSH_PUBKEY") do
    nil ->
      for name <- ["id_rsa.pub", "id_ecdsa.pub", "id_ed25519.pub"],
          path = Path.join([System.user_home!(), ".ssh", name]),
          File.exists?(path),
          do: path

    path ->
      [path]
  end

config :nerves_ssh,
  authorized_keys: Enum.map(keys, &(&1 |> File.read!() |> String.trim()))
