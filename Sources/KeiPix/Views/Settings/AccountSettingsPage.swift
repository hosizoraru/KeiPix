import SwiftUI

struct AccountSettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        Form {
            Section {
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
            } header: {
                Text(L10n.accountMode)
            }

            if store.storedAccounts.isEmpty == false {
                Section(L10n.currentAccount) {
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

            Section {
                Button {
                    coordinator.isAccountLoginPresented = true
                } label: {
                    Label(L10n.addAccount, systemImage: "person.crop.circle.badge.plus")
                }

                Button {
                    coordinator.isTokenLoginPresented = true
                } label: {
                    Label(L10n.importToken, systemImage: "key")
                }

                if store.accountSessionMode == .real, store.session != nil {
                    Button(role: .destructive) {
                        coordinator.isLogoutConfirmationPresented = true
                    } label: {
                        Label(L10n.logout, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } footer: {
                Text(L10n.importTokenHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Apple-style deep-link section for things only the website can
            // change (display name, email, password, profile picture). Pixez
            // opens the same page in a webview; on macOS we hand off to the
            // user's browser so they can authenticate with cookies, password
            // managers, and 2FA they already trust.
            if let profileURL = pixivProfileSettingsURL,
               let accountURL = pixivAccountSettingsURL {
                Section {
                    Link(destination: profileURL) {
                        Label(L10n.editProfileOnPixiv, systemImage: "pencil")
                    }

                    Link(destination: accountURL) {
                        Label(L10n.manageAccountOnPixiv, systemImage: "safari")
                    }
                } footer: {
                    Text(L10n.accountWebSettingsHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .formStyle(.grouped)
        .navigationTitle(L10n.account)
    }

    private var privacyAndIdentitySection: some View {
        Section {
            Toggle(L10n.privacyMode, isOn: store.settings_privacyModeBinding)
            if store.session != nil {
                Toggle(L10n.showAccountIdentity, isOn: store.settings_accountIdentityBinding)
            }

            Button {
                coordinator.selection = .privacy
            } label: {
                Label(L10n.openPrivacySettings, systemImage: SettingsCategory.privacy.systemImage)
            }
        } header: {
            Text(L10n.privacyAndIdentity)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.privacyModeHint)
                if store.session != nil {
                    Text(L10n.accountIdentityPrivacyHint)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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
                store.activateVisualQATestMode()
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
