import Foundation
import Testing
@testable import KeiPix

@Suite(.serialized)
struct ImagePipelineTests {
    @Test("Local image files are decoded through the image pipeline")
    func localImageFilesDecodeThroughPipeline() async throws {
        let pipeline = ImagePipeline()
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "keipix-local-image-\(UUID().uuidString).png")
        try pngData.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let image = try await pipeline.image(contentsOf: fileURL)

        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
        #expect(image.platformCGImage != nil)
    }

    @Test("Decoded images are synchronously available for reused scroll cells")
    func decodedImagesAreSynchronouslyAvailableForReusedScrollCells() async throws {
        let pipeline = ImagePipeline()
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "keipix-reused-scroll-cell-\(UUID().uuidString).png")
        try pngData.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let image = try await pipeline.image(contentsOf: fileURL)
        let cached = try #require(pipeline.cachedImage(for: fileURL))

        #expect(cached.size == image.size)
        #expect(cached.platformCGImage != nil)
    }

    @Test("Decoded memory cache can be cleared without clearing the full image cache")
    func decodedMemoryCacheCanBeClearedSeparately() async throws {
        let pipeline = ImagePipeline()
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "keipix-decoded-cache-clear-\(UUID().uuidString).png")
        try pngData.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        _ = try await pipeline.image(contentsOf: fileURL)
        #expect(pipeline.cachedImage(for: fileURL) != nil)

        _ = pipeline.clearDecodedMemoryCaches()

        #expect(pipeline.cachedImage(for: fileURL) == nil)
    }

    private static let onePixelPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
}
