import CoreML
import CreateML
import Foundation

struct TrainerConfiguration {
    let datasetDirectory: URL
    let modelOutputURL: URL
    let compiledOutputDirectory: URL?
}

enum TrainerError: LocalizedError {
    case invalidArguments
    case datasetMissing(URL)
    case unsupportedDatasetLayout(URL)
    case noAudioFiles(URL)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return """
            Usage:
              xcrun swift scripts/train_shower_classifier.swift \
                --dataset /abs/path/to/labeled_dirs \
                --model-output /abs/path/to/ShowerSoundClassifier.mlmodel \
                [--compiled-output-dir /abs/path/to/output_dir]
            """
        case .datasetMissing(let url):
            return "Dataset directory does not exist: \(url.path)"
        case .unsupportedDatasetLayout(let url):
            return """
            Dataset directory must contain at least:
              \(url.path)/shower_on/
              \(url.path)/not_shower/
            with PCM .wav or .caf files inside.
            """
        case .noAudioFiles(let url):
            return "No supported audio files were found in \(url.path)"
        }
    }
}

func parseConfiguration(arguments: [String]) throws -> TrainerConfiguration {
    var datasetDirectory: URL?
    var modelOutputURL: URL?
    var compiledOutputDirectory: URL?
    var index = 1

    while index < arguments.count {
        switch arguments[index] {
        case "--dataset":
            index += 1
            datasetDirectory = URL(fileURLWithPath: arguments[safe: index] ?? "")
        case "--model-output":
            index += 1
            modelOutputURL = URL(fileURLWithPath: arguments[safe: index] ?? "")
        case "--compiled-output-dir":
            index += 1
            compiledOutputDirectory = URL(fileURLWithPath: arguments[safe: index] ?? "")
        default:
            throw TrainerError.invalidArguments
        }

        index += 1
    }

    guard let datasetDirectory, let modelOutputURL else {
        throw TrainerError.invalidArguments
    }

    return TrainerConfiguration(
        datasetDirectory: datasetDirectory,
        modelOutputURL: modelOutputURL,
        compiledOutputDirectory: compiledOutputDirectory
    )
}

func validateDatasetLayout(at datasetDirectory: URL) throws -> [String: [URL]] {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: datasetDirectory.path) else {
        throw TrainerError.datasetMissing(datasetDirectory)
    }

    let requiredLabels = ["shower_on", "not_shower"]
    let hasAllLabels = requiredLabels.allSatisfy { label in
        let directory = datasetDirectory.appendingPathComponent(label, isDirectory: true)
        return fileManager.fileExists(atPath: directory.path)
    }

    guard hasAllLabels else {
        throw TrainerError.unsupportedDatasetLayout(datasetDirectory)
    }

    let supportedExtensions = Set(["wav", "caf", "aif", "aiff"])
    let labels = ["shower_on", "not_shower"]
    let filesByLabel = try Dictionary(uniqueKeysWithValues: labels.map { label in
        let directory = datasetDirectory.appendingPathComponent(label, isDirectory: true)
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { url in
            supportedExtensions.contains(url.pathExtension.lowercased())
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return (label, urls)
    })

    guard filesByLabel.values.allSatisfy({ !$0.isEmpty }) else {
        throw TrainerError.noAudioFiles(datasetDirectory)
    }

    return filesByLabel
}

func train(configuration: TrainerConfiguration) throws {
    let filesByLabel = try validateDatasetLayout(at: configuration.datasetDirectory)

    let classifier = try MLSoundClassifier(
        trainingData: .filesByLabel(filesByLabel)
    )

    let fileManager = FileManager.default
    try fileManager.createDirectory(
        at: configuration.modelOutputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try classifier.write(to: configuration.modelOutputURL)

    if let compiledOutputDirectory = configuration.compiledOutputDirectory {
        try fileManager.createDirectory(at: compiledOutputDirectory, withIntermediateDirectories: true)
        let compiledModelURL = try MLModel.compileModel(at: configuration.modelOutputURL)
        let destinationURL = compiledOutputDirectory.appendingPathComponent(compiledModelURL.lastPathComponent, isDirectory: true)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: compiledModelURL, to: destinationURL)
        print("Compiled model written to \(destinationURL.path)")
    }

    print("Model written to \(configuration.modelOutputURL.path)")
}

do {
    let configuration = try parseConfiguration(arguments: CommandLine.arguments)
    try train(configuration: configuration)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
