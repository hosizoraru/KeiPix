import PDFKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Generates PDF documents and collage images from artwork image files.
enum BatchExportService {

    // MARK: - PDF Export

    /// Combine multiple image files into a single PDF document, one page per image.
    /// Returns the file URL of the written PDF, or `nil` on failure.
    static func exportPDF(
        from imageURLs: [URL],
        title: String,
        outputDirectory: URL? = nil
    ) -> URL? {
        guard imageURLs.isEmpty == false else { return nil }

        let outputDir = outputDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appendingPathComponent("KeiPix", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let sanitizedTitle = title.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let outputURL = outputDir.appendingPathComponent("\(sanitizedTitle).pdf")

        let pdfDocument = PDFDocument()

        for (index, imageURL) in imageURLs.enumerated() {
            guard let image = PlatformImage(contentsOf: imageURL) else { continue }
            guard let page = PDFPage(image: image) else { continue }
            pdfDocument.insert(page, at: index)
        }

        guard pdfDocument.pageCount > 0 else { return nil }
        return pdfDocument.write(to: outputURL) ? outputURL : nil
    }

    // MARK: - Collage Export

    /// Arrange multiple images in a grid collage and export as a single PNG.
    /// Returns the file URL of the written image, or `nil` on failure.
    static func exportCollage(
        from imageURLs: [URL],
        title: String,
        columns: Int = 2,
        spacing: CGFloat = 8,
        maxDimension: CGFloat = 4096,
        outputDirectory: URL? = nil
    ) -> URL? {
        guard imageURLs.isEmpty == false else { return nil }

        let images = imageURLs.compactMap { PlatformImage(contentsOf: $0) }
        guard images.isEmpty == false else { return nil }

        let cols = min(columns, images.count)
        let rows = Int(ceil(Double(images.count) / Double(cols)))

        // Uniform cell size based on the largest image aspect ratio
        let maxW = images.map(\.size.width).max() ?? 512
        let maxH = images.map(\.size.height).max() ?? 512

        // Scale cells so the collage fits within maxDimension
        let cellW: CGFloat = 512
        let cellH = cellW * (maxH / maxW)

        let totalW = CGFloat(cols) * cellW + CGFloat(cols - 1) * spacing
        let totalH = CGFloat(rows) * cellH + CGFloat(rows - 1) * spacing

        // Clamp to maxDimension
        let scale = min(1, maxDimension / max(totalW, totalH))
        let finalW = totalW * scale
        let finalH = totalH * scale

        #if os(macOS)
        let size = NSSize(width: finalW, height: finalH)
        let image = PlatformImage(size: size)

        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        for (index, img) in images.enumerated() {
            let col = index % cols
            let row = index / cols

            let x = (CGFloat(col) * (cellW + spacing)) * scale
            let y = size.height - ((CGFloat(row) + 1) * cellH + CGFloat(row) * spacing) * scale

            let destRect = NSRect(x: x, y: y, width: cellW * scale, height: cellH * scale)
            img.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        #else
        // iPadOS: UIGraphicsImageRenderer-based implementation in Phase 5.
        return nil
        #endif

        let outputDir = outputDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appendingPathComponent("KeiPix", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let sanitizedTitle = title.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let outputURL = outputDir.appendingPathComponent("\(sanitizedTitle)-collage.png")

        do {
            try pngData.write(to: outputURL)
            return outputURL
        } catch {
            return nil
        }
    }
}
