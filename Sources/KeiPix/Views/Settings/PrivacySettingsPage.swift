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
        OS26SettingsPage(
            title: L10n.settingsPrivacy,
            subtitle: L10n.privacyHint,
            systemImage: SettingsCategory.privacy.systemImage
        ) {
            appControlsSection
            screenCaptureSection
            if store.session != nil {
                accountIdentitySection
            }
            spotlightSection
            relatedControlsSection
        }
    }

    private var appControlsSection: some View {
        OS26SettingsSection(L10n.appControls, systemImage: "hand.raised", tone: .privacy, footer: L10n.privacyModeHint) {
            Toggle(L10n.privacyMode, isOn: store.settings_privacyModeBinding)
        }
    }

    private var screenCaptureSection: some View {
        OS26SettingsSection(L10n.protectSensitiveContent, systemImage: "rectangle.dashed.badge.record", tone: .privacy, footer: L10n.screenCaptureProtectionHint) {
            Toggle(
                L10n.protectSensitiveContent,
                isOn: store.settings_screenCaptureProtectionBinding
            )
        }
    }

    private var accountIdentitySection: some View {
        OS26SettingsSection(L10n.privacyAndIdentity, systemImage: "person.crop.circle", tone: .privacy, footer: L10n.accountIdentityPrivacyHint) {
            Toggle(L10n.showAccountIdentity, isOn: store.settings_accountIdentityBinding)
        }
    }

    private var spotlightSection: some View {
        // CoreSpotlight indexing is opt-in — same posture Mail uses
        // for "Index every message". Off by default so a fresh-install
        // user has to actively decide to surface artwork metadata in
        // the system-wide search index. The Rebuild and Clear buttons
        // mirror the affordances Apple's own apps ship next to a
        // Spotlight toggle.
        OS26SettingsSection(L10n.spotlightIndexing, systemImage: "magnifyingglass", tone: .network, footer: L10n.spotlightIndexingHint) {
            Toggle(
                L10n.spotlightIndexingDownloads,
                isOn: Binding(
                    get: { store.spotlightIndexingEnabled },
                    set: { store.setSpotlightIndexingEnabled($0) }
                )
            )

            FlowLayout(spacing: 8) {
                OS26SettingsActionButton(title: L10n.spotlightRebuildIndex, systemImage: "arrow.triangle.2.circlepath", tone: .network) {
                    store.rebuildSpotlightIndex()
                }
                .disabled(store.spotlightIndexingEnabled == false)

                OS26SettingsActionButton(title: L10n.spotlightClearIndex, systemImage: "trash", role: .destructive, tone: .danger) {
                    store.clearSpotlightIndex()
                }
            }
        }
    }

    private var relatedControlsSection: some View {
        // Apple-style cross-links to neighbouring settings pages so the user
        // can pivot between Privacy and the related Safety / Account
        // surfaces without scanning the sidebar.
        OS26SettingsSection(L10n.relatedSettings, systemImage: "link", tone: .accent) {
            FlowLayout(spacing: 8) {
                OS26SettingsActionButton(title: L10n.settingsSafety, systemImage: SettingsCategory.safety.systemImage, tone: .safety) {
                    coordinator.selection = .safety
                }

                OS26SettingsActionButton(title: L10n.account, systemImage: SettingsCategory.account.systemImage, tone: .privacy) {
                    coordinator.selection = .account
                }
            }
        }
    }
}
