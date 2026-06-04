import SwiftUI

struct GeneralSettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        OS26SettingsPage(
            title: L10n.settingsGeneral,
            subtitle: L10n.themeHint,
            systemImage: SettingsCategory.general.systemImage
        ) {
            OS26SettingsSection(L10n.appearance, systemImage: "paintpalette", footer: L10n.themeHint) {
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
            }

            OS26SettingsSection(
                L10n.imageQualityTierSection,
                systemImage: "photo.on.rectangle.angled",
                footer: L10n.imageQualityTierHint
            ) {
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
            }

            OS26SettingsSection(L10n.layout, systemImage: "rectangle.3.group", footer: L10n.emphasizeFollowingArtistsHint) {
                Picker(L10n.galleryLayout, selection: store.settings_galleryLayoutBinding) {
                    ForEach(GalleryLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.emphasizeFollowingArtists, isOn: store.settings_emphasizeFollowingArtistsBinding)
            }

            OS26SettingsSection(L10n.openAtLaunch, systemImage: "arrow.up.forward.app", footer: L10n.openAtLaunchHint) {
                Picker(L10n.openAtLaunch, selection: store.settings_launchDestinationBinding) {
                    ForEach(LaunchDestination.allCases) { destination in
                        Label(destination.title, systemImage: destination.systemImage)
                            .tag(destination)
                    }
                }
                .pickerStyle(.menu)
            }

            OS26SettingsSection(
                L10n.network,
                systemImage: "network",
                footer: "\(L10n.proxyConfigurationHint)\n\(L10n.proxyConfigurationRestartHint)"
            ) {
                Picker(L10n.proxyConfiguration, selection: store.settings_proxyConfigurationModeBinding) {
                    Text(L10n.proxyConfigurationModeSystem).tag(ProxyConfigurationMode.system)
                    Text(L10n.proxyConfigurationModeDirect).tag(ProxyConfigurationMode.direct)
                    Text(L10n.proxyConfigurationModeManual).tag(ProxyConfigurationMode.manual)
                }
                .pickerStyle(.menu)

                if store.proxyConfigurationMode == .manual {
                    Picker(L10n.proxyScheme, selection: store.settings_proxyConfigurationSchemeBinding) {
                        Text(L10n.proxySchemeHTTP).tag(ProxyScheme.http)
                        Text(L10n.proxySchemeHTTPS).tag(ProxyScheme.https)
                        Text(L10n.proxySchemeSOCKS5).tag(ProxyScheme.socks5)
                    }
                    .pickerStyle(.segmented)

                    OS26LibraryTextEntryField(
                        text: store.settings_proxyConfigurationHostBinding,
                        placeholder: L10n.proxyHostPlaceholder
                    )

                    OS26LibraryTextEntryField(
                        text: store.settings_proxyConfigurationPortBinding,
                        placeholder: L10n.proxyPortPlaceholder
                    )
                }
            }

            OS26SettingsSection(L10n.checkForUpdates, systemImage: "arrow.down.circle", footer: L10n.checkForUpdatesOnLaunchHint) {
                Toggle(L10n.checkForUpdatesOnLaunch, isOn: store.settings_checkForUpdatesOnLaunchBinding)

                OS26SettingsActionButton(
                    title: store.isCheckingForUpdates ? L10n.checkingForUpdates : L10n.checkForUpdates,
                    systemImage: store.isCheckingForUpdates ? "arrow.triangle.2.circlepath" : "arrow.down.circle"
                ) {
                    Task { await store.checkForReleaseUpdateNow() }
                }
                .disabled(store.isCheckingForUpdates)
            }
        }
    }
}
