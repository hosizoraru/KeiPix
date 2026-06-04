import SwiftUI

enum KeiPixSidebarDestination: Hashable {
    case route(PixivRoute)
    case settings
}

struct SidebarColumnWidth {
    let min: CGFloat
    let ideal: CGFloat
    let max: CGFloat

    static let macOS = SidebarColumnWidth(min: 246, ideal: 266, max: 310)
    static let iPadOS = SidebarColumnWidth(min: 196, ideal: 218, max: 250)
}

struct SidebarView: View {
    @Bindable var store: KeiPixStore
    @Binding var selection: KeiPixSidebarDestination

    var columnWidth: SidebarColumnWidth = .macOS
    var includesSettingsDestination = false

    @State private var expansion = SidebarSectionExpansion()

    var body: some View {
        List(selection: optionalSelection) {
            Section {
                AccountHeader(store: store)
            }

            ForEach(PixivRoute.sidebarSections) { section in
                Section(isExpanded: expansion.binding(for: section)) {
                    ForEach(section.routes) { route in
                        sidebarRow(route)
                            .tag(KeiPixSidebarDestination.route(route))
                    }
                } header: {
                    Text(section.title)
                }
            }

            if includesSettingsDestination {
                Section(L10n.settings) {
                    sidebarRow(title: L10n.settings, systemImage: "gearshape")
                        .tag(KeiPixSidebarDestination.settings)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(
            minWidth: columnWidth.min,
            idealWidth: columnWidth.ideal,
            maxWidth: columnWidth.max
        )
        .navigationSplitViewColumnWidth(
            min: columnWidth.min,
            ideal: columnWidth.ideal,
            max: columnWidth.max
        )
    }

    private var optionalSelection: Binding<KeiPixSidebarDestination?> {
        Binding {
            selection
        } set: { newValue in
            if let newValue {
                selection = newValue
            }
        }
    }

    private func sidebarRow(_ route: PixivRoute) -> some View {
        sidebarRow(title: route.title, systemImage: route.systemImage)
            .help(route.title)
            .accessibilityLabel(route.title)
    }

    private func sidebarRow(title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 17)
        }
        .contentShape(Rectangle())
    }
}

/// Tracks which sidebar sections are expanded and persists the state to
/// `UserDefaults` so the layout survives relaunches. Sections default to
/// expanded on first run, matching the previous always-open behavior.
@MainActor
@Observable
final class SidebarSectionExpansion {
    private static let storageKey = "sidebarSectionCollapsedIDs"
    private let defaults: UserDefaults

    /// We persist the *collapsed* set rather than the expanded one. That way
    /// any newly introduced sidebar section is expanded by default without
    /// having to migrate stored state.
    private var collapsedIDs: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.storageKey) ?? []
        self.collapsedIDs = Set(stored)
    }

    func isExpanded(_ section: PixivRouteSection) -> Bool {
        collapsedIDs.contains(section.storageID) == false
    }

    func setExpanded(_ expanded: Bool, for section: PixivRouteSection) {
        let id = section.storageID
        let wasExpanded = isExpanded(section)
        guard wasExpanded != expanded else { return }
        if expanded {
            collapsedIDs.remove(id)
        } else {
            collapsedIDs.insert(id)
        }
        persist()
    }

    func binding(for section: PixivRouteSection) -> Binding<Bool> {
        Binding(
            get: { self.isExpanded(section) },
            set: { self.setExpanded($0, for: section) }
        )
    }

    private func persist() {
        defaults.set(Array(collapsedIDs), forKey: Self.storageKey)
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
            headerLabel
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .help(headerHelp)
        .accessibilityLabel(headerHelp)
    }

    private var headerLabel: some View {
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
        showIdentity ? 46 : 62
    }

    private var avatarSymbolSize: CGFloat {
        showIdentity ? 36 : 48
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
