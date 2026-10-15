import Config

# Route Logger output into RingLogger (view with RingLogger.attach/0 or
# `log` in IEx) instead of spraying the console. Same as the current
# `mix nerves.new` template.
Application.ensure_all_started(:logger_backends)
LoggerBackends.add(RingLogger)
