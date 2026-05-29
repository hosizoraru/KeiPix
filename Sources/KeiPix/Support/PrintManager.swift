#if os(macOS)
import AppKit
import SwiftUI

/// Print manager for artwork and novel content.
///
/// Provides native macOS printing via NSPrintOperation with:
/// - Artwork image printing (fit to page)
/// - Novel text printing (paginated)
/// - Custom print settings (orientation, scaling)
/// - Print preview support
enum PrintManager {

    // MARK: - Artwork Printing

    /// Print an artwork image.
    static func printArtwork(_ image: NSImage, title: String) {
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = image.size.width > image.size.height ? .landscape : .portrait
        printInfo.scalingFactor = 1.0

        let printOperation = NSPrintOperation(view: ArtworkPrintView(image: image, title: title))
        printOperation.printInfo = printInfo
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }

    /// Print artwork from a URL.
    static func printArtwork(from url: URL, title: String) {
        guard let image = NSImage(contentsOf: url) else { return }
        printArtwork(image, title: title)
    }

    // MARK: - Novel Printing

    /// Print novel text content.
    static func printNovel(title: String, author: String, text: String) {
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = .portrait
        printInfo.scalingFactor = 1.0
        printInfo.topMargin = 72    // 1 inch
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72

        let printOperation = NSPrintOperation(view: NovelPrintView(title: title, author: author, text: text))
        printOperation.printInfo = printInfo
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }

    // MARK: - Print Preview

    /// Show print preview for an artwork.
    static func previewArtwork(_ image: NSImage, title: String) {
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = image.size.width > image.size.height ? .landscape : .portrait

        let printOperation = NSPrintOperation(view: ArtworkPrintView(image: image, title: title))
        printOperation.printInfo = printInfo
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false
        printOperation.run()
    }
}

// MARK: - Print Views

/// NSView for printing artwork images.
private class ArtworkPrintView: NSView {
    let image: NSImage
    let title: String

    init(image: NSImage, title: String) {
        self.image = image
        self.title = title
        super.init(frame: NSRect(origin: .zero, size: image.size))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw title
        let titleFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.labelColor
        ]
        let titleSize = (title as NSString).size(withAttributes: titleAttrs)
        let titleRect = NSRect(
            x: (bounds.width - titleSize.width) / 2,
            y: 10,
            width: titleSize.width,
            height: titleSize.height
        )
        (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)

        // Draw image (fit to page, preserving aspect ratio)
        let imageArea = NSRect(x: 0, y: titleSize.height + 20, width: bounds.width, height: bounds.height - titleSize.height - 30)
        let imageSize = image.size
        let widthRatio = imageArea.width / imageSize.width
        let heightRatio = imageArea.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageRect = NSRect(
            x: imageArea.midX - scaledSize.width / 2,
            y: imageArea.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        image.draw(in: imageRect)
    }
}

/// NSView for printing novel text.
private class NovelPrintView: NSView {
    let title: String
    let author: String
    let text: String

    private let textStorage: NSTextStorage
    private let layoutManager: NSLayoutManager
    private let textContainer: NSTextContainer

    init(title: String, author: String, text: String) {
        self.title = title
        self.author = author
        self.text = text

        // Build attributed string
        let attributedText = NSMutableAttributedString()

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        attributedText.append(NSAttributedString(string: "\(title)\n\n", attributes: titleAttrs))

        // Author
        let authorAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        attributedText.append(NSAttributedString(string: "\(author)\n\n", attributes: authorAttrs))

        // Separator
        let separatorAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        attributedText.append(NSAttributedString(string: "────────────────────\n\n", attributes: separatorAttrs))

        // Body text
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        attributedText.append(NSAttributedString(string: text, attributes: bodyAttrs))

        // Setup text layout
        textStorage = NSTextStorage(attributedString: attributedText)
        layoutManager = NSLayoutManager()
        textContainer = NSTextContainer(size: .zero)

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Update text container size
        textContainer.size = bounds.size

        // Draw text
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
    }
}
#endif
