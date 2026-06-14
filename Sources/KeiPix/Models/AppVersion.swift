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
    let buildNumberSource: String?
    let buildAnchorTag: String?
    let buildCommitCount: Int?
    let buildBaseNumber: String?
    let buildDisplayNumber: String?
    let injectedBuildIdentity: String?
    let gitCommit: String?
    let gitShortCommit: String?
    let gitDirty: Bool
    let gitDescribe: String?

    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        displayName = Self.nonEmptyString(infoDictionary?["CFBundleDisplayName"])
            ?? Self.nonEmptyString(infoDictionary?["CFBundleName"])
            ?? Self.fallbackDisplayName
        marketingVersion = Self.nonEmptyString(infoDictionary?["CFBundleShortVersionString"])
            ?? Self.fallbackMarketingVersion
        buildNumber = Self.nonEmptyString(infoDictionary?["CFBundleVersion"])
            ?? Self.fallbackBuildNumber
        buildNumberSource = Self.nonEmptyString(infoDictionary?["KeiPixBuildNumberSource"])
        buildAnchorTag = Self.nonEmptyString(infoDictionary?["KeiPixBuildAnchorTag"])
        buildCommitCount = Self.integer(infoDictionary?["KeiPixBuildCommitCount"])
        buildBaseNumber = Self.nonEmptyString(infoDictionary?["KeiPixBuildBaseNumber"])
        buildDisplayNumber = Self.nonEmptyString(infoDictionary?["KeiPixBuildDisplayNumber"])
        injectedBuildIdentity = Self.nonEmptyString(infoDictionary?["KeiPixBuildIdentity"])
        gitCommit = Self.nonEmptyString(infoDictionary?["KeiPixGitCommit"])
        gitShortCommit = Self.nonEmptyString(infoDictionary?["KeiPixGitShortCommit"])
        gitDirty = Self.boolean(infoDictionary?["KeiPixGitDirty"])
        gitDescribe = Self.nonEmptyString(infoDictionary?["KeiPixGitDescribe"])
    }

    static var current: AppVersion {
        AppVersion()
    }

    var versionAndBuild: String {
        "\(marketingVersion) (\(buildNumber))"
    }

    var versionName: String {
        marketingVersion
    }

    var buildVersion: String {
        buildNumber
    }

    var buildIdentity: String {
        if let injectedBuildIdentity {
            return injectedBuildIdentity
        }

        let identity: String
        if let buildAnchorTag {
            if let buildCommitCount, buildCommitCount > 0 {
                identity = "\(buildAnchorTag)+\(buildCommitCount)"
            } else {
                identity = buildAnchorTag
            }
        } else if let gitDescribe {
            identity = gitDescribe
        } else {
            identity = buildNumber
        }

        return identity
    }

    var hasBuildProvenance: Bool {
        injectedBuildIdentity != nil || buildAnchorTag != nil || gitDescribe != nil || gitDirty
    }

    var versionCode: Int {
        Self.versionCode(fromBuildNumber: buildNumber)
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

    private static func integer(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        guard let string = nonEmptyString(value) else { return nil }
        return Int(string)
    }

    private static func boolean(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        guard let string = nonEmptyString(value)?.lowercased() else { return false }
        return ["1", "true", "yes", "y"].contains(string)
    }

    private static func userAgentSafeVersion(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        let sanitized = String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
        return sanitized.isEmpty ? fallbackMarketingVersion : sanitized
    }

    private static func versionCode(fromBuildNumber value: String) -> Int {
        Int(value) ?? 0
    }
}
