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
    private var scheduledAt: Date?
    private var mode: PlaybackMode = .idle

    func arm(scheduledAt: Date) throws {
        if self.scheduledAt == scheduledAt,
           mode == .keepAlive || mode == .wakeTone || mode == .missionWakeTone {
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
        scheduledAt = nil
        stopPlayback()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Best effort for the prototype.
        }

        mode = .idle
    }

    private func scheduleWakeTone(for scheduledAt: Date) {
        scheduledWakeTask?.cancel()
        scheduledWakeTask = Task { @MainActor [weak self] in
            let interval = scheduledAt.timeIntervalSinceNow
            if interval > 0 {
                try? await Task.sleep(for: .seconds(interval))
            }
            guard let self else { return }
            try? self.configureWakeSession()
            try? self.startWakeToneLoop(
                volume: VolumeProfile.fullWakeTone,
                mode: .wakeTone
            )
        }
    }

    private func configureKeepAliveSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    private func configureWakeSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    private func startKeepAliveLoop() throws {
        guard mode != .keepAlive else { return }

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
    }

    private func startWakeToneLoop(volume: Float, mode: PlaybackMode) throws {
        if self.mode == mode, let wakeTonePlayer {
            wakeTonePlayer.volume = volume
            if !wakeTonePlayer.isPlaying {
                wakeTonePlayer.play()
            }
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
