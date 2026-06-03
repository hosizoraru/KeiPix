import SwiftUI

extension View {
    func keiGlass(_ radius: CGFloat = 18) -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func keiInteractiveGlass(_ radius: CGFloat = 18) -> some View {
        self
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    @ViewBuilder
    func platformGlassControlBar(
        verticalPadding: CGFloat = 8,
        topPadding: CGFloat = 4,
        bottomPadding: CGFloat = 8
    ) -> some View {
        #if os(macOS)
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .keiGlass(16)
            .padding(.horizontal, 18)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        #else
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, verticalPadding)
            .keiGlass(20)
            .padding(.horizontal, 18)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        #endif
    }

    func keiPanel(_ radius: CGFloat = 16) -> some View {
        self
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
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
