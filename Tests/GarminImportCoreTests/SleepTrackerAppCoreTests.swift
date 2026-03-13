import Foundation
import Testing
@testable import GarminImportCore

struct SleepTrackerAppCoreTests {
    @Test
    func mergeImportedRecordPreservesHabitStateAndAddsExpandedMetrics() {
        let existing = DailyLogData(
            habits: ["screens"],
            habitValues: ["meditation_minutes": .number(10)],
            notes: "Felt calm"
        )
        let record = GarminSleepRecord(
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

        let merged = SleepTrackerAppCore.mergeImportedRecord(record, into: existing)

        #expect(merged.habits == ["screens"])
        #expect(merged.habitValues["meditation_minutes"] == .number(10))
        #expect(merged.notes == "Felt calm")
        #expect(merged.sleepScore == 86)
        #expect(merged.durationHours == 8)
        #expect(merged.durationMinutes == 1)
        #expect(merged.deepMinutes == 54)
        #expect(merged.bodyBattery == 48)
        #expect(merged.averageOvernightHRV == 84)
        #expect(merged.averageSkinTemperatureChangeCelsius == 0.3)
    }

    @Test
    func dashboardSnapshotRanksPositiveAndNegativeHabits() {
        let habits = [
            HabitDefinition(id: "read", label: "Read before bed"),
            HabitDefinition(id: "screens", label: "No late screens"),
        ]
        let logs = [
            "2026-02-01": DailyLogData(habits: ["read"], sleepScore: 88, durationHours: 8, durationMinutes: 0),
            "2026-02-02": DailyLogData(habits: ["read"], sleepScore: 86, durationHours: 7, durationMinutes: 45),
            "2026-02-03": DailyLogData(habits: ["read"], sleepScore: 87, durationHours: 7, durationMinutes: 50),
            "2026-02-04": DailyLogData(habits: ["screens"], sleepScore: 68, durationHours: 6, durationMinutes: 10),
            "2026-02-05": DailyLogData(habits: ["screens"], sleepScore: 70, durationHours: 6, durationMinutes: 20),
            "2026-02-06": DailyLogData(habits: ["screens"], sleepScore: 69, durationHours: 6, durationMinutes: 5),
            "2026-02-07": DailyLogData(habits: [], sleepScore: 76, durationHours: 7, durationMinutes: 0),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        #expect(snapshot.bestHabits.first?.id == "read")
        #expect(snapshot.worstHabits.first?.id == "screens")
        #expect(snapshot.trend.count == 7)
        #expect(snapshot.stats.first?.title == "Average Sleep Score")
    }

    @Test
    func historyAndDashboardIgnoreEmptyPlaceholderDays() {
        let habits = [
            HabitDefinition(id: "read", label: "Read before bed"),
        ]
        let logs = [
            "2026-03-11": DailyLogData(),
            "2026-03-12": DailyLogData(
                habits: ["read"],
                sleepScore: 84,
                durationHours: 7,
                durationMinutes: 45,
                importedAt: "2026-03-13T08:00:00Z"
            ),
        ]

        let history = SleepTrackerAppCore.historyItems(from: logs)
        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        #expect(history.count == 1)
        #expect(history.first?.date == "2026-03-12")
        #expect(snapshot.trend.count == 1)
        #expect(snapshot.stats[1].value == "84")
    }

    @Test
    func chartAxisDatesUseSparseReadableTicks() {
        let trend = [
            TrendPoint(date: "2026-03-01", value: 78),
            TrendPoint(date: "2026-03-02", value: 80),
            TrendPoint(date: "2026-03-03", value: 81),
            TrendPoint(date: "2026-03-04", value: 79),
            TrendPoint(date: "2026-03-05", value: 82),
            TrendPoint(date: "2026-03-06", value: 84),
            TrendPoint(date: "2026-03-07", value: 83),
        ]

        let axisDates = SleepTrackerAppCore.chartAxisDates(for: trend, maxLabels: 3)

        #expect(axisDates == ["2026-03-01", "2026-03-04", "2026-03-07"])
    }

    @Test
    func compactDateLabelFormatsIsoDatesForChartAxis() {
        let label = SleepTrackerAppCore.compactDateLabel(for: "2026-03-07")

        #expect(label == "03/07")
    }

    @Test
    func mergedLogsPreferPendingLocalChangesOverRemoteSnapshot() {
        let remoteLogs = [
            "2026-03-12": DailyLogData(notes: "remote", sleepScore: 81),
            "2026-03-11": DailyLogData(sleepScore: 77),
        ]
        let pendingLogs = [
            "2026-03-12": DailyLogData(notes: "pending", sleepScore: 86),
            "2026-03-13": DailyLogData(sleepScore: 88),
        ]

        let merged = SleepTrackerAppCore.mergedLogs(base: remoteLogs, overlay: pendingLogs)

        #expect(merged["2026-03-12"]?.sleepScore == 86)
        #expect(merged["2026-03-12"]?.notes == "pending")
        #expect(merged["2026-03-11"]?.sleepScore == 77)
        #expect(merged["2026-03-13"]?.sleepScore == 88)
    }

    @Test
    func resolvedHabitsPreferPendingLocalEditsWhenPresent() {
        let remoteHabits = [
            HabitDefinition(id: "read", label: "Read"),
        ]
        let pendingHabits = [
            HabitDefinition(id: "read", label: "Read"),
            HabitDefinition(id: "banana", label: "Banana before bed"),
        ]

        let resolved = SleepTrackerAppCore.resolvedHabits(base: remoteHabits, overlay: pendingHabits)

        #expect(resolved.map { $0.id } == ["read", "banana"])
    }

    @Test
    func dashboardSnapshotSeparatesOverallAndRecentImpactLeaders() {
        let habits = [
            HabitDefinition(id: "read", label: "Read a book"),
            HabitDefinition(id: "snack", label: "Evening snack", type: .select, options: ["Banana", "Nothing"]),
            HabitDefinition(id: "screens", label: "No screens 1h before bed"),
        ]
        let logs = [
            "2026-02-01": DailyLogData(habits: ["read"], sleepScore: 92, importedAt: "2026-02-02T08:00:00Z"),
            "2026-02-02": DailyLogData(habits: ["read"], sleepScore: 90, importedAt: "2026-02-03T08:00:00Z"),
            "2026-02-03": DailyLogData(habits: ["read"], sleepScore: 88, importedAt: "2026-02-04T08:00:00Z"),
            "2026-02-04": DailyLogData(habits: [], sleepScore: 70, importedAt: "2026-02-05T08:00:00Z"),
            "2026-02-05": DailyLogData(habits: [], sleepScore: 72, importedAt: "2026-02-06T08:00:00Z"),
            "2026-02-06": DailyLogData(
                habits: ["snack"],
                habitValues: ["snack": .string("Banana")],
                sleepScore: 84,
                importedAt: "2026-02-07T08:00:00Z"
            ),
            "2026-02-07": DailyLogData(
                habits: ["snack"],
                habitValues: ["snack": .string("Banana")],
                sleepScore: 85,
                importedAt: "2026-02-08T08:00:00Z"
            ),
            "2026-02-08": DailyLogData(
                habits: ["snack"],
                habitValues: ["snack": .string("Banana")],
                sleepScore: 86,
                importedAt: "2026-02-09T08:00:00Z"
            ),
            "2026-02-09": DailyLogData(habits: ["screens"], sleepScore: 65, importedAt: "2026-02-10T08:00:00Z"),
            "2026-02-10": DailyLogData(habits: ["screens"], sleepScore: 64, importedAt: "2026-02-11T08:00:00Z"),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        #expect(snapshot.overallImpact.topPositive?.habitID == "read")
        #expect(snapshot.recentImpact.topPositive?.id == "snack_banana")
        #expect(snapshot.recommendations.first?.habitID == "snack")
    }

    @Test
    func dashboardSnapshotCanRecommendAvoidingRecentNegativeHabit() {
        let habits = [
            HabitDefinition(id: "alcohol", label: "Alcohol"),
        ]
        let logs = [
            "2026-02-01": DailyLogData(habits: ["alcohol"], sleepScore: 60, importedAt: "2026-02-02T08:00:00Z"),
            "2026-02-02": DailyLogData(habits: [], sleepScore: 84, importedAt: "2026-02-03T08:00:00Z"),
            "2026-02-03": DailyLogData(habits: ["alcohol"], sleepScore: 62, importedAt: "2026-02-04T08:00:00Z"),
            "2026-02-04": DailyLogData(habits: [], sleepScore: 82, importedAt: "2026-02-05T08:00:00Z"),
            "2026-02-05": DailyLogData(habits: [], sleepScore: 80, importedAt: "2026-02-06T08:00:00Z"),
            "2026-02-06": DailyLogData(habits: ["alcohol"], sleepScore: 58, importedAt: "2026-02-07T08:00:00Z"),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        #expect(snapshot.recentImpact.topNegative?.habitID == "alcohol")
        #expect(snapshot.recommendations.contains { recommendation in
            recommendation.kind == .avoid && recommendation.habitID == "alcohol"
        })
    }

    @Test
    func dashboardSnapshotBuildsTieredRecommendationsAndSkipsStructuralHabits() {
        let habits = [
            HabitDefinition(id: "class_hours", label: "6h+ of classes"),
            HabitDefinition(id: "read", label: "Read a book"),
            HabitDefinition(id: "snack", label: "Evening snack", type: .select, options: ["Banana", "Nothing"]),
            HabitDefinition(id: "alcohol", label: "Alcohol"),
        ]
        let logs = [
            "2026-02-01": DailyLogData(habits: ["class_hours", "read"], sleepScore: 90, importedAt: "2026-02-02T08:00:00Z"),
            "2026-02-02": DailyLogData(habits: ["class_hours", "read"], sleepScore: 89, importedAt: "2026-02-03T08:00:00Z"),
            "2026-02-03": DailyLogData(habits: ["class_hours", "read"], sleepScore: 88, importedAt: "2026-02-04T08:00:00Z"),
            "2026-02-04": DailyLogData(habits: ["snack"], habitValues: ["snack": .string("Banana")], sleepScore: 86, importedAt: "2026-02-05T08:00:00Z"),
            "2026-02-05": DailyLogData(habits: ["snack"], habitValues: ["snack": .string("Banana")], sleepScore: 85, importedAt: "2026-02-06T08:00:00Z"),
            "2026-02-06": DailyLogData(habits: ["snack"], habitValues: ["snack": .string("Banana")], sleepScore: 84, importedAt: "2026-02-07T08:00:00Z"),
            "2026-02-07": DailyLogData(habits: ["alcohol"], sleepScore: 65, importedAt: "2026-02-08T08:00:00Z"),
            "2026-02-08": DailyLogData(habits: ["alcohol"], sleepScore: 64, importedAt: "2026-02-09T08:00:00Z"),
            "2026-02-09": DailyLogData(habits: ["read", "alcohol"], sleepScore: 63, importedAt: "2026-02-10T08:00:00Z"),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        #expect(snapshot.recommendations.contains { $0.kind == .reinforce && $0.habitID == "read" })
        #expect(snapshot.recommendations.contains { $0.kind == .avoid && $0.habitID == "alcohol" })
        #expect(snapshot.recommendations.contains { $0.kind == .test && $0.habitID == "snack" })
        #expect(snapshot.recommendations.contains { $0.habitID == "class_hours" } == false)
    }

    @Test
    func dashboardSnapshotBuildsSleepStatusAndSignalSummaries() {
        let habits = [
            HabitDefinition(id: "read", label: "Read a book"),
        ]
        let logs = [
            "2026-03-01": DailyLogData(habits: ["read"], sleepScore: 80, bedtime: "23:20", waketime: "07:10", durationHours: 7, durationMinutes: 50, deepHours: 0, deepMinutes: 52, remHours: 1, remMinutes: 24, awakeMinutes: 18, restlessMoments: 34, restingHeartRate: 55, bodyBatteryChange: 44, averageSpO2: 97, lowestSpO2: 92, averageOvernightHRV: 70, importedAt: "2026-03-02T08:00:00Z"),
            "2026-03-02": DailyLogData(habits: [], sleepScore: 81, bedtime: "23:25", waketime: "07:15", durationHours: 7, durationMinutes: 45, deepHours: 0, deepMinutes: 50, remHours: 1, remMinutes: 26, awakeMinutes: 16, restlessMoments: 32, restingHeartRate: 54, bodyBatteryChange: 45, averageSpO2: 97, lowestSpO2: 92, averageOvernightHRV: 71, importedAt: "2026-03-03T08:00:00Z"),
            "2026-03-03": DailyLogData(habits: ["read"], sleepScore: 82, bedtime: "23:15", waketime: "07:05", durationHours: 7, durationMinutes: 55, deepHours: 1, deepMinutes: 0, remHours: 1, remMinutes: 28, awakeMinutes: 14, restlessMoments: 30, restingHeartRate: 54, bodyBatteryChange: 46, averageSpO2: 98, lowestSpO2: 93, averageOvernightHRV: 72, importedAt: "2026-03-04T08:00:00Z"),
            "2026-03-04": DailyLogData(habits: [], sleepScore: 83, bedtime: "23:10", waketime: "07:00", durationHours: 8, durationMinutes: 0, deepHours: 1, deepMinutes: 2, remHours: 1, remMinutes: 30, awakeMinutes: 12, restlessMoments: 29, restingHeartRate: 53, bodyBatteryChange: 48, averageSpO2: 98, lowestSpO2: 93, averageOvernightHRV: 74, importedAt: "2026-03-05T08:00:00Z"),
            "2026-03-05": DailyLogData(habits: ["read"], sleepScore: 88, bedtime: "23:12", waketime: "07:04", durationHours: 8, durationMinutes: 2, deepHours: 1, deepMinutes: 5, remHours: 1, remMinutes: 35, awakeMinutes: 10, restlessMoments: 24, restingHeartRate: 50, bodyBatteryChange: 56, averageSpO2: 98, lowestSpO2: 94, averageOvernightHRV: 82, importedAt: "2026-03-06T08:00:00Z"),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        #expect(snapshot.sleepStatus.level == SleepStatusLevel.strong)
        #expect(snapshot.sleepStatus.evidence.count >= 3)
        #expect(snapshot.signalSummaries.map { $0.title } == ["Rhythm", "Recovery", "Breathing", "Stages"])
    }

    @Test
    func dashboardSnapshotTurnsNegatedAvoidRecommendationIntoPositiveAction() {
        let habits = [
            HabitDefinition(id: "no_sports", label: "No sports tonight"),
        ]
        let logs = [
            "2026-03-01": DailyLogData(habits: ["no_sports"], sleepScore: 60, importedAt: "2026-03-02T08:00:00Z"),
            "2026-03-02": DailyLogData(habits: [], sleepScore: 81, importedAt: "2026-03-03T08:00:00Z"),
            "2026-03-03": DailyLogData(habits: ["no_sports"], sleepScore: 61, importedAt: "2026-03-04T08:00:00Z"),
            "2026-03-04": DailyLogData(habits: [], sleepScore: 82, importedAt: "2026-03-05T08:00:00Z"),
            "2026-03-05": DailyLogData(habits: ["no_sports"], sleepScore: 59, importedAt: "2026-03-06T08:00:00Z"),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        let avoidRecommendation = snapshot.recommendations.first { $0.kind == .avoid }

        #expect(avoidRecommendation?.title == "Do sports tonight")
    }

    @Test
    func dashboardSnapshotBuildsTimingInsightsReliabilityAndExperimentPlan() {
        let habits = [
            HabitDefinition(id: "banana", label: "Banana before bed"),
            HabitDefinition(id: "alcohol", label: "Alcohol"),
        ]
        let logs = [
            "2026-03-01": DailyLogData(habits: ["banana"], sleepScore: 87, bedtime: "23:35", waketime: "07:32", durationHours: 7, durationMinutes: 55, importedAt: "2026-03-02T08:00:00Z"),
            "2026-03-02": DailyLogData(habits: ["banana"], sleepScore: 88, bedtime: "23:40", waketime: "07:34", durationHours: 8, durationMinutes: 0, importedAt: "2026-03-03T08:00:00Z"),
            "2026-03-03": DailyLogData(habits: ["banana"], sleepScore: 86, bedtime: "23:38", waketime: "07:30", durationHours: 7, durationMinutes: 48, importedAt: "2026-03-04T08:00:00Z"),
            "2026-03-04": DailyLogData(habits: [], sleepScore: 80, bedtime: "00:05", waketime: "07:45", durationHours: 7, durationMinutes: 20, importedAt: "2026-03-05T08:00:00Z"),
            "2026-03-05": DailyLogData(habits: ["banana"], sleepScore: 89, bedtime: "23:36", waketime: "07:28", durationHours: 8, durationMinutes: 4, importedAt: "2026-03-06T08:00:00Z"),
            "2026-03-06": DailyLogData(habits: [], sleepScore: 79, bedtime: "00:18", waketime: "07:55", durationHours: 7, durationMinutes: 10, importedAt: "2026-03-07T08:00:00Z"),
            "2026-03-07": DailyLogData(habits: ["alcohol"], sleepScore: 63, bedtime: "01:05", waketime: "08:55", durationHours: 6, durationMinutes: 5, importedAt: "2026-03-08T08:00:00Z"),
            "2026-03-08": DailyLogData(habits: ["banana"], sleepScore: 90, bedtime: "23:32", waketime: "07:26", durationHours: 8, durationMinutes: 6, importedAt: "2026-03-09T08:00:00Z"),
            "2026-03-09": DailyLogData(habits: ["alcohol"], sleepScore: 61, bedtime: "01:12", waketime: "09:05", durationHours: 5, durationMinutes: 58, importedAt: "2026-03-10T08:00:00Z"),
            "2026-03-10": DailyLogData(habits: ["alcohol"], sleepScore: 60, bedtime: "01:08", waketime: "08:58", durationHours: 6, durationMinutes: 2, importedAt: "2026-03-11T08:00:00Z"),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: habits,
            metric: .sleepScore
        )

        #expect(snapshot.analysisReliability.level == .medium)
        #expect(snapshot.experimentPlan != nil)
        #expect(snapshot.overallTimingImpact.leaderboard.contains { $0.habitID == "derived_sleep_duration" })
        #expect(snapshot.recentTimingImpact.leaderboard.contains { $0.habitID == "derived_bedtime_window" })
    }

    @Test
    func dashboardSnapshotUsesNaturalTitlesForDerivedTimingRecommendations() {
        let logs = [
            "2026-03-01": DailyLogData(sleepScore: 88, bedtime: "23:40", waketime: "07:30", durationHours: 7, durationMinutes: 50, importedAt: "2026-03-02T08:00:00Z"),
            "2026-03-02": DailyLogData(sleepScore: 87, bedtime: "23:45", waketime: "07:32", durationHours: 7, durationMinutes: 45, importedAt: "2026-03-03T08:00:00Z"),
            "2026-03-03": DailyLogData(sleepScore: 89, bedtime: "23:42", waketime: "07:35", durationHours: 7, durationMinutes: 55, importedAt: "2026-03-04T08:00:00Z"),
            "2026-03-04": DailyLogData(sleepScore: 64, bedtime: "01:10", waketime: "08:55", durationHours: 6, durationMinutes: 5, importedAt: "2026-03-05T08:00:00Z"),
            "2026-03-05": DailyLogData(sleepScore: 63, bedtime: "01:05", waketime: "08:58", durationHours: 6, durationMinutes: 10, importedAt: "2026-03-06T08:00:00Z"),
            "2026-03-06": DailyLogData(sleepScore: 62, bedtime: "01:08", waketime: "09:02", durationHours: 6, durationMinutes: 0, importedAt: "2026-03-07T08:00:00Z"),
        ]

        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: logs,
            habits: [],
            metric: .sleepScore
        )

        let avoidRecommendation = snapshot.recommendations.first { $0.kind == .avoid }

        #expect(avoidRecommendation?.title == "Avoid going to bed after 00:30 tonight")
    }
}
