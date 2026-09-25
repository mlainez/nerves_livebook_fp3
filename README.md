# nerves_livebook_fp3

> ### ⚠️ Very early work — built for a workshop, not for production
>
> Written for the **Goatmire Elixir workshop** on running Nerves on
> Fairphone 3 hardware. It exists for tinkering and teaching.
>
> **Not an actively maintained project** (yet) — no stability
> guarantees, no test coverage, APIs will change without notice.

Workshop firmware for the FairPhone 3+: boots straight into a
Livebook with pre-loaded notebooks demonstrating every onboard
capability — sensors, cameras, LEDs, vibration, GPS, modem,
NFC, audio — plus a full edge-AI inference stack (chat, vision,
speech-to-text, text-to-speech, multimodal pipelines, Bumblebee).

## At workshop time

1. Power on the FP3.
2. On your laptop, open `http://nerves.local:4000` in a browser.
3. The Livebook UI appears with the workshop notebooks listed.
4. Click any notebook, hit "Evaluate", watch it run.

Everything works offline — models are baked into the firmware.

## Notebook curriculum

### Hardware discovery (~30-40 min)

| Notebook | What it covers |
|---|---|
| `10_sensors.livemd` | Accelerometer / gyro / magnetometer (IIO sysfs) |
| `11_camera.livemd` | Snapshot from front + rear cameras |
| `12_leds.livemd` | RGB notification LED control |
| `13_vibration.livemd` | Haptic motor patterns |
| `14_gps.livemd` | GNSS position + satellites |
| `15_modem.livemd` | Cellular signal, IMEI, network info |
| `16_nfc.livemd` | NFC tag reading (NDEF, Mifare, …) |
| `17_audio.livemd` | Speaker output + mic capture |

### AI demos (~30-40 min)

| Notebook | What it covers |
|---|---|
| `01_hello_llm.livemd` | TinyLlama chat — prompt → text |
| `02_see.livemd` | YOLOv5 object detection on JPEG |
| `03_hear.livemd` | Whisper STT on an audio clip |
| `04_speak.livemd` | Piper TTS — text → spoken WAV |
| `05_mix.livemd` | Voice assistant chain (VAD → STT → LLM → TTS) |
| `06_bumblebee.livemd` | Bumblebee ViT running on NxArm.Backend |

## For the workshop organiser

### Prerequisites

* A Rust toolchain (`rustc`/`cargo`), plus the `aarch64-unknown-linux-gnu`
  target (`rustup target add aarch64-unknown-linux-gnu`). `arm_ai` has
  no precompiled-NIF release yet, so its Rust NIF always builds from
  source — including when cross-compiling the real firmware.

### One-time setup on host

```sh
# Get the deps
mix deps.get

# Download every model into rootfs_overlay/srv/models/ (~3.2 GB)
./scripts/fetch_models.sh
```

### Build the firmware

```sh
export MIX_TARGET=nerves_system_fp3
mix deps.get
mix firmware
```

### Flash a device

For initial provisioning (or recovery):

```sh
# Put the FP3 into fastboot mode (volume-down + power)
mix firmware.image
fastboot flash userdata _build/${MIX_TARGET}_prod/${MIX_TARGET}/firmware/nerves_livebook_fp3.img
fastboot reboot
```

For an already-provisioned device on your network:

```sh
mix upload
```

### Many devices in parallel

See `scripts/flash_workshop_devices.sh` (TODO) — uses udev rules to
fastboot-flash every connected FP3 in parallel.

## What's actually running on the device

```
nerves_livebook_fp3 (this firmware)
├── nerves_system_fp3        (FP3 hardware system, kernel, base userspace)
├── nerves_ai                (meta-package wiring the AI stack)
│   ├── arm_ai               (NIF: candle / tract-onnx / rustfft / symphonia)
│   ├── nx_arm               (Nx.Backend over NEON kernels)
│   ├── nx_primitives        (FFT / embeddings / quantized)
│   ├── infer_llm            (Whisper + LLM Nx wrappers)
│   ├── infer_vision         (YOLO / OCR / Face / generic ONNX)
│   ├── infer_audio          (Silero VAD / Piper TTS)
│   ├── cpu_governor         (perf-cluster scope + topology)
│   ├── nerves_model_hub            (first-boot model sync)
│   └── nerves_data_resize     (first-boot F2FS grow)
├── ex_nfc / ex_location / ex_audio / fp3_camera / fp3_modem
├── ex_qcom_smgr (IIO sensors via ADSP)
└── livebook + kino + kino_vega_lite + kino_maplibre + kino_bumblebee
```

## License

Apache-2.0.
