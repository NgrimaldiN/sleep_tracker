import AVFAudio
import Foundation

struct LiveShowerDetectorUpdate: Sendable {
    var prediction: ShowerDetectorPrediction
    var confirmed: Bool
}

protocol LiveShowerListening: Sendable {
    func start(
        profile: ShowerDetectorProfile,
        onUpdate: @escaping @Sendable (LiveShowerDetectorUpdate) -> Void
    ) async throws
    func stop() async
}

private enum LiveShowerDetectorError: LocalizedError {
    case noInputDevice
    case startupFailed(step: String, details: String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No microphone input is available on this device."
        case let .startupFailed(step, details):
            return "\(step) failed. \(details)"
        }
    }
}

final class LiveShowerDetector: @unchecked Sendable, LiveShowerListening {
    private let processingQueue = DispatchQueue(label: "SleepTrackerIOS.LiveShowerDetector")
    private var engine: AVAudioEngine?
    private var profile: ShowerDetectorProfile?
    private var onUpdate: (@Sendable (LiveShowerDetectorUpdate) -> Void)?
    private var streamBuffer = ShowerDetectorStreamBuffer()
    private var detectionGate = ShowerDetectionGate()
    private var hasConfirmedShower = false

    func start(
        profile: ShowerDetectorProfile,
        onUpdate: @escaping @Sendable (LiveShowerDetectorUpdate) -> Void
    ) async throws {
        await stop()

        self.profile = profile
        self.onUpdate = onUpdate
        self.streamBuffer = ShowerDetectorStreamBuffer()
        self.detectionGate = SleepTrackerAppCore.missionShowerDetectionGate(profile: profile)
        self.hasConfirmedShower = false

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker]
            )
        } catch {
            throw makeStartupError(step: "Audio session setup", error: error, session: session)
        }
        do {
            try session.setPreferredIOBufferDuration(0.02)
        } catch {
            throw makeStartupError(step: "Audio buffer setup", error: error, session: session)
        }
        do {
            try session.setActive(true)
        } catch {
            throw makeStartupError(step: "Microphone activation", error: error, session: session)
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let outputNode = engine.outputNode

        do {
            try inputNode.setVoiceProcessingEnabled(true)
            try outputNode.setVoiceProcessingEnabled(true)
        } catch {
            throw makeStartupError(step: "Voice processing setup", error: error, session: session)
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw LiveShowerDetectorError.noInputDevice
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer, sampleRate: inputFormat.sampleRate)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw makeStartupError(step: "Audio engine start", error: error, session: session)
        }
        self.engine = engine
    }

    func stop() async {
        processingQueue.sync {
            streamBuffer.reset()
            detectionGate.reset()
            hasConfirmedShower = false
        }

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        profile = nil
        onUpdate = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore deactivation failures for the prototype.
        }
    }

    private func process(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else { return }

        let channels = (0..<channelCount).map { channelIndex in
            Array(UnsafeBufferPointer(start: channelData[channelIndex], count: frameLength))
        }
        let samples = ShowerDetectorSampleMixer.downmixToMono(channels: channels)
        guard !samples.isEmpty else { return }

        processingQueue.async { [weak self] in
            guard let self, let profile = self.profile, !self.hasConfirmedShower else { return }

            let windows = self.streamBuffer.ingest(samples: samples, sampleRate: sampleRate)
            guard !windows.isEmpty else { return }

            for window in windows {
                let features = ShowerDetectorFeatureExtractor.extractFeatureVector(
                    samples: window,
                    sampleRate: sampleRate
                )
                guard features.count == profile.featureNames.count else { continue }

                let prediction = profile.predict(features: features)
                let confirmed = self.detectionGate.ingest(prediction)
                if confirmed {
                    self.hasConfirmedShower = true
                }
                self.onUpdate?(LiveShowerDetectorUpdate(
                    prediction: prediction,
                    confirmed: confirmed
                ))
            }
        }
    }

    private func makeStartupError(
        step: String,
        error: Error,
        session: AVAudioSession
    ) -> LiveShowerDetectorError {
        let nsError = error as NSError
        let routeSummary = session.currentRoute.inputs.map(\.portName).joined(separator: ", ")
        let routeText = routeSummary.isEmpty ? "No active microphone route." : "Input route: \(routeSummary)."
        let details = "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]. \(routeText)"
        return .startupFailed(step: step, details: details)
    }
}
