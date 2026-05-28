import Foundation

// MARK: - Navigation history engine

/// Pure, testable browser-style back/forward history for artwork IDs.
struct NavigationHistory {
    private let maxEntries: Int
    private(set) var entries: [Int] = []
    private(set) var cursor: Int = -1

    init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    var canGoBack: Bool { cursor > 0 }
    var canGoForward: Bool { cursor < entries.count - 1 }

    /// Push an artwork ID onto the history stack.
    /// Truncates forward history and deduplicates consecutive same-ID entries.
    mutating func push(_ artworkID: Int) {
        // Truncate forward history (like a browser when you click a
        // link after pressing Back).
        if cursor >= 0, cursor < entries.count - 1 {
            entries = Array(entries.prefix(cursor + 1))
        }

        // Deduplicate consecutive same-ID entries.
        if entries.last == artworkID { return }

        entries.append(artworkID)

        // Cap at max entries.
        if entries.count > maxEntries {
            let overflow = entries.count - maxEntries
            entries.removeFirst(overflow)
        }

        cursor = entries.count - 1
    }

    /// Move cursor back. Returns the artwork ID to resolve, or nil if
    /// already at the start.
    mutating func goBack() -> Int? {
        guard canGoBack else { return nil }
        cursor -= 1
        return entries[cursor]
    }

    /// Move cursor forward. Returns the artwork ID to resolve, or nil
    /// if already at the end.
    mutating func goForward() -> Int? {
        guard canGoForward else { return nil }
        cursor += 1
        return entries[cursor]
    }

    /// Reset all history state.
    mutating func clear() {
        entries = []
        cursor = -1
    }
}

// MARK: - KeiPixStore integration

extension KeiPixStore {
    var canNavigateBack: Bool { navigationHistory.canGoBack }
    var canNavigateForward: Bool { navigationHistory.canGoForward }

    /// Push an artwork onto the history stack and select it.
    /// This is the single entry point for all user-initiated artwork
    /// navigation — gallery tap, adjacent nav, deep link, random, etc.
    func navigateToArtwork(_ artwork: PixivArtwork) {
        navigationHistory.push(artwork.id)
        selectedArtwork = artwork
        HandoffManager.shared.updateActivity(
            route: selectedRoute.rawValue,
            artworkID: artwork.id
        )
    }

    /// Navigate backward in history.
    func navigateBack() {
        guard let id = navigationHistory.goBack() else { return }
        resolveAndSelectArtwork(id: id)
    }

    /// Navigate forward in history.
    func navigateForward() {
        guard let id = navigationHistory.goForward() else { return }
        resolveAndSelectArtwork(id: id)
    }

    /// Clear the navigation history. Called on major context changes
    /// (route switch, session reset, creator feed).
    func clearNavigationHistory() {
        navigationHistory.clear()
    }

    /// Resolve an artwork by ID from in-memory arrays, falling back to
    /// an API fetch if the artwork is no longer cached locally.
    private func resolveAndSelectArtwork(id: Int) {
        if let artwork = allKnownArtwork(id: id) {
            selectedArtwork = artwork
        } else {
            Task {
                do {
                    let artwork = try await api.illustDetail(illustID: id)
                    selectedArtwork = artwork
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
