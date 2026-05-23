import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class KeiPixStore {
    var session: PixivSession?
    var selectedRoute: PixivRoute = .illustrations
    var artworks: [PixivArtwork] = []
    var selectedArtwork: PixivArtwork?
    var searchText = ""
    var errorMessage: String?
    var isLoading = false
    var isLoadingMore = false
    var isLoginPresented = false
    var appLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        .flatMap(AppLanguage.init(rawValue:)) ?? .automatic
    var useOriginalImagesInDetail = UserDefaults.standard.bool(forKey: "useOriginalImagesInDetail")
    var galleryLayoutMode = KeiPixStore.loadGalleryLayoutMode()
    var trackpadGesturesEnabled = UserDefaults.standard.object(forKey: "trackpadGesturesEnabled") as? Bool ?? true
    var horizontalSwipeBehavior = UserDefaults.standard.string(forKey: "horizontalSwipeBehavior")
        .flatMap(TrackpadHorizontalSwipeBehavior.init(rawValue:)) ?? .pageOnly
    var hasNextPage: Bool { nextURL != nil }
    var compactArtworkCards: Bool { galleryLayoutMode.usesCompactGrid }

    private let api = PixivAPI()
    private var nextURL: URL?

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        do {
            session = try await api.loadSession()
            if session != nil {
                await reloadCurrentFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginURL() async -> URL {
        await api.makeLoginURL()
    }

    func completeLogin(code: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            session = try await api.login(code: code)
            isLoginPresented = false
            selectedRoute = .illustrations
            await reloadCurrentFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            try await api.clearSession()
            session = nil
            artworks = []
            selectedArtwork = nil
            nextURL = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ route: PixivRoute) {
        selectedRoute = route
        Task { await reloadCurrentFeed() }
    }

    func reloadCurrentFeed() async {
        guard session != nil else {
            artworks = []
            selectedArtwork = nil
            nextURL = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await loadFeed(for: selectedRoute)
            artworks = response.illusts
            nextURL = response.nextURL
            selectedArtwork = response.illusts.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await api.nextFeed(nextURL)
            artworks.append(contentsOf: response.illusts)
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runSearch() async {
        selectedRoute = .search
        await reloadCurrentFeed()
    }

    func toggleBookmark(_ artwork: PixivArtwork) async {
        let nextValue = !artwork.isBookmarked
        do {
            try await api.setBookmark(illustID: artwork.id, isBookmarked: nextValue)
            updateArtwork(artwork.id) { $0.isBookmarked = nextValue }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFollow(_ user: PixivUser) async {
        let nextValue = !user.isFollowed
        do {
            try await api.setFollow(userID: user.id, isFollowed: nextValue)
            for index in artworks.indices where artworks[index].user.id == user.id {
                artworks[index].user.isFollowed = nextValue
            }
            if selectedArtwork?.user.id == user.id {
                selectedArtwork?.user.isFollowed = nextValue
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setUseOriginalImagesInDetail(_ value: Bool) {
        useOriginalImagesInDetail = value
        UserDefaults.standard.set(value, forKey: "useOriginalImagesInDetail")
    }

    func setAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
    }

    func setCompactArtworkCards(_ value: Bool) {
        setGalleryLayoutMode(value ? .compactGrid : .autoMasonry)
    }

    func setGalleryLayoutMode(_ mode: GalleryLayoutMode) {
        galleryLayoutMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "galleryLayoutMode")
        UserDefaults.standard.set(mode.usesCompactGrid, forKey: "compactArtworkCards")
    }

    func setTrackpadGesturesEnabled(_ value: Bool) {
        trackpadGesturesEnabled = value
        UserDefaults.standard.set(value, forKey: "trackpadGesturesEnabled")
    }

    func setHorizontalSwipeBehavior(_ behavior: TrackpadHorizontalSwipeBehavior) {
        horizontalSwipeBehavior = behavior
        UserDefaults.standard.set(behavior.rawValue, forKey: "horizontalSwipeBehavior")
    }

    @discardableResult
    func selectAdjacentArtwork(delta: Int) -> Bool {
        guard let selectedArtwork,
              let index = artworks.firstIndex(where: { $0.id == selectedArtwork.id }) else {
            return false
        }
        let nextIndex = index + delta
        guard artworks.indices.contains(nextIndex) else { return false }
        self.selectedArtwork = artworks[nextIndex]
        return true
    }

    private func loadFeed(for route: PixivRoute) async throws -> PixivFeedResponse {
        switch route {
        case .illustrations:
            return try await api.recommendedIllusts()
        case .mangaRecommended:
            return try await api.recommendedMangas()
        case .search:
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if keyword.isEmpty {
                return PixivFeedResponse(illusts: [], nextURL: nil)
            }
            return try await api.search(keyword: keyword)
        case .rankingDaily:
            return try await api.ranking(mode: "day")
        case .rankingWeekly:
            return try await api.ranking(mode: "week")
        case .rankingMonthly:
            return try await api.ranking(mode: "month")
        case .mangaRankingDaily:
            return try await api.ranking(mode: "day_manga")
        case .mangaRankingWeekly:
            return try await api.ranking(mode: "week_manga")
        case .mangaRankingMonthly:
            return try await api.ranking(mode: "month_manga")
        case .publicBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "public", userID: userID)
        case .privateBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "private", userID: userID)
        case .following:
            return try await api.following()
        }
    }

    private func updateArtwork(_ id: Int, mutate: (inout PixivArtwork) -> Void) {
        if let index = artworks.firstIndex(where: { $0.id == id }) {
            mutate(&artworks[index])
            if selectedArtwork?.id == id {
                selectedArtwork = artworks[index]
            }
        }
    }

    private static func loadGalleryLayoutMode() -> GalleryLayoutMode {
        let defaults = UserDefaults.standard
        if let rawValue = defaults.string(forKey: "galleryLayoutMode"),
           let mode = GalleryLayoutMode(rawValue: rawValue) {
            return mode
        }

        let mode: GalleryLayoutMode = defaults.bool(forKey: "compactArtworkCards")
            ? .compactGrid
            : .autoMasonry
        defaults.set(mode.rawValue, forKey: "galleryLayoutMode")
        return mode
    }
}
