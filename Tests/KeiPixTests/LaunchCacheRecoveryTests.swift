import Foundation
import Testing
@testable import KeiPix

@Suite("Launch cache recovery")
struct LaunchCacheRecoveryTests {
    @Test("Recovery clears only regenerable defaults and turns itself off")
    func recoveryClearsOnlyRegenerableDefaultsAndTurnsItselfOff() {
        let defaults = isolatedDefaults()
        defer { defaults.cleanup() }
        let recoveryDate = Date(timeIntervalSince1970: 1_800_000_000)
        let spy = RecoverySpy()

        defaults.instance.set(true, forKey: LaunchCacheRecovery.clearCachesOnNextLaunchKey)
        for key in LaunchCacheRecovery.regenerableUserDefaultsKeys {
            defaults.instance.set("stale-\(key)", forKey: key)
        }
        let preservedKeys = [
            "savedSearches",
            "mutedContentLibrary",
            "workSubscriptions",
            "downloadQueueItems",
            "refreshToken",
            "bookmarkPrivacyDefault"
        ]
        for key in preservedKeys {
            defaults.instance.set("keep-\(key)", forKey: key)
        }

        let didRecover = LaunchCacheRecovery.performIfRequested(
            defaults: defaults.instance,
            dependencies: .init(
                clearImageCaches: spy.clearImageCaches,
                clearURLCache: spy.clearURLCache,
                clearNovelTextCache: spy.clearNovelTextCache,
                now: { recoveryDate }
            )
        )

        #expect(didRecover)
        #expect(defaults.instance.bool(forKey: LaunchCacheRecovery.clearCachesOnNextLaunchKey) == false)
        #expect(defaults.instance.object(forKey: LaunchCacheRecovery.lastRecoveryDateKey) as? Date == recoveryDate)
        #expect(spy.clearedImageCaches == 1)
        #expect(spy.clearedURLCache == 1)
        #expect(spy.clearedNovelTextCache == 1)
        for key in LaunchCacheRecovery.regenerableUserDefaultsKeys {
            #expect(defaults.instance.object(forKey: key) == nil)
        }
        for key in preservedKeys {
            #expect(defaults.instance.string(forKey: key) == "keep-\(key)")
        }
    }

    @Test("Recovery is a no-op when the external setting is off")
    func recoveryDoesNothingWhenSettingIsOff() {
        let defaults = isolatedDefaults()
        defer { defaults.cleanup() }
        let spy = RecoverySpy()

        defaults.instance.set("cached", forKey: LaunchCacheRecovery.regenerableUserDefaultsKeys[0])

        let didRecover = LaunchCacheRecovery.performIfRequested(
            defaults: defaults.instance,
            dependencies: .init(
                clearImageCaches: spy.clearImageCaches,
                clearURLCache: spy.clearURLCache,
                clearNovelTextCache: spy.clearNovelTextCache,
                now: { Date(timeIntervalSince1970: 0) }
            )
        )

        #expect(didRecover == false)
        #expect(spy.totalClears == 0)
        #expect(defaults.instance.string(forKey: LaunchCacheRecovery.regenerableUserDefaultsKeys[0]) == "cached")
        #expect(defaults.instance.object(forKey: LaunchCacheRecovery.lastRecoveryDateKey) == nil)
    }

    @Test("Settings bundle exposes the same one-shot recovery key")
    func settingsBundleUsesLaunchRecoveryKey() throws {
        let rootPlist = repositoryRoot()
            .appending(path: "Sources/KeiPix/Settings.bundle/Root.plist")
        let data = try Data(contentsOf: rootPlist)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        let specifiers = try #require(plist["PreferenceSpecifiers"] as? [[String: Any]])
        let recoveryToggle = try #require(specifiers.first { specifier in
            specifier["Type"] as? String == "PSToggleSwitchSpecifier"
        })

        #expect(recoveryToggle["Key"] as? String == LaunchCacheRecovery.clearCachesOnNextLaunchKey)
        #expect(recoveryToggle["DefaultValue"] as? Bool == false)
    }

    private func isolatedDefaults() -> (instance: UserDefaults, cleanup: () -> Void) {
        let suiteName = "LaunchCacheRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (
            defaults,
            {
                defaults.removePersistentDomain(forName: suiteName)
            }
        )
    }

    private func repositoryRoot() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private final class RecoverySpy: @unchecked Sendable {
        var clearedImageCaches = 0
        var clearedURLCache = 0
        var clearedNovelTextCache = 0

        var totalClears: Int {
            clearedImageCaches + clearedURLCache + clearedNovelTextCache
        }

        func clearImageCaches() {
            clearedImageCaches += 1
        }

        func clearURLCache() {
            clearedURLCache += 1
        }

        func clearNovelTextCache() {
            clearedNovelTextCache += 1
        }
    }
}
