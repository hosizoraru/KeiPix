import Foundation

enum RouteSwitchRefreshExpiration: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case tenMinutes
    case twentyMinutes
    case thirtyMinutes
    case appSession
    case manualOnly

    static let defaultsKey = "routeSwitchRefreshExpiration"
    static let defaultValue: RouteSwitchRefreshExpiration = .tenMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tenMinutes: L10n.routeSwitchRefreshTenMinutes
        case .twentyMinutes: L10n.routeSwitchRefreshTwentyMinutes
        case .thirtyMinutes: L10n.routeSwitchRefreshThirtyMinutes
        case .appSession: L10n.routeSwitchRefreshAppSession
        case .manualOnly: L10n.routeSwitchRefreshManualOnly
        }
    }

    var systemImage: String {
        switch self {
        case .tenMinutes, .twentyMinutes, .thirtyMinutes: "clock"
        case .appSession: "app.dashed"
        case .manualOnly: "hand.tap"
        }
    }

    var expirationInterval: TimeInterval? {
        switch self {
        case .tenMinutes: 10 * 60
        case .twentyMinutes: 20 * 60
        case .thirtyMinutes: 30 * 60
        case .appSession, .manualOnly: nil
        }
    }

    func shouldRefresh(
        hasReusableContent: Bool,
        cachedAt: Date?,
        loadedInCurrentSession: Bool,
        now: Date = Date()
    ) -> Bool {
        guard hasReusableContent else { return true }

        switch self {
        case .tenMinutes, .twentyMinutes, .thirtyMinutes:
            guard let cachedAt, let expirationInterval else {
                return loadedInCurrentSession == false
            }
            return now.timeIntervalSince(cachedAt) >= expirationInterval
        case .appSession:
            return loadedInCurrentSession == false
        case .manualOnly:
            return false
        }
    }
}
