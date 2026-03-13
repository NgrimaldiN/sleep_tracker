import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private let repository: any SleepTrackerRepository
    private var pendingDailyLogs: [String: DailyLogData] = [:]
    private var pendingHabits: [HabitDefinition]?

    @Published var selectedDate = AppModel.defaultSelectedDate()
    @Published var habits: [HabitDefinition] = []
    @Published var dailyLogs: [String: DailyLogData] = [:]
    @Published var isLoading = true
    @Published var isSyncing = false
    @Published var syncMessage = "Loading..."
    @Published var errorMessage: String?

    init(repository: any SleepTrackerRepository = SupabaseSleepTrackerRepository()) {
        self.repository = repository
    }

    var currentLog: DailyLogData {
        dailyLogs[selectedDate] ?? DailyLogData()
    }

    func bootstrap() async {
        isLoading = true
        errorMessage = nil

        if let cached = try? await repository.loadCachedSnapshot() {
            applySnapshot(cached)
            syncMessage = cached.hasPendingSync ? "Loaded cached data, pending sync" : "Loaded cached data"
        }

        await syncPendingChangesIfNeeded()

        do {
            let snapshot = try await repository.fetchSnapshot()
            let mergedSnapshot = mergedSnapshot(with: snapshot)
            applySnapshot(mergedSnapshot)
            syncMessage = mergedSnapshot.hasPendingSync ? "Using local changes until sync succeeds" : "Synced with Supabase"
            try? await repository.saveCachedSnapshot(mergedSnapshot)
        } catch {
            if habits.isEmpty && dailyLogs.isEmpty {
                habits = SleepTrackerAppCore.defaultHabits
                syncMessage = "Using local defaults"
            } else {
                syncMessage = hasPendingSync ? "Using cached data, pending sync" : "Using cached data"
            }

            errorMessage = error.localizedDescription
            try? await repository.saveCachedSnapshot(currentSnapshot())
        }

        ensureCurrentDateExists()
        isLoading = false
    }

    func refresh() async {
        isSyncing = true
        defer { isSyncing = false }

        await syncPendingChangesIfNeeded()

        do {
            let snapshot = try await repository.fetchSnapshot()
            let mergedSnapshot = mergedSnapshot(with: snapshot)
            applySnapshot(mergedSnapshot)
            syncMessage = mergedSnapshot.hasPendingSync ? "Refreshed, pending sync remains" : "Synced just now"
            try? await repository.saveCachedSnapshot(mergedSnapshot)
            ensureCurrentDateExists()
        } catch {
            errorMessage = error.localizedDescription
            syncMessage = hasPendingSync ? "Refresh failed, pending sync kept locally" : "Refresh failed"
            try? await repository.saveCachedSnapshot(currentSnapshot())
        }
    }

    func saveImportedRecord(_ record: GarminSleepRecord) async {
        let merged = SleepTrackerAppCore.mergeImportedRecord(record, into: dailyLogs[record.sleepDate])
        dailyLogs[record.sleepDate] = merged
        selectedDate = record.sleepDate
        await persist(date: record.sleepDate)
    }

    func toggleHabit(_ habitID: String, on date: String) async {
        var log = dailyLogs[date] ?? DailyLogData()
        if log.habits.contains(habitID) {
            log.habits.removeAll { $0 == habitID }
        } else {
            log.habits.append(habitID)
        }

        dailyLogs[date] = log
        await persist(date: date)
    }

    func setHabitValue(_ value: HabitValue?, for habitID: String, on date: String) async {
        var log = dailyLogs[date] ?? DailyLogData()

        if let value {
            log.habitValues[habitID] = value
            if !log.habits.contains(habitID) {
                log.habits.append(habitID)
            }
        } else {
            log.habitValues.removeValue(forKey: habitID)
            log.habits.removeAll { $0 == habitID }
        }

        dailyLogs[date] = log
        await persist(date: date)
    }

    func updateNotes(_ notes: String, on date: String) async {
        var log = dailyLogs[date] ?? DailyLogData()
        log.notes = notes
        dailyLogs[date] = log
        await persist(date: date)
    }

    func addHabit(label: String, type: HabitType, options: [String]) async {
        let id = label
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        guard !id.isEmpty, habits.contains(where: { $0.id == id }) == false else {
            return
        }

        let newHabit = HabitDefinition(
            id: id,
            label: label,
            type: type,
            options: options.isEmpty ? nil : options,
            sortOrder: (habits.map(\.sortOrder).compactMap { $0 }.max() ?? habits.count) + 1
        )

        await addHabitDefinition(newHabit)
    }

    func addHabitDefinition(_ habit: HabitDefinition) async {
        guard habits.contains(where: { $0.id == habit.id }) == false else {
            return
        }

        var newHabit = habit
        if newHabit.sortOrder == nil {
            newHabit.sortOrder = (habits.map(\.sortOrder).compactMap { $0 }.max() ?? habits.count) + 1
        }

        habits.append(newHabit)
        await persistHabits()
    }

    func archiveHabit(_ habit: HabitDefinition) async {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return
        }

        habits[index].archivedAt = ISO8601DateFormatter().string(from: Date())
        await persistHabits()
    }

    private func persist(date: String) async {
        guard let log = dailyLogs[date] else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let savedLog = try await repository.upsertDailyLog(date: date, data: log)
            dailyLogs[date] = savedLog
            pendingDailyLogs.removeValue(forKey: date)
            errorMessage = nil
            try? await repository.saveCachedSnapshot(currentSnapshot())
            syncMessage = "Saved \(date)"
        } catch {
            errorMessage = error.localizedDescription
            pendingDailyLogs[date] = log
            syncMessage = "Saved locally, will retry sync"
            try? await repository.saveCachedSnapshot(currentSnapshot())
        }
    }

    private func persistHabits() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            habits = try await repository.upsertHabits(habits)
            pendingHabits = nil
            errorMessage = nil
            try? await repository.saveCachedSnapshot(currentSnapshot())
            syncMessage = "Habits synced"
        } catch {
            errorMessage = error.localizedDescription
            pendingHabits = habits
            syncMessage = "Habits saved locally, will retry sync"
            try? await repository.saveCachedSnapshot(currentSnapshot())
        }
    }

    private var hasPendingSync: Bool {
        pendingHabits != nil || !pendingDailyLogs.isEmpty
    }

    private func applySnapshot(_ snapshot: AppSnapshot) {
        pendingHabits = snapshot.pendingHabits
        pendingDailyLogs = snapshot.pendingDailyLogs
        habits = snapshot.effectiveHabits
        dailyLogs = snapshot.effectiveDailyLogs
    }

    private func mergedSnapshot(with remoteSnapshot: AppSnapshot) -> AppSnapshot {
        AppSnapshot(
            habits: remoteSnapshot.habits,
            dailyLogs: remoteSnapshot.dailyLogs,
            pendingHabits: pendingHabits,
            pendingDailyLogs: pendingDailyLogs
        )
    }

    private func currentSnapshot() -> AppSnapshot {
        AppSnapshot(
            habits: habits,
            dailyLogs: dailyLogs,
            pendingHabits: pendingHabits,
            pendingDailyLogs: pendingDailyLogs
        )
    }

    private func syncPendingChangesIfNeeded() async {
        guard hasPendingSync else {
            return
        }

        var latestError: Error?

        if let pendingHabits {
            do {
                habits = try await repository.upsertHabits(pendingHabits)
                self.pendingHabits = nil
            } catch {
                latestError = error
            }
        }

        for date in pendingDailyLogs.keys.sorted() {
            guard let pendingLog = pendingDailyLogs[date] else {
                continue
            }

            do {
                let savedLog = try await repository.upsertDailyLog(date: date, data: pendingLog)
                dailyLogs[date] = savedLog
                pendingDailyLogs.removeValue(forKey: date)
            } catch {
                latestError = error
            }
        }

        if let latestError {
            errorMessage = latestError.localizedDescription
        } else {
            errorMessage = nil
        }

        try? await repository.saveCachedSnapshot(currentSnapshot())
    }

    private func ensureCurrentDateExists() {
        if dailyLogs[selectedDate] == nil {
            dailyLogs[selectedDate] = DailyLogData()
        }
    }

    static func defaultSelectedDate() -> String {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: targetDate)
    }

    nonisolated static let defaultHabits = SleepTrackerAppCore.defaultHabits
}
