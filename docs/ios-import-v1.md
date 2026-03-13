# iOS Garmin Import V1

## Understanding Summary
- Build a native iPhone-side Garmin screenshot importer while keeping the current Supabase backend shared with the web app.
- V1 goal is to prove local extraction from Garmin screenshots, not to finish the full mobile product.
- Daily capture routine is fixed-order: `summary`, `timeline`, `metrics`.
- The importer should collect all visible Garmin sleep fields across those three screenshots.
- Parsing must stay local on-device with no external OCR/API dependency.
- The UX should minimize daily friction; incorrect screenshots should be rejected instead of silently guessed.
- Screenshots are temporary inputs, not long-term stored records.

## Assumptions
- V1 can start as a Swift parser package that is Xcode-openable before a full SwiftUI app shell exists.
- Apple Vision OCR is the primary OCR mechanism for both tests and the eventual iOS app.
- Richer Garmin fields will require backend schema expansion later, but parser output should already model them now.
- The user can keep screenshot order consistent enough for deterministic parsing.

## Decision Log
| Decision | Alternatives Considered | Why Chosen |
|----------|--------------------------|------------|
| Use local OCR + deterministic rules instead of a trained model | Custom vision model, external OCR API | The sample set is too small to train reliably and local OCR satisfies privacy/cost constraints. |
| Fix the capture order to `summary -> timeline -> metrics` | Auto-detect screenshot types | Fixed order reduces parser ambiguity and daily friction. |
| Build parser core before the full mobile UX | Start with complete SwiftUI app | The main V1 risk is extraction accuracy, so parser validation should come first. |
| Keep web and mobile on the same backend | Separate mobile data store | Shared backend preserves continuity and lets both clients reflect the same records. |

## Final Design

### Architecture
The first implementation unit is a Swift package that Xcode can open directly. It contains:
- a Garmin sleep domain model,
- a Vision-backed OCR layer,
- deterministic parsers for the three screenshot types,
- merger logic that produces one sleep record,
- tests that use the real screenshot fixtures in `photo_garmin/`.

Once the parser is stable, a SwiftUI app target will wrap it with a photo-import flow and Supabase sync.

### Parsing Strategy
Each screenshot type has a dedicated parser:
- `summary`: date label, sleep score, quality, duration, headline text.
- `timeline`: date label, bedtime, wake time.
- `metrics`: stages and the detailed metric grid.

OCR output should preserve bounding boxes so the parser can use position when plain text ordering is ambiguous. If a required field cannot be extracted with sufficient confidence, the importer should fail that screenshot explicitly.

### V1 Output
The parser should produce a normalized record containing:
- sleep date,
- score, quality, duration,
- deep/light/REM/awake stage totals,
- bedtime and wake time,
- breathing variations, restlessness,
- resting heart rate, body battery change,
- average/lowest SpO2,
- average/lowest respiration,
- average overnight HRV,
- 7-day HRV status,
- average skin temperature change.

### V1 Non-Goals
- final mobile navigation and dashboard polish,
- full Supabase schema migration,
- habit-input UX,
- automatic correction for arbitrarily bad screenshots,
- any custom-trained OCR or vision model.
