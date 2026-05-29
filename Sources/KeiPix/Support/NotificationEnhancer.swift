#if os(macOS)
import AppKit
import UserNotifications

/// Enhanced notification support for macOS.
///
/// Provides richer notifications than basic UNUserNotificationCenter:
/// - Custom notification content with images
/// - Action buttons in notifications
/// - Notification grouping by category
/// - Sound customization
enum NotificationEnhancer {

    /// Notification categories for grouping.
    enum Category: String {
        case download = "com.keipix.download"
        case update = "com.keipix.update"
        case social = "com.keipix.social"
    }

    /// Register notification categories with actions.
    static func registerCategories() {
        let downloadCategory = UNNotificationCategory(
            identifier: Category.download.rawValue,
            actions: [
                UNNotificationAction(identifier: "open", title: L10n.openDownloads, options: .foreground),
                UNNotificationAction(identifier: "pause", title: L10n.pauseDownloads, options: [])
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let updateCategory = UNNotificationCategory(
            identifier: Category.update.rawValue,
            actions: [
                UNNotificationAction(identifier: "view", title: L10n.openReleaseNotes, options: .foreground),
                UNNotificationAction(identifier: "skip", title: L10n.skipThisVersion, options: [])
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let socialCategory = UNNotificationCategory(
            identifier: Category.social.rawValue,
            actions: [
                UNNotificationAction(identifier: "view", title: L10n.openArticle, options: .foreground)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            downloadCategory,
            updateCategory,
            socialCategory
        ])
    }

    /// Post a notification with custom content.
    static func post(
        title: String,
        body: String,
        category: Category,
        sound: UNNotificationSound? = .default,
        imageData: Data? = nil
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.rawValue
        content.sound = sound

        if let imageData {
            // Create a temporary file for the image attachment
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("notif-\(UUID().uuidString).png")
            try? imageData.write(to: tempURL)
            if let attachment = try? UNNotificationAttachment(identifier: "image", url: tempURL, options: nil) {
                content.attachments = [attachment]
            }
        }

        let request = UNNotificationRequest(
            identifier: "keipix.\(category.rawValue).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Post a download completion notification with artwork thumbnail.
    static func postDownloadComplete(title: String, thumbnailData: Data? = nil) async {
        await post(
            title: L10n.downloadFinishedNotificationTitle,
            body: String(format: L10n.downloadFinishedNotificationBodyFormat, title),
            category: .download,
            imageData: thumbnailData
        )
    }

    /// Post an update available notification.
    static func postUpdateAvailable(version: String) async {
        await post(
            title: L10n.updateAvailableTitle,
            body: String(format: L10n.updateAvailableMessageFormat, version, ""),
            category: .update
        )
    }
}
#endif
