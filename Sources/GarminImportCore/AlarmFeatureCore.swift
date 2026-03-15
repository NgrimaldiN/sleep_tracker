import Foundation

public enum AlarmPermissionState: String, Codable, Equatable, Sendable {
    case unknown
    case denied
    case authorized
    case unavailable
}

public enum ShowerClassifierState: String, Codable, Equatable, Sendable {
    case missing
    case training
    case ready
}

public enum ShowerDetectorLabel: String, Codable, Equatable, Sendable {
    case showerOn = "shower_on"
    case notShower = "not_shower"
}

public struct ShowerDetectorPrediction: Equatable, Sendable {
    public var label: ShowerDetectorLabel
    public var margin: Double
    public var showerDistance: Double
    public var notShowerDistance: Double

    public init(
        label: ShowerDetectorLabel,
        margin: Double,
        showerDistance: Double,
        notShowerDistance: Double
    ) {
        self.label = label
        self.margin = margin
        self.showerDistance = showerDistance
        self.notShowerDistance = notShowerDistance
    }
}

public struct ShowerDetectorProfile: Codable, Equatable, Sendable {
    public var featureNames: [String]
    public var normalizationMeans: [Double]
    public var normalizationStds: [Double]
    public var showerCentroid: [Double]
    public var notShowerCentroid: [Double]
    public var decisionThreshold: Double

    public init(
        featureNames: [String],
        normalizationMeans: [Double],
        normalizationStds: [Double],
        showerCentroid: [Double],
        notShowerCentroid: [Double],
        decisionThreshold: Double
    ) {
        self.featureNames = featureNames
        self.normalizationMeans = normalizationMeans
        self.normalizationStds = normalizationStds
        self.showerCentroid = showerCentroid
        self.notShowerCentroid = notShowerCentroid
        self.decisionThreshold = decisionThreshold
    }

    public func predict(features: [Double]) -> ShowerDetectorPrediction {
        let normalizedFeatures = normalized(features: features)
        let showerDistance = euclideanDistance(
            lhs: normalizedFeatures,
            rhs: showerCentroid
        )
        let notShowerDistance = euclideanDistance(
            lhs: normalizedFeatures,
            rhs: notShowerCentroid
        )
        let margin = notShowerDistance - showerDistance
        let label: ShowerDetectorLabel = margin >= decisionThreshold ? .showerOn : .notShower

        return ShowerDetectorPrediction(
            label: label,
            margin: margin,
            showerDistance: showerDistance,
            notShowerDistance: notShowerDistance
        )
    }

    private func normalized(features: [Double]) -> [Double] {
        zip(features.indices, features).map { index, value in
            let mean = normalizationMeans[index]
            let std = normalizationStds[index]
            guard std > 0 else {
                return value - mean
            }
            return (value - mean) / std
        }
    }

    private func euclideanDistance(lhs: [Double], rhs: [Double]) -> Double {
        sqrt(zip(lhs, rhs).reduce(0) { partialResult, pair in
            let delta = pair.0 - pair.1
            return partialResult + (delta * delta)
        })
    }
}

public struct ShowerDetectionGate: Equatable, Sendable {
    public var consecutivePositiveWindowsRequired: Int
    public var minimumMargin: Double
    public private(set) var consecutivePositiveCount: Int

    public init(
        consecutivePositiveWindowsRequired: Int = 3,
        minimumMargin: Double = 0.25,
        consecutivePositiveCount: Int = 0
    ) {
        self.consecutivePositiveWindowsRequired = max(1, consecutivePositiveWindowsRequired)
        self.minimumMargin = minimumMargin
        self.consecutivePositiveCount = consecutivePositiveCount
    }

    public mutating func ingest(_ prediction: ShowerDetectorPrediction) -> Bool {
        let qualifies = prediction.label == .showerOn && prediction.margin >= minimumMargin

        if qualifies {
            consecutivePositiveCount += 1
        } else {
            consecutivePositiveCount = 0
        }

        return consecutivePositiveCount >= consecutivePositiveWindowsRequired
    }

    public mutating func reset() {
        consecutivePositiveCount = 0
    }
}

public struct WakeNotificationCadence: Equatable, Sendable {
    public var count: Int
    public var spacingSeconds: TimeInterval

    public init(count: Int, spacingSeconds: TimeInterval) {
        self.count = max(1, count)
        self.spacingSeconds = max(1, spacingSeconds)
    }
}

public struct ShowerDetectorStreamBuffer: Equatable, Sendable {
    public var analysisWindowDuration: Double
    public var analysisHopDuration: Double
    public private(set) var bufferedSamples: [Float]

    public init(
        analysisWindowDuration: Double = 2.0,
        analysisHopDuration: Double = 1.0,
        bufferedSamples: [Float] = []
    ) {
        self.analysisWindowDuration = max(0.25, analysisWindowDuration)
        self.analysisHopDuration = max(0.1, analysisHopDuration)
        self.bufferedSamples = bufferedSamples
    }

    public mutating func ingest(samples: [Float], sampleRate: Double) -> [[Float]] {
        guard sampleRate > 0 else { return [] }

        bufferedSamples.append(contentsOf: samples)

        let windowSize = max(1, Int((sampleRate * analysisWindowDuration).rounded()))
        let hopSize = max(1, Int((sampleRate * analysisHopDuration).rounded()))

        var emittedWindows: [[Float]] = []
        while bufferedSamples.count >= windowSize {
            emittedWindows.append(Array(bufferedSamples.prefix(windowSize)))
            bufferedSamples.removeFirst(min(hopSize, bufferedSamples.count))
        }

        return emittedWindows
    }

    public mutating func reset() {
        bufferedSamples.removeAll(keepingCapacity: false)
    }
}

public enum ShowerDetectorSampleMixer {
    public static func downmixToMono(channels: [[Float]]) -> [Float] {
        guard let firstChannel = channels.first else { return [] }
        guard channels.count > 1 else { return firstChannel }

        let frameCount = channels.map(\.count).min() ?? 0
        guard frameCount > 0 else { return [] }

        let channelCount = Float(channels.count)
        return (0..<frameCount).map { frameIndex in
            let sum = channels.reduce(Float.zero) { partialResult, channel in
                partialResult + channel[frameIndex]
            }
            return sum / channelCount
        }
    }
}

public enum ShowerDetectorFeatureExtractor {
    public static let targetSampleRate = 16_000.0
    public static let featureNames = [
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

    private static let frameSize = 1_024
    private static let hopSize = 256

    public static func extractFeatureVector(
        samples: [Float],
        sampleRate: Double
    ) -> [Double] {
        let mono = resampled(samples: samples, from: sampleRate, to: targetSampleRate)
        let frames = frame(samples: mono)

        let rmsDb = frames.map(frameRmsDb)
        let zeroCrossings = frames.map(frameZeroCrossingRate)
        let absDiff = frames.map(frameAbsoluteDiffMean)
        let peakToRms = frames.map(framePeakToRms)
        let flux = frameFlux(rmsDb: rmsDb)

        return [
            mean(rmsDb),
            standardDeviation(rmsDb),
            mean(zeroCrossings),
            standardDeviation(zeroCrossings),
            mean(absDiff),
            standardDeviation(absDiff),
            mean(flux),
            standardDeviation(flux),
            mean(peakToRms),
            standardDeviation(peakToRms),
        ]
    }

    private static func resampled(
        samples: [Float],
        from sourceSampleRate: Double,
        to targetSampleRate: Double
    ) -> [Float] {
        guard !samples.isEmpty else { return [] }
        guard abs(sourceSampleRate - targetSampleRate) > 0.5 else { return samples }

        let ratio = targetSampleRate / sourceSampleRate
        let targetCount = max(1, Int((Double(samples.count) * ratio).rounded()))

        return (0..<targetCount).map { index in
            let sourcePosition = Double(index) / ratio
            let lowerIndex = max(0, min(samples.count - 1, Int(sourcePosition.rounded(.down))))
            let upperIndex = max(0, min(samples.count - 1, lowerIndex + 1))
            let fraction = Float(sourcePosition - Double(lowerIndex))
            return samples[lowerIndex] + ((samples[upperIndex] - samples[lowerIndex]) * fraction)
        }
    }

    private static func frame(samples: [Float]) -> [[Float]] {
        guard !samples.isEmpty else {
            return [Array(repeating: 0, count: frameSize)]
        }

        var padded = samples
        if padded.count < frameSize {
            padded.append(contentsOf: repeatElement(0, count: frameSize - padded.count))
        }

        let remainder = (padded.count - frameSize) % hopSize
        if remainder != 0 {
            padded.append(contentsOf: repeatElement(0, count: hopSize - remainder))
        }

        let frameCount = 1 + ((padded.count - frameSize) / hopSize)
        return (0..<frameCount).map { index in
            let start = index * hopSize
            let end = start + frameSize
            return Array(padded[start..<end])
        }
    }

    private static func frameRmsDb(_ frame: [Float]) -> Double {
        let squareMean = frame.reduce(0.0) { partialResult, value in
            partialResult + Double(value * value)
        } / Double(frame.count)
        let rms = sqrt(squareMean + 1e-8)
        return 20.0 * log10(rms + 1e-8)
    }

    private static func frameZeroCrossingRate(_ frame: [Float]) -> Double {
        guard frame.count > 1 else { return 0 }
        let crossings = zip(frame, frame.dropFirst()).reduce(0.0) { partialResult, pair in
            let changedSign = (pair.0 >= 0 && pair.1 < 0) || (pair.0 < 0 && pair.1 >= 0)
            return partialResult + (changedSign ? 1 : 0)
        }
        return crossings / Double(frame.count - 1)
    }

    private static func frameAbsoluteDiffMean(_ frame: [Float]) -> Double {
        guard frame.count > 1 else { return 0 }
        let total = zip(frame, frame.dropFirst()).reduce(0.0) { partialResult, pair in
            partialResult + Double(abs(pair.1 - pair.0))
        }
        return total / Double(frame.count - 1)
    }

    private static func framePeakToRms(_ frame: [Float]) -> Double {
        let peak = frame.map { Double(abs($0)) }.max() ?? 0
        let rms = sqrt(frame.reduce(0.0) { partialResult, value in
            partialResult + Double(value * value)
        } / Double(frame.count) + 1e-8)
        return peak / max(rms, 1e-8)
    }

    private static func frameFlux(rmsDb: [Double]) -> [Double] {
        guard rmsDb.count > 1 else { return [0] }
        return zip(rmsDb, rmsDb.dropFirst()).map { abs($1 - $0) }
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let average = mean(values)
        let variance = values.reduce(0.0) { partialResult, value in
            let delta = value - average
            return partialResult + (delta * delta)
        } / Double(values.count)
        return sqrt(variance)
    }
}

public enum ShowerSampleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case showerOn = "shower_on"
    case bathroomAmbient = "bathroom_ambient"
    case sinkRunning = "sink_running"
    case bathroomFan = "bathroom_fan"
    case speechMovement = "speech_movement"
    case silence = "silence"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .showerOn:
            return "Shower On"
        case .bathroomAmbient:
            return "Bathroom Ambient"
        case .sinkRunning:
            return "Sink Running"
        case .bathroomFan:
            return "Bathroom Fan"
        case .speechMovement:
            return "Speech + Movement"
        case .silence:
            return "Silence"
        }
    }

    public var guidance: String {
        switch self {
        case .showerOn:
            return "Record the real shower you use, with the phone in realistic bathroom positions."
        case .bathroomAmbient:
            return "Record normal bathroom room tone with no water running."
        case .sinkRunning:
            return "Record sink or faucet noise so the detector does not confuse it with the shower."
        case .bathroomFan:
            return "Record the ventilation/fan sound on its own if it is audible in the bathroom."
        case .speechMovement:
            return "Record you moving around, speaking, or handling the phone in the bathroom."
        case .silence:
            return "Record the quiet baseline so the detector learns the room noise floor."
        }
    }

    public var targetClipCount: Int {
        switch self {
        case .showerOn:
            return 12
        case .bathroomAmbient:
            return 8
        case .sinkRunning:
            return 8
        case .bathroomFan:
            return 8
        case .speechMovement:
            return 8
        case .silence:
            return 6
        }
    }

    public var clipDurationSeconds: Int { 8 }

    public var isRequiredForBaselineClassifier: Bool {
        switch self {
        case .showerOn, .bathroomAmbient, .speechMovement:
            return true
        case .sinkRunning, .bathroomFan, .silence:
            return false
        }
    }
}

public struct ShowerTrainingSample: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ShowerSampleKind
    public var durationSeconds: Int
    public var createdAt: String
    public var fileName: String

    public init(
        id: UUID = UUID(),
        kind: ShowerSampleKind,
        durationSeconds: Int,
        createdAt: String,
        fileName: String
    ) {
        self.id = id
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.fileName = fileName
    }
}

public struct ShowerSampleRequirement: Equatable, Identifiable, Sendable {
    public var kind: ShowerSampleKind
    public var label: String
    public var guidance: String
    public var targetClipCount: Int
    public var clipDurationSeconds: Int
    public var completedClipCount: Int
    public var isRequired: Bool

    public var id: String { kind.rawValue }

    public var remainingClipCount: Int {
        max(0, targetClipCount - completedClipCount)
    }

    public var isComplete: Bool {
        remainingClipCount == 0
    }

    public init(
        kind: ShowerSampleKind,
        label: String,
        guidance: String,
        targetClipCount: Int,
        clipDurationSeconds: Int,
        completedClipCount: Int,
        isRequired: Bool
    ) {
        self.kind = kind
        self.label = label
        self.guidance = guidance
        self.targetClipCount = targetClipCount
        self.clipDurationSeconds = clipDurationSeconds
        self.completedClipCount = completedClipCount
        self.isRequired = isRequired
    }
}

public struct ShowerAlarmConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int
    public var repeatsDaily: Bool
    public var scheduledAlarmID: UUID?
    public var scheduledForISO8601: String?
    public var lastScheduledAt: String?
    public var experimentalHandsFreeEnabled: Bool
    public var handsFreeWindowMinutes: Int

    public init(
        isEnabled: Bool = false,
        hour: Int = 7,
        minute: Int = 0,
        repeatsDaily: Bool = true,
        scheduledAlarmID: UUID? = nil,
        scheduledForISO8601: String? = nil,
        lastScheduledAt: String? = nil,
        experimentalHandsFreeEnabled: Bool = false,
        handsFreeWindowMinutes: Int = 5
    ) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.repeatsDaily = repeatsDaily
        self.scheduledAlarmID = scheduledAlarmID
        self.scheduledForISO8601 = scheduledForISO8601
        self.lastScheduledAt = lastScheduledAt
        self.experimentalHandsFreeEnabled = experimentalHandsFreeEnabled
        self.handsFreeWindowMinutes = handsFreeWindowMinutes
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case hour
        case minute
        case repeatsDaily
        case scheduledAlarmID
        case scheduledForISO8601
        case lastScheduledAt
        case experimentalHandsFreeEnabled
        case handsFreeWindowMinutes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        hour = try container.decodeIfPresent(Int.self, forKey: .hour) ?? 7
        minute = try container.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        repeatsDaily = try container.decodeIfPresent(Bool.self, forKey: .repeatsDaily) ?? true
        scheduledAlarmID = try container.decodeIfPresent(UUID.self, forKey: .scheduledAlarmID)
        scheduledForISO8601 = try container.decodeIfPresent(String.self, forKey: .scheduledForISO8601)
        lastScheduledAt = try container.decodeIfPresent(String.self, forKey: .lastScheduledAt)
        experimentalHandsFreeEnabled = try container.decodeIfPresent(Bool.self, forKey: .experimentalHandsFreeEnabled) ?? false
        handsFreeWindowMinutes = try container.decodeIfPresent(Int.self, forKey: .handsFreeWindowMinutes) ?? 5
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encode(repeatsDaily, forKey: .repeatsDaily)
        try container.encodeIfPresent(scheduledAlarmID, forKey: .scheduledAlarmID)
        try container.encodeIfPresent(scheduledForISO8601, forKey: .scheduledForISO8601)
        try container.encodeIfPresent(lastScheduledAt, forKey: .lastScheduledAt)
        try container.encode(experimentalHandsFreeEnabled, forKey: .experimentalHandsFreeEnabled)
        try container.encode(handsFreeWindowMinutes, forKey: .handsFreeWindowMinutes)
    }
}

public struct ShowerAlarmScheduleDescriptor: Equatable, Sendable {
    public var dayLabel: String
    public var timeLabel: String
    public var nextOccurrence: Date

    public init(dayLabel: String, timeLabel: String, nextOccurrence: Date) {
        self.dayLabel = dayLabel
        self.timeLabel = timeLabel
        self.nextOccurrence = nextOccurrence
    }
}

public struct ShowerAlarmListCardDescriptor: Equatable, Sendable {
    public var timeLabel: String
    public var dayLabel: String
    public var isActive: Bool

    public init(timeLabel: String, dayLabel: String, isActive: Bool) {
        self.timeLabel = timeLabel
        self.dayLabel = dayLabel
        self.isActive = isActive
    }
}

public enum ShowerWakeWindowPhase: String, Codable, Equatable, Sendable {
    case disabled
    case pending
    case active
    case expired
}

public struct ShowerWakeWindowDescriptor: Equatable, Sendable {
    public var phase: ShowerWakeWindowPhase
    public var startLabel: String
    public var endLabel: String
    public var summary: String
    public var shouldKeepListening: Bool
    public var isWithinConfirmationWindow: Bool

    public init(
        phase: ShowerWakeWindowPhase,
        startLabel: String,
        endLabel: String,
        summary: String,
        shouldKeepListening: Bool,
        isWithinConfirmationWindow: Bool
    ) {
        self.phase = phase
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.summary = summary
        self.shouldKeepListening = shouldKeepListening
        self.isWithinConfirmationWindow = isWithinConfirmationWindow
    }
}

public enum ShowerMissionPhase: String, Codable, Equatable, Sendable {
    case pending
    case active
    case expired
}

public struct ShowerMissionDescriptor: Equatable, Sendable {
    public var phase: ShowerMissionPhase
    public var scheduledTimeLabel: String
    public var expiresAtLabel: String
    public var summary: String
    public var shouldPresentMission: Bool

    public init(
        phase: ShowerMissionPhase,
        scheduledTimeLabel: String,
        expiresAtLabel: String,
        summary: String,
        shouldPresentMission: Bool
    ) {
        self.phase = phase
        self.scheduledTimeLabel = scheduledTimeLabel
        self.expiresAtLabel = expiresAtLabel
        self.summary = summary
        self.shouldPresentMission = shouldPresentMission
    }
}

public enum ShowerAlarmReadinessLevel: String, Codable, Equatable, Sendable {
    case unavailable
    case needsAlarmAccess
    case needsMicrophoneAccess
    case needsSamples
    case needsModel
    case readyToArm
    case armed
}

public struct ShowerAlarmSnapshot: Equatable, Sendable {
    public var level: ShowerAlarmReadinessLevel
    public var title: String
    public var summary: String
    public var nextActionTitle: String
    public var blockers: [String]
    public var sampleRequirements: [ShowerSampleRequirement]
    public var totalRequiredClips: Int
    public var totalRequiredSeconds: Int
    public var collectedClipCount: Int
    public var collectedSeconds: Int
    public var alarmTimeLabel: String
    public var scheduleDayLabel: String

    public init(
        level: ShowerAlarmReadinessLevel,
        title: String,
        summary: String,
        nextActionTitle: String,
        blockers: [String],
        sampleRequirements: [ShowerSampleRequirement],
        totalRequiredClips: Int,
        totalRequiredSeconds: Int,
        collectedClipCount: Int,
        collectedSeconds: Int,
        alarmTimeLabel: String,
        scheduleDayLabel: String
    ) {
        self.level = level
        self.title = title
        self.summary = summary
        self.nextActionTitle = nextActionTitle
        self.blockers = blockers
        self.sampleRequirements = sampleRequirements
        self.totalRequiredClips = totalRequiredClips
        self.totalRequiredSeconds = totalRequiredSeconds
        self.collectedClipCount = collectedClipCount
        self.collectedSeconds = collectedSeconds
        self.alarmTimeLabel = alarmTimeLabel
        self.scheduleDayLabel = scheduleDayLabel
    }
}

public extension SleepTrackerAppCore {
    static func showerAlarmScheduleDescriptor(
        hour: Int,
        minute: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ShowerAlarmScheduleDescriptor {
        let nextOccurrence = nextAlarmOccurrence(
            hour: hour,
            minute: minute,
            now: now,
            calendar: calendar
        )
        let dayLabel = relativeDayLabel(
            for: nextOccurrence,
            now: now,
            calendar: calendar
        )
        return ShowerAlarmScheduleDescriptor(
            dayLabel: dayLabel,
            timeLabel: String(format: "%02d:%02d", hour, minute),
            nextOccurrence: nextOccurrence
        )
    }

    static func showerAlarmListCardDescriptor(
        configuration: ShowerAlarmConfiguration,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ShowerAlarmListCardDescriptor {
        let plannedSchedule = showerAlarmScheduleDescriptor(
            hour: configuration.hour,
            minute: configuration.minute,
            now: now,
            calendar: calendar
        )
        let scheduledOccurrence = scheduledDate(
            from: configuration.scheduledForISO8601
        ) ?? plannedSchedule.nextOccurrence
        let dayLabel = relativeDayLabel(
            for: scheduledOccurrence,
            now: now,
            calendar: calendar
        )

        return ShowerAlarmListCardDescriptor(
            timeLabel: plannedSchedule.timeLabel,
            dayLabel: dayLabel,
            isActive: configuration.isEnabled && configuration.scheduledAlarmID != nil
        )
    }

    static func showerWakeWindowDescriptor(
        configuration: ShowerAlarmConfiguration,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ShowerWakeWindowDescriptor? {
        guard configuration.experimentalHandsFreeEnabled else {
            return ShowerWakeWindowDescriptor(
                phase: .disabled,
                startLabel: String(format: "%02d:%02d", configuration.hour, configuration.minute),
                endLabel: String(format: "%02d:%02d", configuration.hour, configuration.minute),
                summary: "Hands-free shower stop is off.",
                shouldKeepListening: false,
                isWithinConfirmationWindow: false
            )
        }

        guard configuration.isEnabled,
              configuration.scheduledAlarmID != nil,
              let scheduledAt = scheduledDate(from: configuration.scheduledForISO8601) else {
            return nil
        }

        let endAt = calendar.date(
            byAdding: .minute,
            value: max(1, configuration.handsFreeWindowMinutes),
            to: scheduledAt
        ) ?? scheduledAt.addingTimeInterval(TimeInterval(max(1, configuration.handsFreeWindowMinutes) * 60))

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"

        if now < scheduledAt {
            return ShowerWakeWindowDescriptor(
                phase: .pending,
                startLabel: formatter.string(from: scheduledAt),
                endLabel: formatter.string(from: endAt),
                summary: "The app keeps listening in the background so it can verify the shower from \(formatter.string(from: scheduledAt)) to \(formatter.string(from: endAt)).",
                shouldKeepListening: true,
                isWithinConfirmationWindow: false
            )
        }

        if now <= endAt {
            return ShowerWakeWindowDescriptor(
                phase: .active,
                startLabel: formatter.string(from: scheduledAt),
                endLabel: formatter.string(from: endAt),
                summary: "The hands-free shower window is active until \(formatter.string(from: endAt)).",
                shouldKeepListening: true,
                isWithinConfirmationWindow: true
            )
        }

        return ShowerWakeWindowDescriptor(
            phase: .expired,
            startLabel: formatter.string(from: scheduledAt),
            endLabel: formatter.string(from: endAt),
            summary: "The five-minute hands-free shower window ended at \(formatter.string(from: endAt)).",
            shouldKeepListening: false,
            isWithinConfirmationWindow: false
        )
    }

    static func showerMissionDescriptor(
        configuration: ShowerAlarmConfiguration,
        now: Date = Date(),
        calendar: Calendar = .current,
        missionWindowMinutes: Int = 20
    ) -> ShowerMissionDescriptor? {
        guard configuration.isEnabled,
              configuration.scheduledAlarmID != nil,
              let scheduledAt = scheduledDate(from: configuration.scheduledForISO8601) else {
            return nil
        }

        let expiry = calendar.date(
            byAdding: .minute,
            value: max(1, missionWindowMinutes),
            to: scheduledAt
        ) ?? scheduledAt.addingTimeInterval(TimeInterval(max(1, missionWindowMinutes) * 60))

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"

        if now < scheduledAt {
            return ShowerMissionDescriptor(
                phase: .pending,
                scheduledTimeLabel: formatter.string(from: scheduledAt),
                expiresAtLabel: formatter.string(from: expiry),
                summary: "At wake time the app should switch into the loud wake tone. Open the app or the wake notification and shower detection will start automatically.",
                shouldPresentMission: false
            )
        }

        if now <= expiry {
            return ShowerMissionDescriptor(
                phase: .active,
                scheduledTimeLabel: formatter.string(from: scheduledAt),
                expiresAtLabel: formatter.string(from: expiry),
                summary: "Wake-up mission active until \(formatter.string(from: expiry)). Open the app from the notification and turn on the shower with the phone in the bathroom while the alarm keeps sounding.",
                shouldPresentMission: true
            )
        }

        return ShowerMissionDescriptor(
            phase: .expired,
            scheduledTimeLabel: formatter.string(from: scheduledAt),
            expiresAtLabel: formatter.string(from: expiry),
            summary: "The automatic shower mission window ended at \(formatter.string(from: expiry)).",
            shouldPresentMission: false
        )
    }

    static func shouldStartShowerMissionListening(
        requestedGeneration: Int,
        currentGeneration: Int,
        isSceneActive: Bool,
        isMissionPresented: Bool,
        isMissionListening: Bool,
        hasConfirmedShower: Bool
    ) -> Bool {
        guard requestedGeneration == currentGeneration else {
            return false
        }

        guard isSceneActive else {
            return false
        }

        guard isMissionPresented else {
            return false
        }

        guard !isMissionListening else {
            return false
        }

        guard !hasConfirmedShower else {
            return false
        }

        return true
    }

    static func missionShowerDetectionGate(
        profile: ShowerDetectorProfile
    ) -> ShowerDetectionGate {
        ShowerDetectionGate(
            consecutivePositiveWindowsRequired: 5,
            minimumMargin: max(profile.decisionThreshold + 0.35, 0.35)
        )
    }

    static func wakeNotificationCadence(
        windowMinutes: Int,
        spacingSeconds: TimeInterval = 3
    ) -> WakeNotificationCadence {
        let clampedWindowMinutes = max(1, windowMinutes)
        let clampedSpacingSeconds = max(1, spacingSeconds)
        let totalWindowSeconds = Double(clampedWindowMinutes * 60)
        let count = Int(ceil(totalWindowSeconds / clampedSpacingSeconds))

        return WakeNotificationCadence(
            count: max(1, count),
            spacingSeconds: clampedSpacingSeconds
        )
    }

    static func shouldResumeWakeAudioForBackgroundMission(
        isMissionPresented: Bool,
        hasConfirmedShower: Bool
    ) -> Bool {
        isMissionPresented && !hasConfirmedShower
    }

    static func shouldKeepWakeToneAudibleDuringMission(
        isMissionPresented: Bool,
        isMissionListening: Bool,
        hasConfirmedShower: Bool
    ) -> Bool {
        isMissionPresented && !isMissionListening && !hasConfirmedShower
    }

    static func enforcedWakeVolumeTarget(
        currentVolume: Float,
        isAlarmArmed: Bool,
        isMissionPresented: Bool,
        mutedThreshold: Float = 0.05,
        targetVolume: Float = 0.55
    ) -> Float? {
        // When the alarm is actively ringing, force volume to maximum.
        // Combined with KVO on outputVolume this reacts before the
        // volume HUD even finishes animating — matching Math Alarm's
        // "impossible to silence" behavior.
        if isMissionPresented {
            guard currentVolume < 0.99 else { return nil }
            return 1.0
        }

        guard isAlarmArmed else { return nil }
        guard currentVolume <= mutedThreshold else { return nil }
        return targetVolume
    }

    static func shouldPlayForegroundWakeNotificationSound(
        isMissionPresented: Bool
    ) -> Bool {
        // Always play the notification sound even when the continuous wake tone
        // is already playing.  The notification sound is the last-resort
        // fallback: if the audio session failed to activate, the notification
        // sound still reaches the user every 3 seconds.  A brief overlap with
        // the AVAudioPlayer tone is acceptable — louder is better than silent.
        true
    }

    static func shouldRefreshWakeAudioOnMissionPresentation(
        isMissionPresented: Bool,
        isMissionListening: Bool,
        hasConfirmedShower: Bool
    ) -> Bool {
        isMissionPresented && !isMissionListening && !hasConfirmedShower
    }

    static func shouldWakeAudioReconfigureSession(
        isMissionPresented: Bool,
        isMissionListening: Bool,
        hasConfirmedShower: Bool
    ) -> Bool {
        !(isMissionPresented && isMissionListening && !hasConfirmedShower)
    }

    static func showerSampleRequirements(
        samples: [ShowerTrainingSample]
    ) -> [ShowerSampleRequirement] {
        let counts = Dictionary(grouping: samples, by: \.kind)
            .mapValues(\.count)

        return ShowerSampleKind.allCases.map { kind in
            ShowerSampleRequirement(
                kind: kind,
                label: kind.label,
                guidance: kind.guidance,
                targetClipCount: kind.targetClipCount,
                clipDurationSeconds: kind.clipDurationSeconds,
                completedClipCount: counts[kind, default: 0],
                isRequired: kind.isRequiredForBaselineClassifier
            )
        }
    }

    static func showerAlarmSnapshot(
        configuration: ShowerAlarmConfiguration,
        alarmPermission: AlarmPermissionState,
        microphonePermission: AlarmPermissionState,
        classifierState: ShowerClassifierState,
        samples: [ShowerTrainingSample],
        isPlatformSupported: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ShowerAlarmSnapshot {
        let requirements = showerSampleRequirements(samples: samples)
        let requiredRequirements = requirements.filter(\.isRequired)
        let totalRequiredClips = requiredRequirements.reduce(0) { $0 + $1.targetClipCount }
        let totalRequiredSeconds = requiredRequirements.reduce(0) { $0 + ($1.targetClipCount * $1.clipDurationSeconds) }
        let collectedClipCount = requiredRequirements.reduce(0) { partialResult, requirement in
            partialResult + min(requirement.completedClipCount, requirement.targetClipCount)
        }
        let collectedSeconds = requiredRequirements.reduce(0) { partialResult, requirement in
            partialResult + (min(requirement.completedClipCount, requirement.targetClipCount) * requirement.clipDurationSeconds)
        }
        let plannedSchedule = showerAlarmScheduleDescriptor(
            hour: configuration.hour,
            minute: configuration.minute,
            now: now,
            calendar: calendar
        )
        let armedOccurrence = scheduledDate(
            from: configuration.scheduledForISO8601
        ) ?? plannedSchedule.nextOccurrence
        let armedDayLabel = relativeDayLabel(
            for: armedOccurrence,
            now: now,
            calendar: calendar
        )
        let alarmTimeLabel = plannedSchedule.timeLabel

        if !isPlatformSupported {
            return ShowerAlarmSnapshot(
                level: .unavailable,
                title: "Wake mission unavailable",
                summary: "This device cannot schedule local wake notifications for the shower mission.",
                nextActionTitle: "Use a supported iPhone",
                blockers: ["Wake notifications are unavailable on this device."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel,
                scheduleDayLabel: plannedSchedule.dayLabel
            )
        }

        if alarmPermission != .authorized {
            return ShowerAlarmSnapshot(
                level: .needsAlarmAccess,
                title: "Allow wake notifications",
                summary: "The app cannot schedule the shower wake mission until notification access is granted.",
                nextActionTitle: "Allow notifications",
                blockers: ["Notification permission is still missing."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel,
                scheduleDayLabel: plannedSchedule.dayLabel
            )
        }

        if microphonePermission != .authorized {
            return ShowerAlarmSnapshot(
                level: .needsMicrophoneAccess,
                title: "Allow the microphone",
                summary: "Shower confirmation depends on local audio listening after the wake notification, so microphone access is required.",
                nextActionTitle: "Allow microphone",
                blockers: ["Microphone permission is still missing."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel,
                scheduleDayLabel: plannedSchedule.dayLabel
            )
        }

        if classifierState != .ready {
            if let incompleteRequirement = requiredRequirements.first(where: { !$0.isComplete }) {
                let remainingClips = requiredRequirements.reduce(0) { $0 + $1.remainingClipCount }
                return ShowerAlarmSnapshot(
                    level: .needsSamples,
                    title: "Build the shower dataset",
                    summary: "Record \(remainingClips) more baseline clips so the app can learn your bathroom soundscape before wake-up testing.",
                    nextActionTitle: "Record training samples",
                    blockers: ["\(incompleteRequirement.label) still needs \(incompleteRequirement.remainingClipCount) more clips."],
                    sampleRequirements: requirements,
                    totalRequiredClips: totalRequiredClips,
                    totalRequiredSeconds: totalRequiredSeconds,
                    collectedClipCount: collectedClipCount,
                    collectedSeconds: collectedSeconds,
                    alarmTimeLabel: alarmTimeLabel,
                    scheduleDayLabel: plannedSchedule.dayLabel
                )
            }

            return ShowerAlarmSnapshot(
                level: .needsModel,
                title: "Training data ready",
                summary: "The sample pack is complete, but the shower classifier still needs to be trained and added back into the app.",
                nextActionTitle: "Train and import classifier",
                blockers: ["The shower classifier has not been trained yet."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel,
                scheduleDayLabel: plannedSchedule.dayLabel
            )
        }

        if configuration.isEnabled, configuration.scheduledAlarmID != nil {
            return ShowerAlarmSnapshot(
                level: .armed,
                title: "Wake mission armed",
                summary: "Your \(armedDayLabel) at \(alarmTimeLabel) wake mission is armed. Leave the app in the background so it can switch into the loud wake tone, with notifications as backup.",
                nextActionTitle: "Wake mission armed",
                blockers: [],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel,
                scheduleDayLabel: armedDayLabel
            )
        }

        return ShowerAlarmSnapshot(
            level: .readyToArm,
            title: "Wake mission ready",
            summary: "Permissions and the shower classifier are ready. The next step is arming the wake mission for \(plannedSchedule.dayLabel) at \(alarmTimeLabel), then leaving the app in the background overnight.",
            nextActionTitle: "Arm for \(plannedSchedule.dayLabel)",
            blockers: [],
            sampleRequirements: requirements,
            totalRequiredClips: totalRequiredClips,
            totalRequiredSeconds: totalRequiredSeconds,
            collectedClipCount: collectedClipCount,
            collectedSeconds: collectedSeconds,
            alarmTimeLabel: alarmTimeLabel,
            scheduleDayLabel: plannedSchedule.dayLabel
        )
    }

    private static func nextAlarmOccurrence(
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(hour: hour, minute: minute)
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? now.addingTimeInterval(60)
    }

    private static func relativeDayLabel(
        for date: Date,
        now: Date,
        calendar: Calendar
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    private static func scheduledDate(from iso8601Value: String?) -> Date? {
        guard let iso8601Value else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso8601Value)
    }
}
