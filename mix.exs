defmodule WebDemoNerves.MixProject do
  use Mix.Project

  @app :web_demo_nerves
  @version "0.1.0"
  @all_targets [:jslinux]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.20",
      archives: [nerves_bootstrap: "~> 1.17"],
      listeners: listeners(Mix.target(), Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {WebDemoNerves.Application, []}
    ]
  end

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.13", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:logger_backends, "~> 1.0"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.5.0"},
      # The board's LEDs, buttons and sensors (see WebDemoNerves.Board); on
      # the host they compile against Circuits' test backends
      {:circuits_gpio, "~> 2.3"},
      {:circuits_i2c, "~> 2.1"},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      #
      # From upstream main until a release after 0.13.13 has its KV pass the
      # configured fwup timeout to fwup (see config/target.exs).
      {:nerves_runtime,
       github: "nerves-project/nerves_runtime",
       ref: "b53eaa9c730d02d40d6d8f9b1710cd871c4e6ff2",
       override: true},

      # Dependencies for all targets except :host
      # The template's nerves_pack without its networking (vintage_net,
      # mdns_lite, nerves_ssh, nerves_time): the browser has no network.
      {:nerves_motd, "~> 0.1.18", targets: @all_targets},

      # Dependencies for specific targets
      # The jslinux system (Nerves on a RISC-V machine emulated by TinyEMU in
      # a browser). Tags of the fork have a prebuilt artifact on its GitHub
      # releases, which mix deps.get downloads. To build the system from a
      # checkout instead: path: "../nerves_system_jslinux", nerves: [compile: true]
      {:nerves_system_jslinux,
       github: "underjord/nerves_system_jslinux",
       tag: "v0.4.2",
       runtime: false,
       targets: :jslinux}
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  # Uncomment the following line if using Phoenix > 1.8.
  # defp listeners(:host, :dev), do: [Phoenix.CodeReloader]
  defp listeners(_, _), do: []
end
