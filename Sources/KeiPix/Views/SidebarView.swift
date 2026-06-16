import SwiftUI

enum KeiPixSidebarDestination: Hashable {
    case route(PixivRoute)
    case settings
}

struct SidebarColumnWidth {
    let ideal: CGFloat

    static let macOS = SidebarColumnWidth(ideal: 264)
    static let iPadOS = SidebarColumnWidth(ideal: 224)
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
        .navigationSplitViewColumnWidth(ideal: columnWidth.ideal)
        .navigationTitle("KeiPix")
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
        AccountIdentityMenuButton(store: store, displayStyle: .sidebar)
    }
}
