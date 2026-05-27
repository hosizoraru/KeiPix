import Foundation
import UserNotifications

/// Posts a macOS Notification Center banner when an artwork finishes
/// downloading. Lives on the main actor because it's driven directly
/// from `ArtworkDownloadStore.markCompleted` and we want the
/// debounce timer to land on the same scheduler the store mutates on.
///
/// Coalescing strategy mirrors how Finder reports a copy: one banner
/// per quiescent burst. We keep a buffer of completion titles, debounce
/// for `coalesceWindowSeconds` after the most recent finish, then post
/// a single banner — naming the item if there's exactly one, or a
/// batch count if more landed during the window. This keeps a 50-image
/// queue from spawning 50 banners on top of each other.
@MainActor
final class DownloadCompletionNotifier {
    private let center: any UserNotificationCenterPosting
    private let authorizationStore: AuthorizationCacheStore
    private let coalesceWindowSeconds: TimeInterval
    private var pendingTitles: [String] = []
    private var coalesceTask: Task<Void, Never>?

    init(
        center: any UserNotificationCenterPosting = UNUserNotificationCenter.current(),
        authorizationStore: AuthorizationCacheStore = .userDefaults,
        coalesceWindowSeconds: TimeInterval = 1.5
    ) {
        self.center = center
        self.authorizationStore = authorizationStore
        self.coalesceWindowSeconds = coalesceWindowSeconds
    }

    /// Requests authorization the first time the user opts in. macOS
    /// remembers the answer in System Settings → Notifications, so we
    /// only ask once per install — `authorizationStore` records that we
    /// asked so a no-op call from the toggle's setter doesn't re-prompt.
    /// Returns `true` when the system reports the app is authorized to
    /// post (or already authorized); the settings toggle uses the
    /// return value to decide whether to flip itself back off.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        if authorizationStore.hasRequestedAuthorization {
            return await center.isAuthorizedToPost()
        }
        authorizationStore.markAuthorizationRequested()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Buffers a completed-item title and arms the debounce. The actual
    /// banner fires once `coalesceWindowSeconds` of quiet has elapsed,
    /// so a burst of finishes turns into one banner with a count.
    func recordCompletion(title: String) {
        pendingTitles.append(title)
        coalesceTask?.cancel()
        coalesceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.coalesceWindowSeconds ?? 1.5))
            guard Task.isCancelled == false else { return }
            await self?.flushPendingNotifications()
        }
    }

    /// Drops any buffered completions without posting. Called when the
    /// queue is paused or the user cancels in bulk so a stale "1
    /// download finished" doesn't fire after the affected workers
    /// abandoned their tasks.
    func flushBuffer() {
        pendingTitles.removeAll()
        coalesceTask?.cancel()
        coalesceTask = nil
    }

    private func flushPendingNotifications() async {
        let titles = pendingTitles
        pendingTitles.removeAll()
        coalesceTask = nil
        guard titles.isEmpty == false else { return }

        guard await center.isAuthorizedToPost() else {
            KeiPixLog.downloads.info("Download finish banner suppressed: notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        if titles.count == 1 {
            content.title = L10n.downloadFinishedNotificationTitle
            content.body = String(format: L10n.downloadFinishedNotificationBodyFormat, titles[0])
        } else {
            content.title = L10n.downloadsFinishedNotificationTitle
            content.body = String(format: L10n.downloadsFinishedNotificationBodyFormat, titles.count)
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "kei.download.finish.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
            KeiPixLog.downloads.info("Posted download finish banner for \(titles.count, privacy: .public) item(s)")
        } catch {
            KeiPixLog.downloads.error(
                "Failed to post download finish banner: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

/// Persists the "we already asked for auth" bit so the toggle's setter
/// doesn't re-prompt. Bridged via a protocol so unit tests can swap in
/// an in-memory store without leaking state into UserDefaults.
protocol AuthorizationCacheStore: Sendable {
    var hasRequestedAuthorization: Bool { get }
    func markAuthorizationRequested()
}

extension AuthorizationCacheStore where Self == UserDefaultsAuthorizationCacheStore {
    static var userDefaults: UserDefaultsAuthorizationCacheStore {
        UserDefaultsAuthorizationCacheStore()
    }
}

struct UserDefaultsAuthorizationCacheStore: AuthorizationCacheStore {
    private static let key = "downloadFinishNotificationsAuthRequested"

    var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: Self.key)
    }

    func markAuthorizationRequested() {
        UserDefaults.standard.set(true, forKey: Self.key)
    }
}

/// Mockable surface over `UNUserNotificationCenter` so the notifier
/// can be unit-tested without touching the real Notification Center.
/// The real `UNUserNotificationCenter` already exposes async variants
/// of every method we need; the protocol just narrows the surface.
@MainActor
protocol UserNotificationCenterPosting {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func isAuthorizedToPost() async -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: UserNotificationCenterPosting {
    func isAuthorizedToPost() async -> Bool {
        let settings = await notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }
}
