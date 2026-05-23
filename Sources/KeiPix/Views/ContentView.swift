import SwiftUI

struct ContentView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } content: {
            GalleryView(store: store)
                .navigationSplitViewColumnWidth(min: 560, ideal: 780)
        } detail: {
            ArtworkDetailView(store: store)
                .navigationSplitViewColumnWidth(min: 360, ideal: 460)
        }
        .searchable(text: $store.searchText, prompt: L10n.searchPlaceholder)
        .onSubmit(of: .search) {
            Task { await store.runSearch() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.reloadCurrentFeed() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: compactCardsBinding) {
                    Label(L10n.compactCards, systemImage: store.compactArtworkCards ? "rectangle.grid.3x2.fill" : "rectangle.grid.2x2")
                }
                .toggleStyle(.button)
            }

            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label(L10n.settings, systemImage: "gearshape")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if store.session == nil {
                    Button {
                        store.isLoginPresented = true
                    } label: {
                        Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .sheet(isPresented: $store.isLoginPresented) {
            LoginSheetView(store: store)
                .frame(width: 900, height: 680)
        }
        .alert(L10n.errorTitle, isPresented: errorBinding) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            store.errorMessage != nil
        } set: { value in
            if value == false {
                store.errorMessage = nil
            }
        }
    }

    private var compactCardsBinding: Binding<Bool> {
        Binding {
            store.compactArtworkCards
        } set: { value in
            store.setCompactArtworkCards(value)
        }
    }
}
