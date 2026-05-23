import Foundation

enum ArtworkDownloadStatus: String, Codable, Sendable {
    case queued
    case downloading
    case completed
    case failed

    var title: String {
        switch self {
        case .queued:
            L10n.queued
        case .downloading:
            L10n.downloading
        case .completed:
            L10n.downloaded
        case .failed:
            L10n.failed
        }
    }
}

enum ArtworkDownloadArtifactKind: String, Codable, Sendable {
    case imagePages
    case ugoiraZip

    var title: String {
        switch self {
        case .imagePages:
            L10n.imagePages
        case .ugoiraZip:
            L10n.ugoiraZip
        }
    }
}

struct ArtworkDownloadItem: Identifiable, Codable, Sendable {
    let id: UUID
    let artworkID: Int
    let title: String
    let creatorName: String
    var creatorID: Int? = nil
    var tags: [String]? = nil
    var isAI: Bool? = nil
    var isR18: Bool? = nil
    var isR18G: Bool? = nil
    var artifactKind: ArtworkDownloadArtifactKind? = nil
    var ugoiraFrameCount: Int? = nil
    var ugoiraFrames: [PixivUgoiraFrame]? = nil
    let pageCount: Int
    var completedPages: Int
    var status: ArtworkDownloadStatus
    var folderPath: String?
    var sourceImageURLs: [URL]?
    var downloadedFilePaths: [String]? = nil
    var errorMessage: String?
    let createdAt: Date
    var updatedAt: Date

    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return Double(completedPages) / Double(pageCount)
    }

    var progressLabel: String {
        if resolvedArtifactKind == .ugoiraZip, let ugoiraFrameCount {
            return String(format: L10n.ugoiraFrameCountFormat, ugoiraFrameCount)
        }
        return "\(completedPages) / \(pageCount)"
    }

    var resolvedArtifactKind: ArtworkDownloadArtifactKind {
        artifactKind ?? .imagePages
    }
}
