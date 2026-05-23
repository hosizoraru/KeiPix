import SwiftUI

struct ArtworkContentBadgesView: View {
    let badges: [ArtworkContentBadge]
    var style: Style = .regular

    enum Style {
        case regular
        case compact
        case overlay
    }

    var body: some View {
        if badges.isEmpty == false {
            FlowLayout(spacing: style == .compact ? 4 : 6) {
                ForEach(badges) { badge in
                    Label(badge.title, systemImage: badge.systemImage)
                        .font(font)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .foregroundStyle(foreground(for: badge))
                        .background(background(for: badge), in: Capsule())
                        .help(badge.title)
                }
            }
        }
    }

    private var font: Font {
        switch style {
        case .regular:
            .caption.weight(.semibold)
        case .compact, .overlay:
            .caption2.weight(.bold)
        }
    }

    private var horizontalPadding: CGFloat {
        style == .regular ? 8 : 6
    }

    private var verticalPadding: CGFloat {
        style == .regular ? 4 : 3
    }

    private func foreground(for badge: ArtworkContentBadge) -> some ShapeStyle {
        switch style {
        case .overlay:
            AnyShapeStyle(.white)
        case .regular, .compact:
            AnyShapeStyle(tint(for: badge))
        }
    }

    private func background(for badge: ArtworkContentBadge) -> some ShapeStyle {
        switch style {
        case .overlay:
            AnyShapeStyle(tint(for: badge).opacity(0.74))
        case .regular, .compact:
            AnyShapeStyle(tint(for: badge).opacity(0.16))
        }
    }

    private func tint(for badge: ArtworkContentBadge) -> Color {
        switch badge {
        case .aiGenerated:
            .purple
        case .r18:
            .orange
        case .r18g:
            .red
        case .ugoira:
            .blue
        case .muted:
            .secondary
        }
    }
}
