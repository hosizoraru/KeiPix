#if os(macOS)
import AppKit
#endif
import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

    private static let backupFileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    var body: some View {
        OS26SettingsPage(
            title: L10n.settingsStorage,
            subtitle: L10n.storageHint,
            systemImage: SettingsCategory.storage.systemImage
        ) {
            overviewSection
            ForEach(categories) { snapshot in
                categorySection(snapshot)
            }
            backupSection
            footerSection
        }
        .onAppear { reloadSnapshots() }
    }

    private var overviewSection: some View {
        OS26SettingsSection(L10n.storageOverview, systemImage: "internaldrive", footer: L10n.storageHint) {
            LabeledContent(L10n.totalCacheSize) {
                Text(formattedTotal)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func categorySection(_ snapshot: CacheCategorySnapshot) -> some View {
        OS26SettingsSection(snapshot.title, systemImage: "externaldrive", footer: snapshot.detail) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(snapshot.title)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(snapshot.displayLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    OS26SettingsActionButton(
                        title: L10n.clearCategory,
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        clear(snapshot.id)
                    }
                    .disabled(snapshot.isEmpty)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var footerSection: some View {
        OS26SettingsSection(L10n.clearAllCaches, systemImage: "trash.slash") {
            OS26SettingsActionButton(
                title: L10n.clearAllCaches,
                systemImage: "trash.slash",
                role: .destructive
            ) {
                clearAll()
            }
            .disabled(categories.allSatisfy(\.isEmpty))
        }
    }

    /// Backup/restore lives in Storage rather than its own Settings
    /// category because users come here to think about *the data
    /// KeiPix keeps locally* — caches, libraries, history. Putting
    /// the Export/Import controls beside the cache list keeps the
    /// "what's on my disk" mental model in one place, the same way
    /// macOS Time Machine settings live under General → Storage.
    private var backupSection: some View {
        OS26SettingsSection(L10n.backupAndRestore, systemImage: "archivebox", footer: L10n.backupHint) {
            FlowLayout(spacing: 8) {
                OS26SettingsActionButton(
                    title: L10n.exportBackup,
                    systemImage: "square.and.arrow.up",
                    isProminent: true
                ) {
                    exportBackup()
                }
                OS26SettingsActionButton(title: L10n.importBackup, systemImage: "square.and.arrow.down") {
                    importBackup()
                }
            }
            .padding(.vertical, 2)
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

    /// Hand the archive to `NSSavePanel` and let the user pick a
    /// destination. Mirrors the saved-search and muted-content
    /// exporters already in the app — same JSON+ISO-8601 wire
    /// shape, same naming convention so users recognise the file
    /// at a glance.
    private func exportBackup() {
        #if os(macOS)
        let archive = store.exportBackupArchive()
        let panel = NSSavePanel()
        panel.title = L10n.exportBackup
        panel.nameFieldStringValue = "keipix-backup-\(Self.backupFileDateFormatter.string(from: archive.exportedAt)).json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try store.encodeBackupArchive(archive)
            try data.write(to: url, options: [.atomic])
            // Use a coarse "everything in this archive" count so the
            // user knows the file isn't empty without us having to
            // tally per-category counts at export time.
            let entryCount = archive.savedSearches?.presets.count ?? 0
                + (archive.savedSearches?.savedSearches.count ?? 0)
                + (archive.savedSearches?.searchHistory.count ?? 0)
                + archive.localBrowsingHistory.count
                + archive.pinnedCreators.creators.count
                + archive.pinnedBookmarkTags.count
                + archive.readerProgress.items.count
                + archive.downloadedReaderProgress.items.count
                + archive.mangaWatchlistReadState.items.count
                + archive.artworkDetailState.entries.count
                + (archive.mutedContent?.totalCount ?? 0)
            coordinator.setActionMessage(
                String(format: L10n.exportedBackupFormat, entryCount)
            )
        } catch {
            coordinator.setActionMessage(
                "\(L10n.unableToExportBackup): \(error.localizedDescription)"
            )
        }
        #else
        coordinator.setActionMessage(L10n.unableToExportBackup)
        #endif
    }

    private func importBackup() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = L10n.importBackup
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let archive = try store.decodeBackupArchive(data)
            let summary = store.importBackupArchive(archive)
            coordinator.setActionMessage(
                String(format: L10n.importedBackupFormat, summary.totalCount)
            )
            // Refresh the cache snapshots — importing browsing history
            // and reader progress moves their on-disk size, and we'd
            // rather show the new totals than make the user click away
            // and come back.
            reloadSnapshots()
        } catch let error as KeiPixBackupError {
            coordinator.setActionMessage(
                "\(L10n.unableToImportBackup): \(error.localizedMessage)"
            )
        } catch {
            coordinator.setActionMessage(
                "\(L10n.unableToImportBackup): \(error.localizedDescription)"
            )
        }
        #else
        coordinator.setActionMessage(L10n.unableToImportBackup)
        #endif
    }
}
