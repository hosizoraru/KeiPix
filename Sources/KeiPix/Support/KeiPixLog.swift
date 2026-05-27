import Foundation
import os

/// Centralized `os.Logger` namespace.
///
/// `KeiPix` previously emitted nothing to the unified logging system, which
/// meant the `Console.app` filter the build script suggests
/// (`subsystem == com.keipix.client`) had nothing to surface. Routing the
/// few diagnostic-worthy events through one subsystem keeps the in-app
/// `LogViewerView` populated and lets users grab a pasteable log slice for
/// bug reports without leaving the app.
///
/// Categories are intentionally coarse — same shape Apple uses in the
/// Activity tracing samples — so the in-app filter UI stays a chip strip
/// instead of a tree.
enum KeiPixLog {
    /// Matches the bundle identifier baked into `script/build_and_run.sh`
    /// and `script/build_release_app.sh`, so anyone already filtering
    /// `log stream --predicate "subsystem == \"com.keipix.client\""`
    /// continues to see KeiPix output without having to relearn a name.
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.keipix.client"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let releaseUpdate = Logger(subsystem: subsystem, category: "release-update")
    static let downloads = Logger(subsystem: subsystem, category: "downloads")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let localization = Logger(subsystem: subsystem, category: "localization")
    static let spotlight = Logger(subsystem: subsystem, category: "spotlight")

    /// Stable list of category names the viewer surfaces as filter chips.
    /// Order mirrors the user-facing severity / blast radius of each
    /// surface so the chip strip reads like a debug runbook.
    static let allCategories: [String] = [
        "general",
        "release-update",
        "downloads",
        "network",
        "localization",
        "spotlight"
    ]
}
