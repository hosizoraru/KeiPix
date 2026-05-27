import SwiftUI

/// Storage settings page. Surfaces every regenerable cache the app
/// keeps locally so users can audit on-disk footprint and clear
/// individual categories or everything in one shot. Mirrors macOS
/// System Settings → General → Storage: each row owns a size
/// readout and a single Clear action; one footer button reclaims
/// everything at once.
///
/// We snapshot the categories on appear and after every Clear
/// instead of observing the underlying caches live — image-pipeline
/// fills run on every URL fetch, and we don't want a busy gallery
/// to repaint this page on every cell.
struct StorageSettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    @State private var categories: [CacheCategorySnapshot] = []

    var body: some View {
        Form {
            overviewSection
            ForEach(categories) { snapshot in
                categorySection(snapshot)
            }
            footerSection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsStorage)
        .onAppear { reloadSnapshots() }
    }

    private var overviewSection: some View {
        Section {
            LabeledContent(L10n.totalCacheSize) {
                Text(formattedTotal)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.storageOverview)
        } footer: {
            Text(L10n.storageHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func categorySection(_ snapshot: CacheCategorySnapshot) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(snapshot.title)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(snapshot.displayLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(snapshot.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button {
                        clear(snapshot.id)
                    } label: {
                        Label(L10n.clearCategory, systemImage: "trash")
                    }
                    .disabled(snapshot.isEmpty)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var footerSection: some View {
        Section {
            Button(role: .destructive) {
                clearAll()
            } label: {
                Label(L10n.clearAllCaches, systemImage: "trash.slash")
            }
            .disabled(categories.allSatisfy(\.isEmpty))
        }
    }

    private var formattedTotal: String {
        let total = categories.reduce(0) { $0 + ($1.byteSize ?? 0) }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    private func clear(_ kind: CacheCategoryKind) {
        let snapshot = store.clearCacheCategory(kind)
        if let index = categories.firstIndex(where: { $0.id == kind }) {
            categories[index] = snapshot
        }
        coordinator.setActionMessage(
            String(format: L10n.clearedCacheCategoryFormat, locale: Locale.current, snapshot.title)
        )
    }

    private func clearAll() {
        categories = store.clearAllCacheCategories()
        coordinator.setActionMessage(L10n.clearedAllCaches)
    }

    private func reloadSnapshots() {
        categories = store.cacheCategorySnapshots()
    }
}
