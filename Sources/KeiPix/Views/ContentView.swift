import SwiftUI

struct ContentView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } content: {
            GalleryView(store: store)
                .navigationSplitViewColumnWidth(min: 520, ideal: 720)
        } detail: {
            ArtworkDetailView(store: store)
                .navigationSplitViewColumnWidth(min: 340, ideal: 420)
        }
        .searchable(text: $store.searchText, prompt: L10n.searchPlaceholder)
        .onSubmit(of: .search) {
            Task { await store.runSearch() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.reloadCurrentFeed() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }

                if store.session == nil {
                    Button {
                        store.isLoginPresented = true
                    } label: {
                        Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
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
}
