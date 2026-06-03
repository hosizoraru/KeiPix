import SwiftUI

/// Standard one-row header for sheets across the app.
///
/// Most sheets (`BookmarkEditorView`, `FeedbackReportSheet`,
/// `ImageSourceSearchSheet`, `PixivIDOpenSheet`, …) used to roll their
/// own header layout: a `VStack { title, subtitle }` on the left,
/// `Spacer`, and a `SheetCloseButton` on the right. That pattern was
/// fine for the bare close button, but as soon as we wanted to surface
/// frequently used actions (open in Pixiv, copy link, paste from
/// clipboard) every sheet grew its own bespoke `HStack` of bordered
/// chips — easy to drift, hard to keep consistent.
///
/// `SheetHeaderRail` is the shared chrome instead. Following the same
/// pattern as `UserProfileSheetHeader`, it lays out:
///
///   1. a leading visual (thumbnail, icon, or any custom view),
///   2. the identity block (title + optional subtitle / overline),
///   3. an action rail of always-visible buttons,
///   4. the close button on the very trailing edge.
///
/// The action rail follows Apple HIG: standalone bordered chips for
/// frequent actions, `.glassProminent` reserved for a single primary
/// CTA. Keep the action count modest (≤ 3) and let truly low-priority
/// destructive items live in a `Menu` next to the rail.
///
/// Pure presentation — every action is a closure handed in by the
/// parent. The view never reads the store directly.
struct SheetHeaderRail<Leading: View, Trailing: View>: View {
    /// Optional one-word kicker drawn above the title, e.g. the
    /// section name (`Bookmark`, `Feedback / Mute`). Helps when the
    /// title itself is the artwork title or user name and could
    /// otherwise be mistaken for the heading.
    var overline: String? = nil
    let title: String
    var subtitle: String? = nil

    /// Caller-provided leading visual. Use `EmptyView()` to omit.
    @ViewBuilder var leading: () -> Leading

    /// Caller-provided action rail. Render bordered `Button` chips
    /// here — the close button is appended automatically.
    @ViewBuilder var trailing: () -> Trailing

    /// Optional explicit close handler for sheets that need extra
    /// cleanup beyond `@Environment(\.dismiss)`.
    var closeAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            leading()

            VStack(alignment: .leading, spacing: 3) {
                if let overline {
                    Text(overline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                }

                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                trailing()
                SheetCloseButton(action: closeAction, style: .plain)
            }
        }
        .platformGlassControlBar(verticalPadding: 12, topPadding: 8, bottomPadding: 8)
    }
}

// Convenience overload: header without a leading visual (icon/title-only sheets).
extension SheetHeaderRail where Leading == EmptyView {
    init(
        overline: String? = nil,
        title: String,
        subtitle: String? = nil,
        closeAction: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.init(
            overline: overline,
            title: title,
            subtitle: subtitle,
            leading: { EmptyView() },
            trailing: trailing,
            closeAction: closeAction
        )
    }
}

// Convenience overload: header without an action rail (only the
// close button is rendered on the trailing edge).
extension SheetHeaderRail where Trailing == EmptyView {
    init(
        overline: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        closeAction: (() -> Void)? = nil
    ) {
        self.init(
            overline: overline,
            title: title,
            subtitle: subtitle,
            leading: leading,
            trailing: { EmptyView() },
            closeAction: closeAction
        )
    }
}

// Both leading + trailing omitted: bare title row with just close.
extension SheetHeaderRail where Leading == EmptyView, Trailing == EmptyView {
    init(
        overline: String? = nil,
        title: String,
        subtitle: String? = nil,
        closeAction: (() -> Void)? = nil
    ) {
        self.init(
            overline: overline,
            title: title,
            subtitle: subtitle,
            leading: { EmptyView() },
            trailing: { EmptyView() },
            closeAction: closeAction
        )
    }
}

/// Convenience leading visual: a thumbnail or remote image.
struct SheetHeaderThumbnail: View {
    let url: URL?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 10

    var body: some View {
        RemoteImageView(url: url)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

/// Convenience leading visual: a tinted SF Symbol tile.
///
/// Mirrors the icon treatment used in App Store / Settings sheets —
/// rounded square, tint-colored fill, hierarchical glyph. Keeps title-
/// only sheets visually anchored without an external image asset.
struct SheetHeaderIcon: View {
    let systemImage: String
    var tint: Color = .accentColor
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.18))
            Image(systemName: systemImage)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

/// Standard chip for the action rail.
///
/// Keeps the styling consistent (bordered, small) and the tooltip /
/// accessibility plumbing in one place so callers only have to think
/// about what the action does.
struct SheetHeaderActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    var role: ButtonRole? = nil
    var isDisabled: Bool = false

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
        .accessibilityLabel(title)
        .disabled(isDisabled)
    }
}
