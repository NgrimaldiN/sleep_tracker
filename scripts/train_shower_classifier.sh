#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 ]]; then
  cat <<'EOF' >&2
Usage:
  scripts/train_shower_classifier.sh /abs/path/to/dataset_dir /abs/path/to/output_dir

Dataset layout:
  dataset_dir/
    shower_on/
      clip-1.wav
      ...
    not_shower/
      clip-1.wav
      ...

The dataset must already contain PCM .wav or .caf files.
EOF
  exit 1
fi

DATASET_DIR="$1"
OUTPUT_DIR="$2"
MODEL_PATH="$OUTPUT_DIR/ShowerSoundClassifier.mlmodel"
COMPILED_DIR="$OUTPUT_DIR/compiled"

mkdir -p "$PWD/.xcodebuild/ModuleCache.noindex" "$OUTPUT_DIR"
CLANG_MODULE_CACHE_PATH="$PWD/.xcodebuild/ModuleCache.noindex" \
  /usr/bin/xcrun swift "$PWD/scripts/train_shower_classifier.swift" \
    --dataset "$DATASET_DIR" \
    --model-output "$MODEL_PATH" \
    --compiled-output-dir "$COMPILED_DIR"
