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

struct NovelContinuousVisiblePageRange: Equatable, Hashable, Sendable {
    let firstPageIndex: Int
    let lastPageIndex: Int

    init(firstPageIndex: Int, lastPageIndex: Int) {
        self.firstPageIndex = min(firstPageIndex, lastPageIndex)
        self.lastPageIndex = max(firstPageIndex, lastPageIndex)
    }

    func clamped(to pageCount: Int) -> NovelContinuousVisiblePageRange? {
        guard pageCount > 0 else { return nil }
        let upperBound = pageCount - 1
        let first = min(max(firstPageIndex, 0), upperBound)
        let last = min(max(lastPageIndex, 0), upperBound)
        return NovelContinuousVisiblePageRange(firstPageIndex: first, lastPageIndex: last)
    }
}

enum NovelTranslationScheduler {
    static func pageOrder(
        pageCount: Int,
        activePageIndex: Int,
        mode: NovelTranslationScheduleMode,
        continuousVisiblePageRange: NovelContinuousVisiblePageRange? = nil
    ) -> [Int] {
        guard pageCount > 0 else { return [] }
        if mode == .continuous {
            if let visibleRange = continuousVisiblePageRange?.clamped(to: pageCount) {
                return continuousPageOrder(pageCount: pageCount, visibleRange: visibleRange)
            }
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

    private static func continuousPageOrder(
        pageCount: Int,
        visibleRange: NovelContinuousVisiblePageRange
    ) -> [Int] {
        var ordered: [Int] = []
        var seen: Set<Int> = []

        func append(_ page: Int) {
            guard page >= 0, page < pageCount, seen.insert(page).inserted else { return }
            ordered.append(page)
        }

        for page in visibleRange.firstPageIndex...visibleRange.lastPageIndex {
            append(page)
        }

        var distance = 1
        while ordered.count < pageCount {
            append(visibleRange.firstPageIndex - distance)
            append(visibleRange.lastPageIndex + distance)
            distance += 1
        }

        return ordered
    }
}

enum NovelTranslationReadinessSampler {
    static func sampleSegment(from segments: [NovelTranslationSegment]) -> NovelTranslationSegment? {
        segments.first(where: isReliableLanguageSample) ?? segments.first
    }

    private static func isReliableLanguageSample(_ segment: NovelTranslationSegment) -> Bool {
        NovelTranslationTextSignal.meaningfulScalarCount(in: segment.sourceText) >= minimumReliableScalarCount
    }

    private static let minimumReliableScalarCount = 12
}

enum NovelTranslationRequestPolicy {
    static func requestableSegments(from segments: [NovelTranslationSegment]) -> [NovelTranslationSegment] {
        segments.filter(canRequestTranslation)
    }

    static func localFallbackResults(from segments: [NovelTranslationSegment]) -> [NovelTranslationBatchResult] {
        segments
            .filter { canRequestTranslation($0) == false }
            .map { NovelTranslationBatchResult(segment: $0, translatedText: $0.sourceText) }
    }

    private static func canRequestTranslation(_ segment: NovelTranslationSegment) -> Bool {
        NovelTranslationTextSignal.meaningfulScalarCount(in: segment.sourceText) >= minimumReliableScalarCount
    }

    private static let minimumReliableScalarCount = 12
}

private enum NovelTranslationTextSignal {
    static func meaningfulScalarCount(in text: String) -> Int {
        text.unicodeScalars.reduce(0) { count, scalar in
            if CharacterSet.letters.contains(scalar)
                || CharacterSet.decimalDigits.contains(scalar) {
                count + 1
            } else {
                count
            }
        }
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
