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
                GeneralSettingsMenuPicker(
                    title: L10n.language,
                    value: store.appLanguage.title,
                    selection: store.settings_languageBinding,
                    options: AppLanguage.allCases
                ) { language, isSelected in
                    if isSelected {
                        Label(language.title, systemImage: "checkmark")
                    } else {
                        Text(language.title)
                    }
                }

                GeneralSettingsMenuPicker(
                    title: L10n.theme,
                    value: store.appColorScheme.title,
                    selection: store.settings_appColorSchemeBinding,
                    options: AppColorScheme.allCases
                ) { scheme, isSelected in
                    Label(scheme.title, systemImage: isSelected ? "checkmark" : scheme.systemImage)
                }
            }

            OS26SettingsSection(
                L10n.imageQualityTierSection,
                systemImage: "photo.on.rectangle.angled",
                footer: L10n.imageQualityTierHint
            ) {
                GeneralSettingsMenuPicker(
                    title: L10n.feedPreviewQuality,
                    value: store.feedPreviewImageQualityTier.title,
                    selection: store.settings_feedPreviewImageQualityTierBinding,
                    options: ArtworkImageQualityTier.allCases
                ) { tier, isSelected in
                    Label(tier.title, systemImage: isSelected ? "checkmark" : tier.systemImage)
                }

                GeneralSettingsMenuPicker(
                    title: L10n.illustDetailQuality,
                    value: store.illustDetailImageQualityTier.title,
                    selection: store.settings_illustDetailImageQualityTierBinding,
                    options: ArtworkImageQualityTier.allCases
                ) { tier, isSelected in
                    Label(tier.title, systemImage: isSelected ? "checkmark" : tier.systemImage)
                }

                GeneralSettingsMenuPicker(
                    title: L10n.mangaDetailQuality,
                    value: store.mangaDetailImageQualityTier.title,
                    selection: store.settings_mangaDetailImageQualityTierBinding,
                    options: ArtworkImageQualityTier.allCases
                ) { tier, isSelected in
                    Label(tier.title, systemImage: isSelected ? "checkmark" : tier.systemImage)
                }

                Toggle(L10n.showTranslatedTags, isOn: store.settings_showTranslatedTagsBinding)
            }

            OS26SettingsSection(L10n.layout, systemImage: "rectangle.3.group", footer: L10n.emphasizeFollowingArtistsHint) {
                GeneralSettingsMenuPicker(
                    title: L10n.galleryLayout,
                    value: store.galleryLayoutMode.title,
                    selection: store.settings_galleryLayoutBinding,
                    options: GalleryLayoutMode.allCases
                ) { mode, isSelected in
                    Label(mode.title, systemImage: isSelected ? "checkmark" : mode.systemImage)
                }

                Toggle(L10n.emphasizeFollowingArtists, isOn: store.settings_emphasizeFollowingArtistsBinding)
            }

            #if os(macOS)
            OS26SettingsSection(L10n.openAtLaunch, systemImage: "arrow.up.forward.app", footer: L10n.openAtLaunchHint) {
                GeneralSettingsMenuPicker(
                    title: L10n.openAtLaunch,
                    value: store.launchDestination.title,
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
                footer: "\(L10n.proxyConfigurationHint)\n\(L10n.proxyConfigurationRestartHint)"
            ) {
                GeneralSettingsMenuPicker(
                    title: L10n.proxyConfiguration,
                    value: title(for: store.proxyConfigurationMode),
                    selection: store.settings_proxyConfigurationModeBinding,
                    options: ProxyConfigurationMode.allCases
                ) { mode, isSelected in
                    if isSelected {
                        Label(title(for: mode), systemImage: "checkmark")
                    } else {
                        Text(title(for: mode))
                    }
                }

                if store.proxyConfigurationMode == .manual {
                    GeneralSettingsMenuPicker(
                        title: L10n.proxyScheme,
                        value: title(for: store.proxyConfigurationScheme),
                        selection: store.settings_proxyConfigurationSchemeBinding,
                        options: ProxyScheme.allCases
                    ) { scheme, isSelected in
                        if isSelected {
                            Label(title(for: scheme), systemImage: "checkmark")
                        } else {
                            Text(title(for: scheme))
                        }
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
}

private struct GeneralSettingsMenuPicker<Option: Identifiable & Hashable, RowLabel: View>: View {
    let title: String
    let value: String
    @Binding private var selection: Option
    private let options: [Option]
    private let rowLabel: (Option, Bool) -> RowLabel

    init(
        title: String,
        value: String,
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder rowLabel: @escaping (Option, Bool) -> RowLabel
    ) {
        self.title = title
        self.value = value
        _selection = selection
        self.options = options
        self.rowLabel = rowLabel
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    rowLabel(option, option == selection)
                }
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    titleText
                    Spacer(minLength: 8)
                    valueText
                    menuChevron
                }

                VStack(alignment: .leading, spacing: 4) {
                    titleText
                    HStack(spacing: 6) {
                        valueText
                        menuChevron
                    }
                }
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }

    private var titleText: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.84)
    }

    private var valueText: some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(0.82)
    }

    private var menuChevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(.tertiary)
    }
}
