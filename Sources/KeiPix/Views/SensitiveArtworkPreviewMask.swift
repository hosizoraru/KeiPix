import SwiftUI

struct SensitiveArtworkPreviewMask: View {
    let badges: [ArtworkContentBadge]

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "eye.slash")
                .font(.title3.weight(.semibold))

            Text(maskTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
        .accessibilityLabel(maskTitle)
    }

    private var maskTitle: String {
        if badges.contains(.r18g) {
            L10n.r18gPreviewHidden
        } else {
            L10n.r18PreviewHidden
        }
    }
}

extension View {
    func sensitiveArtworkPreviewMasked(_ isMasked: Bool, badges: [ArtworkContentBadge]) -> some View {
        ZStack {
            self
                .blur(radius: isMasked ? 18 : 0)
                .saturation(isMasked ? 0.45 : 1)
                .scaleEffect(isMasked ? 1.04 : 1)

            if isMasked {
                Rectangle()
                    .fill(.black.opacity(0.2))

                SensitiveArtworkPreviewMask(badges: badges)
                    .padding(10)
            }
        }
        .clipped()
    }
}
