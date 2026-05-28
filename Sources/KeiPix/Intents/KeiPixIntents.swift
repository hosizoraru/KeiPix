import AppIntents
import Foundation

/// Opens a Pixiv link inside KeiPix. Wraps the same logic the
/// `onOpenURL` handler runs, so a user invoking this intent from
/// the Shortcuts app, Spotlight, or a workflow lands on the same
/// destination as if they had clicked a `pixiv.net` link.
///
/// The string parameter accepts a full URL (`pixiv.net`, `pixiv://`,
/// `keipix://open?url=…`) or a bare numeric artwork id, mirroring
/// what the clipboard handler tolerates.
struct OpenPixivLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Pixiv Link"
    static let description = IntentDescription(
        "Open a Pixiv URL or artwork ID in KeiPix."
    )

    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Link",
        description: "A Pixiv URL or artwork ID."
    )
    var link: String

    init() {}

    init(link: String) {
        self.link = link
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let url = IntentInputNormalizer.pixivURL(from: link) else {
            return .result(dialog: IntentDialog(stringLiteral: L10n.intentNotPixivLink))
        }

        guard let store = KeiPixStoreLocator.shared.store else {
            return .result(dialog: IntentDialog(stringLiteral: L10n.intentNotReady))
        }

        let message = await store.openPixivLink(url)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

/// Opens the reader window for a specific artwork id. Pairs with
/// the multi-window scene wired in P3-05 so a user can have multiple
/// reader windows side-by-side, each driven by an intent invocation.
struct OpenArtworkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Artwork in Reader"
    static let description = IntentDescription(
        "Open a Pixiv artwork in its own reader window."
    )

    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Artwork",
        description: "A Pixiv artwork ID or URL."
    )
    var artwork: String

    init() {}

    init(artwork: String) {
        self.artwork = artwork
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = IntentInputNormalizer.artworkID(from: artwork) else {
            return .result(dialog: IntentDialog(stringLiteral: L10n.intentNoArtworkIDFormat))
        }

        let locator = KeiPixStoreLocator.shared
        guard let store = locator.store else {
            return .result(dialog: IntentDialog(stringLiteral: L10n.intentNotReady))
        }

        if let cached = store.readerWindowArtwork(id: id) {
            store.registerReaderWindowArtwork(cached)
        } else if let resolved = await store.resolveReaderWindowArtwork(id: id) {
            store.registerReaderWindowArtwork(resolved)
        }

        locator.openReaderWindow(artworkID: id)
        return .result(dialog: IntentDialog(stringLiteral: String(format: L10n.intentOpenedArtworkFormat, id)))
    }
}

/// Refreshes whatever feed is currently selected in the main window.
/// The shortcut's blast radius is identical to hitting Cmd+R inside
/// the app — useful in a morning automation that wakes the Mac and
/// pulls the latest illustrations before the user sits down.
struct RefreshFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Current Feed"
    static let description = IntentDescription(
        "Reload the feed currently shown in KeiPix's main window."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = KeiPixStoreLocator.shared.store else {
            return .result(dialog: IntentDialog(stringLiteral: L10n.intentNotRunning))
        }
        await store.reloadCurrentFeed()
        return .result(dialog: IntentDialog(stringLiteral: L10n.intentRefreshed))
    }
}
