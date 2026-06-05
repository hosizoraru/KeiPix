import SwiftUI

struct AccountIdentityMenuButton: View {
    enum DisplayStyle {
        case sidebar
        case heroAvatar(diameter: CGFloat, symbolSize: CGFloat)

        var isSidebar: Bool {
            if case .sidebar = self {
                return true
            }
            return false
        }
    }

    @Bindable var store: KeiPixStore
    let displayStyle: DisplayStyle

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
                            StoredAccountMenuLabel(
                                account: account,
                                isCurrent: store.accountSessionMode == .real && store.session?.user.id == account.id,
                                showIdentity: store.showsSidebarAccountIdentity
                            )
                        }
                    }
                }
            }

            Section(L10n.privacyAndIdentity) {
                Toggle(L10n.showAccountIdentity, isOn: showAccountIdentityBinding)

                Button {
                    store.setPrivacyModeEnabled(!store.privacyModeEnabled)
                } label: {
                    Label(
                        store.privacyModeEnabled ? L10n.disablePrivacyMode : L10n.enablePrivacyMode,
                        systemImage: store.privacyModeEnabled ? "eye.slash.fill" : "eye"
                    )
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
            label
        }
        .buttonStyle(.plain)
        .padding(.vertical, displayStyle.isSidebar ? 6 : 0)
        .help(headerHelp)
        .accessibilityLabel(headerHelp)
    }

    @ViewBuilder
    private var label: some View {
        switch displayStyle {
        case .sidebar:
            sidebarLabel
        case .heroAvatar:
            avatar
        }
    }

    private var sidebarLabel: some View {
        Group {
            if showIdentity {
                HStack(spacing: 12) {
                    avatar

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    avatar
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: showIdentity ? .leading : .center)
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL {
            RemoteImageView(url: avatarURL)
                .frame(width: avatarDiameter, height: avatarDiameter)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(.quaternary, lineWidth: 1)
                }
        } else {
            Image(systemName: accountIconName)
                .font(.system(size: avatarSymbolSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: avatarDiameter, height: avatarDiameter)
                .glassEffect(.regular.interactive(), in: Circle())
        }
    }

    private var avatarDiameter: CGFloat {
        switch displayStyle {
        case .sidebar:
            showIdentity ? 46 : 62
        case .heroAvatar(let diameter, _):
            diameter
        }
    }

    private var avatarSymbolSize: CGFloat {
        switch displayStyle {
        case .sidebar:
            showIdentity ? 36 : 48
        case .heroAvatar(_, let symbolSize):
            symbolSize
        }
    }

    private var avatarURL: URL? {
        if let session = store.session {
            return session.user.profileImageURL
        }
        return store.storedAccounts.first?.profileImageURL
    }

    private var accountIconName: String {
        store.session == nil ? "person.crop.circle" : "person.crop.circle.fill"
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
        return store.storedAccounts.isEmpty ? L10n.signedOut : L10n.realAccount
    }

    private var headerHelp: String {
        if let session = store.session, store.showsSidebarAccountIdentity {
            return "\(session.user.name) @\(session.user.account)"
        }
        return store.accountSessionMode.title
    }

    private var showAccountIdentityBinding: Binding<Bool> {
        Binding {
            store.showAccountIdentity
        } set: { value in
            store.setShowAccountIdentity(value)
        }
    }
}

private struct StoredAccountMenuLabel: View {
    let account: PixivStoredAccount
    let isCurrent: Bool
    let showIdentity: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(showIdentity ? account.name : L10n.hidden)
                Text(showIdentity ? "@\(account.account)" : L10n.accountIdentityHidden)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "person.crop.circle")
        }
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
