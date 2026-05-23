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

struct ArtworkDownloadItem: Identifiable, Codable, Sendable {
    let id: UUID
    let artworkID: Int
    let title: String
    let creatorName: String
    let pageCount: Int
    var completedPages: Int
    var status: ArtworkDownloadStatus
    var folderPath: String?
    var sourceImageURLs: [URL]?
    var errorMessage: String?
    let createdAt: Date
    var updatedAt: Date

    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return Double(completedPages) / Double(pageCount)
    }

    var progressLabel: String {
        "\(completedPages) / \(pageCount)"
    }
}
