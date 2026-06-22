import Foundation

enum LaunchCacheRecovery {
    static let clearCachesOnNextLaunchKey = "clearCachesOnNextLaunch"
    static let lastRecoveryDateKey = "lastLaunchCacheRecoveryAt"

    static let regenerableUserDefaultsKeys = [
        "feedSnapshotLibrary",
        "localBrowsingHistory",
        "searchHistory",
        "artworkDetailStateLibrary"
    ]

    struct Dependencies: Sendable {
        var clearImageCaches: @Sendable () -> Void
        var clearURLCache: @Sendable () -> Void
        var clearNovelTextCache: @Sendable () -> Void
        var now: @Sendable () -> Date

        static let live = Dependencies(
            clearImageCaches: {
                _ = ImagePipeline.shared.clearCaches()
            },
            clearURLCache: {
                URLCache.shared.removeAllCachedResponses()
            },
            clearNovelTextCache: {
                NovelTextDiskCache.clearAllSynchronously()
            },
            now: Date.init
        )
    }

    @discardableResult
    static func performIfRequested(
        defaults: UserDefaults = .standard,
        dependencies: Dependencies = .live
    ) -> Bool {
        guard defaults.bool(forKey: clearCachesOnNextLaunchKey) else { return false }

        for key in regenerableUserDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
        dependencies.clearImageCaches()
        dependencies.clearURLCache()
        dependencies.clearNovelTextCache()
        defaults.set(false, forKey: clearCachesOnNextLaunchKey)
        defaults.set(dependencies.now(), forKey: lastRecoveryDateKey)
        defaults.synchronize()
        return true
    }
}
