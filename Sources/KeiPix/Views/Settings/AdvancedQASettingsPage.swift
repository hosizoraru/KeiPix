import SwiftUI

struct AdvancedQASettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        // `RuntimeReadinessView.body` returns a `Section`, which only renders
        // properly inside a `Form`. Wrap it the same way every other Settings
        // page does so the section chrome (header, dividers, grouped material)
        // matches the rest of the sidebar destinations.
        Form {
            RuntimeReadinessView(store: store, state: coordinator.runtimeReadinessState)
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsAdvancedQA)
    }
}
