import Foundation

/// Top-level Settings categories presented in the sidebar.
///
/// Each case owns its title, SF Symbol, and the localized search terms used to
/// filter the sidebar. Mirrors the structure of System Settings on macOS 26 so
/// users can navigate by category rather than scroll one tall column.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case general
    case reading
    case discovery
    case sharing
    case safety
    case downloads
    case account
    case advancedQA

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.settingsGeneral
        case .reading: L10n.readingWindow
        case .discovery: L10n.settingsDiscovery
        case .sharing: L10n.sharing
        case .safety: L10n.settingsSafety
        case .downloads: L10n.downloads
        case .account: L10n.account
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
        case .downloads: "tray.and.arrow.down"
        case .account: "person.crop.circle"
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
                L10n.privacy,
                L10n.privacyMode,
                L10n.protectSensitiveContent,
                L10n.showAccountIdentity
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
                L10n.logout
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
        if VisualQALaunchArgument.contains(.runtimeReadiness) {
            return .advancedQA
        }
        if VisualQALaunchArgument.contains(.sharingTemplates) {
            return .sharing
        }
        return nil
    }
}
