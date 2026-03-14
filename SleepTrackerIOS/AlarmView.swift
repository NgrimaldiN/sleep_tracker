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
                    liveDetectorCard
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
                VStack(alignment: .trailing, spacing: 4) {
                    Text(snapshot.scheduleDayLabel.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(snapshot.alarmTimeLabel)
                        .font(.title3.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.18))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }
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
        let card = alarmModel.alarmListCardDescriptor
        let handsFree = alarmModel.handsFreeState

        return VStack(alignment: .leading, spacing: 14) {
            Text("Alarm")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.timeLabel)
                        .font(.custom("AvenirNext-Bold", size: 38))
                        .foregroundStyle(.white)
                    Text(card.dayLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { card.isActive },
                        set: { newValue in
                            Task {
                                await alarmModel.setAlarmArmed(newValue)
                            }
                        }
                    )
                )
                .labelsHidden()
                .tint(Color.cardTeal)
                .disabled(alarmModel.isWorking || (!card.isActive && !canArm(from: snapshot.level)))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )

            Text("One-shot wake-up mission for the next occurrence. When armed, the app keeps a quiet background playback session alive overnight, switches to a loud wake tone at wake time, and also schedules backup notifications.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Experimental Hands-Free Stop")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Optional. This keeps the microphone armed until 5 minutes after the wake time. Leave it off for the first background-audio test.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { alarmModel.configuration.experimentalHandsFreeEnabled },
                            set: { newValue in
                                Task {
                                    await alarmModel.setHandsFreeEnabled(newValue)
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .tint(Color.sunAccent)
                    .disabled(alarmModel.isWorking)
                }

                HStack(spacing: 10) {
                    Text(handsFreeBadgeTitle(for: handsFree.phase))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.18))
                        .clipShape(Capsule())
                        .foregroundStyle(handsFreeBadgeTint(for: handsFree.phase))

                    if handsFree.isRunning {
                        Text("Mic armed")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.18))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.cardTeal)
                    }
                }

                Text(handsFree.detailLine)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(alarmModel.quickPresetTimes) { preset in
                        Button {
                            Task {
                                await alarmModel.applyQuickPreset(preset)
                            }
                        } label: {
                            Text(preset.label)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            alarmModel.configuration.hour == preset.hour &&
                                            alarmModel.configuration.minute == preset.minute
                                            ? Color.cardTeal
                                            : Color.white.opacity(0.08)
                                        )
                                )
                                .foregroundStyle(
                                    alarmModel.configuration.hour == preset.hour &&
                                    alarmModel.configuration.minute == preset.minute
                                    ? Color.nightInk
                                    : .white
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                Task {
                    await alarmModel.armTestAlarmSoon()
                }
            } label: {
                Label("Test Ring in 2 Minutes", systemImage: "bell.badge")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.sunAccent)
                    .foregroundStyle(Color.nightInk)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(alarmModel.isWorking || !canArm(from: snapshot.level))

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

            Text("Leave the app in the background after arming. At wake time it should switch from quiet keep-alive playback to the loud wake tone, with backup notifications firing too.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
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
                title: "Notifications",
                detail: "Needed for the backup wake notifications that get you back into the shower mission if the background audio path fails.",
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
                    Text("\(snapshot.collectedClipCount)/\(snapshot.totalRequiredClips) baseline clips · \(formattedDuration(snapshot.collectedSeconds))/\(formattedDuration(snapshot.totalRequiredSeconds))")
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

    private var liveDetectorCard: some View {
        let liveState = alarmModel.liveDetectionState
        let prediction = liveState.latestPrediction

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Detector")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(liveState.statusLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text(liveBadgeTitle(for: liveState))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Capsule())
                    .foregroundStyle(liveBadgeTint(for: liveState))
            }

            Text(liveState.detailLine)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))

            if let prediction {
                HStack(spacing: 12) {
                    liveSignalPill(
                        title: prediction.label == .showerOn ? "Leaning shower" : "Leaning background",
                        value: prediction.label == .showerOn ? "Shower" : "Not Shower"
                    )
                    liveSignalPill(
                        title: "Margin",
                        value: String(format: "%.2f", prediction.margin)
                    )
                }
            }

            Button {
                Task {
                    if liveState.isListening {
                        await alarmModel.stopListeningTest()
                    } else {
                        await alarmModel.startListeningTest()
                    }
                }
            } label: {
                Text(liveState.isListening ? "Stop Listening" : "Start Listening")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(liveState.isListening ? Color.white.opacity(0.08) : Color.cardTeal)
                    .foregroundStyle(liveState.isListening ? .white : Color.nightInk)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(alarmModel.isWorking || alarmModel.classifierState != .ready)
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

            noteLine("1. Record the baseline sounds here first: shower, quiet bathroom, and human movement.")
            noteLine("2. Sink and fan clips are optional hard negatives that can make the detector tougher later.")
            noteLine("3. Once the baseline pack is complete, the app can run the bundled detector profile live on your phone.")
            noteLine("4. Leave the app in the background after arming. Do not force-quit it before sleep.")
            noteLine("5. If the loud wake tone starts, open the app or the notification. The shower mission launches automatically and the alarm keeps sounding while it listens.")
            noteLine("6. If the media volume is dragged all the way down while the wake mission is armed, the app will try to raise it back to an audible level.")
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
                    HStack(spacing: 8) {
                        Text(requirement.label)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if !requirement.isRequired {
                            Text("Optional")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
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

    private func liveSignalPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
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

    private func liveBadgeTitle(for state: LiveShowerDetectionState) -> String {
        if state.hasConfirmedShower {
            return "Confirmed"
        }
        if state.isListening {
            return "Listening"
        }
        return "Ready"
    }

    private func liveBadgeTint(for state: LiveShowerDetectionState) -> Color {
        if state.hasConfirmedShower {
            return Color.cardTeal
        }
        if state.isListening {
            return Color.sunAccent
        }
        return Color.white.opacity(0.78)
    }

    private func handsFreeBadgeTitle(for phase: ShowerWakeWindowPhase) -> String {
        switch phase {
        case .disabled:
            return "Off"
        case .pending:
            return "Armed"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        }
    }

    private func handsFreeBadgeTint(for phase: ShowerWakeWindowPhase) -> Color {
        switch phase {
        case .disabled:
            return Color.white.opacity(0.78)
        case .pending:
            return Color.sunAccent
        case .active:
            return Color.cardTeal
        case .expired:
            return Color.coral
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
