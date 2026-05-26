import SwiftUI

struct SafetySettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator
    var updateRestrictedMode: (Bool) async -> Void
    var syncFromPixiv: () async -> Void
    var uploadToPixiv: () async -> Void
    var importLocalFile: () -> Void
    var exportLocalFile: () -> Void

    var body: some View {
        Form {
            filtersSection
            mutedContentSection
            if store.session != nil {
                pixivSafetySection
            }
            privacySection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsSafety)
    }

    private var filtersSection: some View {
        Section {
            Toggle(L10n.showContentBadges, isOn: store.settings_showContentBadgesBinding)
            Toggle(L10n.hideMutedContent, isOn: store.settings_hideMutedBinding)
            Toggle(L10n.hideAIArtworks, isOn: store.settings_hideAIBinding)
            Toggle(L10n.hideR18Artworks, isOn: store.settings_hideR18Binding)
            Toggle(L10n.hideR18GArtworks, isOn: store.settings_hideR18GBinding)
            Toggle(L10n.maskSensitivePreviews, isOn: store.settings_maskSensitivePreviewsBinding)
        } header: {
            Text(L10n.contentFilters)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.pixivAIDisplayHint)
                Text(L10n.maskSensitivePreviewsHint)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var pixivSafetySection: some View {
        Section {
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
        } header: {
            Text("Pixiv")
        } footer: {
            Text(L10n.pixivRestrictedModeHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var mutedContentSection: some View {
        Section {
            LabeledContent(L10n.mutedContent) {
                Text(String(format: L10n.mutedContentCountFormat, mutedContentCount))
                    .foregroundStyle(.secondary)
            }

            Button {
                store.select(.mutedContent)
            } label: {
                Label(L10n.openMutedContentManager, systemImage: "eye.slash")
            }

            FlowLayout(spacing: 8) {
                Button {
                    coordinator.isMutedContentSyncConfirmationPresented = true
                } label: {
                    Label(L10n.syncFromPixiv, systemImage: "arrow.down.circle")
                }
                .disabled(coordinator.isSyncingMutedContent)

                Button {
                    coordinator.isMutedContentUploadConfirmationPresented = true
                } label: {
                    Label(L10n.uploadToPixiv, systemImage: "arrow.up.circle")
                }
                .disabled(coordinator.isSyncingMutedContent
                          || (store.mutedTagList.isEmpty && store.mutedUserList.isEmpty))

                if coordinator.isSyncingMutedContent {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            FlowLayout(spacing: 8) {
                Button {
                    exportLocalFile()
                } label: {
                    Label(L10n.exportMutedContent, systemImage: "square.and.arrow.up")
                }
                .disabled(coordinator.isSyncingMutedContent
                          || (store.mutedTagList.isEmpty
                              && store.mutedUserList.isEmpty
                              && store.mutedArtworkList.isEmpty))

                Button {
                    coordinator.isMutedContentImportConfirmationPresented = true
                } label: {
                    Label(L10n.importMutedContent, systemImage: "square.and.arrow.down")
                }
                .disabled(coordinator.isSyncingMutedContent)
            }

            if let mutedContentMessage = coordinator.mutedContentMessage {
                Text(mutedContentMessage)
                    .font(.caption)
                    .foregroundStyle(coordinator.mutedContentMessageIsError ? .red : .secondary)
                    .textSelection(.enabled)
            }
        } header: {
            Text(L10n.mutedContent)
        } footer: {
            Text(L10n.muteSyncHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section {
            Toggle(L10n.privacyMode, isOn: store.settings_privacyModeBinding)
            Toggle(L10n.protectSensitiveContent, isOn: store.settings_screenCaptureProtectionBinding)
            if store.session != nil {
                Toggle(L10n.showAccountIdentity, isOn: store.settings_accountIdentityBinding)
            }
        } header: {
            Text(L10n.privacy)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.privacyModeHint)
                Text(L10n.screenCaptureProtectionHint)
                if store.session != nil {
                    Text(L10n.accountIdentityPrivacyHint)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
}
