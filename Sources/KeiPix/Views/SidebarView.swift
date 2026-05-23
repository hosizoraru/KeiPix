import SwiftUI

struct SidebarView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        List(selection: $store.selectedRoute) {
            if let session = store.session {
                Section {
                    UserHeader(session: session, showIdentity: store.showsSidebarAccountIdentity)
                }
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

private struct UserHeader: View {
    let session: PixivSession
    let showIdentity: Bool

    var body: some View {
        HStack(spacing: showIdentity ? 10 : 0) {
            if showIdentity == false {
                Spacer(minLength: 0)
            }

            RemoteImageView(url: session.user.profileImageURL)
                .frame(width: 34, height: 34)
                .clipShape(Circle())

            if showIdentity {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.user.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("@\(session.user.account)")
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
        .padding(.vertical, showIdentity ? 4 : 7)
        .help(showIdentity ? "\(session.user.name) @\(session.user.account)" : L10n.account)
    }
}
