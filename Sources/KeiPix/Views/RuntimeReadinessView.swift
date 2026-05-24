import SwiftUI

struct RuntimeReadinessView: View {
    let store: KeiPixStore
    @State private var didCopyDiagnostics = false

    var body: some View {
        let snapshot = store.runtimeReadinessSnapshot

        Section(L10n.runtimeReadiness) {
            Text(L10n.runtimeReadinessHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(snapshot.rows) { row in
                RuntimeReadinessRowView(row: row)
            }

            Button {
                store.copyRuntimeReadinessDiagnostics()
                didCopyDiagnostics = true
            } label: {
                Label(L10n.copyDiagnostics, systemImage: "doc.on.doc")
            }
            .task(id: didCopyDiagnostics) {
                await dismissCopyStatusIfNeeded()
            }

            if didCopyDiagnostics {
                Text(L10n.copiedDiagnostics)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dismissCopyStatusIfNeeded() async {
        guard didCopyDiagnostics else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if didCopyDiagnostics {
            didCopyDiagnostics = false
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
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
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
