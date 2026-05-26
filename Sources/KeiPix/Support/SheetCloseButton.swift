import SwiftUI

/// Standardised close affordance for sheets.
///
/// Every sheet in the app should expose a *visible* dismiss control. macOS
/// users can press Esc, but iPad/iPhone builds and any context where the
/// user reaches for the pointer first need a real button. Keeping the
/// affordance in one place means we can tweak the look once and stay
/// consistent across every sheet.
///
/// Use `SheetCloseButton` directly when the sheet has its own custom
/// header (e.g. a profile banner) and just needs an X tucked into a
/// corner. Use `sheetCloseButton(_:)` on a `View` to overlay the standard
/// top-trailing close button for sheets that don't already pad a corner
/// with controls. For the standard "title + actions + close" header
/// layout most sheets want, reach for `SheetHeaderRail` instead.
struct SheetCloseButton: View {
    /// Optional explicit dismiss handler for cases where the sheet owns
    /// extra cleanup (e.g. clearing a presentation flag on the store) on
    /// top of `@Environment(\.dismiss)`. When `nil` the button calls
    /// `dismiss()` directly.
    var action: (() -> Void)?
    /// Picks between a plain icon and a bordered chip. Sheets with a busy
    /// header typically use `.plain` so the X doesn't compete with other
    /// controls; standalone overlay buttons use `.bordered`.
    var style: Style = .bordered

    @Environment(\.dismiss) private var dismiss

    enum Style {
        case plain
        case bordered
    }

    var body: some View {
        Button {
            if let action {
                action()
            } else {
                dismiss()
            }
        } label: {
            Label(L10n.close, systemImage: "xmark")
        }
        .labelStyle(.iconOnly)
        .modifier(StyleModifier(style: style))
        .keyboardShortcut(.cancelAction)
        .help(L10n.close)
        .accessibilityLabel(L10n.close)
    }

    private struct StyleModifier: ViewModifier {
        let style: Style

        func body(content: Content) -> some View {
            switch style {
            case .plain:
                content
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .contentShape(Circle())
            case .bordered:
                content
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

extension View {
    /// Overlays a top-trailing close button on a sheet body. Use this for
    /// sheets whose body fills the surface and don't already place
    /// controls in the top-trailing corner.
    func sheetCloseButton(action: (() -> Void)? = nil) -> some View {
        overlay(alignment: .topTrailing) {
            SheetCloseButton(action: action, style: .plain)
                .padding(.top, 10)
                .padding(.trailing, 12)
        }
    }

    /// Apply standard sheet chrome that travels well to iPadOS / iOS.
    ///
    /// On macOS the call is largely a no-op — `presentationDragIndicator`
    /// has no visible effect when the sheet is rendered as a window — but
    /// having it baked into every sheet means we don't have to grep
    /// through the codebase when we ship the iPad build. iPad users get
    /// the system grabber + drag-to-dismiss for free, matching every
    /// other modal sheet on the platform.
    ///
    /// Pair this with a `SheetCloseButton` (or `SheetHeaderRail`) inside
    /// the sheet body so pointer users always have a visible escape
    /// hatch, even on platforms where there's no Esc key handy.
    func iPadFriendlySheet() -> some View {
        self.presentationDragIndicator(.visible)
    }
}
