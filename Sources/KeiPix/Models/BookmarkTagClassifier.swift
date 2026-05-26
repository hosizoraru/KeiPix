import Foundation

/// Where a tag in the bookmark editor sheet comes from.
///
/// The bookmark editor used to lump every candidate tag into a single
/// "Bookmark Tags" pile, which left users guessing whether a tag came from
/// the artwork's own metadata, their personal bookmark library, or both.
/// Splitting into named sources lets the sheet tell users exactly what
/// they're picking and surface meaningful bulk actions (Add All Recommended,
/// Add All Artwork Tags, etc.).
enum BookmarkTagSource: String, CaseIterable, Hashable, Sendable {
    /// Tag exists on the artwork **and** in the user's bookmark library.
    /// Highest-signal pick: the user has used this tag before, and the
    /// artwork actually has it, so it's the safest auto-recommendation.
    case recommended

    /// Tag is on the artwork but the user has never bookmarked anything
    /// with it. Useful for adopting a new tag from the artwork's metadata.
    case artwork

    /// Tag lives in the user's library but isn't on this artwork. Useful
    /// for filing the artwork under an existing user-defined category
    /// (e.g. "favorites", "for-printing", "wallpapers") that wouldn't
    /// otherwise apply.
    case library

    /// Free-form tags the user typed in this session. Always shown last
    /// since they're transient state.
    case custom

    var title: String {
        switch self {
        case .recommended: L10n.bookmarkTagSectionRecommended
        case .artwork: L10n.bookmarkTagSectionArtwork
        case .library: L10n.bookmarkTagSectionLibrary
        case .custom: L10n.bookmarkTagSectionCustom
        }
    }

    var subtitle: String {
        switch self {
        case .recommended: L10n.bookmarkTagSectionRecommendedHint
        case .artwork: L10n.bookmarkTagSectionArtworkHint
        case .library: L10n.bookmarkTagSectionLibraryHint
        case .custom: L10n.bookmarkTagSectionCustomHint
        }
    }

    var systemImage: String {
        switch self {
        case .recommended: "sparkles"
        case .artwork: "photo.artframe"
        case .library: "bookmark"
        case .custom: "plus.circle"
        }
    }
}

/// Single tag entry as displayed in the bookmark editor sheet, carrying
/// enough context to render the chip and run bulk actions.
struct BookmarkTagCandidate: Identifiable, Hashable, Sendable {
    let name: String
    let source: BookmarkTagSource
    /// Translated tag label from the artwork (e.g. `風景 → Landscape`).
    /// Only set for `.artwork` and `.recommended` candidates that came
    /// from the live artwork tag list.
    let translatedName: String?
    /// Library usage count (number of bookmarks under this tag) when the
    /// tag came from the user's library. `nil` for `.artwork`-only and
    /// `.custom` entries that have no usage data yet.
    let usageCount: Int?
    /// Whether the user pinned this tag in `BookmarkTagsView`. Pinned
    /// library tags float to the top of their section.
    let isPinned: Bool

    var id: String { name }
}

/// Ordered, deduplicated grouping of tag candidates by source.
///
/// Built once per editor render so the view's body is just a flat
/// `ForEach`. Pure value type so it's easy to unit-test.
struct BookmarkTagGrouping: Sendable, Equatable {
    var recommended: [BookmarkTagCandidate]
    var artwork: [BookmarkTagCandidate]
    var library: [BookmarkTagCandidate]
    var custom: [BookmarkTagCandidate]

    /// Convenience flat list keyed by source for ForEach bodies that want
    /// to render every section in priority order.
    var orderedSections: [(source: BookmarkTagSource, candidates: [BookmarkTagCandidate])] {
        BookmarkTagSource.allCases.compactMap { source in
            let candidates = candidates(for: source)
            return candidates.isEmpty ? nil : (source, candidates)
        }
    }

    func candidates(for source: BookmarkTagSource) -> [BookmarkTagCandidate] {
        switch source {
        case .recommended: recommended
        case .artwork: artwork
        case .library: library
        case .custom: custom
        }
    }

    var totalCount: Int {
        recommended.count + artwork.count + library.count + custom.count
    }

    static let empty = BookmarkTagGrouping(recommended: [], artwork: [], library: [], custom: [])
}

enum BookmarkTagClassifier {
    /// Splits the raw inputs into the four bookmark-editor sections.
    ///
    /// - Parameters:
    ///   - artworkTags: Tags from `PixivArtwork.tags`. Drives the recommended
    ///     and artwork sections; translated names are preserved for display.
    ///   - libraryTags: User's bookmark library tags fetched from
    ///     `bookmarkTagSuggestions`. Drives the library section and the
    ///     recommended cross-listing.
    ///   - selectedTags: Tags that the user has currently selected. Custom
    ///     tags are inferred as anything in `selectedTags` that doesn't
    ///     appear in either source list.
    ///   - pinnedTags: Tags the user pinned in `BookmarkTagsView`. Pinned
    ///     library tags float to the top of the library section.
    static func classify(
        artworkTags: [PixivTag],
        libraryTags: [PixivBookmarkTag],
        selectedTags: Set<String>,
        pinnedTags: Set<String>
    ) -> BookmarkTagGrouping {
        let normalizedArtwork = artworkTags.compactMap { tag -> (name: String, translated: String?)? in
            let trimmed = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            let translated = tag.translatedName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            return (trimmed, translated?.localizedCaseInsensitiveCompare(trimmed) == .orderedSame ? nil : translated)
        }

        let normalizedLibrary = libraryTags.compactMap { tag -> (name: String, count: Int)? in
            let trimmed = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            return (trimmed, tag.count)
        }

        // Build name -> library entry map so we can look up usage counts in
        // O(1) when classifying artwork tags.
        var libraryByName: [String: Int] = [:]
        for entry in normalizedLibrary {
            libraryByName[entry.name] = entry.count
        }

        var recommended: [BookmarkTagCandidate] = []
        var artworkOnly: [BookmarkTagCandidate] = []
        // Walk the artwork list once; preserve its order so the sheet
        // surfaces tags in the same order Pixiv ships them on the artwork.
        var seenArtworkNames = Set<String>()
        for entry in normalizedArtwork {
            guard seenArtworkNames.insert(entry.name).inserted else { continue }
            if let count = libraryByName[entry.name] {
                recommended.append(BookmarkTagCandidate(
                    name: entry.name,
                    source: .recommended,
                    translatedName: entry.translated,
                    usageCount: count,
                    isPinned: pinnedTags.contains(entry.name)
                ))
            } else {
                artworkOnly.append(BookmarkTagCandidate(
                    name: entry.name,
                    source: .artwork,
                    translatedName: entry.translated,
                    usageCount: nil,
                    isPinned: pinnedTags.contains(entry.name)
                ))
            }
        }

        // Library tags that aren't already in the recommended bucket.
        let recommendedNames = Set(recommended.map(\.name))
        let library = normalizedLibrary
            .filter { recommendedNames.contains($0.name) == false }
            .map { entry in
                BookmarkTagCandidate(
                    name: entry.name,
                    source: .library,
                    translatedName: nil,
                    usageCount: entry.count,
                    isPinned: pinnedTags.contains(entry.name)
                )
            }
            .sorted { lhs, rhs in
                // Pinned first, then highest usage count, then alphabetical.
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                let lhsCount = lhs.usageCount ?? 0
                let rhsCount = rhs.usageCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        // Custom tags: anything the user has selected that isn't in either
        // source list. Sort alphabetically so the order is stable as the
        // user adds more custom tags.
        let knownNames = recommendedNames
            .union(artworkOnly.map(\.name))
            .union(library.map(\.name))
        let custom = selectedTags
            .subtracting(knownNames)
            .map { name in
                BookmarkTagCandidate(
                    name: name,
                    source: .custom,
                    translatedName: nil,
                    usageCount: nil,
                    isPinned: pinnedTags.contains(name)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return BookmarkTagGrouping(
            recommended: recommended,
            artwork: artworkOnly,
            library: library,
            custom: custom
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
