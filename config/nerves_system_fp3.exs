import Config

# Use shoehorn for orderly boot — fail-soft on individual app crashes
# so we still get into Livebook even if (say) the modem doesn't come up.
config :shoehorn,
  init: [:nerves_runtime, :nerves_pack],
  app: Mix.Project.config()[:app]

# vintage_net: try ethernet over USB gadget first, then any of the
# FP3's onboard interfaces. Livebook listens on all of them once one
# comes up.
config :vintage_net,
  regulatory_domain: "BE",
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
  ]

# CPU governor: don't pin to performance at boot — let workshop
# attendees experience the default thermals. They can opt into
# perf via `CpuGovernor.Performance.with_performance/1` in a cell.
config :nerves_ai,
  governor_at_boot: :default,
  thread_pool: :perf_cluster

# Audio mixer state: configure ALSA routing to speaker by default.
# Vibration handled separately by sysfs.
config :ex_audio,
  defaults: %{
    "Headphone Playback Volume" => "70%",
    "Speaker Playback Volume" => "70%"
  }

# Modem: low-power on shutdown for battery.
config :fp3_modem,
  on_boot: :online,
  on_shutdown: :low_power

# Pin the Livebook web endpoint to a known port and bind it to all
# interfaces so attendees can reach it from any connected network.
config :livebook, :iframe_port, 4001

config :livebook, LivebookWeb.Endpoint,
  url: [host: "nerves.local", port: 80],
  http: [port: 4000, ip: {0, 0, 0, 0}],
  server: true,
  secret_key_base: "REPLACE_ME_WITH_AT_LEAST_64_BYTES_FOR_PROD_DEPLOYMENT_SECURITY"
