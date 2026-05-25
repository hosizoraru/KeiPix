extension SettingsView {
    var generalSettingsTerms: [String] {
        [
            L10n.settingsGeneral,
            L10n.language,
            L10n.appearance,
            L10n.useOriginalImages,
            L10n.showTranslatedTags,
            L10n.layout,
            L10n.galleryLayout
        ]
    }

    var readingSettingsTerms: [String] {
        [
            L10n.readingWindow,
            L10n.defaultArtworkReadingMode,
            L10n.defaultMangaReadingMode,
            L10n.restoreLastReadPage,
            L10n.trackpad,
            L10n.enableTrackpadGestures,
            L10n.twoFingerSwipeBehavior
        ]
    }

    var discoverySettingsTerms: [String] {
        [
            L10n.settingsDiscovery,
            L10n.bookmarks,
            L10n.defaultBookmarkVisibility,
            L10n.autoTagBookmarksWithArtworkTags,
            L10n.followCreatorAfterBookmark,
            L10n.autoDownloadBookmarkedArtworks,
            L10n.followingCreators,
            L10n.pinnedCreators,
            L10n.defaultFollowVisibility
        ]
    }

    var safetySettingsTerms: [String] {
        [
            L10n.settingsSafety,
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
    }

    var copyTemplateSettingsTerms: [String] {
        [
            L10n.sharing,
            L10n.artworkCopyTemplate,
            L10n.creatorCopyTemplate,
            L10n.copyTemplateHint,
            L10n.templatePreview
        ]
    }

    var downloadsSettingsTerms: [String] {
        [
            L10n.downloads,
            L10n.downloadFolder,
            L10n.concurrentDownloads,
            L10n.autoBookmarkDownloadedArtworks,
            L10n.downloadNamingTemplate,
            L10n.templatePreview
        ]
    }

    var accountSettingsTerms: [String] {
        [
            L10n.account,
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
    }

    var advancedQASettingsTerms: [String] {
        [
            L10n.settingsAdvancedQA,
            L10n.runtimeReadiness,
            L10n.qaSettingsOrganization,
            L10n.runSearchDiagnostics,
            L10n.qaAccountHealth
        ]
    }
}
