import CoreGraphics
import Testing
@testable import KeiPix

struct BookmarkTagIndexPresentationTests {
    @Test("Bookmark tag index keeps pinned tags first and sorts by usage")
    func visibleTagsKeepPinnedTagsFirstAndSortByUsage() {
        let tags = [
            PixivBookmarkTag(name: "landscape", count: 12),
            PixivBookmarkTag(name: "favorite", count: 3),
            PixivBookmarkTag(name: "portrait", count: 20),
            PixivBookmarkTag(name: "animal", count: 20)
        ]

        let visible = BookmarkTagIndexPresentation.visibleTags(
            tags,
            query: "",
            pinnedTags: ["favorite"],
            sort: .mostUsed
        )

        #expect(visible.map(\.name) == ["favorite", "animal", "portrait", "landscape"])
    }

    @Test("Bookmark tag index trims query and can sort names")
    func visibleTagsTrimQueryAndSortNames() {
        let tags = [
            PixivBookmarkTag(name: "夜景", count: 1),
            PixivBookmarkTag(name: "landscape", count: 8),
            PixivBookmarkTag(name: "city landscape", count: 2),
            PixivBookmarkTag(name: "portrait", count: 20)
        ]

        let visible = BookmarkTagIndexPresentation.visibleTags(
            tags,
            query: " landscape ",
            pinnedTags: [],
            sort: .name
        )

        #expect(visible.map(\.name) == ["city landscape", "landscape"])
    }

    @Test("Bookmark tag collection lets long tags span the row")
    func collectionLayoutLetsLongTagsSpanTheRow() {
        let layout = NativeBookmarkTagCollectionLayout()
        let containerWidth: CGFloat = 368
        let availableWidth = containerWidth - layout.sectionInsets.leading - layout.sectionInsets.trailing

        let shortSize = layout.itemSize(
            for: .tag(PixivBookmarkTag(name: "sese", count: 1)),
            containerWidth: containerWidth
        )
        let longSize = layout.itemSize(
            for: .tag(PixivBookmarkTag(name: "ケイ(ブルーアーカイブ)", count: 5)),
            containerWidth: containerWidth
        )

        #expect(shortSize.width < availableWidth)
        #expect(longSize.width == availableWidth)
    }
}
