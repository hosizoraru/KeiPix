import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RuntimeReadinessView: View {
    let store: KeiPixStore
    @State private var didCopyDiagnostics = false
    @State private var isRunningDiagnostics = false
    @State private var networkResults: [NetworkDiagnosticResult] = []
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

            FlowLayout(spacing: 8) {
                Button {
                    Task { await runDiagnostics() }
                } label: {
                    Label(L10n.runNetworkDiagnostics, systemImage: "network.badge.shield.half.filled")
                }
                .disabled(isRunningDiagnostics)

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
    }

    private func runDiagnostics() async {
        isRunningDiagnostics = true
        defer { isRunningDiagnostics = false }
        networkResults = await store.runNetworkDiagnostics()
        await refreshCacheStatus()
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
        return lines.joined(separator: "\n")
    }

    private func dismissCopyStatusIfNeeded() async {
        guard didCopyDiagnostics else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if didCopyDiagnostics {
            didCopyDiagnostics = false
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
