import SwiftUI

struct FloatingStatusBanner<Content: View>: View {
    var maxWidth: CGFloat = 640
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .keiGlass(16)
            .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }
}
