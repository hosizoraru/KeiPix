import SwiftUI

struct AdvancedQASettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        // RuntimeReadinessView already provides its own Form/Section layout and
        // is too heavy to refactor in this pass. Embed it directly so the page
        // still composes cleanly under the sidebar shell.
        RuntimeReadinessView(store: store)
            .navigationTitle(L10n.settingsAdvancedQA)
    }
}
