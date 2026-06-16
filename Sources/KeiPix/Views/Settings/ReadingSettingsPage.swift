import SwiftUI

struct ReadingSettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        OS26SettingsPage(
            title: L10n.readingWindow,
            subtitle: L10n.defaultReadingModeHint,
            systemImage: SettingsCategory.reading.systemImage
        ) {
            OS26SettingsSection(
                L10n.readingWindow,
                systemImage: "book.pages"
            ) {
                readingModePicker(
                    title: L10n.defaultArtworkReadingMode,
                    value: store.defaultArtworkReadingMode,
                    detail: L10n.defaultArtworkReadingModeHint,
                    selection: store.settings_defaultArtworkReadingModeBinding
                )

                readingModePicker(
                    title: L10n.defaultMangaReadingMode,
                    value: store.defaultMangaReadingMode,
                    detail: L10n.defaultMangaReadingModeHint,
                    selection: store.settings_defaultMangaReadingModeBinding
                )

                OS26SettingsToggleRow(
                    title: L10n.restoreLastReadPage,
                    detail: L10n.restoreLastReadPageHint,
                    systemImage: "clock.arrow.circlepath",
                    isOn: store.settings_restoreReaderProgressBinding
                )
            }

            OS26SettingsSection(L10n.translate, systemImage: "translate") {
                OS26SettingsMenuPicker(
                    title: L10n.translationTargetLanguage,
                    value: store.translationTargetLanguage.title,
                    detail: L10n.translationTargetLanguageHint,
                    systemImage: translationSystemImage(store.translationTargetLanguage),
                    selection: store.settings_translationTargetLanguageBinding,
                    options: TranslationTargetLanguage.allCases
                ) { language, isSelected in
                    Label(language.title, systemImage: isSelected ? "checkmark" : translationSystemImage(language))
                }

                HStack {
                    Spacer()
                    OS26SettingsActionButton(
                        title: L10n.clearNovelTranslationCache,
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        clearNovelTranslationCache()
                    }
                }
            }

            OS26SettingsSection(L10n.trackpad, systemImage: "trackpad") {
                OS26SettingsToggleRow(
                    title: L10n.enableTrackpadGestures,
                    detail: L10n.trackpadGesturesHint,
                    systemImage: "hand.draw",
                    isOn: store.settings_trackpadGesturesBinding
                )

                OS26SettingsMenuPicker(
                    title: L10n.twoFingerSwipeBehavior,
                    value: store.horizontalSwipeBehavior.title,
                    detail: L10n.twoFingerSwipeBehaviorHint,
                    systemImage: swipeBehaviorSystemImage(store.horizontalSwipeBehavior),
                    selection: store.settings_horizontalSwipeBehaviorBinding,
                    options: TrackpadHorizontalSwipeBehavior.allCases
                ) { behavior, isSelected in
                    Label(behavior.title, systemImage: isSelected ? "checkmark" : swipeBehaviorSystemImage(behavior))
                }
            }
        }
    }

    private func readingModePicker(
        title: String,
        value: ArtworkReadingMode,
        detail: String,
        selection: Binding<ArtworkReadingMode>
    ) -> some View {
        OS26SettingsMenuPicker(
            title: title,
            value: value.title,
            detail: detail,
            systemImage: value.systemImage,
            selection: selection,
            options: ArtworkReadingMode.allCases
        ) { mode, isSelected in
            Label(mode.title, systemImage: isSelected ? "checkmark" : mode.systemImage)
        }
    }

    private func translationSystemImage(_ language: TranslationTargetLanguage) -> String {
        switch language {
        case .system:
            "globe"
        case .simplifiedChinese, .traditionalChinese:
            "character.bubble"
        case .japanese:
            "textformat.characters"
        case .english:
            "textformat.abc"
        }
    }

    private func swipeBehaviorSystemImage(_ behavior: TrackpadHorizontalSwipeBehavior) -> String {
        switch behavior {
        case .pageOnly:
            "rectangle"
        case .pageThenArtworkAtEdges:
            "rectangle.stack.badge.play"
        }
    }

    private func clearNovelTranslationCache() {
        do {
            try NovelTranslationDiskCache().clear()
            coordinator.setActionMessage(L10n.novelTranslationCacheCleared)
        } catch {
            coordinator.setActionMessage(L10n.translationFailed)
        }
    }
}
