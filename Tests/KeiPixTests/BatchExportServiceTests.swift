import Foundation
import Testing
@testable import KeiPix

@Suite("Batch export service")
struct BatchExportServiceTests {
    @Test("Collage export clamps invalid column counts")
    func collageExportClampsInvalidColumnCounts() throws {
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "keipix-batch-export-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appending(path: "first.png")
        let second = directory.appending(path: "second.png")
        try pngData.write(to: first, options: .atomic)
        try pngData.write(to: second, options: .atomic)

        let output = try #require(BatchExportService.exportCollage(
            from: [first, second],
            title: "Invalid Columns",
            columns: 0,
            outputDirectory: directory
        ))

        #expect(FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
        #expect(output.lastPathComponent == "Invalid Columns-collage.png")
    }

    private static let onePixelPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
}
