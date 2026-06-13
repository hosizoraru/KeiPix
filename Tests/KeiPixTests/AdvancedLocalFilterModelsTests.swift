import Foundation
import Testing
@testable import KeiPix

struct AdvancedLocalFilterModelsTests {
    @Test("Advanced local filter criteria build a DSL query without exposing raw syntax to the editor")
    func criteriaBuildDSLQuery() {
        let draft = AdvancedLocalFilterDraft(criteria: [
            .text(field: .tag, value: "Blue Archive"),
            .text(field: .title, value: "summer"),
            .text(field: .author, value: "Alice"),
            .number(.bookmarkCount, range: .init(minimum: 100, maximum: 500)),
            .flag(.r18, isIncluded: false),
            .flag(.ai, isIncluded: false),
            .flag(.ugoira, isIncluded: true),
            .ratio(.landscape),
            .number(.pageCount, range: .init(minimum: 2, maximum: nil))
        ])

        #expect(draft.query == #"tag:"Blue Archive" title:summer user:Alice bookmark:>=100 bookmark:<=500 !r18 !ai gif ratio:landscape page:>=2"#)
        #expect(draft.isEmpty == false)
        #expect(draft.prefersWideEditor)
    }

    @Test("Advanced local filter draft removes empty criteria and reports compact eligibility")
    func draftRemovesEmptyCriteriaAndReportsCompactEligibility() {
        let draft = AdvancedLocalFilterDraft(criteria: [
            .text(field: .tag, value: "   "),
            .flag(.bookmarked, isIncluded: true)
        ])

        #expect(draft.query == "bookmarked")
        #expect(draft.isEmpty == false)
        #expect(draft.prefersWideEditor == false)
    }

    @Test("Client filter DSL supports menu generated title author ratio and gif tokens")
    func clientFilterSupportsMenuGeneratedTokens() {
        let landscapeUgoira = artwork(
            id: 1,
            title: "summer study",
            user: PixivUser(id: 10, name: "Alice", account: "alice"),
            tags: [PixivTag(name: "Blue Archive", translatedName: nil)],
            width: 1600,
            height: 900,
            type: "ugoira",
            bookmarks: 300,
            pages: 3,
            isAI: false,
            isBookmarked: true,
            xRestrict: 0
        )
        let portraitAI = artwork(
            id: 2,
            title: "winter",
            user: PixivUser(id: 20, name: "Bob", account: "bob"),
            tags: [PixivTag(name: "Original", translatedName: nil)],
            width: 900,
            height: 1600,
            type: "illust",
            bookmarks: 20,
            pages: 1,
            isAI: true,
            isBookmarked: false,
            xRestrict: 1
        )

        let query = AdvancedLocalFilterDraft(criteria: [
            .text(field: .tag, value: "Blue Archive"),
            .text(field: .title, value: "summer"),
            .text(field: .author, value: "Alice"),
            .number(.bookmarkCount, range: .init(minimum: 100, maximum: 500)),
            .flag(.r18, isIncluded: false),
            .flag(.ai, isIncluded: false),
            .flag(.ugoira, isIncluded: true),
            .ratio(.landscape),
            .number(.pageCount, range: .init(minimum: 2, maximum: nil))
        ]).query

        #expect(ClientFilterDSL.filter([landscapeUgoira, portraitAI], query: query).map(\.id) == [1])
        #expect(ClientFilterDSL.filter([landscapeUgoira, portraitAI], query: "artist:Alice").map(\.id) == [1])
        #expect(ClientFilterDSL.filter([landscapeUgoira, portraitAI], query: "-gif").map(\.id) == [2])
        #expect(ClientFilterDSL.filter([landscapeUgoira, portraitAI], query: "ratio:portrait").map(\.id) == [2])
    }

    @Test("Advanced local filter quick presets preserve quoted text while switching grouped tokens")
    func quickPresetsPreserveQuotedTextAndSwitchGroupedTokens() {
        var query = #"tag:"Blue Archive" title:summer"#

        query = AdvancedLocalFilterQuickPreset.excludeAI.applying(to: query)
        #expect(query == #"tag:"Blue Archive" title:summer !ai"#)
        #expect(AdvancedLocalFilterQuickPreset.excludeAI.isActive(in: query))

        query = AdvancedLocalFilterQuickPreset.onlyUgoira.applying(to: query)
        #expect(query == #"tag:"Blue Archive" title:summer !ai gif"#)

        query = AdvancedLocalFilterQuickPreset.excludeUgoira.applying(to: query)
        #expect(query == #"tag:"Blue Archive" title:summer !ai !gif"#)
        #expect(AdvancedLocalFilterQuickPreset.onlyUgoira.isActive(in: query) == false)
        #expect(AdvancedLocalFilterQuickPreset.excludeUgoira.isActive(in: query))

        query = AdvancedLocalFilterQuickPreset.excludeUgoira.applying(to: query)
        #expect(query == #"tag:"Blue Archive" title:summer !ai"#)
    }

    @Test("Advanced local filter quick presets keep one active aspect ratio")
    func quickPresetsKeepOneActiveAspectRatio() {
        var query = AdvancedLocalFilterQuickPreset.landscape.applying(to: "bookmarked")

        #expect(query == "bookmarked ratio:landscape")
        #expect(AdvancedLocalFilterQuickPreset.landscape.isActive(in: query))

        query = AdvancedLocalFilterQuickPreset.portrait.applying(to: query)
        #expect(query == "bookmarked ratio:portrait")
        #expect(AdvancedLocalFilterQuickPreset.landscape.isActive(in: query) == false)
        #expect(AdvancedLocalFilterQuickPreset.portrait.isActive(in: query))
    }

    @Test("Advanced local filter editor draft round trips typed fields while preserving free text")
    func editorDraftRoundTripsTypedFieldsAndPreservesFreeText() {
        let editor = AdvancedLocalFilterEditorDraft(
            query: #"tag:"Blue Archive" title:summer artist:Alice bookmark:>=100 bookmark:<=500 view:>=2000 page:<=8 !r18 !r18g !ai gif ratio:landscape bookmarked quiet"#)

        #expect(editor.tagText == "Blue Archive")
        #expect(editor.titleText == "summer")
        #expect(editor.authorText == "Alice")
        #expect(editor.bookmarkRange == .init(minimum: 100, maximum: 500))
        #expect(editor.viewRange == .init(minimum: 2000, maximum: nil))
        #expect(editor.pageRange == .init(minimum: nil, maximum: 8))
        #expect(editor.r18Rule == .exclude)
        #expect(editor.r18gRule == .exclude)
        #expect(editor.aiRule == .exclude)
        #expect(editor.ugoiraRule == .include)
        #expect(editor.bookmarkedRule == .include)
        #expect(editor.ratio == .landscape)
        #expect(editor.passthroughQuery == "quiet")
        #expect(editor.query == #"tag:"Blue Archive" title:summer user:Alice bookmark:>=100 bookmark:<=500 view:>=2000 page:<=8 !r18 !r18g !ai gif bookmarked ratio:landscape quiet"#)
    }

    private func artwork(
        id: Int,
        title: String,
        user: PixivUser,
        tags: [PixivTag],
        width: Int,
        height: Int,
        type: String,
        bookmarks: Int,
        pages: Int,
        isAI: Bool,
        isBookmarked: Bool,
        xRestrict: Int
    ) -> PixivArtwork {
        PixivArtwork(
            id: id,
            title: title,
            type: type,
            caption: "",
            user: user,
            tags: tags,
            createDate: Date(timeIntervalSince1970: 0),
            pageCount: pages,
            width: width,
            height: height,
            totalView: 1000,
            totalBookmarks: bookmarks,
            totalComments: 0,
            isBookmarked: isBookmarked,
            isMuted: false,
            isAI: isAI,
            sanityLevel: 2,
            xRestrict: xRestrict,
            series: nil,
            images: [
                PixivImageSet(
                    squareMedium: URL(string: "https://example.com/\(id)_square.jpg"),
                    medium: URL(string: "https://example.com/\(id)_medium.jpg"),
                    large: URL(string: "https://example.com/\(id)_large.jpg"),
                    original: URL(string: "https://example.com/\(id)_original.jpg")
                )
            ]
        )
    }
}
