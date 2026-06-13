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
                systemImage: "book.pages",
                footer: "\(L10n.defaultReadingModeHint)\n\(L10n.restoreLastReadPageHint)"
            ) {
                Picker(L10n.defaultArtworkReadingMode, selection: store.settings_defaultArtworkReadingModeBinding) {
                    ForEach(ArtworkReadingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.defaultMangaReadingMode, selection: store.settings_defaultMangaReadingModeBinding) {
                    ForEach(ArtworkReadingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.restoreLastReadPage, isOn: store.settings_restoreReaderProgressBinding)
            }

            OS26SettingsSection(L10n.translate, systemImage: "translate", footer: L10n.translationTargetLanguageHint) {
                Picker(L10n.translationTargetLanguage, selection: store.settings_translationTargetLanguageBinding) {
                    ForEach(TranslationTargetLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.menu)

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
                Toggle(L10n.enableTrackpadGestures, isOn: store.settings_trackpadGesturesBinding)

                Picker(L10n.twoFingerSwipeBehavior, selection: store.settings_horizontalSwipeBehaviorBinding) {
                    ForEach(TrackpadHorizontalSwipeBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
            }
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
