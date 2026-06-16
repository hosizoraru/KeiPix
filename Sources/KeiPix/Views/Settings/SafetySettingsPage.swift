import SwiftUI

struct SafetySettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator
    var updateRestrictedMode: (Bool) async -> Void
    var updateAIShow: (Bool) async -> Void
    var syncFromPixiv: () async -> Void
    var uploadToPixiv: () async -> Void
    var importLocalFile: () -> Void
    var exportLocalFile: () -> Void

    var body: some View {
        OS26SettingsPage(
            title: L10n.settingsSafety,
            subtitle: L10n.maskSensitivePreviewsHint,
            systemImage: SettingsCategory.safety.systemImage
        ) {
            filtersSection
            mutedContentSection
            if store.session != nil {
                pixivSafetySection
            }
            privacyShortcutSection
        }
    }

    private var filtersSection: some View {
        OS26SettingsSection(L10n.contentFilters, systemImage: "line.3.horizontal.decrease.circle", tone: .safety) {
            OS26SettingsToggleRow(
                title: L10n.showContentBadges,
                detail: L10n.showContentBadgesHint,
                systemImage: "tag.circle",
                tone: .accent,
                isOn: store.settings_showContentBadgesBinding
            )
            OS26SettingsToggleRow(
                title: L10n.hideMutedContent,
                detail: L10n.hideMutedContentHint,
                systemImage: "eye.slash",
                tone: .safety,
                isOn: store.settings_hideMutedBinding
            )
            OS26SettingsToggleRow(
                title: L10n.hideAIArtworks,
                detail: L10n.hideAIArtworksHint,
                systemImage: "sparkles.square.filled.on.square",
                tone: .warning,
                isOn: store.settings_hideAIBinding
            )
            OS26SettingsToggleRow(
                title: L10n.hideR18Artworks,
                detail: L10n.hideR18ArtworksHint,
                systemImage: "exclamationmark.triangle",
                tone: .danger,
                isOn: store.settings_hideR18Binding
            )
            OS26SettingsToggleRow(
                title: L10n.hideR18GArtworks,
                detail: L10n.hideR18GArtworksHint,
                systemImage: "exclamationmark.octagon",
                tone: .danger,
                isOn: store.settings_hideR18GBinding
            )
            OS26SettingsToggleRow(
                title: L10n.maskSensitivePreviews,
                detail: L10n.maskSensitivePreviewsHint,
                systemImage: "rectangle.dashed.badge.record",
                tone: .privacy,
                isOn: store.settings_maskSensitivePreviewsBinding
            )
        }
    }

    private var pixivSafetySection: some View {
        OS26SettingsSection(L10n.pixivSection, systemImage: "shield.lefthalf.filled", tone: .safety) {
            pixivAccountToggleRow(
                title: L10n.pixivRestrictedMode,
                detail: L10n.pixivRestrictedModeHint,
                systemImage: "exclamationmark.shield",
                tone: .danger,
                isOn: restrictedModeBinding,
                isPending: store.restrictedModeEnabled == nil || coordinator.isUpdatingRestrictedMode
            )

            if let restrictedModeMessage = coordinator.restrictedModeMessage {
                Text(restrictedModeMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            pixivAccountToggleRow(
                title: L10n.pixivAIDisplay,
                detail: L10n.pixivAIDisplayHint,
                systemImage: "sparkles",
                tone: .warning,
                isOn: aiShowBinding,
                isPending: store.aiShowEnabled == nil || coordinator.isUpdatingAIShow
            )

            if let aiShowMessage = coordinator.aiShowMessage {
                Text(aiShowMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var mutedContentSection: some View {
        OS26SettingsSection(L10n.mutedContent, systemImage: "eye.slash", tone: .safety) {
            OS26SettingsControlRow(
                title: L10n.mutedContent,
                detail: L10n.muteSyncHint,
                systemImage: "list.bullet.rectangle",
                tone: .safety
            ) {
                Text(String(format: L10n.mutedContentCountFormat, mutedContentCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            OS26SettingsActionButton(title: L10n.openMutedContentManager, systemImage: "eye.slash", isProminent: true, tone: .safety) {
                store.select(.mutedContent)
            }

            FlowLayout(spacing: 8) {
                pixivPremiumSettingsActionButton(title: L10n.syncFromPixiv, systemImage: "arrow.down.circle") {
                    coordinator.isMutedContentSyncConfirmationPresented = true
                }
                .disabled(coordinator.isSyncingMutedContent)

                pixivPremiumSettingsActionButton(title: L10n.uploadToPixiv, systemImage: "arrow.up.circle") {
                    coordinator.isMutedContentUploadConfirmationPresented = true
                }
                .disabled(coordinator.isSyncingMutedContent
                    || (store.mutedTagList.isEmpty && store.mutedUserList.isEmpty))

                if coordinator.isSyncingMutedContent {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            FlowLayout(spacing: 8) {
                OS26SettingsActionButton(title: L10n.exportMutedContent, systemImage: "square.and.arrow.up", tone: .safety) {
                    exportLocalFile()
                }
                .disabled(coordinator.isSyncingMutedContent
                    || (store.mutedTagList.isEmpty
                        && store.mutedUserList.isEmpty
                        && store.mutedArtworkList.isEmpty))

                OS26SettingsActionButton(title: L10n.importMutedContent, systemImage: "square.and.arrow.down", tone: .safety) {
                    coordinator.isMutedContentImportConfirmationPresented = true
                }
                .disabled(coordinator.isSyncingMutedContent)
            }

            if let mutedContentMessage = coordinator.mutedContentMessage {
                Text(mutedContentMessage)
                    .font(.caption)
                    .foregroundStyle(coordinator.mutedContentMessageIsError ? .red : .secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var privacyShortcutSection: some View {
        // Privacy controls live on their own page now (mirroring macOS System
        // Settings → Privacy & Security). Keep a deep-link here so users
        // looking for "Privacy Mode" or "Show account identity" while
        // browsing Safety can pivot one click away.
        OS26SettingsSection(L10n.privacy, systemImage: SettingsCategory.privacy.systemImage, tone: .privacy, footer: L10n.privacyHint) {
            OS26SettingsActionButton(title: L10n.openPrivacySettings, systemImage: SettingsCategory.privacy.systemImage, tone: .privacy) {
                coordinator.selection = .privacy
            }
        }
    }

    private var mutedContentCount: Int {
        store.mutedTagList.count + store.mutedUserList.count + store.mutedArtworkList.count
    }

    private func pixivAccountToggleRow(
        title: String,
        detail: String,
        systemImage: String,
        tone: OS26SettingsTone,
        isOn: Binding<Bool>,
        isPending: Bool
    ) -> some View {
        OS26SettingsControlRow(title: title, detail: detail, systemImage: systemImage, tone: tone) {
            HStack(spacing: 8) {
                Toggle(title, isOn: isOn)
                    .labelsHidden()
                    .disabled(isPending)
                    .accessibilityLabel(title)

                if isPending {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func pixivPremiumSettingsActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            PixivPremiumInlineLabel(title: title, systemImage: systemImage)
                .lineLimit(1)
        }
        .os26GlassButton()
        .help(L10n.pixivPremiumRequired)
    }

    private var restrictedModeBinding: Binding<Bool> {
        Binding {
            store.restrictedModeEnabled ?? false
        } set: { value in
            Task { await updateRestrictedMode(value) }
        }
    }

    private var aiShowBinding: Binding<Bool> {
        Binding {
            store.aiShowEnabled ?? false
        } set: { value in
            Task { await updateAIShow(value) }
        }
    }
}
