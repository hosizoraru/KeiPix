import Foundation
import Testing
@testable import KeiPix

struct ImagePipelineTests {
    @Test("Local image files are decoded through the shared pipeline")
    func localImageFilesDecodeThroughPipeline() async throws {
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "keipix-local-image-\(UUID().uuidString).png")
        try pngData.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let image = try await ImagePipeline.shared.image(contentsOf: fileURL)

        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
        #expect(image.platformCGImage != nil)
    }

    @Test("Decoded images are synchronously available for reused scroll cells")
    func decodedImagesAreSynchronouslyAvailableForReusedScrollCells() async throws {
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "keipix-reused-scroll-cell-\(UUID().uuidString).png")
        try pngData.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let image = try await ImagePipeline.shared.image(contentsOf: fileURL)
        let cached = try #require(ImagePipeline.shared.cachedImage(for: fileURL))

        #expect(cached.size == image.size)
        #expect(cached.platformCGImage != nil)
    }

    private static let onePixelPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
}
