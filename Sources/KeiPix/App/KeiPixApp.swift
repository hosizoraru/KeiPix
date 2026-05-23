import SwiftUI

@main
struct KeiPixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = KeiPixStore()

    var body: some Scene {
        WindowGroup("KeiPix", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1040, minHeight: 700)
                .environment(\.locale, store.appLanguage.locale ?? .current)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(L10n.refresh) {
                    Task { await store.reloadCurrentFeed() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView(store: store)
                .environment(\.locale, store.appLanguage.locale ?? .current)
        }
    }
}
