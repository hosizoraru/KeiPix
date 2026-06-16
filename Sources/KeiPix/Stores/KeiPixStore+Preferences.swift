import Foundation

@MainActor
extension KeiPixStore {
    // MARK: - Generic persistence helper

    /// Persists a value to UserDefaults and updates the store property.
    /// Reduces the repetitive `property = value; UserDefaults.set(value, forKey:)` pattern.
    private func persist<T>(_ key: String, value: T, to property: ReferenceWritableKeyPath<KeiPixStore, T>) {
        self[keyPath: property] = value
        UserDefaults.standard.set(value, forKey: key)
    }

    /// Persists a `RawRepresentable` value (enum with String/Int raw value).
    private func persistRaw<T: RawRepresentable>(_ key: String, value: T, to property: ReferenceWritableKeyPath<KeiPixStore, T>) {
        self[keyPath: property] = value
        UserDefaults.standard.set(value.rawValue, forKey: key)
    }

    // MARK: - Bookmark & follow

    func setDefaultBookmarkRestrict(_ restrict: BookmarkRestrict) {
        persistRaw("defaultBookmarkRestrict", value: restrict, to: \.defaultBookmarkRestrict)
        persistRaw("defaultIllustrationBookmarkRestrict", value: restrict, to: \.defaultIllustrationBookmarkRestrict)
        persistRaw("defaultMangaBookmarkRestrict", value: restrict, to: \.defaultMangaBookmarkRestrict)
        persistRaw("defaultNovelBookmarkRestrict", value: restrict, to: \.defaultNovelBookmarkRestrict)
    }

    func setDefaultIllustrationBookmarkRestrict(_ restrict: BookmarkRestrict) {
        persistRaw("defaultIllustrationBookmarkRestrict", value: restrict, to: \.defaultIllustrationBookmarkRestrict)
        persistRaw("defaultBookmarkRestrict", value: restrict, to: \.defaultBookmarkRestrict)
    }

    func setDefaultMangaBookmarkRestrict(_ restrict: BookmarkRestrict) {
        persistRaw("defaultMangaBookmarkRestrict", value: restrict, to: \.defaultMangaBookmarkRestrict)
    }

    func setDefaultNovelBookmarkRestrict(_ restrict: BookmarkRestrict) {
        persistRaw("defaultNovelBookmarkRestrict", value: restrict, to: \.defaultNovelBookmarkRestrict)
    }

    func setDefaultFollowRestrict(_ restrict: BookmarkRestrict) {
        persistRaw("defaultFollowRestrict", value: restrict, to: \.defaultFollowRestrict)
    }

    func setFollowCreatorAfterBookmark(_ value: Bool) {
        persist("followCreatorAfterBookmark", value: value, to: \.followCreatorAfterBookmark)
    }

    func setAutoDownloadBookmarkedArtworks(_ value: Bool) {
        persist("autoDownloadBookmarkedArtworks", value: value, to: \.autoDownloadBookmarkedArtworks)
    }

    func setAutoBookmarkDownloadedArtworks(_ value: Bool) {
        persist("autoBookmarkDownloadedArtworks", value: value, to: \.autoBookmarkDownloadedArtworks)
    }

    func setAutoTagBookmarksWithArtworkTags(_ value: Bool) {
        persist("autoTagBookmarksWithArtworkTags", value: value, to: \.autoTagBookmarksWithArtworkTags)
    }

    func setArtworkCopyTemplate(_ template: String) {
        persist("artworkCopyTemplate", value: template, to: \.artworkCopyTemplate)
    }

    func resetArtworkCopyTemplate() -> Bool {
        guard artworkCopyTemplate != ArtworkCopyTemplate.defaultTemplate else { return false }
        setArtworkCopyTemplate(ArtworkCopyTemplate.defaultTemplate)
        return true
    }

    func setCreatorCopyTemplate(_ template: String) {
        persist("creatorCopyTemplate", value: template, to: \.creatorCopyTemplate)
    }

    func resetCreatorCopyTemplate() -> Bool {
        guard creatorCopyTemplate != CreatorCopyTemplate.defaultTemplate else { return false }
        setCreatorCopyTemplate(CreatorCopyTemplate.defaultTemplate)
        return true
    }

    func setRestoreArtworkReaderProgress(_ value: Bool) {
        persist("restoreArtworkReaderProgress", value: value, to: \.restoreArtworkReaderProgress)
    }

    func setUseOriginalImagesInDetail(_ value: Bool) {
        useOriginalImagesInDetail = value
        UserDefaults.standard.set(value, forKey: "useOriginalImagesInDetail")
        // Keep the legacy Bool and the new tier in lock-step so the
        // reader's HD/Standard chip and the settings tier picker can't
        // disagree. Flipping HD off only downgrades to `.large` (not
        // `.medium`) so users who never visit settings keep the old
        // resolver behaviour.
        setIllustDetailImageQualityTier(.legacy(preferOriginal: value))
    }

    func setUseOriginalImagesForManga(_ value: Bool) {
        useOriginalImagesForManga = value
        UserDefaults.standard.set(value, forKey: "useOriginalImagesForManga")
        setMangaDetailImageQualityTier(.legacy(preferOriginal: value))
    }

    /// Tier setter for illust detail. Keeps the legacy `useOriginalImagesInDetail`
    /// Bool aligned so existing readers / downloads / sharing call sites
    /// that still consult the Bool stay consistent with the picker.
    func setIllustDetailImageQualityTier(_ tier: ArtworkImageQualityTier) {
        guard illustDetailImageQualityTier != tier else { return }
        illustDetailImageQualityTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: "illustDetailImageQualityTier")
        let legacyValue = tier.prefersOriginal
        if useOriginalImagesInDetail != legacyValue {
            useOriginalImagesInDetail = legacyValue
            UserDefaults.standard.set(legacyValue, forKey: "useOriginalImagesInDetail")
        }
    }

    func setMangaDetailImageQualityTier(_ tier: ArtworkImageQualityTier) {
        guard mangaDetailImageQualityTier != tier else { return }
        mangaDetailImageQualityTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: "mangaDetailImageQualityTier")
        let legacyValue = tier.prefersOriginal
        if useOriginalImagesForManga != legacyValue {
            useOriginalImagesForManga = legacyValue
            UserDefaults.standard.set(legacyValue, forKey: "useOriginalImagesForManga")
        }
    }

    func setFeedPreviewImageQualityTier(_ tier: ArtworkImageQualityTier) {
        guard feedPreviewImageQualityTier != tier else { return }
        feedPreviewImageQualityTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: "feedPreviewImageQualityTier")
    }

    /// Effective value for unified quality controls. Older installs can have
    /// per-surface tiers that diverged; show `.large` until the user chooses a
    /// single tier and `setArtworkImageQualityTier(_:)` writes them back in sync.
    var sharedArtworkImageQualityTier: ArtworkImageQualityTier {
        guard feedPreviewImageQualityTier == illustDetailImageQualityTier,
              feedPreviewImageQualityTier == mangaDetailImageQualityTier else {
            return .large
        }
        return feedPreviewImageQualityTier
    }

    func setArtworkImageQualityTier(_ tier: ArtworkImageQualityTier) {
        setFeedPreviewImageQualityTier(tier)
        setIllustDetailImageQualityTier(tier)
        setMangaDetailImageQualityTier(tier)
    }

    /// Tier resolver mirroring `preferOriginalImages(for:)` so call
    /// sites can pick illust vs manga without re-implementing the
    /// content-kind switch. The reader, downloads, and ugoira surfaces
    /// all funnel through this helper.
    func imageQualityTier(for artwork: PixivArtwork, pageCount: Int? = nil) -> ArtworkImageQualityTier {
        let resolvedCount = pageCount ?? artwork.displayPageCount
        switch ArtworkReadingModePreferenceKind.kind(for: artwork, pageCount: resolvedCount) {
        case .artwork: return illustDetailImageQualityTier
        case .manga: return mangaDetailImageQualityTier
        }
    }

    func setImageQualityTier(
        _ tier: ArtworkImageQualityTier,
        for artwork: PixivArtwork,
        pageCount: Int? = nil
    ) {
        let resolvedCount = pageCount ?? artwork.displayPageCount
        switch ArtworkReadingModePreferenceKind.kind(for: artwork, pageCount: resolvedCount) {
        case .artwork: setIllustDetailImageQualityTier(tier)
        case .manga: setMangaDetailImageQualityTier(tier)
        }
    }

    /// Returns the preferred-original flag for an artwork based on the
    /// per-content quality presets. Mirrors `ArtworkReadingModePreferenceKind`
    /// so the picture/manga split lines up with how reading modes are split.
    func preferOriginalImages(for artwork: PixivArtwork, pageCount: Int? = nil) -> Bool {
        let resolvedCount = pageCount ?? artwork.displayPageCount
        switch ArtworkReadingModePreferenceKind.kind(for: artwork, pageCount: resolvedCount) {
        case .artwork: return useOriginalImagesInDetail
        case .manga: return useOriginalImagesForManga
        }
    }

    /// Counterpart to `preferOriginalImages(for:)` that flips the preset
    /// matching the artwork's kind. Powers the in-viewer HD/Standard toggle
    /// so the user's per-artwork choice persists into the right preset
    /// instead of leaking across illust/manga categories.
    func setPreferOriginalImages(_ value: Bool, for artwork: PixivArtwork, pageCount: Int? = nil) {
        let resolvedCount = pageCount ?? artwork.displayPageCount
        switch ArtworkReadingModePreferenceKind.kind(for: artwork, pageCount: resolvedCount) {
        case .artwork: setUseOriginalImagesInDetail(value)
        case .manga: setUseOriginalImagesForManga(value)
        }
    }

    func setShowTranslatedTags(_ value: Bool) {
        persist("showTranslatedTags", value: value, to: \.showTranslatedTags)
    }

    func setShowContentBadges(_ value: Bool) {
        persist("showContentBadges", value: value, to: \.showContentBadges)
    }

    func setShowAccountIdentity(_ value: Bool) {
        persist("showAccountIdentity", value: value, to: \.showAccountIdentity)
    }

    func setEmphasizeFollowingArtists(_ value: Bool) {
        persist("emphasizeFollowingArtists", value: value, to: \.emphasizeFollowingArtists)
    }

    func setPrivacyModeEnabled(_ value: Bool) {
        persist("privacyModeEnabled", value: value, to: \.privacyModeEnabled)
    }

    func setScreenCaptureProtectionEnabled(_ value: Bool) {
        screenCaptureProtectionEnabled = value
        UserDefaults.standard.set(value, forKey: "screenCaptureProtectionEnabled")
    }

    func setHideMutedContent(_ value: Bool) {
        let changed = hideMutedContent != value
        hideMutedContent = value
        UserDefaults.standard.set(value, forKey: "hideMutedContent")
        applyContentFilters()
        novels.applyContentFilter()
        if changed {
            markContentVisibilityFiltersChanged()
        }
    }

    func setHideAIArtworks(_ value: Bool) {
        let changed = hideAIArtworks != value
        hideAIArtworks = value
        UserDefaults.standard.set(value, forKey: "hideAIArtworks")
        applyContentFilters()
        novels.applyContentFilter()
        refreshSpotlightIndexAfterFilterChange()
        if changed {
            markContentVisibilityFiltersChanged()
        }
    }

    func setHideR18Artworks(_ value: Bool) {
        let changed = hideR18Artworks != value
        hideR18Artworks = value
        UserDefaults.standard.set(value, forKey: "hideR18Artworks")
        applyContentFilters()
        novels.applyContentFilter()
        refreshSpotlightIndexAfterFilterChange()
        if changed {
            markContentVisibilityFiltersChanged()
        }
    }

    func setHideR18GArtworks(_ value: Bool) {
        let changed = hideR18GArtworks != value
        hideR18GArtworks = value
        UserDefaults.standard.set(value, forKey: "hideR18GArtworks")
        applyContentFilters()
        novels.applyContentFilter()
        refreshSpotlightIndexAfterFilterChange()
        if changed {
            markContentVisibilityFiltersChanged()
        }
    }

    private func markContentVisibilityFiltersChanged() {
        contentFilterGeneration &+= 1
        creatorPreviewArtworkCacheGeneration &+= 1
    }

    /// Wipe the KeiPix Spotlight domain and rebuild from the current
    /// download list when a hide-toggle flips. The wipe-and-rebuild
    /// shape is the safe option — flipping a toggle off (e.g. show
    /// AI again) needs the previously-hidden items to come back, and
    /// re-indexing every completed download is cheap when the cap is
    /// in the low thousands.
    private func refreshSpotlightIndexAfterFilterChange() {
        guard spotlightIndexingEnabled else { return }
        clearSpotlightIndex()
        rebuildSpotlightIndex()
    }

    func setMaskSensitivePreviews(_ value: Bool) {
        persist("maskSensitivePreviews", value: value, to: \.maskSensitivePreviews)
    }

    func setSearchMatchType(_ value: SearchMatchType) {
        persistRaw("searchMatchType", value: value, to: \.searchMatchType)
        rememberCurrentSearchOptionsProfile()
    }

    func setSearchSort(_ value: SearchSort) {
        persistRaw("searchSort", value: value, to: \.searchSort)
        rememberCurrentSearchOptionsProfile()
    }

    func setSearchAgeLimit(_ value: SearchAgeLimit) {
        persistRaw("searchAgeLimit", value: value, to: \.searchAgeLimit)
        rememberCurrentSearchOptionsProfile()
    }

    func setSearchDateRange(_ value: SearchDateRange) {
        persistRaw("searchDateRange", value: value, to: \.searchDateRange)
        rememberCurrentSearchOptionsProfile()
    }

    func setSearchMinimumBookmarks(_ value: SearchBookmarkThreshold) {
        searchMinimumBookmarks = value
        UserDefaults.standard.set(value.value, forKey: "searchMinimumBookmarks")
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setSearchMaximumBookmarks(_ value: SearchBookmarkThreshold) {
        searchMaximumBookmarks = value
        UserDefaults.standard.set(value.value, forKey: "searchMaximumBookmarks")
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setSearchArtworkType(_ value: SearchArtworkType) {
        let profile = SearchOptionsProfileKind.artworkProfile(for: value)
        guard profile == activeSearchOptionsProfile else {
            activateSearchOptionsProfile(profile)
            return
        }
        searchArtworkType = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchArtworkType")
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setSearchAIFilter(_ value: SearchAIFilter) {
        searchAIFilter = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchAIFilter")
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setSearchUgoiraFilter(_ value: SearchUgoiraFilter) {
        searchUgoiraFilter = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchUgoiraFilter")
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setSearchNovelLanguageCode(_ value: String?) {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, normalized.isEmpty == false {
            searchNovelLanguageCode = normalized
            UserDefaults.standard.set(normalized, forKey: "searchNovelLanguageCode")
        } else {
            searchNovelLanguageCode = nil
            UserDefaults.standard.removeObject(forKey: "searchNovelLanguageCode")
        }
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setSearchNovelGenreID(_ value: Int?) {
        searchNovelGenreID = value
        if let value {
            UserDefaults.standard.set(value, forKey: "searchNovelGenreID")
        } else {
            UserDefaults.standard.removeObject(forKey: "searchNovelGenreID")
        }
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setSearchNovelTextLength(_ value: SearchNovelTextLength) {
        searchNovelTextLength = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchNovelTextLength")
        rememberCurrentSearchOptionsProfile()
        applyContentFilters()
    }

    func setImageSourceSearchEngine(_ value: ImageSourceSearchEngineKind) {
        persistRaw("imageSourceSearchEngine", value: value, to: \.imageSourceSearchEngine)
    }

    func setUseRankingDate(_ value: Bool) {
        persist("useRankingDate", value: value, to: \.useRankingDate)
    }

    func setRankingDate(_ value: Date) {
        let clamped = Self.clampedRankingDate(value)
        rankingDate = clamped
        UserDefaults.standard.set(clamped, forKey: "rankingDate")
    }

    func setAppLanguage(_ language: AppLanguage) {
        persistRaw("appLanguage", value: language, to: \.appLanguage)
    }

    func setTranslationTargetLanguage(_ language: TranslationTargetLanguage) {
        persistRaw("translationTargetLanguage", value: language, to: \.translationTargetLanguage)
    }

    func setAppColorScheme(_ scheme: AppColorScheme) {
        persistRaw("appColorScheme", value: scheme, to: \.appColorScheme)
    }

    func setLaunchDestination(_ destination: LaunchDestination) {
        persistRaw("launchDestination", value: destination, to: \.launchDestination)
    }

    func setRouteSwitchRefreshExpiration(_ expiration: RouteSwitchRefreshExpiration) {
        persistRaw(RouteSwitchRefreshExpiration.defaultsKey, value: expiration, to: \.routeSwitchRefreshExpiration)
    }

    /// Persists the proxy mode picker. Mode flips take effect on the
    /// next URLSession init — KeiPix surfaces a footer note that the
    /// app must restart for the change to apply, mirroring how Pixez
    /// ships the same setting (and avoiding mid-flight session
    /// invalidation on the global ImagePipeline).
    func setProxyConfigurationMode(_ mode: ProxyConfigurationMode) {
        persistRaw(ProxyConfiguration.DefaultsKey.mode, value: mode, to: \.proxyConfigurationMode)
    }

    func setProxyConfigurationHost(_ host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        persist(ProxyConfiguration.DefaultsKey.host, value: trimmed, to: \.proxyConfigurationHost)
    }

    func setProxyConfigurationPort(_ port: Int) {
        let clamped = max(0, min(port, 65_535))
        persist(ProxyConfiguration.DefaultsKey.port, value: clamped, to: \.proxyConfigurationPort)
    }

    func setProxyConfigurationScheme(_ scheme: ProxyScheme) {
        persistRaw(ProxyConfiguration.DefaultsKey.scheme, value: scheme, to: \.proxyConfigurationScheme)
    }

    /// Persists the launch-time update-check toggle. Flipping it off
    /// also clears `lastUpdateCheckAt` so re-enabling the toggle later
    /// doesn't replay an already-passed throttle window.
    func setCheckForUpdatesOnLaunch(_ value: Bool) {
        checkForUpdatesOnLaunch = value
        UserDefaults.standard.set(value, forKey: "checkForUpdatesOnLaunch")
        if value == false {
            lastUpdateCheckAt = nil
            UserDefaults.standard.removeObject(forKey: "lastUpdateCheckAt")
        }
    }

    /// Toggles whether a bookmark tag is pinned. Returns `true` when the tag
    /// is pinned after the call so callers can show appropriate feedback.
    @discardableResult
    func togglePinnedBookmarkTag(_ tag: String) -> Bool {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return false }
        let pinned: Bool
        if pinnedBookmarkTags.contains(trimmed) {
            pinnedBookmarkTags.remove(trimmed)
            pinned = false
        } else {
            pinnedBookmarkTags.insert(trimmed)
            pinned = true
        }
        UserDefaults.standard.set(Array(pinnedBookmarkTags), forKey: "pinnedBookmarkTags")
        return pinned
    }

    func isBookmarkTagPinned(_ tag: String) -> Bool {
        pinnedBookmarkTags.contains(tag.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func setCompactArtworkCards(_ value: Bool) {
        setGalleryLayoutMode(value ? .compactGrid : .autoMasonry)
    }

    func setGalleryLayoutMode(_ mode: GalleryLayoutMode) {
        galleryLayoutMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "galleryLayoutMode")
        UserDefaults.standard.set(mode.usesCompactGrid, forKey: "compactArtworkCards")
    }

    func setCreatorListLayoutMode(_ mode: CreatorListLayoutMode) {
        persistRaw("creatorListLayoutMode", value: mode, to: \.creatorListLayoutMode)
    }

    func setSpotlightListLayoutMode(_ mode: SpotlightListLayoutMode) {
        persistRaw("spotlightListLayoutMode", value: mode, to: \.spotlightListLayoutMode)
    }

    func setNovelGalleryLayoutMode(_ mode: NovelGalleryLayoutMode) {
        persistRaw("novelGalleryLayoutMode", value: mode, to: \.novelGalleryLayoutMode)
    }

    func setPixivActivityLayoutMode(_ mode: PixivActivityLayoutMode) {
        persistRaw("pixivActivityLayoutMode", value: mode, to: \.pixivActivityLayoutMode)
    }

    var dashboardCardOrder: [DiscoveryDashboardCardKind] {
        DiscoveryDashboardCardKind.ordered(from: dashboardCardOrderID)
    }

    var visibleDashboardCards: [DiscoveryDashboardCardKind] {
        DiscoveryDashboardCardKind.visibleCards(order: dashboardCardOrder, hiddenIDs: effectiveHiddenDashboardCardIDs)
    }

    func isDashboardCardVisible(_ card: DiscoveryDashboardCardKind) -> Bool {
        effectiveHiddenDashboardCardIDs.contains(card.id) == false
    }

    func setDashboardCardVisible(_ visible: Bool, for card: DiscoveryDashboardCardKind) {
        hiddenDashboardCardIDs = DiscoveryDashboardCardKind.hiddenIDs(
            afterSetting: visible,
            for: card,
            currentHiddenIDs: effectiveHiddenDashboardCardIDs,
            order: dashboardCardOrder
        )
        UserDefaults.standard.set(Array(hiddenDashboardCardIDs), forKey: "hiddenDashboardCardIDs")
    }

    private var effectiveHiddenDashboardCardIDs: Set<String> {
        guard UserDefaults.standard.object(forKey: "hiddenDashboardCardIDs") != nil else {
            return hiddenDashboardCardIDs.union(DiscoveryDashboardCardKind.defaultHiddenIDs)
        }
        return hiddenDashboardCardIDs
    }

    func moveDashboardCard(_ card: DiscoveryDashboardCardKind, offset: Int) {
        let cards = DiscoveryDashboardCardKind.moved(card, offset: offset, in: dashboardCardOrder)
        guard cards != dashboardCardOrder else { return }
        dashboardCardOrderID = DiscoveryDashboardCardKind.storageID(for: cards)
        UserDefaults.standard.set(dashboardCardOrderID, forKey: "dashboardCardOrderID")
    }

    func isDashboardSectionVisible(_ section: DiscoveryDashboardSection) -> Bool {
        hiddenDashboardSectionIDs.contains(section.id) == false
    }

    func setDashboardSectionVisible(_ visible: Bool, for section: DiscoveryDashboardSection) {
        if visible {
            hiddenDashboardSectionIDs.remove(section.id)
        } else {
            hiddenDashboardSectionIDs.insert(section.id)
        }
        UserDefaults.standard.set(Array(hiddenDashboardSectionIDs), forKey: "hiddenDashboardSectionIDs")
    }

    var visibleDashboardSections: [DiscoveryDashboardSection] {
        DiscoveryDashboardSection.all.filter { isDashboardSectionVisible($0) }
    }

    func isDashboardRouteSectionExpanded(_ section: DiscoveryDashboardSection) -> Bool {
        expandedDashboardRouteSectionIDs.contains(section.id)
    }

    func setDashboardRouteSectionExpanded(_ expanded: Bool, for section: DiscoveryDashboardSection) {
        if expanded {
            expandedDashboardRouteSectionIDs.insert(section.id)
        } else {
            expandedDashboardRouteSectionIDs.remove(section.id)
        }
        UserDefaults.standard.set(Array(expandedDashboardRouteSectionIDs), forKey: "expandedDashboardRouteSectionIDs")
    }

    func resetDashboardSections() {
        dashboardCardOrderID = DiscoveryDashboardCardKind.storageID(for: DiscoveryDashboardCardKind.defaultOrder)
        hiddenDashboardCardIDs.removeAll()
        hiddenDashboardSectionIDs.removeAll()
        expandedDashboardRouteSectionIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: "dashboardCardOrderID")
        UserDefaults.standard.removeObject(forKey: "hiddenDashboardCardIDs")
        UserDefaults.standard.removeObject(forKey: "hiddenDashboardSectionIDs")
        UserDefaults.standard.removeObject(forKey: "expandedDashboardRouteSectionIDs")
    }

    func setTrackpadGesturesEnabled(_ value: Bool) {
        persist("trackpadGesturesEnabled", value: value, to: \.trackpadGesturesEnabled)
    }

    func setHorizontalSwipeBehavior(_ behavior: TrackpadHorizontalSwipeBehavior) {
        persistRaw("horizontalSwipeBehavior", value: behavior, to: \.horizontalSwipeBehavior)
    }

    // MARK: - Image Processing

    func setImageProcessorsEnabled(_ value: Bool) {
        if value, activeImageProcessors.isEmpty {
            activeImageProcessors = ImageProcessorRegistry.defaultActiveProcessorIdentifiers
            UserDefaults.standard.set(activeImageProcessors, forKey: "activeImageProcessors")
        }
        imageProcessorsEnabled = value
        UserDefaults.standard.set(value, forKey: "imageProcessorsEnabled")
        _ = ImagePipeline.shared.clearCaches()
    }

    func setActiveImageProcessors(_ identifiers: [String]) {
        activeImageProcessors = identifiers
        UserDefaults.standard.set(identifiers, forKey: "activeImageProcessors")
        _ = ImagePipeline.shared.clearCaches()
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
        persistRaw(ArtworkReadingModePreferenceKind.artwork.storageKey, value: mode, to: \.defaultArtworkReadingMode)
    }

    func setDefaultMangaReadingMode(_ mode: ArtworkReadingMode) {
        persistRaw(ArtworkReadingModePreferenceKind.manga.storageKey, value: mode, to: \.defaultMangaReadingMode)
    }

    func restoredReaderPageIndex(for artwork: PixivArtwork, pageCount: Int? = nil) -> Int {
        guard restoreArtworkReaderProgress else { return 0 }
        let resolvedPageCount = pageCount ?? artwork.displayPageCount
        return readerProgressLibrary.restoredPageIndex(for: artwork.id, pageCount: resolvedPageCount) ?? 0
    }

    func saveReaderPageIndex(_ pageIndex: Int, for artwork: PixivArtwork, pageCount: Int? = nil) {
        guard restoreArtworkReaderProgress else { return }
        readerProgressLibrary.update(
            artworkID: artwork.id,
            pageIndex: pageIndex,
            pageCount: pageCount ?? artwork.displayPageCount
        )
        persistReaderProgressLibrary()
    }

    func restoredDownloadedReaderPageIndex(for item: ArtworkDownloadItem, pageCount: Int) -> Int {
        guard restoreArtworkReaderProgress else { return 0 }
        return downloadedReaderProgressLibrary.restoredPageIndex(for: item.id, pageCount: pageCount) ?? 0
    }

    func saveDownloadedReaderPageIndex(_ pageIndex: Int, for item: ArtworkDownloadItem, pageCount: Int) {
        guard restoreArtworkReaderProgress else { return }
        downloadedReaderProgressLibrary.update(
            downloadID: item.id,
            pageIndex: pageIndex,
            pageCount: pageCount
        )
        persistDownloadedReaderProgressLibrary()
    }

    func mangaWatchlistUpdateStatus(for series: PixivMangaSeriesPreview) -> MangaWatchlistUpdateStatus {
        mangaWatchlistReadStateLibrary.status(for: series)
    }

    func registerMangaWatchlistSnapshot(_ series: [PixivMangaSeriesPreview]) {
        mangaWatchlistReadStateLibrary.registerSnapshot(series)
        persistMangaWatchlistReadStateLibrary()
    }

    func markMangaWatchlistSeriesRead(_ series: PixivMangaSeriesPreview) {
        mangaWatchlistReadStateLibrary.markRead(series)
        persistMangaWatchlistReadStateLibrary()
    }

    func removeMangaWatchlistReadState(seriesID: Int) {
        mangaWatchlistReadStateLibrary.remove(seriesID: seriesID)
        persistMangaWatchlistReadStateLibrary()
    }

    func persistReaderProgressLibrary() {
        guard let data = try? JSONEncoder().encode(readerProgressLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "readerProgressLibrary")
    }

    func persistDownloadedReaderProgressLibrary() {
        guard let data = try? JSONEncoder().encode(downloadedReaderProgressLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "downloadedReaderProgressLibrary")
    }

    func persistMangaWatchlistReadStateLibrary() {
        guard let data = try? JSONEncoder().encode(mangaWatchlistReadStateLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "mangaWatchlistReadStateLibrary")
    }
}
