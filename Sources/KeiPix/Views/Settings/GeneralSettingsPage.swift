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
                Picker(L10n.feedPreviewQuality, selection: store.settings_feedPreviewImageQualityTierBinding) {
                    ForEach(ArtworkImageQualityTier.allCases) { tier in
                        Label(tier.title, systemImage: tier.systemImage).tag(tier)
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.illustDetailQuality, selection: store.settings_illustDetailImageQualityTierBinding) {
                    ForEach(ArtworkImageQualityTier.allCases) { tier in
                        Label(tier.title, systemImage: tier.systemImage).tag(tier)
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.mangaDetailQuality, selection: store.settings_mangaDetailImageQualityTierBinding) {
                    ForEach(ArtworkImageQualityTier.allCases) { tier in
                        Label(tier.title, systemImage: tier.systemImage).tag(tier)
                    }
                }
                .pickerStyle(.menu)

                Toggle(L10n.showTranslatedTags, isOn: store.settings_showTranslatedTagsBinding)
            } header: {
                Text(L10n.imageQualityTierSection)
            } footer: {
                Text(L10n.imageQualityTierHint)
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

                Toggle(L10n.emphasizeFollowingArtists, isOn: store.settings_emphasizeFollowingArtistsBinding)
            } header: {
                Text(L10n.layout)
            } footer: {
                Text(L10n.emphasizeFollowingArtistsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
