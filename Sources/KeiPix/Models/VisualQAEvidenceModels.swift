import Foundation

enum VisualQASurface: String, CaseIterable, Identifiable, Sendable {
    case discoverDashboard = "discover-dashboard"
    case galleryFeed = "gallery-feed"
    case galleryAuto = "gallery-auto"
    case galleryTwoColumn = "gallery-two-column"
    case galleryThreeColumn = "gallery-three-column"
    case galleryCompact = "gallery-compact"
    case trendingTags = "trending-tags"
    case pixivision
    case pixivLinkDrop = "pixiv-link-drop"
    case mangaWatchlist = "manga-watchlist"
    case seriesSheet = "series-sheet"
    case cachedFeed = "cached-feed"
    case narrowWindow = "narrow-window"
    case downloadQueue = "download-queue"
    case readerWindow = "reader-window"
    case batchBookmarkPreview = "batch-bookmark-preview"
    case settingsWindow = "settings-window"

    var id: String { rawValue }
}

struct VisualQAEvidenceManifest: Identifiable, Hashable, Sendable {
    let id: String
    let surface: VisualQASurface
    let capturedAt: String
    let screenshotPath: String
    let manifestPath: String
}

struct VisualQAEvidenceIndex: Hashable, Sendable {
    let manifests: [VisualQAEvidenceManifest]

    init(manifests: [VisualQAEvidenceManifest]) {
        self.manifests = manifests
    }

    init(rootURL: URL) {
        self.manifests = Self.loadManifests(rootURL: rootURL)
    }

    init(rootURLs: [URL]) {
        var seenPaths = Set<String>()
        self.manifests = rootURLs.flatMap { Self.loadManifests(rootURL: $0) }.filter { manifest in
            seenPaths.insert(manifest.manifestPath).inserted
        }
    }

    func latestManifest(for surface: VisualQASurface) -> VisualQAEvidenceManifest? {
        manifests
            .filter { $0.surface == surface }
            .sorted { $0.capturedAt > $1.capturedAt }
            .first
    }

    func covers(_ surfaces: [VisualQASurface]) -> Bool {
        surfaces.allSatisfy { latestManifest(for: $0) != nil }
    }

    func summary(for surfaces: [VisualQASurface]) -> String {
        let covered = surfaces.filter { latestManifest(for: $0) != nil }
        let latest = surfaces.compactMap { latestManifest(for: $0)?.capturedAt }.max()
        if let latest {
            return String(format: L10n.visualQAEvidenceFormat, covered.count, surfaces.count, latest)
        }
        return String(format: L10n.visualQAEvidenceFormat, covered.count, surfaces.count, L10n.notRun)
    }

    static func manifest(from text: String, manifestPath: String) -> VisualQAEvidenceManifest? {
        let lines = text.split(separator: "\n").map(String.init)
        let values = Dictionary(uniqueKeysWithValues: lines.compactMap { line -> (String, String)? in
            guard line.hasPrefix("- "), let separator = line.firstIndex(of: ":") else { return nil }
            let keyStart = line.index(line.startIndex, offsetBy: 2)
            let key = String(line[keyStart..<separator]).trimmingCharacters(in: .whitespaces)
            let valueStart = line.index(after: separator)
            let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
            return (key, value)
        })

        guard let surfaceText = values["Surface"],
              let surface = VisualQASurface(rawValue: surfaceText),
              let capturedAt = values["Captured at"],
              let screenshot = values["Screenshot"] else {
            return nil
        }

        return VisualQAEvidenceManifest(
            id: "\(surface.rawValue)-\(capturedAt)",
            surface: surface,
            capturedAt: capturedAt,
            screenshotPath: screenshot,
            manifestPath: manifestPath
        )
    }

    private static func loadManifests(rootURL: URL) -> [VisualQAEvidenceManifest] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> VisualQAEvidenceManifest? in
            guard let url = item as? URL, url.pathExtension == "md" else { return nil }
            let isRegularFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isRegularFile, let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return manifest(from: text, manifestPath: url.path(percentEncoded: false))
        }
    }
}
