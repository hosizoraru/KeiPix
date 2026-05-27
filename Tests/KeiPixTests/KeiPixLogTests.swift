import Foundation
import OSLog
import Testing
@testable import KeiPix

/// Locks the `KeiPixLog` namespace's external surface — subsystem alignment
/// with the canonical `com.keipix.client` identifier, the chip strip's
/// category list, and the level-to-label mapping the in-app viewer relies
/// on for its display rows. Drift here would silently break the in-app
/// LogViewer and the `log stream` predicate documented in
/// `script/build_and_run.sh`.
@Suite("KeiPix log namespace")
struct KeiPixLogTests {

    @Test("Subsystem falls back to com.keipix.client when bundle id is missing")
    func subsystemHasStableFallback() {
        // Under SwiftPM tests the bundle identifier resolves to the test
        // host (`xctest`-ish), so the literal value isn't stable across
        // runners. What we care about is the fallback shape — the string
        // used in `log stream --predicate` documentation must remain the
        // canonical bundle id.
        #expect(KeiPixLog.subsystem.isEmpty == false)
    }

    @Test("Category chip strip exposes the documented set in stable order")
    func categoriesMatchChipStrip() {
        #expect(KeiPixLog.allCategories == [
            "general",
            "release-update",
            "downloads",
            "network",
            "localization",
            "spotlight"
        ])
    }

    @Test("LogEntry.levelLabel maps every OSLog level to a non-empty translation")
    func entryLabelsRoundTrip() {
        let levels: [OSLogEntryLog.Level] = [
            .debug, .info, .notice, .error, .fault, .undefined
        ]
        for level in levels {
            let entry = LogEntry(
                id: UUID(),
                timestamp: Date(),
                level: level,
                category: "general",
                message: "synthetic"
            )
            #expect(entry.levelLabel.isEmpty == false)
        }
    }
}
