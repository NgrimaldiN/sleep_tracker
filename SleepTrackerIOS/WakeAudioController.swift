import AVFAudio
import Foundation

@MainActor
final class WakeAudioController {
    private enum VolumeProfile {
        static let fullWakeTone: Float = 1.0
        static let missionWakeTone: Float = 0.6
        static let keepAlive: Float = 1.0
    }

    private enum PlaybackMode: Equatable {
        case idle
        case keepAlive
        case wakeTone
        case missionWakeTone
    }

    private var keepAlivePlayer: AVAudioPlayer?
    private var wakeTonePlayer: AVAudioPlayer?
    private var scheduledWakeTask: Task<Void, Never>?
    private var wakeTimer: Timer?
    private var scheduledAt: Date?
    private var mode: PlaybackMode = .idle

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var resumeRetryTask: Task<Void, Never>?
    private var healthCheckTask: Task<Void, Never>?

    init() {
        observeAudioSessionEvents()
    }

    // MARK: – Public API

    func arm(scheduledAt: Date) throws {
        if self.scheduledAt == scheduledAt,
           mode != .idle,
           isActivelyPlaying {
            return
        }

        stopPlayback()
        self.scheduledAt = scheduledAt

        try configureKeepAliveSession()
        try startKeepAliveLoop()
        scheduleWakeTone(for: scheduledAt)
    }

    func enterMissionMode() throws {
        guard let scheduledAt else { return }

        try configureWakeSession()

        if Date() >= scheduledAt {
            try startWakeToneLoop(
                volume: VolumeProfile.missionWakeTone,
                mode: .missionWakeTone
            )
            return
        }

        try startKeepAliveLoop()
        scheduleWakeTone(for: scheduledAt)
    }

    func enterMissionModeWithoutSessionReconfigure() throws {
        guard let scheduledAt else { return }

        if Date() >= scheduledAt {
            try startWakeToneLoop(
                volume: VolumeProfile.missionWakeTone,
                mode: .missionWakeTone
            )
            return
        }

        try startKeepAliveLoop()
        scheduleWakeTone(for: scheduledAt)
    }

    func resumeIfNeeded() throws {
        guard let scheduledAt else { return }

        try configureWakeSession()

        if Date() >= scheduledAt {
            try startWakeToneLoop(
                volume: VolumeProfile.fullWakeTone,
                mode: .wakeTone
            )
            return
        }

        try startKeepAliveLoop()
        scheduleWakeTone(for: scheduledAt)
    }

    func suspendForMissionVerification() {
        cancelHealthCheck()
        stopPlayback()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Best effort. The detector will attempt to take over the session next.
        }
        mode = .idle
    }

    func stop() {
        scheduledWakeTask?.cancel()
        scheduledWakeTask = nil
        wakeTimer?.invalidate()
        wakeTimer = nil
        resumeRetryTask?.cancel()
        resumeRetryTask = nil
        cancelHealthCheck()
        scheduledAt = nil
        stopPlayback()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Best effort for the prototype.
        }

        mode = .idle
    }

    // MARK: – Scheduling

    private func scheduleWakeTone(for scheduledAt: Date) {
        scheduledWakeTask?.cancel()
        wakeTimer?.invalidate()

        let interval = scheduledAt.timeIntervalSinceNow
        guard interval > 0 else {
            fireWakeTone()
            return
        }

        // Timer on the main RunLoop with zero tolerance — more reliable
        // than Task.sleep for long overnight waits in background mode.
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fireWakeTone()
            }
        }
        timer.tolerance = 0
        RunLoop.main.add(timer, forMode: .common)
        wakeTimer = timer
    }

    private func fireWakeTone() {
        scheduledWakeTask?.cancel()
        scheduledWakeTask = Task { @MainActor [weak self] in
            for attempt in 0..<10 {
                guard let self, !Task.isCancelled else { return }
                if attempt > 0 {
                    try? await Task.sleep(for: .seconds(1))
                }
                do {
                    try self.configureWakeSession()
                    try self.startWakeToneLoop(
                        volume: VolumeProfile.fullWakeTone,
                        mode: .wakeTone
                    )
                    return
                } catch {
                    continue
                }
            }
        }
    }

    // MARK: – Session Configuration

    private func configureKeepAliveSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    private func configureWakeSession() throws {
        let session = AVAudioSession.sharedInstance()
        // The session is already active from the keep-alive phase.
        // Just swap the category to drop mixWithOthers so the alarm
        // takes exclusive control of the hardware.
        try session.setCategory(.playback, mode: .default, options: [])
        do {
            try session.setActive(true)
        } catch {
            // If exclusive activation fails (cannotInterruptOthers when
            // another app is coexisting), fall back to duckOthers so the
            // alarm still plays loudly while lowering the other audio.
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        }
    }

    // MARK: – Playback

    private func startKeepAliveLoop() throws {
        if mode == .keepAlive, keepAlivePlayer?.isPlaying == true {
            return
        }

        stopPlayback()
        let player = try makePlayer(
            resource: "BackgroundKeepAlive",
            ext: "wav",
            volume: VolumeProfile.keepAlive,
            loops: -1
        )
        keepAlivePlayer = player
        player.play()
        mode = .keepAlive
        startHealthCheck()
    }

    private func startWakeToneLoop(volume: Float, mode: PlaybackMode) throws {
        if self.mode == mode, let wakeTonePlayer {
            wakeTonePlayer.volume = volume
            if !wakeTonePlayer.isPlaying {
                wakeTonePlayer.play()
            }
            startHealthCheck()
            return
        }

        stopPlayback()
        let player = try makePlayer(
            resource: "WakeMissionTone",
            ext: "wav",
            volume: volume,
            loops: -1
        )
        wakeTonePlayer = player
        player.play()
        self.mode = mode
        startHealthCheck()
    }

    private func makePlayer(resource: String, ext: String, volume: Float, loops: Int) throws -> AVAudioPlayer {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            throw WakeAudioControllerError.missingResource("\(resource).\(ext)")
        }

        let player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = loops
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    private func stopPlayback() {
        keepAlivePlayer?.stop()
        wakeTonePlayer?.stop()
        keepAlivePlayer = nil
        wakeTonePlayer = nil
    }

    private var isActivelyPlaying: Bool {
        switch mode {
        case .idle: return false
        case .keepAlive: return keepAlivePlayer?.isPlaying ?? false
        case .wakeTone, .missionWakeTone: return wakeTonePlayer?.isPlaying ?? false
        }
    }

    // MARK: – Audio Session Events

    private func observeAudioSessionEvents() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            break
        case .ended:
            resumeAfterInterruption()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard mode != .idle else { return }

        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            resumeAfterInterruption()
        default:
            break
        }
    }

    /// Re-activate the audio session and resume whatever was playing before the
    /// system interrupted us (phone call, Siri, headphone disconnect, etc.).
    /// Retries several times with back-off because the system may not release
    /// the hardware immediately after the interruption ends.
    private func resumeAfterInterruption() {
        guard mode != .idle else { return }
        resumeRetryTask?.cancel()

        resumeRetryTask = Task { @MainActor [weak self] in
            for attempt in 0..<5 {
                guard let self, !Task.isCancelled, self.mode != .idle else { return }
                if attempt > 0 {
                    try? await Task.sleep(for: .milliseconds(300 * (attempt + 1)))
                }

                do {
                    try self.restorePlayback()
                    return
                } catch {
                    continue
                }
            }
        }
    }

    // MARK: – Playback Health Monitor

    /// Periodically verifies that the expected player is still running.
    /// If the player silently died (no interruption notification from the
    /// system), this kicks in as a last-resort self-heal.
    private func startHealthCheck() {
        guard healthCheckTask == nil || healthCheckTask?.isCancelled == true else { return }
        healthCheckTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.mode != .idle {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, self.mode != .idle else { break }
                guard !self.isActivelyPlaying else { continue }

                // Try a cheap resume first — just call .play() on the
                // existing player without touching the audio session.
                switch self.mode {
                case .keepAlive:
                    if let player = self.keepAlivePlayer {
                        player.play()
                    }
                case .wakeTone, .missionWakeTone:
                    if let player = self.wakeTonePlayer {
                        player.play()
                    }
                case .idle:
                    break
                }

                // If the cheap resume didn't help, escalate to full
                // session restoration with retry.
                if !self.isActivelyPlaying {
                    self.resumeAfterInterruption()
                }
            }
        }
    }

    private func cancelHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    // MARK: – Playback Restoration

    private func restorePlayback() throws {
        let pastWakeTime = scheduledAt.map { Date() >= $0 } ?? false

        switch mode {
        case .idle:
            return

        case .keepAlive:
            if pastWakeTime {
                try configureWakeSession()
                try startWakeToneLoop(volume: VolumeProfile.fullWakeTone, mode: .wakeTone)
            } else {
                try configureKeepAliveSession()
                if let player = keepAlivePlayer, !player.isPlaying {
                    player.play()
                } else if keepAlivePlayer == nil {
                    try startKeepAliveLoop()
                }
            }

        case .wakeTone:
            try configureWakeSession()
            if let player = wakeTonePlayer, !player.isPlaying {
                player.play()
            } else if wakeTonePlayer == nil {
                try startWakeToneLoop(volume: VolumeProfile.fullWakeTone, mode: .wakeTone)
            }

        case .missionWakeTone:
            try configureWakeSession()
            if let player = wakeTonePlayer, !player.isPlaying {
                player.play()
            } else if wakeTonePlayer == nil {
                try startWakeToneLoop(volume: VolumeProfile.missionWakeTone, mode: .missionWakeTone)
            }
        }
    }
}

private enum WakeAudioControllerError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing bundled wake audio resource: \(name)."
        }
    }
}
