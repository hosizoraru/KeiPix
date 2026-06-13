import Foundation
#if canImport(Translation)
@preconcurrency import Translation
#endif

struct NovelTranslationSegment: Identifiable, Hashable, Codable, Sendable {
    let novelID: Int
    let targetLanguageID: String
    let pageIndex: Int
    let tokenIndex: Int
    let paragraphIndex: Int
    let sourceText: String
    let sourceHash: String
    let clientIdentifier: String

    var id: String { clientIdentifier }
}

struct NovelTranslationBatchResult: Equatable, Hashable, Sendable {
    let segment: NovelTranslationSegment
    let translatedText: String
}

enum NovelTranslationReadiness: Equatable, Hashable, Sendable {
    case ready
    case requiresPreparation
    case unavailable(NovelTranslationIssue)
}

enum NovelTranslationIssue: Equatable, Hashable, Sendable {
    case unsupportedSourceLanguage
    case unsupportedTargetLanguage
    case unsupportedLanguagePair
    case unableToIdentifyLanguage
    case nothingToTranslate
    case modelNotInstalled
    case cancelled
    case unavailable

    var localizedMessage: String {
        switch self {
        case .unsupportedSourceLanguage:
            L10n.novelTranslationUnsupportedSourceLanguage
        case .unsupportedTargetLanguage:
            L10n.novelTranslationUnsupportedTargetLanguage
        case .unsupportedLanguagePair:
            L10n.novelTranslationUnsupportedLanguagePair
        case .unableToIdentifyLanguage:
            L10n.novelTranslationCannotIdentifyLanguage
        case .nothingToTranslate:
            L10n.novelTranslationNothingToTranslate
        case .modelNotInstalled:
            L10n.novelTranslationModelNotInstalled
        case .cancelled:
            L10n.novelTranslationCancelled
        case .unavailable:
            L10n.translationFailed
        }
    }
}

enum NovelTranslationReadinessMapper {
    #if canImport(Translation)
    static func readiness(for status: LanguageAvailability.Status) -> NovelTranslationReadiness {
        switch status {
        case .installed:
            .ready
        case .supported:
            .requiresPreparation
        case .unsupported:
            .unavailable(.unsupportedLanguagePair)
        @unknown default:
            .unavailable(.unavailable)
        }
    }

    static func issue(for error: any Error) -> NovelTranslationIssue {
        if error is CancellationError {
            return .cancelled
        }
        if TranslationError.unsupportedSourceLanguage ~= error {
            return .unsupportedSourceLanguage
        }
        if TranslationError.unsupportedTargetLanguage ~= error {
            return .unsupportedTargetLanguage
        }
        if TranslationError.unsupportedLanguagePairing ~= error {
            return .unsupportedLanguagePair
        }
        if TranslationError.unableToIdentifyLanguage ~= error {
            return .unableToIdentifyLanguage
        }
        if TranslationError.nothingToTranslate ~= error {
            return .nothingToTranslate
        }
        if #available(iOS 26.0, macOS 26.0, *) {
            if TranslationError.notInstalled ~= error {
                return .modelNotInstalled
            }
            if TranslationError.alreadyCancelled ~= error {
                return .cancelled
            }
        }
        return .unavailable
    }
    #endif
}

struct NovelTranslationBatchClient {
    typealias ResultHandler = @MainActor (NovelTranslationBatchResult) -> Void

    private let operation: @MainActor ([NovelTranslationSegment], ResultHandler) async throws -> Void

    init(_ operation: @escaping @MainActor ([NovelTranslationSegment], ResultHandler) async throws -> Void) {
        self.operation = operation
    }

    @MainActor
    func translate(
        _ segments: [NovelTranslationSegment],
        onResult: ResultHandler
    ) async throws {
        try await operation(segments, onResult)
    }
}

enum NovelTranslationScheduleMode: String, Codable, Hashable, Sendable {
    case singlePage
    case doublePage
    case continuous
}

struct NovelTranslationScheduleIdentity: Hashable, Sendable {
    let novelID: Int
    let targetLanguageID: String
    let mode: NovelTranslationScheduleMode
    let activePageIndex: Int
    let pageCount: Int
}

enum NovelTranslationScheduler {
    static func pageOrder(
        pageCount: Int,
        activePageIndex: Int,
        mode: NovelTranslationScheduleMode
    ) -> [Int] {
        guard pageCount > 0 else { return [] }
        if mode == .continuous {
            return Array(0..<pageCount)
        }

        let activePage = min(max(activePageIndex, 0), pageCount - 1)
        var ordered: [Int] = []
        var seen: Set<Int> = []

        func append(_ page: Int) {
            guard page >= 0, page < pageCount, seen.insert(page).inserted else { return }
            ordered.append(page)
        }

        append(activePage)
        if mode == .doublePage {
            append(activePage + 1)
        }

        var distance = 1
        while ordered.count < pageCount {
            append(activePage - distance)
            let trailingDistance = mode == .doublePage ? distance + 1 : distance
            append(activePage + trailingDistance)
            distance += 1
        }

        return ordered
    }
}

enum NovelTranslationBatchMapper {
    static func segmentIndex(_ segments: [NovelTranslationSegment]) -> [String: NovelTranslationSegment] {
        Dictionary(uniqueKeysWithValues: segments.map { ($0.clientIdentifier, $0) })
    }

    static func result(
        clientIdentifier: String?,
        translatedText: String,
        segmentsByClientIdentifier: [String: NovelTranslationSegment]
    ) -> NovelTranslationBatchResult? {
        guard let clientIdentifier,
              let segment = segmentsByClientIdentifier[clientIdentifier] else {
            return nil
        }
        return NovelTranslationBatchResult(segment: segment, translatedText: translatedText)
    }

    #if canImport(Translation)
    static func requests(from segments: [NovelTranslationSegment]) -> [TranslationSession.Request] {
        segments.map { segment in
            if #available(iOS 26.4, macOS 26.4, macCatalyst 26.4, *) {
                return TranslationSession.Request(
                    sourceText: attributedSourceText(from: segment.sourceText),
                    clientIdentifier: segment.clientIdentifier
                )
            }
            return TranslationSession.Request(
                sourceText: segment.sourceText,
                clientIdentifier: segment.clientIdentifier
            )
        }
    }

    @available(iOS 26.4, macOS 26.4, macCatalyst 26.4, *)
    private static func attributedSourceText(from raw: String) -> AttributedString {
        let ranges = skipTranslationRanges(in: raw)
        guard ranges.isEmpty == false else {
            return AttributedString(raw)
        }

        var result = AttributedString()
        var cursor = raw.startIndex
        for range in ranges {
            if cursor < range.lowerBound {
                result += AttributedString(String(raw[cursor..<range.lowerBound]))
            }

            var skipped = AttributedString(String(raw[range]))
            skipped.translation.skipsTranslation = true
            result += skipped
            cursor = range.upperBound
        }

        if cursor < raw.endIndex {
            result += AttributedString(String(raw[cursor..<raw.endIndex]))
        }
        return result
    }

    private static func skipTranslationRanges(in raw: String) -> [Range<String.Index>] {
        let patterns = [
            #"https?://[^\s\]\)）]+"#,
            #"\[(?:newpage|chapter:[^\]]+|pixivimage:[^\]]+|uploadedimage:[^\]]+|jump:[^\]]+)\]"#,
            #"\[\[(?:rb|jumpuri):[^\]]+\]\]"#
        ]

        var ranges: [Range<String.Index>] = []
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
            let matches = expression.matches(in: raw, range: nsRange)
            for match in matches {
                guard let range = Range(match.range, in: raw) else { continue }
                ranges.append(range)
            }
        }

        return mergeOverlappingRanges(ranges)
    }

    private static func mergeOverlappingRanges(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        let sorted = ranges.sorted { lhs, rhs in
            if lhs.lowerBound == rhs.lowerBound {
                return lhs.upperBound < rhs.upperBound
            }
            return lhs.lowerBound < rhs.lowerBound
        }
        guard var current = sorted.first else { return [] }

        var merged: [Range<String.Index>] = []
        for range in sorted.dropFirst() {
            if range.lowerBound <= current.upperBound {
                current = current.lowerBound..<max(current.upperBound, range.upperBound)
            } else {
                merged.append(current)
                current = range
            }
        }
        merged.append(current)
        return merged
    }
    #endif
}

enum NovelTranslationPlanner {
    static func segments(
        novelID: Int,
        targetLanguageID: String,
        pages: [[NovelToken]],
        pageStartIndex: Int = 0
    ) -> [NovelTranslationSegment] {
        var segments: [NovelTranslationSegment] = []

        for (pageIndex, page) in pages.enumerated() {
            let resolvedPageIndex = pageStartIndex + pageIndex
            for (tokenIndex, token) in page.enumerated() {
                guard case .text(let rawText) = token else { continue }

                for paragraph in paragraphCandidates(from: rawText) {
                    guard let sourceText = CaptionTranslationAvailability.translatableText(from: paragraph.text) else {
                        continue
                    }

                    let sourceHash = stableSourceHash(sourceText)
                    let clientIdentifier = [
                        "novel-\(novelID)",
                        "target-\(sanitizedIdentifierComponent(targetLanguageID))",
                        "page-\(pageIndex)",
                        "token-\(tokenIndex)",
                        "paragraph-\(paragraph.index)",
                        "hash-\(sourceHash)"
                    ].joined(separator: "-")

                    segments.append(
                        NovelTranslationSegment(
                            novelID: novelID,
                            targetLanguageID: targetLanguageID,
                            pageIndex: resolvedPageIndex,
                            tokenIndex: tokenIndex,
                            paragraphIndex: paragraph.index,
                            sourceText: sourceText,
                            sourceHash: sourceHash,
                            clientIdentifier: clientIdentifier
                        )
                    )
                }
            }
        }

        return segments
    }

    private struct ParagraphCandidate {
        let index: Int
        let text: String
    }

    private static func paragraphCandidates(from rawText: String) -> [ParagraphCandidate] {
        let normalized = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard let expression = try? NSRegularExpression(pattern: #"\n[ \t]*\n+"#) else {
            return [ParagraphCandidate(index: 0, text: normalized)]
        }

        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = expression.matches(in: normalized, range: range)
        guard matches.isEmpty == false else {
            return [ParagraphCandidate(index: 0, text: normalized)]
        }

        var candidates: [ParagraphCandidate] = []
        var start = normalized.startIndex

        for match in matches {
            guard let delimiterRange = Range(match.range, in: normalized) else { continue }
            candidates.append(
                ParagraphCandidate(
                    index: candidates.count,
                    text: String(normalized[start..<delimiterRange.lowerBound])
                )
            )
            start = delimiterRange.upperBound
        }

        candidates.append(
            ParagraphCandidate(
                index: candidates.count,
                text: String(normalized[start..<normalized.endIndex])
            )
        )
        return candidates
    }

    private static func stableSourceHash(_ sourceText: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in sourceText.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private static func sanitizedIdentifierComponent(_ raw: String) -> String {
        var sanitized = ""
        for scalar in raw.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "." {
                sanitized.unicodeScalars.append(scalar)
            } else {
                sanitized += String(format: "u%04x", scalar.value)
            }
        }
        return sanitized.isEmpty ? "system" : sanitized
    }
}
