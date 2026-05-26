import SwiftUI

/// Bindings shared across the Settings detail pages.
///
/// Pulled out of `SettingsView` so each per-category page can pull only the
/// store bindings it actually uses, instead of all 22 bindings being declared
/// on the shell view.
extension KeiPixStore {
    var settings_languageBinding: Binding<AppLanguage> {
        Binding {
            self.appLanguage
        } set: { value in
            self.setAppLanguage(value)
        }
    }

    var settings_useOriginalImagesBinding: Binding<Bool> {
        Binding {
            self.useOriginalImagesInDetail
        } set: { value in
            self.setUseOriginalImagesInDetail(value)
        }
    }

    var settings_showTranslatedTagsBinding: Binding<Bool> {
        Binding {
            self.showTranslatedTags
        } set: { value in
            self.setShowTranslatedTags(value)
        }
    }

    var settings_galleryLayoutBinding: Binding<GalleryLayoutMode> {
        Binding {
            self.galleryLayoutMode
        } set: { value in
            self.setGalleryLayoutMode(value)
        }
    }

    var settings_defaultArtworkReadingModeBinding: Binding<ArtworkReadingMode> {
        Binding {
            self.defaultArtworkReadingMode
        } set: { value in
            self.setDefaultArtworkReadingMode(value)
        }
    }

    var settings_defaultMangaReadingModeBinding: Binding<ArtworkReadingMode> {
        Binding {
            self.defaultMangaReadingMode
        } set: { value in
            self.setDefaultMangaReadingMode(value)
        }
    }

    var settings_restoreReaderProgressBinding: Binding<Bool> {
        Binding {
            self.restoreArtworkReaderProgress
        } set: { value in
            self.setRestoreArtworkReaderProgress(value)
        }
    }

    var settings_trackpadGesturesBinding: Binding<Bool> {
        Binding {
            self.trackpadGesturesEnabled
        } set: { value in
            self.setTrackpadGesturesEnabled(value)
        }
    }

    var settings_horizontalSwipeBehaviorBinding: Binding<TrackpadHorizontalSwipeBehavior> {
        Binding {
            self.horizontalSwipeBehavior
        } set: { value in
            self.setHorizontalSwipeBehavior(value)
        }
    }

    var settings_defaultBookmarkRestrictBinding: Binding<BookmarkRestrict> {
        Binding {
            self.defaultBookmarkRestrict
        } set: { value in
            self.setDefaultBookmarkRestrict(value)
        }
    }

    var settings_defaultFollowRestrictBinding: Binding<BookmarkRestrict> {
        Binding {
            self.defaultFollowRestrict
        } set: { value in
            self.setDefaultFollowRestrict(value)
        }
    }

    var settings_followCreatorAfterBookmarkBinding: Binding<Bool> {
        Binding {
            self.followCreatorAfterBookmark
        } set: { value in
            self.setFollowCreatorAfterBookmark(value)
        }
    }

    var settings_autoTagBookmarksBinding: Binding<Bool> {
        Binding {
            self.autoTagBookmarksWithArtworkTags
        } set: { value in
            self.setAutoTagBookmarksWithArtworkTags(value)
        }
    }

    var settings_autoDownloadBookmarksBinding: Binding<Bool> {
        Binding {
            self.autoDownloadBookmarkedArtworks
        } set: { value in
            self.setAutoDownloadBookmarkedArtworks(value)
        }
    }

    var settings_autoBookmarkDownloadsBinding: Binding<Bool> {
        Binding {
            self.autoBookmarkDownloadedArtworks
        } set: { value in
            self.setAutoBookmarkDownloadedArtworks(value)
        }
    }

    var settings_showContentBadgesBinding: Binding<Bool> {
        Binding {
            self.showContentBadges
        } set: { value in
            self.setShowContentBadges(value)
        }
    }

    var settings_hideAIBinding: Binding<Bool> {
        Binding {
            self.hideAIArtworks
        } set: { value in
            self.setHideAIArtworks(value)
        }
    }

    var settings_hideMutedBinding: Binding<Bool> {
        Binding {
            self.hideMutedContent
        } set: { value in
            self.setHideMutedContent(value)
        }
    }

    var settings_hideR18Binding: Binding<Bool> {
        Binding {
            self.hideR18Artworks
        } set: { value in
            self.setHideR18Artworks(value)
        }
    }

    var settings_hideR18GBinding: Binding<Bool> {
        Binding {
            self.hideR18GArtworks
        } set: { value in
            self.setHideR18GArtworks(value)
        }
    }

    var settings_maskSensitivePreviewsBinding: Binding<Bool> {
        Binding {
            self.maskSensitivePreviews
        } set: { value in
            self.setMaskSensitivePreviews(value)
        }
    }

    var settings_privacyModeBinding: Binding<Bool> {
        Binding {
            self.privacyModeEnabled
        } set: { value in
            self.setPrivacyModeEnabled(value)
        }
    }

    var settings_screenCaptureProtectionBinding: Binding<Bool> {
        Binding {
            self.screenCaptureProtectionEnabled
        } set: { value in
            self.setScreenCaptureProtectionEnabled(value)
        }
    }

    var settings_accountIdentityBinding: Binding<Bool> {
        Binding {
            self.showAccountIdentity
        } set: { value in
            self.setShowAccountIdentity(value)
        }
    }

    var settings_downloadNamingTemplateBinding: Binding<String> {
        Binding {
            self.downloads.downloadNamingTemplate
        } set: { value in
            self.downloads.setDownloadNamingTemplate(value)
        }
    }

    var settings_maxConcurrentDownloadsBinding: Binding<Int> {
        Binding {
            self.downloads.maxConcurrentDownloads
        } set: { value in
            self.downloads.setMaxConcurrentDownloads(value)
        }
    }
}
