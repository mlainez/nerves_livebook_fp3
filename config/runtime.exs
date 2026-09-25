import Config

# Evaluated after all dependencies are compiled, so it's safe to call
# into :livebook here — unlike config.exs, which runs before deps.get.
config :livebook,
  default_runtime: Livebook.Runtime.Embedded.new(),
  default_app_runtime: Livebook.Runtime.Embedded.new()
