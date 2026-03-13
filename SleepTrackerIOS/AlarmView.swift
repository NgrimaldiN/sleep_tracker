import SwiftUI

struct AlarmView: View {
    @ObservedObject var alarmModel: AlarmFeatureModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if alarmModel.isLoading {
                    ProgressView("Loading alarm prototype")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                } else {
                    statusCard
                    scheduleCard
                    permissionsCard
                    trainingCard
                    notesCard
                }
            }
            .padding(20)
        }
        .navigationTitle("Alarm")
        .task {
            if alarmModel.isLoading {
                await alarmModel.bootstrap()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await alarmModel.refreshStatus()
                    }
                } label: {
                    if alarmModel.isWorking {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .tint(.white)
            }
        }
    }

    private var statusCard: some View {
        let snapshot = alarmModel.snapshot
        let tint = statusTint(for: snapshot.level)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.title)
                        .font(.custom("AvenirNext-Bold", size: 28))
                        .foregroundStyle(.white)
                    Text(snapshot.summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text(snapshot.alarmTimeLabel)
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }

            Label(alarmModel.statusMessage, systemImage: "bolt.horizontal.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)

            if !snapshot.blockers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(snapshot.blockers, id: \.self) { blocker in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(tint)
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)
                            Text(blocker)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                }
            }

            if let errorMessage = alarmModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.coral)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.95),
                            Color.cardBlue.opacity(0.9),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var scheduleCard: some View {
        let snapshot = alarmModel.snapshot

        return VStack(alignment: .leading, spacing: 14) {
            Text("Schedule")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("This prototype arms the next occurrence of your shower alarm. If you change the time, re-arm it.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))

            DatePicker(
                "Wake-up time",
                selection: Binding(
                    get: { alarmModel.alarmTimeDate },
                    set: { newDate in
                        Task {
                            await alarmModel.updateAlarmTime(newDate)
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .tint(.white)

            Toggle(isOn: Binding(
                get: { alarmModel.configuration.isEnabled },
                set: { isOn in
                    Task {
                        await alarmModel.setEnabled(isOn)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable shower alarm")
                        .foregroundStyle(.white)
                    Text("The actual auto-stop still depends on the trained shower classifier.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .tint(Color.sunAccent)

            Button {
                Task {
                    if snapshot.level == .armed {
                        await alarmModel.disarmAlarm()
                    } else {
                        await alarmModel.armAlarm()
                    }
                }
            } label: {
                Text(snapshot.level == .armed ? "Disarm Alarm" : snapshot.nextActionTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(snapshot.level == .armed ? Color.white.opacity(0.08) : Color.sunAccent)
                    .foregroundStyle(snapshot.level == .armed ? .white : Color.nightInk)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(alarmModel.isWorking || !canArm(from: snapshot.level))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            permissionRow(
                title: "Alarm access",
                detail: "Needed for a real app-owned alarm on the lock screen.",
                status: alarmModel.alarmPermission,
                actionTitle: alarmModel.alarmPermission == .authorized ? nil : "Allow"
            ) {
                Task {
                    await alarmModel.requestAlarmAccess()
                }
            }

            permissionRow(
                title: "Microphone",
                detail: "Needed to hear the shower locally in the bathroom.",
                status: alarmModel.microphonePermission,
                actionTitle: alarmModel.microphonePermission == .authorized ? nil : "Allow"
            ) {
                Task {
                    await alarmModel.requestMicrophoneAccess()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var trainingCard: some View {
        let snapshot = alarmModel.snapshot

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training Pack")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(snapshot.collectedClipCount)/\(snapshot.totalRequiredClips) clips · \(formattedDuration(snapshot.collectedSeconds))/\(formattedDuration(snapshot.totalRequiredSeconds))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                }
                Spacer()
                Text(classifierBadgeTitle(for: alarmModel.classifierState))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Capsule())
                    .foregroundStyle(.white.opacity(0.78))
            }

            ForEach(snapshot.sampleRequirements) { requirement in
                sampleCard(requirement: requirement)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Happens Next")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            noteLine("1. Record the labeled bathroom sounds directly here in the app.")
            noteLine("2. Once the pack is complete, we train a small custom shower classifier for your bathroom.")
            noteLine("3. Then we prove the full loop on-device: alarm rings, phone is in the bathroom, shower starts, alarm stops.")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func permissionRow(
        title: String,
        detail: String,
        status: AlarmPermissionState,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Text(permissionTitle(for: status))
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(permissionTint(for: status).opacity(0.2))
                .clipShape(Capsule())
                .foregroundStyle(permissionTint(for: status))

            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func sampleCard(requirement: ShowerSampleRequirement) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(requirement.label)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(requirement.guidance)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Text("\(requirement.completedClipCount)/\(requirement.targetClipCount)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(requirement.isComplete ? Color.cardTeal : .white)
            }

            ProgressView(
                value: Double(requirement.completedClipCount),
                total: Double(requirement.targetClipCount)
            )
            .tint(requirement.isComplete ? Color.cardTeal : Color.sunAccent)

            Button {
                Task {
                    await alarmModel.recordSample(kind: requirement.kind)
                }
            } label: {
                Text(alarmModel.recordingKind == requirement.kind ? "Recording \(requirement.clipDurationSeconds)s..." : "Record \(requirement.clipDurationSeconds)s")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(requirement.isComplete ? Color.cardTeal.opacity(0.16) : Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(alarmModel.recordingKind != nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
    }

    private func noteLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.sunAccent)
                .frame(width: 7, height: 7)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func canArm(from level: ShowerAlarmReadinessLevel) -> Bool {
        level == .readyToArm || level == .armed
    }

    private func permissionTitle(for state: AlarmPermissionState) -> String {
        switch state {
        case .authorized:
            return "Ready"
        case .denied:
            return "Denied"
        case .unknown:
            return "Unknown"
        case .unavailable:
            return "Unavailable"
        }
    }

    private func permissionTint(for state: AlarmPermissionState) -> Color {
        switch state {
        case .authorized:
            return Color.cardTeal
        case .denied:
            return Color.coral
        case .unknown, .unavailable:
            return Color.sunAccent
        }
    }

    private func classifierBadgeTitle(for state: ShowerClassifierState) -> String {
        switch state {
        case .ready:
            return "Classifier Ready"
        case .training:
            return "Training"
        case .missing:
            return "Needs Model"
        }
    }

    private func statusTint(for level: ShowerAlarmReadinessLevel) -> Color {
        switch level {
        case .armed, .readyToArm:
            return Color.cardTeal
        case .needsSamples, .needsModel, .needsAlarmAccess, .needsMicrophoneAccess:
            return Color.sunAccent
        case .unavailable:
            return Color.coral
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes)m" : "\(minutes)m \(remainder)s"
    }
}
