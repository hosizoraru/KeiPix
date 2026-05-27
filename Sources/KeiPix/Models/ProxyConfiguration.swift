import Foundation

/// Application-level proxy preference.
///
/// Three modes match what every desktop client (Pixez, Pixes, Finder
/// itself) ships:
///
/// - `.system` follows the macOS network preferences. This is the
///   default — the safest fallback because Apple's stack already reads
///   the system proxy when `connectionProxyDictionary` is `nil`.
/// - `.direct` forces a no-proxy connection even when the system has
///   one set. Useful when the user wants KeiPix to bypass a corporate
///   proxy that doesn't allow Pixiv hosts.
/// - `.manual(host, port, scheme)` routes every Pixiv API and image
///   request through the given proxy. The scheme picks which CFNetwork
///   keys we set on the URLSession configuration.
///
/// This type is value-typed and `Sendable` so the URLSession owners
/// can read a snapshot during init and rebuild their session on
/// change without locking.
enum ProxyConfiguration: Equatable, Sendable {
    case system
    case direct
    case manual(host: String, port: Int, scheme: ProxyScheme)

    static let `default`: ProxyConfiguration = .system

    /// Builds the dictionary URLSession passes to CFNetwork via
    /// `connectionProxyDictionary`. Returning `nil` lets the session
    /// fall back to the system configuration — that's how `.system`
    /// stays in sync with macOS network preferences.
    ///
    /// We deliberately avoid the `kCFProxyTypeAutoConfigurationURL`
    /// (PAC) path: it requires an extra fetch every connection and
    /// the user-facing UI doesn't expose it.
    var connectionProxyDictionary: [AnyHashable: Any]? {
        switch self {
        case .system:
            return nil
        case .direct:
            // An empty dictionary tells CFNetwork "no proxy", which is
            // different from `nil` (which means "use system"). Setting
            // each `Enable` key to 0 makes the disable explicit and
            // survives any URLSessionConfiguration template that might
            // copy the proxy keys forward.
            return [
                kCFNetworkProxiesHTTPEnable: 0,
                kCFNetworkProxiesHTTPSEnable: 0,
                kCFNetworkProxiesSOCKSEnable: 0
            ]
        case let .manual(host, port, scheme):
            return scheme.proxyDictionary(host: host, port: port)
        }
    }
}

/// Scheme picker for manual proxy mode. Mirrors the three CFNetwork
/// proxy categories that ship on macOS: HTTP, HTTPS (CONNECT-style),
/// and SOCKS v5.
enum ProxyScheme: String, CaseIterable, Identifiable, Sendable {
    case http
    case https
    case socks5

    var id: String { rawValue }

    /// CFNetwork enable / host / port keys for this scheme. Returned
    /// as a dictionary so the proxy-configuration builder can compose
    /// it directly.
    func proxyDictionary(host: String, port: Int) -> [AnyHashable: Any] {
        switch self {
        case .http:
            return [
                kCFNetworkProxiesHTTPEnable: 1,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port
            ]
        case .https:
            return [
                kCFNetworkProxiesHTTPSEnable: 1,
                kCFNetworkProxiesHTTPSProxy: host,
                kCFNetworkProxiesHTTPSPort: port
            ]
        case .socks5:
            return [
                kCFNetworkProxiesSOCKSEnable: 1,
                kCFNetworkProxiesSOCKSProxy: host,
                kCFNetworkProxiesSOCKSPort: port
            ]
        }
    }
}

/// Storage / discriminator for `ProxyConfiguration` so the store can
/// keep one UserDefaults key per field instead of trying to encode an
/// enum-with-associated-values blob. The mode + manual fields persist
/// as four primitives (mode raw value, host string, port int, scheme
/// raw value) — losing the manual-mode payload when the user flips
/// back to system / direct, then restoring it on next manual-mode
/// switch, mirrors Pixez's own proxy panel.
enum ProxyConfigurationMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case direct
    case manual

    var id: String { rawValue }
}

extension ProxyConfiguration {
    /// UserDefaults keys we persist the proxy configuration into.
    /// Centralised so `URLSession` owners that init before the store
    /// (PixivAPI, ImagePipeline) can read the same snapshot.
    enum DefaultsKey {
        static let mode = "proxyConfigurationMode"
        static let host = "proxyConfigurationHost"
        static let port = "proxyConfigurationPort"
        static let scheme = "proxyConfigurationScheme"
    }

    /// Reads the persisted proxy configuration straight from
    /// UserDefaults. Used by URLSession owners (PixivAPI,
    /// ImagePipeline) that init before the store exists — the store
    /// keeps the same snapshot in sync via its observable properties.
    ///
    /// Manual mode falls back to `.system` when the host string is
    /// empty so a half-configured proxy can never block all traffic.
    static func loadFromUserDefaults(_ defaults: UserDefaults = .standard) -> ProxyConfiguration {
        let rawMode = defaults.string(forKey: DefaultsKey.mode) ?? ""
        let mode = ProxyConfigurationMode(rawValue: rawMode) ?? .system
        switch mode {
        case .system:
            return .system
        case .direct:
            return .direct
        case .manual:
            let host = (defaults.string(forKey: DefaultsKey.host) ?? "").trimmingCharacters(in: .whitespaces)
            let port = defaults.integer(forKey: DefaultsKey.port)
            let rawScheme = defaults.string(forKey: DefaultsKey.scheme) ?? ""
            let scheme = ProxyScheme(rawValue: rawScheme) ?? .http
            guard host.isEmpty == false, port > 0 else { return .system }
            return .manual(host: host, port: port, scheme: scheme)
        }
    }
}
