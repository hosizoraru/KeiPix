import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Native TextKit-backed page renderer for Pixiv novel body pages.
///
/// SwiftUI still owns navigation, page splitting, translation state, and
/// embedded-image fallback. This view takes over the hot path that is expensive
/// in SwiftUI: long selectable text with links, ruby fallbacks, and paragraph
/// styling.
struct NativeNovelTextPageView: View {
    let tokens: [NovelToken]
    let fontFamily: NovelReaderFontFamily
    let textSize: Double
    let lineSpacing: Double
    let paragraphSpacing: Double
    let theme: NovelReaderTheme
    let translatedTexts: [Int: String]
    let translationMode: NovelTranslationMode
    let isTranslationActive: Bool
    let isTranslating: Bool
    let showChapterMarkers: Bool

    var body: some View {
        NativeNovelTextRepresentable(
            attributedString: NativeNovelTextAttributedStringBuilder.build(
                tokens: tokens,
                fontFamily: fontFamily,
                textSize: textSize,
                lineSpacing: lineSpacing,
                paragraphSpacing: paragraphSpacing,
                theme: theme,
                translatedTexts: translatedTexts,
                translationMode: translationMode,
                isTranslationActive: isTranslationActive,
                isTranslating: isTranslating,
                showChapterMarkers: showChapterMarkers
            ),
            backgroundColor: PlatformColor(theme.backgroundColor),
            textColor: PlatformColor(theme.foregroundColor)
        )
    }
}

/// Native continuous reader for iOS/iPadOS long-form novel text.
///
/// The page view above is still useful for macOS book-style layouts. Mobile
/// reading needs a different hot path: one vertically scrolling native text
/// surface that owns selection, link interaction, Dynamic Type scaling, and
/// scroll indicators without SwiftUI gesture overlays.
struct NativeNovelContinuousTextView: View {
    let tokens: [NovelToken]
    let fontFamily: NovelReaderFontFamily
    let textSize: Double
    let lineSpacing: Double
    let paragraphSpacing: Double
    let theme: NovelReaderTheme
    let translatedTexts: [Int: String]
    let translationMode: NovelTranslationMode
    let isTranslationActive: Bool
    let isTranslating: Bool
    let showChapterMarkers: Bool
    let maxContentWidth: CGFloat

    var body: some View {
        let attributedString = NativeNovelTextAttributedStringBuilder.build(
            tokens: tokens,
            fontFamily: fontFamily,
            textSize: textSize,
            lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing,
            theme: theme,
            translatedTexts: translatedTexts,
            translationMode: translationMode,
            isTranslationActive: isTranslationActive,
            isTranslating: isTranslating,
            showChapterMarkers: showChapterMarkers
        )

        #if os(iOS)
        NativeNovelContinuousTextRepresentable(
            attributedString: attributedString,
            backgroundColor: PlatformColor(theme.backgroundColor),
            textColor: PlatformColor(theme.foregroundColor),
            maxContentWidth: maxContentWidth
        )
        #else
        NativeNovelTextRepresentable(
            attributedString: attributedString,
            backgroundColor: PlatformColor(theme.backgroundColor),
            textColor: PlatformColor(theme.foregroundColor)
        )
        #endif
    }
}

private enum NativeNovelTextAttributedStringBuilder {
    static func build(
        tokens: [NovelToken],
        fontFamily: NovelReaderFontFamily,
        textSize: Double,
        lineSpacing: Double,
        paragraphSpacing: Double,
        theme: NovelReaderTheme,
        translatedTexts: [Int: String],
        translationMode: NovelTranslationMode,
        isTranslationActive: Bool,
        isTranslating: Bool,
        showChapterMarkers: Bool
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = platformFont(for: fontFamily, size: textSize, weight: .regular)
        let boldFont = platformFont(for: fontFamily, size: textSize, weight: .semibold)
        let rubyFont = platformFont(for: fontFamily, size: max(textSize - 4, 9), weight: .regular)
        let linkFont = platformFont(for: fontFamily, size: textSize, weight: .medium)
        let foregroundColor = PlatformColor(theme.foregroundColor)
        let translatingColor = foregroundColor.withAlphaComponent(0.6)
        let secondaryColor = foregroundColor.withAlphaComponent(0.68)
        let paragraph = paragraphStyle(lineSpacing: lineSpacing, paragraphSpacing: paragraphSpacing)
        let compactParagraph = paragraphStyle(lineSpacing: max(lineSpacing - 2, 0), paragraphSpacing: max(paragraphSpacing - 2, 0))

        for (index, token) in tokens.enumerated() {
            switch token {
            case .text(let value):
                if isTranslationActive,
                   let translated = translatedTexts[index] {
                    switch translationMode {
                    case .bilingual:
                        appendBlock(
                            value,
                            to: result,
                            attributes: [
                                .font: bodyFont,
                                .foregroundColor: foregroundColor,
                                .paragraphStyle: compactParagraph
                            ]
                        )
                        appendBlock(
                            translated,
                            to: result,
                            attributes: [
                                .font: platformFont(for: fontFamily, size: textSize * 0.92, weight: .regular),
                                .foregroundColor: secondaryColor,
                                .backgroundColor: PlatformColor(theme.embedBackgroundColor).withAlphaComponent(0.32),
                                .paragraphStyle: compactParagraph
                            ]
                        )
                    case .immersive:
                        appendBlock(
                            translated,
                            to: result,
                            attributes: [
                                .font: bodyFont,
                                .foregroundColor: foregroundColor,
                                .paragraphStyle: paragraph
                            ]
                        )
                    }
                } else {
                    appendBlock(
                        value,
                        to: result,
                        attributes: [
                            .font: bodyFont,
                            .foregroundColor: isTranslating ? translatingColor : foregroundColor,
                            .paragraphStyle: paragraph
                        ]
                    )
                }

            case .chapter(let title):
                guard showChapterMarkers else { continue }
                appendBlock(
                    String(format: L10n.novelChapterFormat, title),
                    to: result,
                    attributes: [
                        .font: boldFont,
                        .foregroundColor: foregroundColor,
                        .paragraphStyle: paragraph
                    ],
                    prefix: result.length == 0 ? "" : "\n"
                )

            case .ruby(let base, let reading):
                let line = NSMutableAttributedString(
                    string: base,
                    attributes: [
                        .font: bodyFont,
                        .foregroundColor: foregroundColor,
                        .paragraphStyle: paragraph
                    ]
                )
                line.append(NSAttributedString(
                    string: " (\(reading))",
                    attributes: [
                        .font: rubyFont,
                        .foregroundColor: secondaryColor,
                        .paragraphStyle: paragraph
                    ]
                ))
                result.append(line)
                result.append(NSAttributedString(string: "\n"))

            case .jumpURL(let label, let url):
                appendBlock(
                    label.isEmpty ? url.absoluteString : label,
                    to: result,
                    attributes: [
                        .font: linkFont,
                        .foregroundColor: platformLinkColor,
                        .link: url,
                        .paragraphStyle: paragraph
                    ]
                )

            case .jumpPage(let target):
                appendBlock(
                    String(format: L10n.novelJumpPageFormat, target),
                    to: result,
                    attributes: [
                        .font: linkFont,
                        .foregroundColor: secondaryColor,
                        .paragraphStyle: paragraph
                    ]
                )

            case .newPage, .pixivImage, .uploadedImage:
                break
            }
        }

        return result
    }

    private static func appendBlock(
        _ string: String,
        to result: NSMutableAttributedString,
        attributes: [NSAttributedString.Key: Any],
        prefix: String = ""
    ) {
        guard string.isEmpty == false else { return }
        if prefix.isEmpty == false {
            result.append(NSAttributedString(string: prefix, attributes: attributes))
        }
        result.append(NSAttributedString(string: string, attributes: attributes))
        if string.hasSuffix("\n") == false {
            result.append(NSAttributedString(string: "\n", attributes: attributes))
        }
    }

    private static func paragraphStyle(lineSpacing: Double, paragraphSpacing: Double) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = CGFloat(max(lineSpacing, 0))
        style.paragraphSpacing = CGFloat(max(paragraphSpacing, 0))
        return style
    }

    private static var platformLinkColor: PlatformColor {
        #if os(macOS)
        PlatformColor.linkColor
        #else
        PlatformColor.link
        #endif
    }
}

#if os(macOS)
private struct NativeNovelTextRepresentable: NSViewRepresentable {
    let attributedString: NSAttributedString
    let backgroundColor: NSColor
    let textColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false

        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = true
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        context.coordinator.textView = textView
        textView.textStorage?.setAttributedString(attributedString)
        context.coordinator.lastSignature = renderSignature
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        if context.coordinator.lastSignature != renderSignature {
            textView.textStorage?.setAttributedString(attributedString)
            context.coordinator.lastSignature = renderSignature
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var renderSignature: String {
        "\(attributedString.string.hashValue)-\(attributedString.length)-\(backgroundColor)-\(textColor)"
    }

    final class Coordinator {
        weak var textView: NSTextView?
        var lastSignature = ""
    }
}
#elseif os(iOS)
private struct NativeNovelTextRepresentable: UIViewRepresentable {
    let attributedString: NSAttributedString
    let backgroundColor: UIColor
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.link,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.attributedText = attributedString
        context.coordinator.lastSignature = renderSignature
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        if context.coordinator.lastSignature != renderSignature {
            textView.attributedText = attributedString
            context.coordinator.lastSignature = renderSignature
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var renderSignature: String {
        "\(attributedString.string.hashValue)-\(attributedString.length)-\(backgroundColor)-\(textColor)"
    }

    final class Coordinator {
        var lastSignature = ""
    }
}

private struct NativeNovelContinuousTextRepresentable: UIViewRepresentable {
    let attributedString: NSAttributedString
    let backgroundColor: UIColor
    let textColor: UIColor
    let maxContentWidth: CGFloat

    func makeUIView(context: Context) -> NativeNovelContinuousTextContainerView {
        let container = NativeNovelContinuousTextContainerView()
        container.configure(maxContentWidth: maxContentWidth)

        let textView = container.textView
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        textView.keyboardDismissMode = .interactive
        textView.contentInsetAdjustmentBehavior = .never
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 0, bottom: 36, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.link,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.attributedText = attributedString

        context.coordinator.lastSignature = renderSignature
        context.coordinator.lastPlainText = attributedString.string
        return container
    }

    func updateUIView(_ container: NativeNovelContinuousTextContainerView, context: Context) {
        container.configure(maxContentWidth: maxContentWidth)

        let textView = container.textView
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor

        guard context.coordinator.lastSignature != renderSignature else { return }

        let shouldResetScroll = context.coordinator.lastPlainText != attributedString.string
        let previousOffset = textView.contentOffset
        textView.attributedText = attributedString
        context.coordinator.lastSignature = renderSignature
        context.coordinator.lastPlainText = attributedString.string

        if shouldResetScroll {
            textView.setContentOffset(.zero, animated: false)
        } else {
            textView.setContentOffset(previousOffset, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var renderSignature: String {
        "\(attributedString.string.hashValue)-\(attributedString.length)-\(backgroundColor)-\(textColor)-\(maxContentWidth)"
    }

    final class Coordinator {
        var lastSignature = ""
        var lastPlainText = ""
    }
}

private final class NativeNovelContinuousTextContainerView: UIView {
    let textView = UITextView()

    private var maxWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(textView)

        let fillWidth = textView.widthAnchor.constraint(equalTo: layoutMarginsGuide.widthAnchor)
        fillWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            textView.centerXAnchor.constraint(equalTo: centerXAnchor),
            textView.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor),
            fillWidth
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(maxContentWidth: CGFloat) {
        let resolvedWidth = max(320, maxContentWidth)
        if let maxWidthConstraint {
            maxWidthConstraint.constant = resolvedWidth
        } else {
            let constraint = textView.widthAnchor.constraint(lessThanOrEqualToConstant: resolvedWidth)
            constraint.priority = .required
            constraint.isActive = true
            maxWidthConstraint = constraint
        }
    }
}
#endif

private enum NativeNovelFontWeight {
    case regular
    case medium
    case semibold
}

private func platformFont(
    for family: NovelReaderFontFamily,
    size: Double,
    weight: NativeNovelFontWeight
) -> Any {
    #if os(macOS)
    let nsWeight: NSFont.Weight
    switch weight {
    case .regular: nsWeight = .regular
    case .medium: nsWeight = .medium
    case .semibold: nsWeight = .semibold
    }
    switch family {
    case .system:
        return NSFont.systemFont(ofSize: CGFloat(size), weight: nsWeight)
    case .serif:
        return NSFont(descriptor: NSFontDescriptor(name: "Georgia", size: CGFloat(size)), size: CGFloat(size))
            ?? NSFont.systemFont(ofSize: CGFloat(size), weight: nsWeight)
    case .monospaced:
        return NSFont.monospacedSystemFont(ofSize: CGFloat(size), weight: nsWeight)
    }
    #else
    let uiWeight: UIFont.Weight
    switch weight {
    case .regular: uiWeight = .regular
    case .medium: uiWeight = .medium
    case .semibold: uiWeight = .semibold
    }
    switch family {
    case .system:
        let font = UIFont.systemFont(ofSize: CGFloat(size), weight: uiWeight)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    case .serif:
        let font = UIFont(descriptor: UIFontDescriptor(name: "Georgia", size: CGFloat(size)), size: CGFloat(size))
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    case .monospaced:
        let font = UIFont.monospacedSystemFont(ofSize: CGFloat(size), weight: uiWeight)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    }
    #endif
}
