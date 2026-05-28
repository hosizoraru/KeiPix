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
        presentLocalSampleFeed(for: selectedRoute.usesArtworkFeed ? selectedRoute : .illustrations)
    }
}
