import CoreGraphics
import Foundation

enum PixivActivityLayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case masonry
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .masonry: L10n.waterfall
        case .list: L10n.listRow
        }
    }

    var systemImage: String {
        switch self {
        case .masonry: "rectangle.grid.2x2"
        case .list: "list.bullet"
        }
    }

    var usesMasonry: Bool {
        self == .masonry
    }
}

enum PixivActivityFeedPresentation {
    static let defaultLayoutMode: PixivActivityLayoutMode = .masonry

    static func statusText(itemCount: Int) -> String {
        guard itemCount > 0 else { return "" }
        return String(format: L10n.pixivActivityLoadedCountFormat, itemCount)
    }

    static func primaryTitle(for item: PixivActivityItem) -> String {
        let actorName = item.actor?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetTitle = item.target?.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let actorName, actorName.isEmpty == false,
           let targetTitle, targetTitle.isEmpty == false {
            return "\(actorName) · \(targetTitle)"
        }
        if let targetTitle, targetTitle.isEmpty == false {
            return targetTitle
        }
        if let actorName, actorName.isEmpty == false {
            return actorName
        }
        return kindTitle(for: item.kind)
    }

    static func secondaryTitle(for item: PixivActivityItem) -> String {
        let summary = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard summary.isEmpty == false else {
            return item.target?.url?.absoluteString ?? L10n.pixivActivityOpenHint
        }
        return summary
    }

    static func masonryCardHeight(for item: PixivActivityItem, width: CGFloat) -> CGFloat {
        let contentWidth = max(width - 24, 120)
        let titleLines = estimatedLineCount(
            for: primaryTitle(for: item),
            contentWidth: contentWidth,
            averageCharacterWidth: 8.4,
            maximum: 2
        )
        let summaryLines = estimatedLineCount(
            for: secondaryTitle(for: item),
            contentWidth: contentWidth,
            averageCharacterWidth: 6.9,
            maximum: item.target?.thumbnailURL == nil ? 3 : 2
        )
        return 12
            + masonryThumbnailHeight(for: item, width: width)
            + 10
            + 23
            + 7
            + CGFloat(titleLines) * 18
            + 5
            + CGFloat(summaryLines) * 15
            + 12
    }

    static func masonryThumbnailHeight(for item: PixivActivityItem, width: CGFloat) -> CGFloat {
        if item.target?.thumbnailURL != nil {
            return max(100, min(142, width * 0.70))
        }
        if item.actor?.avatarURL != nil || item.kind == .followedUser {
            return max(92, min(126, width * 0.62))
        }
        return max(84, min(118, width * 0.58))
    }

    private static func estimatedLineCount(
        for text: String,
        contentWidth: CGFloat,
        averageCharacterWidth: CGFloat,
        maximum: Int
    ) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return 1 }
        let charactersPerLine = max(8, Int(contentWidth / averageCharacterWidth))
        let lines = Int(ceil(Double(trimmed.count) / Double(charactersPerLine)))
        return min(max(lines, 1), maximum)
    }

    private static func kindTitle(for kind: PixivActivityKind) -> String {
        switch kind {
        case .postedArtwork: L10n.pixivActivityPostedArtwork
        case .bookmarkedArtwork: L10n.pixivActivityBookmarkedArtwork
        case .followedUser: L10n.pixivActivityFollowedUser
        case .unknown: L10n.pixivActivityUnknown
        }
    }
}
