import Foundation
import SwiftUI
import Testing
@testable import KeiPix

@MainActor
@Suite("Artwork image quality quick access", .serialized)
struct ArtworkImageQualityQuickAccessTests {
    @Test("Unified image quality quick access has an initial tier")
    func unifiedImageQualityQuickAccessHasInitialTier() {
        Self.withIsolatedQualityPreferences {
            let store = Self.store()

            #expect(store.sharedArtworkImageQualityTier == .large)
        }
    }

    @Test("Unified image quality quick access applies one tier to all surfaces")
    func unifiedImageQualityQuickAccessAppliesOneTierToAllSurfaces() {
        Self.withIsolatedQualityPreferences {
            let store = Self.store()

            store.setArtworkImageQualityTier(.original)

            #expect(store.feedPreviewImageQualityTier == .original)
            #expect(store.illustDetailImageQualityTier == .original)
            #expect(store.mangaDetailImageQualityTier == .original)
            #expect(store.useOriginalImagesInDetail == true)
            #expect(store.useOriginalImagesForManga == true)

            store.setArtworkImageQualityTier(.medium)

            #expect(store.feedPreviewImageQualityTier == .medium)
            #expect(store.illustDetailImageQualityTier == .medium)
            #expect(store.mangaDetailImageQualityTier == .medium)
            #expect(store.useOriginalImagesInDetail == false)
            #expect(store.useOriginalImagesForManga == false)
        }
    }

    @Test("Settings image quality binding has a default and applies one tier")
    func settingsImageQualityBindingHasDefaultAndAppliesOneTier() {
        Self.withIsolatedQualityPreferences {
            let store = Self.store()
            let binding = store.settings_artworkImageQualityTierBinding

            #expect(binding.wrappedValue == .large)

            binding.wrappedValue = .original

            #expect(store.feedPreviewImageQualityTier == .original)
            #expect(store.illustDetailImageQualityTier == .original)
            #expect(store.mangaDetailImageQualityTier == .original)
        }
    }

    @Test("Downloads use the current image quality tier for saved image URLs")
    func downloadsUseCurrentImageQualityTierForSavedImageURLs() throws {
        try Self.withIsolatedQualityPreferences {
            let store = Self.store()
            store.downloads.items = []
            store.downloads.isPaused = true
            let artwork = try Self.sampleArtwork()

            store.setArtworkImageQualityTier(.medium)
            store.enqueueDownload(artwork)

            #expect(store.downloads.items.first?.sourceImageURLs?.map(\.absoluteString) == [
                "https://example.com/1_medium.jpg"
            ])

            store.downloads.items = []
            store.setArtworkImageQualityTier(.original)
            store.enqueueDownload(artwork)

            #expect(store.downloads.items.first?.sourceImageURLs?.map(\.absoluteString) == [
                "https://example.com/1_original.jpg"
            ])
        }
    }

    @Test("Page and batch downloads inherit the current image quality tier")
    func pageAndBatchDownloadsInheritCurrentImageQualityTier() {
        Self.withIsolatedQualityPreferences {
            let store = Self.store()
            store.downloads.items = []
            store.downloads.isPaused = true
            store.setArtworkImageQualityTier(.medium)

            let manga = Self.sampleArtwork(id: 2, pageCount: 3)
            let queuedPages = store.enqueueDownloadPages(manga, pageIndexes: [0, 2])

            #expect(queuedPages == 2)
            #expect(store.downloads.items.first?.sourceImageURLs?.map(\.absoluteString) == [
                "https://example.com/2_0_medium.jpg",
                "https://example.com/2_2_medium.jpg"
            ])

            store.downloads.items = []
            let queuedBatch = store.enqueueDownloads(
                [
                    Self.sampleArtwork(id: 3, pageCount: 1),
                    Self.sampleArtwork(id: 4, pageCount: 1)
                ],
                limit: 2
            )

            #expect(queuedBatch == 2)
            #expect(
                store.downloads.items.compactMap(\.sourceImageURLs?.first?.absoluteString).sorted() == [
                    "https://example.com/3_0_medium.jpg",
                    "https://example.com/4_0_medium.jpg"
                ]
            )
        }
    }

    private static func withIsolatedQualityPreferences(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let previousValues = Dictionary(uniqueKeysWithValues: qualityPreferenceKeys.map { ($0, defaults.object(forKey: $0)) })
        qualityPreferenceKeys.forEach { defaults.removeObject(forKey: $0) }
        defer {
            qualityPreferenceKeys.forEach { key in
                if let value = previousValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try body()
    }

    private static func sampleArtwork() throws -> PixivArtwork {
        let payload = """
        {
          "id": 1,
          "title": "Sample",
          "type": "illust",
          "image_urls": {
            "square_medium": "https://example.com/1_square.jpg",
            "medium": "https://example.com/1_medium.jpg",
            "large": "https://example.com/1_large.jpg",
            "original": "https://example.com/1_original.jpg"
          },
          "meta_single_page": {
            "original_image_url": "https://example.com/1_original.jpg"
          },
          "caption": "",
          "create_date": 1700000000,
          "user": {
            "id": 9001,
            "name": "Creator",
            "account": "creator9001"
          },
          "tags": [],
          "page_count": 1,
          "is_bookmarked": false
        }
        """
        return try JSONDecoder().decode(PixivArtwork.self, from: Data(payload.utf8))
    }

    private static func sampleArtwork(id: Int, pageCount: Int) -> PixivArtwork {
        PixivArtwork(
            id: id,
            title: "Sample \(id)",
            type: "illust",
            caption: "",
            user: PixivUser(id: 9001, name: "Creator", account: "creator9001"),
            tags: [],
            createDate: Date(timeIntervalSince1970: 1_700_000_000),
            pageCount: pageCount,
            width: 1200,
            height: 1600,
            totalView: 0,
            totalBookmarks: 0,
            totalComments: 0,
            isBookmarked: false,
            isMuted: false,
            isAI: false,
            sanityLevel: 0,
            xRestrict: 0,
            series: nil,
            images: (0..<pageCount).map { page in
                PixivImageSet(
                    squareMedium: URL(string: "https://example.com/\(id)_\(page)_square.jpg")!,
                    medium: URL(string: "https://example.com/\(id)_\(page)_medium.jpg")!,
                    large: URL(string: "https://example.com/\(id)_\(page)_large.jpg")!,
                    original: URL(string: "https://example.com/\(id)_\(page)_original.jpg")!
                )
            }
        )
    }

    private static func store() -> KeiPixStore {
        KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
    }

    private static let qualityPreferenceKeys = [
        "feedPreviewImageQualityTier",
        "illustDetailImageQualityTier",
        "mangaDetailImageQualityTier",
        "useOriginalImagesInDetail",
        "useOriginalImagesForManga"
    ]
}
