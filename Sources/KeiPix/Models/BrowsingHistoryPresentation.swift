import Foundation

enum BrowsingHistoryStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case followedCreators
    case bookmarkedWorks
    case followedUnbookmarked
    case bookmarkedUnfollowed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.all
        case .followedCreators:
            L10n.following
        case .bookmarkedWorks:
            L10n.bookmarked
        case .followedUnbookmarked:
            "\(L10n.following) · \(L10n.unbookmarked)"
        case .bookmarkedUnfollowed:
            "\(L10n.bookmarked) · \(L10n.unfollowed)"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "line.3.horizontal.decrease.circle"
        case .followedCreators:
            "person.crop.circle.badge.checkmark"
        case .bookmarkedWorks:
            "bookmark.fill"
        case .followedUnbookmarked:
            "person.crop.circle.badge.checkmark"
        case .bookmarkedUnfollowed:
            "bookmark.circle"
        }
    }

    var isActive: Bool {
        self != .all
    }

    func includes(_ item: LocalArtworkHistoryItem) -> Bool {
        includes(isCreatorFollowed: item.isCreatorFollowed, isBookmarked: item.isBookmarked)
    }

    func includes(_ artwork: PixivArtwork) -> Bool {
        includes(isCreatorFollowed: artwork.user.isFollowed, isBookmarked: artwork.isBookmarked)
    }

    private func includes(isCreatorFollowed: Bool, isBookmarked: Bool) -> Bool {
        switch self {
        case .all:
            true
        case .followedCreators:
            isCreatorFollowed
        case .bookmarkedWorks:
            isBookmarked
        case .followedUnbookmarked:
            isCreatorFollowed && isBookmarked == false
        case .bookmarkedUnfollowed:
            isBookmarked && isCreatorFollowed == false
        }
    }
}

enum BrowsingHistoryTimestampLabel {
    static func shortLabel(
        for date: Date,
        relativeTo now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(
                style(
                    Date.FormatStyle.dateTime
                        .hour()
                        .minute()
                        .locale(locale),
                    calendar: calendar
                )
            )
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(
                style(
                    Date.FormatStyle.dateTime
                        .month(.abbreviated)
                        .day()
                        .locale(locale),
                    calendar: calendar
                )
            )
        }

        return date.formatted(
            style(
                Date.FormatStyle.dateTime
                    .year()
                    .month(.abbreviated)
                    .day()
                    .locale(locale),
                calendar: calendar
            )
        )
    }

    private static func style(_ style: Date.FormatStyle, calendar: Calendar) -> Date.FormatStyle {
        var style = style
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return style
    }
}
