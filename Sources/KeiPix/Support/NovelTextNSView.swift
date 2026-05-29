#if os(macOS)
import AppKit
import SwiftUI

/// NSTextView wrapper for the novel reader.
///
/// Provides rich text rendering, virtualized scrolling, native IME
/// support, and better text selection — all limitations of SwiftUI's
/// `Text` view for long-form content.
struct NovelTextNSView: NSViewRepresentable {
    let tokens: [NovelToken]
    let fontFamily: NovelReaderFontFamily
    let textSize: Double
    let lineSpacing: Double
    let paragraphSpacing: Double
    let theme: NovelReaderTheme
    let translatedTexts: [Int: String]
    let translationMode: NovelTranslationMode
    let isTranslationActive: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true

        // Configure text container for proper wrapping
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let textView = coordinator.textView else { return }

        // Only update if content changed
        let newAttributed = buildAttributedString()
        if coordinator.lastContent != newAttributed.string {
            coordinator.lastContent = newAttributed.string
            textView.textStorage?.setAttributedString(newAttributed)
        }

        // Update theme colors
        textView.backgroundColor = NSColor(theme.backgroundColor)
        textView.textColor = NSColor(theme.foregroundColor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var scrollView: NSScrollView?
        var textView: NSTextView?
        var lastContent: String = ""
    }

    private func buildAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = nsFont(for: fontFamily, size: textSize)
        let rubyFont = nsFont(for: fontFamily, size: max(textSize - 4, 9))
        let translatedFont = nsFont(for: fontFamily, size: textSize * 0.9)

        for (index, token) in tokens.enumerated() {
            switch token {
            case .text(let value):
                // Original text
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: NSColor(theme.foregroundColor)
                ]
                result.append(NSAttributedString(string: value, attributes: attrs))

                // Translation (if active)
                if isTranslationActive,
                   let translated = translatedTexts[index] {
                    result.append(NSAttributedString(string: "\n"))

                    let translatedAttrs: [NSAttributedString.Key: Any] = [
                        .font: translatedFont,
                        .foregroundColor: NSColor(theme.foregroundColor).withAlphaComponent(0.7),
                        .backgroundColor: NSColor(theme.embedBackgroundColor)
                    ]
                    result.append(NSAttributedString(string: translated, attributes: translatedAttrs))
                }

                result.append(NSAttributedString(string: "\n"))

            case .chapter(let title):
                let boldFont = NSFont(descriptor: bodyFont.fontDescriptor.withSymbolicTraits(.bold), size: bodyFont.pointSize) ?? bodyFont
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: boldFont,
                    .foregroundColor: NSColor(theme.foregroundColor)
                ]
                result.append(NSAttributedString(string: "\n\(title)\n\n", attributes: attrs))

            case .ruby(let base, let reading):
                // Inline ruby: base(reading)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: NSColor(theme.foregroundColor)
                ]
                let rubyAttrs: [NSAttributedString.Key: Any] = [
                    .font: rubyFont,
                    .foregroundColor: NSColor(theme.foregroundColor).withAlphaComponent(0.6)
                ]
                result.append(NSAttributedString(string: base, attributes: attrs))
                result.append(NSAttributedString(string: " (\(reading))", attributes: rubyAttrs))

            case .jumpURL(let label, let url):
                let mediumFont = NSFont(descriptor: bodyFont.fontDescriptor.withWeight(.medium), size: bodyFont.pointSize) ?? bodyFont
                let linkAttrs: [NSAttributedString.Key: Any] = [
                    .font: mediumFont,
                    .foregroundColor: NSColor.linkColor,
                    .link: url
                ]
                result.append(NSAttributedString(string: label.isEmpty ? url.absoluteString : label, attributes: linkAttrs))
                result.append(NSAttributedString(string: "\n"))

            case .jumpPage(let target):
                let mediumItalic = NSFont(descriptor: bodyFont.fontDescriptor.withWeight(.medium).withSymbolicTraits(.italic), size: bodyFont.pointSize) ?? bodyFont
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: mediumItalic,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                result.append(NSAttributedString(string: "→ p.\(target)\n", attributes: attrs))

            case .newPage, .pixivImage, .uploadedImage:
                // These are handled by the page splitter or rendered separately
                break
            }
        }

        return result
    }

    private func nsFont(for family: NovelReaderFontFamily, size: CGFloat) -> NSFont {
        switch family {
        case .system:
            return NSFont.systemFont(ofSize: size)
        case .serif:
            let descriptor = NSFontDescriptor(name: "Georgia", size: size)
            return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size)
        case .monospaced:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

// MARK: - NSFont helpers

private extension NSFontDescriptor {
    func withWeight(_ weight: NSFont.Weight) -> NSFontDescriptor {
        let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: weight]
        return addingAttributes([.traits: traits])
    }
}

// MARK: - SwiftUI wrapper

/// SwiftUI view that uses NSTextView for rich text rendering.
struct NovelRichTextView: View {
    let tokens: [NovelToken]
    let fontFamily: NovelReaderFontFamily
    let textSize: Double
    let lineSpacing: Double
    let paragraphSpacing: Double
    let theme: NovelReaderTheme
    let translatedTexts: [Int: String]
    let translationMode: NovelTranslationMode
    let isTranslationActive: Bool

    var body: some View {
        NovelTextNSView(
            tokens: tokens,
            fontFamily: fontFamily,
            textSize: textSize,
            lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing,
            theme: theme,
            translatedTexts: translatedTexts,
            translationMode: translationMode,
            isTranslationActive: isTranslationActive
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
