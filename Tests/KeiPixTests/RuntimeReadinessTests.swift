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

    @Test("Non-novel QA matrix covers P0 through P2")
    @MainActor
    func nonNovelQAMatrixBaseline() {
        let items = KeiPixStore.nonNovelQABaselineItems
        let snapshot = NonNovelQAMatrixSnapshot(checkedAt: Date(timeIntervalSince1970: 0), items: items)

        #expect(items.contains { $0.priority == .p0 && $0.id == "gallery-visual" })
        #expect(items.contains { $0.priority == .p1 && $0.id == "reader" })
        #expect(items.contains { $0.priority == .p2 && $0.id == "creator-discovery" })
        #expect(snapshot.progressRows().count == NonNovelQAPriority.allCases.count)
        #expect(snapshot.diagnosticsText.contains("KeiPix Non-Novel QA Matrix"))
        #expect(snapshot.diagnosticsText.contains("Swift + SwiftUI"))
    }
}
