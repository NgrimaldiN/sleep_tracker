import Foundation
import Testing
@testable import GarminImportCore

struct AlarmFeatureCoreTests {
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
        #expect(snapshot.nextActionTitle == "Allow alarms")
        #expect(snapshot.blockers.contains("Alarm permission is still missing."))
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
    func showerAlarmSnapshotBecomesReadyThenArmedWhenScheduled() {
        let samples = fullSamplePack()
        let readyConfiguration = ShowerAlarmConfiguration(isEnabled: true, hour: 6, minute: 45)

        let readySnapshot = SleepTrackerAppCore.showerAlarmSnapshot(
            configuration: readyConfiguration,
            alarmPermission: .authorized,
            microphonePermission: .authorized,
            classifierState: .ready,
            samples: samples,
            isPlatformSupported: true
        )

        #expect(readySnapshot.level == .readyToArm)
        #expect(readySnapshot.nextActionTitle == "Arm 06:45 alarm")

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
            isPlatformSupported: true
        )

        #expect(armedSnapshot.level == .armed)
        #expect(armedSnapshot.title == "Shower alarm armed")
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
}
