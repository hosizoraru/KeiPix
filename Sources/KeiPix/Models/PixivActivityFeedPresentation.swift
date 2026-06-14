import Foundation

enum PixivActivityFeedPresentation {
    static func statusText(itemCount: Int) -> String {
        guard itemCount > 0 else { return "" }
        return String(format: L10n.pixivActivityLoadedCountFormat, itemCount)
    }
}
