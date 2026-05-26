import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// A compact "Translate" button that opens Apple's system translation
/// presentation for a chunk of user-visible text. Used on artwork
/// captions and comment bodies where Pixiv content is frequently
/// Japanese / Chinese and the user wants a quick read in their own
/// language.
///
/// We deliberately lean on the Apple-supplied
/// `.translationPresentation(isPresented:text:)` modifier instead of
/// rolling our own UI — it ships the language picker, "show original",
/// and copy actions for free, and matches the affordance Safari /
/// Mail / Messages already use on macOS so the gesture feels native.
///
/// Visibility is gated by `CaptionTranslationAvailability` so we don't
/// surface the button for empty captions or pure-emoji blurbs that
/// Translate can't usefully process.
struct ArtworkTranslateButton: View {
    let text: String
    var style: Style = .compact

    @State private var isPresented = false

    enum Style {
        /// Borderless caption-row glyph paired with `Translate`. Used
        /// inline next to caption / comment text.
        case compact
        /// Bordered button with full label. Used as a primary action
        /// inside the caption inspector.
        case prominent
    }

    var body: some View {
        if let translatable = CaptionTranslationAvailability.translatableText(from: text) {
            button(translatable)
        }
    }

    @ViewBuilder
    private func button(_ translatable: String) -> some View {
        switch style {
        case .compact:
            compactButton(translatable)
        case .prominent:
            prominentButton(translatable)
        }
    }

    private func compactButton(_ translatable: String) -> some View {
        Button {
            isPresented = true
        } label: {
            Label(L10n.translate, systemImage: "character.bubble")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.medium))
        }
        .buttonStyle(.borderless)
        .help(L10n.translateCaptionHelp)
        .modifier(TranslationPresentationModifier(text: translatable, isPresented: $isPresented))
    }

    private func prominentButton(_ translatable: String) -> some View {
        Button {
            isPresented = true
        } label: {
            Label(L10n.translate, systemImage: "character.bubble")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(L10n.translateCaptionHelp)
        .modifier(TranslationPresentationModifier(text: translatable, isPresented: $isPresented))
    }
}

/// Wraps the Apple `translationPresentation` modifier behind an
/// availability check so KeiPix keeps building if the SDK ever drops
/// the Translation framework (e.g. on a non-macOS slice). On every
/// supported macOS 26 build the modifier resolves at compile time.
private struct TranslationPresentationModifier: ViewModifier {
    let text: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(macOS 14.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
