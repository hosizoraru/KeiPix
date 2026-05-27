#if os(macOS)
import AppKit
import Foundation

/// Handles entries the system surfaces in the macOS Services menu —
/// the menu that lets users hand a selection (a URL, a snippet of
/// text) from any app off to KeiPix without having to leave that
/// app. Apple's HIG calls Services out as a first-class extension
/// point: anything an app can already do with its own URL handling
/// belongs here too, so right-clicking a Pixiv link in Mail or
/// Safari and picking "Open in KeiPix" feels native.
///
/// The provider is registered on `NSApp.servicesProvider` from
/// `AppDelegate`, and the Services declaration in Info.plist points
/// the system at this method.
final class KeiPixServicesProvider: NSObject {
    /// Selector signature AppKit demands for service handlers.
    /// The system passes the user's selection on the pasteboard;
    /// we read whatever URL string is in there, normalize it, and
    /// hand it off to the live store via the intents locator.
    @objc func openPixivLinkFromService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let candidate = pboard.string(forType: .URL)
            ?? pboard.string(forType: .string)
            ?? ""

        guard let url = IntentInputNormalizer.pixivURL(from: candidate) else {
            error.pointee = "No Pixiv link found in selection."
            return
        }

        Task { @MainActor in
            // Bring the app forward so the user sees the result of
            // their service invocation. Without this, a service
            // dispatched from a backgrounded KeiPix would silently
            // load the link without surfacing the window.
            NSApp.activate(ignoringOtherApps: true)
            await KeiPixStoreLocator.shared.store?.openPixivLink(url)
        }
    }
}
#endif
