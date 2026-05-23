import SwiftUI

struct SidebarView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        List(selection: $store.selectedRoute) {
            if let session = store.session {
                Section {
                    UserHeader(session: session)
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
        .navigationSplitViewColumnWidth(min: 196, ideal: 216, max: 248)
        .onChange(of: store.selectedRoute) { _, newValue in
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

    var body: some View {
        HStack(spacing: 10) {
            RemoteImageView(url: session.user.profileImageURL)
                .frame(width: 34, height: 34)
                .clipShape(Circle())

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
        .padding(.vertical, 4)
        .help("\(session.user.name) @\(session.user.account)")
    }
}
