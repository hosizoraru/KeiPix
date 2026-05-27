import SwiftUI

struct AdvancedQASettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // `RuntimeReadinessView.body` returns a `Section`, which only renders
        // properly inside a `Form`. Wrap it the same way every other Settings
        // page does so the section chrome (header, dividers, grouped material)
        // matches the rest of the sidebar destinations.
        Form {
            RuntimeReadinessView(store: store, state: coordinator.runtimeReadinessState)

            // Log viewer entry point. Lives next to the runtime-readiness
            // diagnostics because both surfaces feed into the same triage
            // flow: a user sees a misbehaviour in QA, then jumps to the
            // log tail to grab a copyable trace for a bug report.
            Section(L10n.diagnostics) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.logViewerSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        openWindow(id: "logs")
                    } label: {
                        Label(L10n.openLogViewer, systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsAdvancedQA)
    }
}
