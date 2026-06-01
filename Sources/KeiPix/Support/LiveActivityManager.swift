#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity manager for download progress on Lock Screen.
///
/// Uses ActivityKit to show download progress as a Live Activity
/// on iOS 16.1+ and iPadOS 17.0+.

/// Activity attributes for download progress.
struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Current download progress (0.0 - 1.0).
        var progress: Double
        /// Number of items completed.
        var completedCount: Int
        /// Total number of items.
        var totalCount: Int
        /// Currently downloading item title.
        var currentTitle: String
    }

    /// Fixed attributes about the download session.
    var artworkTitle: String
    var artworkID: Int
}

/// Manages Live Activities for download progress.
final class LiveActivityManager: @unchecked Sendable {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<DownloadActivityAttributes>?

    /// Start a Live Activity for a download session.
    func startActivity(artworkTitle: String, artworkID: Int, totalCount: Int) {
        let attributes = DownloadActivityAttributes(
            artworkTitle: artworkTitle,
            artworkID: artworkID
        )
        let initialState = DownloadActivityAttributes.ContentState(
            progress: 0,
            completedCount: 0,
            totalCount: totalCount,
            currentTitle: artworkTitle
        )

        do {
            currentActivity = try Activity<DownloadActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
        } catch {
            // Live Activities may not be available
        }
    }

    /// Update the Live Activity with new progress.
    func updateProgress(completed: Int, total: Int, currentTitle: String) {
        guard let activity = currentActivity else { return }

        let state = DownloadActivityAttributes.ContentState(
            progress: Double(completed) / Double(total),
            completedCount: completed,
            totalCount: total,
            currentTitle: currentTitle
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// End the Live Activity.
    func endActivity() {
        guard let activity = currentActivity else { return }

        let finalState = DownloadActivityAttributes.ContentState(
            progress: 1.0,
            completedCount: activity.content.state.totalCount,
            totalCount: activity.content.state.totalCount,
            currentTitle: L10n.downloadFinishedNotificationTitle
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 300))
        }
        currentActivity = nil
    }

    /// Cancel the Live Activity without showing completion.
    func cancelActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
#endif
