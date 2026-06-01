import Foundation
#if os(macOS)
import CFNetwork
#endif

struct RuntimeReadinessRow: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    let isReady: Bool?
}

struct RuntimeReadinessSnapshot: Hashable {
    let checkedAt: Date
    let rows: [RuntimeReadinessRow]
    let mutableActionItems: [MutableActionQAItem]
    let diagnosticsText: String

    var mutableActionChecklistText: String {
        MutableActionQAItem.checklistText(for: mutableActionItems)
    }
}

enum MutableActionQAStatus: String, CaseIterable, Hashable {
    case verified
    case needsTestAccount
    case needsExplicitApproval

    var title: String {
        switch self {
        case .verified:
            L10n.verified
        case .needsTestAccount:
            L10n.needsTestAccount
        case .needsExplicitApproval:
            L10n.needsExplicitApproval
        }
    }

    var systemImage: String {
        switch self {
        case .verified:
            "checkmark.circle"
        case .needsTestAccount:
            "person.crop.circle.badge.questionmark"
        case .needsExplicitApproval:
            "hand.raised.circle"
        }
    }
}

struct MutableActionQAItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let status: MutableActionQAStatus
    let systemImage: String

    var checklistLine: String {
        "- [\(status.title)] \(title): \(detail)"
    }

    static func checklistText(for items: [MutableActionQAItem]) -> String {
        var lines = [
            "KeiPix Mutable Action QA Checklist",
            ""
        ]
        lines += items.map(\.checklistLine)
        return lines.joined(separator: "\n")
    }
}

@MainActor
extension KeiPixStore {
    var systemProxySummary: String {
        #if os(macOS)
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return L10n.unknown
        }

        let httpEnabled = (settings[kCFNetworkProxiesHTTPEnable as String] as? NSNumber)?.boolValue == true
        let httpsEnabled = (settings["HTTPSEnable"] as? NSNumber)?.boolValue == true
        let socksEnabled = (settings[kCFNetworkProxiesSOCKSEnable as String] as? NSNumber)?.boolValue == true
        let autoConfig = (settings[kCFNetworkProxiesProxyAutoConfigEnable as String] as? NSNumber)?.boolValue == true
        let autoDiscovery = (settings[kCFNetworkProxiesProxyAutoDiscoveryEnable as String] as? NSNumber)?.boolValue == true

        var values: [String] = []
        if httpEnabled {
            values.append(proxyDescription(label: "HTTP", hostKey: kCFNetworkProxiesHTTPProxy as String, portKey: kCFNetworkProxiesHTTPPort as String, settings: settings))
        }
        if httpsEnabled {
            values.append(proxyDescription(label: "HTTPS", hostKey: "HTTPSProxy", portKey: "HTTPSPort", settings: settings))
        }
        if socksEnabled {
            values.append(proxyDescription(label: "SOCKS", hostKey: kCFNetworkProxiesSOCKSProxy as String, portKey: kCFNetworkProxiesSOCKSPort as String, settings: settings))
        }
        if autoConfig {
            values.append("PAC")
        }
        if autoDiscovery {
            values.append("WPAD")
        }
        return values.isEmpty ? L10n.directConnection : values.joined(separator: " · ")
        #else
        return L10n.unknown
        #endif
    }

    func runNetworkDiagnostics() async -> [NetworkDiagnosticResult] {
        let proxyResult = NetworkDiagnosticResult(
            id: "proxy",
            title: L10n.systemProxy,
            status: .passed,
            detail: systemProxySummary,
            duration: nil
        )
        let apiResult = await pixivAPIDiagnostic()
        let imageResult = await imageHostDiagnostic()
        return [proxyResult, apiResult, imageResult]
    }

    func runAccountHealthDiagnostics() async -> [NetworkDiagnosticResult] {
        guard session != nil else {
            return [
                NetworkDiagnosticResult(
                    id: "account-token-refresh",
                    title: L10n.accountTokenRefresh,
                    status: .skipped,
                    detail: L10n.signedOut,
                    duration: nil
                )
            ]
        }

        let startedAt = Date()
        do {
            let refreshedSession = try await api.refreshCurrentSession()
            session = refreshedSession
            storedAccounts = try await api.storedAccounts()
            return [
                NetworkDiagnosticResult(
                    id: "account-token-refresh",
                    title: L10n.accountTokenRefresh,
                    status: .passed,
                    detail: storeAccountHealthDetail(for: refreshedSession),
                    duration: Date().timeIntervalSince(startedAt)
                )
            ]
        } catch {
            return [
                NetworkDiagnosticResult(
                    id: "account-token-refresh",
                    title: L10n.accountTokenRefresh,
                    status: .failed,
                    detail: error.localizedDescription,
                    duration: Date().timeIntervalSince(startedAt)
                )
            ]
        }
    }

    func runSearchDiagnostics() async -> [NetworkDiagnosticResult] {
        guard session != nil else {
            return SearchDiagnosticProbe.defaultProbes.map { probe in
                NetworkDiagnosticResult(
                    id: "search-\(probe.id)",
                    title: "\(L10n.search) · \(probe.title)",
                    status: .skipped,
                    detail: L10n.signedOut,
                    duration: nil
                )
            }
        }

        var results: [NetworkDiagnosticResult] = []
        for probe in SearchDiagnosticProbe.defaultProbes {
            if probe.options.sort.requiresPixivPremium, session?.user.isPremium != true {
                results.append(NetworkDiagnosticResult(
                    id: "search-\(probe.id)",
                    title: "\(L10n.search) · \(probe.title)",
                    status: .skipped,
                    detail: L10n.pixivPremiumRequired,
                    duration: nil
                ))
                continue
            }

            let startedAt = Date()
            do {
                let response = try await api.search(keyword: probe.keyword, options: probe.options)
                results.append(NetworkDiagnosticResult(
                    id: "search-\(probe.id)",
                    title: "\(L10n.search) · \(probe.title)",
                    status: .passed,
                    detail: String(format: L10n.searchDiagnosticResultFormat, response.illusts.count, probe.keyword),
                    duration: Date().timeIntervalSince(startedAt)
                ))
            } catch {
                results.append(NetworkDiagnosticResult(
                    id: "search-\(probe.id)",
                    title: "\(L10n.search) · \(probe.title)",
                    status: .failed,
                    detail: error.localizedDescription,
                    duration: Date().timeIntervalSince(startedAt)
                ))
            }
        }
        return results
    }

    func runReversibleMutableActionQA() async -> [NetworkDiagnosticResult] {
        guard session != nil else {
            return reversibleMutableActionSkippedResults(detail: L10n.signedOut)
        }

        guard let selectedArtwork else {
            return reversibleMutableActionSkippedResults(detail: L10n.noSelection)
        }

        async let bookmarkResult = runReversibleBookmarkQA(artwork: selectedArtwork)
        async let followResult = runReversibleFollowQA(user: selectedArtwork.user)
        return await [bookmarkResult, followResult]
    }

    func runDirectNavigationDiagnostics() async -> [NetworkDiagnosticResult] {
        guard session != nil else {
            return directNavigationSkippedResults(detail: L10n.signedOut)
        }

        guard let selectedArtwork else {
            return directNavigationSkippedResults(detail: L10n.noSelection)
        }

        async let artworkResult = runArtworkIDNavigationDiagnostic(id: selectedArtwork.id)
        async let creatorResult = runCreatorIDNavigationDiagnostic(id: selectedArtwork.user.id)
        return await [artworkResult, creatorResult]
    }

    func runCommentFeedbackDiagnostics() async -> [NetworkDiagnosticResult] {
        guard session != nil else {
            return [
                NetworkDiagnosticResult(
                    id: "comment-feedback",
                    title: L10n.commentFeedbackDiagnostic,
                    status: .skipped,
                    detail: L10n.signedOut,
                    duration: nil
                )
            ]
        }

        guard let selectedArtwork else {
            return [
                NetworkDiagnosticResult(
                    id: "comment-feedback",
                    title: L10n.commentFeedbackDiagnostic,
                    status: .skipped,
                    detail: L10n.noSelection,
                    duration: nil
                )
            ]
        }

        let startedAt = Date()
        do {
            let response = try await api.illustComments(illustID: selectedArtwork.id)
            guard let comment = response.comments.first else {
                return [
                    NetworkDiagnosticResult(
                        id: "comment-feedback",
                        title: L10n.commentFeedbackDiagnostic,
                        status: .skipped,
                        detail: L10n.noComments,
                        duration: Date().timeIntervalSince(startedAt)
                    )
                ]
            }

            let request = FeedbackReportRequest.comment(comment, artwork: selectedArtwork)
            let summary = request.summary(reason: .other, note: "")
            let passed = summary.contains(request.targetTitle) && request.targetURL != nil
            return [
                NetworkDiagnosticResult(
                    id: "comment-feedback",
                    title: L10n.commentFeedbackDiagnostic,
                    status: passed ? .passed : .failed,
                    detail: passed ? String(format: L10n.commentFeedbackReadyFormat, comment.id) : L10n.unsupportedPixivLink,
                    duration: Date().timeIntervalSince(startedAt)
                )
            ]
        } catch {
            return [
                NetworkDiagnosticResult(
                    id: "comment-feedback",
                    title: L10n.commentFeedbackDiagnostic,
                    status: .failed,
                    detail: error.localizedDescription,
                    duration: Date().timeIntervalSince(startedAt)
                )
            ]
        }
    }

    func commentFeedbackPreviewRequest() async throws -> FeedbackReportRequest {
        guard session != nil else { throw PixivAPIError.serverMessage(L10n.signedOut) }
        guard let selectedArtwork else { throw PixivAPIError.serverMessage(L10n.noSelection) }

        let response = try await api.illustComments(illustID: selectedArtwork.id)
        guard let comment = response.comments.first else {
            throw PixivAPIError.serverMessage(L10n.noComments)
        }
        return FeedbackReportRequest.comment(comment, artwork: selectedArtwork)
    }

    func imageCacheStatus() async -> ImageCacheStatus {
        ImagePipeline.shared.cacheStatus()
    }

    func clearImageCache() async -> ImageCacheStatus {
        ImagePipeline.shared.clearCaches()
    }

    var runtimeReadinessSnapshot: RuntimeReadinessSnapshot {
        let checkedAt = Date()
        let rows = runtimeReadinessRows
        let mutableActionItems = mutableActionQAItems
        return RuntimeReadinessSnapshot(
            checkedAt: checkedAt,
            rows: rows,
            mutableActionItems: mutableActionItems,
            diagnosticsText: runtimeReadinessDiagnosticsText(
                checkedAt: checkedAt,
                rows: rows,
                mutableActionItems: mutableActionItems
            )
        )
    }

    func copyRuntimeReadinessDiagnostics() {
        PasteboardWriter.copy(runtimeReadinessSnapshot.diagnosticsText)
    }

    private var runtimeReadinessRows: [RuntimeReadinessRow] {
        [
            sessionReadinessRow,
            accountHealthReadinessRow,
            routeReadinessRow,
            feedReadinessRow,
            selectionReadinessRow,
            downloadReadinessRow,
            proxyReadinessRow,
            filterReadinessRow,
            aiVisibilityReadinessRow,
            mutedReadinessRow,
            privacyReadinessRow,
            trackpadReadinessRow
        ]
    }

    var mutableActionQAItems: [MutableActionQAItem] {
        [
            MutableActionQAItem(
                id: "download-queue",
                title: L10n.qaDownloadQueue,
                detail: L10n.qaDownloadQueueDetail,
                status: .verified,
                systemImage: "arrow.down.circle"
            ),
            MutableActionQAItem(
                id: "follow-toggle",
                title: L10n.qaFollowToggle,
                detail: L10n.qaFollowToggleDetail,
                status: .needsTestAccount,
                systemImage: "person.crop.circle.badge.plus"
            ),
            MutableActionQAItem(
                id: "bookmark-toggle",
                title: L10n.qaBookmarkToggle,
                detail: L10n.qaBookmarkToggleDetail,
                status: .needsTestAccount,
                systemImage: "bookmark"
            ),
            MutableActionQAItem(
                id: "comment-post",
                title: L10n.qaCommentPost,
                detail: L10n.qaCommentPostDetail,
                status: .needsExplicitApproval,
                systemImage: "text.bubble"
            ),
            MutableActionQAItem(
                id: "download-delete",
                title: L10n.qaDownloadDelete,
                detail: L10n.qaDownloadDeleteDetail,
                status: .needsExplicitApproval,
                systemImage: "trash"
            ),
            MutableActionQAItem(
                id: "mute-sync",
                title: L10n.qaMuteSync,
                detail: L10n.qaMuteSyncDetail,
                status: .needsExplicitApproval,
                systemImage: "eye.slash"
            )
        ]
    }

    private var sessionReadinessRow: RuntimeReadinessRow {
        let value: String
        if let session {
            value = showsSidebarAccountIdentity ? "#\(session.user.id)" : L10n.hidden
        } else {
            value = L10n.signedOut
        }

        return RuntimeReadinessRow(
            id: "session",
            title: L10n.session,
            value: session == nil ? value : "\(L10n.signedIn) · \(value)",
            systemImage: "person.crop.circle.badge.checkmark",
            isReady: session != nil
        )
    }

    private var accountHealthReadinessRow: RuntimeReadinessRow {
        let value: String
        if let session {
            value = storeAccountHealthDetail(for: session)
        } else {
            value = L10n.signedOut
        }

        return RuntimeReadinessRow(
            id: "account-health",
            title: L10n.qaAccountHealth,
            value: value,
            systemImage: "person.crop.circle.badge.checkmark",
            isReady: session != nil
        )
    }

    private var routeReadinessRow: RuntimeReadinessRow {
        RuntimeReadinessRow(
            id: "route",
            title: L10n.currentRoute,
            value: selectedRoute.title,
            systemImage: selectedRoute.systemImage,
            isReady: selectedRoute.usesArtworkFeed ? session != nil : true
        )
    }

    private var feedReadinessRow: RuntimeReadinessRow {
        let value = String(
            format: L10n.feedReadinessFormat,
            artworks.count,
            allArtworks.count,
            hasNextPage ? L10n.nextPageAvailable : L10n.noMorePages
        )
        return RuntimeReadinessRow(
            id: "feed",
            title: L10n.feed,
            value: value,
            systemImage: "photo.stack",
            isReady: selectedRoute.usesArtworkFeed ? artworks.isEmpty == false : true
        )
    }

    private var selectionReadinessRow: RuntimeReadinessRow {
        let value: String
        if let selectedArtwork {
            value = "#\(selectedArtwork.id) · \(String(format: L10n.pageCountFormat, selectedArtwork.pageCount))"
        } else {
            value = L10n.noSelection
        }

        return RuntimeReadinessRow(
            id: "selection",
            title: L10n.selectedArtwork,
            value: value,
            systemImage: "cursorarrow.rays",
            isReady: selectedRoute.usesArtworkFeed ? selectedArtwork != nil : nil
        )
    }

    private var downloadReadinessRow: RuntimeReadinessRow {
        let value = String(
            format: L10n.downloadReadinessFormat,
            downloads.items.count,
            downloads.activeCount,
            downloads.completedCount
        )
        return RuntimeReadinessRow(
            id: "downloads",
            title: L10n.downloads,
            value: value,
            systemImage: "arrow.down.circle",
            isReady: true
        )
    }

    private var proxyReadinessRow: RuntimeReadinessRow {
        RuntimeReadinessRow(
            id: "proxy",
            title: L10n.systemProxy,
            value: systemProxySummary,
            systemImage: "network",
            isReady: true
        )
    }

    private var filterReadinessRow: RuntimeReadinessRow {
        let activeFilters = [
            hideMutedContent ? L10n.muted : nil,
            hideAIArtworks ? L10n.aiGenerated : nil,
            hideR18Artworks ? L10n.r18 : nil,
            hideR18GArtworks ? L10n.r18g : nil
        ].compactMap(\.self)

        return RuntimeReadinessRow(
            id: "filters",
            title: L10n.contentFilters,
            value: activeFilters.isEmpty ? L10n.allAges : activeFilters.joined(separator: " · "),
            systemImage: "line.3.horizontal.decrease.circle",
            isReady: true
        )
    }

    private var aiVisibilityReadinessRow: RuntimeReadinessRow {
        let value = hideAIArtworks
            ? L10n.aiVisibilityLocalHidden
            : L10n.aiVisibilityLocalVisible
        return RuntimeReadinessRow(
            id: "ai-visibility",
            title: L10n.pixivAIDisplay,
            value: value,
            systemImage: "sparkles",
            isReady: true
        )
    }

    private var mutedReadinessRow: RuntimeReadinessRow {
        RuntimeReadinessRow(
            id: "muted",
            title: L10n.mutedContent,
            value: String(
                format: L10n.mutedContentCountFormat,
                mutedTags.count + mutedUsers.count + mutedArtworks.count + mutedCommentPhrases.count
            ),
            systemImage: "eye.slash",
            isReady: true
        )
    }

    private var privacyReadinessRow: RuntimeReadinessRow {
        let values = [
            privacyModeEnabled ? L10n.privacyMode : nil,
            showAccountIdentity ? nil : L10n.accountIdentityHidden,
            screenCaptureProtectionEnabled ? L10n.screenProtection : nil
        ].compactMap(\.self)

        return RuntimeReadinessRow(
            id: "privacy",
            title: L10n.privacy,
            value: values.isEmpty ? L10n.disabled : values.joined(separator: " · "),
            systemImage: "hand.raised",
            isReady: true
        )
    }

    private var trackpadReadinessRow: RuntimeReadinessRow {
        let value = trackpadGesturesEnabled
            ? "\(L10n.enabled) · \(horizontalSwipeBehavior.title)"
            : L10n.disabled
        return RuntimeReadinessRow(
            id: "trackpad",
            title: L10n.trackpad,
            value: value,
            systemImage: "rectangle.and.hand.point.up.left",
            isReady: trackpadGesturesEnabled
        )
    }

    private func runtimeReadinessDiagnosticsText(
        checkedAt: Date,
        rows: [RuntimeReadinessRow],
        mutableActionItems: [MutableActionQAItem]
    ) -> String {
        var lines = [
            "KeiPix Runtime Readiness",
            "Checked: \(Self.runtimeReadinessDateFormatter.string(from: checkedAt))",
            "Native: Swift + SwiftUI + AppKit bridges",
            ""
        ]
        lines += rows.map { "\($0.title): \($0.value)" }
        lines += [
            "",
            "Mutable Action QA"
        ]
        lines += mutableActionItems.map(\.checklistLine)
        lines += [
            "",
            "Downloads: \(downloads.downloadDirectoryPath)",
            "System Proxy: \(systemProxySummary)"
        ]
        return lines.joined(separator: "\n")
    }

    private func storeAccountHealthDetail(for session: PixivSession) -> String {
        let identity = showAccountIdentity ? "@\(session.user.account)" : L10n.hidden
        return "\(L10n.savedSession) · \(identity)"
    }

    private func pixivAPIDiagnostic() async -> NetworkDiagnosticResult {
        guard let rawUserID = session?.user.id, let userID = Int(rawUserID) else {
            return NetworkDiagnosticResult(
                id: "pixiv-api",
                title: L10n.pixivAPI,
                status: .skipped,
                detail: L10n.signedOut,
                duration: nil
            )
        }

        let startedAt = Date()
        do {
            _ = try await api.userDetail(userID: userID)
            return NetworkDiagnosticResult(
                id: "pixiv-api",
                title: L10n.pixivAPI,
                status: .passed,
                detail: L10n.reachable,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return NetworkDiagnosticResult(
                id: "pixiv-api",
                title: L10n.pixivAPI,
                status: .failed,
                detail: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func imageHostDiagnostic() async -> NetworkDiagnosticResult {
        guard let url = selectedArtwork?.thumbnailURL ?? artworks.first?.thumbnailURL ?? allArtworks.first?.thumbnailURL else {
            return NetworkDiagnosticResult(
                id: "image-host",
                title: L10n.imageHost,
                status: .skipped,
                detail: L10n.noArtworkForImageProbe,
                duration: nil
            )
        }

        let startedAt = Date()
        do {
            _ = try await ImagePipeline.shared.data(for: url)
            return NetworkDiagnosticResult(
                id: "image-host",
                title: L10n.imageHost,
                status: .passed,
                detail: url.host(percentEncoded: false) ?? L10n.reachable,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return NetworkDiagnosticResult(
                id: "image-host",
                title: L10n.imageHost,
                status: .failed,
                detail: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func runReversibleBookmarkQA(artwork: PixivArtwork) async -> NetworkDiagnosticResult {
        guard artwork.isBookmarked == false else {
            return NetworkDiagnosticResult(
                id: "mutable-bookmark",
                title: L10n.qaBookmarkToggle,
                status: .skipped,
                detail: L10n.selectUnbookmarkedArtworkForQA,
                duration: nil
            )
        }

        let startedAt = Date()
        do {
            try await api.addBookmark(illustID: artwork.id, restrict: .private, tags: [])
            do {
                try await api.deleteBookmark(illustID: artwork.id)
            } catch {
                updateArtwork(artwork.id) { $0.isBookmarked = true }
                throw error
            }
            updateArtwork(artwork.id) { $0.isBookmarked = false }
            return NetworkDiagnosticResult(
                id: "mutable-bookmark",
                title: L10n.qaBookmarkToggle,
                status: .passed,
                detail: L10n.privateBookmarkRoundTripCompleted,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return NetworkDiagnosticResult(
                id: "mutable-bookmark",
                title: L10n.qaBookmarkToggle,
                status: .failed,
                detail: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func runArtworkIDNavigationDiagnostic(id: Int) async -> NetworkDiagnosticResult {
        let startedAt = Date()
        do {
            let artwork = try await api.illustDetail(illustID: id)
            return NetworkDiagnosticResult(
                id: "direct-artwork-id",
                title: L10n.artworkID,
                status: artwork.id == id ? .passed : .failed,
                detail: artwork.id == id ? String(format: L10n.openedPixivIDFormat, L10n.artworkID, id) : L10n.invalidResponse,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return NetworkDiagnosticResult(
                id: "direct-artwork-id",
                title: L10n.artworkID,
                status: .failed,
                detail: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func runCreatorIDNavigationDiagnostic(id: Int) async -> NetworkDiagnosticResult {
        let startedAt = Date()
        do {
            let detail = try await api.userDetail(userID: id)
            return NetworkDiagnosticResult(
                id: "direct-creator-id",
                title: L10n.creatorID,
                status: detail.user.id == id ? .passed : .failed,
                detail: detail.user.id == id ? String(format: L10n.openedPixivIDFormat, L10n.creatorID, id) : L10n.invalidResponse,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return NetworkDiagnosticResult(
                id: "direct-creator-id",
                title: L10n.creatorID,
                status: .failed,
                detail: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func runReversibleFollowQA(user: PixivUser) async -> NetworkDiagnosticResult {
        guard user.isFollowed == false else {
            return NetworkDiagnosticResult(
                id: "mutable-follow",
                title: L10n.qaFollowToggle,
                status: .skipped,
                detail: L10n.selectUnfollowedCreatorForQA,
                duration: nil
            )
        }

        let startedAt = Date()
        do {
            try await api.setFollow(userID: user.id, isFollowed: true, restrict: .private)
            do {
                try await api.setFollow(userID: user.id, isFollowed: false)
            } catch {
                updateFollowState(userID: user.id, isFollowed: true)
                throw error
            }
            updateFollowState(userID: user.id, isFollowed: false)
            return NetworkDiagnosticResult(
                id: "mutable-follow",
                title: L10n.qaFollowToggle,
                status: .passed,
                detail: L10n.privateFollowRoundTripCompleted,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return NetworkDiagnosticResult(
                id: "mutable-follow",
                title: L10n.qaFollowToggle,
                status: .failed,
                detail: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func reversibleMutableActionSkippedResults(detail: String) -> [NetworkDiagnosticResult] {
        [
            NetworkDiagnosticResult(
                id: "mutable-bookmark",
                title: L10n.qaBookmarkToggle,
                status: .skipped,
                detail: detail,
                duration: nil
            ),
            NetworkDiagnosticResult(
                id: "mutable-follow",
                title: L10n.qaFollowToggle,
                status: .skipped,
                detail: detail,
                duration: nil
            )
        ]
    }

    private func directNavigationSkippedResults(detail: String) -> [NetworkDiagnosticResult] {
        [
            NetworkDiagnosticResult(
                id: "direct-artwork-id",
                title: L10n.artworkID,
                status: .skipped,
                detail: detail,
                duration: nil
            ),
            NetworkDiagnosticResult(
                id: "direct-creator-id",
                title: L10n.creatorID,
                status: .skipped,
                detail: detail,
                duration: nil
            )
        ]
    }

    private func proxyDescription(label: String, hostKey: String, portKey: String, settings: [String: Any]) -> String {
        let host = settings[hostKey] as? String ?? "?"
        if let port = settings[portKey] {
            return "\(label) \(host):\(port)"
        }
        return "\(label) \(host)"
    }

    private static let runtimeReadinessDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
