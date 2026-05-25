import Foundation

@MainActor
extension KeiPixStore {
    func runNonNovelQAMatrix() async -> NonNovelQAMatrixSnapshot {
        let checkedAt = Date()
        guard session != nil else {
            return NonNovelQAMatrixSnapshot(
                checkedAt: checkedAt,
                items: Self.nonNovelQABaseline.map {
                    $0.item(status: .skipped, evidence: L10n.signedOut, nextAction: L10n.signInAndRunQA)
                }
            )
        }

        async let feeds = qaFeedSurfaces()
        async let discovery = qaDiscoverySurfaces()
        async let account = qaAccountSurfaces()
        async let search = qaSearchSurfaces()
        async let selected = qaSelectedArtworkSurfaces()
        async let local = qaLocalSurfaces()

        let groups = await [feeds, discovery, account, search, selected, local]
        return NonNovelQAMatrixSnapshot(checkedAt: checkedAt, items: groups.flatMap { $0 })
    }

    static var nonNovelQABaselineItems: [NonNovelQAItem] {
        nonNovelQABaseline.map {
            $0.item(status: .needsEvidence, evidence: L10n.notRun, nextAction: $0.nextAction)
        }
    }

    private func qaFeedSurfaces() async -> [NonNovelQAItem] {
        async let recommended = qaFeedItem(
            id: "illust-feeds",
            count: { try await self.api.recommendedIllusts().illusts.count }
        )
        async let manga = qaFeedItem(
            id: "manga-feeds",
            count: { try await self.api.recommendedMangas().illusts.count }
        )
        async let ranking = qaFeedItem(
            id: "ranking",
            count: { try await self.api.ranking(mode: "day").illusts.count }
        )
        async let following = qaFeedItem(
            id: "following-feed",
            count: { try await self.api.following(restrict: "public").illusts.count }
        )
        return await [recommended, manga, ranking, following]
    }

    private func qaDiscoverySurfaces() async -> [NonNovelQAItem] {
        async let trending = qaFeedItem(
            id: "trending-tags",
            count: { try await self.trendingTags().count }
        )
        async let spotlight = qaFeedItem(
            id: "pixivision",
            count: { try await self.spotlightArticles().articles.count }
        )
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
            count: { try await self.api.bookmarks(restrict: "public", userID: rawUserID).illusts.count }
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
        async let urlResolver = qaStaticItem(
            id: "pixiv-url-routing",
            passed: PixivWebLinkResolver.destination(from: URL(string: "https://www.pixiv.net/artworks/123")!) == .artwork(123)
                && PixivWebLinkResolver.destination(from: URL(string: "https://www.pixiv.net/tags/OC")!) == .tag("OC")
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
            passed: selectedArtwork.images.isEmpty == false && selectedArtwork.pageCount > 0,
            evidence: String(format: L10n.pageCountFormat, selectedArtwork.pageCount)
        )
        return await [reader, detail, comments]
    }

    private func qaLocalSurfaces() async -> [NonNovelQAItem] {
        let gallery = qaStaticItem(
            id: "gallery-visual",
            passed: galleryLayoutMode != .compactGrid || artworks.isEmpty == false,
            evidence: "\(galleryLayoutMode.title) · \(artworks.count.formatted())"
        )
        let downloads = qaStaticItem(
            id: "downloads",
            passed: true,
            evidence: String(
                format: L10n.downloadReadinessFormat,
                self.downloads.items.count,
                self.downloads.activeCount,
                self.downloads.completedCount
            )
        )
        let safety = qaStaticItem(
            id: "safety-filtering",
            passed: true,
            evidence: [
                hideAIArtworks ? L10n.aiGenerated : nil,
                hideR18Artworks ? L10n.r18 : nil,
                hideR18GArtworks ? L10n.r18g : nil,
                maskSensitivePreviews ? L10n.maskSensitivePreviews : nil,
                hideMutedContent ? L10n.muted : nil
            ].compactMap(\.self).joined(separator: " · ").nilIfEmpty ?? L10n.availableInDiagnostics
        )
        let cache = await imageCacheStatus()
        let offline = qaStaticItem(
            id: "local-cache-offline",
            passed: cache.diskCapacity > 0,
            evidence: cache.summaryText
        )
        let settings = qaStaticItem(
            id: "settings-organization",
            passed: true,
            evidence: L10n.availableInDiagnostics
        )
        return [gallery, downloads, safety, offline, settings]
    }

    private func qaFeedItem(
        id: String,
        count: @escaping @Sendable () async throws -> Int
    ) async -> NonNovelQAItem {
        guard let template = Self.nonNovelQABaseline.first(where: { $0.id == id }) else {
            return NonNovelQATemplate.unknown(id: id).item(status: .actionRequired, evidence: L10n.unknown, nextAction: L10n.reviewImplementation)
        }

        do {
            let value = try await count()
            let status: NonNovelQAStatus = value > 0 ? .passed : .needsEvidence
            let nextAction = value > 0 ? L10n.keepRegressionCoverage : template.nextAction
            return template.item(
                status: status,
                evidence: String(format: L10n.qaLoadedCountFormat, value),
                nextAction: nextAction
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
        NonNovelQATemplate(id: "settings-organization", priority: .p2, title: L10n.qaSettingsOrganization, requirement: L10n.qaSettingsOrganizationRequirement, nextAction: L10n.qaSettingsOrganizationNext, systemImage: "gearshape")
    ]
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
