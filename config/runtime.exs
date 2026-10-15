import Config

if Mix.target() != :host or config_env() == :prod do
  Application.ensure_all_started(:logger_backends)
  LoggerBackends.add(RingLogger)
end
