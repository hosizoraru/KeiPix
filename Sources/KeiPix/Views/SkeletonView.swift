import SwiftUI

/// A shimmering placeholder view that indicates content is loading.
///
/// Replaces `ProgressView()` spinners with a more polished loading
/// experience. The shimmer effect animates a gradient across the
/// placeholder shape.
struct SkeletonView: ViewModifier {
    var cornerRadius: CGFloat = 8
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        GeometryReader { proxy in
                            let width = proxy.size.width
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.15),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: width * 0.5)
                            .offset(x: isAnimating ? width : -width * 0.5)
                        }
                        .mask(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                    }
                    .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    /// Apply a skeleton shimmer effect to indicate loading state.
    func skeleton(cornerRadius: CGFloat = 8) -> some View {
        modifier(SkeletonView(cornerRadius: cornerRadius))
    }
}

/// A rectangular skeleton placeholder for image loading.
struct SkeletonPlaceholder: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)
            .frame(width: width, height: height)
            .skeleton(cornerRadius: cornerRadius)
    }
}
