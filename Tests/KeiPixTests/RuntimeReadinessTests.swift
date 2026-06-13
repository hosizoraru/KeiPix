import Foundation
import Testing
@testable import KeiPix

@Suite("Runtime readiness")
struct RuntimeReadinessTests {
    @Test("Mutable action statuses expose QA labels")
    func mutableActionStatusLabels() {
        #expect(MutableActionQAStatus.verified.title == L10n.verified)
        #expect(MutableActionQAStatus.needsTestAccount.systemImage == "person.crop.circle.badge.questionmark")
        #expect(MutableActionQAStatus.needsExplicitApproval.title == L10n.needsExplicitApproval)
    }

    @Test("Mutable action checklist includes status and details")
    func mutableActionChecklistText() {
        let items = [
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
            )
        ]

        let checklist = MutableActionQAItem.checklistText(for: items)

        #expect(checklist.contains("KeiPix Mutable Action QA Checklist"))
        #expect(checklist.contains(L10n.needsTestAccount))
        #expect(checklist.contains(L10n.qaBookmarkToggle))
        #expect(checklist.contains(L10n.needsExplicitApproval))
        #expect(checklist.contains(L10n.qaCommentPostDetail))
    }

    @Test("Mutable action QA authorization requires exact test-account phrase")
    func mutableActionQAAuthorizationPhrase() {
        #expect(MutableActionQAAuthorization.isAuthorized("TEST ACCOUNT"))
        #expect(MutableActionQAAuthorization.isAuthorized(" TEST ACCOUNT "))
        #expect(MutableActionQAAuthorization.isAuthorized("test account") == false)
        #expect(MutableActionQAAuthorization.isAuthorized("") == false)
    }

    @Test("Mute sync diagnostics compare remote and local read-only state")
    func muteSyncDiagnosticsSummary() {
        let summary = MuteSyncDiagnosticSummary(
            localTags: ["cat", "Landscape", "local-only"],
            localUsers: [10: "Local shared", 11: "Local only"],
            localArtworks: [100: "Local muted artwork"],
            localCommentPhrases: ["spoiler"],
            remoteTags: ["CAT", "remote-only"],
            remoteUserIDs: [10, 12],
            muteLimitCount: 500
        )

        #expect(summary.localTagCount == 3)
        #expect(summary.remoteTagCount == 2)
        #expect(summary.remoteTagCountMissingLocally == 1)
        #expect(summary.remoteUserCountMissingLocally == 1)
        #expect(summary.localTagCountMissingRemotely == 2)
        #expect(summary.localUserCountMissingRemotely == 1)
        #expect(summary.detailText.contains("500"))
        #expect(summary.localOnlyDetailText.contains("1"))
    }

    @Test("Non-novel QA matrix covers P0 through P2")
    @MainActor
    func nonNovelQAMatrixBaseline() {
        let items = KeiPixStore.nonNovelQABaselineItems
        let snapshot = NonNovelQAMatrixSnapshot(checkedAt: Date(timeIntervalSince1970: 0), items: items)

        #expect(items.contains { $0.priority == .p0 && $0.id == "native-apple-route" })
        #expect(items.contains { $0.priority == .p0 && $0.id == "gallery-visual" })
        #expect(items.contains { $0.priority == .p1 && $0.id == "reader" })
        #expect(items.contains { $0.priority == .p2 && $0.id == "creator-discovery" })
        #expect(items.contains { $0.priority == .p2 && $0.id == "ugoira" })
        #expect(items.contains { $0.priority == .p2 && $0.id == "sharing-copy" })
        #expect(snapshot.progressRows().count == NonNovelQAPriority.allCases.count)
        #expect(snapshot.diagnosticsText.contains("KeiPix Non-Novel QA Matrix"))
        #expect(snapshot.diagnosticsText.contains("Swift + SwiftUI"))
    }

    @Test("Non-novel QA matrix snapshot is codable for persistence")
    @MainActor
    func nonNovelQAMatrixSnapshotRoundTrips() throws {
        let snapshot = NonNovelQAMatrixSnapshot(
            checkedAt: Date(timeIntervalSince1970: 1_771_830_000),
            items: [
                NonNovelQAItem(
                    id: "settings-organization",
                    priority: .p2,
                    title: L10n.qaSettingsOrganization,
                    requirement: L10n.qaSettingsOrganizationRequirement,
                    status: .passed,
                    evidence: "Visual QA 1/1",
                    nextAction: L10n.keepRegressionCoverage,
                    systemImage: "gearshape"
                )
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(NonNovelQAMatrixSnapshot.self, from: data)

        #expect(decoded.checkedAt == snapshot.checkedAt)
        #expect(decoded.items == snapshot.items)
        #expect(decoded.progressRows().first { $0.priority == .p2 }?.passed == 1)
    }

    @Test("Pixiv host probes cover the public API, auth, web, and image hosts")
    func pixivHostProbesCoverPrimaryPixivHosts() throws {
        let probes = PixivNetworkHostProbe.defaultProbes

        #expect(probes.map(\.id) == ["app-api", "oauth", "web", "image-cdn"])
        #expect(probes.map(\.host) == ["app-api.pixiv.net", "oauth.secure.pixiv.net", "www.pixiv.net", "i.pximg.net"])
        #expect(probes.allSatisfy { $0.url.scheme == "https" })

        let joined = probes.map { "\($0.url.absoluteString) \($0.title)" }.joined(separator: " ")
        #expect(joined.localizedCaseInsensitiveContains("mitm") == false)
        #expect(joined.localizedCaseInsensitiveContains("certificate bypass") == false)
        #expect(joined.localizedCaseInsensitiveContains("sni bypass") == false)
    }

    @Test("Pixiv host diagnostics treat non-5xx HTTP responses as reachable")
    func pixivHostDiagnosticsTreatHTTPResponsesAsReachable() throws {
        let probe = try #require(PixivNetworkHostProbe.defaultProbes.first)
        let result = PixivNetworkHostDiagnostics.result(
            for: probe,
            response: .http(statusCode: 403),
            proxySummary: "Manual SOCKS5 127.0.0.1:7890",
            duration: 0.125
        )

        #expect(result.id == "pixiv-host-app-api")
        #expect(result.status == .passed)
        #expect(result.detail.contains("app-api.pixiv.net"))
        #expect(result.detail.contains("HTTP 403"))
        #expect(result.detail.contains("Manual SOCKS5"))
    }

    @Test("Pixiv host diagnostics surface transport failures with the host name")
    func pixivHostDiagnosticsSurfaceTransportFailures() throws {
        let probe = try #require(PixivNetworkHostProbe.defaultProbes.last)
        let result = PixivNetworkHostDiagnostics.result(
            for: probe,
            response: .transportError("The request timed out."),
            proxySummary: L10n.directConnection,
            duration: 1.5
        )

        #expect(result.status == .failed)
        #expect(result.detail.contains("i.pximg.net"))
        #expect(result.detail.contains("timed out"))
        #expect(result.detail.localizedCaseInsensitiveContains("self-signed") == false)
    }
}
