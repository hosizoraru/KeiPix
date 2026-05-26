import Foundation

/// Where a tag in the bookmark editor sheet comes from.
///
/// The sheet groups candidates into three user-facing buckets so the source
/// of every chip is unambiguous:
///
/// - **作品标签 (artwork)** — every tag Pixiv attached to this artwork.
/// - **推荐标签 (recommended)** — a small, opinionated subset of the
///   artwork ∩ library intersection that's *actually* worth one-tapping
///   (pinned tags or library tags the user has applied multiple times).
///   The previous behavior treated the entire intersection as a
///   recommendation, which produced a wall of suggestions for any
///   even-moderately-popular artwork. Recommendations now only carry the
///   highest-signal entries so the section stays scannable.
/// - **已收藏 (library)** — the rest of the user's library that isn't on
///   this artwork, useful for filing the bookmark under an existing
///   category like `favorites` or `wallpapers`.
///
/// Free-form custom tags the user typed in this session aren't a section
/// of their own anymore — they're displayed inline next to the custom-tag
/// input (see `BookmarkEditorView`) so the three-way split stays clean.
enum BookmarkTagSource: String, CaseIterable, Hashable, Sendable {
    /// High-signal subset of the artwork ∩ library intersection. Shown
    /// first so the user can one-tap their usual picks.
    case recommended

    /// Every tag attached to this artwork. The user can adopt any of them,
    /// including ones they've never bookmarked under before.
    case artwork

    /// Library tags that aren't on this artwork. Lets the user file the
    /// bookmark under an existing personal category.
    case library

    /// Free-form tags the user typed in this session that aren't covered
    /// by the other three buckets. Rendered inline next to the custom-tag
    /// input rather than as a top-level section, but kept as a case so
    /// every candidate carries an explicit source.
    case custom

    /// Sources that render as a top-level labelled section in the sheet.
    /// `custom` is intentionally absent — custom chips are shown inline
    /// next to the input field so the three primary buckets stay clean.
    static let primarySections: [BookmarkTagSource] = [.recommended, .artwork, .library]

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
    /// Cherry-picked subset of the artwork ∩ library intersection — only
    /// pinned tags or library tags the user has applied multiple times.
    var recommended: [BookmarkTagCandidate]
    /// Every tag attached to the artwork (including the ones promoted into
    /// `recommended`). Showing the full set means the user always knows
    /// what Pixiv thinks the artwork is "about."
    var artwork: [BookmarkTagCandidate]
    /// Library tags that aren't already on the artwork.
    var library: [BookmarkTagCandidate]
    /// Free-form tags the user typed this session that aren't part of the
    /// other three buckets. Rendered inline next to the input field rather
    /// than as a top-level section.
    var custom: [BookmarkTagCandidate]

    /// Convenience flat list keyed by source for ForEach bodies that want
    /// to render every primary section in priority order. Excludes
    /// `.custom` — custom chips are rendered inline by the sheet.
    var orderedSections: [(source: BookmarkTagSource, candidates: [BookmarkTagCandidate])] {
        BookmarkTagSource.primarySections.compactMap { source in
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

    /// Count across only the primary sections rendered in the sheet body
    /// (recommended + artwork + library). The editor uses this to decide
    /// whether to show the empty state, since custom chips live in their
    /// own panel and shouldn't suppress the placeholder.
    var totalSectionCount: Int {
        recommended.count + artwork.count + library.count
    }

    static let empty = BookmarkTagGrouping(recommended: [], artwork: [], library: [], custom: [])
}

enum BookmarkTagClassifier {
    /// Pinned tags are always recommended. Non-pinned library tags need at
    /// least this many bookmarks under them to count as a "habit" worth
    /// promoting into the recommended bucket. The previous implementation
    /// promoted *every* artwork ∩ library overlap, which produced a wall
    /// of suggestions on popular artworks. Three is conservative enough
    /// that the user has clearly chosen this tag as a category, not used
    /// it once accidentally.
    static let recommendUsageThreshold = 3

    /// Hard cap on the recommended section. Even users with very busy
    /// libraries shouldn't see a 30-tag "recommendation" — the point of
    /// the section is to be a fast pick list.
    static let recommendMaxCount = 8

    /// Splits the raw inputs into the three bookmark-editor sections plus
    /// any free-form custom selections.
    ///
    /// - Parameters:
    ///   - artworkTags: Tags from `PixivArtwork.tags`. Drives the artwork
    ///     section and seeds the recommended pool; translated names are
    ///     preserved for display.
    ///   - libraryTags: User's bookmark library tags fetched from
    ///     `bookmarkTagSuggestions`. Drives the library section and the
    ///     recommended cross-listing.
    ///   - selectedTags: Tags that the user has currently selected. Custom
    ///     tags are inferred as anything in `selectedTags` that doesn't
    ///     appear in either source list. Selected tags are also auto-promoted
    ///     into the recommended bucket — if the user just picked a tag, it
    ///     belongs at the top of the sheet.
    ///   - pinnedTags: Tags the user pinned in `BookmarkTagsView`. Pinned
    ///     library tags float to the top of the library section and are
    ///     always promoted into recommended when they appear on the artwork.
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

        // First pass: walk the artwork list once, dedup, build the artwork
        // section in source order. Translation metadata is preserved here.
        var artworkBucket: [BookmarkTagCandidate] = []
        var seenArtworkNames = Set<String>()
        for entry in normalizedArtwork {
            guard seenArtworkNames.insert(entry.name).inserted else { continue }
            artworkBucket.append(BookmarkTagCandidate(
                name: entry.name,
                source: .artwork,
                translatedName: entry.translated,
                usageCount: libraryByName[entry.name],
                isPinned: pinnedTags.contains(entry.name)
            ))
        }

        // Second pass: pick high-signal recommendations from the artwork
        // bucket. A candidate gets promoted if any of:
        //   * the user already pinned it,
        //   * the user has used it at least `recommendUsageThreshold` times
        //     in their library,
        //   * the user already selected it (so it stays at the top of the
        //     sheet next to their other picks).
        let recommendedSlice = artworkBucket
            .filter { candidate in
                if candidate.isPinned { return true }
                if selectedTags.contains(candidate.name) && libraryByName[candidate.name] != nil {
                    return true
                }
                if let count = candidate.usageCount, count >= recommendUsageThreshold {
                    return true
                }
                return false
            }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                let lhsCount = lhs.usageCount ?? 0
                let rhsCount = rhs.usageCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            .prefix(recommendMaxCount)
        let recommended = recommendedSlice.map { candidate in
            BookmarkTagCandidate(
                name: candidate.name,
                source: .recommended,
                translatedName: candidate.translatedName,
                usageCount: candidate.usageCount,
                isPinned: candidate.isPinned
            )
        }

        // Drop the promoted tags from the artwork bucket so each chip only
        // shows up once in the sheet — duplicating chips just inflates the
        // sheet height for no informational gain.
        let recommendedNames = Set(recommended.map(\.name))
        let artworkOnly = artworkBucket.filter { recommendedNames.contains($0.name) == false }

        // Library section: tags the user has used elsewhere that aren't
        // already on this artwork. Pinned first, then by descending usage
        // count, then alphabetical.
        let artworkNames = Set(artworkBucket.map(\.name))
        let library = normalizedLibrary
            .filter { artworkNames.contains($0.name) == false }
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
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                let lhsCount = lhs.usageCount ?? 0
                let rhsCount = rhs.usageCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        // Custom: anything the user has selected that isn't covered by the
        // three primary buckets. Stays alphabetical for stable ordering as
        // the user types more tags.
        let knownNames = artworkNames.union(library.map(\.name))
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
