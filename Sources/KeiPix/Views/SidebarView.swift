import SwiftUI

struct SidebarView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        List(selection: $store.selectedRoute) {
            Section {
                AccountHeader(store: store)
            }

            ForEach(PixivRoute.sidebarSections) { section in
                Section(section.title) {
                    ForEach(section.routes) { route in
                        sidebarRow(route)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: store.showsSidebarAccountIdentity ? 168 : 132,
            ideal: store.showsSidebarAccountIdentity ? 184 : 144,
            max: store.showsSidebarAccountIdentity ? 216 : 168
        )
        .onChange(of: store.selectedRoute) { _, newValue in
            guard newValue.isSidebarRoute else { return }
            store.select(newValue)
        }
    }

    private func sidebarRow(_ route: PixivRoute) -> some View {
        Label {
            Text(route.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: route.systemImage)
                .frame(width: 16)
        }
            .tag(route)
            .help(route.title)
    }
}

private struct AccountHeader: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Menu {
            Section(L10n.accountMode) {
                Button {
                    store.activateGuestMode()
                } label: {
                    AccountModeMenuLabel(mode: .guest, isCurrent: store.accountSessionMode == .guest)
                }

                Button {
                    store.activateVisualQATestMode()
                } label: {
                    AccountModeMenuLabel(mode: .visualQA, isCurrent: store.accountSessionMode == .visualQA)
                }
            }

            if store.storedAccounts.isEmpty == false {
                Section(L10n.realAccount) {
                    ForEach(store.storedAccounts) { account in
                        Button {
                            Task { await store.switchAccount(userID: account.id) }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(store.showsSidebarAccountIdentity ? account.name : L10n.hidden)
                                    Text(store.showsSidebarAccountIdentity ? "@\(account.account)" : L10n.accountIdentityHidden)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: store.accountSessionMode == .real && store.session?.user.id == account.id ? "checkmark.circle.fill" : "person.crop.circle")
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    store.isLoginPresented = true
                } label: {
                    Label(L10n.addAccount, systemImage: "person.crop.circle.badge.plus")
                }

                Button {
                    store.isTokenLoginPresented = true
                } label: {
                    Label(L10n.importToken, systemImage: "key")
                }

                if store.accountSessionMode == .real, store.session != nil {
                    Button(role: .destructive) {
                        Task { await store.logout() }
                    } label: {
                        Label(L10n.logout, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        } label: {
            headerLabel
        }
        .buttonStyle(.plain)
        .padding(.vertical, showIdentity ? 4 : 7)
        .help(headerHelp)
    }

    private var headerLabel: some View {
        HStack(spacing: showIdentity ? 10 : 0) {
            if showIdentity == false {
                Spacer(minLength: 0)
            }

            avatar

            if showIdentity {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            if showIdentity == false {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let session = store.session {
            RemoteImageView(url: session.user.profileImageURL)
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 34))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
        }
    }

    private var showIdentity: Bool {
        store.showsSidebarAccountIdentity
    }

    private var title: String {
        if let session = store.session {
            return store.showsSidebarAccountIdentity ? session.user.name : L10n.hidden
        }
        return L10n.account
    }

    private var subtitle: String {
        if let session = store.session {
            if store.showsSidebarAccountIdentity {
                return store.accountSessionMode == .real ? "@\(session.user.account)" : store.accountSessionMode.title
            }
            return L10n.accountIdentityHidden
        }
        return L10n.signedOut
    }

    private var headerHelp: String {
        if let session = store.session, store.showsSidebarAccountIdentity {
            return "\(session.user.name) @\(session.user.account)"
        }
        return store.accountSessionMode.title
    }
}

private struct AccountModeMenuLabel: View {
    let mode: AccountSessionMode
    let isCurrent: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(mode.title)
                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : mode.systemImage)
        }
    }
}
