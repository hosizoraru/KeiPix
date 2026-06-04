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
        OS26SettingsSection(L10n.contentFilters, systemImage: "line.3.horizontal.decrease.circle", footer: L10n.maskSensitivePreviewsHint) {
            Toggle(L10n.showContentBadges, isOn: store.settings_showContentBadgesBinding)
            Toggle(L10n.hideMutedContent, isOn: store.settings_hideMutedBinding)
            Toggle(L10n.hideAIArtworks, isOn: store.settings_hideAIBinding)
            Toggle(L10n.hideR18Artworks, isOn: store.settings_hideR18Binding)
            Toggle(L10n.hideR18GArtworks, isOn: store.settings_hideR18GBinding)
            Toggle(L10n.maskSensitivePreviews, isOn: store.settings_maskSensitivePreviewsBinding)
        }
    }

    private var pixivSafetySection: some View {
        OS26SettingsSection(
            L10n.pixivSection,
            systemImage: "shield.lefthalf.filled",
            footer: "\(L10n.pixivRestrictedModeHint)\n\(L10n.pixivAIDisplayHint)"
        ) {
            HStack(spacing: 8) {
                Toggle(L10n.pixivRestrictedMode, isOn: restrictedModeBinding)
                    .disabled(store.restrictedModeEnabled == nil || coordinator.isUpdatingRestrictedMode)

                if store.restrictedModeEnabled == nil || coordinator.isUpdatingRestrictedMode {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let restrictedModeMessage = coordinator.restrictedModeMessage {
                Text(restrictedModeMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack(spacing: 8) {
                Toggle(L10n.pixivAIDisplay, isOn: aiShowBinding)
                    .disabled(store.aiShowEnabled == nil || coordinator.isUpdatingAIShow)

                if store.aiShowEnabled == nil || coordinator.isUpdatingAIShow {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let aiShowMessage = coordinator.aiShowMessage {
                Text(aiShowMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var mutedContentSection: some View {
        OS26SettingsSection(L10n.mutedContent, systemImage: "eye.slash", footer: L10n.muteSyncHint) {
            LabeledContent(L10n.mutedContent) {
                Text(String(format: L10n.mutedContentCountFormat, mutedContentCount))
                    .foregroundStyle(.secondary)
            }

            OS26SettingsActionButton(title: L10n.openMutedContentManager, systemImage: "eye.slash", isProminent: true) {
                store.select(.mutedContent)
            }

            FlowLayout(spacing: 8) {
                OS26SettingsActionButton(title: L10n.syncFromPixiv, systemImage: "arrow.down.circle") {
                    coordinator.isMutedContentSyncConfirmationPresented = true
                }
                .disabled(coordinator.isSyncingMutedContent)

                OS26SettingsActionButton(title: L10n.uploadToPixiv, systemImage: "arrow.up.circle") {
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
                OS26SettingsActionButton(title: L10n.exportMutedContent, systemImage: "square.and.arrow.up") {
                    exportLocalFile()
                }
                .disabled(coordinator.isSyncingMutedContent
                          || (store.mutedTagList.isEmpty
                              && store.mutedUserList.isEmpty
                              && store.mutedArtworkList.isEmpty))

                OS26SettingsActionButton(title: L10n.importMutedContent, systemImage: "square.and.arrow.down") {
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
        OS26SettingsSection(L10n.privacy, systemImage: SettingsCategory.privacy.systemImage, footer: L10n.privacyHint) {
            OS26SettingsActionButton(title: L10n.openPrivacySettings, systemImage: SettingsCategory.privacy.systemImage) {
                coordinator.selection = .privacy
            }
        }
    }

    private var mutedContentCount: Int {
        store.mutedTagList.count + store.mutedUserList.count + store.mutedArtworkList.count
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
