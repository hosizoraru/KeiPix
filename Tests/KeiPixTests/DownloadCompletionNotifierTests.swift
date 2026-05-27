import Foundation
import Testing
import UserNotifications
@testable import KeiPix

@MainActor
@Suite("Download finish notifier", .serialized)
struct DownloadCompletionNotifierTests {

    @Test("Single completion fires exactly one banner after the coalesce window")
    func singleCompletion() async throws {
        let center = FakeUserNotificationCenter(isAuthorized: true)
        let auth = InMemoryAuthorizationCacheStore(hasRequested: true)
        let notifier = DownloadCompletionNotifier(
            center: center,
            authorizationStore: auth,
            coalesceWindowSeconds: 0.10
        )

        notifier.recordCompletion(title: "First")
        // Coalesce window is 100 ms; we wait long enough that even under
        // parallel test load the unstructured Task.sleep + @MainActor hop
        // back into flushPendingNotifications has finished. Earlier
        // 50 ms / 120 ms tuning was tight enough to flake on busy runners.
        try await Task.sleep(for: .milliseconds(400))

        #expect(center.added.count == 1)
        #expect(center.added.first?.content.body == "First")
    }

    @Test("Burst of completions inside the window collapses into one batch banner")
    func burstCoalesces() async throws {
        let center = FakeUserNotificationCenter(isAuthorized: true)
        let auth = InMemoryAuthorizationCacheStore(hasRequested: true)
        let notifier = DownloadCompletionNotifier(
            center: center,
            authorizationStore: auth,
            coalesceWindowSeconds: 0.08
        )

        for index in 0..<5 {
            notifier.recordCompletion(title: "Item \(index)")
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(150))

        #expect(center.added.count == 1)
        // Body for batch path uses %d so the count must appear; we
        // don't assert the exact string so localisation can shift it.
        #expect(center.added.first?.content.body.contains("5") == true)
    }

    @Test("Denied authorization keeps the buffer from posting")
    func deniedAuthSuppressesPost() async throws {
        let center = FakeUserNotificationCenter(isAuthorized: false)
        let auth = InMemoryAuthorizationCacheStore(hasRequested: true)
        let notifier = DownloadCompletionNotifier(
            center: center,
            authorizationStore: auth,
            coalesceWindowSeconds: 0.05
        )

        notifier.recordCompletion(title: "Quiet")
        try await Task.sleep(for: .milliseconds(120))

        #expect(center.added.isEmpty)
    }

    @Test("flushBuffer drops pending completions before they post")
    func flushBufferDropsPending() async throws {
        let center = FakeUserNotificationCenter(isAuthorized: true)
        let auth = InMemoryAuthorizationCacheStore(hasRequested: true)
        let notifier = DownloadCompletionNotifier(
            center: center,
            authorizationStore: auth,
            coalesceWindowSeconds: 0.10
        )

        notifier.recordCompletion(title: "Will be cancelled")
        notifier.flushBuffer()
        try await Task.sleep(for: .milliseconds(150))

        #expect(center.added.isEmpty)
    }

    @Test("First opt-in asks Notification Center for authorization exactly once")
    func authorizationRequestedOnce() async throws {
        let center = FakeUserNotificationCenter(
            isAuthorized: false,
            grantAuthorization: true
        )
        let auth = InMemoryAuthorizationCacheStore(hasRequested: false)
        let notifier = DownloadCompletionNotifier(
            center: center,
            authorizationStore: auth,
            coalesceWindowSeconds: 0.05
        )

        let firstCall = await notifier.requestAuthorizationIfNeeded()
        let secondCall = await notifier.requestAuthorizationIfNeeded()

        #expect(firstCall == true)
        #expect(secondCall == true)
        #expect(center.requestAuthorizationCallCount == 1)
        #expect(auth.hasRequestedAuthorization == true)
    }
}

@MainActor
final class FakeUserNotificationCenter: UserNotificationCenterPosting {
    var added: [UNNotificationRequest] = []
    var requestAuthorizationCallCount = 0
    private(set) var isAuthorized: Bool
    private let grantAuthorization: Bool

    init(isAuthorized: Bool, grantAuthorization: Bool = true) {
        self.isAuthorized = isAuthorized
        self.grantAuthorization = grantAuthorization
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        if grantAuthorization {
            isAuthorized = true
        }
        return grantAuthorization
    }

    func isAuthorizedToPost() async -> Bool {
        isAuthorized
    }

    func add(_ request: UNNotificationRequest) async throws {
        added.append(request)
    }
}

final class InMemoryAuthorizationCacheStore: AuthorizationCacheStore, @unchecked Sendable {
    var hasRequestedAuthorization: Bool

    init(hasRequested: Bool) {
        self.hasRequestedAuthorization = hasRequested
    }

    func markAuthorizationRequested() {
        hasRequestedAuthorization = true
    }
}
