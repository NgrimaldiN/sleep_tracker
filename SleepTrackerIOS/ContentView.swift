import Charts
import PhotosUI
import SwiftUI

struct ContentView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var alarmModel: AlarmFeatureModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack {
            AppBackground()

            if appModel.isLoading && appModel.dailyLogs.isEmpty {
                ProgressView("Loading Sleep Tracker")
                    .tint(.white)
                    .foregroundStyle(.white)
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        HomeView(appModel: appModel, selectedTab: $selectedTab)
                    }
                    .tag(AppTab.home)
                    .tabItem {
                        Label("Home", systemImage: "waveform.path.ecg")
                    }

                    NavigationStack {
                        CheckInView(appModel: appModel)
                    }
                    .tag(AppTab.checkIn)
                    .tabItem {
                        Label("Check-In", systemImage: "camera.macro")
                    }

                    NavigationStack {
                        AlarmView(alarmModel: alarmModel)
                    }
                    .tag(AppTab.alarm)
                    .tabItem {
                        Label("Alarm", systemImage: "alarm")
                    }

                    NavigationStack {
                        InsightsView(appModel: appModel)
                    }
                    .tag(AppTab.insights)
                    .tabItem {
                        Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationStack {
                        HistoryView(appModel: appModel)
                    }
                    .tag(AppTab.history)
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                    NavigationStack {
                        SettingsView(appModel: appModel)
                    }
                    .tag(AppTab.settings)
                    .tabItem {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }
                .tint(Color.sunAccent)
            }
        }
        .task {
            if appModel.isLoading {
                await appModel.bootstrap()
            }

            if alarmModel.isLoading {
                await alarmModel.bootstrap()
            }
        }
    }
}

private enum AppTab: Hashable {
    case home
    case checkIn
    case alarm
    case insights
    case history
    case settings
}

private struct HomeView: View {
    @ObservedObject var appModel: AppModel
    @Binding var selectedTab: AppTab
    @State private var selectedMetric: DashboardMetric = .sleepScore
    @State private var selectedImpactWindow: ImpactWindow = .recent

    var body: some View {
        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: appModel.dailyLogs,
            habits: appModel.habits,
            metric: .sleepScore
        )
        let latest = SleepTrackerAppCore.historyItems(from: appModel.dailyLogs).first

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard(latest: latest, snapshot: snapshot)
                recentImpactDigestCard(snapshot: snapshot)
                recommendationCard(recommendations: snapshot.recommendations)
                insightsPreviewCard
            }
            .padding(20)
        }
        .navigationTitle("Sleep")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await appModel.refresh()
                    }
                } label: {
                    if appModel.isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .tint(.white)
            }
        }
    }

    private func heroCard(latest: SleepHistoryItem?, snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(snapshot.sleepStatus.title)
                .font(.custom("AvenirNext-Bold", size: 30))
                .foregroundStyle(.white)

            Text(snapshot.sleepStatus.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            HStack {
                Label(appModel.syncMessage, systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(statusTint(for: snapshot.sleepStatus.level).opacity(0.95))
                Spacer()
                Text("Sleep Status")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Capsule())
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(spacing: 12) {
                summaryPill(title: "Latest", value: latest?.date ?? appModel.selectedDate)
                summaryPill(title: "Score", value: latest?.score.map(String.init) ?? "--")
                summaryPill(
                    title: "Duration",
                    value: latest?.durationHours.map { String(format: "%.1fh", $0) } ?? "--"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(snapshot.sleepStatus.focusTitle)
                    .font(.headline)
                    .foregroundStyle(statusTint(for: snapshot.sleepStatus.level))
                Text(snapshot.sleepStatus.focusDetail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(16)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if !snapshot.sleepStatus.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(snapshot.sleepStatus.evidence.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(statusTint(for: snapshot.sleepStatus.level))
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)
                            Text(item.element)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.76))
                        }
                    }
                }
            }

            Button {
                selectedTab = .checkIn
            } label: {
                Label("Run Morning Check-In", systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sunAccent)
                    .foregroundStyle(Color.nightInk)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    statusGradient(for: snapshot.sleepStatus.level)
                )
        )
    }

    private func recentImpactDigestCard(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Moved Sleep Lately")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("Fast morning read: what is helping right now, what is hurting, then act on tonight's plan.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))

            HStack(spacing: 12) {
                impactHighlight(
                    title: "Helping",
                    impact: snapshot.recentImpact.topPositive,
                    tint: Color.cardTeal
                )
                impactHighlight(
                    title: "Hurting",
                    impact: snapshot.recentImpact.topNegative,
                    tint: Color.coral
                )
            }

            if let overallContext = overallContextLine(snapshot: snapshot) {
                Text(overallContext)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var insightsPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Need More Than 30 Seconds?")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("Timing factors, experiment mode, body signals, and deeper trends are now in Insights so Home stays fast.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))

            Button {
                selectedTab = .insights
            } label: {
                Label("Open Full Insights", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func signalSummaryCard(summaries: [SignalSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Body Signals")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("This compresses the Garmin metrics into the signals that matter most for what to do tonight.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(summaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                        Text(summary.value)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(summary.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(signalToneColor(summary.tone).opacity(0.16))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(signalToneColor(summary.tone).opacity(0.28), lineWidth: 1)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func overallContextLine(snapshot: DashboardSnapshot) -> String? {
        let positive = snapshot.overallImpact.topPositive?.label
        let negative = snapshot.overallImpact.topNegative?.label

        switch (positive, negative) {
        case let (positive?, negative?):
            return "Overall, \(positive) still looks strongest while \(negative) remains the main drag."
        case let (positive?, nil):
            return "Overall, \(positive) still looks like the most reliable positive habit."
        case let (nil, negative?):
            return "Overall, \(negative) still looks like the clearest thing to avoid."
        default:
            return nil
        }
    }

    private func statsGrid(snapshot: DashboardSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(snapshot.stats, id: \.title) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    Text(stat.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(stat.value)
                        .font(.custom("AvenirNext-Bold", size: 22))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
            }
        }
    }

    private var metricStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DashboardMetric.allCases, id: \.rawValue) { metric in
                    Button {
                        selectedMetric = metric
                    } label: {
                        Text(metric.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedMetric == metric ? Color.sunAccent : Color.white.opacity(0.06))
                            .foregroundStyle(selectedMetric == metric ? Color.nightInk : .white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func trendCard(snapshot: DashboardSnapshot) -> some View {
        let axisDates = SleepTrackerAppCore.chartAxisDates(for: snapshot.trend, maxLabels: 3)

        return VStack(alignment: .leading, spacing: 14) {
            Text("\(selectedMetric.title) Trend")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if snapshot.trend.isEmpty {
                emptyCard(text: "Import a few mornings to unlock trend lines.")
            } else {
                Chart(snapshot.trend) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cardTeal.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.sunAccent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisDates) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisTick()
                            .foregroundStyle(Color.white.opacity(0.25))
                        if let string = value.as(String.self) {
                            AxisValueLabel {
                                Text(SleepTrackerAppCore.compactDateLabel(for: string))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                    }
                }
                .frame(height: 236)
                .padding(.bottom, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var impactWindowStrip: some View {
        HStack(spacing: 10) {
            ForEach(ImpactWindow.allCases, id: \.rawValue) { window in
                Button {
                    selectedImpactWindow = window
                } label: {
                    Text(window.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedImpactWindow == window ? Color.sunAccent : Color.white.opacity(0.06))
                        .foregroundStyle(selectedImpactWindow == window ? Color.nightInk : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recommendationCard(recommendations: [DashboardRecommendation]) -> some View {
        let continueRecommendation = recommendations.first { $0.kind == .reinforce }
        let stopRecommendation = recommendations.first { $0.kind == .avoid }
        let tryRecommendation = recommendations.first { $0.kind == .test }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Tonight's Plan")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if recommendations.isEmpty {
                emptyCard(text: "Track a few more nights with habits to unlock recommendations.")
            } else {
                recommendationLane(
                    title: "Continue Doing",
                    recommendation: continueRecommendation,
                    fallback: "No strong keep-doing signal yet.",
                    tint: recommendationColor(for: .reinforce)
                )
                recommendationLane(
                    title: "Stop Doing",
                    recommendation: stopRecommendation,
                    fallback: "Nothing clearly harmful is active right now.",
                    tint: recommendationColor(for: .avoid)
                )
                recommendationLane(
                    title: "Try Doing",
                    recommendation: tryRecommendation,
                    fallback: "No realistic experiment is strong enough yet.",
                    tint: recommendationColor(for: .test)
                )

                Text("Recommendations only use habits the app thinks you can realistically choose tonight.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.54))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func recommendationLane(
        title: String,
        recommendation: DashboardRecommendation?,
        fallback: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
            if let recommendation {
                Text(recommendation.title)
                    .font(.headline)
                    .foregroundStyle(tint)
                Text(recommendation.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                Text(fallback)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private func experimentCard(plan: ExperimentPlan?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experiment Mode")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if let plan {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(Color.sunAccent)
                Text(plan.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                HStack(spacing: 12) {
                    summaryChip(title: "Length", value: "\(plan.durationDays) nights")
                    summaryChip(title: "Watch", value: plan.successMetric)
                }

                Text(plan.confidenceNote)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            } else {
                emptyCard(text: "Track a few more mornings before the app can propose a clean one-change experiment.")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func reliabilityCard(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Data Reliability")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(snapshot.analysisReliability.level.rawValue.capitalized)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(reliabilityTint(snapshot.analysisReliability.level).opacity(0.18))
                    .foregroundStyle(reliabilityTint(snapshot.analysisReliability.level))
                    .clipShape(Capsule())
            }

            Text(snapshot.analysisReliability.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            ForEach(snapshot.analysisReliability.evidence, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(reliabilityTint(snapshot.analysisReliability.level))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.64))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func impactOverviewCard(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Impact")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                impactHighlight(
                    title: "Recent Best",
                    impact: snapshot.recentImpact.topPositive,
                    tint: Color.cardTeal
                )
                impactHighlight(
                    title: "Overall Best",
                    impact: snapshot.overallImpact.topPositive,
                    tint: Color.sunAccent
                )
            }

            HStack(spacing: 12) {
                impactHighlight(
                    title: "Recent Drag",
                    impact: snapshot.recentImpact.topNegative,
                    tint: Color.coral
                )
                impactHighlight(
                    title: "Overall Drag",
                    impact: snapshot.overallImpact.topNegative,
                    tint: Color.roseClay
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func impactLeaderboardCard(summary: ImpactSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedImpactWindow == .recent ? "Recent Habit Impact" : "Overall Habit Impact")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if summary.leaderboard.isEmpty {
                emptyCard(text: "Not enough habit data yet.")
            } else {
                ForEach(summary.leaderboard.prefix(8)) { impact in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(impact.label)
                                .foregroundStyle(.white)
                            Text(impactDetail(for: impact))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        if impact.isSignificant {
                            Text(signedImpactString(impact))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(impact.impact >= 0 ? Color.cardTeal : Color.coral)
                        } else {
                            Text("Need 3+ nights")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func impactHighlight(title: String, impact: HabitImpact?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            if let impact {
                Text(impact.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(signedImpactString(impact))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
            } else {
                Text("Not enough data")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private func impactDetail(for impact: HabitImpact) -> String {
        let comparison = impact.comparisonCount > 0 ? "\(impact.comparisonCount) comparison nights" : "No comparison nights yet"
        return "\(impact.sampleCount) tracked nights • \(comparison)"
    }

    private func signedImpactString(_ impact: HabitImpact) -> String {
        let prefix = impact.impact >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", impact.impact))\(selectedMetric.unit)"
    }

    private func recommendationColor(for kind: RecommendationKind) -> Color {
        switch kind {
        case .reinforce:
            return Color.cardTeal
        case .avoid:
            return Color.coral
        case .test:
            return Color.sunAccent
        }
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private func statusGradient(for level: SleepStatusLevel) -> LinearGradient {
        switch level {
        case .strong:
            return LinearGradient(
                colors: [Color.cardTeal, Color.cardBlue.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .steady:
            return LinearGradient(
                colors: [Color.cardBlue, Color.sunAccent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .watch:
            return LinearGradient(
                colors: [Color.roseClay, Color.coral.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .lowData:
            return LinearGradient(
                colors: [Color.cardBlue, Color.black.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func statusTint(for level: SleepStatusLevel) -> Color {
        switch level {
        case .strong:
            return Color.cardTeal
        case .steady:
            return Color.sunAccent
        case .watch:
            return Color.coral
        case .lowData:
            return .white
        }
    }

    private func signalToneColor(_ tone: SignalTone) -> Color {
        switch tone {
        case .positive:
            return Color.cardTeal
        case .neutral:
            return Color.sunAccent
        case .caution:
            return Color.coral
        }
    }

    private func reliabilityTint(_ level: AnalysisReliabilityLevel) -> Color {
        switch level {
        case .high:
            return Color.cardTeal
        case .medium:
            return Color.sunAccent
        case .low:
            return Color.coral
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.18))
        .clipShape(Capsule())
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.62))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
    }
}

private enum ImpactWindow: String, CaseIterable {
    case recent
    case overall

    var title: String {
        switch self {
        case .recent:
            return "Past 7"
        case .overall:
            return "Overall"
        }
    }
}

private struct InsightsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedMetric: DashboardMetric = .sleepScore
    @State private var selectedImpactWindow: ImpactWindow = .recent

    var body: some View {
        let snapshot = SleepTrackerAppCore.dashboardSnapshot(
            logs: appModel.dailyLogs,
            habits: appModel.habits,
            metric: selectedMetric
        )
        let timingSummary = selectedImpactWindow == .recent ? snapshot.recentTimingImpact : snapshot.overallTimingImpact

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                experimentFocusCard(snapshot: snapshot)
                reliabilityDeepDive(snapshot: snapshot)
                timingImpactOverviewCard(snapshot: snapshot)
                metricStrip
                impactWindowStrip
                timingLeaderboardCard(summary: timingSummary)
                signalDeck(snapshot: snapshot)
            }
            .padding(20)
        }
        .navigationTitle("Insights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await appModel.refresh()
                    }
                } label: {
                    if appModel.isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .tint(.white)
            }
        }
    }

    private func experimentFocusCard(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What To Do Next")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if let plan = snapshot.experimentPlan {
                Text(plan.title)
                    .font(.custom("AvenirNext-Bold", size: 28))
                    .foregroundStyle(Color.sunAccent)
                Text(plan.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))

                HStack(spacing: 12) {
                    insightChip(title: "Length", value: "\(plan.durationDays) nights")
                    insightChip(title: "Watch", value: plan.successMetric)
                }

                Text(plan.confidenceNote)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                insightPlaceholder("Import more mornings and complete habit check-ins to unlock a cleaner experiment suggestion.")
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.cardBlue, Color.sunAccent.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func reliabilityDeepDive(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Why The App Believes This")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(snapshot.analysisReliability.title)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(reliabilityTint(snapshot.analysisReliability.level).opacity(0.16))
                    .foregroundStyle(reliabilityTint(snapshot.analysisReliability.level))
                    .clipShape(Capsule())
            }

            Text(snapshot.analysisReliability.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.analysisReliability.evidence, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(reliabilityTint(snapshot.analysisReliability.level))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(item)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func timingImpactOverviewCard(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automatic Sleep Timing Levers")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("These are derived from the Garmin sleep times, wake times, duration, and regularity you already import.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))

            HStack(spacing: 12) {
                timingHighlight(
                    title: "Recent Best",
                    impact: snapshot.recentTimingImpact.topPositive,
                    tint: Color.cardTeal
                )
                timingHighlight(
                    title: "Recent Drag",
                    impact: snapshot.recentTimingImpact.topNegative,
                    tint: Color.coral
                )
            }

            HStack(spacing: 12) {
                timingHighlight(
                    title: "Overall Best",
                    impact: snapshot.overallTimingImpact.topPositive,
                    tint: Color.sunAccent
                )
                timingHighlight(
                    title: "Overall Drag",
                    impact: snapshot.overallTimingImpact.topNegative,
                    tint: Color.roseClay
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func timingLeaderboardCard(summary: ImpactSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedImpactWindow == .recent ? "Recent Timing Factors" : "Overall Timing Factors")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if summary.leaderboard.isEmpty {
                insightPlaceholder("Import a few nights to let the app compare timing windows and regularity patterns.")
            } else {
                ForEach(summary.leaderboard.prefix(8)) { impact in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(impact.label)
                                .foregroundStyle(.white)
                            Text("\(impact.sampleCount) matching nights • \(impact.comparisonCount) comparison nights")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        Spacer()
                        if impact.isSignificant {
                            Text(signedImpactString(impact))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(impact.impact >= 0 ? Color.cardTeal : Color.coral)
                        } else {
                            Text("Need 3+ nights")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func signalDeck(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body Signal Readout")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if snapshot.signalSummaries.isEmpty {
                insightPlaceholder("Import a full Garmin night to unlock the deeper body-signal readout.")
            } else {
                ForEach(snapshot.signalSummaries) { summary in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(summary.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(summary.value)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(signalTint(summary.tone))
                        }
                        Text(summary.detail)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var metricStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DashboardMetric.allCases, id: \.rawValue) { metric in
                    Button {
                        selectedMetric = metric
                    } label: {
                        Text(metric.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedMetric == metric ? Color.sunAccent : Color.white.opacity(0.06))
                            .foregroundStyle(selectedMetric == metric ? Color.nightInk : .white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var impactWindowStrip: some View {
        HStack(spacing: 10) {
            ForEach(ImpactWindow.allCases, id: \.rawValue) { window in
                Button {
                    selectedImpactWindow = window
                } label: {
                    Text(window.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedImpactWindow == window ? Color.sunAccent : Color.white.opacity(0.06))
                        .foregroundStyle(selectedImpactWindow == window ? Color.nightInk : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timingHighlight(title: String, impact: HabitImpact?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            if let impact {
                Text(impact.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(signedImpactString(impact))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
            } else {
                Text("Not enough data")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private func insightChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private func insightPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.62))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
    }

    private func reliabilityTint(_ level: AnalysisReliabilityLevel) -> Color {
        switch level {
        case .high:
            return Color.cardTeal
        case .medium:
            return Color.sunAccent
        case .low:
            return Color.coral
        }
    }

    private func signalTint(_ tone: SignalTone) -> Color {
        switch tone {
        case .positive:
            return Color.cardTeal
        case .neutral:
            return Color.sunAccent
        case .caution:
            return Color.coral
        }
    }

    private func signedImpactString(_ impact: HabitImpact) -> String {
        let prefix = impact.impact >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", impact.impact))\(selectedMetric.unit)"
    }
}

private struct CheckInView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var importViewModel = ImportViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        let habitCheckInDate = importViewModel.record?.sleepDate ?? appModel.selectedDate

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                importCard
                NavigationLink {
                    HabitCheckInView(appModel: appModel, date: habitCheckInDate)
                } label: {
                    habitsCard(for: habitCheckInDate)
                }
                .buttonStyle(.plain)
                .disabled(importViewModel.isImporting)
                .opacity(importViewModel.isImporting ? 0.6 : 1)

                if !importViewModel.summaryRows.isEmpty {
                    parsedSummaryCard
                }

                if !importViewModel.debugSections.isEmpty {
                    debugCard
                }
            }
            .padding(20)
        }
        .navigationTitle("Morning Check-In")
        .onChange(of: pickerItems) { _, newItems in
            guard newItems.count == 3 else { return }
            Task {
                do {
                    let orderedData = try await loadOrderedData(from: newItems)
                    await importViewModel.importSelectionData(orderedData, using: appModel)
                } catch {
                    importViewModel.errorMessage = "Could not load the selected screenshots."
                }
            }
        }
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Import")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Open the photo library once, then tap the Garmin screenshots in this order: summary, timeline, metrics.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 3,
                selectionBehavior: .ordered,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Select 3 Garmin Screenshots", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.sunAccent)
                    .foregroundStyle(Color.nightInk)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            ForEach(importViewModel.slotStates) { state in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(state.slot.rawValue + 1). \(state.slot.title)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(state.slot.helperText)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if state.hasImage {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.cardTeal)
                    } else {
                        Image(systemName: "circle.dashed")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }

            if importViewModel.isImporting {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Parsing and saving...")
                        .foregroundStyle(.white)
                }
            }

            if let successMessage = importViewModel.successMessage {
                banner(text: successMessage, kind: .success)
            }

            if let errorMessage = importViewModel.errorMessage {
                banner(text: errorMessage, kind: .error)
            }

            Button("Clear Selection") {
                pickerItems = []
                importViewModel.clear()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func habitsCard(for targetDate: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habits")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("Log what you did before bed for \(targetDate). After an import, this date automatically switches to the night from the screenshots you just selected.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
            Label("Open Habit Check-In for \(targetDate)", systemImage: "list.bullet.clipboard")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.08))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var parsedSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Import")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            ForEach(importViewModel.summaryRows) { row in
                HStack {
                    Text(row.label)
                        .foregroundStyle(.white.opacity(0.62))
                    Spacer()
                    Text(row.value)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var debugCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OCR Debug")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            DisclosureGroup("Show OCR lines") {
                VStack(spacing: 12) {
                    ForEach(importViewModel.debugSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(section.lines.joined(separator: "\n"))
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.82))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                        )
                    }
                }
                .padding(.top, 8)
            }
            .tint(.white)
            .foregroundStyle(.white)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func banner(text: String, kind: BannerKind) -> some View {
        let tint = kind == .success ? Color.cardTeal : Color.coral

        return HStack {
            Image(systemName: kind == .success ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.18))
        .foregroundStyle(tint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func loadOrderedData(
        from items: [PhotosPickerItem]
    ) async throws -> [ImportViewModel.Slot: Data] {
        var loaded: [ImportViewModel.Slot: Data] = [:]

        for (index, item) in items.enumerated() {
            guard let slot = ImportViewModel.Slot(rawValue: index) else { continue }
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoLoadError.emptyData(slot.title)
            }
            loaded[slot] = data
        }

        return loaded
    }
}

private enum BannerKind {
    case success
    case error
}

private enum PhotoLoadError: LocalizedError {
    case emptyData(String)

    var errorDescription: String? {
        switch self {
        case .emptyData(let slot):
            return "Could not load \(slot.lowercased()) image data."
        }
    }
}

private struct HabitCheckInView: View {
    @ObservedObject var appModel: AppModel
    let date: String
    @State private var notesDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(date)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sunAccent)

                ForEach(appModel.habits.filter { $0.archivedAt == nil }) { habit in
                    HabitRow(appModel: appModel, date: date, habit: habit)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundStyle(.white)
                    TextField("Anything unusual last night?", text: $notesDraft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .foregroundStyle(.white)

                    Button("Save Notes") {
                        Task {
                            await appModel.updateNotes(notesDraft, on: date)
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(20)
        }
        .navigationTitle("Habits")
        .onAppear {
            notesDraft = appModel.dailyLogs[date]?.notes ?? ""
        }
        .onChange(of: date) { _, newDate in
            notesDraft = appModel.dailyLogs[newDate]?.notes ?? ""
        }
    }
}

private struct HabitRow: View {
    @ObservedObject var appModel: AppModel
    let date: String
    let habit: HabitDefinition

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        let log = appModel.dailyLogs[date] ?? DailyLogData()
        let isActive = log.habits.contains(habit.id)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.label)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(habit.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                if habit.type == .boolean {
                    Button {
                        Task {
                            await appModel.toggleHabit(habit.id, on: date)
                        }
                    } label: {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isActive ? Color.cardTeal : .white.opacity(0.4))
                    }
                }
            }

            switch habit.type {
            case .boolean:
                EmptyView()
            case .number:
                TextField(
                    "Enter a number",
                    text: Binding(
                        get: { log.habitValues[habit.id]?.stringValue ?? "" },
                        set: { newValue in
                            Task {
                                await appModel.setHabitValue(
                                    newValue.isEmpty ? nil : .number(Double(newValue) ?? 0),
                                    for: habit.id,
                                    on: date
                                )
                            }
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            case .select:
                Picker(
                    "Value",
                    selection: Binding(
                        get: { log.habitValues[habit.id]?.stringValue ?? "" },
                        set: { newValue in
                            Task {
                                await appModel.setHabitValue(
                                    newValue.isEmpty ? nil : .string(newValue),
                                    for: habit.id,
                                    on: date
                                )
                            }
                        }
                    )
                ) {
                    Text("Select").tag("")
                    ForEach(habit.options ?? [], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            case .time:
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { timeValue(for: log.habitValues[habit.id]?.stringValue) },
                        set: { newDate in
                            Task {
                                await appModel.setHabitValue(
                                    .string(Self.timeFormatter.string(from: newDate)),
                                    for: habit.id,
                                    on: date
                                )
                            }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .tint(Color.sunAccent)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func timeValue(for stored: String?) -> Date {
        guard let stored, let date = Self.timeFormatter.date(from: stored) else {
            return Date()
        }

        return date
    }
}

private struct HistoryView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        let items = SleepTrackerAppCore.historyItems(from: appModel.dailyLogs)

        List(items) { item in
            NavigationLink {
                NightDetailView(
                    date: item.date,
                    entry: appModel.dailyLogs[item.date] ?? DailyLogData(),
                    habits: appModel.habits
                )
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.date)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                    HStack(spacing: 12) {
                        Text(item.score.map { "Score \($0)" } ?? "Score --")
                        Text(item.durationHours.map { String(format: "%.1fh", $0) } ?? "Duration --")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sunAccent)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("History")
    }
}

private struct NightDetailView: View {
    let date: String
    let entry: DailyLogData
    let habits: [HabitDefinition]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailCard(title: "Sleep") {
                    detailRow("Score", entry.sleepScore.map(String.init) ?? "--")
                    detailRow("Quality", entry.sleepQuality ?? "--")
                    detailRow("Summary", entry.summaryHeadline ?? "--")
                    detailRow("Bedtime", entry.bedtime ?? "--")
                    detailRow("Wake", entry.waketime ?? "--")
                    detailRow("Duration", entry.totalDurationHours.map { String(format: "%.1fh", $0) } ?? "--")
                }

                detailCard(title: "Stages") {
                    detailRow("Deep", stageString(hours: entry.deepHours, minutes: entry.deepMinutes))
                    detailRow("Light", stageString(hours: entry.lightHours, minutes: entry.lightMinutes))
                    detailRow("REM", stageString(hours: entry.remHours, minutes: entry.remMinutes))
                    detailRow("Awake", entry.awakeMinutes.map { "\($0)m" } ?? "--")
                }

                detailCard(title: "Metrics") {
                    detailRow("Breathing Variations", entry.breathingVariations ?? "--")
                    detailRow("Restless Moments", entry.restlessMoments.map(String.init) ?? "--")
                    detailRow("Resting HR", entry.restingHeartRate.map { "\($0) bpm" } ?? "--")
                    detailRow("Body Battery Change", entry.bodyBatteryChange.map { signedValue($0) } ?? "--")
                    detailRow("Avg SpO2", entry.averageSpO2.map { "\($0)%" } ?? "--")
                    detailRow("Lowest SpO2", entry.lowestSpO2.map { "\($0)%" } ?? "--")
                    detailRow("Avg Respiration", entry.averageRespiration.map { String(format: "%.1f brpm", $0) } ?? "--")
                    detailRow("Lowest Respiration", entry.lowestRespiration.map { String(format: "%.1f brpm", $0) } ?? "--")
                    detailRow("Avg Overnight HRV", entry.averageOvernightHRV.map { "\($0) ms" } ?? "--")
                    detailRow("7d Avg HRV", entry.sevenDayHRVStatus ?? "--")
                    detailRow("Skin Temp", entry.averageSkinTemperatureChangeCelsius.map(skinTempString) ?? "--")
                }

                detailCard(title: "Import") {
                    detailRow("Imported At", entry.importedAt ?? "--")
                }

                if !entry.habits.isEmpty || !entry.habitValues.isEmpty {
                    detailCard(title: "Habits") {
                        ForEach(habitRows, id: \.label) { row in
                            detailRow(row.label, row.value)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(date)
    }

    private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private func stageString(hours: Int?, minutes: Int?) -> String {
        guard let hours, let minutes else { return "--" }
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var habitRows: [(label: String, value: String)] {
        let labels = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0.label) })
        let activeHabits = entry.habits.map { habitID in
            (label: labels[habitID] ?? habitID, value: entry.habitValues[habitID]?.stringValue ?? "Yes")
        }
        let extraValues = entry.habitValues
            .filter { entry.habits.contains($0.key) == false }
            .map { habitID, value in
                (label: labels[habitID] ?? habitID, value: value.stringValue ?? "--")
            }

        return (activeHabits + extraValues).sorted { $0.label < $1.label }
    }

    private func signedValue(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func skinTempString(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", value)) C"
    }
}

private struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var newHabitLabel = ""
    @State private var newHabitType: HabitType = .boolean
    @State private var newHabitOptions = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoCard
                addHabitCard
                starterHabitsCard
                existingHabitsCard
            }
            .padding(20)
        }
        .navigationTitle("Settings")
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("Backend sync: \(appModel.syncMessage)")
                .foregroundStyle(.white.opacity(0.72))
            Text("Import order: Summary -> Timeline -> Metrics")
                .foregroundStyle(.white.opacity(0.72))
            Text("Skin temperature is optional and blank Garmin values are accepted.")
                .foregroundStyle(.white.opacity(0.72))
            Text("Habit changes here sync to the same Supabase backend as the web app.")
                .foregroundStyle(.white.opacity(0.72))
            if let errorMessage = appModel.errorMessage {
                Text("Last sync error: \(errorMessage)")
                    .foregroundStyle(Color.coral)
            }
            Button {
                Task {
                    await appModel.refresh()
                }
            } label: {
                if appModel.isSyncing {
                    ProgressView()
                } else {
                    Label("Refresh from Supabase", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var addHabitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Habit")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            TextField("Habit label", text: $newHabitLabel)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)

            Picker("Type", selection: $newHabitType) {
                ForEach(HabitType.allCases, id: \.rawValue) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if newHabitType == .select {
                TextField("Options separated by commas", text: $newHabitOptions)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
            }

            Button("Add Habit") {
                let options = newHabitOptions
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                Task {
                    await appModel.addHabit(label: newHabitLabel, type: newHabitType, options: options)
                    newHabitLabel = ""
                    newHabitType = .boolean
                    newHabitOptions = ""
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.sunAccent)
            .foregroundStyle(Color.nightInk)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .disabled(newHabitLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var existingHabitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Habits")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            ForEach(appModel.habits.filter { $0.archivedAt == nil }) { habit in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.label)
                            .foregroundStyle(.white)
                        Text(habit.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button("Archive") {
                        Task {
                            await appModel.archiveHabit(habit)
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.coral)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var starterHabitsCard: some View {
        let activeHabitIDs = Set(appModel.habits.map(\.id))
        let suggestions = SleepTrackerAppCore.recommendedStarterHabits.filter { !activeHabitIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Starter Habits")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("Quick-add common habits so you do not have to type every one by hand.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))

            if suggestions.isEmpty {
                Text("All starter habits are already in your tracker.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.56))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(suggestions) { habit in
                        Button {
                            Task {
                                await appModel.addHabitDefinition(habit)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(habit.label)
                                    .lineLimit(2)
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.12),
                Color(red: 0.02, green: 0.03, blue: 0.07),
                Color.black,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.sunAccent.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: 90, y: -80)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.cardTeal.opacity(0.15))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -80, y: 120)
        }
    }
}

extension Color {
    static let nightInk = Color(red: 0.03, green: 0.05, blue: 0.08)
    static let sunAccent = Color(red: 0.95, green: 0.74, blue: 0.26)
    static let cardBlue = Color(red: 0.07, green: 0.20, blue: 0.38)
    static let cardTeal = Color(red: 0.12, green: 0.72, blue: 0.68)
    static let coral = Color(red: 0.95, green: 0.42, blue: 0.36)
    static let roseClay = Color(red: 0.72, green: 0.40, blue: 0.45)
}
