import SwiftUI

struct GeneralSettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Form {
            Section {
                Picker(L10n.language, selection: store.settings_languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.theme, selection: store.settings_appColorSchemeBinding) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Label(scheme.title, systemImage: scheme.systemImage)
                            .tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.appearance)
            } footer: {
                Text(L10n.themeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(L10n.useOriginalImages, isOn: store.settings_useOriginalImagesBinding)
                Toggle(L10n.useOriginalImagesForManga, isOn: store.settings_useOriginalImagesForMangaBinding)
                Toggle(L10n.showTranslatedTags, isOn: store.settings_showTranslatedTagsBinding)
            } footer: {
                Text(L10n.imageQualityHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(L10n.galleryLayout, selection: store.settings_galleryLayoutBinding) {
                    ForEach(GalleryLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.layout)
            }

            Section {
                Picker(L10n.openAtLaunch, selection: store.settings_launchDestinationBinding) {
                    ForEach(LaunchDestination.allCases) { destination in
                        Label(destination.title, systemImage: destination.systemImage)
                            .tag(destination)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                Text(L10n.openAtLaunchHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsGeneral)
    }
}
