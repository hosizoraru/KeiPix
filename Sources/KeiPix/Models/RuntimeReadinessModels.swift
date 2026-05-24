import Foundation
import CFNetwork

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

    func imageCacheStatus() async -> ImageCacheStatus {
        await ImagePipeline.shared.cacheStatus()
    }

    func clearImageCache() async -> ImageCacheStatus {
        await ImagePipeline.shared.clearCaches()
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
            routeReadinessRow,
            feedReadinessRow,
            selectionReadinessRow,
            downloadReadinessRow,
            proxyReadinessRow,
            filterReadinessRow,
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
