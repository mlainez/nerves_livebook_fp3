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

# Livebook configuration — token-less for the workshop (the device
# is the trust boundary; you have to be on the local network).
#
# default_runtime / default_app_runtime live in config/runtime.exs:
# Livebook.Runtime.Embedded.new() calls into :livebook, which isn't
# compiled yet when config.exs runs.
config :livebook,
  app_service_name: "nerves-livebook-fp3",
  authentication: :disabled,
  notebook_directory: "/data/livebook/notebooks",
  apps_path: "/data/livebook/apps",
  cookie: :"nerves_livebook_fp3"

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
config :nerves_ai, :models, [
  tinyllama: [
    source: {:file, "/srv/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"},
    path: "/data/models/tinyllama.gguf"
  ],
  tinyllama_tokenizer: [
    source: {:file, "/srv/models/tinyllama-tokenizer.json"},
    path: "/data/models/tinyllama-tokenizer.json"
  ],
  whisper_tiny: [
    source: {:file, "/srv/models/whisper-tiny-q4_0.gguf"},
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
