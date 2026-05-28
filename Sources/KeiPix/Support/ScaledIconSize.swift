import SwiftUI

/// Scaled icon size that respects Dynamic Type settings.
///
/// Use for decorative icons in empty states, headers, and other
/// prominent positions where the icon should scale with text size.
struct ScaledIconSize {
    @ScaledMetric(relativeTo: .largeTitle) var large: CGFloat = 56
    @ScaledMetric(relativeTo: .title) var medium: CGFloat = 46
    @ScaledMetric(relativeTo: .title2) var small: CGFloat = 36
    @ScaledMetric(relativeTo: .headline) var tiny: CGFloat = 28

    static let shared = ScaledIconSize()
}

extension View {
    /// Apply a scaled icon size based on the text style.
    func scaledIconSize(_ style: Font.TextStyle = .largeTitle) -> some View {
        modifier(ScaledIconSizeModifier(style: style))
    }
}

private struct ScaledIconSizeModifier: ViewModifier {
    let style: Font.TextStyle
    @ScaledMetric private var size: CGFloat

    init(style: Font.TextStyle) {
        self.style = style
        let baseSize: CGFloat
        switch style {
        case .largeTitle: baseSize = 56
        case .title: baseSize = 46
        case .title2: baseSize = 36
        case .title3: baseSize = 28
        case .headline: baseSize = 24
        case .subheadline: baseSize = 20
        case .callout: baseSize = 18
        case .body: baseSize = 17
        case .footnote: baseSize = 15
        case .caption: baseSize = 13
        case .caption2: baseSize = 11
        @unknown default: baseSize = 46
        }
        _size = ScaledMetric(wrappedValue: baseSize, relativeTo: style)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
    }
}
