import Foundation
import Testing
@testable import KeiPix

struct RemoteImageViewTests {
    @Test("Remote image load keys change with the displayed image source")
    func loadKeysChangeWithDisplayedImageSource() throws {
        let first = RemoteImageLoadKey(
            localURL: nil,
            url: try testURL("https://example.com/artwork-a.jpg")
        )
        let second = RemoteImageLoadKey(
            localURL: nil,
            url: try testURL("https://example.com/artwork-b.jpg")
        )
        let downloaded = RemoteImageLoadKey(
            localURL: URL(fileURLWithPath: "/tmp/keipix/artwork-a.jpg"),
            url: try testURL("https://example.com/artwork-a.jpg")
        )

        #expect(first != second)
        #expect(first != downloaded)
    }

    @Test("Remote image views never render a loaded bitmap for another source")
    func loadedBitmapMustMatchTheCurrentImageSource() throws {
        let first = RemoteImageLoadKey(
            localURL: nil,
            url: try testURL("https://example.com/artwork-a.jpg")
        )
        let second = RemoteImageLoadKey(
            localURL: nil,
            url: try testURL("https://example.com/artwork-b.jpg")
        )

        #expect(RemoteImageLoadPolicy.shouldDisplay(loadedImageKey: first, currentKey: first))
        #expect(RemoteImageLoadPolicy.shouldDisplay(loadedImageKey: first, currentKey: second) == false)
        #expect(RemoteImageLoadPolicy.shouldDisplay(loadedImageKey: nil, currentKey: second) == false)
    }

    @Test("Remote image views reject stale or cancelled load completions")
    func staleOrCancelledLoadCompletionsCannotCommit() throws {
        let oldKey = RemoteImageLoadKey(
            localURL: nil,
            url: try testURL("https://example.com/old.jpg")
        )
        let currentKey = RemoteImageLoadKey(
            localURL: nil,
            url: try testURL("https://example.com/current.jpg")
        )

        #expect(RemoteImageLoadPolicy.shouldCommit(requestedKey: currentKey, activeKey: currentKey, isCancelled: false))
        #expect(RemoteImageLoadPolicy.shouldCommit(requestedKey: oldKey, activeKey: currentKey, isCancelled: false) == false)
        #expect(RemoteImageLoadPolicy.shouldCommit(requestedKey: currentKey, activeKey: currentKey, isCancelled: true) == false)
        #expect(RemoteImageLoadPolicy.shouldCommit(requestedKey: currentKey, activeKey: nil, isCancelled: false) == false)
    }

    private func testURL(_ rawValue: String) throws -> URL {
        try #require(URL(string: rawValue))
    }
}
