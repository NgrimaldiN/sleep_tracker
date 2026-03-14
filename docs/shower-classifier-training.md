# Shower Classifier Training

## Current Path

The working path is now the portable detector, not Apple’s built-in Create ML sound trainer.

It trains a small binary profile from your bathroom audio:

- `shower_on`
- `not_shower`

The exported artifact is a JSON detector profile that the iPhone app can bundle or install locally:

- `ShowerDetectorProfile.json`

This avoids the Create ML `SoundAnalysis` crash that happens on this Mac during feature extraction.

## Baseline Dataset

For the first detector, the app now treats these as the required baseline sounds:

- `shower_on`
- `bathroom_ambient`
- `speech_movement`

These are still useful, but optional for the first pass:

- `sink_running`
- `bathroom_fan`
- `silence`

The training scripts flatten all negative examples into `not_shower`.

## Working Commands

Train the portable detector from a PCM dataset:

```bash
zsh scripts/train_shower_detector.sh /abs/path/to/dataset_dir /abs/path/to/output_dir
```

To train for the real wake-up mission, include the bundled alarm tone so the model also sees
`shower + alarm tone` and `not shower + alarm tone` mixes:

```bash
zsh scripts/train_shower_detector.sh \
  /abs/path/to/dataset_dir \
  /abs/path/to/output_dir \
  --overlay-tone /abs/path/to/WakeMissionTone.wav
```

Expected dataset layout:

```text
dataset_dir/
  shower_on/
    clip-1.wav
    clip-2.wav
  not_shower/
    clip-1.wav
    clip-2.wav
```

The script writes:

- `ShowerDetectorProfile.json`

## Current Trained Profile

The repo currently includes a trained detector profile at:

- [`SleepTrackerIOS/ShowerDetectorProfile.json`](/Users/ines/Nicolas/sleep_tracker/SleepTrackerIOS/ShowerDetectorProfile.json)

It was trained from:

- 13 `shower_on` clips
- 16 `not_shower` clips
- plus synthetic alarm-tone overlays for both labels

Recorded metrics for this profile:

- training accuracy: `0.9655`
- leave-one-out accuracy: `0.9224`

These are promising, but they are still small-sample metrics from one bathroom and one user.

## Why This Exists

The original `MLSoundClassifier` training path is still kept in the repo as an experiment, but on this machine it crashes inside Apple’s sound feature extractor. The portable detector gives us:

- a reproducible trainer
- a readable model artifact
- a path to implement the same scoring logic inside the iPhone app

without depending on that unstable training stack.

## Runtime Status

The iPhone app now includes a `Live Detector` test card in the `Alarm` tab.

That runtime path uses:

- the bundled `ShowerDetectorProfile.json`
- the shared Swift feature extractor in `AlarmFeatureCore.swift`
- a small smoothing gate so one noisy buffer does not falsely confirm the shower

The next proof still has to happen on-device in your bathroom:

- start `Live Detector`
- turn the real shower on near the phone
- confirm the detector reaches `Shower confirmed`
