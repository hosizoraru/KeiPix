import SwiftUI

struct AccountSettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        OS26SettingsPage(
            title: L10n.account,
            subtitle: accountPageSubtitle,
            systemImage: SettingsCategory.account.systemImage
        ) {
            OS26SettingsSection(L10n.accountMode, systemImage: "person.crop.circle") {
                Picker(L10n.accountMode, selection: accountSessionModeBinding) {
                    ForEach(AccountSessionMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if let session = store.session {
                    LabeledContent(
                        L10n.profile,
                        value: store.showAccountIdentity
                            ? "\(session.user.name) @\(session.user.account)"
                            : L10n.hidden
                    )
                }
            }

            if store.storedAccounts.isEmpty == false {
                OS26SettingsSection(L10n.currentAccount, systemImage: "person.text.rectangle") {
                    ForEach(store.storedAccounts) { account in
                        StoredAccountRow(
                            account: account,
                            isCurrent: store.accountSessionMode == .real
                                && account.id == store.session?.user.id,
                            showIdentity: store.showAccountIdentity,
                            switchAccount: {
                                Task {
                                    await store.switchAccount(userID: account.id)
                                    coordinator.setActionMessage(
                                        String(format: L10n.switchedAccountFormat, account.name)
                                    )
                                }
                            },
                            removeAccount: {
                                coordinator.accountRemovalCandidate = account
                            }
                        )
                    }
                }
            }

            OS26SettingsSection(
                L10n.session,
                systemImage: "person.badge.key",
                footer: accountActionFooter
            ) {
                FlowLayout(spacing: 8) {
                    OS26SettingsActionButton(
                        title: L10n.addAccount,
                        systemImage: "person.crop.circle.badge.plus",
                        isProminent: true
                    ) {
                        coordinator.isAccountLoginPresented = true
                    }

                    OS26SettingsActionButton(title: L10n.importToken, systemImage: "key") {
                        coordinator.isTokenLoginPresented = true
                    }

                    if store.accountSessionMode == .real, store.session != nil {
                        OS26SettingsActionButton(title: L10n.copyRefreshToken, systemImage: "doc.on.doc") {
                            coordinator.isRefreshTokenCopyConfirmationPresented = true
                        }

                        OS26SettingsActionButton(
                            title: L10n.logout,
                            systemImage: "rectangle.portrait.and.arrow.right",
                            role: .destructive
                        ) {
                            coordinator.isLogoutConfirmationPresented = true
                        }
                    }
                }
            }

            // Apple-style deep-link section for things only the website can
            // change (display name, email, password, profile picture). Pixez
            // opens the same page in a webview; on macOS we hand off to the
            // user's browser so they can authenticate with cookies, password
            // managers, and 2FA they already trust.
            if let profileURL = pixivProfileSettingsURL,
               let accountURL = pixivAccountSettingsURL {
                OS26SettingsSection(L10n.profile, systemImage: "safari", footer: L10n.accountWebSettingsHint) {
                    FlowLayout(spacing: 8) {
                        OS26SettingsLinkButton(
                            title: L10n.editProfileOnPixiv,
                            systemImage: "pencil",
                            destination: profileURL
                        )

                        OS26SettingsLinkButton(
                            title: L10n.manageAccountOnPixiv,
                            systemImage: "safari",
                            destination: accountURL
                        )
                    }
                }
            }

            // Mirror the privacy controls that touch account identity here so
            // users who land on Account looking for "Privacy Mode" or
            // "Show account identity" find them in context. The bindings are
            // shared with `PrivacySettingsPage`, so toggling either page keeps
            // both in sync — the same UX Apple uses for surfacing privacy
            // toggles inside the Apple ID section of System Settings.
            privacyAndIdentitySection
        }
    }

    private var privacyAndIdentitySection: some View {
        OS26SettingsSection(
            L10n.privacyAndIdentity,
            systemImage: SettingsCategory.privacy.systemImage,
            footer: privacyFooter
        ) {
            Toggle(L10n.privacyMode, isOn: store.settings_privacyModeBinding)
            if store.session != nil {
                Toggle(L10n.showAccountIdentity, isOn: store.settings_accountIdentityBinding)
            }

            OS26SettingsActionButton(title: L10n.openPrivacySettings, systemImage: SettingsCategory.privacy.systemImage) {
                coordinator.selection = .privacy
            }
        }
    }

    private var accountPageSubtitle: String? {
        if let session = store.session, store.showAccountIdentity {
            return "\(session.user.name) @\(session.user.account)"
        }
        return L10n.importTokenHint
    }

    private var accountActionFooter: String {
        guard store.accountSessionMode == .real, store.session != nil else {
            return L10n.importTokenHint
        }
        return "\(L10n.importTokenHint)\n\(L10n.copyRefreshTokenHint)"
    }

    private var privacyFooter: String {
        guard store.session != nil else {
            return L10n.privacyModeHint
        }
        return "\(L10n.privacyModeHint)\n\(L10n.accountIdentityPrivacyHint)"
    }

    private var accountSessionModeBinding: Binding<AccountSessionMode> {
        Binding {
            store.accountSessionMode
        } set: { mode in
            switch mode {
            case .real:
                if let account = store.storedAccounts.first {
                    Task { await store.switchAccount(userID: account.id) }
                } else {
                    coordinator.isAccountLoginPresented = true
                }
            case .guest:
                store.activateGuestMode()
            case .visualQA:
                #if DEBUG
                store.activateVisualQATestMode()
                #endif
            }
        }
    }

    /// Pixiv's "edit profile" page where display name, bio, and avatar live.
    private var pixivProfileSettingsURL: URL? {
        URL(string: "https://www.pixiv.net/setting_profile.php")
    }

    /// Pixiv's "account" page where email, password, and 2FA live.
    private var pixivAccountSettingsURL: URL? {
        URL(string: "https://www.pixiv.net/setting_user.php")
    }
}
