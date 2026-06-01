import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Platform-agnostic façade over the OS "open URL" and
/// "reveal-in-file-browser" surfaces. Today every call routes to
/// `NSWorkspace`; on iPadOS the same entry points would route to
/// `UIApplication.shared.open(_:)` and `UIDocumentPickerViewController`.
///
/// Centralising this means a future iPadOS port only edits this one
/// file instead of rewriting every share / link / "show in Finder"
/// affordance scattered across 20+ views and stores. Mirrors the
/// pattern Apple uses internally for `OpenURLAction` — call sites
/// state intent, the platform decides how to honour it.
///
/// Keep this surface deliberately small: opening a URL, revealing a
/// file. Anything richer (drag bindings, share sheet) belongs in its
/// own façade so we don't accidentally re-export the entirety of
/// AppKit through one type.
enum PlatformWorkspace {
    /// Opens `url` in the user's default handler. Returns `true` when
    /// the system accepted the request.
    ///
    /// On iPadOS this becomes `UIApplication.shared.open(_:)`, which
    /// is async-completing — callers that care about completion will
    /// need to opt into the async variant when we add it.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        return true
        #endif
    }

    /// Reveals a single file URL in the system file browser.
    /// On macOS this raises Finder with the file selected; on
    /// iPadOS it would deep-link into Files at the parent folder.
    static func revealInFiles(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
        // iPadOS: UIDocumentPickerViewController in Phase 5.
    }

    /// Reveals multiple file URLs in the system file browser. Used
    /// by the downloads viewer when the user batch-selects items.
    static func revealInFiles(_ urls: [URL]) {
        guard urls.isEmpty == false else { return }
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        #endif
    }
}
