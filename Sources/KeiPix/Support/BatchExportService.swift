import PDFKit
import SwiftUI
import ImageIO
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
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

        let sources = imageURLs.compactMap { url in
            imageSize(at: url).map { ImageExportSource(url: url, size: $0) }
        }
        guard sources.isEmpty == false else { return nil }

        let cols = min(max(columns, 1), sources.count)
        let rows = Int(ceil(Double(sources.count) / Double(cols)))

        // Uniform cell size based on the largest image aspect ratio
        let maxW = sources.map(\.size.width).max() ?? 512
        let maxH = sources.map(\.size.height).max() ?? 512

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

        for (index, source) in sources.enumerated() {
            let col = index % cols
            let row = index / cols

            let x = (CGFloat(col) * (cellW + spacing)) * scale
            let y = size.height - ((CGFloat(row) + 1) * cellH + CGFloat(row) * spacing) * scale

            let destRect = NSRect(x: x, y: y, width: cellW * scale, height: cellH * scale)
            autoreleasepool {
                guard let image = PlatformImage(contentsOf: source.url) else { return }
                image.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        #else
        let size = CGSize(width: finalW, height: finalH)
        let renderer = UIGraphicsImageRenderer(size: size)
        let pngData = renderer.pngData { context in
            PlatformColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for (index, source) in sources.enumerated() {
                let col = index % cols
                let row = index / cols

                let x = (CGFloat(col) * (cellW + spacing)) * scale
                let y = (CGFloat(row) * (cellH + spacing)) * scale
                let destRect = CGRect(x: x, y: y, width: cellW * scale, height: cellH * scale)
                autoreleasepool {
                    guard let image = PlatformImage(contentsOf: source.url) else { return }
                    image.draw(in: destRect)
                }
            }
        }
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

    private static func imageSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return PlatformImage(contentsOf: url)?.size
        }

        let width = cgFloatProperty(properties[kCGImagePropertyPixelWidth])
        let height = cgFloatProperty(properties[kCGImagePropertyPixelHeight])

        guard let width, let height, width > 0, height > 0 else {
            return PlatformImage(contentsOf: url)?.size
        }
        return CGSize(width: width, height: height)
    }

    private static func cgFloatProperty(_ value: Any?) -> CGFloat? {
        if let value = value as? CGFloat {
            return value
        }
        if let value = value as? NSNumber {
            return CGFloat(truncating: value)
        }
        return nil
    }
}

private struct ImageExportSource {
    let url: URL
    let size: CGSize
}
