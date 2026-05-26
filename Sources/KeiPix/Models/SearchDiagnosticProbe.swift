import Foundation

struct SearchDiagnosticProbe: Identifiable, Hashable {
    let id: String
    let title: String
    let keyword: String
    let options: SearchOptions

    static let defaultKeyword = "landscape"

    static var defaultProbes: [SearchDiagnosticProbe] {
        [
            probe(id: "popular-preview", sort: .popularPreview),
            probe(id: "popular-male", sort: .popularMale),
            probe(id: "popular-female", sort: .popularFemale)
        ]
    }

    private static func probe(id: String, sort: SearchSort) -> SearchDiagnosticProbe {
        SearchDiagnosticProbe(
            id: id,
            title: sort.title,
            keyword: defaultKeyword,
            options: SearchOptions(
                matchType: .partialTags,
                sort: sort,
                ageLimit: .allAges,
                dateRange: .anytime,
                minimumBookmarks: .unlimited,
                maximumBookmarks: .unlimited,
                artworkType: .all,
                aiFilter: .all,
                ugoiraFilter: .all
            )
        )
    }
}
