import Foundation

protocol SearchFilterOptionTitle {
    var title: String { get }
}

enum SearchMatchType: String, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
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

enum SearchSort: String, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
    case dateDescending
    case dateAscending
    case popularPreview
    case popularMale
    case popularFemale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateDescending:
            L10n.newest
        case .dateAscending:
            L10n.oldest
        case .popularPreview:
            L10n.popular
        case .popularMale:
            L10n.popularMale
        case .popularFemale:
            L10n.popularFemale
        }
    }

    func title(isPremium: Bool) -> String {
        switch self {
        case .popularPreview where isPremium == false:
            L10n.popularLimitedPreview
        case .dateDescending, .dateAscending, .popularPreview, .popularMale, .popularFemale:
            title
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
        case .popularMale:
            "popular_male_desc"
        case .popularFemale:
            "popular_female_desc"
        }
    }

    var requiresPixivPremium: Bool {
        switch self {
        case .popularMale, .popularFemale:
            true
        case .dateDescending, .dateAscending, .popularPreview:
            false
        }
    }

    static func availableCases(isPremium: Bool) -> [SearchSort] {
        allCases.filter { isPremium || $0.requiresPixivPremium == false }
    }

    static func selectableCases(isPremium: Bool) -> [SearchSort] {
        availableCases(isPremium: isPremium)
    }

    static var premiumOnlyCases: [SearchSort] {
        allCases.filter(\.requiresPixivPremium)
    }
}

enum SearchAgeLimit: String, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
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

enum SearchDateRange: String, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
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

enum SearchMinimumBookmarks: Int, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
    case none = 0
    case oneHundred = 100
    case fiveHundred = 500
    case oneThousand = 1000
    case fiveThousand = 5000
    case tenThousand = 10000
    case twentyThousand = 20000
    case fiftyThousand = 50000
    case oneHundredThousand = 100000

    var id: Int { rawValue }

    var title: String {
        rawValue == 0 ? L10n.noMinimum : "\(rawValue.formatted())+"
    }
}

enum SearchMaximumBookmarks: Int, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
    case none = 0
    case oneHundred = 100
    case fiveHundred = 500
    case oneThousand = 1000
    case fiveThousand = 5000
    case tenThousand = 10000
    case twentyThousand = 20000
    case fiftyThousand = 50000
    case oneHundredThousand = 100000

    var id: Int { rawValue }

    var title: String {
        rawValue == 0 ? L10n.noMaximum : "\(rawValue.formatted())"
    }
}

enum SearchArtworkType: String, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
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

enum SearchUgoiraFilter: String, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
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

enum SearchAIFilter: String, CaseIterable, Identifiable, Codable, SearchFilterOptionTitle {
    case all
    case excludeAI
    case onlyAI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.all
        case .excludeAI:
            L10n.excludeAI
        case .onlyAI:
            L10n.onlyAI
        }
    }

    var apiValue: String? {
        switch self {
        case .all:
            nil
        case .excludeAI:
            "1"
        case .onlyAI:
            "2"
        }
    }
}

struct SearchOptions: Codable, Hashable, Sendable {
    var matchType: SearchMatchType
    var sort: SearchSort
    var ageLimit: SearchAgeLimit
    var dateRange: SearchDateRange
    var minimumBookmarks: SearchMinimumBookmarks
    var maximumBookmarks: SearchMaximumBookmarks
    var artworkType: SearchArtworkType
    var aiFilter: SearchAIFilter
    var ugoiraFilter: SearchUgoiraFilter

    static let defaultValue = SearchOptions(
        matchType: .partialTags,
        sort: .dateDescending,
        ageLimit: .unlimited,
        dateRange: .anytime,
        minimumBookmarks: .none,
        maximumBookmarks: .none,
        artworkType: .all,
        aiFilter: .all,
        ugoiraFilter: .all
    )

    init(
        matchType: SearchMatchType,
        sort: SearchSort,
        ageLimit: SearchAgeLimit,
        dateRange: SearchDateRange,
        minimumBookmarks: SearchMinimumBookmarks,
        maximumBookmarks: SearchMaximumBookmarks,
        artworkType: SearchArtworkType,
        aiFilter: SearchAIFilter,
        ugoiraFilter: SearchUgoiraFilter
    ) {
        self.matchType = matchType
        self.sort = sort
        self.ageLimit = ageLimit
        self.dateRange = dateRange
        self.minimumBookmarks = minimumBookmarks
        self.maximumBookmarks = maximumBookmarks
        self.artworkType = artworkType
        self.aiFilter = aiFilter
        self.ugoiraFilter = ugoiraFilter
    }

    enum CodingKeys: String, CodingKey {
        case matchType
        case sort
        case ageLimit
        case dateRange
        case minimumBookmarks
        case maximumBookmarks
        case artworkType
        case aiFilter
        case ugoiraFilter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matchType = try container.decodeIfPresent(SearchMatchType.self, forKey: .matchType) ?? .partialTags
        sort = try container.decodeIfPresent(SearchSort.self, forKey: .sort) ?? .dateDescending
        ageLimit = try container.decodeIfPresent(SearchAgeLimit.self, forKey: .ageLimit) ?? .unlimited
        dateRange = try container.decodeIfPresent(SearchDateRange.self, forKey: .dateRange) ?? .anytime
        minimumBookmarks = try container.decodeIfPresent(SearchMinimumBookmarks.self, forKey: .minimumBookmarks) ?? .none
        maximumBookmarks = try container.decodeIfPresent(SearchMaximumBookmarks.self, forKey: .maximumBookmarks) ?? .none
        artworkType = try container.decodeIfPresent(SearchArtworkType.self, forKey: .artworkType) ?? .all
        aiFilter = try container.decodeIfPresent(SearchAIFilter.self, forKey: .aiFilter) ?? .all
        ugoiraFilter = try container.decodeIfPresent(SearchUgoiraFilter.self, forKey: .ugoiraFilter) ?? .all
    }

    var isDefault: Bool {
        self == Self.defaultValue
    }

    var summary: String {
        [
            matchType.title,
            sort.title,
            ageLimit.title,
            dateRange.title,
            minimumBookmarks.title,
            maximumBookmarks.title,
            artworkType.title,
            aiFilter.title,
            ugoiraFilter.title
        ].joined(separator: " · ")
    }
}

struct SavedSearchPreset: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var keyword: String
    var options: SearchOptions
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        keyword: String,
        options: SearchOptions,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.keyword = keyword
        self.options = options
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SavedSearchLibraryExport: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var exportedAt: Date
    var presets: [SavedSearchPreset]
    var savedSearches: [String]
    var searchHistory: [String]

    init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        presets: [SavedSearchPreset],
        savedSearches: [String],
        searchHistory: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.presets = presets
        self.savedSearches = savedSearches
        self.searchHistory = searchHistory
    }
}

struct SavedSearchLibraryImportSummary: Hashable, Sendable {
    let presetCount: Int
    let savedSearchCount: Int
    let historyCount: Int

    var totalCount: Int {
        presetCount + savedSearchCount + historyCount
    }
}
