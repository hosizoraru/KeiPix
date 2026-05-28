import AppKit
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 480)
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
                    .background(.thinMaterial, in: Capsule())
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
        HStack(spacing: 12) {
            TextField(L10n.filterLogs, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)

            Picker(L10n.allCategories, selection: $selectedCategory) {
                Text(L10n.allCategories).tag("")
                ForEach(KeiPixLog.allCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 180)

            Picker(L10n.minLevel, selection: $minimumLevel) {
                Text(L10n.logLevelDebug).tag(OSLogEntryLog.Level.debug)
                Text(L10n.logLevelInfo).tag(OSLogEntryLog.Level.info)
                Text(L10n.logLevelNotice).tag(OSLogEntryLog.Level.notice)
                Text(L10n.logLevelError).tag(OSLogEntryLog.Level.error)
                Text(L10n.logLevelFault).tag(OSLogEntryLog.Level.fault)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 140)

            Spacer()

            Button {
                Task { await refresh() }
            } label: {
                Label(L10n.refreshLogs, systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .help(L10n.refreshLogs)
            .disabled(loading)

            Button {
                copyVisibleLogs()
            } label: {
                Label(L10n.copyVisibleLogs, systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .help(L10n.copyVisibleLogs)
            .disabled(filteredEntries.isEmpty)

            Button {
                revealInConsole()
            } label: {
                Label(L10n.revealInConsole, systemImage: "arrow.up.right.square")
            }
            .labelStyle(.iconOnly)
            .help(L10n.revealInConsole)
        }
    }

    @ViewBuilder
    private var content: some View {
        if unavailable {
            unavailableState
        } else if loading && entries.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredEntries.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        // `Table` would surface column resizing for free, but log entries
        // only need a single dense row per record and the message column
        // would dominate the rest anyway — `List` keeps the layout
        // closer to Console.app.
        List(filteredEntries) { entry in
            VStack(alignment: .leading, spacing: 2) {
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
                    Spacer()
                }
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(L10n.noLogEntries)
                .font(.headline)
            Text(L10n.noLogEntriesHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableState: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(L10n.logAccessUnavailable)
                .font(.headline)
            Text(L10n.logAccessUnavailableHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                revealInConsole()
            } label: {
                Label(L10n.revealInConsole, systemImage: "arrow.up.right.square")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private extension Color {
    static var tertiary: Color { Color.secondary.opacity(0.6) }
}

#Preview {
    LogViewerView()
}
