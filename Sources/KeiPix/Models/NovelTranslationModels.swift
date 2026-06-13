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
            TranslationSession.Request(
                sourceText: segment.sourceText,
                clientIdentifier: segment.clientIdentifier
            )
        }
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
