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
                tone: .accent
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
                    tone: .accent,
                    isOn: store.settings_restoreReaderProgressBinding
                )
            }

            OS26SettingsSection(
                L10n.imageQualityTierSection,
                systemImage: "photo.stack",
                tone: .accent
            ) {
                OS26SettingsMenuPicker(
                    title: L10n.imageQualityTierSection,
                    value: store.sharedArtworkImageQualityTier.title,
                    detail: L10n.imageQualityTierHint,
                    systemImage: store.sharedArtworkImageQualityTier.systemImage,
                    tone: .accent,
                    selection: store.settings_artworkImageQualityTierBinding,
                    options: ArtworkImageQualityTier.allCases
                ) { tier, isSelected in
                    Label(tier.title, systemImage: isSelected ? "checkmark" : tier.systemImage)
                }
            }

            imageProcessingSection

            OS26SettingsSection(L10n.translate, systemImage: "translate", tone: .accent) {
                OS26SettingsMenuPicker(
                    title: L10n.translationTargetLanguage,
                    value: store.translationTargetLanguage.title,
                    detail: L10n.translationTargetLanguageHint,
                    systemImage: translationSystemImage(store.translationTargetLanguage),
                    tone: .accent,
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
                        role: .destructive,
                        tone: .danger
                    ) {
                        clearNovelTranslationCache()
                    }
                }
            }

            OS26SettingsSection(L10n.trackpad, systemImage: "trackpad", tone: .accent) {
                OS26SettingsToggleRow(
                    title: L10n.enableTrackpadGestures,
                    detail: L10n.trackpadGesturesHint,
                    systemImage: "hand.draw",
                    tone: .accent,
                    isOn: store.settings_trackpadGesturesBinding
                )

                OS26SettingsMenuPicker(
                    title: L10n.twoFingerSwipeBehavior,
                    value: store.horizontalSwipeBehavior.title,
                    detail: L10n.twoFingerSwipeBehaviorHint,
                    systemImage: swipeBehaviorSystemImage(store.horizontalSwipeBehavior),
                    tone: .accent,
                    selection: store.settings_horizontalSwipeBehaviorBinding,
                    options: TrackpadHorizontalSwipeBehavior.allCases
                ) { behavior, isSelected in
                    Label(behavior.title, systemImage: isSelected ? "checkmark" : swipeBehaviorSystemImage(behavior))
                }
            }
        }
    }

    private var imageProcessingSection: some View {
        OS26SettingsSection(
            L10n.imageProcessing,
            systemImage: "camera.filters",
            tone: .warning
        ) {
            OS26SettingsToggleRow(
                title: L10n.imageProcessorsEnabled,
                detail: L10n.imageProcessorsHint,
                systemImage: "wand.and.stars",
                tone: .warning,
                isOn: store.settings_imageProcessorsEnabledBinding
            )

            if store.imageProcessorsEnabled {
                OS26SettingsDivider()

                ForEach(ImageProcessorRegistry.allProcessors, id: \.identifier) { processor in
                    OS26SettingsToggleRow(
                        title: processor.displayName,
                        detail: nil,
                        systemImage: processorSystemImage(processor.identifier),
                        tone: processorSettingsTone(processor.identifier),
                        isOn: processorToggleBinding(for: processor.identifier)
                    )
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
            tone: .accent,
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

    private func processorSystemImage(_ identifier: String) -> String {
        switch identifier {
        case "smartCrop":
            "crop"
        case "sharpen":
            "sparkle.magnifyingglass"
        case "denoise":
            "circle.dotted"
        default:
            "camera.filters"
        }
    }

    private func processorSettingsTone(_ identifier: String) -> OS26SettingsTone {
        switch identifier {
        case "smartCrop":
            .warning
        default:
            .accent
        }
    }

    private func processorToggleBinding(for identifier: String) -> Binding<Bool> {
        Binding {
            store.activeImageProcessors.contains(identifier)
        } set: { enabled in
            var current = store.activeImageProcessors
            if enabled {
                if !current.contains(identifier) {
                    current.append(identifier)
                }
            } else {
                current.removeAll { $0 == identifier }
            }
            store.setActiveImageProcessors(current)
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
