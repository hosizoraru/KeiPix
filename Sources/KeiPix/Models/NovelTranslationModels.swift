import Foundation

struct NovelTranslationSegment: Identifiable, Hashable, Sendable {
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

enum NovelTranslationPlanner {
    static func segments(
        novelID: Int,
        targetLanguageID: String,
        pages: [[NovelToken]]
    ) -> [NovelTranslationSegment] {
        var segments: [NovelTranslationSegment] = []

        for (pageIndex, page) in pages.enumerated() {
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
                            pageIndex: pageIndex,
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
