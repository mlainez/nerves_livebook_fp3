#!/usr/bin/env bash
# Pre-download every workshop model into rootfs_overlay/srv/models/.
# Run this on the HOST before `mix firmware` so the firmware image
# contains everything attendees need offline.
#
# Total download: ~3.2 GB. Re-runs skip already-downloaded files.

set -euo pipefail

cd "$(dirname "$0")/.."
DEST="rootfs_overlay/srv/models"
mkdir -p "$DEST"

fetch() {
  local url="$1" name="$2"
  if [ -f "$DEST/$name" ]; then
    printf '  ✓ %s (cached)\n' "$name"
    return
  fi
  printf '  ↓ %s\n' "$name"
  curl -fSL -o "$DEST/$name.tmp" "$url"
  mv "$DEST/$name.tmp" "$DEST/$name"
}

echo "Fetching workshop models into $DEST/ …"

# TinyLlama 1.1B Chat Q4_K_M (~700 MB) — TheBloke / GGUF
fetch \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf" \
  "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

fetch \
  "https://huggingface.co/TinyLlama/TinyLlama-1.1B-Chat-v1.0/resolve/main/tokenizer.json" \
  "tinyllama-tokenizer.json"

# Whisper tiny.en quantized (~30 MB) — ggerganov/whisper.cpp's own
# GGUF conversion, the format candle-transformers' quantized Whisper
# loader expects (the distil-whisper GGUF this used to point at is
# gone: the HF repo now 401s).
fetch \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin" \
  "whisper-tiny-q5_1.bin"

fetch \
  "https://huggingface.co/openai/whisper-tiny.en/resolve/main/tokenizer.json" \
  "whisper-tokenizer.json"

# Mel filterbanks: 80 mel bins x 201 fft bins, raw little-endian f32
# (64320 bytes) — candle's own whisper example ships this exact file.
# (The Xenova/whisper-web space this used to point at dropped it.)
fetch \
  "https://raw.githubusercontent.com/huggingface/candle/main/candle-examples/examples/whisper/melfilters.bytes" \
  "whisper-mel-filters.bin"

# YOLOv5n in ONNX (~7.5 MB)
fetch \
  "https://github.com/ultralytics/yolov5/releases/download/v7.0/yolov5n.onnx" \
  "yolov5n.onnx"

# Silero VAD V4 ONNX (~1.8 MB)
fetch \
  "https://github.com/snakers4/silero-vad/raw/v4.0/files/silero_vad.onnx" \
  "silero_vad.onnx"

# Piper en_US-amy-medium (~70 MB) + its config
fetch \
  "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx" \
  "en_US-amy-medium.onnx"

fetch \
  "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx.json" \
  "en_US-amy-medium.onnx.json"

echo ""
echo "Done. Total size of $DEST/:"
du -sh "$DEST"
echo ""
echo "Now run: mix firmware && mix burn  (or mix upload)"
