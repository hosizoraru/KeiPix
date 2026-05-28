import Foundation

/// Manages Handoff activity for cross-device continuity.
///
/// Creates and updates NSUserActivity objects so users can continue
/// browsing on another device (Mac → iPad, iPad → Mac, etc.).
///
/// The activity carries the current route and selected artwork ID
/// so the receiving device can restore the exact view state.
@MainActor
final class HandoffManager {
    static let shared = HandoffManager()

    static let activityType = "com.keipix.browse"

    private var currentActivity: NSUserActivity?

    /// Update the Handoff activity to reflect the current browsing state.
    func updateActivity(route: String, artworkID: Int? = nil, userID: Int? = nil) {
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = "KeiPix — \(route)"
        activity.isEligibleForHandoff = true
        activity.persistentIdentifier = "com.keipix.current"

        var userInfo: [String: Any] = ["route": route]
        if let artworkID {
            userInfo["artworkID"] = artworkID
        }
        if let userID {
            userInfo["userID"] = userID
        }
        activity.userInfo = userInfo

        // Web URL for universal links
        if let artworkID {
            activity.webpageURL = URL(string: "https://www.pixiv.net/artworks/\(artworkID)")
        }

        activity.becomeCurrent()
        currentActivity = activity
    }

    /// Clear the current Handoff activity (e.g., on sign out).
    func clearActivity() {
        currentActivity?.resignCurrent()
        currentActivity = nil
    }

    /// Restore state from a received Handoff activity.
    /// Returns the route and artwork ID if present.
    static func restoreState(from activity: NSUserActivity) -> (route: String, artworkID: Int?, userID: Int?)? {
        guard activity.activityType == activityType,
              let userInfo = activity.userInfo,
              let route = userInfo["route"] as? String else {
            return nil
        }

        let artworkID = userInfo["artworkID"] as? Int
        let userID = userInfo["userID"] as? Int
        return (route, artworkID, userID)
    }
}
