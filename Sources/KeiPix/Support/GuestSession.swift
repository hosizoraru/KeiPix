import Foundation

/// Guest session for browsing without login.
///
/// Provides a minimal PixivSession that allows users to browse
/// public content without authenticating. Available in all builds.
enum GuestSession {
    /// A minimal guest session for unauthenticated browsing.
    static let session: PixivSession = {
        let payload = """
        {
          "accessToken": "guest-preview-access-token",
          "refreshToken": "guest-preview-refresh-token",
          "user": {
            "id": "5000",
            "name": "Guest Preview",
            "account": "guest_preview",
            "is_premium": false
          }
        }
        """
        return try! JSONDecoder().decode(PixivSession.self, from: Data(payload.utf8))
    }()
}

extension KeiPixStore {
    /// Activate guest mode for browsing without login.
    func activateGuestMode() {
        accountSessionMode = .guest
        UserDefaults.standard.set(AccountSessionMode.guest.rawValue, forKey: "accountSessionMode")
        UserDefaults.standard.set(true, forKey: "accountSessionModeUserSelected")
        session = GuestSession.session
        restrictedModeEnabled = false
        isLoginPresented = false
        #if DEBUG
        presentLocalSampleFeed(for: selectedRoute.usesArtworkFeed ? selectedRoute : .illustrations)
        #else
        Task { await reloadCurrentFeed() }
        #endif
    }

    #if !DEBUG
    /// Stub for release builds — presentLocalSampleFeed is DEBUG-only.
    func presentLocalSampleFeed(for route: PixivRoute) {
        // No-op in release builds
    }

    /// Stub for release builds — presentCachedFeedVisualQA is DEBUG-only.
    func presentCachedFeedVisualQA() {
        // No-op in release builds
    }
    #endif
}
