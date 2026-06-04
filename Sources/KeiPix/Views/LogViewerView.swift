import Foundation
import OSLog
import SwiftUI

/// In-app log surface backed by `OSLogStore`. Lets users tail the unified
/// logging entries KeiPix emits under `com.keipix.client` without leaving
/// the app — the equivalent of opening Console.app filtered to our
/// subsystem, but with category chips and a copy-to-pasteboard affordance
/// tuned for bug reports.
///
/// We read from `OSLogStore.local()` because that's the only entry point
/// that works for an unsigned development build; `OSLogStore.system(at:)`
/// requires entitlements we don't ship. The store is queried on demand
/// (Refresh button + initial task) rather than streamed, since
/// `OSLogStore` doesn't expose a Combine publisher and polling would burn
/// CPU for a window the user only opens occasionally.
struct LogViewerView: View {
    @State private var entries: [LogEntry] = []
    @State private var unavailable: Bool = false
    @State private var loading: Bool = false
    @State private var searchText: String = ""
    @State private var selectedCategory: String = ""  // empty == all
    @State private var minimumLevel: OSLogEntryLog.Level = .info
    @State private var copyToast: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .platformGlassControlBar(verticalPadding: 8, topPadding: 2)
            content
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 480)
        #endif
        .navigationTitle(L10n.logs)
        .task {
            await refresh()
        }
        .overlay(alignment: .bottom) {
            if let message = copyToast {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
                    .padding(.bottom, 14)
                    .transition(.opacity)
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { copyToast = nil }
                    }
            }
        }
        .animation(.snappy, value: copyToast)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    logSearchField
                    categoryMenu
                    levelMenu
                    toolbarActions
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 10) {
                    logSearchField
                    HStack(spacing: 10) {
                        categoryMenu
                        levelMenu
                        toolbarActions
                    }
                }
            }
        }
        .controlSize(.small)
    }

    private var logSearchField: some View {
        OS26LibrarySearchField(
            text: $searchText,
            placeholder: L10n.filterLogs,
            minWidth: 180,
            idealWidth: 240,
            maxWidth: 320
        )
    }

    private var categoryMenu: some View {
        Menu {
            Picker(L10n.allCategories, selection: $selectedCategory) {
                Text(L10n.allCategories).tag("")
                ForEach(KeiPixLog.allCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(selectedCategory.isEmpty ? L10n.allCategories : selectedCategory, systemImage: "folder")
        }
        .os26GlassIconButton()
        .help(L10n.allCategories)
    }

    private var levelMenu: some View {
        Menu {
            Picker(L10n.minLevel, selection: $minimumLevel) {
                Text(L10n.logLevelDebug).tag(OSLogEntryLog.Level.debug)
                Text(L10n.logLevelInfo).tag(OSLogEntryLog.Level.info)
                Text(L10n.logLevelNotice).tag(OSLogEntryLog.Level.notice)
                Text(L10n.logLevelError).tag(OSLogEntryLog.Level.error)
                Text(L10n.logLevelFault).tag(OSLogEntryLog.Level.fault)
            }
            .pickerStyle(.inline)
        } label: {
            Label(L10n.minLevel, systemImage: "line.3.horizontal.decrease.circle")
        }
        .os26GlassIconButton()
        .help(L10n.minLevel)
    }

    private var toolbarActions: some View {
        OS26LibraryActionRail {
            Button {
                Task { await refresh() }
            } label: {
                Label(L10n.refreshLogs, systemImage: "arrow.clockwise")
            }
            .os26GlassIconButton()
            .help(L10n.refreshLogs)
            .disabled(loading)

            Button {
                copyVisibleLogs()
            } label: {
                Label(L10n.copyVisibleLogs, systemImage: "doc.on.doc")
            }
            .os26GlassIconButton()
            .help(L10n.copyVisibleLogs)
            .disabled(filteredEntries.isEmpty)

            Button {
                revealInConsole()
            } label: {
                Label(L10n.revealInConsole, systemImage: "arrow.up.right.square")
            }
            .os26GlassIconButton()
            .help(L10n.revealInConsole)
        }
    }

    @ViewBuilder
    private var content: some View {
        if unavailable {
            unavailableState
        } else if loading && entries.isEmpty {
            OS26LibraryLoadingView(title: L10n.loading, systemImage: "list.bullet.rectangle")
        } else if filteredEntries.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        NativeLogEntryListView(entries: filteredEntries) { entry in
            AnyView(LogEntryRow(entry: entry))
        }
    }

    private var emptyState: some View {
        OS26LibraryUnavailableView(
            title: L10n.noLogEntries,
            subtitle: L10n.noLogEntriesHint,
            systemImage: "tray"
        )
    }

    private var unavailableState: some View {
        OS26LibraryUnavailableView(
            title: L10n.logAccessUnavailable,
            subtitle: L10n.logAccessUnavailableHint,
            systemImage: "exclamationmark.triangle"
        ) {
            Button {
                revealInConsole()
            } label: {
                Label(L10n.revealInConsole, systemImage: "arrow.up.right.square")
            }
            .os26GlassButton(prominent: true)
        }
    }

    // MARK: - Filtering

    private var filteredEntries: [LogEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.filter { entry in
            guard entry.level.rawValue >= minimumLevel.rawValue else { return false }
            if selectedCategory.isEmpty == false, entry.category != selectedCategory {
                return false
            }
            if query.isEmpty == false {
                return entry.message.lowercased().contains(query)
                    || entry.category.lowercased().contains(query)
            }
            return true
        }
    }

    // MARK: - Actions

    private func refresh() async {
        loading = true
        defer { loading = false }
        let result = await Task.detached(priority: .userInitiated) {
            LogViewerView.fetchEntries()
        }.value
        switch result {
        case .success(let fetched):
            entries = fetched
            unavailable = false
        case .failure:
            entries = []
            unavailable = true
        }
    }

    private func copyVisibleLogs() {
        let payload = filteredEntries
            .map { entry in
                "[\(entry.timestamp.formatted(date: .numeric, time: .standard))] " +
                "\(entry.levelLabel.uppercased()) \(entry.category): \(entry.message)"
            }
            .joined(separator: "\n")
        PasteboardWriter.copy(payload)
        copyToast = L10n.logsCopied
    }

    private func revealInConsole() {
        // `open -a Console` opens the app fresh; no public URL scheme exists
        // for pre-filtering by subsystem, but Console restores its last
        // filter and our build script documents the canonical predicate.
        let consoleURL = URL(fileURLWithPath: "/System/Applications/Utilities/Console.app")
        PlatformWorkspace.open(consoleURL)
    }

    // MARK: - OSLogStore plumbing

    /// Pulls every entry emitted by KeiPix's subsystem since launch. We
    /// scope to `KeiPixLog.subsystem` and the start of the running process
    /// so the viewer matches what the user has actually seen this session
    /// — historical entries from prior runs would just confuse a triage
    /// flow without buying signal we can't already get from Console.app.
    nonisolated static func fetchEntries() -> Result<[LogEntry], Error> {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 0)
            let predicate = NSPredicate(
                format: "subsystem == %@",
                KeiPixLog.subsystem
            )
            let entries = try store.getEntries(at: position, matching: predicate)
            let mapped: [LogEntry] = entries.compactMap { raw in
                guard let log = raw as? OSLogEntryLog else { return nil }
                return LogEntry(
                    id: UUID(),
                    timestamp: log.date,
                    level: log.level,
                    category: log.category,
                    message: log.composedMessage
                )
            }
            return .success(mapped)
        } catch {
            return .failure(error)
        }
    }
}

/// Display row backing each visible entry. We materialise out of
/// `OSLogEntryLog` immediately so the SwiftUI list doesn't keep a strong
/// reference back to the OS log database — the latter is large and
/// memory-mapped, and pinning it via diff'd identifiers caused noticeable
/// memory growth during the v0.x prototype.
struct LogEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: OSLogEntryLog.Level
    let category: String
    let message: String

    var levelLabel: String {
        switch level {
        case .debug: return L10n.logLevelDebug
        case .info: return L10n.logLevelInfo
        case .notice: return L10n.logLevelNotice
        case .error: return L10n.logLevelError
        case .fault: return L10n.logLevelFault
        case .undefined: return L10n.logLevelDefault
        @unknown default: return L10n.logLevelDefault
        }
    }

    var levelColor: Color {
        switch level {
        case .error, .fault: return .red
        case .notice: return .orange
        case .info: return .secondary
        case .debug: return .tertiary
        case .undefined: return .secondary
        @unknown default: return .secondary
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(entry.levelLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.levelColor)
                Text(entry.category)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer()
            }

            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension Color {
    static var tertiary: Color { Color.secondary.opacity(0.6) }
}

#Preview {
    LogViewerView()
}
