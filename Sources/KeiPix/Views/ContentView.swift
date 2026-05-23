import SwiftUI

struct ContentView: View {
    @Bindable var store: KeiPixStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
        } content: {
            GalleryView(store: store)
                .navigationSplitViewColumnWidth(min: 500, ideal: 720)
        } detail: {
            ArtworkDetailView(store: store)
                .navigationSplitViewColumnWidth(min: 360, ideal: 480)
        }
        .frame(minWidth: minimumWindowWidth, minHeight: 700)
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
                Menu {
                    ForEach(WindowSizePreset.allCases) { preset in
                        Button(preset.title) {
                            preset.apply(sidebarVisible: sidebarVisible)
                        }
                    }
                } label: {
                    Label(L10n.windowSize, systemImage: "macwindow")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Picker(L10n.galleryLayout, selection: galleryLayoutBinding) {
                    ForEach(GalleryLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 300)
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

    private var sidebarVisible: Bool {
        columnVisibility == .all || columnVisibility == .automatic
    }

    private var minimumWindowWidth: CGFloat {
        sidebarVisible ? 1080 : 1040
    }

    private var galleryLayoutBinding: Binding<GalleryLayoutMode> {
        Binding {
            store.galleryLayoutMode
        } set: { value in
            store.setGalleryLayoutMode(value)
        }
    }
}
