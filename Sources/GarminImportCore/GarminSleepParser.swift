import CoreGraphics
import Foundation
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(Vision)
import Vision
#endif

public struct RecognizedLine: Equatable, Sendable {
    public let text: String
    public let boundingBox: CGRect

    public init(text: String, boundingBox: CGRect) {
        self.text = text
        self.boundingBox = boundingBox
    }
}

public protocol OCRRecognizing: Sendable {
    func recognizeText(in imageURL: URL) throws -> [RecognizedLine]
}

public struct VisionOCRRecognizer: OCRRecognizing {
    public init() {}

    public func recognizeText(in imageURL: URL) throws -> [RecognizedLine] {
        #if canImport(Vision) && canImport(ImageIO)
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw GarminSleepParserError.missingField("image data")
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            return RecognizedLine(text: candidate.string, boundingBox: observation.boundingBox)
        }
        #else
        throw GarminSleepParserError.notImplemented
        #endif
    }
}

public struct GarminSleepRecord: Equatable, Sendable {
    public var sleepDate: String
    public var sleepScore: Int
    public var sleepQuality: String
    public var totalSleepMinutes: Int
    public var bedtime: String
    public var wakeTime: String
    public var summaryHeadline: String
    public var deepSleepMinutes: Int
    public var lightSleepMinutes: Int
    public var remSleepMinutes: Int
    public var awakeMinutes: Int
    public var breathingVariations: String
    public var restlessMoments: Int
    public var restingHeartRate: Int
    public var bodyBatteryChange: Int
    public var averageSpO2: Int
    public var lowestSpO2: Int
    public var averageRespiration: Double
    public var lowestRespiration: Double
    public var averageOvernightHRV: Int
    public var sevenDayHRVStatus: String
    public var averageSkinTemperatureChangeCelsius: Double?

    public init(
        sleepDate: String,
        sleepScore: Int,
        sleepQuality: String,
        totalSleepMinutes: Int,
        bedtime: String,
        wakeTime: String,
        summaryHeadline: String,
        deepSleepMinutes: Int,
        lightSleepMinutes: Int,
        remSleepMinutes: Int,
        awakeMinutes: Int,
        breathingVariations: String,
        restlessMoments: Int,
        restingHeartRate: Int,
        bodyBatteryChange: Int,
        averageSpO2: Int,
        lowestSpO2: Int,
        averageRespiration: Double,
        lowestRespiration: Double,
        averageOvernightHRV: Int,
        sevenDayHRVStatus: String,
        averageSkinTemperatureChangeCelsius: Double?
    ) {
        self.sleepDate = sleepDate
        self.sleepScore = sleepScore
        self.sleepQuality = sleepQuality
        self.totalSleepMinutes = totalSleepMinutes
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.summaryHeadline = summaryHeadline
        self.deepSleepMinutes = deepSleepMinutes
        self.lightSleepMinutes = lightSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.awakeMinutes = awakeMinutes
        self.breathingVariations = breathingVariations
        self.restlessMoments = restlessMoments
        self.restingHeartRate = restingHeartRate
        self.bodyBatteryChange = bodyBatteryChange
        self.averageSpO2 = averageSpO2
        self.lowestSpO2 = lowestSpO2
        self.averageRespiration = averageRespiration
        self.lowestRespiration = lowestRespiration
        self.averageOvernightHRV = averageOvernightHRV
        self.sevenDayHRVStatus = sevenDayHRVStatus
        self.averageSkinTemperatureChangeCelsius = averageSkinTemperatureChangeCelsius
    }
}

public enum GarminSleepParserError: Error, Equatable, Sendable {
    case notImplemented
    case missingField(String)
}

public struct GarminSleepParser: Sendable {
    private let ocrRecognizer: any OCRRecognizing

    public init(ocrRecognizer: any OCRRecognizing) {
        self.ocrRecognizer = ocrRecognizer
    }

    public func parseNight(
        summaryURL: URL,
        timelineURL: URL,
        metricsURL: URL,
        importedAt: Date
    ) throws -> GarminSleepRecord {
        let summaryLines = try ocrRecognizer.recognizeText(in: summaryURL)
        let timelineLines = try ocrRecognizer.recognizeText(in: timelineURL)
        let metricsLines = try ocrRecognizer.recognizeText(in: metricsURL)

        return try parseNight(
            summaryLines: summaryLines,
            timelineLines: timelineLines,
            metricsLines: metricsLines,
            importedAt: importedAt
        )
    }

    public func parseNight(
        summaryLines: [RecognizedLine],
        timelineLines: [RecognizedLine],
        metricsLines: [RecognizedLine],
        importedAt: Date
    ) throws -> GarminSleepRecord {
        let sleepDate = try parseSleepDate(from: summaryLines, importedAt: importedAt)
        let sleepScore = try parseSleepScore(from: summaryLines)
        let sleepQuality = try parseLabeledString(
            valueAbove: "Quality",
            from: summaryLines,
            fieldName: "sleep quality"
        )
        let totalSleepMinutes = try parseLabeledDuration(
            valueAbove: "Duration",
            from: summaryLines,
            fieldName: "total sleep duration"
        )
        let summaryHeadline = try parseSummaryHeadline(from: summaryLines)
        let (bedtime, wakeTime) = try parseTimelineTimes(from: timelineLines)

        let deepSleepMinutes = try parseLabeledDuration(
            valueAboveAliases: ["Deep"],
            from: metricsLines,
            fieldName: "deep sleep"
        )
        let lightSleepMinutes = try parseLabeledDuration(
            valueAboveAliases: ["Light"],
            from: metricsLines,
            fieldName: "light sleep"
        )
        let remSleepMinutes = try parseLabeledDuration(
            valueAboveAliases: ["REM"],
            from: metricsLines,
            fieldName: "rem sleep"
        )
        let awakeMinutes = try parseLabeledDuration(
            valueAboveAliases: ["Awake"],
            from: metricsLines,
            fieldName: "awake time"
        )
        let breathingVariations = try parseLabeledString(
            valueAboveAliases: ["Breathing Variations"],
            from: metricsLines,
            fieldName: "breathing variations"
        )
        let restlessMoments = try parseLabeledInt(
            valueAboveAliases: ["Restless Moments"],
            from: metricsLines,
            fieldName: "restless moments"
        )
        let restingHeartRate = try parseLabeledInt(
            valueAboveAliases: ["Resting Heart Rate"],
            from: metricsLines,
            fieldName: "resting heart rate"
        )
        let bodyBatteryChange = try parseLabeledSignedInt(
            valueAboveAliases: ["Body Battery Change"],
            from: metricsLines,
            fieldName: "body battery change"
        )
        let averageSpO2 = try parseLabeledInt(
            valueAboveAliases: ["Avg SpO2", "Avg SpOz"],
            from: metricsLines,
            fieldName: "average SpO2"
        )
        let lowestSpO2 = try parseLabeledInt(
            valueAboveAliases: ["Lowest SpO2", "Lowest SpOz"],
            from: metricsLines,
            fieldName: "lowest SpO2"
        )
        let averageRespiration = try parseLabeledDouble(
            valueAboveAliases: ["Avg Respiration"],
            from: metricsLines,
            fieldName: "average respiration"
        )
        let lowestRespiration = try parseLabeledDouble(
            valueAboveAliases: ["Lowest Respiration"],
            from: metricsLines,
            fieldName: "lowest respiration"
        )
        let averageOvernightHRV = try parseLabeledInt(
            valueAboveAliases: ["Avg Overnight HRV"],
            from: metricsLines,
            fieldName: "average overnight HRV"
        )
        let sevenDayHRVStatus = try parseLabeledString(
            valueAboveAliases: ["7d Avg HRV"],
            from: metricsLines,
            fieldName: "7d average HRV status"
        )
        let averageSkinTemperatureChangeCelsius = parseOptionalLabeledSignedDouble(
            valueAboveAliases: ["Avg Skin Temp Change", "Avg Skin Temperature Change"],
            from: metricsLines
        )

        return GarminSleepRecord(
            sleepDate: sleepDate,
            sleepScore: sleepScore,
            sleepQuality: sleepQuality,
            totalSleepMinutes: totalSleepMinutes,
            bedtime: bedtime,
            wakeTime: wakeTime,
            summaryHeadline: summaryHeadline,
            deepSleepMinutes: deepSleepMinutes,
            lightSleepMinutes: lightSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            awakeMinutes: awakeMinutes,
            breathingVariations: breathingVariations,
            restlessMoments: restlessMoments,
            restingHeartRate: restingHeartRate,
            bodyBatteryChange: bodyBatteryChange,
            averageSpO2: averageSpO2,
            lowestSpO2: lowestSpO2,
            averageRespiration: averageRespiration,
            lowestRespiration: lowestRespiration,
            averageOvernightHRV: averageOvernightHRV,
            sevenDayHRVStatus: sevenDayHRVStatus,
            averageSkinTemperatureChangeCelsius: averageSkinTemperatureChangeCelsius
        )
    }
}

private extension GarminSleepParser {
    func parseSleepDate(from lines: [RecognizedLine], importedAt: Date) throws -> String {
        let calendar = Calendar(identifier: .gregorian)
        let importYear = calendar.component(.year, from: importedAt)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "EEEE, MMMM d yyyy"

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        outputFormatter.dateFormat = "yyyy-MM-dd"

        let dateLine = lines
            .map(\.text)
            .first { $0.contains(",") && $0.range(of: #"[A-Za-z]+, [A-Za-z]+ \d{1,2}"#, options: .regularExpression) != nil }

        guard let dateLine else {
            throw GarminSleepParserError.missingField("sleep date")
        }

        guard let date = dateFormatter.date(from: "\(dateLine) \(importYear)") else {
            throw GarminSleepParserError.missingField("sleep date")
        }

        return outputFormatter.string(from: date)
    }

    func parseSleepScore(from lines: [RecognizedLine]) throws -> Int {
        let upperBoundY = min(findDateLine(in: lines)?.boundingBox.midY ?? 1, 0.94)
        let primaryCandidates: [RecognizedLine]

        if let scoreLabel = findLine(matchingAliases: ["Score"], in: lines) {
            primaryCandidates = lines
                .filter { candidate in
                    candidate.boundingBox.midY > scoreLabel.boundingBox.midY
                        && candidate.boundingBox.midY < upperBoundY
                        && abs(candidate.boundingBox.midX - scoreLabel.boundingBox.midX) < 0.18
                        && isStandaloneIntegerText(candidate.text)
                }
                .sorted { lhs, rhs in
                    if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.0001 {
                        return lhs.boundingBox.midY > rhs.boundingBox.midY
                    }

                    return abs(lhs.boundingBox.midX - scoreLabel.boundingBox.midX) < abs(rhs.boundingBox.midX - scoreLabel.boundingBox.midX)
                }
        } else {
            primaryCandidates = []
        }

        let fallbackLowerBoundY = lines
            .filter { ["quality", "duration"].contains(normalizedKey($0.text)) }
            .map { $0.boundingBox.midY }
            .max() ?? 0.55

        let fallbackCandidates = lines
            .filter { candidate in
                candidate.boundingBox.midY > fallbackLowerBoundY
                    && candidate.boundingBox.midY < upperBoundY
                    && candidate.boundingBox.midX > 0.3
                    && candidate.boundingBox.midX < 0.7
                    && isStandaloneIntegerText(candidate.text)
            }
            .sorted { lhs, rhs in
                if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.0001 {
                    return lhs.boundingBox.midY > rhs.boundingBox.midY
                }

                return abs(lhs.boundingBox.midX - 0.5) < abs(rhs.boundingBox.midX - 0.5)
            }

        guard let value = (primaryCandidates.isEmpty ? fallbackCandidates : primaryCandidates)
            .compactMap(\.text)
            .compactMap(parseInteger)
            .first(where: { (0 ... 100).contains($0) })
        else {
            throw GarminSleepParserError.missingField("sleep score")
        }

        return value
    }

    func parseSummaryHeadline(from lines: [RecognizedLine]) throws -> String {
        let excluded = Set([
            normalizedKey("Sleep"),
            normalizedKey("Sleep Score"),
            normalizedKey("Sleep Coach"),
            normalizedKey("Score"),
            normalizedKey("Quality"),
            normalizedKey("Duration"),
        ])

        let labelY = lines
            .filter { ["quality", "duration"].contains(normalizedKey($0.text)) }
            .map { $0.boundingBox.midY }
            .min() ?? 1

        guard let headline = sortedLines(lines).first(where: { line in
            let key = normalizedKey(line.text)
            return line.boundingBox.midY < labelY
                && !excluded.contains(key)
                && key.range(of: #"[a-z]"#, options: .regularExpression) != nil
                && key.range(of: #"\d"#, options: .regularExpression) == nil
                && !key.hasPrefix("you")
        })?.text
        else {
            throw GarminSleepParserError.missingField("summary headline")
        }

        return headline
    }

    func parseTimelineTimes(from lines: [RecognizedLine]) throws -> (String, String) {
        let timeLines = lines
            .filter { line in
                isTimeText(line.text) && line.boundingBox.midY < 0.45
            }
            .map { line in
                (line.text, line.boundingBox.minX)
            }
            .sorted { $0.1 < $1.1 }

        guard let bedtime = timeLines.first?.0,
              let wakeTime = timeLines.last?.0,
              timeLines.count >= 2
        else {
            throw GarminSleepParserError.missingField("timeline start/end times")
        }

        return (bedtime, wakeTime)
    }

    func findLine(matchingAliases aliases: [String], in lines: [RecognizedLine]) -> RecognizedLine? {
        let aliasKeys = aliases
            .map(normalizedKey)
            .filter { !$0.isEmpty }

        guard !aliasKeys.isEmpty else {
            return nil
        }

        if let exactMatch = lines.first(where: { aliasKeys.contains(normalizedKey($0.text)) }) {
            return exactMatch
        }

        return lines
            .compactMap { line -> (RecognizedLine, Int, Int)? in
                let key = normalizedKey(line.text)
                guard key.count >= 6 else {
                    return nil
                }

                let bestMatch = aliasKeys
                    .map { aliasKey in
                        (
                            distance: editDistance(between: key, and: aliasKey),
                            prefixLength: commonPrefixLength(between: key, and: aliasKey)
                        )
                    }
                    .min { lhs, rhs in
                        if lhs.distance != rhs.distance {
                            return lhs.distance < rhs.distance
                        }

                        return lhs.prefixLength > rhs.prefixLength
                    }

                guard let bestMatch, bestMatch.distance <= 2 else {
                    return nil
                }

                return (line, bestMatch.distance, bestMatch.prefixLength)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }

                return lhs.2 > rhs.2
            }
            .first?.0
    }

    func findDateLine(in lines: [RecognizedLine]) -> RecognizedLine? {
        lines.first { line in
            line.text.contains(",")
                && line.text.range(of: #"[A-Za-z]+, [A-Za-z]+ \d{1,2}"#, options: .regularExpression) != nil
        }
    }

    func isStandaloneIntegerText(_ text: String) -> Bool {
        text.range(of: #"^\d{1,3}$"#, options: .regularExpression) != nil
    }

    func isTimeText(_ text: String) -> Bool {
        text.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil
    }

    func parseLabeledDuration(
        valueAbove label: String,
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> Int {
        try parseLabeledDuration(valueAboveAliases: [label], from: lines, fieldName: fieldName)
    }

    func parseLabeledDuration(
        valueAboveAliases aliases: [String],
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> Int {
        let value = try labeledValue(aboveAliases: aliases, from: lines, fieldName: fieldName)

        guard let duration = parseDurationMinutes(from: value.text) else {
            throw GarminSleepParserError.missingField(fieldName)
        }

        return duration
    }

    func parseLabeledString(
        valueAbove label: String,
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> String {
        try parseLabeledString(valueAboveAliases: [label], from: lines, fieldName: fieldName)
    }

    func parseLabeledString(
        valueAboveAliases aliases: [String],
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> String {
        try labeledValue(aboveAliases: aliases, from: lines, fieldName: fieldName).text
    }

    func parseLabeledInt(
        valueAboveAliases aliases: [String],
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> Int {
        let value = try labeledValue(aboveAliases: aliases, from: lines, fieldName: fieldName)

        guard let parsed = parseInteger(from: value.text) else {
            throw GarminSleepParserError.missingField(fieldName)
        }

        return parsed
    }

    func parseLabeledSignedInt(
        valueAboveAliases aliases: [String],
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> Int {
        let value = try labeledValue(aboveAliases: aliases, from: lines, fieldName: fieldName)

        guard let parsed = parseSignedInteger(from: value.text) else {
            throw GarminSleepParserError.missingField(fieldName)
        }

        return parsed
    }

    func parseLabeledDouble(
        valueAboveAliases aliases: [String],
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> Double {
        let value = try labeledValue(aboveAliases: aliases, from: lines, fieldName: fieldName)

        guard let parsed = parseSignedDouble(from: value.text) else {
            throw GarminSleepParserError.missingField(fieldName)
        }

        return parsed
    }

    func parseLabeledSignedDouble(
        valueAboveAliases aliases: [String],
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> Double {
        try parseLabeledDouble(valueAboveAliases: aliases, from: lines, fieldName: fieldName)
    }

    func parseOptionalLabeledSignedDouble(
        valueAboveAliases aliases: [String],
        from lines: [RecognizedLine]
    ) -> Double? {
        guard let value = try? labeledValue(
            aboveAliases: aliases,
            from: lines,
            fieldName: "optional labeled double"
        ) else {
            return nil
        }

        return parseSignedDouble(from: value.text)
    }

    func labeledValue(
        aboveAliases aliases: [String],
        from lines: [RecognizedLine],
        fieldName: String
    ) throws -> RecognizedLine {
        guard let label = findLine(matchingAliases: aliases, in: lines) else {
            throw GarminSleepParserError.missingField(fieldName)
        }

        let candidates = lines
            .filter { candidate in
                candidate.text != label.text
                    && candidate.boundingBox.midY > label.boundingBox.midY
                    && abs(candidate.boundingBox.minX - label.boundingBox.minX) < 0.2
            }
            .sorted { lhs, rhs in
                let lhsDistance = lhs.boundingBox.midY - label.boundingBox.midY
                let rhsDistance = rhs.boundingBox.midY - label.boundingBox.midY

                if abs(lhsDistance - rhsDistance) > 0.0001 {
                    return lhsDistance < rhsDistance
                }

                return abs(lhs.boundingBox.minX - label.boundingBox.minX) < abs(rhs.boundingBox.minX - label.boundingBox.minX)
            }

        guard let value = candidates.first else {
            throw GarminSleepParserError.missingField(fieldName)
        }

        return value
    }

    func sortedLines(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        lines.sorted { lhs, rhs in
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.0001 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    func normalizedKey(_ text: String) -> String {
        let lowered = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "spoz", with: "spo2")
            .replacingOccurrences(of: "hry", with: "hrv")
            .replacingOccurrences(of: "o2", with: "02")

        return lowered.replacingOccurrences(
            of: #"[^a-z0-9]"#,
            with: "",
            options: .regularExpression
        )
    }

    func editDistance(between lhs: String, and rhs: String) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)

        if lhsCharacters.isEmpty {
            return rhsCharacters.count
        }

        if rhsCharacters.isEmpty {
            return lhsCharacters.count
        }

        var previousRow = Array(0...rhsCharacters.count)

        for (lhsIndex, lhsCharacter) in lhsCharacters.enumerated() {
            var currentRow = [lhsIndex + 1]

            for (rhsIndex, rhsCharacter) in rhsCharacters.enumerated() {
                let substitutionCost = lhsCharacter == rhsCharacter ? 0 : 1
                currentRow.append(
                    min(
                        previousRow[rhsIndex + 1] + 1,
                        currentRow[rhsIndex] + 1,
                        previousRow[rhsIndex] + substitutionCost
                    )
                )
            }

            previousRow = currentRow
        }

        return previousRow[rhsCharacters.count]
    }

    func commonPrefixLength(between lhs: String, and rhs: String) -> Int {
        zip(lhs, rhs).prefix { $0 == $1 }.count
    }

    func parseDurationMinutes(from text: String) -> Int? {
        let pattern = #"(?:(\d+)\s*h\s*)?(\d+)\s*m"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        let hours = match.range(at: 1).location == NSNotFound ? 0 : Int((text as NSString).substring(with: match.range(at: 1))) ?? 0
        let minutes = Int((text as NSString).substring(with: match.range(at: 2))) ?? 0
        return (hours * 60) + minutes
    }

    func parseInteger(from text: String) -> Int? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let match = normalized.range(of: #"\d+"#, options: .regularExpression) else {
            return nil
        }

        return Int(normalized[match])
    }

    func parseSignedInteger(from text: String) -> Int? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let match = normalized.range(of: #"[+-]?\d+"#, options: .regularExpression) else {
            return nil
        }

        return Int(normalized[match])
    }

    func parseSignedDouble(from text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let match = normalized.range(of: #"[+-]?\d+(?:\.\d+)?"#, options: .regularExpression) else {
            return nil
        }

        return Double(normalized[match])
    }
}
