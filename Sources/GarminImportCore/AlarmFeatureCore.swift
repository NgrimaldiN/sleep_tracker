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
        completedClipCount: Int
    ) {
        self.kind = kind
        self.label = label
        self.guidance = guidance
        self.targetClipCount = targetClipCount
        self.clipDurationSeconds = clipDurationSeconds
        self.completedClipCount = completedClipCount
    }
}

public struct ShowerAlarmConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int
    public var repeatsDaily: Bool
    public var scheduledAlarmID: UUID?
    public var lastScheduledAt: String?

    public init(
        isEnabled: Bool = false,
        hour: Int = 7,
        minute: Int = 0,
        repeatsDaily: Bool = true,
        scheduledAlarmID: UUID? = nil,
        lastScheduledAt: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.repeatsDaily = repeatsDaily
        self.scheduledAlarmID = scheduledAlarmID
        self.lastScheduledAt = lastScheduledAt
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
        alarmTimeLabel: String
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
    }
}

public extension SleepTrackerAppCore {
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
                completedClipCount: counts[kind, default: 0]
            )
        }
    }

    static func showerAlarmSnapshot(
        configuration: ShowerAlarmConfiguration,
        alarmPermission: AlarmPermissionState,
        microphonePermission: AlarmPermissionState,
        classifierState: ShowerClassifierState,
        samples: [ShowerTrainingSample],
        isPlatformSupported: Bool
    ) -> ShowerAlarmSnapshot {
        let requirements = showerSampleRequirements(samples: samples)
        let totalRequiredClips = requirements.reduce(0) { $0 + $1.targetClipCount }
        let totalRequiredSeconds = requirements.reduce(0) { $0 + ($1.targetClipCount * $1.clipDurationSeconds) }
        let collectedClipCount = samples.count
        let collectedSeconds = samples.reduce(0) { $0 + $1.durationSeconds }
        let alarmTimeLabel = String(format: "%02d:%02d", configuration.hour, configuration.minute)

        if !isPlatformSupported {
            return ShowerAlarmSnapshot(
                level: .unavailable,
                title: "Shower alarm unavailable",
                summary: "This feature needs iOS 26 or later because AlarmKit is not available on this device.",
                nextActionTitle: "Use iOS 26 or later",
                blockers: ["AlarmKit is unavailable on this OS version."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel
            )
        }

        if alarmPermission != .authorized {
            return ShowerAlarmSnapshot(
                level: .needsAlarmAccess,
                title: "Allow app alarms first",
                summary: "The app cannot schedule a true wake-up alarm until AlarmKit access is granted.",
                nextActionTitle: "Allow alarms",
                blockers: ["Alarm permission is still missing."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel
            )
        }

        if microphonePermission != .authorized {
            return ShowerAlarmSnapshot(
                level: .needsMicrophoneAccess,
                title: "Allow the microphone",
                summary: "Shower confirmation depends on local audio listening, so microphone access is required.",
                nextActionTitle: "Allow microphone",
                blockers: ["Microphone permission is still missing."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel
            )
        }

        if let incompleteRequirement = requirements.first(where: { !$0.isComplete }) {
            let remainingClips = requirements.reduce(0) { $0 + $1.remainingClipCount }
            return ShowerAlarmSnapshot(
                level: .needsSamples,
                title: "Build the shower dataset",
                summary: "Record \(remainingClips) more clips so the app can learn your bathroom soundscape.",
                nextActionTitle: "Record training samples",
                blockers: ["\(incompleteRequirement.label) still needs \(incompleteRequirement.remainingClipCount) more clips."],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel
            )
        }

        if classifierState != .ready {
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
                alarmTimeLabel: alarmTimeLabel
            )
        }

        if configuration.isEnabled, configuration.scheduledAlarmID != nil {
            return ShowerAlarmSnapshot(
                level: .armed,
                title: "Shower alarm armed",
                summary: "Your \(alarmTimeLabel) alarm is scheduled. The remaining job is proving the shower detector on-device.",
                nextActionTitle: "Alarm armed",
                blockers: [],
                sampleRequirements: requirements,
                totalRequiredClips: totalRequiredClips,
                totalRequiredSeconds: totalRequiredSeconds,
                collectedClipCount: collectedClipCount,
                collectedSeconds: collectedSeconds,
                alarmTimeLabel: alarmTimeLabel
            )
        }

        return ShowerAlarmSnapshot(
            level: .readyToArm,
            title: "Shower alarm ready",
            summary: "Permissions, samples, and classifier are ready. The next step is arming the \(alarmTimeLabel) alarm on-device.",
            nextActionTitle: "Arm \(alarmTimeLabel) alarm",
            blockers: [],
            sampleRequirements: requirements,
            totalRequiredClips: totalRequiredClips,
            totalRequiredSeconds: totalRequiredSeconds,
            collectedClipCount: collectedClipCount,
            collectedSeconds: collectedSeconds,
            alarmTimeLabel: alarmTimeLabel
        )
    }
}
