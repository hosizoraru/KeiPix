import AppIntents
import Foundation

/// Surfaces the KeiPix intents in the Shortcuts app and Spotlight
/// so a user can run them without having to build a custom shortcut
/// from scratch. Apple's HIG asks apps with intent-shaped affordances
/// to ship a shortcuts provider — without this declaration the
/// Shortcuts app shows nothing under "KeiPix".
///
/// `appShortcuts` is the only required hook; the runtime reads it
/// off `AppShortcutsProvider.appShortcuts` at install time so the
/// system gallery and Spotlight stay in sync with code changes
/// across launches.
struct KeiPixShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPixivLinkIntent(),
            phrases: [
                "Open Pixiv link in \(.applicationName)",
                "Open \(\.$link) in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource(stringLiteral: L10n.intentOpenPixivLink),
            systemImageName: "link"
        )

        AppShortcut(
            intent: OpenArtworkIntent(),
            phrases: [
                "Open artwork in \(.applicationName)",
                "Show \(\.$artwork) in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource(stringLiteral: L10n.intentOpenArtwork),
            systemImageName: "rectangle.portrait.on.rectangle.portrait"
        )

        AppShortcut(
            intent: RefreshFeedIntent(),
            phrases: [
                "Refresh \(.applicationName)",
                "Reload feed in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource(stringLiteral: L10n.intentRefreshFeed),
            systemImageName: "arrow.clockwise"
        )
    }
}
