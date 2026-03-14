#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

TARGET_SAMPLE_RATE = 16_000
WINDOW_SIZE = 1_024
HOP_SIZE = 256
EPSILON = 1e-8

FEATURE_NAMES = [
    "rms_db_mean",
    "rms_db_std",
    "zero_crossing_rate_mean",
    "zero_crossing_rate_std",
    "abs_diff_mean",
    "abs_diff_std",
    "frame_flux_mean",
    "frame_flux_std",
    "peak_to_rms_mean",
    "peak_to_rms_std",
]


@dataclass(frozen=True)
class Sample:
    path: Path
    label: str
    features: np.ndarray


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--overlay-tone", type=Path)
    return parser.parse_args()


def load_audio(path: Path) -> np.ndarray:
    audio, sample_rate = sf.read(path, dtype="float32")
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    if sample_rate != TARGET_SAMPLE_RATE:
        gcd = math.gcd(sample_rate, TARGET_SAMPLE_RATE)
        up = TARGET_SAMPLE_RATE // gcd
        down = sample_rate // gcd
        audio = resample_poly(audio, up=up, down=down).astype(np.float32)
    return audio


def frame_audio(audio: np.ndarray) -> np.ndarray:
    if audio.size < WINDOW_SIZE:
        audio = np.pad(audio, (0, WINDOW_SIZE - audio.size))

    remainder = (audio.size - WINDOW_SIZE) % HOP_SIZE
    if remainder:
        audio = np.pad(audio, (0, HOP_SIZE - remainder))

    frame_count = 1 + ((audio.size - WINDOW_SIZE) // HOP_SIZE)
    indices = (
        np.arange(WINDOW_SIZE)[None, :]
        + (np.arange(frame_count)[:, None] * HOP_SIZE)
    )
    return audio[indices]


def compute_features(path: Path) -> np.ndarray:
    audio = load_audio(path)
    return compute_features_from_audio(audio)


def compute_features_from_audio(audio: np.ndarray) -> np.ndarray:
    frames = frame_audio(audio)

    rms = np.sqrt(np.mean(np.square(frames), axis=1) + EPSILON)
    rms_db = 20.0 * np.log10(rms + EPSILON)

    sign_changes = np.diff(np.signbit(frames), axis=1)
    zero_crossing_rate = np.mean(np.abs(sign_changes), axis=1)
    abs_diff = np.mean(np.abs(np.diff(frames, axis=1)), axis=1)
    peak = np.max(np.abs(frames), axis=1)
    peak_to_rms = peak / np.maximum(rms, EPSILON)
    frame_flux = np.abs(np.diff(rms_db))
    if frame_flux.size == 0:
        frame_flux = np.zeros(1, dtype=np.float64)

    return np.array(
        [
            float(np.mean(rms_db)),
            float(np.std(rms_db)),
            float(np.mean(zero_crossing_rate)),
            float(np.std(zero_crossing_rate)),
            float(np.mean(abs_diff)),
            float(np.std(abs_diff)),
            float(np.mean(frame_flux)),
            float(np.std(frame_flux)),
            float(np.mean(peak_to_rms)),
            float(np.std(peak_to_rms)),
        ],
        dtype=np.float64,
    )


def mix_with_tone(audio: np.ndarray, tone: np.ndarray, gain: float, offset: int) -> np.ndarray:
    if tone.size == 0:
        return audio

    repeated = np.resize(np.roll(tone, offset), audio.size).astype(np.float32)
    mixed = audio + (repeated * gain)
    peak = float(np.max(np.abs(mixed)))
    if peak > 0.98:
        mixed = mixed / peak * 0.98
    return mixed.astype(np.float32)


def deterministic_offsets(path: Path, count: int, tone_size: int) -> list[int]:
    if tone_size <= 0:
        return [0] * count

    seed = sum(ord(character) for character in path.stem)
    offsets: list[int] = []
    for index in range(count):
        offsets.append((seed + (index * 997)) % tone_size)
    return offsets


def augmented_feature_vectors(path: Path, overlay_tone: np.ndarray | None) -> list[np.ndarray]:
    audio = load_audio(path)
    feature_vectors = [compute_features_from_audio(audio)]

    if overlay_tone is None:
        return feature_vectors

    gains = [0.18, 0.32, 0.48]
    offsets = deterministic_offsets(path, len(gains), overlay_tone.size)
    for gain, offset in zip(gains, offsets):
        augmented = mix_with_tone(audio, overlay_tone, gain=gain, offset=offset)
        feature_vectors.append(compute_features_from_audio(augmented))

    return feature_vectors


def collect_samples(dataset_dir: Path, overlay_tone: np.ndarray | None) -> list[Sample]:
    samples: list[Sample] = []
    for label in ("shower_on", "not_shower"):
        directory = dataset_dir / label
        if not directory.exists():
            raise FileNotFoundError(f"Missing directory: {directory}")
        for path in sorted(directory.iterdir()):
            if path.suffix.lower() not in {".wav", ".caf", ".aif", ".aiff"}:
                continue
            for features in augmented_feature_vectors(path, overlay_tone):
                samples.append(Sample(path=path, label=label, features=features))
    if not samples:
        raise ValueError(f"No supported audio files found in {dataset_dir}")
    return samples


def normalize_features(matrix: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    means = np.mean(matrix, axis=0)
    stds = np.std(matrix, axis=0)
    stds = np.where(stds < EPSILON, 1.0, stds)
    normalized = (matrix - means) / stds
    return normalized, means, stds


def choose_threshold(margins: np.ndarray, labels: np.ndarray) -> float:
    candidates = sorted(set(margins.tolist()))
    thresholds = [candidates[0] - 1.0]
    thresholds.extend((left + right) / 2.0 for left, right in zip(candidates, candidates[1:]))
    thresholds.append(candidates[-1] + 1.0)

    best_threshold = 0.0
    best_accuracy = -1.0
    for threshold in thresholds:
        predictions = np.where(margins >= threshold, "shower_on", "not_shower")
        accuracy = float(np.mean(predictions == labels))
        if accuracy > best_accuracy:
            best_accuracy = accuracy
            best_threshold = threshold
    return best_threshold


def build_profile(samples: list[Sample]) -> dict:
    labels = np.array([sample.label for sample in samples])
    matrix = np.vstack([sample.features for sample in samples])
    normalized, means, stds = normalize_features(matrix)

    shower_centroid = np.mean(normalized[labels == "shower_on"], axis=0)
    not_shower_centroid = np.mean(normalized[labels == "not_shower"], axis=0)

    shower_distance = np.linalg.norm(normalized - shower_centroid[None, :], axis=1)
    not_shower_distance = np.linalg.norm(normalized - not_shower_centroid[None, :], axis=1)
    margins = not_shower_distance - shower_distance
    threshold = choose_threshold(margins, labels)

    training_predictions = np.where(margins >= threshold, "shower_on", "not_shower")
    training_accuracy = float(np.mean(training_predictions == labels))

    loo_predictions: list[str] = []
    for index in range(len(samples)):
        train_mask = np.ones(len(samples), dtype=bool)
        train_mask[index] = False

        train_labels = labels[train_mask]
        train_matrix = matrix[train_mask]
        normalized_train, train_means, train_stds = normalize_features(train_matrix)
        train_shower_centroid = np.mean(normalized_train[train_labels == "shower_on"], axis=0)
        train_not_shower_centroid = np.mean(normalized_train[train_labels == "not_shower"], axis=0)

        train_shower_distance = np.linalg.norm(
            normalized_train - train_shower_centroid[None, :],
            axis=1,
        )
        train_not_shower_distance = np.linalg.norm(
            normalized_train - train_not_shower_centroid[None, :],
            axis=1,
        )
        train_margins = train_not_shower_distance - train_shower_distance
        train_threshold = choose_threshold(train_margins, train_labels)

        holdout = (matrix[index] - train_means) / train_stds
        holdout_shower_distance = float(np.linalg.norm(holdout - train_shower_centroid))
        holdout_not_shower_distance = float(np.linalg.norm(holdout - train_not_shower_centroid))
        holdout_margin = holdout_not_shower_distance - holdout_shower_distance
        loo_predictions.append("shower_on" if holdout_margin >= train_threshold else "not_shower")

    leave_one_out_accuracy = float(np.mean(np.array(loo_predictions) == labels))

    return {
        "model_type": "centroid_detector",
        "version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "feature_names": FEATURE_NAMES,
        "normalization_means": means.tolist(),
        "normalization_stds": stds.tolist(),
        "shower_centroid": shower_centroid.tolist(),
        "not_shower_centroid": not_shower_centroid.tolist(),
        "decision_threshold": float(threshold),
        "metrics": {
            "training_accuracy": training_accuracy,
            "leave_one_out_accuracy": leave_one_out_accuracy,
            "sample_count": len(samples),
            "sample_counts_by_label": {
                "shower_on": int(np.sum(labels == "shower_on")),
                "not_shower": int(np.sum(labels == "not_shower")),
            },
        },
    }


def main() -> None:
    args = parse_args()
    overlay_tone = load_audio(args.overlay_tone) if args.overlay_tone else None
    samples = collect_samples(args.dataset, overlay_tone)
    profile = build_profile(samples)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(profile, indent=2, sort_keys=True))

    metrics = profile["metrics"]
    print(
        json.dumps(
            {
                "output": str(args.output),
                "training_accuracy": metrics["training_accuracy"],
                "leave_one_out_accuracy": metrics["leave_one_out_accuracy"],
                "sample_counts_by_label": metrics["sample_counts_by_label"],
            },
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
