import Foundation
import Testing
@testable import KeiPix

@Suite("Feedback report")
struct FeedbackReportTests {
    @Test("Report reasons default to Pixiv-compatible safety categories")
    func reportReasons() {
        let titles = FeedbackReportReason.allCases.map(\.title)

        #expect(titles.contains(L10n.reportReasonSexualContent))
        #expect(titles.contains(L10n.reportReasonHateSpeech))
        #expect(titles.contains(L10n.reportReasonBullyingHarassment))
        #expect(FeedbackReportReason.other.title == L10n.reportReasonOther)
    }

    @Test("Report summary includes target, reason, note, and Pixiv link")
    func reportSummary() throws {
        let url = try #require(URL(string: "https://www.pixiv.net/artworks/123"))
        let request = FeedbackReportRequest(
            id: "artwork-123",
            kind: .artwork,
            targetTitle: "Sample",
            targetSubtitle: "#123 · Creator",
            targetURL: url,
            localMuteTitle: L10n.muteArtwork
        )

        let summary = request.summary(reason: .sensitiveEvents, note: "needs review")

        #expect(summary.contains(L10n.feedbackTarget))
        #expect(summary.contains(L10n.reportReasonSensitiveEvents))
        #expect(summary.contains("needs review"))
        #expect(summary.contains(url.absoluteString))
    }
}
