import Foundation

enum PixivRoute: String, CaseIterable, Identifiable, Codable {
    case explore
    case search
    case rankingDaily
    case rankingWeekly
    case rankingMonthly
    case publicBookmarks
    case privateBookmarks
    case following

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore: L10n.explore
        case .search: L10n.search
        case .rankingDaily: L10n.daily
        case .rankingWeekly: L10n.weekly
        case .rankingMonthly: L10n.monthly
        case .publicBookmarks: L10n.publicBookmarks
        case .privateBookmarks: L10n.privateBookmarks
        case .following: L10n.following
        }
    }

    var systemImage: String {
        switch self {
        case .explore: "sparkles"
        case .search: "magnifyingglass"
        case .rankingDaily, .rankingWeekly, .rankingMonthly: "chart.bar"
        case .publicBookmarks, .privateBookmarks: "bookmark"
        case .following: "person.2"
        }
    }
}
