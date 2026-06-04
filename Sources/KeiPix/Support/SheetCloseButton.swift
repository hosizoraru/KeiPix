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
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .foregroundStyle(.secondary)
            case .bordered:
                content
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
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

    /// Applies the shared OS 26 sheet presentation contract.
    ///
    /// SwiftUI's own sheet surface already picks up most Liquid Glass
    /// behavior. This modifier keeps the app-level contract consistent:
    /// iPhone/iPad sheets get system grabbers, detents, material
    /// presentation backgrounds, and rounded presentation corners, while
    /// macOS sheets stay inside the native sheet/window presentation
    /// without custom opaque chrome fighting the system.
    ///
    /// Pair this with `SheetHeaderRail` or `SheetCloseButton` inside the
    /// sheet body so pointer and keyboard users always have an explicit
    /// dismissal path.
    func os26SheetChrome(_ style: OS26SheetPresentationStyle = .standard) -> some View {
        modifier(OS26SheetChromeModifier(style: style))
    }

    /// Back-compatibility for existing call sites. New sheet code should
    /// prefer `os26SheetChrome(_:)` so the intended presentation size is
    /// visible at the call site.
    func iPadFriendlySheet() -> some View {
        os26SheetChrome()
    }
}

enum OS26SheetPresentationStyle {
    /// Form-sized sheet for compact utility tasks such as token import,
    /// quick-open, feedback, and dashboard customization.
    case form
    /// Balanced default for sheets with moderate scrollable content.
    case standard
    /// Full-height editorial/detail sheet, e.g. creator profiles and
    /// reverse image search.
    case detail
    /// System web or reader surfaces that should start at the large
    /// detent and avoid presenting as a half sheet.
    case immersive
    /// Reader surfaces need wider, page-like sizing on iPad/macOS while
    /// staying full-height and touch-first on iPhone.
    case reader

    var cornerRadius: CGFloat {
        switch self {
        case .form:
            24
        case .standard:
            28
        case .detail, .immersive, .reader:
            32
        }
    }

    #if os(iOS)
    @MainActor
    var detents: Set<PresentationDetent> {
        switch self {
        case .form:
            return [.medium, .large]
        case .standard:
            return [.medium, .large]
        case .detail:
            return [.large]
        case .immersive:
            return [.large]
        case .reader:
            if ReaderPlatformKind.current == .phone {
                return [.large]
            }
            return [.fraction(0.88), .large]
        }
    }
    #endif
}

private struct OS26SheetChromeModifier: ViewModifier {
    let style: OS26SheetPresentationStyle

    func body(content: Content) -> some View {
        #if os(iOS)
        sizedContent(content)
            .presentationDragIndicator(.visible)
            .presentationDetents(style.detents)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(style.cornerRadius)
            .presentationContentInteraction(.scrolls)
        #else
        sizedContent(content)
            .presentationDragIndicator(.visible)
        #endif
    }

    @ViewBuilder
    private func sizedContent(_ content: Content) -> some View {
        switch style {
        case .form, .standard:
            content
                .presentationSizing(.form)
        case .detail:
            content
                .presentationSizing(.page)
        case .immersive, .reader:
            content
                .presentationSizing(.page)
        }
    }
}
