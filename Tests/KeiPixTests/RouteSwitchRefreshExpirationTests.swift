import Foundation
import Testing
@testable import KeiPix

struct RouteSwitchRefreshExpirationTests {
    @Test("Timed route refresh expiration keeps recent content and expires old content")
    func timedRouteRefreshExpiration() {
        let now = Date(timeIntervalSince1970: 1_800_000)
        let recent = now.addingTimeInterval(-9 * 60)
        let stale = now.addingTimeInterval(-11 * 60)

        #expect(RouteSwitchRefreshExpiration.tenMinutes.shouldRefresh(
            hasReusableContent: true,
            cachedAt: recent,
            loadedInCurrentSession: true,
            now: now
        ) == false)
        #expect(RouteSwitchRefreshExpiration.tenMinutes.shouldRefresh(
            hasReusableContent: true,
            cachedAt: stale,
            loadedInCurrentSession: true,
            now: now
        ))
        #expect(RouteSwitchRefreshExpiration.twentyMinutes.expirationInterval == Optional(TimeInterval(20 * 60)))
        #expect(RouteSwitchRefreshExpiration.thirtyMinutes.expirationInterval == Optional(TimeInterval(30 * 60)))
    }

    @Test("Session route refresh expiration resets at cold launch")
    func sessionRouteRefreshExpiration() {
        let now = Date(timeIntervalSince1970: 1_800_000)
        let cachedAt = now.addingTimeInterval(-60)

        #expect(RouteSwitchRefreshExpiration.appSession.shouldRefresh(
            hasReusableContent: true,
            cachedAt: cachedAt,
            loadedInCurrentSession: true,
            now: now
        ) == false)
        #expect(RouteSwitchRefreshExpiration.appSession.shouldRefresh(
            hasReusableContent: true,
            cachedAt: cachedAt,
            loadedInCurrentSession: false,
            now: now
        ))
    }

    @Test("Manual route refresh expiration only auto-loads missing content")
    func manualRouteRefreshExpiration() {
        let now = Date(timeIntervalSince1970: 1_800_000)
        let cachedAt = now.addingTimeInterval(-86_400)

        #expect(RouteSwitchRefreshExpiration.manualOnly.shouldRefresh(
            hasReusableContent: true,
            cachedAt: cachedAt,
            loadedInCurrentSession: false,
            now: now
        ) == false)
        #expect(RouteSwitchRefreshExpiration.manualOnly.shouldRefresh(
            hasReusableContent: false,
            cachedAt: nil,
            loadedInCurrentSession: false,
            now: now
        ))
    }
}
