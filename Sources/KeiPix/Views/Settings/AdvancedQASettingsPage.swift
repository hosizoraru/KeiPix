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

            OS26SettingsSection(L10n.imageProcessing, systemImage: "camera.filters") {
                OS26SettingsToggleRow(
                    title: L10n.imageProcessorsEnabled,
                    detail: L10n.imageProcessorsHint,
                    systemImage: "wand.and.stars",
                    isOn: store.settings_imageProcessorsEnabledBinding
                )

                if store.imageProcessorsEnabled {
                    OS26SettingsDivider()

                    ForEach(ImageProcessorRegistry.allProcessors, id: \.identifier) { processor in
                        OS26SettingsToggleRow(
                            title: processor.displayName,
                            detail: nil,
                            systemImage: processorSystemImage(processor.identifier),
                            isOn: processorToggleBinding(for: processor.identifier)
                        )
                    }
                }
            }
        }
    }

    private func processorSystemImage(_ identifier: String) -> String {
        switch identifier {
        case "smart-crop":
            "crop"
        case "sharpen":
            "sparkle.magnifyingglass"
        case "denoise":
            "circle.dotted"
        default:
            "camera.filters"
        }
    }

    private func processorToggleBinding(for identifier: String) -> Binding<Bool> {
        Binding {
            store.activeImageProcessors.contains(identifier)
        } set: { enabled in
            var current = store.activeImageProcessors
            if enabled {
                if !current.contains(identifier) {
                    current.append(identifier)
                }
            } else {
                current.removeAll { $0 == identifier }
            }
            store.setActiveImageProcessors(current)
        }
    }
}
