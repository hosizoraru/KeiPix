import SwiftUI

extension View {
    func keiGlass(_ radius: CGFloat = 18) -> some View {
        let shape = ButtonBorderShape.roundedRectangle(radius: radius)
        return self
            .containerShape(shape)
            .glassEffect(.regular, in: shape)
    }

    func keiInteractiveGlass(_ radius: CGFloat = 18) -> some View {
        let shape = ButtonBorderShape.roundedRectangle(radius: radius)
        return self
            .containerShape(shape)
            .glassEffect(.regular.interactive(), in: shape)
    }

    @ViewBuilder
    func platformGlassControlBar(
        verticalPadding: CGFloat = 8,
        topPadding: CGFloat = 4,
        bottomPadding: CGFloat = 8
    ) -> some View {
        #if os(macOS)
        GlassEffectContainer(spacing: 12) {
            self
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, verticalPadding)
                .keiGlass(16)
        }
            .padding(.horizontal, 18)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        #else
        GlassEffectContainer(spacing: 12) {
            self
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, verticalPadding)
                .keiGlass(20)
        }
            .padding(.horizontal, 18)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        #endif
    }

    @ViewBuilder
    func keiPanel(_ radius: CGFloat = 16, clipsContent: Bool = false) -> some View {
        let shape = ButtonBorderShape.roundedRectangle(radius: radius)
        if clipsContent {
            self
                .containerShape(shape)
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 1)
                }
                .clipShape(shape)
        } else {
            self
                .containerShape(shape)
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func macOSWindowCompanionBackground() -> some View {
        #if os(macOS)
        if #available(macOS 27.0, *) {
            self.background(.windowBackground)
        } else {
            self.background(.background)
        }
        #else
        self.background(.background)
        #endif
    }

    func cardPadding() -> some View {
        padding(14)
    }
}

extension String {
    var htmlStripped: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
