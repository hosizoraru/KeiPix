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
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.account)
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
}
