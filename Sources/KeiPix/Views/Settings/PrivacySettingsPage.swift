import SwiftUI

/// Dedicated Privacy page in the Settings sidebar.
///
/// Mirrors Apple's macOS System Settings → Privacy & Security: a single
/// destination that aggregates every privacy-shaped control, with cross-links
/// back to the Account and Safety pages for adjacent surfaces. The same
/// bindings are also exposed inside `AccountSettingsPage` so users who land
/// on Account while looking for "Privacy Mode" find the controls there too —
/// matching Apple's pattern of letting privacy toggles surface in multiple
/// natural locations.
struct PrivacySettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        Form {
            // Apple-style intro paragraph at the top of the page so the page
            // describes itself before the user reads the controls. Keeps the
            // tone consistent with System Settings → Privacy & Security.
            Section {
                Text(L10n.privacyHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            appControlsSection
            screenCaptureSection
            if store.session != nil {
                accountIdentitySection
            }
            spotlightSection
            relatedControlsSection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsPrivacy)
    }

    private var appControlsSection: some View {
        Section {
            Toggle(L10n.privacyMode, isOn: store.settings_privacyModeBinding)
        } header: {
            Text(L10n.appControls)
        } footer: {
            Text(L10n.privacyModeHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var screenCaptureSection: some View {
        Section {
            Toggle(
                L10n.protectSensitiveContent,
                isOn: store.settings_screenCaptureProtectionBinding
            )
        } footer: {
            Text(L10n.screenCaptureProtectionHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var accountIdentitySection: some View {
        Section {
            Toggle(L10n.showAccountIdentity, isOn: store.settings_accountIdentityBinding)
        } header: {
            Text(L10n.privacyAndIdentity)
        } footer: {
            Text(L10n.accountIdentityPrivacyHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var spotlightSection: some View {
        // CoreSpotlight indexing is opt-in — same posture Mail uses
        // for "Index every message". Off by default so a fresh-install
        // user has to actively decide to surface artwork metadata in
        // the system-wide search index. The Rebuild and Clear buttons
        // mirror the affordances Apple's own apps ship next to a
        // Spotlight toggle.
        Section {
            Toggle(
                L10n.spotlightIndexingDownloads,
                isOn: Binding(
                    get: { store.spotlightIndexingEnabled },
                    set: { store.setSpotlightIndexingEnabled($0) }
                )
            )

            Button(L10n.spotlightRebuildIndex) {
                store.rebuildSpotlightIndex()
            }
            .disabled(store.spotlightIndexingEnabled == false)

            Button(L10n.spotlightClearIndex) {
                store.clearSpotlightIndex()
            }
        } header: {
            Text(L10n.spotlightIndexing)
        } footer: {
            Text(L10n.spotlightIndexingHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var relatedControlsSection: some View {
        // Apple-style cross-links to neighbouring settings pages so the user
        // can pivot between Privacy and the related Safety / Account
        // surfaces without scanning the sidebar.
        Section {
            Button {
                coordinator.selection = .safety
            } label: {
                Label(L10n.settingsSafety, systemImage: SettingsCategory.safety.systemImage)
            }

            Button {
                coordinator.selection = .account
            } label: {
                Label(L10n.account, systemImage: SettingsCategory.account.systemImage)
            }
        } header: {
            Text(L10n.relatedSettings)
        }
    }
}
