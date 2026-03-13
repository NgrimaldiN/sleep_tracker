import Foundation

@MainActor
final class ImportViewModel: ObservableObject {
    enum Slot: Int, CaseIterable {
        case summary
        case timeline
        case metrics

        var title: String {
            switch self {
            case .summary: return "Summary"
            case .timeline: return "Timeline"
            case .metrics: return "Metrics"
            }
        }

        var helperText: String {
            switch self {
            case .summary: return "Score, quality, duration"
            case .timeline: return "Sleep chart with bedtime/waketime"
            case .metrics: return "Stages and Garmin metrics"
            }
        }

        var fileName: String { "\(title.lowercased()).jpeg" }
    }

    @Published private(set) var selectedData: [Slot: Data] = [:]
    @Published private(set) var record: GarminSleepRecord?
    @Published private(set) var debugSections: [OCRDebugSection] = []
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var slotStates: [SlotState] {
        Slot.allCases.map { slot in
            SlotState(
                slot: slot,
                hasImage: selectedData[slot] != nil,
                byteCount: selectedData[slot]?.count ?? 0
            )
        }
    }

    var summaryRows: [RecordRow] {
        guard let record else { return [] }

        return [
            RecordRow(label: "Date", value: record.sleepDate),
            RecordRow(label: "Score", value: "\(record.sleepScore)"),
            RecordRow(label: "Duration", value: format(minutes: record.totalSleepMinutes)),
            RecordRow(label: "Bedtime", value: record.bedtime),
            RecordRow(label: "Wake", value: record.wakeTime),
            RecordRow(label: "HRV", value: "\(record.averageOvernightHRV) ms"),
            RecordRow(label: "Avg SpO2", value: "\(record.averageSpO2)%"),
        ]
    }

    func importSelectionData(_ orderedData: [Slot: Data], using appModel: AppModel) async {
        guard orderedData.count == Slot.allCases.count else {
            errorMessage = "Pick exactly 3 screenshots in this order: summary, timeline, metrics."
            return
        }

        isImporting = true
        errorMessage = nil
        successMessage = nil
        debugSections = []
        record = nil

        do {
            selectedData = orderedData

            let result = try await Task.detached(priority: .userInitiated) { [selectedData] in
                try Self.runImport(selectedData: selectedData, importedAt: Date())
            }.value

            debugSections = result.debugSections.map { OCRDebugSection(title: $0.title, lines: $0.lines) }
            record = result.record

            if let parserError = result.parserError {
                errorMessage = Self.errorMessage(for: parserError)
            } else if let record = result.record {
                await appModel.saveImportedRecord(record)
                successMessage = "Imported and saved \(record.sleepDate)"
            }
        } catch {
            errorMessage = Self.errorMessage(for: error)
        }

        isImporting = false
    }

    func clear() {
        selectedData = [:]
        record = nil
        debugSections = []
        errorMessage = nil
        successMessage = nil
    }

    private nonisolated static func runImport(
        selectedData: [Slot: Data],
        importedAt: Date
    ) throws -> ImportPipelineResult {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let summaryURL = tempDirectory.appending(path: Slot.summary.fileName)
        let timelineURL = tempDirectory.appending(path: Slot.timeline.fileName)
        let metricsURL = tempDirectory.appending(path: Slot.metrics.fileName)

        guard let summaryData = selectedData[.summary],
              let timelineData = selectedData[.timeline],
              let metricsData = selectedData[.metrics]
        else {
            throw ImportPipelineError.missingOrderedData
        }

        try summaryData.write(to: summaryURL)
        try timelineData.write(to: timelineURL)
        try metricsData.write(to: metricsURL)

        let recognizer = VisionOCRRecognizer()
        let summaryLines = try recognizer.recognizeText(in: summaryURL)
        let timelineLines = try recognizer.recognizeText(in: timelineURL)
        let metricsLines = try recognizer.recognizeText(in: metricsURL)
        let debugSections = [
            makeDebugSection(title: "Summary", lines: summaryLines),
            makeDebugSection(title: "Timeline", lines: timelineLines),
            makeDebugSection(title: "Metrics", lines: metricsLines),
        ]

        let parser = GarminSleepParser(ocrRecognizer: recognizer)

        do {
            let record = try parser.parseNight(
                summaryLines: summaryLines,
                timelineLines: timelineLines,
                metricsLines: metricsLines,
                importedAt: importedAt
            )

            return ImportPipelineResult(record: record, debugSections: debugSections, parserError: nil)
        } catch let error as GarminSleepParserError {
            return ImportPipelineResult(record: nil, debugSections: debugSections, parserError: error)
        }
    }

    private nonisolated static func makeDebugSection(title: String, lines: [RecognizedLine]) -> OCRDebugSnapshot {
        let formattedLines = lines
            .sorted { lhs, rhs in
                if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.0001 {
                    return lhs.boundingBox.midY > rhs.boundingBox.midY
                }

                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            .map { line in
                String(format: "y %.3f x %.3f %@", line.boundingBox.midY, line.boundingBox.minX, line.text)
            }

        return OCRDebugSnapshot(title: title, lines: formattedLines)
    }

    private nonisolated static func errorMessage(for error: Error) -> String {
        if let parserError = error as? GarminSleepParserError {
            return errorMessage(for: parserError)
        }

        return "Import failed. \(error.localizedDescription)"
    }

    private nonisolated static func errorMessage(for error: GarminSleepParserError) -> String {
        switch error {
        case .missingField(let field):
            return "Import failed. Could not read \(field)."
        case .notImplemented:
            return "Import failed. OCR is not available in this build."
        }
    }

    private func format(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(remainder)m"
    }
}

struct SlotState: Identifiable {
    let slot: ImportViewModel.Slot
    let hasImage: Bool
    let byteCount: Int

    var id: Int { slot.rawValue }
}

struct RecordRow: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct OCRDebugSection: Identifiable {
    let title: String
    let lines: [String]

    var id: String { title }
}

private struct ImportPipelineResult: Sendable {
    let record: GarminSleepRecord?
    let debugSections: [OCRDebugSnapshot]
    let parserError: GarminSleepParserError?
}

private struct OCRDebugSnapshot: Sendable {
    let title: String
    let lines: [String]
}

private enum ImportPipelineError: LocalizedError {
    case missingOrderedData

    var errorDescription: String? {
        switch self {
        case .missingOrderedData:
            return "Three ordered screenshots are required."
        }
    }
}
