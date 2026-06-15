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
