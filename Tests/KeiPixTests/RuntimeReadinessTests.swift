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
}
