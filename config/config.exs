import Config

# Make sure Livebook's apps boot in the right order.
config :nerves, source_date_epoch: "1700000000"

# Use shoehorn to start the main application. See the shoehorn
# documentation on hexdocs.pm/shoehorn for the full options.
config :shoehorn,
  init: [:nerves_runtime, :nerves_pack, :nerves_ai],
  app: Mix.Project.config()[:app]

# Use Ringlogger as the logger backend so the log buffer is
# available from `RingLogger.next/0` in iex / Livebook.
config :logger, backends: [RingLogger]

# Erlang's logger is configured by other libraries; tell it to
# defer formatting to our ring logger.
config :logger, RingLogger,
  max_size: 1024,
  application_levels: %{ssh: :error}

# Livebook reads its own config/config.exs defaults only when it's the
# root Mix project — as a dependency here, none of that applies, and
# several of its modules read compile-time config (Application.compile_env
# / fetch_env!) that would otherwise be missing entirely and crash
# `mix compile`. Replicate its defaults (deps/livebook/config/config.exs)
# so it boots the way it would standalone; our own overrides come after
# and take precedence per key.
config :livebook, LivebookWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost", path: "/"],
  pubsub_server: Livebook.PubSub,
  live_view: [signing_salt: "livebook"],
  drainer: [shutdown: 1000],
  render_errors: [formats: [html: LivebookWeb.ErrorHTML], layout: false]

config :phoenix, :json_library, JSON

config :mime, :types, %{
  "audio/m4a" => ["m4a"],
  "text/plain" => ["livemd"]
}

config :livebook,
  agent_name: "default",
  allowed_uri_schemes: [],
  app_service_url: nil,
  apps_banner: nil,
  aws_credentials: false,
  feature_flags: [],
  force_ssl_host: nil,
  learn_notebooks: [],
  plugs: [],
  rewrite_on: [],
  shutdown_callback: nil,
  teams_auth: nil,
  teams_url: "https://teams.livebook.dev",
  github_release_info: %{repo: "livebook-dev/livebook", version: "0.19.10"},
  update_instructions_url: nil,
  within_iframe: false,
  k8s_kubeconfig_pipeline: Kubereq.Kubeconfig.Default

config :livebook, Livebook.Apps.Manager, retry_backoff_base_ms: 5_000

# Workshop-specific overrides — token-less (the device is the trust
# boundary; you have to be on the local network).
#
# default_runtime / default_app_runtime live in config/runtime.exs:
# Livebook.Runtime.Embedded.new() calls into :livebook, which isn't
# compiled yet when config.exs runs.
config :livebook,
  app_service_name: "nerves-livebook-fp3",
  authentication: :disabled,
  home: "/data/livebook/notebooks",
  apps_path: "/data/livebook/apps",
  cookie: :nerves_livebook_fp3

# Where the workshop notebooks live on disk. We bake them into
# /srv/livebook/notebooks/ in the rootfs overlay; on first boot
# we copy them to /data/livebook/notebooks/ so they're writable
# (Livebook needs to be able to save state next to them).
#
# On the writable paths: erlinit mounts /dev/mmcblk0p62p3 (f2fs)
# at /root, and nerves_system_br's skeleton ships /data as a
# symlink to root — so /data/... and /root/... are the same
# storage. We use /data here because that's the Nerves-facing
# name. /srv is on the read-only rootfs.
config :nerves_livebook_fp3,
  notebooks_source: "/srv/livebook/notebooks",
  notebooks_dest: "/data/livebook/notebooks"

# Pre-baked model paths. NervesModelHub's app config takes a list of
# {id, [source: ..., path: ...]} entries. We point `source` at the
# baked-in /srv path so the on-first-boot logic copies (not
# downloads) into /data/models/.
config :nerves_ai, :models,
  tinyllama: [
    source: {:file, "/srv/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"},
    path: "/data/models/tinyllama.gguf"
  ],
  tinyllama_tokenizer: [
    source: {:file, "/srv/models/tinyllama-tokenizer.json"},
    path: "/data/models/tinyllama-tokenizer.json"
  ],
  whisper_tiny: [
    source: {:file, "/srv/models/whisper-tiny-q5_1.bin"},
    path: "/data/models/whisper-tiny.gguf"
  ],
  whisper_tokenizer: [
    source: {:file, "/srv/models/whisper-tokenizer.json"},
    path: "/data/models/whisper-tokenizer.json"
  ],
  whisper_mel_filters: [
    source: {:file, "/srv/models/whisper-mel-filters.bin"},
    path: "/data/models/whisper-mel-filters.bin"
  ],
  yolov5n: [
    source: {:file, "/srv/models/yolov5n.onnx"},
    path: "/data/models/yolov5n.onnx"
  ],
  silero_vad: [
    source: {:file, "/srv/models/silero_vad.onnx"},
    path: "/data/models/silero_vad.onnx"
  ],
  piper_voice: [
    source: {:file, "/srv/models/en_US-amy-medium.onnx"},
    path: "/data/models/en_US-amy-medium.onnx"
  ],
  # Piper's voice config carries the `phoneme_id_map` that
  # ArmAI.Phonemizer.to_phoneme_ids/2 needs — without it there is
  # no way to turn text into the IDs Piper.synthesize/3 expects.
  piper_voice_config: [
    source: {:file, "/srv/models/en_US-amy-medium.onnx.json"},
    path: "/data/models/en_US-amy-medium.onnx.json"
  ]

# First-boot F2FS grow of the /root partition (idempotent — the
# resizer reports :already_grown once the FS fills the partition).
# Keys and app namespace must match NervesDataResize.run/1, which
# reads `config :nerves_data_resize, :config`.
config :nerves_data_resize, :config,
  partition: "/dev/mmcblk0p62p3",
  mount_point: "/root",
  mount_opts: "nodev"

import_config "#{Mix.target()}.exs"
