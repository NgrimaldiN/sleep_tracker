import AVFAudio
import Combine
import Foundation
import SwiftUI
import UserNotifications
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
    @Published var liveDetectionState = LiveShowerDetectionState()
    @Published var handsFreeState = HandsFreeWakeWindowState()
    @Published var missionState = ShowerMissionState()
    @Published var isLoading = true
    @Published var isWorking = false
    @Published var recordingKind: ShowerSampleKind?
    @Published var statusMessage = "Wake-up mission data stays local on this iPhone."
    @Published var errorMessage: String?

    private let store: AlarmFeatureStore
    private let scheduler: any AlarmScheduling
    private let recorder: any ShowerSampleRecording
    private let liveDetector: any LiveShowerListening
    private let handsFreeMonitor: any HandsFreeShowerMonitoring
    private let wakeAudioController: WakeAudioController
    private let systemVolumeController: SystemVolumeController
    private let isoFormatter = ISO8601DateFormatter()
    private var missionRestartTask: Task<Void, Never>?
    private var currentScenePhase: ScenePhase = .active
    private var missionListeningGeneration = 0

    init() {
        self.store = AlarmFeatureStore()
        self.scheduler = AlarmSchedulingFactory.makeScheduler()
        self.recorder = ShowerSampleRecorder()
        self.liveDetector = LiveShowerDetector()
        self.handsFreeMonitor = HandsFreeShowerMonitor()
        self.wakeAudioController = WakeAudioController()
        self.systemVolumeController = SystemVolumeController.shared
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

    var quickPresetTimes: [AlarmQuickPreset] {
        [
            AlarmQuickPreset(label: "06:30", hour: 6, minute: 30),
            AlarmQuickPreset(label: "07:00", hour: 7, minute: 0),
            AlarmQuickPreset(label: "07:30", hour: 7, minute: 30),
            AlarmQuickPreset(label: "08:00", hour: 8, minute: 0),
        ]
    }

    var scheduleDescriptor: ShowerAlarmScheduleDescriptor {
        SleepTrackerAppCore.showerAlarmScheduleDescriptor(
            hour: configuration.hour,
            minute: configuration.minute
        )
    }

    var alarmListCardDescriptor: ShowerAlarmListCardDescriptor {
        SleepTrackerAppCore.showerAlarmListCardDescriptor(
            configuration: configuration
        )
    }

    var wakeWindowDescriptor: ShowerWakeWindowDescriptor? {
        SleepTrackerAppCore.showerWakeWindowDescriptor(
            configuration: configuration
        )
    }

    var missionDescriptor: ShowerMissionDescriptor? {
        SleepTrackerAppCore.showerMissionDescriptor(
            configuration: configuration
        )
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
        await presentMissionIfNeeded()
        await syncWakeAudio()
        await syncHandsFreeMonitoring()
    }

    func refreshStatus() async {
        alarmPermission = await scheduler.authorizationState()
        microphonePermission = recorder.permissionState()
        classifierState = await store.classifierState()
    }

    func handleScenePhase(_ scenePhase: ScenePhase) async {
        currentScenePhase = scenePhase

        switch scenePhase {
        case .active:
            await refreshStatus()
            await presentMissionIfNeeded()
            await syncWakeAudio()
            await syncHandsFreeMonitoring()
        case .inactive, .background:
            cancelMissionListeningRestart()
            if SleepTrackerAppCore.shouldResumeWakeAudioForBackgroundMission(
                isMissionPresented: missionState.isPresented,
                hasConfirmedShower: missionState.hasConfirmedShower
            ) {
                await liveDetector.stop()
                missionState.isListening = false
                missionState.statusLine = "Return to the app"
                missionState.detailLine = "Open the app again, then press and hold to continue shower confirmation."
                do {
                    try wakeAudioController.resumeIfNeeded()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        @unknown default:
            break
        }
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
        await syncWakeAudio()
        await syncHandsFreeMonitoring()
    }

    func applyQuickPreset(_ preset: AlarmQuickPreset) async {
        configuration.hour = preset.hour
        configuration.minute = preset.minute

        if configuration.scheduledAlarmID != nil {
            await clearScheduledAlarm(cancelWithSystem: true)
            statusMessage = "Alarm preset applied. Re-arm to schedule the new time."
        }

        await persist()
        await syncWakeAudio()
        await syncHandsFreeMonitoring()
    }

    func setEnabled(_ enabled: Bool) async {
        configuration.isEnabled = enabled

        if !enabled {
            await clearScheduledAlarm(cancelWithSystem: true)
            statusMessage = "Alarm disabled."
        }

        await persist()
        await syncWakeAudio()
        await syncHandsFreeMonitoring()
    }

    func setHandsFreeEnabled(_ enabled: Bool) async {
        configuration.experimentalHandsFreeEnabled = enabled
        await persist()
        await syncWakeAudio()
        await syncHandsFreeMonitoring()

        if enabled {
            statusMessage = "Hands-free stop will keep listening until 5 minutes after the wake time."
        } else {
            statusMessage = "Hands-free stop disabled."
        }
    }

    func setAlarmArmed(_ armed: Bool) async {
        if armed {
            await armAlarm()
        } else {
            await disarmAlarm()
        }
    }

    func armTestAlarmSoon() async {
        let calendar = Calendar.current
        let testDate = calendar.date(byAdding: .minute, value: 2, to: Date()) ?? Date().addingTimeInterval(120)
        let components = calendar.dateComponents([.hour, .minute], from: testDate)
        configuration.hour = components.hour ?? configuration.hour
        configuration.minute = components.minute ?? configuration.minute
        configuration.experimentalHandsFreeEnabled = false
        await persist()
        statusMessage = "Preparing a wake notification test for \(String(format: "%02d:%02d", configuration.hour, configuration.minute))."
        await armAlarm()
    }

    func requestAlarmAccess() async {
        isWorking = true
        defer { isWorking = false }

        do {
            alarmPermission = try await scheduler.requestAuthorization()
            errorMessage = nil
            statusMessage = alarmPermission == .authorized ? "Wake notification access granted." : "Wake notification access is still unavailable."
        } catch {
            errorMessage = error.localizedDescription
        }

        await syncHandsFreeMonitoring()
    }

    func requestMicrophoneAccess() async {
        isWorking = true
        defer { isWorking = false }

        microphonePermission = await recorder.requestPermission()
        errorMessage = nil
        statusMessage = microphonePermission == .authorized ? "Microphone access granted." : "Microphone access was denied."
        await syncHandsFreeMonitoring()
    }

    func armAlarm() async {
        guard snapshot.level == .readyToArm || snapshot.level == .armed else {
            errorMessage = "Finish permissions, samples, and classifier setup before arming the wake mission."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            await clearScheduledAlarm(cancelWithSystem: true)
            let scheduledAlarm = try await scheduler.scheduleNextAlarm(
                hour: configuration.hour,
                minute: configuration.minute
            )
            configuration.isEnabled = true
            configuration.scheduledAlarmID = scheduledAlarm.id
            configuration.scheduledForISO8601 = isoFormatter.string(from: scheduledAlarm.scheduledFor)
            configuration.lastScheduledAt = isoFormatter.string(from: Date())
            try await store.save(configuration: configuration, samples: samples)
            errorMessage = nil
            let descriptor = SleepTrackerAppCore.showerAlarmScheduleDescriptor(
                hour: configuration.hour,
                minute: configuration.minute,
                now: Date()
            )
            statusMessage = "Wake mission armed for \(descriptor.dayLabel) at \(descriptor.timeLabel). Leave the app in the background overnight."
            await syncWakeAudio()
            await syncHandsFreeMonitoring()
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
        await syncWakeAudio()
        await syncHandsFreeMonitoring()
        errorMessage = nil
        statusMessage = "Wake notifications cancelled."
    }

    func startListeningTest() async {
        guard !liveDetectionState.isListening else { return }

        guard !handsFreeState.isRunning else {
            errorMessage = "Hands-free listening is already running for the armed wake mission."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            if microphonePermission != .authorized {
                microphonePermission = await recorder.requestPermission()
            }

            guard microphonePermission == .authorized else {
                errorMessage = "Microphone access is required to test live shower detection."
                return
            }

            guard classifierState == .ready else {
                errorMessage = "Train or bundle a detector profile before starting live shower detection."
                return
            }

            guard let profile = try await store.loadDetectorProfile() else {
                errorMessage = "The shower detector profile could not be loaded from the device."
                return
            }

            liveDetectionState = LiveShowerDetectionState(
                isListening: true,
                hasConfirmedShower: false,
                latestPrediction: nil,
                statusLine: "Listening for the shower",
                detailLine: "Start the real shower with the phone in the bathroom."
            )

            try await liveDetector.start(profile: profile) { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.applyLiveDetectorUpdate(update)
                }
            }

            errorMessage = nil
            statusMessage = "Live shower detection is running."
        } catch {
            liveDetectionState = LiveShowerDetectionState(
                isListening: false,
                hasConfirmedShower: false,
                latestPrediction: nil,
                statusLine: "Live detector failed",
                detailLine: error.localizedDescription
            )
            statusMessage = "Live shower detection could not start."
            errorMessage = error.localizedDescription
        }
    }

    func stopListeningTest() async {
        isWorking = true
        defer { isWorking = false }

        await liveDetector.stop()
        liveDetectionState = LiveShowerDetectionState(
            isListening: false,
            hasConfirmedShower: false,
            latestPrediction: liveDetectionState.latestPrediction,
            statusLine: "Live detector stopped",
            detailLine: "Start listening again to test the shower in real time."
        )
        errorMessage = nil
        statusMessage = "Live shower detection stopped."
    }

    func beginMissionVerificationHold() async {
        guard missionState.isPresented,
              !missionState.isListening,
              !missionState.hasConfirmedShower else {
            return
        }

        missionState.statusLine = "Preparing verification"
        missionState.detailLine = "Keep holding while the app starts listening for the shower."
        wakeAudioController.suspendForMissionVerification()
        await startMissionListening(requestedGeneration: nextMissionListeningGeneration())
    }

    func endMissionVerificationHold() async {
        guard missionState.isPresented,
              missionState.isListening,
              !missionState.hasConfirmedShower else {
            return
        }

        cancelMissionListeningRestart()
        await liveDetector.stop()
        missionState.isListening = false
        missionState.statusLine = "Hold to verify shower"
        missionState.detailLine = "Press and hold the button, then turn on the shower while the alarm is muted."
        await syncWakeAudio()
    }

    func ensureWakeAudioForPresentedMission() async {
        guard SleepTrackerAppCore.shouldRefreshWakeAudioOnMissionPresentation(
            isMissionPresented: missionState.isPresented,
            isMissionListening: missionState.isListening,
            hasConfirmedShower: missionState.hasConfirmedShower
        ) else {
            return
        }

        await syncWakeAudio()
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
            await syncWakeAudio()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyLiveDetectorUpdate(_ update: LiveShowerDetectorUpdate) {
        liveDetectionState.latestPrediction = update.prediction

        if update.confirmed {
            liveDetectionState.isListening = false
            liveDetectionState.hasConfirmedShower = true
            liveDetectionState.statusLine = "Shower confirmed"
            liveDetectionState.detailLine = "The detector heard your shower. This is the signal the alarm flow will rely on."
            statusMessage = "Shower confirmed during the live detector test."

            Task {
                await liveDetector.stop()
            }
            return
        }

        let confidence = String(format: "%.2f", update.prediction.margin)
        if update.prediction.label == .showerOn {
            liveDetectionState.statusLine = "Possible shower sound"
            liveDetectionState.detailLine = "The detector is leaning shower with margin \(confidence). Keep the phone near the running shower."
        } else {
            liveDetectionState.statusLine = "Background noise"
            liveDetectionState.detailLine = "Current audio still looks like non-shower bathroom noise."
        }
    }

    private func presentMissionIfNeeded() async {
        defer {
            WakeNotificationDelegate.shared.updateMissionPresentation(
                isPresented: missionState.isPresented
            )
        }

        guard let descriptor = missionDescriptor else {
            if missionState.isPresented {
                cancelMissionListeningRestart()
                missionState = ShowerMissionState()
            }
            return
        }

            guard descriptor.shouldPresentMission else {
            if descriptor.phase == .expired, missionState.isPresented {
                cancelMissionListeningRestart()
                missionState = ShowerMissionState()
            }
            return
        }

        if !missionState.isPresented {
            missionState = ShowerMissionState(
                isPresented: true,
                isListening: false,
                hasConfirmedShower: false,
                latestPrediction: nil,
                statusLine: "Wake-up mission",
                detailLine: "Press and hold the button when you are ready to start the real shower. The alarm keeps sounding until then.",
                scheduledTimeLabel: descriptor.scheduledTimeLabel
            )
        } else {
            if missionState.hasConfirmedShower {
                missionState.detailLine = descriptor.summary
            } else if !missionState.isListening {
                missionState.detailLine = "Press and hold the button when you are ready to start the real shower. The alarm keeps sounding until then."
            }
        }
    }

    private func startMissionListening(requestedGeneration: Int) async {
        guard shouldProceedWithMissionListening(requestedGeneration: requestedGeneration) else {
            return
        }

        func abortMissionListening(
            statusLine: String,
            detailLine: String,
            errorMessage: String? = nil
        ) async {
            missionState.isListening = false
            missionState.statusLine = statusLine
            missionState.detailLine = detailLine
            self.errorMessage = errorMessage
            await syncWakeAudio()
        }

        do {
            if microphonePermission != .authorized {
                microphonePermission = await recorder.requestPermission()
            }

            guard shouldProceedWithMissionListening(requestedGeneration: requestedGeneration) else {
                return
            }

            guard microphonePermission == .authorized else {
                await abortMissionListening(
                    statusLine: "Microphone needed",
                    detailLine: "Microphone access is required to hear the shower.",
                    errorMessage: "Microphone access is required to run the shower mission."
                )
                return
            }

            guard classifierState == .ready else {
                await abortMissionListening(
                    statusLine: "Detector missing",
                    detailLine: "The shower detector profile is not ready on this device.",
                    errorMessage: "The shower detector profile is not ready on this device."
                )
                return
            }

            guard let profile = try await store.loadDetectorProfile() else {
                await abortMissionListening(
                    statusLine: "Detector missing",
                    detailLine: "The shower detector profile could not be loaded.",
                    errorMessage: "The shower detector profile could not be loaded from the device."
                )
                return
            }

            guard shouldProceedWithMissionListening(requestedGeneration: requestedGeneration) else {
                return
            }

            if handsFreeState.isRunning {
                await handsFreeMonitor.stop()
                handsFreeState = HandsFreeWakeWindowState(
                    phase: .disabled,
                    isRunning: false,
                    latestPrediction: handsFreeState.latestPrediction,
                    statusLine: "Mission took over",
                    detailLine: "Foreground shower confirmation took over the microphone."
                )
            }

            if liveDetectionState.isListening {
                await liveDetector.stop()
                liveDetectionState = LiveShowerDetectionState()
            }

            missionState.isListening = true
            missionState.statusLine = "Listening for your shower"
            missionState.detailLine = "Keep holding while you turn on the shower. The alarm is muted only during this hold."
            errorMessage = nil

            wakeAudioController.suspendForMissionVerification()
            try? await Task.sleep(for: .milliseconds(180))

            try await liveDetector.start(profile: profile) { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.applyMissionDetectorUpdate(update)
                }
            }
        } catch {
            await abortMissionListening(
                statusLine: "Mission failed to start",
                detailLine: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func applyMissionDetectorUpdate(_ update: LiveShowerDetectorUpdate) {
        missionState.latestPrediction = update.prediction

        if update.confirmed {
            missionState.isListening = false
            missionState.hasConfirmedShower = true
            missionState.statusLine = "Shower confirmed"
            missionState.detailLine = "Wake-up complete. The shower mission succeeded."
            statusMessage = "Shower confirmed after the wake notification."

            Task {
                await completeMissionSuccess()
            }
            return
        }

        let confidence = String(format: "%.2f", update.prediction.margin)
        if update.prediction.label == .showerOn {
            missionState.statusLine = "Almost there"
            missionState.detailLine = "The detector is leaning shower with margin \(confidence). Keep the phone close to the running shower."
        } else {
            missionState.statusLine = "Listening..."
            missionState.detailLine = "No shower yet. Turn it on and keep the phone in the bathroom."
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
        configuration.scheduledForISO8601 = nil
        configuration.lastScheduledAt = nil
    }

    private func syncHandsFreeMonitoring() async {
        guard configuration.experimentalHandsFreeEnabled else {
            await handsFreeMonitor.stop()
            handsFreeState = HandsFreeWakeWindowState(
                phase: .disabled,
                isRunning: false,
                statusLine: "Hands-free stop off",
                detailLine: "Turn this on to keep the microphone ready until 5 minutes after the wake time."
            )
            return
        }

        guard configuration.isEnabled,
              configuration.scheduledAlarmID != nil,
              let descriptor = wakeWindowDescriptor,
              let scheduledFor = configuration.scheduledForISO8601,
              let scheduledAt = isoFormatter.date(from: scheduledFor) else {
            await handsFreeMonitor.stop()
            handsFreeState = HandsFreeWakeWindowState(
                phase: .pending,
                isRunning: false,
                statusLine: "Hands-free idle",
                detailLine: "Arm the wake mission to keep listening through the five-minute shower window."
            )
            return
        }

        handsFreeState = HandsFreeWakeWindowState(
            phase: descriptor.phase,
            isRunning: descriptor.shouldKeepListening,
            latestPrediction: handsFreeState.latestPrediction,
            statusLine: descriptor.phase == .active ? "Hands-free window active" : "Hands-free window armed",
            detailLine: descriptor.summary
        )

        guard microphonePermission == .authorized, classifierState == .ready else {
            return
        }

        if !descriptor.shouldKeepListening {
            await handsFreeMonitor.stop()
            return
        }

        do {
            guard let profile = try await store.loadDetectorProfile() else {
                return
            }

            if liveDetectionState.isListening {
                await liveDetector.stop()
                liveDetectionState = LiveShowerDetectionState(
                    isListening: false,
                    hasConfirmedShower: false,
                    latestPrediction: liveDetectionState.latestPrediction,
                    statusLine: "Live detector stopped",
                    detailLine: "Hands-free monitoring took over the microphone for the armed wake mission."
                )
            }

            try await handsFreeMonitor.start(
                profile: profile,
                scheduledAt: scheduledAt,
                windowMinutes: configuration.handsFreeWindowMinutes
            ) { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.applyHandsFreeUpdate(update)
                }
            }
            errorMessage = nil
        } catch {
            handsFreeState = HandsFreeWakeWindowState(
                phase: descriptor.phase,
                isRunning: false,
                latestPrediction: nil,
                statusLine: "Hands-free monitor failed",
                detailLine: error.localizedDescription
            )
            errorMessage = error.localizedDescription
        }
    }

    private func applyHandsFreeUpdate(_ update: HandsFreeShowerMonitorUpdate) {
        handsFreeState.phase = update.phase
        handsFreeState.isRunning = update.phase == .pending || update.phase == .active
        handsFreeState.latestPrediction = update.latestPrediction ?? handsFreeState.latestPrediction
        handsFreeState.statusLine = update.confirmed
            ? "Shower confirmed"
            : (update.phase == .active ? "Hands-free window active" : "Hands-free window armed")
        handsFreeState.detailLine = update.detailLine

        if update.confirmed {
            Task {
                await completeHandsFreeAlarmStop()
            }
            return
        }

        if update.phase == .expired {
            statusMessage = "The five-minute hands-free shower window ended without confirmation."
        }
    }

    private func completeHandsFreeAlarmStop() async {
        if let scheduledAlarmID = configuration.scheduledAlarmID {
            do {
                try await scheduler.cancel(alarmID: scheduledAlarmID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        await handsFreeMonitor.stop()
        await clearScheduledAlarm(cancelWithSystem: true)
        configuration.isEnabled = false
        await persist()
        statusMessage = "Shower confirmed. The app cancelled the remaining wake notifications automatically."
    }

    private func completeMissionSuccess() async {
        cancelMissionListeningRestart()
        await liveDetector.stop()
        try? await Task.sleep(for: .milliseconds(700))
        await clearScheduledAlarm(cancelWithSystem: true)
        configuration.isEnabled = false
        await persist()
        missionState = ShowerMissionState()
        WakeNotificationDelegate.shared.updateMissionPresentation(isPresented: false)
        statusMessage = "Shower confirmed. Wake-up complete."
    }

    private func syncWakeAudio() async {
        let isAlarmArmed = configuration.isEnabled && configuration.scheduledAlarmID != nil
        let keepMissionToneAudible = SleepTrackerAppCore.shouldKeepWakeToneAudibleDuringMission(
            isMissionPresented: missionState.isPresented,
            isMissionListening: missionState.isListening,
            hasConfirmedShower: missionState.hasConfirmedShower
        )
        systemVolumeController.updateWakeState(
            isAlarmArmed: isAlarmArmed,
            isMissionPresented: keepMissionToneAudible
        )

        guard configuration.isEnabled,
              configuration.scheduledAlarmID != nil,
              let raw = configuration.scheduledForISO8601,
              let scheduledAt = isoFormatter.date(from: raw) else {
            wakeAudioController.stop()
            return
        }

        if missionState.isPresented && missionState.isListening && !missionState.hasConfirmedShower {
            wakeAudioController.suspendForMissionVerification()
            return
        }

        if keepMissionToneAudible {
            do {
                if SleepTrackerAppCore.shouldWakeAudioReconfigureSession(
                    isMissionPresented: missionState.isPresented,
                    isMissionListening: missionState.isListening,
                    hasConfirmedShower: missionState.hasConfirmedShower
                ) {
                    try wakeAudioController.enterMissionMode()
                } else {
                    try wakeAudioController.enterMissionModeWithoutSessionReconfigure()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        do {
            try wakeAudioController.arm(scheduledAt: scheduledAt)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleMissionListeningRestart() {
        cancelMissionListeningRestart()
        let requestedGeneration = nextMissionListeningGeneration()
        missionRestartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self else { return }
            await self.startMissionListening(requestedGeneration: requestedGeneration)
        }
    }

    private func cancelMissionListeningRestart() {
        missionRestartTask?.cancel()
        missionRestartTask = nil
        missionListeningGeneration += 1
    }

    private func nextMissionListeningGeneration() -> Int {
        missionListeningGeneration += 1
        return missionListeningGeneration
    }

    private func shouldProceedWithMissionListening(requestedGeneration: Int) -> Bool {
        SleepTrackerAppCore.shouldStartShowerMissionListening(
            requestedGeneration: requestedGeneration,
            currentGeneration: missionListeningGeneration,
            isSceneActive: currentScenePhase == .active,
            isMissionPresented: missionState.isPresented,
            isMissionListening: missionState.isListening,
            hasConfirmedShower: missionState.hasConfirmedShower
        )
    }
}

struct AlarmQuickPreset: Equatable, Identifiable {
    var label: String
    var hour: Int
    var minute: Int

    var id: String { label }
}

struct StoredAlarmFeatureState: Codable, Sendable {
    var configuration: ShowerAlarmConfiguration
    var samples: [ShowerTrainingSample]
}

struct LiveShowerDetectionState: Equatable {
    var isListening = false
    var hasConfirmedShower = false
    var latestPrediction: ShowerDetectorPrediction?
    var statusLine = "Ready to test shower detection"
    var detailLine = "Use this with the phone in the bathroom to validate the detector."
}

struct HandsFreeWakeWindowState: Equatable {
    var phase: ShowerWakeWindowPhase = .disabled
    var isRunning = false
    var latestPrediction: ShowerDetectorPrediction?
    var statusLine = "Hands-free stop off"
    var detailLine = "Turn this on to keep the microphone ready until 5 minutes after the wake time."
}

struct ShowerMissionState: Equatable {
    var isPresented = false
    var isListening = false
    var hasConfirmedShower = false
    var latestPrediction: ShowerDetectorPrediction?
    var statusLine = "Wake-up mission"
    var detailLine = "Press and hold when you are ready to start the shower. The alarm stays on until then."
    var scheduledTimeLabel = "--:--"
}

struct HandsFreeShowerMonitorUpdate: Sendable {
    var phase: ShowerWakeWindowPhase
    var latestPrediction: ShowerDetectorPrediction?
    var confirmed: Bool
    var detailLine: String
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
            let installedDirectory = try baseDirectory()
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("ShowerSoundClassifier.mlmodelc", isDirectory: true)
            if FileManager.default.fileExists(atPath: installedDirectory.path) {
                return .ready
            }

            let installedPortableProfile = try baseDirectory()
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("ShowerDetectorProfile.json", isDirectory: false)
            if FileManager.default.fileExists(atPath: installedPortableProfile.path) {
                return .ready
            }

            if let bundledDirectory = Bundle.main.url(
                forResource: "ShowerSoundClassifier",
                withExtension: "mlmodelc"
            ), FileManager.default.fileExists(atPath: bundledDirectory.path) {
                return .ready
            }

            if let bundledPortableProfile = Bundle.main.url(
                forResource: "ShowerDetectorProfile",
                withExtension: "json"
            ), FileManager.default.fileExists(atPath: bundledPortableProfile.path) {
                return .ready
            }

            return .missing
        } catch {
            return .missing
        }
    }

    func loadDetectorProfile() throws -> ShowerDetectorProfile? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let installedProfile = try baseDirectory()
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("ShowerDetectorProfile.json", isDirectory: false)
        if FileManager.default.fileExists(atPath: installedProfile.path) {
            let data = try Data(contentsOf: installedProfile)
            return try decoder.decode(ShowerDetectorProfile.self, from: data)
        }

        if let bundledProfile = Bundle.main.url(
            forResource: "ShowerDetectorProfile",
            withExtension: "json"
        ), FileManager.default.fileExists(atPath: bundledProfile.path) {
            let data = try Data(contentsOf: bundledProfile)
            return try decoder.decode(ShowerDetectorProfile.self, from: data)
        }

        return nil
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
    case handsFreeMonitoringUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "This device cannot use the wake-up mission prototype."
        case .alarmPermissionDenied:
            return "Notification permission is required before the app can schedule wake notifications."
        case .recordingInProgress:
            return "A training sample is already being recorded."
        case .recordingStartFailed:
            return "The training sample could not start recording."
        case .handsFreeMonitoringUnavailable:
            return "Hands-free shower monitoring could not start."
        }
    }
}

protocol HandsFreeShowerMonitoring: Sendable {
    func start(
        profile: ShowerDetectorProfile,
        scheduledAt: Date,
        windowMinutes: Int,
        onUpdate: @escaping @Sendable (HandsFreeShowerMonitorUpdate) -> Void
    ) async throws
    func stop() async
}

protocol AlarmScheduling: Sendable {
    var isSupported: Bool { get }
    func authorizationState() async -> AlarmPermissionState
    func requestAuthorization() async throws -> AlarmPermissionState
    func scheduleNextAlarm(hour: Int, minute: Int) async throws -> ScheduledAlarm
    func cancel(alarmID: UUID) async throws
}

struct ScheduledAlarm: Sendable {
    var id: UUID
    var scheduledFor: Date
}

private enum AlarmSchedulingFactory {
    @MainActor
    static func makeScheduler() -> any AlarmScheduling {
        NotificationScheduler()
    }
}

private struct NotificationScheduler: AlarmScheduling {
    private static let categoryIdentifier = "SHOWER_WAKE_CATEGORY"
    private static let missionWindowMinutes = 5

    var isSupported: Bool { true }

    func authorizationState() async -> AlarmPermissionState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return mapAuthorization(settings.authorizationStatus)
    }

    func requestAuthorization() async throws -> AlarmPermissionState {
        registerCategories()
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        if #available(iOS 15.0, *) {
            options.insert(.timeSensitive)
        }
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(
            options: options
        )
        return granted ? .authorized : .denied
    }

    func scheduleNextAlarm(hour: Int, minute: Int) async throws -> ScheduledAlarm {
        guard await authorizationState() == .authorized else {
            throw AlarmFeatureError.alarmPermissionDenied
        }

        registerCategories()

        let center = UNUserNotificationCenter.current()
        let alarmID = UUID()
        let scheduleDate = SleepTrackerAppCore.showerAlarmScheduleDescriptor(
            hour: hour,
            minute: minute,
            now: Date()
        ).nextOccurrence
        let cadence = SleepTrackerAppCore.wakeNotificationCadence(
            windowMinutes: Self.missionWindowMinutes
        )

        for offset in 0..<cadence.count {
            let fireDate = scheduleDate.addingTimeInterval(Double(offset) * cadence.spacingSeconds)
            let content = notificationContent(offset: offset)
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(alarmID: alarmID, offset: offset),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }

        return ScheduledAlarm(id: alarmID, scheduledFor: scheduleDate)
    }

    func cancel(alarmID: UUID) async throws {
        let identifiers = notificationIdentifiers(for: alarmID)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: alarmID)
        }
        #endif
    }

    private func mapAuthorization(_ status: UNAuthorizationStatus) -> AlarmPermissionState {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private func notificationContent(offset: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = offset == 0 ? "Shower Mission" : "Still Awake?"
        content.body = offset == 0
            ? "Wake up and open Sleep Tracker. The shower mission is ready."
            : "Open Sleep Tracker and turn on the shower with the phone in the bathroom."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("WakeMissionToneShort.wav"))
        content.categoryIdentifier = Self.categoryIdentifier
        content.threadIdentifier = "shower-wake"
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        return content
    }

    private func notificationIdentifier(alarmID: UUID, offset: Int) -> String {
        "\(alarmID.uuidString)-\(offset)"
    }

    private func notificationIdentifiers(for alarmID: UUID) -> [String] {
        let cadence = SleepTrackerAppCore.wakeNotificationCadence(
            windowMinutes: Self.missionWindowMinutes
        )
        return (0..<cadence.count).map { notificationIdentifier(alarmID: alarmID, offset: $0) }
    }

    private func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_SHOWER_MISSION",
            title: "Open App",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

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

private final class HandsFreeShowerMonitor: @unchecked Sendable, HandsFreeShowerMonitoring {
    private let detector: any LiveShowerListening
    private var tickerTask: Task<Void, Never>?
    private var scheduledAt: Date?
    private var windowMinutes = 5
    private var onUpdate: (@Sendable (HandsFreeShowerMonitorUpdate) -> Void)?
    private var hasConfirmed = false

    init(detector: any LiveShowerListening = LiveShowerDetector()) {
        self.detector = detector
    }

    func start(
        profile: ShowerDetectorProfile,
        scheduledAt: Date,
        windowMinutes: Int,
        onUpdate: @escaping @Sendable (HandsFreeShowerMonitorUpdate) -> Void
    ) async throws {
        await stop()

        self.scheduledAt = scheduledAt
        self.windowMinutes = max(1, windowMinutes)
        self.onUpdate = onUpdate
        self.hasConfirmed = false

        try await detector.start(profile: profile) { [weak self] detectorUpdate in
            self?.handleDetectorUpdate(detectorUpdate)
        }

        publish(
            phase: phase(at: Date()),
            latestPrediction: nil,
            confirmed: false
        )

        tickerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let currentPhase = self.phase(at: Date())
                self.publish(
                    phase: currentPhase,
                    latestPrediction: nil,
                    confirmed: false
                )

                if currentPhase == .expired || self.hasConfirmed {
                    break
                }

                try? await Task.sleep(for: .seconds(1))
            }

            if !self.hasConfirmed {
                await self.detector.stop()
            }
        }
    }

    func stop() async {
        tickerTask?.cancel()
        tickerTask = nil
        hasConfirmed = false
        scheduledAt = nil
        onUpdate = nil
        await detector.stop()
    }

    private func handleDetectorUpdate(_ detectorUpdate: LiveShowerDetectorUpdate) {
        guard !hasConfirmed else { return }

        let currentPhase = phase(at: Date())
        guard currentPhase == .active else { return }

        publish(
            phase: currentPhase,
            latestPrediction: detectorUpdate.prediction,
            confirmed: detectorUpdate.confirmed
        )

        if detectorUpdate.confirmed {
            hasConfirmed = true
        }
    }

    private func phase(at now: Date) -> ShowerWakeWindowPhase {
        guard let scheduledAt else { return .disabled }
        let endAt = scheduledAt.addingTimeInterval(TimeInterval(windowMinutes * 60))

        if now < scheduledAt {
            return .pending
        }

        if now <= endAt {
            return .active
        }

        return .expired
    }

    private func publish(
        phase: ShowerWakeWindowPhase,
        latestPrediction: ShowerDetectorPrediction?,
        confirmed: Bool
    ) {
        guard let onUpdate else { return }

        let detailLine: String
        switch phase {
        case .disabled:
            detailLine = "Hands-free shower stop is off."
        case .pending:
            detailLine = "The microphone is armed in the background and waiting for the wake time."
        case .active:
            detailLine = confirmed
                ? "The app heard your shower during the five-minute wake window."
                : "The five-minute wake window is open. Turn on the shower with the phone in the bathroom."
        case .expired:
            detailLine = "The five-minute hands-free wake window ended without shower confirmation."
        }

        onUpdate(HandsFreeShowerMonitorUpdate(
            phase: phase,
            latestPrediction: latestPrediction,
            confirmed: confirmed,
            detailLine: detailLine
        ))
    }
}
