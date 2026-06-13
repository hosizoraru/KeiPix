import Foundation

struct PixivRemoteSearchOptions: Decodable, Hashable, Sendable {
    let illust: PixivRemoteIllustrationSearchOptions
    let novel: PixivRemoteNovelSearchOptions
}

struct PixivRemoteIllustrationSearchOptions: Decodable, Hashable, Sendable {
    let bookmarkRanges: [PixivRemoteSearchBookmarkRange]
    let showAICondition: Bool
    let languages: PixivRemoteSearchOptionList<PixivRemoteSearchLanguage>
    let tools: PixivRemoteSearchOptionList<String>

    enum CodingKeys: String, CodingKey {
        case bookmarkRanges = "bookmark_ranges"
        case showAICondition = "show_ai_condition"
        case languages = "lang"
        case tools = "tool"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookmarkRanges = try container.decodeIfPresent([PixivRemoteSearchBookmarkRange].self, forKey: .bookmarkRanges) ?? []
        showAICondition = try container.decodeIfPresent(Bool.self, forKey: .showAICondition) ?? false
        languages = try container.decodeIfPresent(PixivRemoteSearchOptionList.self, forKey: .languages) ?? .empty
        tools = try container.decodeIfPresent(PixivRemoteSearchOptionList.self, forKey: .tools) ?? .empty
    }
}

struct PixivRemoteNovelSearchOptions: Decodable, Hashable, Sendable {
    let bookmarkRanges: [PixivRemoteSearchBookmarkRange]
    let showAICondition: Bool
    let languages: PixivRemoteSearchOptionList<PixivRemoteSearchLanguage>
    let genres: PixivRemoteSearchOptionList<PixivRemoteSearchGenre>
    let wordCountSupportedLanguages: String

    enum CodingKeys: String, CodingKey {
        case bookmarkRanges = "bookmark_ranges"
        case showAICondition = "show_ai_condition"
        case languages = "lang"
        case genres = "genre"
        case wordCountSupportedLanguages = "word_count_supported_languages"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookmarkRanges = try container.decodeIfPresent([PixivRemoteSearchBookmarkRange].self, forKey: .bookmarkRanges) ?? []
        showAICondition = try container.decodeIfPresent(Bool.self, forKey: .showAICondition) ?? false
        languages = try container.decodeIfPresent(PixivRemoteSearchOptionList.self, forKey: .languages) ?? .empty
        genres = try container.decodeIfPresent(PixivRemoteSearchOptionList.self, forKey: .genres) ?? .empty
        wordCountSupportedLanguages = try container.decodeIfPresent(String.self, forKey: .wordCountSupportedLanguages) ?? ""
    }

    var wordCountSupportedLanguageCodes: [String] {
        wordCountSupportedLanguages
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}

enum SearchBookmarkThresholdBoundary: Sendable {
    case minimum
    case maximum
}

struct PixivRemoteSearchOptionList<Option: Decodable & Hashable & Sendable>: Decodable, Hashable, Sendable {
    let options: [Option]

    static var empty: Self { Self(options: []) }
}

struct PixivRemoteSearchBookmarkRange: Decodable, Hashable, Sendable {
    let minimum: Int?
    let maximum: Int?

    enum CodingKeys: String, CodingKey {
        case minimum = "bookmark_num_min"
        case maximum = "bookmark_num_max"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimum = Self.boundValue(try container.decodeIfPresent(String.self, forKey: .minimum))
        maximum = Self.boundValue(try container.decodeIfPresent(String.self, forKey: .maximum))
    }

    private static func boundValue(_ value: String?) -> Int? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value != "*",
              value.isEmpty == false else {
            return nil
        }
        return Int(value)
    }
}

extension PixivRemoteIllustrationSearchOptions {
    func bookmarkThresholdPresetRungs(for boundary: SearchBookmarkThresholdBoundary) -> [Int] {
        SearchBookmarkThreshold.presetRungs(from: bookmarkRanges, for: boundary)
    }
}

extension PixivRemoteNovelSearchOptions {
    func bookmarkThresholdPresetRungs(for boundary: SearchBookmarkThresholdBoundary) -> [Int] {
        SearchBookmarkThreshold.presetRungs(from: bookmarkRanges, for: boundary)
    }
}

struct PixivRemoteSearchLanguage: Decodable, Hashable, Sendable {
    let code: String
    let name: String
}

struct PixivRemoteSearchGenre: Decodable, Hashable, Sendable {
    let id: Int
    let label: String
}

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

    func showsPixivPremiumMarker(isPremium: Bool) -> Bool {
        requiresPixivPremium || (self == .popularPreview && isPremium == false)
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

/// Numeric bookmark threshold used by `bookmark_num_min` /
/// `bookmark_num_max` on Pixiv's search endpoint. We carry an
/// arbitrary integer value plus a curated list of preset rungs so the
/// UI can offer one-click ladder picks (100 / 500 / 1k / 5k / …) and
/// still let power users type "237" for surgical filtering.
///
/// **Why the keyed Codable.** Older snapshots stored the threshold as
/// a single `Int` rawValue (the legacy `SearchMinimumBookmarks` /
/// `SearchMaximumBookmarks` enums). The decoder accepts both shapes —
/// raw `Int`, or `{ "value": 500 }` — so saved-search presets and
/// FeedSnapshot keys round-trip across the upgrade without forcing
/// users to re-create their library.
struct SearchBookmarkThreshold: Codable, Hashable, Sendable, SearchFilterOptionTitle {
    /// `0` means "no filter". Negative values are clamped at decode.
    var value: Int

    init(value: Int) {
        self.value = max(0, value)
    }

    static let unlimited = SearchBookmarkThreshold(value: 0)

    /// Quick-pick rungs for the menu. Matches Pixez's preset ladder so
    /// muscle memory transfers across clients.
    static let presetRungs: [Int] = [
        0, 100, 500, 1_000, 5_000, 10_000, 20_000, 50_000, 100_000
    ]

    static func presetRungs(
        from remoteRanges: [PixivRemoteSearchBookmarkRange],
        for boundary: SearchBookmarkThresholdBoundary
    ) -> [Int] {
        let remoteValues = remoteRanges.compactMap { range -> Int? in
            let value: Int?
            switch boundary {
            case .minimum:
                value = range.minimum
            case .maximum:
                value = range.maximum
            }
            guard let value, value > 0 else { return nil }
            return value
        }

        let sortedValues = Array(Set(remoteValues)).sorted()
        guard sortedValues.isEmpty == false else { return presetRungs }
        return [0] + sortedValues
    }

    var isUnlimited: Bool { value <= 0 }

    var matchesPreset: Bool {
        Self.presetRungs.contains(value)
    }

    var title: String {
        if isUnlimited { return L10n.noBookmarkLimit }
        return value.formatted()
    }

    /// Decoder accepts both legacy raw-Int payloads and the new
    /// `{ "value": N }` shape.
    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(Int.self) {
            self.init(value: single)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 0
        self.init(value: value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
    }

    private enum CodingKeys: String, CodingKey { case value }
}

struct SearchOptions: Codable, Hashable, Sendable {
    var matchType: SearchMatchType
    var sort: SearchSort
    var ageLimit: SearchAgeLimit
    var dateRange: SearchDateRange
    var minimumBookmarks: SearchBookmarkThreshold
    var maximumBookmarks: SearchBookmarkThreshold
    var artworkType: SearchArtworkType
    var aiFilter: SearchAIFilter
    var ugoiraFilter: SearchUgoiraFilter

    static let defaultValue = SearchOptions(
        matchType: .partialTags,
        sort: .dateDescending,
        ageLimit: .unlimited,
        dateRange: .anytime,
        minimumBookmarks: .unlimited,
        maximumBookmarks: .unlimited,
        artworkType: .all,
        aiFilter: .all,
        ugoiraFilter: .all
    )

    init(
        matchType: SearchMatchType,
        sort: SearchSort,
        ageLimit: SearchAgeLimit,
        dateRange: SearchDateRange,
        minimumBookmarks: SearchBookmarkThreshold,
        maximumBookmarks: SearchBookmarkThreshold,
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
        minimumBookmarks = try container.decodeIfPresent(SearchBookmarkThreshold.self, forKey: .minimumBookmarks) ?? .unlimited
        maximumBookmarks = try container.decodeIfPresent(SearchBookmarkThreshold.self, forKey: .maximumBookmarks) ?? .unlimited
        artworkType = try container.decodeIfPresent(SearchArtworkType.self, forKey: .artworkType) ?? .all
        aiFilter = try container.decodeIfPresent(SearchAIFilter.self, forKey: .aiFilter) ?? .all
        ugoiraFilter = try container.decodeIfPresent(SearchUgoiraFilter.self, forKey: .ugoiraFilter) ?? .all
    }

    var isDefault: Bool {
        self == Self.defaultValue
    }

    var summary: String {
        let bookmarkSummary: String
        switch (minimumBookmarks.isUnlimited, maximumBookmarks.isUnlimited) {
        case (true, true):
            bookmarkSummary = L10n.noBookmarkLimit
        case (false, true):
            bookmarkSummary = String(format: L10n.bookmarkAtLeastFormat, minimumBookmarks.value.formatted())
        case (true, false):
            bookmarkSummary = String(format: L10n.bookmarkAtMostFormat, maximumBookmarks.value.formatted())
        case (false, false):
            bookmarkSummary = String(
                format: L10n.bookmarkBetweenFormat,
                minimumBookmarks.value.formatted(),
                maximumBookmarks.value.formatted()
            )
        }
        return [
            matchType.title,
            sort.title,
            ageLimit.title,
            dateRange.title,
            bookmarkSummary,
            artworkType.title,
            aiFilter.title,
            ugoiraFilter.title
        ].joined(separator: " · ")
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
