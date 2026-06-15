import SwiftUI

/// Reports the visible count for the current route up to the mobile shell.
///
/// iPhone renders board counts as a badge on the top-left route icon instead
/// of spending content-header space on title/status text. Pages own their
/// visible collections, so they publish the count as a lightweight preference
/// and the shell decides whether the current platform should consume it.
struct MobileRouteBadgePreferenceKey: PreferenceKey {
    static let defaultValue: [PixivRoute: Int] = [:]

    static func reduce(value: inout [PixivRoute: Int], nextValue: () -> [PixivRoute: Int]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func mobileRouteBadgeCount(_ count: Int?, for route: PixivRoute) -> some View {
        preference(
            key: MobileRouteBadgePreferenceKey.self,
            value: count.map { normalizedCount in [route: max(0, normalizedCount)] } ?? [:]
        )
    }
}

/// Lets page-owned lists publish their local filter counts to the iPhone shell.
///
/// Some surfaces, like creator recommendations, own their loaded items inside
/// the page rather than in `KeiPixStore`. The shell still owns the bottom filter
/// pill, so pages report only the lightweight count/placeholder metadata here.
struct MobilePageFilterSnapshot: Equatable {
    let route: PixivRoute
    let totalCount: Int
    let visibleCount: Int
    let placeholder: String
}

struct MobilePageFilterPreferenceKey: PreferenceKey {
    static let defaultValue: [PixivRoute: MobilePageFilterSnapshot] = [:]

    static func reduce(
        value: inout [PixivRoute: MobilePageFilterSnapshot],
        nextValue: () -> [PixivRoute: MobilePageFilterSnapshot]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func mobilePageFilter(_ snapshot: MobilePageFilterSnapshot?) -> some View {
        preference(
            key: MobilePageFilterPreferenceKey.self,
            value: snapshot.map { [$0.route: $0] } ?? [:]
        )
    }
}
