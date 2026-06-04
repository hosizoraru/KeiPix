import Foundation

/// Runtime app metadata resolved from the shipping bundle.
///
/// Build scripts and Xcode targets inject the values into Info.plist. The app
/// reads the bundle at runtime so About, backups, release checks, and network
/// diagnostics all report the exact build the user launched.
struct AppVersion: Equatable, Sendable {
    static let fallbackDisplayName = "KeiPix"
    static let fallbackMarketingVersion = "0.0.0"
    static let fallbackBuildNumber = "0"

    let displayName: String
    let marketingVersion: String
    let buildNumber: String

    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        displayName = Self.nonEmptyString(infoDictionary?["CFBundleDisplayName"])
            ?? Self.nonEmptyString(infoDictionary?["CFBundleName"])
            ?? Self.fallbackDisplayName
        marketingVersion = Self.nonEmptyString(infoDictionary?["CFBundleShortVersionString"])
            ?? Self.fallbackMarketingVersion
        buildNumber = Self.nonEmptyString(infoDictionary?["CFBundleVersion"])
            ?? Self.fallbackBuildNumber
    }

    static var current: AppVersion {
        AppVersion()
    }

    var versionAndBuild: String {
        "\(marketingVersion) (\(buildNumber))"
    }

    var releaseSemanticVersion: SemanticVersion {
        SemanticVersion(marketingVersion) ?? SemanticVersion(major: 0, minor: 0, patch: 0)
    }

    var userAgentProduct: String {
        "KeiPix/\(Self.userAgentSafeVersion(marketingVersion))"
    }

    func desktopSafariUserAgent(safariVersion: String = "26.0") -> String {
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
            + "Version/\(safariVersion) Safari/605.1.15 \(userAgentProduct)"
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func userAgentSafeVersion(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        let sanitized = String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
        return sanitized.isEmpty ? fallbackMarketingVersion : sanitized
    }
}
