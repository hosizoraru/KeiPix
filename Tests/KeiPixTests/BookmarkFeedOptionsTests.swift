import Foundation
import Testing
@testable import KeiPix

@Suite("Bookmark feed options")
struct BookmarkFeedOptionsTests {
    @Test("Default options preserve app-api bookmark order")
    func defaultOptionsPreserveRemoteOrder() {
        let artworks = [
            artwork(id: 1, createdAt: 300, tags: ["landscape"]),
            artwork(id: 2, createdAt: 100, tags: ["portrait"]),
            artwork(id: 3, createdAt: 200, tags: ["landscape"])
        ]

        #expect(BookmarkFeedOptions.defaultValue.applying(to: artworks).map(\.id) == [1, 2, 3])
    }

    @Test("Artwork-date sorting is local and deterministic")
    func artworkDateSorting() {
        let artworks = [
            artwork(id: 1, createdAt: 300),
            artwork(id: 2, createdAt: 100),
            artwork(id: 3, createdAt: 200)
        ]

        var newest = BookmarkFeedOptions.defaultValue
        newest.sort = .newestArtwork
        var oldest = BookmarkFeedOptions.defaultValue
        oldest.sort = .oldestArtwork

        #expect(newest.applying(to: artworks).map(\.id) == [1, 3, 2])
        #expect(oldest.applying(to: artworks).map(\.id) == [2, 3, 1])
    }

    @Test("Age and artwork-tag filters compose")
    func ageAndArtworkTagFiltersCompose() {
        let artworks = [
            artwork(id: 1, tags: ["landscape"], xRestrict: 0),
            artwork(id: 2, tags: ["landscape", "R-18"], xRestrict: 1),
            artwork(id: 3, tags: ["portrait", "R-18G"], xRestrict: 2)
        ]

        var options = BookmarkFeedOptions.defaultValue
        options.ageLimit = .r18
        options.artworkTagFilter = "land"

        #expect(options.applying(to: artworks).map(\.id) == [2])
        #expect(options.activeFilterCount == 2)
        #expect(options.normalizedArtworkTagFilter == "land")
    }

    private func artwork(
        id: Int,
        createdAt: TimeInterval = 0,
        tags: [String] = [],
        xRestrict: Int = 0
    ) -> PixivArtwork {
        PixivArtwork(
            id: id,
            title: "Artwork \(id)",
            type: "illust",
            caption: "",
            user: PixivUser(id: 42, name: "Creator", account: "creator"),
            tags: tags.map { PixivTag(name: $0, translatedName: nil) },
            createDate: Date(timeIntervalSince1970: createdAt),
            pageCount: 1,
            width: 1000,
            height: 1000,
            totalView: 0,
            totalBookmarks: 0,
            totalComments: 0,
            isBookmarked: true,
            isMuted: false,
            isAI: false,
            sanityLevel: 0,
            xRestrict: xRestrict,
            series: nil,
            images: []
        )
    }
}
