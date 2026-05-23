import Foundation

enum SearchMatchType: String, CaseIterable, Identifiable {
    case partialTags
    case exactTags
    case titleAndCaption

    var id: String { rawValue }

    var title: String {
        switch self {
        case .partialTags:
            L10n.partialTagMatch
        case .exactTags:
            L10n.exactTagMatch
        case .titleAndCaption:
            L10n.titleAndCaption
        }
    }

    var apiValue: String {
        switch self {
        case .partialTags:
            "partial_match_for_tags"
        case .exactTags:
            "exact_match_for_tags"
        case .titleAndCaption:
            "title_and_caption"
        }
    }
}

enum SearchSort: String, CaseIterable, Identifiable {
    case dateDescending
    case dateAscending
    case popularPreview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateDescending:
            L10n.newest
        case .dateAscending:
            L10n.oldest
        case .popularPreview:
            L10n.popular
        }
    }

    var apiValue: String {
        switch self {
        case .dateDescending:
            "date_desc"
        case .dateAscending:
            "date_asc"
        case .popularPreview:
            "popular_desc"
        }
    }
}

enum SearchAgeLimit: String, CaseIterable, Identifiable {
    case unlimited
    case allAges
    case r18

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimited:
            L10n.unlimited
        case .allAges:
            L10n.allAges
        case .r18:
            L10n.r18
        }
    }

    var keywordSuffix: String {
        switch self {
        case .unlimited:
            ""
        case .allAges:
            " -R-18"
        case .r18:
            " R-18"
        }
    }
}

enum SearchDateRange: String, CaseIterable, Identifiable {
    case anytime
    case pastDay
    case pastWeek
    case pastMonth
    case pastYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anytime:
            L10n.anytime
        case .pastDay:
            L10n.pastDay
        case .pastWeek:
            L10n.pastWeek
        case .pastMonth:
            L10n.pastMonth
        case .pastYear:
            L10n.pastYear
        }
    }

    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .anytime:
            nil
        case .pastDay:
            calendar.date(byAdding: .day, value: -1, to: now)
        case .pastWeek:
            calendar.date(byAdding: .day, value: -7, to: now)
        case .pastMonth:
            calendar.date(byAdding: .month, value: -1, to: now)
        case .pastYear:
            calendar.date(byAdding: .year, value: -1, to: now)
        }
    }
}

enum SearchMinimumBookmarks: Int, CaseIterable, Identifiable {
    case none = 0
    case oneHundred = 100
    case fiveHundred = 500
    case oneThousand = 1000
    case fiveThousand = 5000
    case tenThousand = 10000

    var id: Int { rawValue }

    var title: String {
        rawValue == 0 ? L10n.noMinimum : "\(rawValue.formatted())+"
    }
}

enum SearchArtworkType: String, CaseIterable, Identifiable {
    case all
    case illustrations
    case manga

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.allWorks
        case .illustrations:
            L10n.illustrations
        case .manga:
            L10n.manga
        }
    }
}

enum SearchUgoiraFilter: String, CaseIterable, Identifiable {
    case all
    case onlyUgoira
    case noUgoira

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.all
        case .onlyUgoira:
            L10n.onlyUgoira
        case .noUgoira:
            L10n.noUgoira
        }
    }
}

struct SearchOptions {
    var matchType: SearchMatchType
    var sort: SearchSort
    var ageLimit: SearchAgeLimit
    var dateRange: SearchDateRange
    var minimumBookmarks: SearchMinimumBookmarks
    var artworkType: SearchArtworkType
    var ugoiraFilter: SearchUgoiraFilter
}
