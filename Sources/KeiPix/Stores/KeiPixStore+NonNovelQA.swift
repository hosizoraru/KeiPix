import Foundation

@MainActor
extension KeiPixStore {
    func runNonNovelQAMatrix() async -> NonNovelQAMatrixSnapshot {
        let checkedAt = Date()
        guard session != nil else {
            return recordNonNovelQAMatrixSnapshot(NonNovelQAMatrixSnapshot(
                checkedAt: checkedAt,
                items: Self.nonNovelQABaseline.map {
                    $0.item(status: .skipped, evidence: L10n.signedOut, nextAction: L10n.signInAndRunQA)
                }
            ))
        }

        async let feeds = qaFeedSurfaces()
        async let discovery = qaDiscoverySurfaces()
        async let account = qaAccountSurfaces()
        async let search = qaSearchSurfaces()
        async let selected = qaSelectedArtworkSurfaces()
        async let local = qaLocalSurfaces()

        let groups = await [feeds, discovery, account, search, selected, local]
        return recordNonNovelQAMatrixSnapshot(NonNovelQAMatrixSnapshot(checkedAt: checkedAt, items: groups.flatMap { $0 }))
    }

    static var nonNovelQABaselineItems: [NonNovelQAItem] {
        nonNovelQABaseline.map {
            $0.item(status: .needsEvidence, evidence: L10n.notRun, nextAction: $0.nextAction)
        }
    }

    private func qaFeedSurfaces() async -> [NonNovelQAItem] {
        let visualEvidence = Self.visualQAEvidenceIndex()
        async let recommended = qaFeedItem(
            id: "illust-feeds",
            count: { try await self.api.recommendedIllusts().illusts.count }
        )
        async let manga = qaFeedItem(
            id: "manga-feeds",
            count: { try await self.api.recommendedMangas().illusts.count },
            visualSurfaces: [.mangaWatchlist, .seriesSheet],
            visualEvidence: visualEvidence
        )
        async let ranking = qaFeedItem(
            id: "ranking",
            count: { try await self.api.ranking(mode: "day").illusts.count },
            visualSurface: .ranking,
            visualEvidence: visualEvidence
        )
        async let following = qaFeedItem(
            id: "following-feed",
            count: { try await self.api.following(restrict: "public").illusts.count }
        )
        return await [recommended, manga, ranking, following]
    }

    private func qaDiscoverySurfaces() async -> [NonNovelQAItem] {
        let visualEvidence = Self.visualQAEvidenceIndex()
        async let trending = qaFeedItem(
            id: "trending-tags",
            count: { try await self.trendingTags().count },
            visualSurface: .trendingTags,
            visualEvidence: visualEvidence
        )
        async let spotlight = qaPixivisionItem(visualEvidence: visualEvidence)
        async let recommendedUsers = qaFeedItem(
            id: "creator-discovery",
            count: { try await self.recommendedUsers().userPreviews.count },
            visualSurface: .creatorProfile,
            visualEvidence: visualEvidence
        )
        return await [trending, spotlight, recommendedUsers]
    }

    private func qaAccountSurfaces() async -> [NonNovelQAItem] {
        guard let rawUserID = session?.user.id, let userID = Int(rawUserID) else {
            return [qaSkippedItem(id: "account-health", detail: L10n.signedOut)]
        }

        async let account = qaFeedItem(
            id: "account-health",
            count: {
                _ = try await self.api.userDetail(userID: userID)
                return 1
            }
        )
        async let bookmarks = qaFeedItem(
            id: "bookmarks",
            count: { try await self.api.bookmarks(restrict: "public", userID: rawUserID).illusts.count },
            visualSurface: .batchBookmarkPreview,
            visualEvidence: Self.visualQAEvidenceIndex()
        )
        async let followingCreators = qaFeedItem(
            id: "following-creators",
            count: { try await self.followingUsers(restrict: .public).userPreviews.count }
        )
        return await [account, bookmarks, followingCreators]
    }

    private func qaSearchSurfaces() async -> [NonNovelQAItem] {
        async let search = qaFeedItem(
            id: "search",
            count: {
                try await self.api.search(
                    keyword: "オリジナル",
                    options: .defaultValue
                ).illusts.count
            }
        )
        let visualEvidence = Self.visualQAEvidenceIndex()
        let pixivLinkDropSurfaces: [VisualQASurface] = [.pixivLinkDrop, .pixivIDOpen]
        async let urlResolver = qaStaticItem(
            id: "pixiv-url-routing",
            passed: PixivURLRoutingCoverage.passes && visualEvidence.covers(pixivLinkDropSurfaces),
            evidence: [
                PixivURLRoutingCoverage.summary,
                visualEvidence.summary(for: pixivLinkDropSurfaces)
            ].joined(separator: " · ")
        )
        return await [search, urlResolver]
    }

    private func qaSelectedArtworkSurfaces() async -> [NonNovelQAItem] {
        guard let selectedArtwork else {
            return [
                qaSkippedItem(id: "reader", detail: L10n.noSelection),
                qaSkippedItem(id: "artwork-detail-social", detail: L10n.noSelection),
                qaSkippedItem(id: "comments-feedback", detail: L10n.noSelection)
            ]
        }

        let visualEvidence = Self.visualQAEvidenceIndex()
        async let detail = qaFeedItem(
            id: "artwork-detail-social",
            count: {
                _ = try await self.api.illustDetail(illustID: selectedArtwork.id)
                return 1
            },
            visualSurface: .artworkDetailSocial,
            visualEvidence: visualEvidence
        )
        async let comments = qaFeedItem(
            id: "comments-feedback",
            count: { try await self.api.illustComments(illustID: selectedArtwork.id).comments.count }
        )
        let reader = qaStaticItem(
            id: "reader",
            passed: selectedArtwork.images.isEmpty == false
                && selectedArtwork.pageCount > 0
                && visualEvidence.covers([.readerWindow]),
            evidence: [
                String(format: L10n.pageCountFormat, selectedArtwork.pageCount),
                visualEvidence.summary(for: [.readerWindow])
            ].joined(separator: " · ")
        )
        return await [reader, detail, comments]
    }

    private func qaLocalSurfaces() async -> [NonNovelQAItem] {
        let visualEvidence = Self.visualQAEvidenceIndex()
        let nativeRoute = qaStaticItem(
            id: "native-apple-route",
            passed: true,
            evidence: L10n.qaNativeAppleRouteEvidence
        )
        let requiredGallerySurfaces: [VisualQASurface] = [
            .discoverDashboard,
            .galleryFeed,
            .galleryAuto,
            .galleryTwoColumn,
            .galleryThreeColumn,
            .galleryCompact,
            .trendingTags,
            .pixivision,
            .narrowWindow
        ]
        let gallery = qaStaticItem(
            id: "gallery-visual",
            passed: visualEvidence.covers(requiredGallerySurfaces),
            evidence: visualEvidence.summary(for: requiredGallerySurfaces)
        )
        let downloadSurfaces: [VisualQASurface] = [.downloadQueue, .downloadedReader]
        let downloads = qaStaticItem(
            id: "downloads",
            passed: visualEvidence.covers(downloadSurfaces),
            evidence: [
                String(
                    format: L10n.downloadReadinessFormat,
                    self.downloads.items.count,
                    self.downloads.activeCount,
                    self.downloads.completedCount
                ),
                visualEvidence.summary(for: downloadSurfaces)
            ].joined(separator: " · ")
        )
        let safetySurfaces: [VisualQASurface] = [.mutedContent, .feedbackSheet]
        let safety = qaStaticItem(
            id: "safety-filtering",
            passed: visualEvidence.covers(safetySurfaces),
            evidence: [
                hideAIArtworks ? L10n.aiGenerated : nil,
                hideR18Artworks ? L10n.r18 : nil,
                hideR18GArtworks ? L10n.r18g : nil,
                maskSensitivePreviews ? L10n.maskSensitivePreviews : nil,
                hideMutedContent ? L10n.muted : nil,
                visualEvidence.summary(for: safetySurfaces)
            ].compactMap(\.self).joined(separator: " · ").nilIfEmpty ?? L10n.availableInDiagnostics
        )
        let cache = await imageCacheStatus()
        let cachedFeedSurfaces: [VisualQASurface] = [.cachedFeed]
        let offline = qaStaticItem(
            id: "local-cache-offline",
            passed: cache.diskCapacity > 0 && visualEvidence.covers(cachedFeedSurfaces),
            evidence: [
                cache.summaryText,
                visualEvidence.summary(for: cachedFeedSurfaces)
            ].joined(separator: " · ")
        )
        let ugoiraSurfaces: [VisualQASurface] = [.ugoiraPlayer]
        let ugoira = qaStaticItem(
            id: "ugoira",
            passed: visualEvidence.covers(ugoiraSurfaces),
            evidence: visualEvidence.summary(for: ugoiraSurfaces)
        )
        let settings = qaStaticItem(
            id: "settings-organization",
            passed: visualEvidence.covers([.settingsWindow, .runtimeReadiness]),
            evidence: visualEvidence.summary(for: [.settingsWindow, .runtimeReadiness])
        )
        let sharing = qaStaticItem(
            id: "sharing-copy",
            passed: visualEvidence.covers([.sharingTemplates]),
            evidence: [
                visualEvidence.summary(for: [.sharingTemplates]),
                "\(L10n.artworkCopyTemplate): \(ArtworkCopyTemplate(rawValue: artworkCopyTemplate).render(context: .preview).visibleLineCount)",
                "\(L10n.creatorCopyTemplate): \(CreatorCopyTemplate(rawValue: creatorCopyTemplate).render(context: .preview).visibleLineCount)"
            ].joined(separator: " · ")
        )
        // Image quality tiers — passes once all three surfaces (feed,
        // illust, manga) have a persisted tier and the legacy
        // `useOriginalImagesInDetail` bridge stays in lock-step. The
        // matrix can't run the picker visually so we anchor the
        // regression on the resolved enum / legacy-Bool agreement,
        // which is what would silently drift if a future refactor
        // forgot to touch the lock-step setter.
        let imageQuality = qaStaticItem(
            id: "image-quality-tier",
            passed: illustDetailImageQualityTier.prefersOriginal == useOriginalImagesInDetail
                && mangaDetailImageQualityTier.prefersOriginal == useOriginalImagesForManga,
            evidence: [
                "\(L10n.feedPreviewQuality): \(feedPreviewImageQualityTier.title)",
                "\(L10n.illustDetailQuality): \(illustDetailImageQualityTier.title)",
                "\(L10n.mangaDetailQuality): \(mangaDetailImageQualityTier.title)"
            ].joined(separator: " · ")
        )
        // Caption translation — passes when the gate helper agrees on
        // the canonical Pixiv caption shapes (typical mixed-script
        // post + emoji-only blurb). Mirrors the unit test floor so
        // both production code and runtime QA stay aligned.
        let translationSamplesPassed = CaptionTranslationAvailability.canTranslate("可愛いイラストです🌸")
            && CaptionTranslationAvailability.canTranslate("Hello world") == true
            && CaptionTranslationAvailability.canTranslate("🌸🌸🌸") == false
        let captionTranslation = qaStaticItem(
            id: "caption-translation",
            passed: translationSamplesPassed,
            evidence: L10n.qaCaptionTranslationEvidence
        )
        // Following-artist emphasis — passes when the persisted toggle
        // is in sync with what `ArtworkCardView` reads on render.
        // Mirrors Pixes' `emphasizeArtworksFromFollowingArtists`
        // preference; we anchor on the toggle round-tripping rather
        // than on any specific artwork because the visual treatment
        // is gated behind `user.is_followed`, which a clean install
        // can't yet evaluate without a session.
        let storedEmphasizeFollowing = (UserDefaults.standard.object(forKey: "emphasizeFollowingArtists") as? Bool)
            ?? true
        let followingEmphasis = qaStaticItem(
            id: "following-emphasis",
            passed: storedEmphasizeFollowing == emphasizeFollowingArtists,
            evidence: storedEmphasizeFollowing ? L10n.enabled : L10n.disabled
        )
        return [
            nativeRoute,
            gallery,
            downloads,
            safety,
            offline,
            ugoira,
            settings,
            sharing,
            imageQuality,
            captionTranslation,
            followingEmphasis,
            qaTransferableDragDropItem(),
            qaQuickLookItem(visualEvidence: visualEvidence),
            qaThroughputItem(visualEvidence: visualEvidence),
            qaDownloadFinishNotificationItem(visualEvidence: visualEvidence),
            qaProxyConfigurationItem(),
            qaReleaseUpdateCheckItem()
        ]
    }

    /// Builds the Transferable drag-and-drop QA row. Pulled into its
    /// own method so `qaLocalSurfaces` stays under SwiftLint's
    /// `function_body_length` ceiling — the local surfaces list keeps
    /// growing as we land P2 items, and inlining each new check pushes
    /// the parent function past the 100-line limit.
    private func qaTransferableDragDropItem() -> NonNovelQAItem {
        // Transferable drag-and-drop — anchors on the symmetry between
        // the modern drop side (`PixivLinkDropPayload`) and the new
        // drag sources (artwork cards + completed download rows). We
        // verify the drop reader still recognises the canonical Pixiv
        // shapes so a future `Transferable` refactor can't silently
        // break the inbound side, and we surface the audit so visual
        // QA can confirm the outbound drag overlays render.
        let dragDropPayloads = [
            PixivLinkDropPayload(rawText: "https://www.pixiv.net/artworks/12345"),
            PixivLinkDropPayload(rawText: "Check this: https://www.pixiv.net/users/678 thanks!"),
            PixivLinkDropPayload(rawText: "pixiv://illusts/901")
        ]
        let dragDropResolves = PixivDroppedLinkReader.firstSupportedURL(from: dragDropPayloads) != nil
        return qaStaticItem(
            id: "transferable-drag-drop",
            passed: dragDropResolves,
            evidence: L10n.qaTransferableDragDropEvidence
        )
    }

    /// Builds the Quick Look QA row. Lives in its own method so
    /// `qaLocalSurfaces` stays under SwiftLint's
    /// `function_body_length` ceiling — the local surfaces list keeps
    /// growing as we land P2 items, and inlining each new check pushes
    /// the parent function past the 100-line limit.
    private func qaQuickLookItem(visualEvidence: VisualQAEvidenceIndex) -> NonNovelQAItem {
        // Quick Look — passes once a download-queue screenshot covers
        // the surface (the Quick Look button only renders inside that
        // view) and the row helper still resolves a non-nil URL for at
        // least one completed item with a readable artifact. The
        // visual surface check is the regression anchor; the live
        // resolution check guards against future refactors that strip
        // the helper but leave the toolbar button behind.
        let quickLookSurfaces: [VisualQASurface] = [.downloadQueue]
        let hasResolvableQuickLook = self.downloads.completedItems.contains { item in
            self.downloads.hasReadableDownload(for: item)
        }
        let quickLookPassed = visualEvidence.covers(quickLookSurfaces)
            && (self.downloads.completedItems.isEmpty || hasResolvableQuickLook)
        return qaStaticItem(
            id: "quick-look",
            passed: quickLookPassed,
            evidence: [
                L10n.qaQuickLookEvidence,
                visualEvidence.summary(for: quickLookSurfaces)
            ].joined(separator: " · ")
        )
    }

    /// Builds the live-throughput QA row. Pulled into its own method
    /// so `qaLocalSurfaces` stays under SwiftLint's
    /// `function_body_length` ceiling — the local surfaces list keeps
    /// growing as we land P2 items, and inlining each new check pushes
    /// the parent function past the 100-line limit.
    private func qaThroughputItem(visualEvidence: VisualQAEvidenceIndex) -> NonNovelQAItem {
        // Live throughput — passes once a download-queue screenshot
        // covers the surface and the sampler is wired up. We can't
        // assert "the speedometer is moving right now" from a static
        // check, so the regression anchor is the visual-evidence
        // requirement plus the helper's existence (verified at compile
        // time by the call below).
        let throughputSurfaces: [VisualQASurface] = [.downloadQueue]
        let throughputSamplerWired = self.downloads.aggregateThroughputText != nil
            || self.downloads.downloadingCount == 0
        return qaStaticItem(
            id: "download-throughput",
            passed: visualEvidence.covers(throughputSurfaces) && throughputSamplerWired,
            evidence: [
                L10n.qaDownloadThroughputEvidence,
                visualEvidence.summary(for: throughputSurfaces)
            ].joined(separator: " · ")
        )
    }

    /// Builds the app-level proxy QA row. Pulled into its own method
    /// so `qaLocalSurfaces` stays under SwiftLint's
    /// `function_body_length` ceiling — the local surfaces list keeps
    /// growing as we land P2 items, and inlining each new check pushes
    /// the parent function past the 100-line limit.
    private func qaProxyConfigurationItem() -> NonNovelQAItem {
        // App-level proxy — the regression anchor is the round-trip
        // between the persisted UserDefaults snapshot and the
        // ProxyConfiguration enum the URLSession owners read at init.
        // We can't probe a live proxy from a static check, but we
        // can guarantee that the same enum case the user picked is
        // what the next launch will hand to PixivAPI / ImagePipeline,
        // and that each scheme produces a non-empty proxy dictionary
        // shape (which would silently drift if a future refactor
        // forgot to wire up a new CFNetwork key).
        let snapshot = ProxyConfiguration.loadFromUserDefaults()
        let modesAgree: Bool
        switch (snapshot, proxyConfigurationMode) {
        case (.system, .system), (.direct, .direct), (.manual, .manual):
            modesAgree = true
        default:
            modesAgree = false
        }
        let manualSampleProducesDictionary = ProxyConfiguration
            .manual(host: "127.0.0.1", port: 7_890, scheme: .http)
            .connectionProxyDictionary?.isEmpty == false
        return qaStaticItem(
            id: "proxy-configuration",
            passed: modesAgree && manualSampleProducesDictionary,
            evidence: L10n.qaProxyConfigurationEvidence
        )
    }

    /// Builds the release-update-check QA row. Pulled into its own
    /// method so `qaLocalSurfaces` stays under SwiftLint's
    /// `function_body_length` ceiling — the local surfaces list keeps
    /// growing as we land P2 items, and inlining each new check pushes
    /// the parent function past the 100-line limit.
    private func qaReleaseUpdateCheckItem() -> NonNovelQAItem {
        // Release update check — anchors on three deterministic
        // invariants that would silently drift if a future refactor
        // unwired the feature: the SemanticVersion comparator orders
        // canonical pairs correctly, the bundle's CFBundleShortVersionString
        // parses back into a usable SemanticVersion, and the persisted
        // toggle round-trips through KeiPixStore. We can't probe a
        // live GitHub release from a static check, so the network
        // round-trip lives in the unit suite (decodeRelease fixture).
        let comparatorOrders = (SemanticVersion("0.1.0") ?? .init(major: 0, minor: 0, patch: 0))
            < (SemanticVersion("0.2.0") ?? .init(major: 0, minor: 0, patch: 0))
        let prereleaseOrdering = (SemanticVersion("0.2.0-rc.1") ?? .init(major: 0, minor: 0, patch: 0))
            < (SemanticVersion("0.2.0") ?? .init(major: 0, minor: 0, patch: 0))
        let bundleVersionParses = currentReleaseSemanticVersion >= SemanticVersion(major: 0, minor: 0, patch: 0)
        let storedToggle = (UserDefaults.standard.object(forKey: "checkForUpdatesOnLaunch") as? Bool) ?? true
        let toggleInSync = storedToggle == checkForUpdatesOnLaunch
        return qaStaticItem(
            id: "release-update-check",
            passed: comparatorOrders && prereleaseOrdering && bundleVersionParses && toggleInSync,
            evidence: L10n.qaReleaseUpdateCheckEvidence
        )
    }

    /// Builds the download-finish notification QA row. Pulled into
    /// its own method so `qaLocalSurfaces` stays under SwiftLint's
    /// `function_body_length` ceiling — the local surfaces list keeps
    /// growing as we land P2 items, and inlining each new check pushes
    /// the parent function past the 100-line limit.
    private func qaDownloadFinishNotificationItem(visualEvidence: VisualQAEvidenceIndex) -> NonNovelQAItem {
        // Notification Center banner on download finish — passes once
        // a download-queue screenshot covers the surface and the
        // toggle round-trips through ArtworkDownloadStore. We can't
        // assert "a banner just posted" from a static check, so the
        // regression anchor is the visual-evidence requirement plus
        // the persisted-toggle agreement (which would silently drift
        // if a future refactor unwired setNotifyOnDownloadFinish from
        // UserDefaults). Compile-time existence of the notifier is
        // guaranteed by the type system on ArtworkDownloadStore.
        let notificationSurfaces: [VisualQASurface] = [.downloadQueue]
        let storedToggle = (UserDefaults.standard.object(forKey: "notifyOnDownloadFinish") as? Bool) ?? false
        let toggleInSync = storedToggle == self.downloads.notifyOnDownloadFinish
        return qaStaticItem(
            id: "download-finish-notification",
            passed: visualEvidence.covers(notificationSurfaces) && toggleInSync,
            evidence: [
                L10n.qaDownloadFinishNotificationEvidence,
                visualEvidence.summary(for: notificationSurfaces)
            ].joined(separator: " · ")
        )
    }

    private func qaFeedItem(
        id: String,
        count: @escaping @Sendable () async throws -> Int,
        visualSurface: VisualQASurface? = nil,
        visualSurfaces: [VisualQASurface] = [],
        visualEvidence: VisualQAEvidenceIndex? = nil
    ) async -> NonNovelQAItem {
        guard let template = Self.nonNovelQABaseline.first(where: { $0.id == id }) else {
            return NonNovelQATemplate.unknown(id: id).item(status: .actionRequired, evidence: L10n.unknown, nextAction: L10n.reviewImplementation)
        }

        do {
            let value = try await count()
            let resolvedVisualEvidence = visualEvidence ?? Self.visualQAEvidenceIndex()
            let singleVisualSurfaces = visualSurface.map { [$0] } ?? []
            let requiredVisualSurfaces = visualSurfaces + singleVisualSurfaces
            let hasVisualEvidence = resolvedVisualEvidence.covers(requiredVisualSurfaces)
            let passed = value > 0 && (requiredVisualSurfaces.isEmpty || hasVisualEvidence)
            let status: NonNovelQAStatus = passed ? .passed : .needsEvidence
            let nextAction = passed ? L10n.keepRegressionCoverage : template.nextAction
            let evidence = [
                String(format: L10n.qaLoadedCountFormat, value),
                requiredVisualSurfaces.isEmpty ? nil : resolvedVisualEvidence.summary(for: requiredVisualSurfaces)
            ].compactMap(\.self).joined(separator: " · ")
            return template.item(
                status: status,
                evidence: evidence,
                nextAction: nextAction
            )
        } catch {
            return template.item(status: .actionRequired, evidence: error.localizedDescription, nextAction: template.nextAction)
        }
    }

    private func qaPixivisionItem(visualEvidence: VisualQAEvidenceIndex) async -> NonNovelQAItem {
        guard let template = Self.nonNovelQABaseline.first(where: { $0.id == "pixivision" }) else {
            return NonNovelQATemplate.unknown(id: "pixivision").item(status: .actionRequired, evidence: L10n.unknown, nextAction: L10n.reviewImplementation)
        }

        do {
            let response = try await spotlightArticles()
            guard let article = response.articles.first else {
                return template.item(
                    status: .needsEvidence,
                    evidence: String(format: L10n.qaLoadedCountFormat, 0),
                    nextAction: template.nextAction
                )
            }

            let audit = try await PixivisionArticleLinkAuditor.audit(article: article)
            let hasVisualEvidence = visualEvidence.covers([.pixivision])
            let passed = audit.hasNativeLinks && hasVisualEvidence
            let evidence = [
                String(format: L10n.qaLoadedCountFormat, response.articles.count),
                audit.evidence,
                visualEvidence.summary(for: [.pixivision])
            ].joined(separator: " · ")
            return template.item(
                status: passed ? .passed : .needsEvidence,
                evidence: evidence,
                nextAction: passed ? L10n.keepRegressionCoverage : template.nextAction
            )
        } catch {
            return template.item(status: .actionRequired, evidence: error.localizedDescription, nextAction: template.nextAction)
        }
    }

    private func qaStaticItem(
        id: String,
        passed: Bool,
        evidence: String = L10n.availableInDiagnostics
    ) -> NonNovelQAItem {
        guard let template = Self.nonNovelQABaseline.first(where: { $0.id == id }) else {
            return NonNovelQATemplate.unknown(id: id).item(status: .actionRequired, evidence: L10n.unknown, nextAction: L10n.reviewImplementation)
        }
        return template.item(
            status: passed ? .passed : .needsEvidence,
            evidence: evidence,
            nextAction: passed ? L10n.keepRegressionCoverage : template.nextAction
        )
    }

    private func qaSkippedItem(id: String, detail: String) -> NonNovelQAItem {
        guard let template = Self.nonNovelQABaseline.first(where: { $0.id == id }) else {
            return NonNovelQATemplate.unknown(id: id).item(status: .skipped, evidence: detail, nextAction: L10n.reviewImplementation)
        }
        return template.item(status: .skipped, evidence: detail, nextAction: template.nextAction)
    }

    @discardableResult
    private func recordNonNovelQAMatrixSnapshot(_ snapshot: NonNovelQAMatrixSnapshot) -> NonNovelQAMatrixSnapshot {
        lastNonNovelQAMatrixSnapshot = snapshot
        persistLastNonNovelQAMatrixSnapshot()
        return snapshot
    }

    static func loadLastNonNovelQAMatrixSnapshot() -> NonNovelQAMatrixSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: "lastNonNovelQAMatrixSnapshot") else {
            return nil
        }
        return try? JSONDecoder().decode(NonNovelQAMatrixSnapshot.self, from: data)
    }

    private func persistLastNonNovelQAMatrixSnapshot() {
        guard let data = try? JSONEncoder().encode(lastNonNovelQAMatrixSnapshot) else { return }
        UserDefaults.standard.set(data, forKey: "lastNonNovelQAMatrixSnapshot")
    }
}

private struct NonNovelQATemplate {
    let id: String
    let priority: NonNovelQAPriority
    let title: String
    let requirement: String
    let nextAction: String
    let systemImage: String

    func item(status: NonNovelQAStatus, evidence: String, nextAction: String) -> NonNovelQAItem {
        NonNovelQAItem(
            id: id,
            priority: priority,
            title: title,
            requirement: requirement,
            status: status,
            evidence: evidence,
            nextAction: nextAction,
            systemImage: systemImage
        )
    }

    static func unknown(id: String) -> NonNovelQATemplate {
        NonNovelQATemplate(
            id: id,
            priority: .p2,
            title: id,
            requirement: L10n.reviewImplementation,
            nextAction: L10n.reviewImplementation,
            systemImage: "questionmark.circle"
        )
    }
}

private extension KeiPixStore {
    static func visualQAEvidenceIndex() -> VisualQAEvidenceIndex {
        return VisualQAEvidenceIndex(rootURLs: visualQAEvidenceRootCandidates())
    }

    static func visualQAEvidenceRootCandidates() -> [URL] {
        var roots: [URL] = []
        if let explicitRoot = ProcessInfo.processInfo.environment["KEIPIX_REPO_ROOT"], explicitRoot.isEmpty == false {
            roots.append(URL(fileURLWithPath: explicitRoot, isDirectory: true))
        }
        roots.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        roots.append(Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())

        var seen = Set<String>()
        return roots.map {
            $0.appending(path: "artifacts", directoryHint: .isDirectory)
                .appending(path: "visual-qa", directoryHint: .isDirectory)
        }.filter { root in
            seen.insert(root.standardizedFileURL.path(percentEncoded: false)).inserted
        }
    }

    static let nonNovelQABaseline: [NonNovelQATemplate] = [
        NonNovelQATemplate(id: "native-apple-route", priority: .p0, title: L10n.qaNativeAppleRoute, requirement: L10n.qaNativeAppleRouteRequirement, nextAction: L10n.qaNativeAppleRouteNext, systemImage: "swift"),
        NonNovelQATemplate(id: "gallery-visual", priority: .p0, title: L10n.qaGalleryVisual, requirement: L10n.qaGalleryVisualRequirement, nextAction: L10n.qaGalleryVisualNext, systemImage: "rectangle.grid.2x2"),
        NonNovelQATemplate(id: "trending-tags", priority: .p0, title: L10n.qaTrendingTags, requirement: L10n.qaTrendingTagsRequirement, nextAction: L10n.qaTrendingTagsNext, systemImage: "number"),
        NonNovelQATemplate(id: "pixivision", priority: .p0, title: L10n.qaPixivision, requirement: L10n.qaPixivisionRequirement, nextAction: L10n.qaPixivisionNext, systemImage: "newspaper"),
        NonNovelQATemplate(id: "pixiv-url-routing", priority: .p0, title: L10n.qaPixivURLRouting, requirement: L10n.qaPixivURLRoutingRequirement, nextAction: L10n.qaPixivURLRoutingNext, systemImage: "link"),
        NonNovelQATemplate(id: "account-health", priority: .p1, title: L10n.qaAccountHealth, requirement: L10n.qaAccountHealthRequirement, nextAction: L10n.qaAccountHealthNext, systemImage: "person.crop.circle.badge.checkmark"),
        NonNovelQATemplate(id: "manga-feeds", priority: .p1, title: L10n.qaMangaFeeds, requirement: L10n.qaMangaFeedsRequirement, nextAction: L10n.qaMangaFeedsNext, systemImage: "book.closed"),
        NonNovelQATemplate(id: "reader", priority: .p1, title: L10n.qaReader, requirement: L10n.qaReaderRequirement, nextAction: L10n.qaReaderNext, systemImage: "rectangle.portrait.on.rectangle.portrait"),
        NonNovelQATemplate(id: "search", priority: .p1, title: L10n.qaSearch, requirement: L10n.qaSearchRequirement, nextAction: L10n.qaSearchNext, systemImage: "magnifyingglass"),
        NonNovelQATemplate(id: "bookmarks", priority: .p1, title: L10n.qaBookmarks, requirement: L10n.qaBookmarksRequirement, nextAction: L10n.qaBookmarksNext, systemImage: "bookmark"),
        NonNovelQATemplate(id: "following-creators", priority: .p1, title: L10n.qaFollowingCreators, requirement: L10n.qaFollowingCreatorsRequirement, nextAction: L10n.qaFollowingCreatorsNext, systemImage: "person.2"),
        NonNovelQATemplate(id: "downloads", priority: .p1, title: L10n.qaDownloads, requirement: L10n.qaDownloadsRequirement, nextAction: L10n.qaDownloadsNext, systemImage: "arrow.down.circle"),
        NonNovelQATemplate(id: "safety-filtering", priority: .p1, title: L10n.qaSafetyFiltering, requirement: L10n.qaSafetyFilteringRequirement, nextAction: L10n.qaSafetyFilteringNext, systemImage: "eye.slash"),
        NonNovelQATemplate(id: "illust-feeds", priority: .p2, title: L10n.qaIllustFeeds, requirement: L10n.qaIllustFeedsRequirement, nextAction: L10n.qaIllustFeedsNext, systemImage: "photo.on.rectangle"),
        NonNovelQATemplate(id: "ranking", priority: .p2, title: L10n.qaRanking, requirement: L10n.qaRankingRequirement, nextAction: L10n.qaRankingNext, systemImage: "chart.bar"),
        NonNovelQATemplate(id: "following-feed", priority: .p2, title: L10n.qaFollowingFeed, requirement: L10n.qaFollowingFeedRequirement, nextAction: L10n.qaFollowingFeedNext, systemImage: "person.2.wave.2"),
        NonNovelQATemplate(id: "creator-discovery", priority: .p2, title: L10n.qaCreatorDiscovery, requirement: L10n.qaCreatorDiscoveryRequirement, nextAction: L10n.qaCreatorDiscoveryNext, systemImage: "person.crop.circle.badge.plus"),
        NonNovelQATemplate(id: "artwork-detail-social", priority: .p2, title: L10n.qaArtworkDetailSocial, requirement: L10n.qaArtworkDetailSocialRequirement, nextAction: L10n.qaArtworkDetailSocialNext, systemImage: "sidebar.right"),
        NonNovelQATemplate(id: "comments-feedback", priority: .p2, title: L10n.qaCommentsFeedback, requirement: L10n.qaCommentsFeedbackRequirement, nextAction: L10n.qaCommentsFeedbackNext, systemImage: "text.bubble"),
        NonNovelQATemplate(id: "local-cache-offline", priority: .p2, title: L10n.qaLocalCacheOffline, requirement: L10n.qaLocalCacheOfflineRequirement, nextAction: L10n.qaLocalCacheOfflineNext, systemImage: "externaldrive"),
        NonNovelQATemplate(id: "ugoira", priority: .p2, title: L10n.ugoira, requirement: L10n.qaUgoiraRequirement, nextAction: L10n.qaUgoiraNext, systemImage: "play.rectangle"),
        NonNovelQATemplate(id: "settings-organization", priority: .p2, title: L10n.qaSettingsOrganization, requirement: L10n.qaSettingsOrganizationRequirement, nextAction: L10n.qaSettingsOrganizationNext, systemImage: "gearshape"),
        NonNovelQATemplate(id: "sharing-copy", priority: .p2, title: L10n.sharing, requirement: L10n.copyTemplateHint, nextAction: L10n.qaSettingsOrganizationNext, systemImage: "square.and.arrow.up"),
        NonNovelQATemplate(id: "image-quality-tier", priority: .p1, title: L10n.qaImageQualityTier, requirement: L10n.qaImageQualityTierRequirement, nextAction: L10n.qaImageQualityTierNext, systemImage: "photo.stack"),
        NonNovelQATemplate(id: "caption-translation", priority: .p1, title: L10n.qaCaptionTranslation, requirement: L10n.qaCaptionTranslationRequirement, nextAction: L10n.qaCaptionTranslationNext, systemImage: "character.bubble"),
        NonNovelQATemplate(id: "following-emphasis", priority: .p2, title: L10n.qaFollowingEmphasis, requirement: L10n.qaFollowingEmphasisRequirement, nextAction: L10n.qaFollowingEmphasisNext, systemImage: "checkmark.seal"),
        NonNovelQATemplate(id: "transferable-drag-drop", priority: .p2, title: L10n.qaTransferableDragDrop, requirement: L10n.qaTransferableDragDropRequirement, nextAction: L10n.qaTransferableDragDropNext, systemImage: "square.and.arrow.up.on.square"),
        NonNovelQATemplate(id: "quick-look", priority: .p2, title: L10n.qaQuickLook, requirement: L10n.qaQuickLookRequirement, nextAction: L10n.qaQuickLookNext, systemImage: "eye"),
        NonNovelQATemplate(
            id: "download-throughput",
            priority: .p2,
            title: L10n.qaDownloadThroughput,
            requirement: L10n.qaDownloadThroughputRequirement,
            nextAction: L10n.qaDownloadThroughputNext,
            systemImage: "speedometer"
        ),
        NonNovelQATemplate(
            id: "download-finish-notification",
            priority: .p2,
            title: L10n.qaDownloadFinishNotification,
            requirement: L10n.qaDownloadFinishNotificationRequirement,
            nextAction: L10n.qaDownloadFinishNotificationNext,
            systemImage: "bell.badge"
        ),
        NonNovelQATemplate(
            id: "proxy-configuration",
            priority: .p2,
            title: L10n.qaProxyConfiguration,
            requirement: L10n.qaProxyConfigurationRequirement,
            nextAction: L10n.qaProxyConfigurationNext,
            systemImage: "network.badge.shield.half.filled"
        ),
        NonNovelQATemplate(
            id: "release-update-check",
            priority: .p2,
            title: L10n.qaReleaseUpdateCheck,
            requirement: L10n.qaReleaseUpdateCheckRequirement,
            nextAction: L10n.qaReleaseUpdateCheckNext,
            systemImage: "arrow.down.circle.dotted"
        )
    ]
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var visibleLineCount: Int {
        split(separator: "\n", omittingEmptySubsequences: true).count
    }
}
