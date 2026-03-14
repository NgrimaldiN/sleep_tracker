import Foundation
import Testing
@testable import GarminImportCore

struct AlarmFeatureCoreTests {
    @Test
    func bundledDetectorProfileMatchesSharedFeatureExtractor() throws {
        let profileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SleepTrackerIOS/ShowerDetectorProfile.json")
        let data = try Data(contentsOf: profileURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let profile = try decoder.decode(ShowerDetectorProfile.self, from: data)

        #expect(profile.featureNames == ShowerDetectorFeatureExtractor.featureNames)
    }

    @Test
    func showerDetectorFeatureExtractorProducesStableFeatureCount() {
        let samples = (0..<16_000).map { index in
            Float(sin(Double(index) * 2 * Double.pi * 440 / 16_000))
        }

        let features = ShowerDetectorFeatureExtractor.extractFeatureVector(
            samples: samples,
            sampleRate: 16_000
        )

        #expect(features.count == ShowerDetectorFeatureExtractor.featureNames.count)
    }

    @Test
    func showerDetectorFeatureExtractorSeparatesSteadyAndBurstySignals() {
        let steady = Array(repeating: Float(0.18), count: 16_000)
        let bursty = (0..<16_000).map { index in
            let active = (index / 1_000).isMultiple(of: 2)
            return active ? Float(0.45) : Float(0.01)
        }

        let steadyFeatures = ShowerDetectorFeatureExtractor.extractFeatureVector(
            samples: steady,
            sampleRate: 16_000
        )
        let burstyFeatures = ShowerDetectorFeatureExtractor.extractFeatureVector(
            samples: bursty,
            sampleRate: 16_000
        )

        #expect(steadyFeatures.count == burstyFeatures.count)
        #expect(burstyFeatures[1] > steadyFeatures[1])
        #expect(burstyFeatures[6] > steadyFeatures[6])
    }

    @Test
    func showerDetectionGateRequiresStableHighMarginPredictions() {
        var gate = ShowerDetectionGate(consecutivePositiveWindowsRequired: 3, minimumMargin: 0.25)

        let tentative = gate.ingest(.init(
            label: .showerOn,
            margin: 0.20,
            showerDistance: 0.5,
            notShowerDistance: 0.7
        ))
        let firstPositive = gate.ingest(.init(
            label: .showerOn,
            margin: 0.35,
            showerDistance: 0.4,
            notShowerDistance: 0.75
        ))
        let secondPositive = gate.ingest(.init(
            label: .showerOn,
            margin: 0.42,
            showerDistance: 0.33,
            notShowerDistance: 0.75
        ))
        let confirmed = gate.ingest(.init(
            label: .showerOn,
            margin: 0.51,
            showerDistance: 0.29,
            notShowerDistance: 0.80
        ))

        #expect(tentative == false)
        #expect(firstPositive == false)
        #expect(secondPositive == false)
        #expect(confirmed == true)
    }

    @Test
    func showerDetectionGateResetsAfterNegativePrediction() {
        var gate = ShowerDetectionGate(consecutivePositiveWindowsRequired: 2, minimumMargin: 0.2)

        let firstPositive = gate.ingest(.init(
            label: .showerOn,
            margin: 0.4,
            showerDistance: 0.4,
            notShowerDistance: 0.8
        ))
        let reset = gate.ingest(.init(
            label: .notShower,
            margin: -0.1,
            showerDistance: 0.8,
            notShowerDistance: 0.7
        ))
        let secondPositive = gate.ingest(.init(
            label: .showerOn,
            margin: 0.31,
            showerDistance: 0.42,
            notShowerDistance: 0.73
        ))
        let confirmed = gate.ingest(.init(
            label: .showerOn,
            margin: 0.29,
            showerDistance: 0.43,
            notShowerDistance: 0.72
        ))

        #expect(firstPositive == false)
        #expect(reset == false)
        #expect(secondPositive == false)
        #expect(confirmed == true)
    }

    @Test
    func missionDetectorGateRequiresLongerStrongerConfirmationThanBaseline() {
        let profile = ShowerDetectorProfile(
            featureNames: ["rms_db", "spectral_centroid_hz"],
            normalizationMeans: [0, 0],
            normalizationStds: [1, 1],
            showerCentroid: [1.0, 0.8],
            notShowerCentroid: [-1.0, -0.9],
            decisionThreshold: 0.0
        )
        var gate = SleepTrackerAppCore.missionShowerDetectionGate(profile: profile)

        let first = gate.ingest(.init(
            label: .showerOn,
            margin: 0.36,
            showerDistance: 0.31,
            notShowerDistance: 0.67
        ))
        let second = gate.ingest(.init(
            label: .showerOn,
            margin: 0.39,
            showerDistance: 0.30,
            notShowerDistance: 0.69
        ))
        let third = gate.ingest(.init(
            label: .showerOn,
            margin: 0.41,
            showerDistance: 0.28,
            notShowerDistance: 0.69
        ))
        let fourth = gate.ingest(.init(
            label: .showerOn,
            margin: 0.47,
            showerDistance: 0.26,
            notShowerDistance: 0.73
        ))
        let fifth = gate.ingest(.init(
            label: .showerOn,
            margin: 0.52,
            showerDistance: 0.24,
            notShowerDistance: 0.76
        ))

        #expect(first == false)
        #expect(second == false)
        #expect(third == false)
        #expect(fourth == false)
        #expect(fifth == true)
    }

    @Test
    func wakeNotificationCadenceUsesDenseBurstAcrossWakeWindow() {
        let cadence = SleepTrackerAppCore.wakeNotificationCadence(windowMinutes: 5)

        #expect(cadence.count == 100)
        #expect(cadence.spacingSeconds == 3)
    }

    @Test
    func showerDetectorStreamBufferEmitsOverlappingWindows() {
        var buffer = ShowerDetectorStreamBuffer(
            analysisWindowDuration: 2.0,
            analysisHopDuration: 1.0
        )

        let firstSecond = (0..<16_000).map(Float.init)
        let secondSecond = (16_000..<32_000).map(Float.init)
        let thirdSecond = (32_000..<48_000).map(Float.init)

        let beforeReady = buffer.ingest(samples: firstSecond, sampleRate: 16_000)
        let firstWindow = buffer.ingest(samples: secondSecond, sampleRate: 16_000)
        let secondWindow = buffer.ingest(samples: thirdSecond, sampleRate: 16_000)

        #expect(beforeReady.isEmpty)
        #expect(firstWindow.count == 1)
        #expect(firstWindow.first?.count == 32_000)
        #expect(firstWindow.first?.first == 0)
        #expect(firstWindow.first?.last == 31_999)
        #expect(secondWindow.count == 1)
        #expect(secondWindow.first?.first == 16_000)
        #expect(secondWindow.first?.last == 47_999)
    }

    @Test
    func showerDetectorSampleMixerLeavesMonoSamplesUntouched() {
        let mono = [Float(0.1), 0.2, -0.2, 0.4]

        let downmixed = ShowerDetectorSampleMixer.downmixToMono(channels: [mono])

        #expect(downmixed == mono)
    }

    @Test
    func showerDetectorSampleMixerAveragesStereoSamples() {
        let left = [Float(0.2), 0.4, -0.2, 0.6]
        let right = [Float(0.0), 0.2, -0.4, 0.2]

        let downmixed = ShowerDetectorSampleMixer.downmixToMono(channels: [left, right])

        #expect(downmixed == [0.1, 0.3, -0.3, 0.4])
    }

    @Test
    func showerDetectorProfilePrefersShowerCentroidForShowerLikeFeatures() {
        let profile = ShowerDetectorProfile(
            featureNames: ["rms_db", "spectral_centroid_hz"],
            normalizationMeans: [0, 0],
            normalizationStds: [1, 1],
            showerCentroid: [1.0, 0.8],
            notShowerCentroid: [-1.0, -0.9],
            decisionThreshold: 0
        )

        let prediction = profile.predict(features: [0.9, 0.75])

        #expect(prediction.label == .showerOn)
        #expect(prediction.margin > 0)
    }

    @Test
    func showerDetectorProfilePrefersNotShowerCentroidForNegativeFeatures() {
        let profile = ShowerDetectorProfile(
            featureNames: ["rms_db", "spectral_centroid_hz"],
            normalizationMeans: [0, 0],
            normalizationStds: [1, 1],
            showerCentroid: [1.0, 0.8],
            notShowerCentroid: [-1.0, -0.9],
            decisionThreshold: 0
        )

        let prediction = profile.predict(features: [-0.8, -1.1])

        #expect(prediction.label == .notShower)
        #expect(prediction.margin < 0)
    }

    @Test
    func showerMissionListeningStartRequiresActivePresentedCurrentMission() {
        let shouldStart = SleepTrackerAppCore.shouldStartShowerMissionListening(
            requestedGeneration: 4,
            currentGeneration: 4,
            isSceneActive: true,
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: false
        )

        #expect(shouldStart == true)
    }

    @Test
    func showerMissionListeningStartRejectsStaleOrBackgroundRequests() {
        let staleRequest = SleepTrackerAppCore.shouldStartShowerMissionListening(
            requestedGeneration: 3,
            currentGeneration: 4,
            isSceneActive: true,
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: false
        )
        let backgroundRequest = SleepTrackerAppCore.shouldStartShowerMissionListening(
            requestedGeneration: 4,
            currentGeneration: 4,
            isSceneActive: false,
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: false
        )

        #expect(staleRequest == false)
        #expect(backgroundRequest == false)
    }

    @Test
    func showerMissionBackgroundResumesWakeAudioUntilShowerIsConfirmed() {
        let shouldResume = SleepTrackerAppCore.shouldResumeWakeAudioForBackgroundMission(
            isMissionPresented: true,
            hasConfirmedShower: false
        )
        let shouldNotResumeAfterConfirmation = SleepTrackerAppCore.shouldResumeWakeAudioForBackgroundMission(
            isMissionPresented: true,
            hasConfirmedShower: true
        )
        let shouldNotResumeWithoutMission = SleepTrackerAppCore.shouldResumeWakeAudioForBackgroundMission(
            isMissionPresented: false,
            hasConfirmedShower: false
        )

        #expect(shouldResume == true)
        #expect(shouldNotResumeAfterConfirmation == false)
        #expect(shouldNotResumeWithoutMission == false)
    }

    @Test
    func showerMissionKeepsWakeToneAudibleUntilShowerIsConfirmed() {
        let shouldKeepAudible = SleepTrackerAppCore.shouldKeepWakeToneAudibleDuringMission(
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: false
        )
        let shouldMuteDuringVerificationHold = SleepTrackerAppCore.shouldKeepWakeToneAudibleDuringMission(
            isMissionPresented: true,
            isMissionListening: true,
            hasConfirmedShower: false
        )
        let shouldMuteAfterConfirmation = SleepTrackerAppCore.shouldKeepWakeToneAudibleDuringMission(
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: true
        )
        let shouldNotForceMissionToneWithoutMission = SleepTrackerAppCore.shouldKeepWakeToneAudibleDuringMission(
            isMissionPresented: false,
            isMissionListening: false,
            hasConfirmedShower: false
        )

        #expect(shouldKeepAudible == true)
        #expect(shouldMuteDuringVerificationHold == false)
        #expect(shouldMuteAfterConfirmation == false)
        #expect(shouldNotForceMissionToneWithoutMission == false)
    }

    @Test
    func wakeMissionRequestsVolumeRestoreWhenSystemVolumeIsMuted() {
        let targetVolume = SleepTrackerAppCore.enforcedWakeVolumeTarget(
            currentVolume: 0.0,
            isAlarmArmed: true,
            isMissionPresented: false
        )

        #expect(targetVolume == 0.55)
    }

    @Test
    func wakeMissionSkipsVolumeRestoreWhenAlarmIsInactiveOrAlreadyAudible() {
        let inactive = SleepTrackerAppCore.enforcedWakeVolumeTarget(
            currentVolume: 0.0,
            isAlarmArmed: false,
            isMissionPresented: false
        )
        let alreadyAudible = SleepTrackerAppCore.enforcedWakeVolumeTarget(
            currentVolume: 0.24,
            isAlarmArmed: true,
            isMissionPresented: false
        )

        #expect(inactive == nil)
        #expect(alreadyAudible == nil)
    }

    @Test
    func wakeForegroundNotificationsOnlyMuteAfterMissionTakesOver() {
        let beforeMission = SleepTrackerAppCore.shouldPlayForegroundWakeNotificationSound(
            isMissionPresented: false
        )
        let duringMission = SleepTrackerAppCore.shouldPlayForegroundWakeNotificationSound(
            isMissionPresented: true
        )

        #expect(beforeMission == true)
        #expect(duringMission == false)
    }

    @Test
    func missionPresentationRequestsWakeAudioBeforeVerificationHoldStarts() {
        let shouldRefresh = SleepTrackerAppCore.shouldRefreshWakeAudioOnMissionPresentation(
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: false
        )
        let shouldSkipWhileHolding = SleepTrackerAppCore.shouldRefreshWakeAudioOnMissionPresentation(
            isMissionPresented: true,
            isMissionListening: true,
            hasConfirmedShower: false
        )
        let shouldSkipAfterConfirmation = SleepTrackerAppCore.shouldRefreshWakeAudioOnMissionPresentation(
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: true
        )

        #expect(shouldRefresh == true)
        #expect(shouldSkipWhileHolding == false)
        #expect(shouldSkipAfterConfirmation == false)
    }

    @Test
    func wakeMissionAudioSessionShouldNotBeReconfiguredAfterDetectorTakesOver() {
        let shouldReconfigure = SleepTrackerAppCore.shouldWakeAudioReconfigureSession(
            isMissionPresented: true,
            isMissionListening: true,
            hasConfirmedShower: false
        )
        let shouldReconfigureForPresentedMissionBeforeHold = SleepTrackerAppCore.shouldWakeAudioReconfigureSession(
            isMissionPresented: true,
            isMissionListening: false,
            hasConfirmedShower: false
        )
        let shouldReconfigureForNormalAlarm = SleepTrackerAppCore.shouldWakeAudioReconfigureSession(
            isMissionPresented: false,
            isMissionListening: false,
            hasConfirmedShower: false
        )

        #expect(shouldReconfigure == false)
        #expect(shouldReconfigureForPresentedMissionBeforeHold == true)
        #expect(shouldReconfigureForNormalAlarm == true)
    }

    @Test
    func showerSampleRequirementsDefineInitialTrainingPack() {
        let requirements = SleepTrackerAppCore.showerSampleRequirements(samples: [])

        #expect(requirements.map(\.kind) == [
            .showerOn,
            .bathroomAmbient,
            .sinkRunning,
            .bathroomFan,
            .speechMovement,
            .silence,
        ])
        #expect(requirements.reduce(0) { $0 + $1.targetClipCount } == 50)
        #expect(requirements.reduce(0) { $0 + ($1.targetClipCount * $1.clipDurationSeconds) } == 400)
        #expect(requirements.first?.targetClipCount == 12)
        #expect(requirements.first?.clipDurationSeconds == 8)
        #expect(requirements.filter(\.isRequired).map(\.kind) == [
            .showerOn,
            .bathroomAmbient,
            .speechMovement,
        ])
    }

    @Test
    func showerAlarmSnapshotAcceptsMinimumViableBinaryTrainingPack() {
        let configuration = ShowerAlarmConfiguration(isEnabled: true, hour: 7, minute: 30)
        let samples = minimumViableSamplePack()

        let snapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: configuration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .missing,
            samples: samples,
            isPlatformSupported: true
        )

        #expect(snapshot.level == .needsModel)
        #expect(snapshot.collectedClipCount == 28)
        #expect(snapshot.blockers == ["The shower classifier has not been trained yet."])
    }

    @Test
    func showerAlarmSnapshotRequiresAlarmAccessBeforeAnythingElse() {
        let configuration = ShowerAlarmConfiguration(isEnabled: true, hour: 7, minute: 30)

        let snapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: configuration,
            alarmPermission: .denied,
            microphonePermission: .unknown,
            classifierState: .missing,
            samples: [],
            isPlatformSupported: true
        )

        #expect(snapshot.level == .needsAlarmAccess)
        #expect(snapshot.nextActionTitle == "Allow notifications")
        #expect(snapshot.blockers.contains("Notification permission is still missing."))
    }

    @Test
    func showerAlarmSnapshotNeedsModelAfterEnoughSamplesAreCollected() {
        let configuration = ShowerAlarmConfiguration(isEnabled: true, hour: 7, minute: 30)
        let samples = fullSamplePack()

        let snapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: configuration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .missing,
            samples: samples,
            isPlatformSupported: true
        )

        #expect(snapshot.level == .needsModel)
        #expect(snapshot.nextActionTitle == "Train and import classifier")
        #expect(snapshot.blockers.contains("The shower classifier has not been trained yet."))
    }

    @Test
    func showerAlarmSnapshotAllowsArmingWhenClassifierIsReadyWithoutLocalSamples() {
        let configuration = ShowerAlarmConfiguration(isEnabled: false, hour: 7, minute: 30)

        let snapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: configuration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .ready,
            samples: [],
            isPlatformSupported: true
        )

        #expect(snapshot.level == .readyToArm)
        #expect(snapshot.nextActionTitle.contains("Arm"))
    }

    @Test
    func showerAlarmConfigurationDefaultsHandsFreeToOff() {
        let configuration = ShowerAlarmConfiguration()

        #expect(configuration.experimentalHandsFreeEnabled == false)
        #expect(configuration.handsFreeWindowMinutes == 5)
    }

    @Test
    func showerAlarmScheduleDescriptorUsesTomorrowWhenTimeAlreadyPassed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = isoDate("2026-03-14T22:15:00Z")

        let descriptor = SleepTrackerAppCore.showerAlarmScheduleDescriptor(
            hour: 7,
            minute: 0,
            now: now,
            calendar: calendar
        )

        #expect(descriptor.dayLabel == "Tomorrow")
        #expect(descriptor.timeLabel == "07:00")
        #expect(descriptor.nextOccurrence == isoDate("2026-03-15T07:00:00Z"))
    }

    @Test
    func showerAlarmSnapshotUsesTodayTomorrowLanguageForSetupAndArmedStates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = isoDate("2026-03-14T22:15:00Z")
        let samples = fullSamplePack()

        let readyConfiguration = ShowerAlarmConfiguration(isEnabled: false, hour: 7, minute: 0)
        let readySnapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: readyConfiguration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .ready,
            samples: samples,
            isPlatformSupported: true,
            now: now,
            calendar: calendar
        )

        #expect(readySnapshot.nextActionTitle == "Arm for Tomorrow")
        #expect(readySnapshot.summary.contains("Tomorrow at 07:00"))
        #expect(readySnapshot.scheduleDayLabel == "Tomorrow")

        let armedConfiguration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 7,
            minute: 0,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
            scheduledForISO8601: "2026-03-15T07:00:00Z"
        )
        let armedSnapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: armedConfiguration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .ready,
            samples: samples,
            isPlatformSupported: true,
            now: now,
            calendar: calendar
        )

        #expect(armedSnapshot.summary.contains("Tomorrow at 07:00"))
        #expect(armedSnapshot.scheduleDayLabel == "Tomorrow")
    }

    @Test
    func showerAlarmListCardDescriptorReflectsArmedAndUnarmedStates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = isoDate("2026-03-14T22:15:00Z")

        let unarmed = SleepTrackerAppCore.showerAlarmListCardDescriptor(
            configuration: ShowerAlarmConfiguration(isEnabled: false, hour: 8, minute: 45),
            now: now,
            calendar: calendar
        )

        #expect(unarmed.timeLabel == "08:45")
        #expect(unarmed.dayLabel == "Tomorrow")
        #expect(unarmed.isActive == false)

        let armed = SleepTrackerAppCore.showerAlarmListCardDescriptor(
            configuration: ShowerAlarmConfiguration(
                isEnabled: true,
                hour: 8,
                minute: 45,
                scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
                scheduledForISO8601: "2026-03-15T08:45:00Z"
            ),
            now: now,
            calendar: calendar
        )

        #expect(armed.timeLabel == "08:45")
        #expect(armed.dayLabel == "Tomorrow")
        #expect(armed.isActive == true)
    }

    @Test
    func showerWakeWindowDescriptorIsPendingBeforeAlarmTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = isoDate("2026-03-14T06:55:00Z")
        let configuration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 7,
            minute: 0,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
            scheduledForISO8601: "2026-03-14T07:00:00Z",
            experimentalHandsFreeEnabled: true,
            handsFreeWindowMinutes: 5
        )

        let descriptor = SleepTrackerAppCore.showerWakeWindowDescriptor(
            configuration: configuration,
            now: now,
            calendar: calendar
        )

        #expect(descriptor?.phase == .pending)
        #expect(descriptor?.shouldKeepListening == true)
        #expect(descriptor?.isWithinConfirmationWindow == false)
    }

    @Test
    func showerWakeWindowDescriptorIsActiveDuringPostAlarmWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = isoDate("2026-03-14T07:03:00Z")
        let configuration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 7,
            minute: 0,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
            scheduledForISO8601: "2026-03-14T07:00:00Z",
            experimentalHandsFreeEnabled: true,
            handsFreeWindowMinutes: 5
        )

        let descriptor = SleepTrackerAppCore.showerWakeWindowDescriptor(
            configuration: configuration,
            now: now,
            calendar: calendar
        )

        #expect(descriptor?.phase == .active)
        #expect(descriptor?.shouldKeepListening == true)
        #expect(descriptor?.isWithinConfirmationWindow == true)
    }

    @Test
    func showerWakeWindowDescriptorExpiresAfterConfiguredWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = isoDate("2026-03-14T07:06:00Z")
        let configuration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 7,
            minute: 0,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
            scheduledForISO8601: "2026-03-14T07:00:00Z",
            experimentalHandsFreeEnabled: true,
            handsFreeWindowMinutes: 5
        )

        let descriptor = SleepTrackerAppCore.showerWakeWindowDescriptor(
            configuration: configuration,
            now: now,
            calendar: calendar
        )

        #expect(descriptor?.phase == .expired)
        #expect(descriptor?.shouldKeepListening == false)
        #expect(descriptor?.isWithinConfirmationWindow == false)
    }

    @Test
    func showerMissionDescriptorIsPendingBeforeScheduledAlarm() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let configuration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 7,
            minute: 0,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
            scheduledForISO8601: "2026-03-14T07:00:00Z"
        )

        let descriptor = SleepTrackerAppCore.showerMissionDescriptor(
            configuration: configuration,
            now: isoDate("2026-03-14T06:58:00Z"),
            calendar: calendar
        )

        #expect(descriptor?.phase == .pending)
        #expect(descriptor?.shouldPresentMission == false)
    }

    @Test
    func showerMissionDescriptorBecomesActiveAfterScheduledAlarm() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let configuration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 7,
            minute: 0,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
            scheduledForISO8601: "2026-03-14T07:00:00Z"
        )

        let descriptor = SleepTrackerAppCore.showerMissionDescriptor(
            configuration: configuration,
            now: isoDate("2026-03-14T07:04:00Z"),
            calendar: calendar
        )

        #expect(descriptor?.phase == .active)
        #expect(descriptor?.shouldPresentMission == true)
    }

    @Test
    func showerMissionDescriptorExpiresAfterMissionWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let configuration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 7,
            minute: 0,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5"),
            scheduledForISO8601: "2026-03-14T07:00:00Z"
        )

        let descriptor = SleepTrackerAppCore.showerMissionDescriptor(
            configuration: configuration,
            now: isoDate("2026-03-14T07:25:00Z"),
            calendar: calendar
        )

        #expect(descriptor?.phase == .expired)
        #expect(descriptor?.shouldPresentMission == false)
    }

    @Test
    func showerAlarmConfigurationDecodesLegacyPayloadWithoutHandsFreeFields() throws {
        let data = Data("""
        {
          "isEnabled": true,
          "hour": 8,
          "minute": 45,
          "repeatsDaily": true
        }
        """.utf8)

        let configuration = try JSONDecoder().decode(ShowerAlarmConfiguration.self, from: data)

        #expect(configuration.experimentalHandsFreeEnabled == false)
        #expect(configuration.handsFreeWindowMinutes == 5)
    }

    @Test
    func showerAlarmSnapshotBecomesReadyThenArmedWhenScheduled() {
        let samples = fullSamplePack()
        let readyConfiguration = ShowerAlarmConfiguration(isEnabled: true, hour: 6, minute: 45)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = isoDate("2026-03-14T05:30:00Z")

        let readySnapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: readyConfiguration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .ready,
            samples: samples,
            isPlatformSupported: true,
            now: now,
            calendar: calendar
        )

        #expect(readySnapshot.level == .readyToArm)
        #expect(readySnapshot.nextActionTitle == "Arm for Today")

        let armedConfiguration = ShowerAlarmConfiguration(
            isEnabled: true,
            hour: 6,
            minute: 45,
            scheduledAlarmID: UUID(uuidString: "C95A1B2D-3E8D-4D2A-A298-33CEB3A4BEA5")
        )

        let armedSnapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: armedConfiguration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .ready,
            samples: samples,
            isPlatformSupported: true,
            now: now,
            calendar: calendar
        )

        #expect(armedSnapshot.level == .armed)
        #expect(armedSnapshot.title == "Wake mission armed")
    }

    private func isoDate(_ rawValue: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: rawValue)!
    }

    private func fullSamplePack() -> [ShowerTrainingSample] {
        SleepTrackerAppCore.showerSampleRequirements(samples: []).flatMap { requirement in
            (0..<requirement.targetClipCount).map { index in
                ShowerTrainingSample(
                    kind: requirement.kind,
                    durationSeconds: requirement.clipDurationSeconds,
                    createdAt: "2026-03-13T08:00:00Z",
                    fileName: "\(requirement.kind.rawValue)-\(index).caf"
                )
            }
        }
    }

    private func minimumViableSamplePack() -> [ShowerTrainingSample] {
        let requiredKinds: [ShowerSampleKind: Int] = [
            .showerOn: 12,
            .bathroomAmbient: 8,
            .speechMovement: 8,
        ]

        return requiredKinds.flatMap { kind, count in
            (0..<count).map { index in
                ShowerTrainingSample(
                    kind: kind,
                    durationSeconds: kind.clipDurationSeconds,
                    createdAt: "2026-03-14T07:00:00Z",
                    fileName: "\(kind.rawValue)-\(index).caf"
                )
            }
        }
    }
}
