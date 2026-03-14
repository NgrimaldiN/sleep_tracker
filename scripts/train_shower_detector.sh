#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 ]]; then
  cat <<'EOF' >&2
Usage:
  scripts/train_shower_detector.sh /abs/path/to/dataset_dir /abs/path/to/output_dir
  scripts/train_shower_detector.sh /abs/path/to/dataset_dir /abs/path/to/output_dir --overlay-tone /abs/path/to/tone.wav

Dataset layout:
  dataset_dir/
    shower_on/
      clip-1.wav
      ...
    not_shower/
      clip-1.wav
      ...
EOF
  exit 1
fi

DATASET_DIR="$1"
OUTPUT_DIR="$2"
OUTPUT_PATH="$OUTPUT_DIR/ShowerDetectorProfile.json"

mkdir -p "$OUTPUT_DIR"
python3 "$PWD/scripts/train_shower_detector.py" \
  --dataset "$DATASET_DIR" \
  --output "$OUTPUT_PATH" \
  "${@:3}"
