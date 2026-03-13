import AVFAudio
import Combine
import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

@MainActor
final class AlarmFeatureModel: ObservableObject {
    @Published var configuration = ShowerAlarmConfiguration()
    @Published var samples: [ShowerTrainingSample] = []
    @Published var alarmPermission: AlarmPermissionState = .unknown
    @Published var microphonePermission: AlarmPermissionState = .unknown
    @Published var classifierState: ShowerClassifierState = .missing
    @Published var isLoading = true
    @Published var isWorking = false
    @Published var recordingKind: ShowerSampleKind?
    @Published var statusMessage = "Alarm data stays local on this iPhone."
    @Published var errorMessage: String?

    private let store: AlarmFeatureStore
    private let scheduler: any AlarmScheduling
    private let recorder: any ShowerSampleRecording
    private let isoFormatter = ISO8601DateFormatter()

    init() {
        self.store = AlarmFeatureStore()
        self.scheduler = AlarmSchedulingFactory.makeScheduler()
        self.recorder = ShowerSampleRecorder()
    }

    var snapshot: ShowerAlarmSnapshot {
        SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: configuration,
            alarmPermission: alarmPermission,
            microphonePermission: microphonePermission,
            classifierState: classifierState,
            samples: samples,
            isPlatformSupported: scheduler.isSupported
        )
    }

    var alarmTimeDate: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = configuration.hour
        components.minute = configuration.minute
        return calendar.date(from: components) ?? Date()
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let stored = try await store.load()
            configuration = stored.configuration
            samples = stored.samples
        } catch {
            errorMessage = error.localizedDescription
        }

        await refreshStatus()
    }

    func refreshStatus() async {
        alarmPermission = await scheduler.authorizationState()
        microphonePermission = recorder.permissionState()
        classifierState = await store.classifierState()
    }

    func updateAlarmTime(_ date: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        configuration.hour = components.hour ?? configuration.hour
        configuration.minute = components.minute ?? configuration.minute

        if configuration.scheduledAlarmID != nil {
            await clearScheduledAlarm(cancelWithSystem: true)
            statusMessage = "Alarm time updated. Re-arm to schedule the new time."
        }

        await persist()
    }

    func setEnabled(_ enabled: Bool) async {
        configuration.isEnabled = enabled

        if !enabled {
            await clearScheduledAlarm(cancelWithSystem: true)
            statusMessage = "Alarm disabled."
        }

        await persist()
    }

    func requestAlarmAccess() async {
        isWorking = true
        defer { isWorking = false }

        do {
            alarmPermission = try await scheduler.requestAuthorization()
            errorMessage = nil
            statusMessage = alarmPermission == .authorized ? "Alarm access granted." : "Alarm access is still unavailable."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestMicrophoneAccess() async {
        isWorking = true
        defer { isWorking = false }

        microphonePermission = await recorder.requestPermission()
        errorMessage = nil
        statusMessage = microphonePermission == .authorized ? "Microphone access granted." : "Microphone access was denied."
    }

    func armAlarm() async {
        guard snapshot.level == .readyToArm || snapshot.level == .armed else {
            errorMessage = "Finish permissions, samples, and classifier setup before arming the shower alarm."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            await clearScheduledAlarm(cancelWithSystem: true)
            let scheduledID = try await scheduler.scheduleNextAlarm(hour: configuration.hour, minute: configuration.minute)
            configuration.isEnabled = true
            configuration.scheduledAlarmID = scheduledID
            configuration.lastScheduledAt = isoFormatter.string(from: Date())
            try await store.save(configuration: configuration, samples: samples)
            errorMessage = nil
            statusMessage = "Alarm armed for \(snapshot.alarmTimeLabel)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disarmAlarm() async {
        isWorking = true
        defer { isWorking = false }

        await clearScheduledAlarm(cancelWithSystem: true)
        configuration.isEnabled = false
        await persist()
        errorMessage = nil
        statusMessage = "Alarm disarmed."
    }

    func recordSample(kind: ShowerSampleKind) async {
        guard recordingKind == nil else {
            errorMessage = "A sample is already being recorded."
            return
        }

        isWorking = true
        recordingKind = kind
        defer {
            isWorking = false
            recordingKind = nil
        }

        do {
            if microphonePermission != .authorized {
                microphonePermission = await recorder.requestPermission()
            }

            guard microphonePermission == .authorized else {
                errorMessage = "Microphone access is required to record training samples."
                return
            }

            let directory = try await store.sampleDirectory(for: kind)
            let sample = try await recorder.recordSample(
                kind: kind,
                durationSeconds: kind.clipDurationSeconds,
                in: directory
            )
            samples.append(sample)
            try await store.save(configuration: configuration, samples: samples)
            errorMessage = nil
            statusMessage = "\(kind.label) recorded. \(samples.count)/\(snapshot.totalRequiredClips) clips collected."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist() async {
        do {
            try await store.save(configuration: configuration, samples: samples)
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearScheduledAlarm(cancelWithSystem: Bool) async {
        if cancelWithSystem, let scheduledAlarmID = configuration.scheduledAlarmID {
            do {
                try await scheduler.cancel(alarmID: scheduledAlarmID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        configuration.scheduledAlarmID = nil
        configuration.lastScheduledAt = nil
    }
}

struct StoredAlarmFeatureState: Codable, Sendable {
    var configuration: ShowerAlarmConfiguration
    var samples: [ShowerTrainingSample]
}

actor AlarmFeatureStore {
    func load() throws -> StoredAlarmFeatureState {
        let url = try stateURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return StoredAlarmFeatureState(configuration: ShowerAlarmConfiguration(), samples: [])
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StoredAlarmFeatureState.self, from: data)
    }

    func save(configuration: ShowerAlarmConfiguration, samples: [ShowerTrainingSample]) throws {
        let url = try stateURL()
        let state = StoredAlarmFeatureState(configuration: configuration, samples: samples)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }

    func sampleDirectory(for kind: ShowerSampleKind) throws -> URL {
        let directory = try baseDirectory()
            .appendingPathComponent("Samples", isDirectory: true)
            .appendingPathComponent(kind.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func classifierState() -> ShowerClassifierState {
        do {
            let directory = try baseDirectory()
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("ShowerSoundClassifier.mlmodelc", isDirectory: true)
            return FileManager.default.fileExists(atPath: directory.path) ? .ready : .missing
        } catch {
            return .missing
        }
    }

    private func stateURL() throws -> URL {
        let directory = try baseDirectory()
        return directory.appendingPathComponent("alarm_state.json")
    }

    private func baseDirectory() throws -> URL {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("SleepTrackerIOS/AlarmFeature", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private enum AlarmFeatureError: LocalizedError {
    case unsupportedPlatform
    case alarmPermissionDenied
    case recordingInProgress
    case recordingStartFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "This device cannot use the app-owned alarm prototype."
        case .alarmPermissionDenied:
            return "Alarm permission is required before the app can schedule a real alarm."
        case .recordingInProgress:
            return "A training sample is already being recorded."
        case .recordingStartFailed:
            return "The training sample could not start recording."
        }
    }
}

protocol AlarmScheduling: Sendable {
    var isSupported: Bool { get }
    func authorizationState() async -> AlarmPermissionState
    func requestAuthorization() async throws -> AlarmPermissionState
    func scheduleNextAlarm(hour: Int, minute: Int) async throws -> UUID
    func cancel(alarmID: UUID) async throws
}

private enum AlarmSchedulingFactory {
    @MainActor
    static func makeScheduler() -> any AlarmScheduling {
        if #available(iOS 26.0, *) {
            return AlarmKitScheduler()
        }

        return UnsupportedAlarmScheduler()
    }
}

private struct UnsupportedAlarmScheduler: AlarmScheduling {
    let isSupported = false

    func authorizationState() async -> AlarmPermissionState { .unavailable }

    func requestAuthorization() async throws -> AlarmPermissionState {
        throw AlarmFeatureError.unsupportedPlatform
    }

    func scheduleNextAlarm(hour: Int, minute: Int) async throws -> UUID {
        throw AlarmFeatureError.unsupportedPlatform
    }

    func cancel(alarmID: UUID) async throws {}
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct AlarmKitScheduler: AlarmScheduling {
    var isSupported: Bool { true }

    func authorizationState() async -> AlarmPermissionState {
        mapAuthorization(AlarmManager.shared.authorizationState)
    }

    func requestAuthorization() async throws -> AlarmPermissionState {
        mapAuthorization(try await AlarmManager.shared.requestAuthorization())
    }

    func scheduleNextAlarm(hour: Int, minute: Int) async throws -> UUID {
        guard AlarmManager.shared.authorizationState == .authorized else {
            throw AlarmFeatureError.alarmPermissionDenied
        }

        let alarmID = UUID()
        let scheduleDate = nextOccurrence(hour: hour, minute: minute)
        let presentation = AlarmPresentation(
            alert: alertPresentation()
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: ShowerAlarmMetadata(feature: "shower_alarm"),
            tintColor: .orange
        )
        let configuration = AlarmManager.AlarmConfiguration<ShowerAlarmMetadata>.alarm(
            schedule: .fixed(scheduleDate),
            attributes: attributes,
            sound: .default
        )

        _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
        return alarmID
    }

    func cancel(alarmID: UUID) async throws {
        try AlarmManager.shared.cancel(id: alarmID)
    }

    private func mapAuthorization(_ state: AlarmManager.AuthorizationState) -> AlarmPermissionState {
        switch state {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private func nextOccurrence(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = DateComponents(hour: hour, minute: minute)
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? now.addingTimeInterval(60)
    }

    private func alertPresentation() -> AlarmPresentation.Alert {
        if #available(iOS 26.1, *) {
            return .init(title: "Shower Alarm")
        }

        return .init(
            title: "Shower Alarm",
            stopButton: AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.fill"
            )
        )
    }
}

@available(iOS 26.0, *)
private struct ShowerAlarmMetadata: AlarmMetadata {
    var feature: String
}
#endif

protocol ShowerSampleRecording: Sendable {
    func permissionState() -> AlarmPermissionState
    func requestPermission() async -> AlarmPermissionState
    func recordSample(kind: ShowerSampleKind, durationSeconds: Int, in directory: URL) async throws -> ShowerTrainingSample
}

private final class ShowerSampleRecorder: NSObject, ShowerSampleRecording, AVAudioRecorderDelegate, @unchecked Sendable {
    private var activeRecorder: AVAudioRecorder?
    private var activeContinuation: CheckedContinuation<Void, Error>?

    func permissionState() -> AlarmPermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .authorized
        case .denied:
            return .denied
        case .undetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    func requestPermission() async -> AlarmPermissionState {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted ? .authorized : .denied)
            }
        }
    }

    func recordSample(
        kind: ShowerSampleKind,
        durationSeconds: Int,
        in directory: URL
    ) async throws -> ShowerTrainingSample {
        guard activeRecorder == nil else {
            throw AlarmFeatureError.recordingInProgress
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fileName = "\(kind.rawValue)-\(timestamp).caf"
        let fileURL = directory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = false
        guard recorder.prepareToRecord() else {
            throw AlarmFeatureError.recordingStartFailed
        }

        activeRecorder = recorder

        try await withCheckedThrowingContinuation { continuation in
            self.activeContinuation = continuation
            if !recorder.record(forDuration: TimeInterval(durationSeconds)) {
                self.finishRecording(result: .failure(AlarmFeatureError.recordingStartFailed))
            }
        }

        try session.setActive(false)

        return ShowerTrainingSample(
            kind: kind,
            durationSeconds: durationSeconds,
            createdAt: formatter.string(from: Date()),
            fileName: fileName
        )
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            finishRecording(result: .success(()))
        } else {
            finishRecording(result: .failure(AlarmFeatureError.recordingStartFailed))
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        finishRecording(result: .failure(error ?? AlarmFeatureError.recordingStartFailed))
    }

    private func finishRecording(result: Result<Void, Error>) {
        activeRecorder?.stop()
        activeRecorder = nil

        switch result {
        case .success:
            activeContinuation?.resume()
        case .failure(let error):
            activeContinuation?.resume(throwing: error)
        }

        activeContinuation = nil
    }
}
