import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RuntimeReadinessView: View {
    let store: KeiPixStore
    @State private var didCopyDiagnostics = false
    @State private var didCopyChecklist = false
    @State private var isRunningDiagnostics = false
    @State private var isRunningSearchDiagnostics = false
    @State private var isRunningMutableActionQA = false
    @State private var isMutableActionQAAuthorizationPresented = false
    @State private var networkResults: [NetworkDiagnosticResult] = []
    @State private var searchResults: [NetworkDiagnosticResult] = []
    @State private var mutableActionQAResults: [NetworkDiagnosticResult] = []
    @State private var cacheStatus: ImageCacheStatus?
    @State private var cacheMessage: String?

    var body: some View {
        let snapshot = store.runtimeReadinessSnapshot

        Section(L10n.runtimeReadiness) {
            Text(L10n.runtimeReadinessHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(snapshot.rows) { row in
                RuntimeReadinessRowView(row: row)
            }

            if let cacheStatus {
                RuntimeReadinessRowView(row: RuntimeReadinessRow(
                    id: "image-cache-live",
                    title: L10n.imageCache,
                    value: String(format: L10n.cacheUsageFormat, cacheStatus.diskUsageText, cacheStatus.diskCapacityText),
                    systemImage: "externaldrive",
                    isReady: true
                ))
            }

            if networkResults.isEmpty == false {
                Divider()

                ForEach(networkResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if searchResults.isEmpty == false {
                Divider()

                ForEach(searchResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if mutableActionQAResults.isEmpty == false {
                Divider()

                ForEach(mutableActionQAResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            Divider()

            MutableActionReadinessView(
                items: snapshot.mutableActionItems,
                didCopyChecklist: didCopyChecklist,
                copyChecklist: {
                    PasteboardWriter.copy(snapshot.mutableActionChecklistText)
                    didCopyChecklist = true
                }
            )
            .task(id: didCopyChecklist) {
                await dismissChecklistCopyStatusIfNeeded()
            }

            FlowLayout(spacing: 8) {
                Button {
                    Task { await runDiagnostics() }
                } label: {
                    Label(L10n.runNetworkDiagnostics, systemImage: "network.badge.shield.half.filled")
                }
                .disabled(isRunningDiagnostics)

                Button {
                    Task { await runSearchDiagnostics() }
                } label: {
                    Label(L10n.runSearchDiagnostics, systemImage: "magnifyingglass.circle")
                }
                .disabled(isRunningSearchDiagnostics)

                Button(role: .destructive) {
                    isMutableActionQAAuthorizationPresented = true
                } label: {
                    Label(L10n.runMutableActionQA, systemImage: "checkmark.shield")
                }
                .disabled(isRunningMutableActionQA)

                Button {
                    Task { await refreshCacheStatus() }
                } label: {
                    Label(L10n.refreshCacheStatus, systemImage: "externaldrive.badge.magnifyingglass")
                }

                Button(role: .destructive) {
                    Task { await clearImageCache() }
                } label: {
                    Label(L10n.clearImageCache, systemImage: "trash")
                }
            }

            if isRunningDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningSearchDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningSearchDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningMutableActionQA {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningMutableActionQA)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let cacheMessage {
                Text(cacheMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button {
                copyDiagnostics(snapshot)
                didCopyDiagnostics = true
            } label: {
                Label(L10n.copyDiagnostics, systemImage: "doc.on.doc")
            }
            .task(id: didCopyDiagnostics) {
                await dismissCopyStatusIfNeeded()
            }

            Button {
                saveDiagnostics(snapshot)
            } label: {
                Label(L10n.saveDiagnostics, systemImage: "square.and.arrow.down")
            }

            if didCopyDiagnostics {
                Text(L10n.copiedDiagnostics)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await refreshCacheStatus()
        }
        .sheet(isPresented: $isMutableActionQAAuthorizationPresented) {
            MutableActionQAAuthorizationSheet {
                Task { await runMutableActionQA() }
            }
        }
    }

    private func runDiagnostics() async {
        isRunningDiagnostics = true
        defer { isRunningDiagnostics = false }
        networkResults = await store.runNetworkDiagnostics()
        await refreshCacheStatus()
    }

    private func runSearchDiagnostics() async {
        isRunningSearchDiagnostics = true
        defer { isRunningSearchDiagnostics = false }
        searchResults = await store.runSearchDiagnostics()
    }

    private func runMutableActionQA() async {
        isRunningMutableActionQA = true
        defer { isRunningMutableActionQA = false }
        mutableActionQAResults = await store.runReversibleMutableActionQA()
    }

    private func refreshCacheStatus() async {
        cacheStatus = await store.imageCacheStatus()
    }

    private func clearImageCache() async {
        cacheStatus = await store.clearImageCache()
        cacheMessage = L10n.imageCacheCleared
        try? await Task.sleep(for: .seconds(2.5))
        if cacheMessage == L10n.imageCacheCleared {
            cacheMessage = nil
        }
    }

    private func copyDiagnostics(_ snapshot: RuntimeReadinessSnapshot) {
        PasteboardWriter.copy(diagnosticsReport(snapshot))
    }

    private func saveDiagnostics(_ snapshot: RuntimeReadinessSnapshot) {
        let panel = NSSavePanel()
        panel.title = L10n.saveDiagnostics
        panel.nameFieldStringValue = "keipix-diagnostics-\(Self.fileDateFormatter.string(from: Date())).txt"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try diagnosticsReport(snapshot).write(to: url, atomically: true, encoding: .utf8)
            cacheMessage = L10n.savedDiagnostics
        } catch {
            cacheMessage = "\(L10n.unableToSaveDiagnostics): \(error.localizedDescription)"
        }
    }

    private func diagnosticsReport(_ snapshot: RuntimeReadinessSnapshot) -> String {
        var lines = [snapshot.diagnosticsText]
        if let cacheStatus {
            lines.append("Image Cache: \(cacheStatus.summaryText)")
        }
        if networkResults.isEmpty == false {
            lines.append("")
            lines.append("Network Diagnostics")
            lines += networkResults.map(\.diagnosticsLine)
        }
        if searchResults.isEmpty == false {
            lines.append("")
            lines.append("Search Diagnostics")
            lines += searchResults.map(\.diagnosticsLine)
        }
        if mutableActionQAResults.isEmpty == false {
            lines.append("")
            lines.append("Mutable Action QA Results")
            lines += mutableActionQAResults.map(\.diagnosticsLine)
        }
        return lines.joined(separator: "\n")
    }

    private func dismissCopyStatusIfNeeded() async {
        guard didCopyDiagnostics else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if didCopyDiagnostics {
            didCopyDiagnostics = false
        }
    }

    private func dismissChecklistCopyStatusIfNeeded() async {
        guard didCopyChecklist else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if didCopyChecklist {
            didCopyChecklist = false
        }
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

struct MutableActionReadinessView: View {
    let items: [MutableActionQAItem]
    let didCopyChecklist: Bool
    let copyChecklist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(L10n.mutableActionReadiness, systemImage: "checklist")
                    .font(.headline)

                Spacer()

                Button {
                    copyChecklist()
                } label: {
                    Label(L10n.copyQAReviewChecklist, systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }

            Text(L10n.mutableActionReadinessHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    MutableActionReadinessRow(item: item)
                }
            }

            if didCopyChecklist {
                Text(L10n.copiedQAReviewChecklist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MutableActionReadinessRow: View {
    let item: MutableActionQAItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: item.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            Spacer(minLength: 16)

            Label(item.status.title, systemImage: item.status.systemImage)
                .font(.caption)
                .foregroundStyle(statusColor)
                .labelStyle(.titleAndIcon)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .verified:
            .green
        case .needsTestAccount:
            .orange
        case .needsExplicitApproval:
            .red
        }
    }
}

private struct NetworkDiagnosticResultRow: View {
    let result: NetworkDiagnosticResult

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .lineLimit(1)
                    Text(result.statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 18)
            }

            Spacer(minLength: 16)

            Text(detailText)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .help(detailText)
        }
    }

    private var detailText: String {
        if let duration = result.duration {
            return "\(result.detail) · \(String(format: "%.0f ms", duration * 1000))"
        }
        return result.detail
    }

    private var systemImage: String {
        switch result.status {
        case .passed:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        case .skipped:
            "minus.circle"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .passed:
            .green
        case .failed:
            .red
        case .skipped:
            .secondary
        }
    }
}

private struct RuntimeReadinessRowView: View {
    let row: RuntimeReadinessRow

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(row.title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: row.systemImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 18)
            }

            Spacer(minLength: 16)

            Text(row.value)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .help(row.value)
        }
    }

    private var statusColor: Color {
        switch row.isReady {
        case .some(true):
            .green
        case .some(false):
            .orange
        case .none:
            .secondary
        }
    }
}
