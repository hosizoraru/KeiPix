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
