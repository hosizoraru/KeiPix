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

            Section(L10n.explore) {
                sidebarRow(.explore)
                sidebarRow(.search)
            }

            Section(L10n.ranking) {
                sidebarRow(.rankingDaily)
                sidebarRow(.rankingWeekly)
                sidebarRow(.rankingMonthly)
            }

            Section(L10n.bookmarks) {
                sidebarRow(.publicBookmarks)
                sidebarRow(.privateBookmarks)
                sidebarRow(.following)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 270)
        .onChange(of: store.selectedRoute) { _, newValue in
            store.select(newValue)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if store.session == nil {
                    Button {
                        store.isLoginPresented = true
                    } label: {
                        Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(role: .destructive) {
                        Task { await store.logout() }
                    } label: {
                        Label(L10n.logout, systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(.bar)
        }
    }

    private func sidebarRow(_ route: PixivRoute) -> some View {
        Label {
            Text(route.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: route.systemImage)
        }
            .tag(route)
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
