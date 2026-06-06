import Foundation

/// Top-level Settings categories presented in the sidebar.
///
/// Each case owns its title, SF Symbol, and the localized search terms used to
/// filter the sidebar. Mirrors the structure of System Settings on macOS 26 so
/// users can navigate by category rather than scroll one tall column.
///
/// Ordering follows Apple's grouping conventions: identity-adjacent
/// destinations (Account) sit near the top, then content/behavior categories
/// (General, Reading, Discovery), then safety/privacy boundaries (Safety,
/// Privacy), then on-disk concerns (Downloads, Sharing), with specialized
/// tooling (Advanced QA) at the bottom — matching how System Settings layers
/// "Apple ID" → user-facing controls → privacy → power-user surfaces.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case account
    case general
    case reading
    case discovery
    case safety
    case privacy
    case downloads
    case sharing
    case storage
    case keyboard
    case about
    case advancedQA

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.settingsGeneral
        case .reading: L10n.readingWindow
        case .discovery: L10n.settingsDiscovery
        case .sharing: L10n.sharing
        case .safety: L10n.settingsSafety
        case .privacy: L10n.settingsPrivacy
        case .downloads: L10n.downloads
        case .storage: L10n.settingsStorage
        case .account: L10n.account
        case .keyboard: L10n.settingsKeyboard
        case .about: L10n.aboutKeiPix
        case .advancedQA: L10n.settingsAdvancedQA
        }
    }

    var systemImage: String {
        switch self {
        case .general: "switch.2"
        case .reading: "book"
        case .discovery: "sparkles.rectangle.stack"
        case .sharing: "square.and.arrow.up"
        case .safety: "lock.shield"
        case .privacy: "hand.raised"
        case .downloads: "tray.and.arrow.down"
        case .storage: "internaldrive"
        case .account: "person.crop.circle"
        case .keyboard: "keyboard"
        case .about: "info.circle"
        case .advancedQA: "wrench.and.screwdriver"
        }
    }

    /// Localized terms searched by the sidebar filter.
    var searchTerms: [String] {
        switch self {
        case .general:
            return [
                title,
                L10n.language,
                L10n.appearance,
                L10n.useOriginalImages,
                L10n.showTranslatedTags,
                L10n.layout,
                L10n.galleryLayout
            ]
        case .reading:
            return [
                title,
                L10n.defaultArtworkReadingMode,
                L10n.defaultMangaReadingMode,
                L10n.restoreLastReadPage,
                L10n.trackpad,
                L10n.enableTrackpadGestures,
                L10n.twoFingerSwipeBehavior
            ]
        case .discovery:
            return [
                title,
                L10n.bookmarks,
                L10n.defaultBookmarkVisibility,
                L10n.autoTagBookmarksWithArtworkTags,
                L10n.followCreatorAfterBookmark,
                L10n.autoDownloadBookmarkedArtworks,
                L10n.followingCreators,
                L10n.pinnedCreators,
                L10n.defaultFollowVisibility
            ]
        case .sharing:
            return [
                title,
                L10n.artworkCopyTemplate,
                L10n.creatorCopyTemplate,
                L10n.copyTemplateHint,
                L10n.templatePreview
            ]
        case .safety:
            return [
                title,
                L10n.contentFilters,
                L10n.showContentBadges,
                L10n.hideMutedContent,
                L10n.hideAIArtworks,
                L10n.hideR18Artworks,
                L10n.hideR18GArtworks,
                L10n.maskSensitivePreviews,
                L10n.pixivRestrictedMode,
                L10n.mutedContent,
                L10n.syncFromPixiv,
                L10n.uploadToPixiv,
                // Cross-listed so users searching for privacy still find the
                // related controls — same as Apple's System Settings linking
                // Privacy & Security to specific app permissions.
                L10n.privacy,
                L10n.privacyMode,
                L10n.protectSensitiveContent,
                L10n.showAccountIdentity
            ]
        case .privacy:
            return [
                title,
                L10n.privacyMode,
                L10n.protectSensitiveContent,
                L10n.showAccountIdentity,
                L10n.privacyHint,
                L10n.privacyAndIdentity,
                L10n.pixivRestrictedMode,
                L10n.account,
                L10n.maskSensitivePreviews
            ]
        case .downloads:
            return [
                title,
                L10n.downloadFolder,
                L10n.concurrentDownloads,
                L10n.autoBookmarkDownloadedArtworks,
                L10n.downloadNamingTemplate,
                L10n.templatePreview
            ]
        case .storage:
            return [
                title,
                L10n.storageOverview,
                L10n.totalCacheSize,
                L10n.clearAllCaches,
                L10n.cacheImageTitle,
                L10n.cacheFeedSnapshotsTitle,
                L10n.cacheBrowsingHistoryTitle,
                L10n.cacheSearchHistoryTitle,
                L10n.cacheArtworkDetailStateTitle,
                L10n.backupAndRestore,
                L10n.exportBackup,
                L10n.importBackup
            ]
        case .account:
            return [
                title,
                L10n.accountMode,
                L10n.guestAccount,
                L10n.testModeAccount,
                L10n.profile,
                L10n.addAccount,
                L10n.importToken,
                L10n.switchAccount,
                L10n.removeAccount,
                L10n.logout,
                // Account-adjacent privacy controls live on the Account page
                // too, so people searching for "privacy" or "identity" while
                // browsing accounts still find them.
                L10n.privacyAndIdentity,
                L10n.privacyMode,
                L10n.showAccountIdentity
            ]
        case .keyboard:
            return [
                title,
                L10n.keyboardCustomization,
                L10n.openKeyboardSystemSettings,
                L10n.artwork,
                L10n.downloads,
                L10n.readerWindow,
                L10n.shortcutSurfaceMain,
                L10n.shortcutSurfaceReaderInline
            ]
        case .about:
            return [
                title,
                L10n.aboutLicense,
                L10n.aboutApacheLicenseTitle,
                L10n.aboutSourceRepository,
                L10n.aboutOpenOnGitHub,
                L10n.aboutCopyDiagnostics,
                L10n.aboutAcknowledgments,
                L10n.aboutLocalization
            ]
        case .advancedQA:
            return [
                title,
                L10n.runtimeReadiness,
                L10n.qaSettingsOrganization,
                L10n.runSearchDiagnostics,
                L10n.qaAccountHealth
            ]
        }
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return true }
        return searchTerms.contains { term in
            term.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Visual-QA launch arguments override the persisted selection so the
    /// snapshot lands on the right page. Computed synchronously at coordinator
    /// init time so the first frame already shows the requested destination.
    static var visualQAOverride: SettingsCategory? {
        if VisualQALaunchArgument.contains(.about) {
            return .about
        }
        if VisualQALaunchArgument.contains(.runtimeReadiness) {
            return .advancedQA
        }
        if VisualQALaunchArgument.contains(.sharingTemplates) {
            return .sharing
        }
        return nil
    }
}
