import SwiftUI

struct GeneralSettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        OS26SettingsPage(
            title: L10n.settingsGeneral,
            subtitle: L10n.themeHint,
            systemImage: SettingsCategory.general.systemImage
        ) {
            OS26SettingsSection(L10n.appearance, systemImage: "paintpalette", tone: .accent) {
                OS26SettingsMenuPicker(
                    title: L10n.language,
                    value: store.appLanguage.title,
                    detail: L10n.languageHint,
                    systemImage: "globe",
                    tone: .accent,
                    selection: store.settings_languageBinding,
                    options: AppLanguage.allCases
                ) { language, isSelected in
                    Label(language.title, systemImage: isSelected ? "checkmark" : languageSystemImage(language))
                }

                OS26SettingsMenuPicker(
                    title: L10n.theme,
                    value: store.appColorScheme.title,
                    detail: L10n.themeHint,
                    systemImage: store.appColorScheme.systemImage,
                    tone: .accent,
                    selection: store.settings_appColorSchemeBinding,
                    options: AppColorScheme.allCases
                ) { scheme, isSelected in
                    Label(scheme.title, systemImage: isSelected ? "checkmark" : scheme.systemImage)
                }

                OS26SettingsToggleRow(
                    title: L10n.showTranslatedTags,
                    detail: L10n.showTranslatedTagsHint,
                    systemImage: "character.book.closed",
                    tone: .accent,
                    isOn: store.settings_showTranslatedTagsBinding
                )
            }

            OS26SettingsSection(L10n.layout, systemImage: "rectangle.3.group", tone: .accent) {
                OS26SettingsMenuPicker(
                    title: L10n.galleryLayout,
                    value: store.galleryLayoutMode.title,
                    detail: L10n.galleryLayoutHint,
                    systemImage: store.galleryLayoutMode.systemImage,
                    tone: .accent,
                    selection: store.settings_galleryLayoutBinding,
                    options: GalleryLayoutMode.allCases
                ) { mode, isSelected in
                    Label(mode.title, systemImage: isSelected ? "checkmark" : mode.systemImage)
                }

                OS26SettingsToggleRow(
                    title: L10n.emphasizeFollowingArtists,
                    detail: L10n.emphasizeFollowingArtistsHint,
                    systemImage: "person.crop.circle.badge.checkmark",
                    tone: .accent,
                    isOn: store.settings_emphasizeFollowingArtistsBinding
                )
            }

            OS26SettingsSection(
                L10n.routeSwitchRefreshExpiration,
                systemImage: "clock.arrow.circlepath",
                tone: .accent
            ) {
                OS26SettingsMenuPicker(
                    title: L10n.routeSwitchRefreshExpiration,
                    value: store.routeSwitchRefreshExpiration.title,
                    detail: L10n.routeSwitchRefreshExpirationHint,
                    systemImage: store.routeSwitchRefreshExpiration.systemImage,
                    tone: .accent,
                    selection: store.settings_routeSwitchRefreshExpirationBinding,
                    options: RouteSwitchRefreshExpiration.allCases
                ) { expiration, isSelected in
                    Label(expiration.title, systemImage: isSelected ? "checkmark" : expiration.systemImage)
                }
            }

            #if os(macOS)
                OS26SettingsSection(L10n.openAtLaunch, systemImage: "arrow.up.forward.app", tone: .accent) {
                    OS26SettingsMenuPicker(
                        title: L10n.openAtLaunch,
                        value: store.launchDestination.title,
                        detail: L10n.openAtLaunchHint,
                        systemImage: store.launchDestination.systemImage,
                        tone: .accent,
                        selection: store.settings_launchDestinationBinding,
                        options: LaunchDestination.allCases
                    ) { destination, isSelected in
                        Label(destination.title, systemImage: isSelected ? "checkmark" : destination.systemImage)
                    }
                }
            #endif

            OS26SettingsSection(
                L10n.network,
                systemImage: "network",
                tone: .network,
                footer: store.proxyConfigurationMode == .manual ? L10n.proxyConfigurationRestartHint : nil
            ) {
                OS26SettingsMenuPicker(
                    title: L10n.proxyConfiguration,
                    value: title(for: store.proxyConfigurationMode),
                    detail: L10n.proxyConfigurationHint,
                    systemImage: proxyModeSystemImage(store.proxyConfigurationMode),
                    tone: .network,
                    selection: store.settings_proxyConfigurationModeBinding,
                    options: ProxyConfigurationMode.allCases
                ) { mode, isSelected in
                    Label(title(for: mode), systemImage: isSelected ? "checkmark" : proxyModeSystemImage(mode))
                }

                if store.proxyConfigurationMode == .manual {
                    OS26SettingsMenuPicker(
                        title: L10n.proxyScheme,
                        value: title(for: store.proxyConfigurationScheme),
                        detail: L10n.proxyConfigurationRestartHint,
                        systemImage: "point.3.connected.trianglepath.dotted",
                        tone: .network,
                        selection: store.settings_proxyConfigurationSchemeBinding,
                        options: ProxyScheme.allCases
                    ) { scheme, isSelected in
                        Label(title(for: scheme), systemImage: isSelected ? "checkmark" : "network")
                    }

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

            OS26SettingsSection(L10n.checkForUpdates, systemImage: "arrow.down.circle", tone: .downloads) {
                OS26SettingsToggleRow(
                    title: L10n.checkForUpdatesOnLaunch,
                    detail: L10n.checkForUpdatesOnLaunchHint,
                    systemImage: "calendar.badge.clock",
                    tone: .downloads,
                    isOn: store.settings_checkForUpdatesOnLaunchBinding
                )

                OS26SettingsActionButton(
                    title: store.isCheckingForUpdates ? L10n.checkingForUpdates : L10n.checkForUpdates,
                    systemImage: store.isCheckingForUpdates ? "arrow.triangle.2.circlepath" : "arrow.down.circle",
                    tone: .downloads
                ) {
                    Task { await store.checkForReleaseUpdateNow() }
                }
                .disabled(store.isCheckingForUpdates)
            }
        }
    }

    private func languageSystemImage(_ language: AppLanguage) -> String {
        switch language {
        case .automatic:
            "globe"
        case .simplifiedChinese, .traditionalChinese:
            "character.bubble"
        case .japanese:
            "textformat.characters"
        case .english:
            "textformat.abc"
        }
    }

    private func title(for mode: ProxyConfigurationMode) -> String {
        switch mode {
        case .system: L10n.proxyConfigurationModeSystem
        case .direct: L10n.proxyConfigurationModeDirect
        case .manual: L10n.proxyConfigurationModeManual
        }
    }

    private func title(for scheme: ProxyScheme) -> String {
        switch scheme {
        case .http: L10n.proxySchemeHTTP
        case .https: L10n.proxySchemeHTTPS
        case .socks5: L10n.proxySchemeSOCKS5
        }
    }

    private func proxyModeSystemImage(_ mode: ProxyConfigurationMode) -> String {
        switch mode {
        case .system:
            "gearshape.2"
        case .direct:
            "bolt.horizontal"
        case .manual:
            "slider.horizontal.3"
        }
    }
}
