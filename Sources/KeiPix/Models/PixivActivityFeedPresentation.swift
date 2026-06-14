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

enum PixivActivityFeedScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case everyone
    case followingUsers
    case myPixiv
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.pixivActivityScopeAll
        case .everyone: L10n.pixivActivityScopeEveryone
        case .followingUsers: L10n.pixivActivityScopeFollowingUsers
        case .myPixiv: L10n.pixivActivityScopeMyPixiv
        case .mine: L10n.pixivActivityScopeMine
        }
    }

    var systemImage: String {
        switch self {
        case .all: "bolt.horizontal.circle"
        case .everyone: "globe.asia.australia"
        case .followingUsers: "person.2"
        case .myPixiv: "person.2.crop.square.stack"
        case .mine: "person.crop.circle"
        }
    }

    var staccPath: String {
        switch self {
        case .all: "/stacc/my/home/all/all"
        case .everyone: "/stacc/p/all"
        case .followingUsers: "/stacc/my/home/favorite/all"
        case .myPixiv: "/stacc/my/home/mypixiv/all"
        case .mine: "/stacc/my/home/self/all"
        }
    }
}

enum PixivActivityKindFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case postedArtwork
    case bookmarkedArtwork
    case followedUser
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.pixivActivityKindAll
        case .postedArtwork: PixivActivityKind.postedArtwork.title
        case .bookmarkedArtwork: PixivActivityKind.bookmarkedArtwork.title
        case .followedUser: PixivActivityKind.followedUser.title
        case .unknown: PixivActivityKind.unknown.title
        }
    }

    var systemImage: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .postedArtwork: PixivActivityKind.postedArtwork.systemImage
        case .bookmarkedArtwork: PixivActivityKind.bookmarkedArtwork.systemImage
        case .followedUser: PixivActivityKind.followedUser.systemImage
        case .unknown: PixivActivityKind.unknown.systemImage
        }
    }

    var activityKind: PixivActivityKind? {
        switch self {
        case .all: nil
        case .postedArtwork: .postedArtwork
        case .bookmarkedArtwork: .bookmarkedArtwork
        case .followedUser: .followedUser
        case .unknown: .unknown
        }
    }
}

struct PixivActivityNewMarkerUpdate: Equatable, Sendable {
    let markerDatesByItemID: [String: Date]
    let newItemIDs: Set<String>

    var activeItemIDs: Set<String> {
        Set(markerDatesByItemID.keys)
    }
}

struct PixivActivityRefreshResult: Equatable, Sendable {
    let itemCount: Int
    let newItemIDs: Set<String>

    var newItemCount: Int {
        newItemIDs.count
    }
}

enum PixivActivityFeedPresentation {
    static let defaultLayoutMode: PixivActivityLayoutMode = .masonry
    static let newMarkerLifetime: TimeInterval = 15 * 60

    static func statusText(itemCount: Int) -> String {
        guard itemCount > 0 else { return "" }
        return String(format: L10n.pixivActivityLoadedCountFormat, itemCount)
    }

    static func routeBadgeText(itemCount: Int) -> String? {
        guard itemCount > 0 else { return nil }
        return itemCount > 999 ? "999+" : "\(itemCount)"
    }

    static func filteredItems(
        _ items: [PixivActivityItem],
        kindFilter: PixivActivityKindFilter
    ) -> [PixivActivityItem] {
        guard let kind = kindFilter.activityKind else { return items }
        return items.filter { $0.kind == kind }
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

    static func updatedNewMarkers(
        previousItemIDs: Set<String>,
        refreshedItemIDs: [String],
        existingMarkerDates: [String: Date],
        now: Date = Date(),
        markerLifetime: TimeInterval = newMarkerLifetime
    ) -> PixivActivityNewMarkerUpdate {
        let refreshedIDSet = Set(refreshedItemIDs)
        let activeMarkerDates = existingMarkerDates.filter { itemID, markedAt in
            refreshedIDSet.contains(itemID) && now.timeIntervalSince(markedAt) < markerLifetime
        }

        guard previousItemIDs.isEmpty == false else {
            return PixivActivityNewMarkerUpdate(
                markerDatesByItemID: activeMarkerDates,
                newItemIDs: []
            )
        }

        let newItemIDs = refreshedIDSet.subtracting(previousItemIDs)
        var markerDates = activeMarkerDates
        for itemID in newItemIDs {
            markerDates[itemID] = now
        }
        return PixivActivityNewMarkerUpdate(
            markerDatesByItemID: markerDates,
            newItemIDs: newItemIDs
        )
    }

    private static func kindTitle(for kind: PixivActivityKind) -> String { kind.title }
}

extension PixivActivityKind {
    var title: String {
        switch self {
        case .postedArtwork: L10n.pixivActivityPostedArtwork
        case .bookmarkedArtwork: L10n.pixivActivityBookmarkedArtwork
        case .followedUser: L10n.pixivActivityFollowedUser
        case .unknown: L10n.pixivActivityUnknown
        }
    }

    var systemImage: String {
        switch self {
        case .postedArtwork: "photo.on.rectangle"
        case .bookmarkedArtwork: "bookmark"
        case .followedUser: "person.crop.circle.badge.plus"
        case .unknown: "bolt.horizontal.circle"
        }
    }
}
