# Changelog

## Unreleased - 2026-03-13

### Added
- A native iPhone app target, `SleepTrackerIOS.xcodeproj`, alongside the existing web app.
- A local Garmin screenshot importer that parses ordered `summary -> timeline -> metrics` screenshots into a structured sleep record.
- Shared Swift core models and analysis logic in `Sources/GarminImportCore`.
- Shared Supabase-backed mobile sync for daily logs and habits so iOS and web use the same dataset.
- A new `Alarm` tab for the personalized shower-alarm prototype.
- Local alarm state persistence, AlarmKit scheduling hooks, microphone/alarm permissions, and in-app labeled sample recording for shower-classifier data collection.
- Design docs for the importer and shower alarm in `docs/ios-import-v1.md` and `docs/shower-alarm-v1.md`.

### Changed
- The iPhone home screen is now optimized for a faster morning scan with habit impact and recommendations surfaced earlier.
- The mobile app now collects the richer Garmin metric set, not just the smaller manual-entry subset from the original web flow.
- Morning screenshot selection now happens in one ordered photo-library pass instead of separate pickers.

### Fixed
- Garmin OCR parsing now tolerates common label drift like `SpO2` OCR noise and `HRV`/`HRY` confusion.
- Blank Garmin skin-temperature values no longer block an import.
- Habit recommendations now handle negated habits more naturally, for example turning `No sports tonight` into `Do sports tonight` when appropriate.
- Supabase save behavior was tightened for mobile and web-side daily log/habit persistence.

### Validation
- `swift test --disable-sandbox` passes for parser, dashboard, and alarm-core logic.
- Generic iPhoneOS `xcodebuild` passes for `SleepTrackerIOS`.

### Known Gap
- The shower alarm can now schedule alarms and collect the labeled audio dataset, but the fully automatic “shower sound stops the lock-screen alarm” behavior still depends on training and testing a custom on-device classifier.
