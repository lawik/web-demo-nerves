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

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      #
      # From git until a release after 0.13.13 has a configurable fwup timeout
      # (see config/target.exs); the commit is upstream main plus a fix that
      # makes the configured value reach the callers.
      {:nerves_runtime,
       github: "lawik/nerves_runtime",
       ref: "b0b34d84255d8e657a3021404a042c3834b77735",
       override: true},

      # Dependencies for all targets except :host
      # The template's nerves_pack without its networking (vintage_net,
      # mdns_lite, nerves_ssh, nerves_time): the browser has no network.
      {:nerves_motd, "~> 0.1.18", targets: @all_targets},

      # Dependencies for specific targets
      # The jslinux system (Nerves on a RISC-V machine emulated by TinyEMU in
      # a browser) is a sibling checkout that is built from source.
      {:nerves_system_jslinux,
       path: "../nerves_system_jslinux",
       runtime: false,
       targets: :jslinux,
       nerves: [compile: true]}
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
