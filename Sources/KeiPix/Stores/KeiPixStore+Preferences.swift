import Foundation

@MainActor
extension KeiPixStore {
    func setDefaultBookmarkRestrict(_ restrict: BookmarkRestrict) {
        defaultBookmarkRestrict = restrict
        UserDefaults.standard.set(restrict.rawValue, forKey: "defaultBookmarkRestrict")
    }

    func setDefaultFollowRestrict(_ restrict: BookmarkRestrict) {
        defaultFollowRestrict = restrict
        UserDefaults.standard.set(restrict.rawValue, forKey: "defaultFollowRestrict")
    }

    func setFollowCreatorAfterBookmark(_ value: Bool) {
        followCreatorAfterBookmark = value
        UserDefaults.standard.set(value, forKey: "followCreatorAfterBookmark")
    }

    func setAutoDownloadBookmarkedArtworks(_ value: Bool) {
        autoDownloadBookmarkedArtworks = value
        UserDefaults.standard.set(value, forKey: "autoDownloadBookmarkedArtworks")
    }

    func setAutoTagBookmarksWithArtworkTags(_ value: Bool) {
        autoTagBookmarksWithArtworkTags = value
        UserDefaults.standard.set(value, forKey: "autoTagBookmarksWithArtworkTags")
    }

    func setUseOriginalImagesInDetail(_ value: Bool) {
        useOriginalImagesInDetail = value
        UserDefaults.standard.set(value, forKey: "useOriginalImagesInDetail")
    }

    func setShowTranslatedTags(_ value: Bool) {
        showTranslatedTags = value
        UserDefaults.standard.set(value, forKey: "showTranslatedTags")
    }

    func setShowContentBadges(_ value: Bool) {
        showContentBadges = value
        UserDefaults.standard.set(value, forKey: "showContentBadges")
    }

    func setShowAccountIdentity(_ value: Bool) {
        showAccountIdentity = value
        UserDefaults.standard.set(value, forKey: "showAccountIdentity")
    }

    func setPrivacyModeEnabled(_ value: Bool) {
        privacyModeEnabled = value
        UserDefaults.standard.set(value, forKey: "privacyModeEnabled")
    }

    func setScreenCaptureProtectionEnabled(_ value: Bool) {
        screenCaptureProtectionEnabled = value
        UserDefaults.standard.set(value, forKey: "screenCaptureProtectionEnabled")
    }

    func setHideMutedContent(_ value: Bool) {
        hideMutedContent = value
        UserDefaults.standard.set(value, forKey: "hideMutedContent")
        applyContentFilters()
    }

    func setHideAIArtworks(_ value: Bool) {
        hideAIArtworks = value
        UserDefaults.standard.set(value, forKey: "hideAIArtworks")
        applyContentFilters()
    }

    func setHideR18Artworks(_ value: Bool) {
        hideR18Artworks = value
        UserDefaults.standard.set(value, forKey: "hideR18Artworks")
        applyContentFilters()
    }

    func setHideR18GArtworks(_ value: Bool) {
        hideR18GArtworks = value
        UserDefaults.standard.set(value, forKey: "hideR18GArtworks")
        applyContentFilters()
    }

    func setMaskSensitivePreviews(_ value: Bool) {
        maskSensitivePreviews = value
        UserDefaults.standard.set(value, forKey: "maskSensitivePreviews")
    }

    func setSearchMatchType(_ value: SearchMatchType) {
        searchMatchType = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchMatchType")
    }

    func setSearchSort(_ value: SearchSort) {
        searchSort = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchSort")
    }

    func setSearchAgeLimit(_ value: SearchAgeLimit) {
        searchAgeLimit = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchAgeLimit")
    }

    func setSearchDateRange(_ value: SearchDateRange) {
        searchDateRange = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchDateRange")
    }

    func setSearchMinimumBookmarks(_ value: SearchMinimumBookmarks) {
        searchMinimumBookmarks = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchMinimumBookmarks")
        applyContentFilters()
    }

    func setSearchMaximumBookmarks(_ value: SearchMaximumBookmarks) {
        searchMaximumBookmarks = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchMaximumBookmarks")
        applyContentFilters()
    }

    func setSearchArtworkType(_ value: SearchArtworkType) {
        searchArtworkType = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchArtworkType")
        applyContentFilters()
    }

    func setSearchAIFilter(_ value: SearchAIFilter) {
        searchAIFilter = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchAIFilter")
        applyContentFilters()
    }

    func setSearchUgoiraFilter(_ value: SearchUgoiraFilter) {
        searchUgoiraFilter = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchUgoiraFilter")
        applyContentFilters()
    }

    func setUseRankingDate(_ value: Bool) {
        useRankingDate = value
        UserDefaults.standard.set(value, forKey: "useRankingDate")
    }

    func setRankingDate(_ value: Date) {
        rankingDate = Self.clampedRankingDate(value)
        UserDefaults.standard.set(rankingDate, forKey: "rankingDate")
    }

    func setAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
    }

    func setCompactArtworkCards(_ value: Bool) {
        setGalleryLayoutMode(value ? .compactGrid : .autoMasonry)
    }

    func setGalleryLayoutMode(_ mode: GalleryLayoutMode) {
        galleryLayoutMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "galleryLayoutMode")
        UserDefaults.standard.set(mode.usesCompactGrid, forKey: "compactArtworkCards")
    }

    func setTrackpadGesturesEnabled(_ value: Bool) {
        trackpadGesturesEnabled = value
        UserDefaults.standard.set(value, forKey: "trackpadGesturesEnabled")
    }

    func setHorizontalSwipeBehavior(_ behavior: TrackpadHorizontalSwipeBehavior) {
        horizontalSwipeBehavior = behavior
        UserDefaults.standard.set(behavior.rawValue, forKey: "horizontalSwipeBehavior")
    }

    func defaultReadingMode(for artwork: PixivArtwork, pageCount: Int? = nil) -> ArtworkReadingMode {
        switch ArtworkReadingModePreferenceKind.kind(for: artwork, pageCount: pageCount ?? artwork.displayPageCount) {
        case .artwork:
            defaultArtworkReadingMode
        case .manga:
            defaultMangaReadingMode
        }
    }

    func setDefaultReadingMode(_ mode: ArtworkReadingMode, for artwork: PixivArtwork, pageCount: Int? = nil) {
        let kind = ArtworkReadingModePreferenceKind.kind(for: artwork, pageCount: pageCount ?? artwork.displayPageCount)
        switch kind {
        case .artwork:
            defaultArtworkReadingMode = mode
        case .manga:
            defaultMangaReadingMode = mode
        }
        UserDefaults.standard.set(mode.rawValue, forKey: kind.storageKey)
    }

    func setDefaultArtworkReadingMode(_ mode: ArtworkReadingMode) {
        defaultArtworkReadingMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: ArtworkReadingModePreferenceKind.artwork.storageKey)
    }

    func setDefaultMangaReadingMode(_ mode: ArtworkReadingMode) {
        defaultMangaReadingMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: ArtworkReadingModePreferenceKind.manga.storageKey)
    }
}
