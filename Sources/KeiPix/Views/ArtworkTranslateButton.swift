import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif

// MARK: - Translation language resolver

/// Resolves the target language for translation based on the app's
/// language setting. Since Pixiv is a Japanese site, most content is
/// in Japanese — when the app language matches the source text, we
/// translate to Japanese as a sensible fallback.
enum TranslationLanguageResolver {
    /// Returns a `Locale.Language` suitable as the translation target.
    /// For `.automatic`, returns `nil` (system decides).
    static func targetLanguage(for appLanguage: AppLanguage) -> Locale.Language? {
        switch appLanguage {
        case .automatic:
            return nil
        case .simplifiedChinese:
            return Locale.Language(identifier: "zh-Hans")
        case .traditionalChinese:
            return Locale.Language(identifier: "zh-Hant")
        case .japanese:
            return Locale.Language(identifier: "ja")
        case .english:
            return Locale.Language(identifier: "en")
        }
    }

    /// Builds a `TranslationSession.Configuration` with the correct
    /// target language for the current app language. Source is always
    /// `nil` for auto-detection.
    static func configuration(for appLanguage: AppLanguage) -> TranslationSession.Configuration {
        let target = targetLanguage(for: appLanguage)
        return TranslationSession.Configuration(source: nil, target: target)
    }
}

// MARK: - Inline translate button

/// A compact icon-only toggle that activates inline bilingual
/// translation via Apple's `TranslationSession`. When active, the
/// accompanying `InlineTranslateSection` shows the translated text
/// above the original.
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
struct InlineTranslateSection<Content: View>: View {
    let text: String
    var appLanguage: AppLanguage = .automatic
    @ViewBuilder var content: Content

    @State private var isTranslateActive = false
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var translationConfig: TranslationSession.Configuration?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Spacer()
                InlineTranslateButton(isActive: $isTranslateActive)
            }

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
                translationConfig = TranslationLanguageResolver.configuration(for: appLanguage)
            } else {
                translatedText = nil
                isTranslating = false
                translationConfig = nil
            }
        }
        .onChange(of: text) { _, _ in
            if isTranslateActive, translationConfig != nil {
                translationConfig?.invalidate()
            }
        }
    }
}

// MARK: - Sheet-based translate (for lightweight contexts like comment rows)

/// Icon-only button that opens the system translation sheet.
/// Used in comment rows where wrapping each comment in
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
            .translationPresentation(isPresented: $isPresented, text: translatable)
            #endif
        }
    }
}
