# Shower Alarm V1

## Understanding Summary
- Build a second major feature inside the same iPhone app: a real wake-up alarm.
- The alarm must ring while the phone is locked.
- The intended stop condition is the sound of the shower starting.
- The user will bring the iPhone into the bathroom, which makes audio capture realistic.
- All audio processing must stay local on-device.
- This is a single-user personalized feature, not a general-purpose App Store product.
- The first implementation should be honest about what is already testable and what still depends on collected training data.

## Assumptions
- The user’s iPhone is on iOS 26 or later if they want the AlarmKit-backed experience.
- The user is willing to grant microphone access.
- Alarm configuration and training audio should remain local to the device.
- A custom on-device Core ML classifier is acceptable once training data exists.
- Power usage is acceptable for a prototype if overnight armed listening is required to prove the lock-screen flow.

## Approaches Considered

### 1. AlarmKit + custom shower classifier + armed overnight listener
Recommended.

Use AlarmKit for app-owned alarms, collect user-specific bathroom audio, train a small custom sound classifier, and keep an armed microphone listener ready overnight so shower detection can matter while the phone is locked.

Pros:
- Matches the real product goal.
- Keeps everything local.
- Personalized to one shower, one bathroom, one phone placement.

Cons:
- Requires custom training data.
- Lock-screen/background audio behavior still needs device proof.
- Higher implementation complexity than a standard alarm.

### 2. AlarmKit + foreground-only shower verification
Rejected.

The app could ring as a real alarm, then open into the app and only stop once it hears the shower while the app is active.

Why rejected:
- It fails the core user requirement.
- It still allows the user to dismiss and go back to bed.

### 3. Puzzle/scan/photo wake-up challenge
Rejected.

The app could require a barcode scan, QR scan, or manual action in the bathroom.

Why rejected:
- It is a common workaround, not the product asked for.
- It solves “don’t snooze” in a more annoying way, not in the shower-specific way the user wants.

## Decision Log
| Decision | Alternatives | Why this won |
|----------|--------------|--------------|
| Use AlarmKit for the alarm | Local notification hacks, timer-only flows | AlarmKit is the real app-owned alarm framework in the installed SDK. |
| Use a custom classifier instead of a built-in generic sound label | Generic sound labels, heuristic amplitude detection | The target sound is highly environment-specific and should be personalized. |
| Build sample collection directly into the app | Ask the user to collect files manually outside the app | In-app recording lowers friction and keeps the dataset consistent. |
| Separate scheduling from detection readiness | Pretend the full feature is ready immediately | The honest path is schedule now, train detector next, then prove the full loop on-device. |
| Keep alarm data local | Sync everything to Supabase | Alarm time, permissions, and raw audio are device-specific and not part of the shared sleep analysis dataset. |

## V1 Architecture

### Core logic
Shared package code defines:
- alarm configuration
- sample kinds and target counts
- readiness status
- data-collection requirements
- copy for the UI

This keeps the planning and readiness logic testable without iOS runtime dependencies.

### iOS runtime layer
The iOS target adds:
- an `Alarm` tab
- local alarm state persistence
- AlarmKit permission + scheduling service
- microphone permission service
- in-app labeled sample recording to local files

### Detection path
The app will be structured for:
1. user enables an alarm time
2. user records labeled bathroom audio clips
3. a custom shower classifier is trained from those clips
4. the classifier is bundled back into the app
5. the app arms background listening overnight
6. when the alarm window is active and the shower is detected, the app stops the alarm

Step 5 and step 6 are the parts that still need on-device proof after the model exists.

## Exact Audio Data Required

The first training pack should be:

| Label | Clips | Seconds per clip | Goal |
|-------|-------|------------------|------|
| `shower_on` | 12 | 8 | Positive class: water from the actual shower you use |
| `bathroom_ambient` | 8 | 8 | Bathroom room tone without water |
| `sink_running` | 8 | 8 | Faucet/sink noise so it is not confused with shower |
| `bathroom_fan` | 8 | 8 | Ventilation noise if present |
| `speech_movement` | 8 | 8 | You moving, speaking, handling the phone |
| `silence` | 6 | 8 | Quiet baseline noise floor |

Total: 50 clips, 400 seconds, about 6 minutes 40 seconds of labeled audio.

### Capture rules
- Keep the phone in realistic bathroom positions.
- Vary placement slightly across clips: sink counter, near the shower, closer to the door.
- Do not stack multiple labels in one clip.
- Prefer steady sound during each clip.
- Record at least a few clips with the bathroom door open and closed if that changes the sound substantially.

## Known Risks
- Apple’s public materials reviewed so far support the ingredients, but do not explicitly guarantee the full “locked phone hears shower and auto-stops alarm” loop.
- The first trained model may need one or two retraining passes after real-world bathroom tests.
- If the phone is left too far from the shower, false negatives become much more likely.

## Implementation Scope For This Pass
- Add the `Alarm` tab.
- Add local alarm state and readiness UI.
- Add alarm permission handling.
- Add microphone permission handling.
- Add local labeled-sample recording.
- Add AlarmKit scheduling hooks.

Not promised in this pass:
- a finished shower classifier model
- guaranteed lock-screen auto-stop behavior before the first real training/test cycle
