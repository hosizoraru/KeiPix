import Foundation

struct NovelTranslationDiskCache {
    static let schemaVersion = 1

    let directoryURL: URL
    private let fileManager: FileManager

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeiPix/NovelTranslations", isDirectory: true)
    }

    func results(for segments: [NovelTranslationSegment]) -> [NovelTranslationBatchResult] {
        segments.compactMap { segment in
            guard let record = try? record(for: segment),
                  record.matches(segment) else {
                return nil
            }
            return NovelTranslationBatchResult(
                segment: segment,
                translatedText: record.translatedText
            )
        }
    }

    func store(_ result: NovelTranslationBatchResult) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let record = NovelTranslationDiskCacheRecord(result: result)
        let data = try JSONEncoder.keiPixCache.encode(record)
        try data.write(to: fileURL(for: result.segment), options: [.atomic])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    private func record(for segment: NovelTranslationSegment) throws -> NovelTranslationDiskCacheRecord? {
        let url = fileURL(for: segment)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.keiPixCache.decode(NovelTranslationDiskCacheRecord.self, from: data)
    }

    private func fileURL(for segment: NovelTranslationSegment) -> URL {
        directoryURL.appendingPathComponent(cacheKey(for: segment), isDirectory: false)
    }

    private func cacheKey(for segment: NovelTranslationSegment) -> String {
        [
            "v\(Self.schemaVersion)",
            "novel-\(segment.novelID)",
            "target-\(segment.targetLanguageID)",
            "segment-\(segment.clientIdentifier)",
            "source-\(segment.sourceHash)"
        ]
        .joined(separator: "-")
        .unicodeScalars
        .map { scalar -> String in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "." {
                return String(scalar)
            }
            return String(format: "u%04x", scalar.value)
        }
        .joined() + ".json"
    }
}

private struct NovelTranslationDiskCacheRecord: Codable {
    let schemaVersion: Int
    let novelID: Int
    let targetLanguageID: String
    let pageIndex: Int
    let tokenIndex: Int
    let paragraphIndex: Int
    let sourceHash: String
    let clientIdentifier: String
    let translatedText: String
    let storedAt: Date

    init(result: NovelTranslationBatchResult) {
        let segment = result.segment
        schemaVersion = NovelTranslationDiskCache.schemaVersion
        novelID = segment.novelID
        targetLanguageID = segment.targetLanguageID
        pageIndex = segment.pageIndex
        tokenIndex = segment.tokenIndex
        paragraphIndex = segment.paragraphIndex
        sourceHash = segment.sourceHash
        clientIdentifier = segment.clientIdentifier
        translatedText = result.translatedText
        storedAt = Date()
    }

    func matches(_ segment: NovelTranslationSegment) -> Bool {
        schemaVersion == NovelTranslationDiskCache.schemaVersion
            && novelID == segment.novelID
            && targetLanguageID == segment.targetLanguageID
            && pageIndex == segment.pageIndex
            && tokenIndex == segment.tokenIndex
            && paragraphIndex == segment.paragraphIndex
            && sourceHash == segment.sourceHash
            && clientIdentifier == segment.clientIdentifier
    }
}

private extension JSONEncoder {
    static var keiPixCache: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var keiPixCache: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
