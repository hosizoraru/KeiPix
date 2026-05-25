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
            count: { try await self.recommendedUsers().userPreviews.count }
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
        let pixivLinkDropSurfaces: [VisualQASurface] = [.pixivLinkDrop]
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
            }
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
        let safetySurfaces: [VisualQASurface] = [.mutedContent]
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
            passed: visualEvidence.covers([.settingsWindow]),
            evidence: visualEvidence.summary(for: [.settingsWindow])
        )
        return [gallery, downloads, safety, offline, ugoira, settings]
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
        NonNovelQATemplate(id: "settings-organization", priority: .p2, title: L10n.qaSettingsOrganization, requirement: L10n.qaSettingsOrganizationRequirement, nextAction: L10n.qaSettingsOrganizationNext, systemImage: "gearshape")
    ]
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
