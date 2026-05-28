import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif

// MARK: - Inline translate button

/// A compact icon-only toggle that activates inline bilingual
/// translation via Apple's `TranslationSession`. When active, the
/// accompanying `InlineTranslateSection` shows the translated text
/// above the original.
///
/// Replaces the old sheet-based `.translationPresentation` with an
/// immersive overlay that keeps the user in their reading flow.
struct InlineTranslateButton: View {
    @Binding var isActive: Bool

    var body: some View {
        Button {
            isActive.toggle()
        } label: {
            Label(L10n.translate, systemImage: "character.bubble")
        }
        .labelStyle(.iconOnly)
        .help(L10n.translate)
        .accessibilityLabel(L10n.translate)
        .buttonStyle(.borderless)
        .tint(isActive ? .accentColor : nil)
    }
}

// MARK: - Inline translate section

/// Wraps a block of text with an inline bilingual translation overlay.
/// When translation is active, shows the translated text above the
/// original in a secondary style. Uses Apple's `TranslationSession`
/// for on-demand translation without sheet popups.
///
/// Usage:
/// ```swift
/// InlineTranslateSection(text: caption) {
///     Text(caption)
///         .font(.callout)
/// }
/// ```
struct InlineTranslateSection<Content: View>: View {
    let text: String
    @ViewBuilder var content: Content

    @State private var isTranslateActive = false
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var translationConfig = TranslationSession.Configuration(source: nil, target: nil)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: translate toggle
            HStack(spacing: 6) {
                Spacer()
                InlineTranslateButton(isActive: $isTranslateActive)
            }

            // Translated text (when active)
            if isTranslateActive {
                if isTranslating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(L10n.translating)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let translatedText {
                    Text(translatedText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            // Original content
            content
        }
        #if canImport(Translation)
        .translationTask(translationConfig) { session in
            guard isTranslateActive else { return }
            let cleaned = CaptionTranslationAvailability.translatableText(from: text)
            guard let cleaned else { return }

            isTranslating = true
            translatedText = nil

            if let response = try? await session.translate(cleaned), isTranslateActive {
                translatedText = response.targetText
            } else if isTranslateActive {
                translatedText = L10n.translationFailed
            }
            isTranslating = false
        }
        #endif
        .onChange(of: isTranslateActive) { _, active in
            if active {
                // Bump config to trigger .translationTask
                translationConfig = TranslationSession.Configuration(source: nil, target: nil)
            } else {
                translatedText = nil
                isTranslating = false
            }
        }
    }
}

// MARK: - Legacy sheet-based button (kept for comments row usage)

/// The old sheet-based translate button, now icon-only. Still used
/// in comment rows where wrapping each comment in a full
/// `InlineTranslateSection` would be too heavy.
struct ArtworkTranslateButton: View {
    let text: String

    @State private var isPresented = false

    var body: some View {
        if let translatable = CaptionTranslationAvailability.translatableText(from: text) {
            Button {
                isPresented = true
            } label: {
                Label(L10n.translate, systemImage: "character.bubble")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(L10n.translate)
            .accessibilityLabel(L10n.translate)
            #if canImport(Translation)
            .modifier(TranslationPresentationModifier(text: translatable, isPresented: $isPresented))
            #endif
        }
    }
}

#if canImport(Translation)
private struct TranslationPresentationModifier: ViewModifier {
    let text: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if #available(macOS 14.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else {
            content
        }
    }
}
#endif
