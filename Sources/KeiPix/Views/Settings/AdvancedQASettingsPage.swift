import SwiftUI

struct AdvancedQASettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        OS26SettingsPage(
            title: L10n.settingsAdvancedQA,
            subtitle: L10n.runtimeReadinessHint,
            systemImage: SettingsCategory.advancedQA.systemImage
        ) {
            OS26SettingsSection(L10n.runtimeReadiness, systemImage: "checklist.checked") {
                RuntimeReadinessView(
                    store: store,
                    state: coordinator.runtimeReadinessState
                )
                .settingsContent
            }

            OS26SettingsSection(L10n.diagnostics, systemImage: "doc.text.magnifyingglass", footer: L10n.logViewerSummary) {
                OS26SettingsActionButton(title: L10n.openLogViewer, systemImage: "doc.text.magnifyingglass") {
                    openWindow(id: "logs")
                }
            }
        }
    }
}
