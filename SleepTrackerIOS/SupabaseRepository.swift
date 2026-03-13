import Foundation

struct AppSnapshot: Codable, Sendable {
    var habits: [HabitDefinition]
    var dailyLogs: [String: DailyLogData]
    var pendingHabits: [HabitDefinition]?
    var pendingDailyLogs: [String: DailyLogData]

    init(
        habits: [HabitDefinition],
        dailyLogs: [String: DailyLogData],
        pendingHabits: [HabitDefinition]? = nil,
        pendingDailyLogs: [String: DailyLogData] = [:]
    ) {
        self.habits = habits
        self.dailyLogs = dailyLogs
        self.pendingHabits = pendingHabits
        self.pendingDailyLogs = pendingDailyLogs
    }

    enum CodingKeys: String, CodingKey {
        case habits
        case dailyLogs
        case pendingHabits
        case pendingDailyLogs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        habits = try container.decodeIfPresent([HabitDefinition].self, forKey: .habits) ?? []
        dailyLogs = try container.decodeIfPresent([String: DailyLogData].self, forKey: .dailyLogs) ?? [:]
        pendingHabits = try container.decodeIfPresent([HabitDefinition].self, forKey: .pendingHabits)
        pendingDailyLogs = try container.decodeIfPresent([String: DailyLogData].self, forKey: .pendingDailyLogs) ?? [:]
    }

    var hasPendingSync: Bool {
        pendingHabits != nil || !pendingDailyLogs.isEmpty
    }

    var effectiveHabits: [HabitDefinition] {
        SleepTrackerAppCore.resolvedHabits(base: habits, overlay: pendingHabits)
    }

    var effectiveDailyLogs: [String: DailyLogData] {
        SleepTrackerAppCore.mergedLogs(base: dailyLogs, overlay: pendingDailyLogs)
    }
}

protocol SleepTrackerRepository: Sendable {
    func loadCachedSnapshot() async throws -> AppSnapshot?
    func saveCachedSnapshot(_ snapshot: AppSnapshot) async throws
    func fetchSnapshot() async throws -> AppSnapshot
    func upsertDailyLog(date: String, data: DailyLogData) async throws -> DailyLogData
    func upsertHabits(_ habits: [HabitDefinition]) async throws -> [HabitDefinition]
}

actor SupabaseSleepTrackerRepository: SleepTrackerRepository {
    private let baseURL = URL(string: "https://wzvnlhctvtwaehkyeewe.supabase.co")!
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw"
    private let cacheStore = SnapshotCacheStore()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadCachedSnapshot() async throws -> AppSnapshot? {
        try await cacheStore.load()
    }

    func saveCachedSnapshot(_ snapshot: AppSnapshot) async throws {
        try await cacheStore.save(snapshot)
    }

    func fetchSnapshot() async throws -> AppSnapshot {
        async let fetchedHabits = fetchHabits()
        async let fetchedLogs = fetchLogs()
        return try await AppSnapshot(
            habits: fetchedHabits,
            dailyLogs: fetchedLogs
        )
    }

    func upsertDailyLog(date: String, data: DailyLogData) async throws -> DailyLogData {
        struct DailyLogRow: Codable {
            let date: String
            let data: DailyLogData
        }

        let payload = [DailyLogRow(date: date, data: data)]
        let body = try JSONEncoder().encode(payload)
        let request = try makeRequest(
            path: "/rest/v1/daily_logs",
            queryItems: [URLQueryItem(name: "on_conflict", value: "date")],
            method: "POST",
            body: body,
            prefer: "resolution=merge-duplicates,return=representation"
        )
        let rows = try await perform(request, decode: [DailyLogRow].self)
        return rows.first?.data ?? data
    }

    func upsertHabits(_ habits: [HabitDefinition]) async throws -> [HabitDefinition] {
        guard !habits.isEmpty else { return [] }

        let body = try JSONEncoder().encode(habits)
        let request = try makeRequest(
            path: "/rest/v1/habits",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            method: "POST",
            body: body,
            prefer: "resolution=merge-duplicates,return=representation"
        )
        let saved = try await perform(request, decode: [HabitDefinition].self)
        return sortHabits(saved)
    }

    private func fetchHabits() async throws -> [HabitDefinition] {
        let request = try makeRequest(
            path: "/rest/v1/habits",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "sort_order.asc.nullslast,created_at.asc.nullslast"),
            ]
        )

        let habits = try await perform(request, decode: [HabitDefinition].self)
        if habits.isEmpty {
            let seeded = try await upsertHabits(SleepTrackerAppCore.defaultHabits)
            return seeded.isEmpty ? SleepTrackerAppCore.defaultHabits : seeded
        }

        return sortHabits(habits)
    }

    private func fetchLogs() async throws -> [String: DailyLogData] {
        struct DailyLogRow: Codable {
            let date: String
            let data: DailyLogData
        }

        let request = try makeRequest(
            path: "/rest/v1/daily_logs",
            queryItems: [URLQueryItem(name: "select", value: "*")]
        )
        let rows = try await perform(request, decode: [DailyLogRow].self)
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.date, $0.data) })
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        prefer: String? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw RepositoryError.invalidRequest
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw RepositoryError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, decode type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RepositoryError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw RepositoryError.httpStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func sortHabits(_ habits: [HabitDefinition]) -> [HabitDefinition] {
        habits.sorted { lhs, rhs in
            let leftSort = lhs.sortOrder ?? Int.max
            let rightSort = rhs.sortOrder ?? Int.max

            if leftSort != rightSort {
                return leftSort < rightSort
            }

            return (lhs.createdAt ?? lhs.label) < (rhs.createdAt ?? rhs.label)
        }
    }
}

private struct EmptyResponse: Decodable {}

private enum RepositoryError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Could not build the Supabase request."
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .httpStatus(let code, let body):
            return "Supabase error \(code): \(body)"
        }
    }
}

private actor SnapshotCacheStore {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func load() throws -> AppSnapshot? {
        let url = try cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(AppSnapshot.self, from: data)
    }

    func save(_ snapshot: AppSnapshot) throws {
        let url = try cacheURL()
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    private func cacheURL() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return baseDirectory
            .appending(path: "SleepTrackerIOS", directoryHint: .isDirectory)
            .appending(path: "snapshot.json")
    }
}
