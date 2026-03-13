import Foundation
import CoreGraphics
import Testing
@testable import GarminImportCore

struct GarminSleepParserTests {
    @Test
    func parseNightBuildsRecordFromOrderedSummaryTimelineAndMetrics() throws {
        let parser = GarminSleepParser(
            ocrRecognizer: StubOCRRecognizer(
                linesByFileName: [
                    "2026-02-24_summary.jpeg": [
                        line("Tuesday, February 24", x: 0.30, y: 0.88),
                        line("86", x: 0.52, y: 0.76),
                        line("Good", x: 0.12, y: 0.64),
                        line("Quality", x: 0.12, y: 0.61),
                        line("8h 1m", x: 0.63, y: 0.64),
                        line("Duration", x: 0.63, y: 0.61),
                        line("Plenty of REM", x: 0.12, y: 0.50),
                    ],
                    "2026-02-24_timeline.jpeg": [
                        line("Tuesday, February 24", x: 0.30, y: 0.88),
                        line("00:55", x: 0.10, y: 0.18),
                        line("09:06", x: 0.82, y: 0.18),
                    ],
                    "2026-02-24_metrics.jpeg": [
                        line("54m", x: 0.08, y: 0.73),
                        line("Deep", x: 0.08, y: 0.70),
                        line("5h 18m", x: 0.58, y: 0.73),
                        line("Light", x: 0.58, y: 0.70),
                        line("1h 49m", x: 0.08, y: 0.63),
                        line("REM", x: 0.08, y: 0.60),
                        line("10m", x: 0.58, y: 0.63),
                        line("Awake", x: 0.58, y: 0.60),
                        line("Minimal", x: 0.08, y: 0.46),
                        line("Breathing Variations", x: 0.08, y: 0.43),
                        line("49", x: 0.58, y: 0.46),
                        line("Restless Moments", x: 0.58, y: 0.43),
                        line("52 bpm", x: 0.08, y: 0.36),
                        line("Resting Heart Rate", x: 0.08, y: 0.33),
                        line("+48", x: 0.58, y: 0.36),
                        line("Body Battery Change", x: 0.58, y: 0.33),
                        line("98 %", x: 0.08, y: 0.26),
                        line("Avg SpO2", x: 0.08, y: 0.23),
                        line("88 %", x: 0.58, y: 0.26),
                        line("Lowest SpO2", x: 0.58, y: 0.23),
                        line("16 brpm", x: 0.08, y: 0.16),
                        line("Avg Respiration", x: 0.08, y: 0.13),
                        line("12 brpm", x: 0.58, y: 0.16),
                        line("Lowest Respiration", x: 0.58, y: 0.13),
                        line("84 ms", x: 0.08, y: 0.06),
                        line("Avg Overnight HRV", x: 0.08, y: 0.03),
                        line("No Status", x: 0.58, y: 0.06),
                        line("7d Avg HRV", x: 0.58, y: 0.03),
                        line("+0,3°", x: 0.08, y: -0.04),
                        line("Avg Skin Temp Change", x: 0.08, y: -0.07),
                    ],
                ]
            )
        )
        let fixtureDirectory = FixturePaths.garminPhotosDirectory

        let summaryURL = fixtureDirectory.appending(path: "2026-02-24_summary.jpeg")
        let timelineURL = fixtureDirectory.appending(path: "2026-02-24_timeline.jpeg")
        let metricsURL = fixtureDirectory.appending(path: "2026-02-24_metrics.jpeg")
        let importedAt = ISO8601DateFormatter().date(from: "2026-02-25T08:30:00Z")!
        let expected = GarminSleepRecord(
            sleepDate: "2026-02-24",
            sleepScore: 86,
            sleepQuality: "Good",
            totalSleepMinutes: 481,
            bedtime: "00:55",
            wakeTime: "09:06",
            summaryHeadline: "Plenty of REM",
            deepSleepMinutes: 54,
            lightSleepMinutes: 318,
            remSleepMinutes: 109,
            awakeMinutes: 10,
            breathingVariations: "Minimal",
            restlessMoments: 49,
            restingHeartRate: 52,
            bodyBatteryChange: 48,
            averageSpO2: 98,
            lowestSpO2: 88,
            averageRespiration: 16,
            lowestRespiration: 12,
            averageOvernightHRV: 84,
            sevenDayHRVStatus: "No Status",
            averageSkinTemperatureChangeCelsius: 0.3
        )

        let record = try parser.parseNight(
            summaryURL: summaryURL,
            timelineURL: timelineURL,
            metricsURL: metricsURL,
            importedAt: importedAt
        )

        #expect(record == expected)
    }

    @Test
    func parseNightIgnoresStatusBarNoiseWhenExtractingScoreAndTimelineTimes() throws {
        let parser = GarminSleepParser(
            ocrRecognizer: StubOCRRecognizer(
                linesByFileName: [
                    "2026-02-24_summary.jpeg": [
                        line("23:29", x: 0.02, y: 0.98),
                        line("95", x: 0.88, y: 0.98),
                        line("Tuesday, February 24", x: 0.30, y: 0.88),
                        line("86", x: 0.52, y: 0.76),
                        line("100", x: 0.52, y: 0.71),
                        line("Score", x: 0.52, y: 0.67),
                        line("Good", x: 0.12, y: 0.64),
                        line("Quality", x: 0.12, y: 0.61),
                        line("8h 1m", x: 0.63, y: 0.64),
                        line("Duration", x: 0.63, y: 0.61),
                        line("Plenty of REM", x: 0.12, y: 0.50),
                    ],
                    "2026-02-24_timeline.jpeg": [
                        line("00:15", x: 0.02, y: 0.98),
                        line("Tuesday, February 24", x: 0.30, y: 0.88),
                        line("00:55", x: 0.10, y: 0.18),
                        line("09:06", x: 0.82, y: 0.18),
                    ],
                    "2026-02-24_metrics.jpeg": [
                        line("54m", x: 0.08, y: 0.73),
                        line("Deep", x: 0.08, y: 0.70),
                        line("5h 18m", x: 0.58, y: 0.73),
                        line("Light", x: 0.58, y: 0.70),
                        line("1h 49m", x: 0.08, y: 0.63),
                        line("REM", x: 0.08, y: 0.60),
                        line("10m", x: 0.58, y: 0.63),
                        line("Awake", x: 0.58, y: 0.60),
                        line("Minimal", x: 0.08, y: 0.46),
                        line("Breathing Variations", x: 0.08, y: 0.43),
                        line("49", x: 0.58, y: 0.46),
                        line("Restless Moments", x: 0.58, y: 0.43),
                        line("52 bpm", x: 0.08, y: 0.36),
                        line("Resting Heart Rate", x: 0.08, y: 0.33),
                        line("+48", x: 0.58, y: 0.36),
                        line("Body Battery Change", x: 0.58, y: 0.33),
                        line("98 %", x: 0.08, y: 0.26),
                        line("Avg SpO2", x: 0.08, y: 0.23),
                        line("88 %", x: 0.58, y: 0.26),
                        line("Lowest SpO2", x: 0.58, y: 0.23),
                        line("16 brpm", x: 0.08, y: 0.16),
                        line("Avg Respiration", x: 0.08, y: 0.13),
                        line("12 brpm", x: 0.58, y: 0.16),
                        line("Lowest Respiration", x: 0.58, y: 0.13),
                        line("84 ms", x: 0.08, y: 0.06),
                        line("Avg Overnight HRV", x: 0.08, y: 0.03),
                        line("No Status", x: 0.58, y: 0.06),
                        line("7d Avg HRV", x: 0.58, y: 0.03),
                        line("+0,3°", x: 0.08, y: -0.04),
                        line("Avg Skin Temp Change", x: 0.08, y: -0.07),
                    ],
                ]
            )
        )

        let fixtureDirectory = FixturePaths.garminPhotosDirectory
        let record = try parser.parseNight(
            summaryURL: fixtureDirectory.appending(path: "2026-02-24_summary.jpeg"),
            timelineURL: fixtureDirectory.appending(path: "2026-02-24_timeline.jpeg"),
            metricsURL: fixtureDirectory.appending(path: "2026-02-24_metrics.jpeg"),
            importedAt: ISO8601DateFormatter().date(from: "2026-02-25T08:30:00Z")!
        )

        #expect(record.sleepScore == 86)
        #expect(record.bedtime == "00:55")
        #expect(record.wakeTime == "09:06")
    }

    @Test
    func parseNightAcceptsCommonHRYOCRMisreadForHRVLabels() throws {
        let parser = GarminSleepParser(
            ocrRecognizer: StubOCRRecognizer(
                linesByFileName: [
                    "2026-02-24_summary.jpeg": [
                        line("Tuesday, February 24", x: 0.30, y: 0.88),
                        line("86", x: 0.52, y: 0.76),
                        line("Good", x: 0.12, y: 0.64),
                        line("Quality", x: 0.12, y: 0.61),
                        line("8h 1m", x: 0.63, y: 0.64),
                        line("Duration", x: 0.63, y: 0.61),
                        line("Plenty of REM", x: 0.12, y: 0.50),
                    ],
                    "2026-02-24_timeline.jpeg": [
                        line("Tuesday, February 24", x: 0.30, y: 0.88),
                        line("00:55", x: 0.10, y: 0.18),
                        line("09:06", x: 0.82, y: 0.18),
                    ],
                    "2026-02-24_metrics.jpeg": [
                        line("54m", x: 0.08, y: 0.73),
                        line("Deep", x: 0.08, y: 0.70),
                        line("5h 18m", x: 0.58, y: 0.73),
                        line("Light", x: 0.58, y: 0.70),
                        line("1h 49m", x: 0.08, y: 0.63),
                        line("REM", x: 0.08, y: 0.60),
                        line("10m", x: 0.58, y: 0.63),
                        line("Awake", x: 0.58, y: 0.60),
                        line("Minimal", x: 0.08, y: 0.46),
                        line("Breathing Variations", x: 0.08, y: 0.43),
                        line("49", x: 0.58, y: 0.46),
                        line("Restless Moments", x: 0.58, y: 0.43),
                        line("52 bpm", x: 0.08, y: 0.36),
                        line("Resting Heart Rate", x: 0.08, y: 0.33),
                        line("+48", x: 0.58, y: 0.36),
                        line("Body Battery Change", x: 0.58, y: 0.33),
                        line("98 %", x: 0.08, y: 0.26),
                        line("Avg SpO2", x: 0.08, y: 0.23),
                        line("88 %", x: 0.58, y: 0.26),
                        line("Lowest SpO2", x: 0.58, y: 0.23),
                        line("16 brpm", x: 0.08, y: 0.16),
                        line("Avg Respiration", x: 0.08, y: 0.13),
                        line("12 brpm", x: 0.58, y: 0.16),
                        line("Lowest Respiration", x: 0.58, y: 0.13),
                        line("84 ms", x: 0.08, y: 0.06),
                        line("Avg Overnight HRY", x: 0.08, y: 0.03),
                        line("No Status", x: 0.58, y: 0.06),
                        line("7d Avg HRY", x: 0.58, y: 0.03),
                        line("+0,3°", x: 0.08, y: -0.04),
                        line("Avg Skin Temp Change", x: 0.08, y: -0.07),
                    ],
                ]
            )
        )

        let fixtureDirectory = FixturePaths.garminPhotosDirectory
        let record = try parser.parseNight(
            summaryURL: fixtureDirectory.appending(path: "2026-02-24_summary.jpeg"),
            timelineURL: fixtureDirectory.appending(path: "2026-02-24_timeline.jpeg"),
            metricsURL: fixtureDirectory.appending(path: "2026-02-24_metrics.jpeg"),
            importedAt: ISO8601DateFormatter().date(from: "2026-02-25T08:30:00Z")!
        )

        #expect(record.averageOvernightHRV == 84)
        #expect(record.sevenDayHRVStatus == "No Status")
    }

    @Test
    func parseNightAcceptsMinorSpO2LabelOCRNoise() throws {
        let parser = GarminSleepParser(
            ocrRecognizer: StubOCRRecognizer(
                linesByFileName: [
                    "2026-02-01_summary.jpeg": [
                        line("Sunday, February 1", x: 0.30, y: 0.88),
                        line("85", x: 0.52, y: 0.76),
                        line("100", x: 0.52, y: 0.71),
                        line("Score", x: 0.52, y: 0.67),
                        line("Good", x: 0.12, y: 0.64),
                        line("Quality", x: 0.12, y: 0.61),
                        line("7h 33m", x: 0.63, y: 0.64),
                        line("Duration", x: 0.63, y: 0.61),
                        line("Plenty of REM", x: 0.12, y: 0.50),
                    ],
                    "2026-02-01_timeline.jpeg": [
                        line("Sunday, February 1", x: 0.30, y: 0.88),
                        line("01:44", x: 0.08, y: 0.16),
                        line("09:28", x: 0.82, y: 0.16),
                    ],
                    "2026-02-01_metrics.jpeg": [
                        line("42m", x: 0.08, y: 0.73),
                        line("Deep", x: 0.08, y: 0.70),
                        line("4h 58m", x: 0.58, y: 0.73),
                        line("Light", x: 0.58, y: 0.70),
                        line("1h 53m", x: 0.08, y: 0.63),
                        line("REM", x: 0.08, y: 0.60),
                        line("11m", x: 0.58, y: 0.63),
                        line("Awake", x: 0.58, y: 0.60),
                        line("--", x: 0.08, y: 0.46),
                        line("Breathing Variations", x: 0.08, y: 0.43),
                        line("35", x: 0.58, y: 0.46),
                        line("Restless Moments", x: 0.58, y: 0.43),
                        line("49 bpm", x: 0.08, y: 0.36),
                        line("Resting Heart Rate", x: 0.08, y: 0.33),
                        line("+37", x: 0.58, y: 0.36),
                        line("Body Battery Change", x: 0.58, y: 0.33),
                        line("99 %", x: 0.08, y: 0.26),
                        line("Avg SpO", x: 0.08, y: 0.23),
                        line("91 %", x: 0.58, y: 0.26),
                        line("Lowest SpO", x: 0.58, y: 0.23),
                        line("15 brpm", x: 0.08, y: 0.16),
                        line("Avg Respiration", x: 0.08, y: 0.13),
                        line("11 brpm", x: 0.58, y: 0.16),
                        line("Lowest Respiration", x: 0.58, y: 0.13),
                        line("83 ms", x: 0.08, y: 0.06),
                        line("Avg Overnight HRV", x: 0.08, y: 0.03),
                        line("Balanced", x: 0.58, y: 0.06),
                        line("7d Avg HRV", x: 0.58, y: 0.03),
                        line("-0,9°", x: 0.08, y: -0.04),
                        line("Avg Skin Temp Change", x: 0.08, y: -0.07),
                    ],
                ]
            )
        )

        let fixtureDirectory = FixturePaths.garminPhotosDirectory
        let record = try parser.parseNight(
            summaryURL: fixtureDirectory.appending(path: "2026-02-01_summary.jpeg"),
            timelineURL: fixtureDirectory.appending(path: "2026-02-01_timeline.jpeg"),
            metricsURL: fixtureDirectory.appending(path: "2026-02-01_metrics.jpeg"),
            importedAt: ISO8601DateFormatter().date(from: "2026-02-02T08:30:00Z")!
        )

        #expect(record.averageSpO2 == 99)
        #expect(record.lowestSpO2 == 91)
    }

    @Test
    func parseNightAllowsBlankSkinTemperatureChange() throws {
        let parser = GarminSleepParser(
            ocrRecognizer: StubOCRRecognizer(
                linesByFileName: [
                    "2026-02-01_summary.jpeg": [
                        line("Sunday, February 1", x: 0.30, y: 0.88),
                        line("85", x: 0.52, y: 0.76),
                        line("100", x: 0.52, y: 0.71),
                        line("Score", x: 0.52, y: 0.67),
                        line("Good", x: 0.12, y: 0.64),
                        line("Quality", x: 0.12, y: 0.61),
                        line("7h 33m", x: 0.63, y: 0.64),
                        line("Duration", x: 0.63, y: 0.61),
                        line("Plenty of REM", x: 0.12, y: 0.50),
                    ],
                    "2026-02-01_timeline.jpeg": [
                        line("Sunday, February 1", x: 0.30, y: 0.88),
                        line("01:44", x: 0.08, y: 0.16),
                        line("09:28", x: 0.82, y: 0.16),
                    ],
                    "2026-02-01_metrics.jpeg": [
                        line("42m", x: 0.08, y: 0.73),
                        line("Deep", x: 0.08, y: 0.70),
                        line("4h 58m", x: 0.58, y: 0.73),
                        line("Light", x: 0.58, y: 0.70),
                        line("1h 53m", x: 0.08, y: 0.63),
                        line("REM", x: 0.08, y: 0.60),
                        line("11m", x: 0.58, y: 0.63),
                        line("Awake", x: 0.58, y: 0.60),
                        line("--", x: 0.08, y: 0.46),
                        line("Breathing Variations", x: 0.08, y: 0.43),
                        line("35", x: 0.58, y: 0.46),
                        line("Restless Moments", x: 0.58, y: 0.43),
                        line("49 bpm", x: 0.08, y: 0.36),
                        line("Resting Heart Rate", x: 0.08, y: 0.33),
                        line("+37", x: 0.58, y: 0.36),
                        line("Body Battery Change", x: 0.58, y: 0.33),
                        line("99 %", x: 0.08, y: 0.26),
                        line("Avg SpO2", x: 0.08, y: 0.23),
                        line("91 %", x: 0.58, y: 0.26),
                        line("Lowest SpO2", x: 0.58, y: 0.23),
                        line("15 brpm", x: 0.08, y: 0.16),
                        line("Avg Respiration", x: 0.08, y: 0.13),
                        line("11 brpm", x: 0.58, y: 0.16),
                        line("Lowest Respiration", x: 0.58, y: 0.13),
                        line("83 ms", x: 0.08, y: 0.06),
                        line("Avg Overnight HRV", x: 0.08, y: 0.03),
                        line("Balanced", x: 0.58, y: 0.06),
                        line("7d Avg HRV", x: 0.58, y: 0.03),
                        line("--", x: 0.08, y: -0.04),
                        line("Avg Skin Temp Change", x: 0.08, y: -0.07),
                    ],
                ]
            )
        )

        let fixtureDirectory = FixturePaths.garminPhotosDirectory
        let record = try parser.parseNight(
            summaryURL: fixtureDirectory.appending(path: "2026-02-01_summary.jpeg"),
            timelineURL: fixtureDirectory.appending(path: "2026-02-01_timeline.jpeg"),
            metricsURL: fixtureDirectory.appending(path: "2026-02-01_metrics.jpeg"),
            importedAt: ISO8601DateFormatter().date(from: "2026-02-02T08:30:00Z")!
        )

        #expect(record.averageSkinTemperatureChangeCelsius == nil)
    }

#if os(iOS)
    @Test
    func visionOCRRecognizesKeySummaryTextFromRealGarminScreenshot() throws {
        let recognizer = VisionOCRRecognizer()
        let summaryURL = FixturePaths.garminPhotosDirectory.appending(path: "2026-02-24_summary.jpeg")

        let lines = try recognizer.recognizeText(in: summaryURL)
        let recognizedText = lines
            .map(\.text)
            .joined(separator: "\n")

        #expect(recognizedText.contains("Tuesday, February 24"))
        #expect(recognizedText.contains("86"))
        #expect(recognizedText.contains("Good"))
        #expect(recognizedText.contains("8h 1m"))
    }
#endif
}

private struct StubOCRRecognizer: OCRRecognizing {
    let linesByFileName: [String: [RecognizedLine]]

    func recognizeText(in imageURL: URL) throws -> [RecognizedLine] {
        linesByFileName[imageURL.lastPathComponent, default: []]
    }
}

private enum FixturePaths {
    static let garminPhotosDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "photo_garmin")
}

private func line(_ text: String, x: CGFloat, y: CGFloat) -> RecognizedLine {
    RecognizedLine(
        text: text,
        boundingBox: CGRect(x: x, y: y, width: 0.1, height: 0.02)
    )
}
