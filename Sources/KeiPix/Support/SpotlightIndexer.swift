import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Thin wrapper around `CSSearchableIndex.default()` so the rest of
/// the app can talk to a small actor instead of CoreSpotlight
/// directly. The wrapper is the only place that constructs
/// `CSSearchableItem`s, so the live-index reach is contained — the
/// pure mapping in `DownloadSpotlightAttributes` stays exercisable
/// in unit tests without spinning up the system index.
///
/// We treat CoreSpotlight as best-effort: errors are logged but
/// never raised back to the user. Spotlight indexing is a
/// nice-to-have, and a transient I/O failure shouldn't prevent the
/// download itself from finishing or the queue from advancing.
actor SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private let index: CSSearchableIndex

    init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    func indexAttributes(_ attributes: [DownloadSpotlightAttributes]) {
        guard attributes.isEmpty == false else { return }
        let searchableItems = attributes.map(makeSearchableItem(from:))
        index.indexSearchableItems(searchableItems) { error in
            if let error {
                let message = error.localizedDescription
                KeiPixLog.spotlight.error("Spotlight index failed: \(message, privacy: .public)")
            }
        }
    }

    func deleteIdentifiers(_ identifiers: [String]) {
        guard identifiers.isEmpty == false else { return }
        index.deleteSearchableItems(withIdentifiers: identifiers) { error in
            if let error {
                let message = error.localizedDescription
                KeiPixLog.spotlight.error("Spotlight delete failed: \(message, privacy: .public)")
            }
        }
    }

    /// Wipes everything in our domain. Used by the privacy toggle
    /// (off → strip all KeiPix entries) and the Settings "Clear
    /// Spotlight Index" action.
    func clearAll() {
        let domain = DownloadSpotlightAttributes.domainIdentifier
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { error in
            if let error {
                let message = error.localizedDescription
                KeiPixLog.spotlight.error("Spotlight domain clear failed: \(message, privacy: .public)")
            }
        }
    }

    private func makeSearchableItem(from attributes: DownloadSpotlightAttributes) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.image)
        attributeSet.title = attributes.title
        attributeSet.contentDescription = attributes.contentDescription
        attributeSet.keywords = attributes.keywords
        if let url = attributes.thumbnailFileURL {
            attributeSet.thumbnailURL = url
        }
        if let contentURL = attributes.contentURL {
            attributeSet.contentURL = contentURL
        }

        return CSSearchableItem(
            uniqueIdentifier: attributes.identifier,
            domainIdentifier: attributes.domainIdentifier,
            attributeSet: attributeSet
        )
    }
}
