import Foundation

public enum HabitType: String, Codable, CaseIterable, Sendable {
    case boolean
    case number
    case select
    case time
}

public struct HabitDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var type: HabitType
    public var options: [String]?
    public var sortOrder: Int?
    public var archivedAt: String?
    public var createdAt: String?

    public init(
        id: String,
        label: String,
        type: HabitType = .boolean,
        options: [String]? = nil,
        sortOrder: Int? = nil,
        archivedAt: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.options = options
        self.sortOrder = sortOrder
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case type
        case options
        case sortOrder = "sort_order"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        type = try container.decodeIfPresent(HabitType.self, forKey: .type) ?? .boolean
        options = try container.decodeIfPresent([String].self, forKey: .options)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
        archivedAt = try container.decodeIfPresent(String.self, forKey: .archivedAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

public enum HabitValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported habit value")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        case .boolean(let value):
            return value ? "true" : "false"
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            return Double(value)
        case .boolean(let value):
            return value ? 1 : 0
        }
    }
}

public struct DailyLogData: Codable, Equatable, Sendable {
    public var habits: [String]
    public var habitValues: [String: HabitValue]
    public var notes: String
    public var sleepScore: Int?
    public var sleepQuality: String?
    public var bedtime: String?
    public var waketime: String?
    public var durationHours: Int?
    public var durationMinutes: Int?
    public var deepHours: Int?
    public var deepMinutes: Int?
    public var lightHours: Int?
    public var lightMinutes: Int?
    public var remHours: Int?
    public var remMinutes: Int?
    public var awakeMinutes: Int?
    public var totalSleepMinutes: Int?
    public var summaryHeadline: String?
    public var breathingVariations: String?
    public var restlessMoments: Int?
    public var restingHeartRate: Int?
    public var bodyBattery: Int?
    public var bodyBatteryChange: Int?
    public var averageSpO2: Int?
    public var lowestSpO2: Int?
    public var averageRespiration: Double?
    public var lowestRespiration: Double?
    public var hrv: Int?
    public var averageOvernightHRV: Int?
    public var sevenDayHRVStatus: String?
    public var rhr: Int?
    public var averageSkinTemperatureChangeCelsius: Double?
    public var importedAt: String?

    public init(
        habits: [String] = [],
        habitValues: [String: HabitValue] = [:],
        notes: String = "",
        sleepScore: Int? = nil,
        sleepQuality: String? = nil,
        bedtime: String? = nil,
        waketime: String? = nil,
        durationHours: Int? = nil,
        durationMinutes: Int? = nil,
        deepHours: Int? = nil,
        deepMinutes: Int? = nil,
        lightHours: Int? = nil,
        lightMinutes: Int? = nil,
        remHours: Int? = nil,
        remMinutes: Int? = nil,
        awakeMinutes: Int? = nil,
        totalSleepMinutes: Int? = nil,
        summaryHeadline: String? = nil,
        breathingVariations: String? = nil,
        restlessMoments: Int? = nil,
        restingHeartRate: Int? = nil,
        bodyBattery: Int? = nil,
        bodyBatteryChange: Int? = nil,
        averageSpO2: Int? = nil,
        lowestSpO2: Int? = nil,
        averageRespiration: Double? = nil,
        lowestRespiration: Double? = nil,
        hrv: Int? = nil,
        averageOvernightHRV: Int? = nil,
        sevenDayHRVStatus: String? = nil,
        rhr: Int? = nil,
        averageSkinTemperatureChangeCelsius: Double? = nil,
        importedAt: String? = nil
    ) {
        self.habits = habits
        self.habitValues = habitValues
        self.notes = notes
        self.sleepScore = sleepScore
        self.sleepQuality = sleepQuality
        self.bedtime = bedtime
        self.waketime = waketime
        self.durationHours = durationHours
        self.durationMinutes = durationMinutes
        self.deepHours = deepHours
        self.deepMinutes = deepMinutes
        self.lightHours = lightHours
        self.lightMinutes = lightMinutes
        self.remHours = remHours
        self.remMinutes = remMinutes
        self.awakeMinutes = awakeMinutes
        self.totalSleepMinutes = totalSleepMinutes
        self.summaryHeadline = summaryHeadline
        self.breathingVariations = breathingVariations
        self.restlessMoments = restlessMoments
        self.restingHeartRate = restingHeartRate
        self.bodyBattery = bodyBattery
        self.bodyBatteryChange = bodyBatteryChange
        self.averageSpO2 = averageSpO2
        self.lowestSpO2 = lowestSpO2
        self.averageRespiration = averageRespiration
        self.lowestRespiration = lowestRespiration
        self.hrv = hrv
        self.averageOvernightHRV = averageOvernightHRV
        self.sevenDayHRVStatus = sevenDayHRVStatus
        self.rhr = rhr
        self.averageSkinTemperatureChangeCelsius = averageSkinTemperatureChangeCelsius
        self.importedAt = importedAt
    }

    public var totalDurationHours: Double? {
        if let totalSleepMinutes {
            return Double(totalSleepMinutes) / 60
        }

        guard let durationHours, let durationMinutes else {
            return nil
        }

        return Double(durationHours) + (Double(durationMinutes) / 60)
    }

    public var deepSleepHours: Double? {
        if let deepHours, let deepMinutes {
            return Double(deepHours) + (Double(deepMinutes) / 60)
        }

        return nil
    }

    public var hasImportedSleepData: Bool {
        importedAt != nil ||
        sleepScore != nil ||
        totalSleepMinutes != nil ||
        bedtime != nil ||
        waketime != nil
    }
}

public enum DashboardMetric: String, CaseIterable, Sendable {
    case sleepScore
    case duration
    case deepSleep
    case bodyBattery
    case hrv
    case rhr

    public var title: String {
        switch self {
        case .sleepScore: return "Sleep Score"
        case .duration: return "Duration"
        case .deepSleep: return "Deep Sleep"
        case .bodyBattery: return "Body Battery"
        case .hrv: return "HRV"
        case .rhr: return "Resting HR"
        }
    }

    public var unit: String {
        switch self {
        case .sleepScore, .bodyBattery: return ""
        case .duration, .deepSleep: return "h"
        case .hrv: return "ms"
        case .rhr: return "bpm"
        }
    }

    public var isInverse: Bool {
        self == .rhr
    }
}

public struct DashboardStat: Equatable, Sendable {
    public var title: String
    public var value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

public struct TrendPoint: Equatable, Identifiable, Sendable {
    public var id: String { date }
    public var date: String
    public var value: Double

    public init(date: String, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct HabitImpact: Equatable, Identifiable, Sendable {
    public var id: String
    public var habitID: String
    public var label: String
    public var impact: Double
    public var sampleCount: Int
    public var comparisonCount: Int
    public var isSignificant: Bool
    public var optionValue: String?
    public var detail: String?

    public init(
        id: String,
        habitID: String,
        label: String,
        impact: Double,
        sampleCount: Int,
        comparisonCount: Int,
        isSignificant: Bool,
        optionValue: String? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.habitID = habitID
        self.label = label
        self.impact = impact
        self.sampleCount = sampleCount
        self.comparisonCount = comparisonCount
        self.isSignificant = isSignificant
        self.optionValue = optionValue
        self.detail = detail
    }
}

public struct ImpactSummary: Equatable, Sendable {
    public var leaderboard: [HabitImpact]
    public var topPositive: HabitImpact?
    public var topNegative: HabitImpact?

    public init(
        leaderboard: [HabitImpact],
        topPositive: HabitImpact?,
        topNegative: HabitImpact?
    ) {
        self.leaderboard = leaderboard
        self.topPositive = topPositive
        self.topNegative = topNegative
    }
}

public enum RecommendationKind: String, Equatable, Sendable {
    case reinforce
    case avoid
    case test
}

public struct DashboardRecommendation: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var kind: RecommendationKind
    public var habitID: String
    public var optionValue: String?

    public init(
        id: String,
        title: String,
        detail: String,
        kind: RecommendationKind,
        habitID: String,
        optionValue: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.habitID = habitID
        self.optionValue = optionValue
    }
}

public enum SleepStatusLevel: String, Equatable, Sendable {
    case strong
    case steady
    case watch
    case lowData
}

public enum SignalTone: String, Equatable, Sendable {
    case positive
    case neutral
    case caution
}

public struct SleepStatus: Equatable, Sendable {
    public var level: SleepStatusLevel
    public var title: String
    public var summary: String
    public var focusTitle: String
    public var focusDetail: String
    public var evidence: [String]

    public init(
        level: SleepStatusLevel,
        title: String,
        summary: String,
        focusTitle: String,
        focusDetail: String,
        evidence: [String]
    ) {
        self.level = level
        self.title = title
        self.summary = summary
        self.focusTitle = focusTitle
        self.focusDetail = focusDetail
        self.evidence = evidence
    }
}

public struct SignalSummary: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var value: String
    public var detail: String
    public var tone: SignalTone

    public init(
        id: String,
        title: String,
        value: String,
        detail: String,
        tone: SignalTone
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
        self.tone = tone
    }
}

public enum AnalysisReliabilityLevel: String, Equatable, Sendable {
    case low
    case medium
    case high
}

public struct AnalysisReliability: Equatable, Sendable {
    public var level: AnalysisReliabilityLevel
    public var title: String
    public var summary: String
    public var evidence: [String]

    public init(
        level: AnalysisReliabilityLevel,
        title: String,
        summary: String,
        evidence: [String]
    ) {
        self.level = level
        self.title = title
        self.summary = summary
        self.evidence = evidence
    }
}

public struct ExperimentPlan: Equatable, Sendable {
    public var title: String
    public var summary: String
    public var durationDays: Int
    public var successMetric: String
    public var confidenceNote: String

    public init(
        title: String,
        summary: String,
        durationDays: Int,
        successMetric: String,
        confidenceNote: String
    ) {
        self.title = title
        self.summary = summary
        self.durationDays = durationDays
        self.successMetric = successMetric
        self.confidenceNote = confidenceNote
    }
}

public struct DashboardSnapshot: Equatable, Sendable {
    public var stats: [DashboardStat]
    public var trend: [TrendPoint]
    public var bestHabits: [HabitImpact]
    public var worstHabits: [HabitImpact]
    public var overallImpact: ImpactSummary
    public var recentImpact: ImpactSummary
    public var overallTimingImpact: ImpactSummary
    public var recentTimingImpact: ImpactSummary
    public var recommendations: [DashboardRecommendation]
    public var sleepStatus: SleepStatus
    public var signalSummaries: [SignalSummary]
    public var analysisReliability: AnalysisReliability
    public var experimentPlan: ExperimentPlan?

    public init(
        stats: [DashboardStat],
        trend: [TrendPoint],
        bestHabits: [HabitImpact],
        worstHabits: [HabitImpact],
        overallImpact: ImpactSummary,
        recentImpact: ImpactSummary,
        overallTimingImpact: ImpactSummary,
        recentTimingImpact: ImpactSummary,
        recommendations: [DashboardRecommendation],
        sleepStatus: SleepStatus,
        signalSummaries: [SignalSummary],
        analysisReliability: AnalysisReliability,
        experimentPlan: ExperimentPlan?
    ) {
        self.stats = stats
        self.trend = trend
        self.bestHabits = bestHabits
        self.worstHabits = worstHabits
        self.overallImpact = overallImpact
        self.recentImpact = recentImpact
        self.overallTimingImpact = overallTimingImpact
        self.recentTimingImpact = recentTimingImpact
        self.recommendations = recommendations
        self.sleepStatus = sleepStatus
        self.signalSummaries = signalSummaries
        self.analysisReliability = analysisReliability
        self.experimentPlan = experimentPlan
    }
}

public struct SleepHistoryItem: Equatable, Identifiable, Sendable {
    public var id: String { date }
    public var date: String
    public var title: String
    public var score: Int?
    public var durationHours: Double?

    public init(date: String, title: String, score: Int?, durationHours: Double?) {
        self.date = date
        self.title = title
        self.score = score
        self.durationHours = durationHours
    }
}

public enum SleepTrackerAppCore {
    public static func mergeImportedRecord(
        _ record: GarminSleepRecord,
        into existing: DailyLogData?
    ) -> DailyLogData {
        var merged = existing ?? DailyLogData()
        merged.sleepScore = record.sleepScore
        merged.sleepQuality = record.sleepQuality
        merged.bedtime = record.bedtime
        merged.waketime = record.wakeTime
        merged.durationHours = record.totalSleepMinutes / 60
        merged.durationMinutes = record.totalSleepMinutes % 60
        merged.deepHours = record.deepSleepMinutes / 60
        merged.deepMinutes = record.deepSleepMinutes % 60
        merged.lightHours = record.lightSleepMinutes / 60
        merged.lightMinutes = record.lightSleepMinutes % 60
        merged.remHours = record.remSleepMinutes / 60
        merged.remMinutes = record.remSleepMinutes % 60
        merged.awakeMinutes = record.awakeMinutes
        merged.totalSleepMinutes = record.totalSleepMinutes
        merged.summaryHeadline = record.summaryHeadline
        merged.breathingVariations = record.breathingVariations
        merged.restlessMoments = record.restlessMoments
        merged.restingHeartRate = record.restingHeartRate
        merged.bodyBattery = record.bodyBatteryChange
        merged.bodyBatteryChange = record.bodyBatteryChange
        merged.averageSpO2 = record.averageSpO2
        merged.lowestSpO2 = record.lowestSpO2
        merged.averageRespiration = record.averageRespiration
        merged.lowestRespiration = record.lowestRespiration
        merged.hrv = record.averageOvernightHRV
        merged.averageOvernightHRV = record.averageOvernightHRV
        merged.sevenDayHRVStatus = record.sevenDayHRVStatus
        merged.rhr = record.restingHeartRate
        merged.averageSkinTemperatureChangeCelsius = record.averageSkinTemperatureChangeCelsius
        merged.importedAt = ISO8601DateFormatter().string(from: Date())
        return merged
    }

    public static func dashboardSnapshot(
        logs: [String: DailyLogData],
        habits: [HabitDefinition],
        metric: DashboardMetric
    ) -> DashboardSnapshot {
        let sortedLogs = logs
            .map { (date: $0.key, entry: $0.value) }
            .filter { $0.entry.hasImportedSleepData }
            .sorted { $0.date < $1.date }

        let values = sortedLogs.compactMap { metricValue(for: $0.entry, metric: metric) }
        let averageValue = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let recentScore = sortedLogs.suffix(7)
            .compactMap { $0.entry.sleepScore }
        let recentAverageScore = recentScore.isEmpty ? nil : Double(recentScore.reduce(0, +)) / Double(recentScore.count)

        let trend = sortedLogs.compactMap { item -> TrendPoint? in
            guard let value = metricValue(for: item.entry, metric: metric) else {
                return nil
            }

            return TrendPoint(date: item.date, value: value)
        }

        let analysisBundle = analysisBundle(from: sortedLogs)
        let lastEntry = analysisBundle.logs.last?.entry ?? sortedLogs.last?.entry
        let overallImpact = impactSummary(
            logs: sortedLogs,
            habits: habits,
            metric: metric
        )
        let recentImpact = impactSummary(
            logs: Array(sortedLogs.suffix(7)),
            habits: habits,
            metric: metric
        )
        let overallTimingImpact = impactSummary(
            logs: analysisBundle.logs,
            habits: analysisBundle.habits,
            metric: metric
        )
        let recentTimingImpact = impactSummary(
            logs: Array(analysisBundle.logs.suffix(7)),
            habits: analysisBundle.habits,
            metric: metric
        )
        let bestHabits = overallImpact.leaderboard
            .filter { $0.isSignificant && $0.impact > 0 }
            .prefix(3)
        let worstHabits = overallImpact.leaderboard
            .filter { $0.isSignificant && $0.impact < 0 }
            .prefix(3)
        let recommendations = dashboardRecommendations(
            overallImpact: overallImpact,
            recentImpact: recentImpact,
            overallTimingImpact: overallTimingImpact,
            recentTimingImpact: recentTimingImpact,
            latestEntry: analysisBundle.logs.last?.entry,
            habits: habits + analysisBundle.habits,
            metric: metric
        )
        let sleepStatus = sleepStatus(
            logs: sortedLogs,
            recommendations: recommendations
        )
        let signalSummaries = signalSummaries(logs: sortedLogs)
        let analysisReliability = analysisReliability(
            logs: sortedLogs,
            habits: habits,
            overallImpact: overallImpact,
            recentImpact: recentImpact,
            overallTimingImpact: overallTimingImpact,
            recentTimingImpact: recentTimingImpact
        )
        let experimentPlan = experimentPlan(
            recommendations: recommendations,
            reliability: analysisReliability,
            metric: metric
        )

        return DashboardSnapshot(
            stats: [
                DashboardStat(title: "Average \(metric.title)", value: formattedMetricValue(averageValue, metric: metric)),
                DashboardStat(title: "Last Score", value: lastEntry?.sleepScore.map(String.init) ?? "--"),
                DashboardStat(
                    title: "7-Day Score",
                    value: recentAverageScore.map { String(Int($0.rounded())) } ?? "--"
                ),
            ],
            trend: trend,
            bestHabits: Array(bestHabits),
            worstHabits: Array(worstHabits),
            overallImpact: overallImpact,
            recentImpact: recentImpact,
            overallTimingImpact: overallTimingImpact,
            recentTimingImpact: recentTimingImpact,
            recommendations: recommendations,
            sleepStatus: sleepStatus,
            signalSummaries: signalSummaries,
            analysisReliability: analysisReliability,
            experimentPlan: experimentPlan
        )
    }

    public static func historyItems(from logs: [String: DailyLogData]) -> [SleepHistoryItem] {
        logs
            .map { date, entry in
                SleepHistoryItem(
                    date: date,
                    title: entry.summaryHeadline ?? entry.sleepQuality ?? "Imported night",
                    score: entry.sleepScore,
                    durationHours: entry.totalDurationHours
                )
            }
            .filter { item in
                logs[item.date]?.hasImportedSleepData == true
            }
            .sorted { $0.date > $1.date }
    }

    public static func metricValue(for entry: DailyLogData, metric: DashboardMetric) -> Double? {
        switch metric {
        case .sleepScore:
            return entry.sleepScore.map(Double.init)
        case .duration:
            return entry.totalDurationHours
        case .deepSleep:
            return entry.deepSleepHours
        case .bodyBattery:
            return entry.bodyBattery.map(Double.init) ?? entry.bodyBatteryChange.map(Double.init)
        case .hrv:
            return entry.averageOvernightHRV.map(Double.init) ?? entry.hrv.map(Double.init)
        case .rhr:
            return entry.restingHeartRate.map(Double.init) ?? entry.rhr.map(Double.init)
        }
    }

    public static func formattedMetricValue(_ value: Double, metric: DashboardMetric) -> String {
        if metric.unit == "h" {
            return String(format: "%.1f%@", value, metric.unit)
        }

        if value.rounded() == value {
            return "\(Int(value))\(metric.unit)"
        }

        return String(format: "%.1f%@", value, metric.unit)
    }

    public static func chartAxisDates(for trend: [TrendPoint], maxLabels: Int = 3) -> [String] {
        let dates = trend.map(\.date)

        guard maxLabels > 0, dates.count > maxLabels else {
            return dates
        }

        guard maxLabels > 1 else {
            return dates.last.map { [$0] } ?? []
        }

        let lastIndex = dates.count - 1
        let step = Double(lastIndex) / Double(maxLabels - 1)
        var selectedIndexes = Set([0, lastIndex])

        if maxLabels > 2 {
            for position in 1 ..< (maxLabels - 1) {
                let rawIndex = Int((Double(position) * step).rounded())
                selectedIndexes.insert(min(max(rawIndex, 0), lastIndex))
            }
        }

        return selectedIndexes
            .sorted()
            .map { dates[$0] }
    }

    public static func compactDateLabel(for isoDate: String) -> String {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3 else {
            return isoDate
        }

        return "\(parts[1])/\(parts[2])"
    }

    public static func habitCheckInDate(forSleepDate sleepDate: String) -> String {
        guard let parsedDate = isoDayDate(from: sleepDate),
              let previousDate = isoCalendar.date(byAdding: .day, value: -1, to: parsedDate)
        else {
            return sleepDate
        }

        return isoDayString(from: previousDate)
    }

    public static func mergedLogs(
        base: [String: DailyLogData],
        overlay: [String: DailyLogData]
    ) -> [String: DailyLogData] {
        var merged = base
        for (date, entry) in overlay {
            merged[date] = entry
        }
        return merged
    }

    public static func resolvedHabits(
        base: [HabitDefinition],
        overlay: [HabitDefinition]?
    ) -> [HabitDefinition] {
        overlay ?? base
    }

    private struct AnalysisBundle {
        var logs: [(date: String, entry: DailyLogData)]
        var habits: [HabitDefinition]
    }

    private static func analysisBundle(
        from logs: [(date: String, entry: DailyLogData)]
    ) -> AnalysisBundle {
        AnalysisBundle(
            logs: logs.enumerated().map { index, item in
                var entry = item.entry

                applyDerivedSelectHabit(
                    id: "derived_sleep_duration",
                    value: sleepDurationBand(for: entry),
                    to: &entry
                )
                applyDerivedSelectHabit(
                    id: "derived_bedtime_window",
                    value: bedtimeWindow(for: entry.bedtime),
                    to: &entry
                )
                applyDerivedSelectHabit(
                    id: "derived_wake_window",
                    value: wakeWindow(for: entry.waketime),
                    to: &entry
                )
                applyDerivedSelectHabit(
                    id: "derived_bedtime_rhythm",
                    value: rhythmBand(
                        current: entry.bedtime,
                        previousLogs: Array(logs.prefix(index)),
                        value: \.bedtime,
                        parser: bedtimeMinutes(for:)
                    ),
                    to: &entry
                )
                applyDerivedSelectHabit(
                    id: "derived_wake_rhythm",
                    value: rhythmBand(
                        current: entry.waketime,
                        previousLogs: Array(logs.prefix(index)),
                        value: \.waketime,
                        parser: clockMinutes(for:)
                    ),
                    to: &entry
                )

                return (date: item.date, entry: entry)
            },
            habits: derivedTimingHabits
        )
    }

    private static func applyDerivedSelectHabit(
        id: String,
        value: String?,
        to entry: inout DailyLogData
    ) {
        guard let value else {
            return
        }

        entry.habitValues[id] = .string(value)
        if !entry.habits.contains(id) {
            entry.habits.append(id)
        }
    }

    private static func sleepDurationBand(for entry: DailyLogData) -> String? {
        guard let duration = entry.totalDurationHours else {
            return nil
        }

        switch duration {
        case ..<7:
            return "Under 7h"
        case ..<8:
            return "7h to 8h"
        case ...9:
            return "8h to 9h"
        default:
            return "Over 9h"
        }
    }

    private static func bedtimeWindow(for bedtime: String?) -> String? {
        guard let minutes = bedtimeMinutes(for: bedtime) else {
            return nil
        }

        switch minutes {
        case ..<1410:
            return "Before 23:30"
        case ...1470:
            return "23:30 to 00:30"
        default:
            return "After 00:30"
        }
    }

    private static func wakeWindow(for waketime: String?) -> String? {
        guard let minutes = clockMinutes(for: waketime) else {
            return nil
        }

        switch minutes {
        case ..<450:
            return "Before 07:30"
        case ...510:
            return "07:30 to 08:30"
        default:
            return "After 08:30"
        }
    }

    private static func rhythmBand(
        current: String?,
        previousLogs: [(date: String, entry: DailyLogData)],
        value: KeyPath<DailyLogData, String?>,
        parser: (String?) -> Double?
    ) -> String? {
        guard let currentMinutes = parser(current) else {
            return nil
        }

        let values = previousLogs
            .suffix(6)
            .compactMap { parser($0.entry[keyPath: value]) }
        guard values.count >= 3 else {
            return nil
        }

        let mean = values.reduce(0, +) / Double(values.count)
        return abs(currentMinutes - mean) <= 45 ? "Consistent" : "Irregular"
    }

    private static func impactSummary(
        logs: [(date: String, entry: DailyLogData)],
        habits: [HabitDefinition],
        metric: DashboardMetric
    ) -> ImpactSummary {
        let impactRows = habits
            .filter { $0.archivedAt == nil }
            .reduce(into: [HabitImpact]()) { partialResult, habit in
                partialResult.append(contentsOf: impacts(for: habit, logs: logs, metric: metric))
            }
            .sorted { lhs, rhs in
                if lhs.isSignificant != rhs.isSignificant {
                    return lhs.isSignificant && !rhs.isSignificant
                }

                return abs(lhs.impact) > abs(rhs.impact)
            }

        let significant = impactRows.filter { $0.isSignificant }
        return ImpactSummary(
            leaderboard: impactRows,
            topPositive: significant.first(where: { $0.impact > 0 }),
            topNegative: significant.first(where: { $0.impact < 0 })
        )
    }

    private static func impacts(
        for habit: HabitDefinition,
        logs: [(date: String, entry: DailyLogData)],
        metric: DashboardMetric
    ) -> [HabitImpact] {
        if habit.type == .time {
            return timeImpacts(for: habit, logs: logs, metric: metric)
        }

        if habit.type == .select, let options = habit.options, !options.isEmpty {
            return options.compactMap { option in
                selectOptionImpact(
                    for: habit,
                    option: option,
                    logs: logs,
                    metric: metric
                )
            }
        }

        guard let impact = booleanStyleImpact(for: habit, logs: logs, metric: metric) else {
            return []
        }

        return [impact]
    }

    private static func timeImpacts(
        for habit: HabitDefinition,
        logs: [(date: String, entry: DailyLogData)],
        metric: DashboardMetric
    ) -> [HabitImpact] {
        let options: [String]
        let classifier: (DailyLogData) -> String?

        if isMealTimeHabit(habit) {
            options = mealTimingOptions
            classifier = { mealTimingOption(for: $0, habitID: habit.id) }
        } else {
            guard let windowOptions = absoluteTimeWindowOptions(for: habit, logs: logs) else {
                return []
            }
            options = windowOptions
            classifier = { absoluteTimeWindowOption(for: $0.habitValues[habit.id]?.stringValue, options: windowOptions) }
        }

        return options.compactMap { option in
            timeOptionImpact(
                for: habit,
                option: option,
                logs: logs,
                metric: metric,
                classifier: classifier
            )
        }
    }

    private static func booleanStyleImpact(
        for habit: HabitDefinition,
        logs: [(date: String, entry: DailyLogData)],
        metric: DashboardMetric
    ) -> HabitImpact? {
        let withHabit = logs.compactMap { item -> Double? in
            guard item.entry.habits.contains(habit.id),
                  let value = metricValue(for: item.entry, metric: metric)
            else {
                return nil
            }
            return value
        }

        let withoutHabit = logs.compactMap { item -> Double? in
            guard !item.entry.habits.contains(habit.id),
                  let value = metricValue(for: item.entry, metric: metric)
            else {
                return nil
            }
            return value
        }

        guard !withHabit.isEmpty || !withoutHabit.isEmpty else {
            return nil
        }

        let withAverage = withHabit.isEmpty ? 0 : withHabit.reduce(0, +) / Double(withHabit.count)
        let withoutAverage = withoutHabit.isEmpty ? 0 : withoutHabit.reduce(0, +) / Double(withoutHabit.count)
        let rawImpact = (withHabit.isEmpty || withoutHabit.isEmpty) ? 0 : (withAverage - withoutAverage)
        let normalizedImpact = normalizeImpact(rawImpact, metric: metric)
        let isSignificant = withHabit.count >= 3 && !withoutHabit.isEmpty

        return HabitImpact(
            id: habit.id,
            habitID: habit.id,
            label: habit.label,
            impact: normalizedImpact,
            sampleCount: withHabit.count,
            comparisonCount: withoutHabit.count,
            isSignificant: isSignificant
        )
    }

    private static func selectOptionImpact(
        for habit: HabitDefinition,
        option: String,
        logs: [(date: String, entry: DailyLogData)],
        metric: DashboardMetric
    ) -> HabitImpact? {
        let withOption = logs.compactMap { item -> Double? in
            guard item.entry.habitValues[habit.id]?.stringValue == option,
                  let value = metricValue(for: item.entry, metric: metric)
            else {
                return nil
            }

            return value
        }
        let withoutOption = logs.compactMap { item -> Double? in
            guard item.entry.habitValues[habit.id]?.stringValue != option,
                  let value = metricValue(for: item.entry, metric: metric)
            else {
                return nil
            }

            return value
        }

        guard !withOption.isEmpty || !withoutOption.isEmpty else {
            return nil
        }

        let withAverage = withOption.isEmpty ? 0 : withOption.reduce(0, +) / Double(withOption.count)
        let withoutAverage = withoutOption.isEmpty ? 0 : withoutOption.reduce(0, +) / Double(withoutOption.count)
        let rawImpact = (withOption.isEmpty || withoutOption.isEmpty) ? 0 : (withAverage - withoutAverage)
        let normalizedImpact = normalizeImpact(rawImpact, metric: metric)
        let normalizedOptionID = option
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let isSignificant = withOption.count >= 3 && !withoutOption.isEmpty

        return HabitImpact(
            id: "\(habit.id)_\(normalizedOptionID)",
            habitID: habit.id,
            label: "\(habit.label): \(option)",
            impact: normalizedImpact,
            sampleCount: withOption.count,
            comparisonCount: withoutOption.count,
            isSignificant: isSignificant,
            optionValue: option
        )
    }

    private static func timeOptionImpact(
        for habit: HabitDefinition,
        option: String,
        logs: [(date: String, entry: DailyLogData)],
        metric: DashboardMetric,
        classifier: (DailyLogData) -> String?
    ) -> HabitImpact? {
        let withOption = logs.compactMap { item -> Double? in
            guard classifier(item.entry) == option,
                  let value = metricValue(for: item.entry, metric: metric)
            else {
                return nil
            }

            return value
        }
        let withoutOption = logs.compactMap { item -> Double? in
            guard let classified = classifier(item.entry),
                  classified != option,
                  let value = metricValue(for: item.entry, metric: metric)
            else {
                return nil
            }

            return value
        }

        guard !withOption.isEmpty || !withoutOption.isEmpty else {
            return nil
        }

        let withAverage = withOption.isEmpty ? 0 : withOption.reduce(0, +) / Double(withOption.count)
        let withoutAverage = withoutOption.isEmpty ? 0 : withoutOption.reduce(0, +) / Double(withoutOption.count)
        let rawImpact = (withOption.isEmpty || withoutOption.isEmpty) ? 0 : (withAverage - withoutAverage)
        let normalizedImpact = normalizeImpact(rawImpact, metric: metric)
        let normalizedOptionID = option
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let isSignificant = withOption.count >= 3 && !withoutOption.isEmpty

        return HabitImpact(
            id: "\(habit.id)_\(normalizedOptionID)",
            habitID: habit.id,
            label: "\(habit.label): \(option)",
            impact: normalizedImpact,
            sampleCount: withOption.count,
            comparisonCount: withoutOption.count,
            isSignificant: isSignificant,
            optionValue: option
        )
    }

    private static func dashboardRecommendations(
        overallImpact: ImpactSummary,
        recentImpact: ImpactSummary,
        overallTimingImpact: ImpactSummary,
        recentTimingImpact: ImpactSummary,
        latestEntry: DailyLogData?,
        habits: [HabitDefinition],
        metric: DashboardMetric
    ) -> [DashboardRecommendation] {
        var recommendations: [DashboardRecommendation] = []

        let habitLookup = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        let positiveHabitCandidates = uniqueImpacts(
            recentImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact > 0 &&
                isPositiveRecommendationImpact($0, habitLookup: habitLookup)
            } +
            overallImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact > 0 &&
                isPositiveRecommendationImpact($0, habitLookup: habitLookup)
            }
        )
        let negativeHabitCandidates = uniqueImpacts(
            recentImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact < 0 &&
                isNegativeRecommendationImpact($0, habitLookup: habitLookup)
            } +
            overallImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact < 0 &&
                isNegativeRecommendationImpact($0, habitLookup: habitLookup)
            }
        )
        let positiveTimingCandidates = prioritizeTimingImpacts(uniqueImpacts(
            recentTimingImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact > 0 &&
                isPositiveRecommendationImpact($0, habitLookup: habitLookup)
            } +
            overallTimingImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact > 0 &&
                isPositiveRecommendationImpact($0, habitLookup: habitLookup)
            }
        ))
        let negativeTimingCandidates = prioritizeTimingImpacts(uniqueImpacts(
            recentTimingImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact < 0 &&
                isNegativeRecommendationImpact($0, habitLookup: habitLookup)
            } +
            overallTimingImpact.leaderboard.filter {
                $0.isSignificant &&
                $0.impact < 0 &&
                isNegativeRecommendationImpact($0, habitLookup: habitLookup)
            }
        ))
        let positiveCandidates = prioritizeRecommendationCandidates(positiveHabitCandidates + positiveTimingCandidates)
        let negativeCandidates = prioritizeRecommendationCandidates(negativeHabitCandidates + negativeTimingCandidates)

        if let latestEntry,
           let continueImpact = positiveCandidates.first(where: { isImpactActive($0, in: latestEntry, habitLookup: habitLookup) }) {
            recommendations.append(
                DashboardRecommendation(
                    id: "continue-\(continueImpact.id)",
                    title: recommendationTitle(for: continueImpact, kind: .reinforce),
                    detail: "\(continueImpact.label) is still helping by about +\(formattedImpact(continueImpact.impact, metric: metric)) across \(continueImpact.sampleCount) tracked nights.",
                    kind: .reinforce,
                    habitID: continueImpact.habitID,
                    optionValue: continueImpact.optionValue
                )
            )
        }

        if let latestEntry,
           let stopImpact = negativeCandidates.first(where: { isImpactActive($0, in: latestEntry, habitLookup: habitLookup) }) {
            recommendations.append(
                DashboardRecommendation(
                    id: "stop-\(stopImpact.id)",
                    title: recommendationTitle(for: stopImpact, kind: .avoid),
                    detail: "\(stopImpact.label) is costing about \(formattedImpact(abs(stopImpact.impact), metric: metric)) when it shows up, so it is the clearest thing to cut tonight.",
                    kind: .avoid,
                    habitID: stopImpact.habitID,
                    optionValue: stopImpact.optionValue
                )
            )
        }

        let activeRecommendationIDs = Set(recommendations.map(\.id))
        if let latestEntry,
           let tryImpact = positiveCandidates.first(where: {
               !isImpactActive($0, in: latestEntry, habitLookup: habitLookup) &&
               !activeRecommendationIDs.contains("continue-\($0.id)")
           }) {
            recommendations.append(
                DashboardRecommendation(
                    id: "try-\(tryImpact.id)",
                    title: recommendationTitle(for: tryImpact, kind: .test),
                    detail: "\(tryImpact.label) has been worth about +\(formattedImpact(tryImpact.impact, metric: metric)) and looks realistic enough to test tonight.",
                    kind: .test,
                    habitID: tryImpact.habitID,
                    optionValue: tryImpact.optionValue
                )
            )
        } else if latestEntry == nil,
                  let tryImpact = positiveCandidates.first {
            recommendations.append(
                DashboardRecommendation(
                    id: "try-\(tryImpact.id)",
                    title: recommendationTitle(for: tryImpact, kind: .test),
                    detail: "\(tryImpact.label) has been worth about +\(formattedImpact(tryImpact.impact, metric: metric)) over \(tryImpact.sampleCount) tracked nights.",
                    kind: .test,
                    habitID: tryImpact.habitID,
                    optionValue: tryImpact.optionValue
                )
            )
        }

        return recommendations
    }

    private static func analysisReliability(
        logs: [(date: String, entry: DailyLogData)],
        habits: [HabitDefinition],
        overallImpact: ImpactSummary,
        recentImpact: ImpactSummary,
        overallTimingImpact: ImpactSummary,
        recentTimingImpact: ImpactSummary
    ) -> AnalysisReliability {
        let importedNights = logs.count
        let trackedHabitNights = logs.reduce(into: 0) { count, item in
            let hasTrackedBoolean = item.entry.habits.contains { !isDerivedHabitID($0) }
            let hasTrackedValue = item.entry.habitValues.keys.contains { !isDerivedHabitID($0) }
            if hasTrackedBoolean || hasTrackedValue {
                count += 1
            }
        }
        let allImpactRows =
            overallImpact.leaderboard +
            recentImpact.leaderboard +
            overallTimingImpact.leaderboard +
            recentTimingImpact.leaderboard
        let strongestImpactSample = allImpactRows
            .filter(\.isSignificant)
            .map(\.sampleCount)
            .max() ?? 0

        let level: AnalysisReliabilityLevel
        let title: String
        let summary: String

        switch (importedNights, trackedHabitNights, strongestImpactSample) {
        case let (nights, tracked, sample) where nights >= 14 && tracked >= 8 && sample >= 5:
            level = .high
            title = "High-confidence read"
            summary = "There is enough sleep and habit coverage for the app to make tighter calls right now."
        case let (nights, tracked, sample) where nights >= 7 && tracked >= 4 && sample >= 3:
            level = .medium
            title = "Useful, still stabilizing"
            summary = "The patterns are usable now, but another week of consistent check-ins will make them harder to fool."
        default:
            level = .low
            title = "Early signal only"
            summary = "Use the guidance as a light hint for now because the sample is still thin."
        }

        return AnalysisReliability(
            level: level,
            title: title,
            summary: summary,
            evidence: [
                "\(importedNights) imported nights",
                "\(trackedHabitNights) nights with habit check-ins",
                strongestImpactSample > 0 ? "Best comparison has \(strongestImpactSample) matching nights" : "No impact clears the minimum sample yet",
                "\(habits.filter { $0.archivedAt == nil }.count) active habits tracked",
            ]
        )
    }

    private static func experimentPlan(
        recommendations: [DashboardRecommendation],
        reliability: AnalysisReliability,
        metric: DashboardMetric
    ) -> ExperimentPlan? {
        guard let target = recommendations.first(where: { $0.kind == .test })
            ?? recommendations.first(where: { $0.kind == .avoid })
            ?? recommendations.first(where: { $0.kind == .reinforce })
        else {
            return nil
        }

        let durationDays: Int
        switch reliability.level {
        case .high:
            durationDays = 7
        case .medium:
            durationDays = 6
        case .low:
            durationDays = 5
        }

        let confidenceNote: String
        switch reliability.level {
        case .high:
            confidenceNote = "Hold the rest of your evening roughly steady so this stays a clean test."
        case .medium:
            confidenceNote = "Keep other habits mostly stable to make the result easier to trust."
        case .low:
            confidenceNote = "Treat this as a first probe, not a final conclusion."
        }

        return ExperimentPlan(
            title: target.title,
            summary: "\(target.detail) Run this single change for \(durationDays) nights before you judge it.",
            durationDays: durationDays,
            successMetric: "Watch \(metric.title.lowercased()) first, then check whether duration and recovery stay supportive.",
            confidenceNote: confidenceNote
        )
    }

    private static func sleepStatus(
        logs: [(date: String, entry: DailyLogData)],
        recommendations: [DashboardRecommendation]
    ) -> SleepStatus {
        guard let latestEntry = logs.last?.entry else {
            return SleepStatus(
                level: .lowData,
                title: "Build a few nights first",
                summary: "The app needs a small run of imported nights before it can describe your sleep state reliably.",
                focusTitle: "Next step",
                focusDetail: "Keep importing sleep and habits for a few mornings to unlock better guidance.",
                evidence: []
            )
        }

        let recentLogs = Array(logs.suffix(7))
        let previousLogs = Array(recentLogs.dropLast())
        var statusScore = 0
        var evidence: [String] = []

        if let duration = latestEntry.totalDurationHours {
            if duration >= 7 && duration <= 9 {
                statusScore += 2
                evidence.append("Duration landed in the 7 to 9 hour range.")
            } else if duration < 6.5 {
                statusScore -= 2
                evidence.append("Duration was below the 7 hour floor.")
            } else if duration < 7 {
                statusScore -= 1
                evidence.append("Duration was a bit short.")
            }
        }

        if let latestScore = latestEntry.sleepScore {
            let baselineScores = previousLogs.compactMap { $0.entry.sleepScore }
            let baseline = baselineScores.isEmpty
                ? nil
                : Double(baselineScores.reduce(0, +)) / Double(baselineScores.count)

            if let baseline {
                if Double(latestScore) >= baseline + 4 {
                    statusScore += 1
                    evidence.append("Sleep score beat your recent average.")
                } else if Double(latestScore) <= baseline - 4 {
                    statusScore -= 1
                    evidence.append("Sleep score fell below your recent average.")
                }
            } else if latestScore >= 85 {
                statusScore += 1
                evidence.append("Sleep score was strong last night.")
            } else if latestScore < 70 {
                statusScore -= 1
                evidence.append("Sleep score was under your stronger nights.")
            }
        }

        if let consistency = bedtimeConsistencyMinutes(recentLogs) {
            if consistency <= 45 {
                statusScore += 1
                evidence.append("Your sleep timing is staying consistent.")
            } else if consistency >= 90 {
                statusScore -= 1
                evidence.append("Your bedtime is drifting too much.")
            }
        }

        let recoveryDirection = recoveryDirection(latest: latestEntry, recent: previousLogs)
        switch recoveryDirection {
        case .positive:
            statusScore += 2
            evidence.append("Recovery signals improved with HRV up and resting heart rate down.")
        case .negative:
            statusScore -= 2
            evidence.append("Recovery signals softened with HRV down or resting heart rate up.")
        case .neutral:
            break
        }

        if let bodyBattery = latestEntry.bodyBatteryChange {
            if bodyBattery >= 50 {
                statusScore += 1
                evidence.append("Body Battery recharge was strong.")
            } else if bodyBattery < 30 {
                statusScore -= 1
                evidence.append("Body Battery recharge was limited.")
            }
        }

        if let averageSpO2 = latestEntry.averageSpO2 {
            if averageSpO2 >= 95 {
                evidence.append("Average oxygen stayed in a typical range.")
            } else {
                statusScore -= 1
                evidence.append("Average oxygen dipped below the usual 95% range.")
            }
        }

        if let lowestSpO2 = latestEntry.lowestSpO2, lowestSpO2 < 90 {
            statusScore -= 1
            evidence.append("Lowest oxygen dipped lower than expected.")
        }

        if let awakeMinutes = latestEntry.awakeMinutes, awakeMinutes <= 15 {
            statusScore += 1
            evidence.append("Awake time was brief once you were asleep.")
        } else if let awakeMinutes = latestEntry.awakeMinutes, awakeMinutes >= 35 {
            statusScore -= 1
            evidence.append("You spent a lot of time awake during the night.")
        }

        if let restlessMoments = latestEntry.restlessMoments,
           let recentRestlessAverage = average(of: previousLogs.compactMap { $0.entry.restlessMoments.map(Double.init) }) {
            if Double(restlessMoments) <= recentRestlessAverage - 4 {
                statusScore += 1
                evidence.append("Restlessness was lower than your recent baseline.")
            } else if Double(restlessMoments) >= recentRestlessAverage + 4 {
                statusScore -= 1
                evidence.append("Restlessness was higher than your recent baseline.")
            }
        }

        let level: SleepStatusLevel
        let title: String
        let summary: String
        switch statusScore {
        case 5...:
            level = .strong
            title = "Recovery looks strong"
            summary = "Your latest night stacked up well against your recent baseline and your body signals look supportive."
        case 2...4:
            level = .steady
            title = "Sleep is moving in the right direction"
            summary = "You have a decent base right now, but one or two levers still matter for keeping it there."
        case ..<2:
            level = .watch
            title = "Sleep needs tighter control"
            summary = "The trend is more fragile right now, so tonight should focus on protecting recovery instead of adding noise."
        default:
            level = .steady
            title = "Sleep is mixed"
            summary = "Some signals are supportive, but the picture is not clean enough to call it strong."
        }

        let focusRecommendation = prioritizedFocusRecommendation(from: recommendations)
        return SleepStatus(
            level: level,
            title: title,
            summary: summary,
            focusTitle: focusRecommendation?.title ?? "Tonight's focus",
            focusDetail: focusRecommendation?.detail ?? "Keep tracking habits consistently so the app can isolate what is really helping.",
            evidence: Array(evidence.prefix(3))
        )
    }

    private static func signalSummaries(logs: [(date: String, entry: DailyLogData)]) -> [SignalSummary] {
        guard let latestEntry = logs.last?.entry else {
            return []
        }

        let previousLogs = Array(logs.suffix(7).dropLast())
        var summaries: [SignalSummary] = []

        if let rhythmSummary = rhythmSummary(latest: latestEntry, recent: previousLogs) {
            summaries.append(rhythmSummary)
        }

        if let recoverySummary = recoverySummary(latest: latestEntry, recent: previousLogs) {
            summaries.append(recoverySummary)
        }

        if let breathingSummary = breathingSummary(latest: latestEntry) {
            summaries.append(breathingSummary)
        }

        if let stagesSummary = stagesSummary(latest: latestEntry, recent: previousLogs) {
            summaries.append(stagesSummary)
        }

        return summaries
    }

    private static func rhythmSummary(
        latest: DailyLogData,
        recent: [(date: String, entry: DailyLogData)]
    ) -> SignalSummary? {
        guard let duration = latest.totalDurationHours else {
            return nil
        }

        let consistency = bedtimeConsistencyMinutes(recent + [(date: "latest", entry: latest)])
        let value = consistency.map { "\(String(format: "%.1fh", duration)) • \($0)m drift" } ?? String(format: "%.1fh", duration)
        let detail: String
        let tone: SignalTone

        if duration >= 7, let consistency, consistency <= 45 {
            detail = "Enough time asleep and your schedule is staying anchored."
            tone = .positive
        } else if duration < 6.5 || (consistency ?? 0) >= 90 {
            detail = "Either sleep time or timing is putting pressure on the next day."
            tone = .caution
        } else {
            detail = "Rhythm is decent, but it still has room to tighten up."
            tone = .neutral
        }

        return SignalSummary(
            id: "rhythm",
            title: "Rhythm",
            value: value,
            detail: detail,
            tone: tone
        )
    }

    private static func recoverySummary(
        latest: DailyLogData,
        recent: [(date: String, entry: DailyLogData)]
    ) -> SignalSummary? {
        let hrvText = latest.averageOvernightHRV.map { "HRV \($0) ms" }
        let rhrText = latest.restingHeartRate.map { "RHR \($0) bpm" }
        let batteryText = latest.bodyBatteryChange.map { "Battery \(signedInt($0))" }
        let value = [hrvText, rhrText, batteryText].compactMap { $0 }.joined(separator: " • ")

        guard !value.isEmpty else {
            return nil
        }

        let direction = recoveryDirection(latest: latest, recent: recent)
        let detail: String
        let tone: SignalTone
        switch direction {
        case .positive:
            detail = "Recovery is stronger than your recent baseline."
            tone = .positive
        case .negative:
            detail = "Recovery is softer than usual, so protect tonight."
            tone = .caution
        case .neutral:
            detail = "Recovery signals are close to your recent baseline."
            tone = .neutral
        }

        return SignalSummary(
            id: "recovery",
            title: "Recovery",
            value: value,
            detail: detail,
            tone: tone
        )
    }

    private static func breathingSummary(latest: DailyLogData) -> SignalSummary? {
        let oxygenText = latest.averageSpO2.map { "Avg \($0)%" }
        let lowText = latest.lowestSpO2.map { "Low \($0)%" }
        let value = [oxygenText, lowText].compactMap { $0 }.joined(separator: " • ")

        guard !value.isEmpty else {
            return nil
        }

        let detail: String
        let tone: SignalTone
        if let averageSpO2 = latest.averageSpO2, averageSpO2 >= 95,
           let lowestSpO2 = latest.lowestSpO2, lowestSpO2 >= 90 {
            detail = "Oxygen stayed in a typical range overnight."
            tone = .positive
        } else if let lowestSpO2 = latest.lowestSpO2, lowestSpO2 < 90 {
            detail = "Lowest oxygen dipped lower than expected, so keep an eye on this trend."
            tone = .caution
        } else {
            detail = "Breathing signals are usable, but not clearly strong."
            tone = .neutral
        }

        return SignalSummary(
            id: "breathing",
            title: "Breathing",
            value: value,
            detail: detail,
            tone: tone
        )
    }

    private static func stagesSummary(
        latest: DailyLogData,
        recent: [(date: String, entry: DailyLogData)]
    ) -> SignalSummary? {
        let remText = stageText(hours: latest.remHours, minutes: latest.remMinutes, label: "REM")
        let deepText = stageText(hours: latest.deepHours, minutes: latest.deepMinutes, label: "Deep")
        let value = [remText, deepText].compactMap { $0 }.joined(separator: " • ")

        guard !value.isEmpty else {
            return nil
        }

        let awakeText = latest.awakeMinutes.map { "\($0)m awake" }
        let restlessText = latest.restlessMoments.map { "\($0) restless" }
        let detailParts = [latest.summaryHeadline, awakeText, restlessText].compactMap { $0 }
        let detail = detailParts.isEmpty ? "Sleep stages imported successfully." : detailParts.joined(separator: " • ")

        let tone: SignalTone
        if let awake = latest.awakeMinutes, awake <= 15 {
            tone = .positive
        } else if let restless = latest.restlessMoments,
                  let recentAverage = average(of: recent.compactMap { $0.entry.restlessMoments.map(Double.init) }),
                  Double(restless) >= recentAverage + 4 {
            tone = .caution
        } else {
            tone = .neutral
        }

        return SignalSummary(
            id: "stages",
            title: "Stages",
            value: value,
            detail: detail,
            tone: tone
        )
    }

    private static func isImpactActive(
        _ impact: HabitImpact,
        in entry: DailyLogData,
        habitLookup: [String: HabitDefinition]
    ) -> Bool {
        if let habit = habitLookup[impact.habitID],
           habit.type == .time,
           let optionValue = impact.optionValue {
            return timeOptionMatches(entry: entry, habit: habit, option: optionValue)
        }

        if let optionValue = impact.optionValue {
            return entry.habitValues[impact.habitID]?.stringValue == optionValue
        }

        return entry.habits.contains(impact.habitID)
    }

    private static func normalizeImpact(_ impact: Double, metric: DashboardMetric) -> Double {
        metric.isInverse ? (impact * -1) : impact
    }

    private static func uniqueImpacts(_ impacts: [HabitImpact]) -> [HabitImpact] {
        var ordered: [HabitImpact] = []
        var seen = Set<String>()

        for impact in impacts {
            guard seen.insert(impact.id).inserted else {
                continue
            }
            ordered.append(impact)
        }

        return ordered
    }

    private static func prioritizeRecommendationCandidates(_ impacts: [HabitImpact]) -> [HabitImpact] {
        impacts.sorted { lhs, rhs in
            let leftMagnitude = abs(lhs.impact)
            let rightMagnitude = abs(rhs.impact)

            if abs(leftMagnitude - rightMagnitude) > 0.0001 {
                return leftMagnitude > rightMagnitude
            }

            return recommendationPriority(for: lhs.habitID) < recommendationPriority(for: rhs.habitID)
        }
    }

    private static func isDerivedHabitID(_ habitID: String) -> Bool {
        habitID.hasPrefix("derived_")
    }

    private static func recommendationPriority(for habitID: String) -> Int {
        isDerivedHabitID(habitID) ? timingPriority(for: habitID) : 10
    }

    private static func prioritizeTimingImpacts(_ impacts: [HabitImpact]) -> [HabitImpact] {
        impacts.sorted { lhs, rhs in
            let leftPriority = timingPriority(for: lhs.habitID)
            let rightPriority = timingPriority(for: rhs.habitID)

            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            return abs(lhs.impact) > abs(rhs.impact)
        }
    }

    private static func timingPriority(for habitID: String) -> Int {
        switch habitID {
        case "derived_bedtime_window":
            return 0
        case "derived_wake_window":
            return 1
        case "derived_bedtime_rhythm":
            return 2
        case "derived_wake_rhythm":
            return 3
        case "derived_sleep_duration":
            return 4
        default:
            return 5
        }
    }

    private static func isRecommendableImpact(
        _ impact: HabitImpact,
        habitLookup: [String: HabitDefinition]
    ) -> Bool {
        guard let habit = habitLookup[impact.habitID] else {
            return true
        }

        return isHabitRecommendable(habit)
    }

    private static func isPositiveRecommendationImpact(
        _ impact: HabitImpact,
        habitLookup: [String: HabitDefinition]
    ) -> Bool {
        guard isRecommendableImpact(impact, habitLookup: habitLookup) else {
            return false
        }

        guard let habit = habitLookup[impact.habitID] else {
            return true
        }

        if habit.type == .time,
           isMealTimeHabit(habit),
           impact.optionValue == mealTimingOptions.first {
            return false
        }

        return true
    }

    private static func isNegativeRecommendationImpact(
        _ impact: HabitImpact,
        habitLookup: [String: HabitDefinition]
    ) -> Bool {
        isRecommendableImpact(impact, habitLookup: habitLookup)
    }

    private static func isHabitRecommendable(_ habit: HabitDefinition) -> Bool {
        let haystack = "\(habit.id) \(habit.label)".lowercased()
        let blockedKeywords = [
            "class",
            "lecture",
            "school",
            "study",
            "exam",
            "work",
            "office",
            "job",
            "meeting",
            "commute",
            "travel",
            "shift",
            "deadline",
        ]

        return blockedKeywords.allSatisfy { !haystack.contains($0) }
    }

    private static func prioritizedFocusRecommendation(
        from recommendations: [DashboardRecommendation]
    ) -> DashboardRecommendation? {
        recommendations.first { $0.kind == .avoid }
            ?? recommendations.first { $0.kind == .test }
            ?? recommendations.first { $0.kind == .reinforce }
    }

    private static func recommendationTitle(
        for impact: HabitImpact,
        kind: RecommendationKind
    ) -> String {
        if let derivedTitle = derivedRecommendationTitle(label: impact.label, kind: kind) {
            return derivedTitle
        }

        if let timeTitle = timeRecommendationTitle(label: impact.label, kind: kind) {
            return timeTitle
        }

        if let negatedObject = negatedObject(from: impact.label) {
            switch kind {
            case .reinforce:
                return phraseTitle(verb: "Keep avoiding", object: negatedObject, appendTonight: false)
            case .avoid:
                return phraseTitle(verb: "Do", object: negatedObject, appendTonight: true)
            case .test:
                return phraseTitle(verb: "Try avoiding", object: negatedObject, appendTonight: true)
            }
        }

        switch kind {
        case .reinforce:
            return "Continue \(impact.label)"
        case .avoid:
            return phraseTitle(verb: "Stop", object: impact.label, appendTonight: true)
        case .test:
            return phraseTitle(verb: "Try", object: impact.label, appendTonight: true)
        }
    }

    private static func timeRecommendationTitle(
        label: String,
        kind: RecommendationKind
    ) -> String? {
        let parts = label.components(separatedBy: ": ")
        guard parts.count == 2 else {
            return nil
        }

        let category = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let option = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        if isMealTimeLabel(category) {
            switch option {
            case "Within 2h of bed":
                switch kind {
                case .avoid:
                    return "Avoid eating within 2 hours of bed tonight"
                case .reinforce:
                    return "Keep your last meal at least 2 hours before bed"
                case .test:
                    return "Try leaving at least 2 hours between dinner and bed tonight"
                }
            case "2h to 4h before bed":
                switch kind {
                case .reinforce:
                    return "Keep your last meal about 2h to 4h before bed"
                case .avoid:
                    return "Avoid moving your last meal out of the 2h to 4h window tonight"
                case .test:
                    return "Try having your last meal about 2h to 4h before bed"
                }
            case "More than 4h before bed":
                switch kind {
                case .reinforce:
                    return "Keep your last meal more than 4h before bed"
                case .avoid:
                    return "Avoid leaving your last meal more than 4h before bed tonight"
                case .test:
                    return "Try having your last meal more than 4h before bed"
                }
            default:
                break
            }
        }

        if let genericTimeTitle = genericTimeRecommendationTitle(category: category, option: option, kind: kind) {
            return genericTimeTitle
        }

        return nil
    }

    private static func derivedRecommendationTitle(
        label: String,
        kind: RecommendationKind
    ) -> String? {
        let parts = label.components(separatedBy: ": ")
        guard parts.count == 2 else {
            return nil
        }

        let category = parts[0]
        let option = parts[1]

        switch category {
        case "Sleep duration":
            switch kind {
            case .reinforce, .test:
                return sleepDurationTitle(option: option, testing: kind == .test)
            case .avoid:
                if option == "Under 7h" {
                    return "Avoid getting under 7h of sleep tonight"
                }
                return nil
            }
        case "Bedtime window":
            switch kind {
            case .reinforce:
                return bedtimeTitle(prefix: "Keep", option: option, appendTonight: false)
            case .avoid:
                return bedtimeTitle(prefix: "Avoid", option: option, appendTonight: true)
            case .test:
                return bedtimeTitle(prefix: "Try", option: option, appendTonight: true)
            }
        case "Wake time":
            switch kind {
            case .reinforce:
                return wakeTitle(prefix: "Keep", option: option, appendToday: false)
            case .avoid:
                return wakeTitle(prefix: "Avoid", option: option, appendToday: true)
            case .test:
                return wakeTitle(prefix: "Try", option: option, appendToday: true)
            }
        case "Bedtime rhythm":
            switch option {
            case "Consistent":
                return kind == .test ? "Try keeping bedtime regular tonight" : "Keep bedtime regular"
            case "Irregular":
                return kind == .avoid ? "Avoid an irregular bedtime tonight" : nil
            default:
                return nil
            }
        case "Wake rhythm":
            switch option {
            case "Consistent":
                return kind == .test ? "Try keeping wake time regular tomorrow" : "Keep wake time regular"
            case "Irregular":
                return kind == .avoid ? "Avoid an irregular wake time tomorrow" : nil
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func sleepDurationTitle(option: String, testing: Bool) -> String? {
        switch option {
        case "7h to 8h", "8h to 9h":
            return testing ? "Aim for \(option) of sleep tonight" : "Keep sleep at \(option)"
        case "Over 9h":
            return testing ? "Aim for over 9h of sleep tonight" : "Keep sleep over 9h"
        case "Under 7h":
            return testing ? nil : "Keep sleep under 7h"
        default:
            return nil
        }
    }

    private static func bedtimeTitle(
        prefix: String,
        option: String,
        appendTonight: Bool
    ) -> String? {
        switch option {
        case "Before 23:30":
            return appendTonight ? "\(prefix) going to bed before 23:30 tonight" : "\(prefix) bedtime before 23:30"
        case "23:30 to 00:30":
            return appendTonight ? "\(prefix) going to bed around 23:30 to 00:30 tonight" : "\(prefix) bedtime around 23:30 to 00:30"
        case "After 00:30":
            return appendTonight ? "\(prefix) going to bed after 00:30 tonight" : "\(prefix) bedtime after 00:30"
        default:
            return nil
        }
    }

    private static func wakeTitle(
        prefix: String,
        option: String,
        appendToday: Bool
    ) -> String? {
        switch option {
        case "Before 07:30":
            return appendToday ? "\(prefix) waking before 07:30 tomorrow" : "\(prefix) waking before 07:30"
        case "07:30 to 08:30":
            return appendToday ? "\(prefix) waking around 07:30 to 08:30 tomorrow" : "\(prefix) waking around 07:30 to 08:30"
        case "After 08:30":
            return appendToday ? "\(prefix) waking after 08:30 tomorrow" : "\(prefix) waking after 08:30"
        default:
            return nil
        }
    }

    private static func genericTimeRecommendationTitle(
        category: String,
        option: String,
        kind: RecommendationKind
    ) -> String? {
        let subject = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let loweredSubject = subject.lowercased()

        if option.hasPrefix("Before ") {
            let threshold = String(option.dropFirst("Before ".count))
            switch kind {
            case .reinforce:
                return "Keep \(loweredSubject) before \(threshold)"
            case .avoid:
                return "Avoid pushing \(loweredSubject) past \(threshold) today"
            case .test:
                return "Try \(loweredSubject) before \(threshold) today"
            }
        }

        if option.hasPrefix("After ") {
            let threshold = String(option.dropFirst("After ".count))
            switch kind {
            case .reinforce:
                return "Keep \(loweredSubject) after \(threshold)"
            case .avoid:
                return "Avoid \(loweredSubject) after \(threshold) today"
            case .test:
                return "Try \(loweredSubject) after \(threshold) today"
            }
        }

        if option.contains(" to ") {
            switch kind {
            case .reinforce:
                return "Keep \(loweredSubject) around \(option)"
            case .avoid:
                return "Avoid shifting \(loweredSubject) away from \(option) today"
            case .test:
                return "Try \(loweredSubject) around \(option) today"
            }
        }

        return nil
    }

    private static func negatedObject(from label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("no ") {
            return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if lowercased.hasPrefix("not ") {
            return String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if lowercased.hasPrefix("without ") {
            return String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private static func phraseTitle(
        verb: String,
        object: String,
        appendTonight: Bool
    ) -> String {
        let trimmedObject = object.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedObject = trimmedObject.lowercased()
        let shouldAppendTonight = appendTonight &&
            !lowercasedObject.contains("tonight") &&
            !lowercasedObject.contains("today")

        return shouldAppendTonight ? "\(verb) \(trimmedObject) tonight" : "\(verb) \(trimmedObject)"
    }

    private static func bedtimeConsistencyMinutes(
        _ logs: [(date: String, entry: DailyLogData)]
    ) -> Int? {
        let values = logs.compactMap { bedtimeMinutes(for: $0.entry.bedtime) }
        guard values.count >= 3 else {
            return nil
        }

        let mean = values.reduce(0, +) / Double(values.count)
        let averageDeviation = values
            .map { abs($0 - mean) }
            .reduce(0, +) / Double(values.count)

        return Int(averageDeviation.rounded())
    }

    private static func bedtimeMinutes(for bedtime: String?) -> Double? {
        guard let bedtime else {
            return nil
        }

        let parts = bedtime.split(separator: ":")
        guard parts.count == 2,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1])
        else {
            return nil
        }

        var total = (hours * 60) + minutes
        if total < 300 {
            total += 1440
        }
        return total
    }

    private static func clockMinutes(for time: String?) -> Double? {
        guard let time else {
            return nil
        }

        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1])
        else {
            return nil
        }

        return (hours * 60) + minutes
    }

    private static let mealTimingOptions = [
        "Within 2h of bed",
        "2h to 4h before bed",
        "More than 4h before bed",
    ]

    private static let isoCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(abbreviation: "UTC")!
        return calendar
    }()

    private static func isoDayDate(from isoDate: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = isoCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: isoDate)
    }

    private static func isoDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = isoCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func isMealTimeHabit(_ habit: HabitDefinition) -> Bool {
        isMealTimeLabel("\(habit.id) \(habit.label)")
    }

    private static func isMealTimeLabel(_ label: String) -> Bool {
        let lowered = label.lowercased()
        let keywords = ["meal", "dinner", "eat", "eating", "snack", "food", "supper"]
        return keywords.contains { lowered.contains($0) }
    }

    private static func mealTimingOption(
        for entry: DailyLogData,
        habitID: String
    ) -> String? {
        guard let rawMealTime = clockMinutes(for: entry.habitValues[habitID]?.stringValue),
              let bedtime = bedtimeMinutes(for: entry.bedtime)
        else {
            return nil
        }

        var mealTime = rawMealTime
        if bedtime >= 1440, mealTime < 300 {
            mealTime += 1440
        }

        guard mealTime <= bedtime else {
            return nil
        }

        let gapToBed = bedtime - mealTime
        switch gapToBed {
        case ..<120:
            return mealTimingOptions[0]
        case ..<240:
            return mealTimingOptions[1]
        default:
            return mealTimingOptions[2]
        }
    }

    private static func absoluteTimeWindowOptions(
        for habit: HabitDefinition,
        logs: [(date: String, entry: DailyLogData)]
    ) -> [String]? {
        let values = logs
            .compactMap { clockMinutes(for: $0.entry.habitValues[habit.id]?.stringValue) }
            .sorted()

        guard values.count >= 4 else {
            return nil
        }

        let median = values[values.count / 2]
        let lowerBound = roundedClockMinutes(median - 30)
        var upperBound = roundedClockMinutes(median + 30)
        if abs(upperBound - lowerBound) < 1 {
            upperBound = roundedClockMinutes(median + 60)
        }

        let lowerLabel = formattedClockMinutes(lowerBound)
        let upperLabel = formattedClockMinutes(upperBound)
        return [
            "Before \(lowerLabel)",
            "\(lowerLabel) to \(upperLabel)",
            "After \(upperLabel)",
        ]
    }

    private static func absoluteTimeWindowOption(
        for storedTime: String?,
        options: [String]
    ) -> String? {
        guard let minutes = clockMinutes(for: storedTime) else {
            return nil
        }

        return options.first { absoluteTimeWindowOptionMatches(minutes: minutes, option: $0) }
    }

    private static func timeOptionMatches(
        entry: DailyLogData,
        habit: HabitDefinition,
        option: String
    ) -> Bool {
        if isMealTimeHabit(habit) {
            return mealTimingOption(for: entry, habitID: habit.id) == option
        }

        guard let storedTime = entry.habitValues[habit.id]?.stringValue,
              let minutes = clockMinutes(for: storedTime)
        else {
            return false
        }

        return absoluteTimeWindowOptionMatches(minutes: minutes, option: option)
    }

    private static func absoluteTimeWindowOptionMatches(
        minutes: Double,
        option: String
    ) -> Bool {
        if option.hasPrefix("Before ") {
            let threshold = String(option.dropFirst("Before ".count))
            guard let thresholdMinutes = clockMinutes(for: threshold) else {
                return false
            }
            return minutes < thresholdMinutes
        }

        if option.hasPrefix("After ") {
            let threshold = String(option.dropFirst("After ".count))
            guard let thresholdMinutes = clockMinutes(for: threshold) else {
                return false
            }
            return minutes > thresholdMinutes
        }

        let parts = option.components(separatedBy: " to ")
        guard parts.count == 2,
              let startMinutes = clockMinutes(for: parts[0]),
              let endMinutes = clockMinutes(for: parts[1])
        else {
            return false
        }

        return minutes >= startMinutes && minutes <= endMinutes
    }

    private static func roundedClockMinutes(_ minutes: Double) -> Double {
        let clamped = min(max(minutes, 0), 1439)
        let rounded = (clamped / 15).rounded() * 15
        return min(max(rounded, 0), 1439)
    }

    private static func formattedClockMinutes(_ minutes: Double) -> String {
        let normalized = Int(minutes.rounded())
        let hours = normalized / 60
        let remainder = normalized % 60
        return String(format: "%02d:%02d", hours, remainder)
    }

    private enum RecoveryDirection {
        case positive
        case neutral
        case negative
    }

    private static func recoveryDirection(
        latest: DailyLogData,
        recent: [(date: String, entry: DailyLogData)]
    ) -> RecoveryDirection {
        var score = 0

        if let latestHRV = latest.averageOvernightHRV,
           let recentHRV = average(of: recent.compactMap { $0.entry.averageOvernightHRV.map(Double.init) }) {
            if Double(latestHRV) >= recentHRV + 5 {
                score += 1
            } else if Double(latestHRV) <= recentHRV - 5 {
                score -= 1
            }
        }

        if let latestRHR = latest.restingHeartRate,
           let recentRHR = average(of: recent.compactMap { $0.entry.restingHeartRate.map(Double.init) }) {
            if Double(latestRHR) <= recentRHR - 1 {
                score += 1
            } else if Double(latestRHR) >= recentRHR + 1 {
                score -= 1
            }
        }

        if latest.sevenDayHRVStatus?.lowercased() == "balanced" {
            score += 1
        } else if latest.sevenDayHRVStatus?.lowercased() == "unbalanced" {
            score -= 1
        }

        switch score {
        case let value where value > 0:
            return .positive
        case let value where value < 0:
            return .negative
        default:
            return .neutral
        }
    }

    private static func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private static func stageText(hours: Int?, minutes: Int?, label: String) -> String? {
        guard let hours, let minutes else {
            return nil
        }

        let value = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        return "\(label) \(value)"
    }

    private static func signedInt(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private static func formattedImpact(_ value: Double, metric: DashboardMetric) -> String {
        let magnitude = value.rounded() == value ? String(Int(value.rounded())) : String(format: "%.1f", value)
        return "\(magnitude)\(metric.unit)"
    }

    private static let derivedTimingHabits: [HabitDefinition] = [
        HabitDefinition(
            id: "derived_sleep_duration",
            label: "Sleep duration",
            type: .select,
            options: ["Under 7h", "7h to 8h", "8h to 9h", "Over 9h"]
        ),
        HabitDefinition(
            id: "derived_bedtime_window",
            label: "Bedtime window",
            type: .select,
            options: ["Before 23:30", "23:30 to 00:30", "After 00:30"]
        ),
        HabitDefinition(
            id: "derived_wake_window",
            label: "Wake time",
            type: .select,
            options: ["Before 07:30", "07:30 to 08:30", "After 08:30"]
        ),
        HabitDefinition(
            id: "derived_bedtime_rhythm",
            label: "Bedtime rhythm",
            type: .select,
            options: ["Consistent", "Irregular"]
        ),
        HabitDefinition(
            id: "derived_wake_rhythm",
            label: "Wake rhythm",
            type: .select,
            options: ["Consistent", "Irregular"]
        ),
    ]

    public static let defaultHabits: [HabitDefinition] = [
        HabitDefinition(id: "caffeine", label: "No caffeine after 2 PM"),
        HabitDefinition(id: "screens", label: "No screens 1h before bed"),
        HabitDefinition(id: "read", label: "Read a book"),
        HabitDefinition(id: "magnesium", label: "Took Magnesium"),
        HabitDefinition(id: "meditation", label: "Meditation (10m)"),
        HabitDefinition(id: "hot_shower", label: "Hot shower/bath"),
    ]

    public static let recommendedStarterHabits: [HabitDefinition] = [
        HabitDefinition(id: "banana", label: "Banana before bed"),
        HabitDefinition(id: "alcohol", label: "Alcohol"),
        HabitDefinition(id: "late_sport", label: "Late sport tonight"),
        HabitDefinition(id: "day_sport", label: "Did sport during the day"),
        HabitDefinition(id: "meal_time", label: "Mealtime", type: .time),
        HabitDefinition(id: "late_meal", label: "Late meal"),
        HabitDefinition(id: "journaling", label: "Journaling before bed"),
        HabitDefinition(id: "sunlight", label: "Morning sunlight"),
        HabitDefinition(id: "walk", label: "Evening walk"),
    ]
}
