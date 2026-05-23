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

enum DownloadQueueFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case active
    case completed
    case failed
    case imagePages
    case ugoiraZip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.allDownloads
        case .active:
            L10n.activeDownloads
        case .completed:
            L10n.completedDownloads
        case .failed:
            L10n.failedDownloads
        case .imagePages:
            L10n.imagePages
        case .ugoiraZip:
            L10n.ugoiraZip
        }
    }

    func includes(_ item: ArtworkDownloadItem) -> Bool {
        switch self {
        case .all:
            true
        case .active:
            item.status == .queued || item.status == .downloading
        case .completed:
            item.status == .completed
        case .failed:
            item.status == .failed
        case .imagePages:
            item.resolvedArtifactKind == .imagePages
        case .ugoiraZip:
            item.resolvedArtifactKind == .ugoiraZip
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
