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

    static func activityActorTitle(for item: PixivActivityItem) -> String {
        let actorName = item.actor?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let actorName, actorName.isEmpty == false {
            return actorName
        }
        return kindTitle(for: item.kind)
    }

    static func masonryWorkTitle(for item: PixivActivityItem) -> String {
        let targetTitle = item.target?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetTitle, targetTitle.isEmpty == false {
            return targetTitle
        }
        let actorName = item.actor?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let actorName, actorName.isEmpty == false {
            return actorName
        }
        return kindTitle(for: item.kind)
    }

    static func masonryAuthorTitle(for item: PixivActivityItem) -> String {
        guard let author = item.target?.author else { return "" }
        if let actorID = item.actor?.userID,
           let authorID = author.userID,
           actorID == authorID {
            return ""
        }
        let actorName = item.actor?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorName = author.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard authorName.isEmpty == false else {
            return ""
        }
        if let actorName,
           actorName.localizedCaseInsensitiveCompare(authorName) == .orderedSame {
            return ""
        }
        return authorName
    }

    static func masonryCardHeight(for item: PixivActivityItem, width: CGFloat) -> CGFloat {
        max(124, min(340, width / masonryImageAspectRatio(for: item)))
    }

    static func masonryImageAspectRatio(for item: PixivActivityItem) -> CGFloat {
        if let thumbnailAspectRatio = item.target?.thumbnailAspectRatio,
           thumbnailAspectRatio.isFinite,
           thumbnailAspectRatio > 0 {
            return CGFloat(thumbnailAspectRatio)
        }
        switch item.target?.kind {
        case .novel:
            return 0.72
        case .user:
            return 1
        case .artwork, .unknown:
            return 1
        case nil:
            return 1
        }
    }

    static func compactTimeText(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        if elapsed < 60 {
            return L10n.justNow
        }
        if elapsed < 3_600 {
            return String(format: L10n.minutesAgoFormat, max(1, Int(elapsed / 60)))
        }
        if elapsed < 86_400, calendar.isDate(date, inSameDayAs: now) {
            return String(format: L10n.hoursAgoFormat, max(1, Int(elapsed / 3_600)))
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .autoupdatingCurrent

        if calendar.isDateInYesterday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return String(format: L10n.yesterdayTimeFormat, formatter.string(from: date))
        }

        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now))
        if let days = components.day, days > 0, days < 7 {
            return String(format: L10n.daysAgoFormat, days)
        }

        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.setLocalizedDateFormatFromTemplate("Md")
            return formatter.string(from: date)
        }
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
