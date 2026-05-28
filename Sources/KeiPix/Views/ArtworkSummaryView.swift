import SwiftUI

struct ArtworkSummaryView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let pageIndex: Int
    let pageCount: Int
    @State private var isUserProfilePresented = false
    @State private var creatorActionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(artwork.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(3)
                    .textSelection(.enabled)

                if store.showContentBadges {
                    ArtworkContentBadgesView(badges: artwork.contentBadges)
                }

                HStack(spacing: 10) {
                    Button {
                        isUserProfilePresented = true
                    } label: {
                        HStack(spacing: 10) {
                            RemoteImageView(url: artwork.user.avatarURL)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 1) {
                                Text(artwork.user.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("@\(artwork.user.account)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(L10n.openCreatorProfile)

                    CreatorQuickActionsMenu(
                        artwork: artwork,
                        store: store,
                        showActionMessage: showCreatorActionMessage
                    ) {
                        isUserProfilePresented = true
                    }
                }
                .sheet(isPresented: $isUserProfilePresented) {
                    UserProfileSheet(user: artwork.user, store: store)
                        .iPadFriendlySheet()
                }

                if let creatorActionMessage {
                    Text(creatorActionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            ArtworkActionStrip(artwork: artwork, store: store, pageIndex: pageIndex, pageCount: pageCount)
        }
        .padding(14)
        .keiPanel(18)
    }

    private func showCreatorActionMessage(_ message: String) {
        creatorActionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if creatorActionMessage == message {
                creatorActionMessage = nil
            }
        }
    }
}

private struct CreatorQuickActionsMenu: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let showActionMessage: (String) -> Void
    let openProfile: () -> Void
    @State private var isUpdatingFollow = false
    @State private var feedbackRequest: FeedbackReportRequest?

    var body: some View {
        Menu {
            Button {
                openProfile()
            } label: {
                Label(L10n.openCreatorProfile, systemImage: "person.crop.rectangle")
            }

            if let url = artwork.user.pixivURL {
                Link(destination: url) {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }

                Button {
                    PasteboardWriter.copy(url.absoluteString)
                    showActionMessage(L10n.copied)
                } label: {
                    Label(L10n.copyLink, systemImage: "link")
                }
            }

            Divider()

            if artwork.user.isFollowed {
                Button(role: .destructive) {
                    store.requestDangerAction(
                        AppDangerAction(kind: .unfollowCreator(artwork.user, nil))
                    )
                } label: {
                    Label(L10n.unfollow, systemImage: "person.badge.minus")
                }
            } else {
                Button {
                    Task { await follow(artwork.user, restrict: nil) }
                } label: {
                    Label(L10n.followUsingDefault, systemImage: "person.badge.plus")
                }
                .disabled(isUpdatingFollow)

                Button {
                    Task { await follow(artwork.user, restrict: .public) }
                } label: {
                    Label(L10n.followPublicly, systemImage: "person.2")
                }
                .disabled(isUpdatingFollow)

                Button {
                    Task { await follow(artwork.user, restrict: .private) }
                } label: {
                    Label(L10n.followPrivately, systemImage: "lock")
                }
                .disabled(isUpdatingFollow)
            }

            Divider()

            Button {
                feedbackRequest = .creator(artwork.user)
            } label: {
                Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
            }
        } label: {
            Image(systemName: artwork.user.isFollowed ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                .frame(width: 28, height: 28)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(artwork.user.isFollowed ? L10n.unfollow : L10n.follow)
        .accessibilityLabel(artwork.user.isFollowed ? L10n.unfollow : L10n.follow)
        .disabled(isUpdatingFollow)
        .sheet(item: $feedbackRequest) { request in
            FeedbackReportSheet(request: request) {
                store.requestDangerAction(AppDangerAction(kind: .muteCreator(artwork.user)))
            } onComplete: { message in
                showActionMessage(message)
            }
            .iPadFriendlySheet()
        }
    }

    private func follow(_ user: PixivUser, restrict: BookmarkRestrict?) async {
        guard isUpdatingFollow == false else { return }
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }

        do {
            try await store.setFollow(user, isFollowed: true, restrict: restrict ?? store.defaultFollowRestrict)
            showActionMessage(String(format: L10n.followedCreatorFormat, user.name))
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

private struct ArtworkActionStrip: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let pageIndex: Int
    let pageCount: Int

    @Environment(\.openWindow) private var openWindow
    @State private var isBookmarkEditorPresented = false
    @State private var actionMessage: String?
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var isPageRangeDownloadPresented = false
    @State private var isPageSelectionDownloadPresented = false
    @State private var isBulkBlockPresented = false

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    MetricView(title: L10n.views, value: artwork.totalView, systemImage: "eye")
                    MetricView(title: L10n.saves, value: artwork.totalBookmarks, systemImage: "bookmark")
                    MetricView(title: L10n.comments, value: artwork.totalComments, systemImage: "text.bubble")
                    MetricView(title: L10n.pages, value: pageCount, systemImage: "square.stack", detail: pageCount > 1 ? "\(pageIndex + 1) / \(pageCount)" : nil)
                }

                if let actionMessage {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if downloadState != .none {
                    DownloadStateSummary(state: downloadState)
                }

                AdaptiveActionRow(artwork: artwork, store: store, pageIndex: pageIndex, pageCount: pageCount, downloadState: downloadState, downloadPrimaryTitle: downloadPrimaryTitle, downloadPrimarySystemImage: downloadPrimarySystemImage, currentPageURL: currentPageURL, sharePageURL: sharePageURL, currentLocalPageURL: currentLocalPageURL, downloadedItem: downloadedItem, artworkSummaryText: artworkSummaryText, isBookmarkEditorPresented: $isBookmarkEditorPresented, isPageRangeDownloadPresented: $isPageRangeDownloadPresented, isPageSelectionDownloadPresented: $isPageSelectionDownloadPresented, isBulkBlockPresented: $isBulkBlockPresented, feedbackRequest: $feedbackRequest, showActionMessage: showActionMessage, copyArtworkSummary: copyArtworkSummary)

            }
        }
        .sheet(isPresented: $isPageRangeDownloadPresented) {
            DownloadPageRangeSheet(
                artwork: artwork,
                store: store,
                initialPageIndex: pageIndex,
                pageCount: pageCount,
                onComplete: showPageRangeDownloadMessage
            )
            .iPadFriendlySheet()
        }
        .sheet(isPresented: $isPageSelectionDownloadPresented) {
            DownloadPageSelectionSheet(
                artwork: artwork,
                store: store,
                initialPageIndex: pageIndex,
                pageCount: pageCount,
                onComplete: showPageSelectionDownloadMessage
            )
            .iPadFriendlySheet()
        }
        .sheet(isPresented: $isBulkBlockPresented) {
            BulkBlockSheet(artwork: artwork, store: store) { applied in
                showBulkBlockMessage(applied)
            }
            .iPadFriendlySheet()
        }
    }

    private func copyArtworkSummary() {
        PasteboardWriter.copy(artworkSummaryText)
        showActionMessage(L10n.copiedArtworkSummary)
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message

        Task {
            try? await Task.sleep(for: .seconds(2))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }

    private func showPageRangeDownloadMessage(_ queuedCount: Int, _ oneBasedRange: ClosedRange<Int>) {
        if queuedCount > 0 {
            showActionMessage(String(
                format: L10n.queuedPageRangeFormat,
                oneBasedRange.lowerBound,
                oneBasedRange.upperBound,
                queuedCount
            ))
        } else {
            showActionMessage(L10n.noDownloadRecordsChanged)
        }
    }

    private func showPageSelectionDownloadMessage(_ queuedCount: Int, _ pageIndexes: [Int]) {
        // The bulk-queue API returns 0 when the same selection is already in
        // flight; mirror the page-range message so the UI feels consistent
        // and tells the user something either way.
        guard queuedCount > 0, pageIndexes.isEmpty == false else {
            showActionMessage(L10n.noDownloadRecordsChanged)
            return
        }
        showActionMessage(String(format: L10n.pagesSelectedFormat, queuedCount, pageCount))
    }

    private func showBulkBlockMessage(_ applied: Int) {
        guard applied > 0 else { return }
        showActionMessage(String(format: L10n.bulkBlockSummaryFormat, applied))
    }

    private var currentPageURL: URL? {
        artwork.imageURL(at: pageIndex, preferOriginal: store.preferOriginalImages(for: artwork, pageCount: pageCount))
    }

    private var currentLocalPageURL: URL? {
        store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: pageIndex)
    }

    private var downloadedItem: ArtworkDownloadItem? {
        store.downloads.completedDownloadItem(for: artwork.id)
    }

    private var downloadState: ArtworkDownloadArtworkState {
        store.downloads.downloadState(for: artwork.id)
    }

    private var downloadPrimaryTitle: String {
        downloadState == .downloaded ? L10n.openDownloadedArtwork : L10n.download
    }

    private var downloadPrimarySystemImage: String {
        downloadState == .downloaded ? "book" : "arrow.down.circle"
    }

    private var sharePageURL: URL? {
        currentLocalPageURL ?? currentPageURL
    }

    private var artworkSummaryText: String {
        store.renderArtworkCopySummary(artwork, pageCount: pageCount)
    }
}

// MARK: - Adaptive action row

/// Measures available width and promotes secondary actions from the
/// "more" menu to inline icon buttons as space allows.
///
/// Width tiers (approximate, accounts for Dynamic Type):
///   < 280  → Bookmark · Download · More          (compact)
///   280–400 → + Open Reader                       (default inspector)
///   400–520 → + Share · Copy Link                  (wide inspector)
///   ≥ 520  → + Search Source · Watch Later          (full-width)
private struct AdaptiveActionRow: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let pageIndex: Int
    let pageCount: Int
    let downloadState: ArtworkDownloadArtworkState
    let downloadPrimaryTitle: String
    let downloadPrimarySystemImage: String
    let currentPageURL: URL?
    let sharePageURL: URL?
    let currentLocalPageURL: URL?
    let downloadedItem: ArtworkDownloadItem?
    let artworkSummaryText: String
    @Binding var isBookmarkEditorPresented: Bool
    @Binding var isPageRangeDownloadPresented: Bool
    @Binding var isPageSelectionDownloadPresented: Bool
    @Binding var isBulkBlockPresented: Bool
    @Binding var feedbackRequest: FeedbackReportRequest?
    let showActionMessage: (String) -> Void
    let copyArtworkSummary: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 10) {
                bookmarkButton
                downloadButton

                if geo.size.width >= 280 {
                    openReaderButton
                }

                if geo.size.width >= 400, artwork.pixivURL != nil {
                    shareButton
                    copyLinkButton
                }

                if geo.size.width >= 520 {
                    if currentPageURL != nil || currentLocalPageURL != nil {
                        searchImageButton
                    }
                    watchLaterButton
                }

                moreMenu(promoteShare: geo.size.width >= 400,
                         promoteSearch: geo.size.width >= 520,
                         promoteWatchLater: geo.size.width >= 520)
            }
        }
        .frame(height: 28)
    }

    // MARK: - Inline buttons

    private var bookmarkButton: some View {
        Button {
            isBookmarkEditorPresented = true
        } label: {
            Label(artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark,
                  systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
        }
        .labelStyle(.iconOnly)
        .help(artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark)
        .accessibilityLabel(artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark)
        .buttonStyle(.glassProminent)
        .controlSize(.small)
        .sheet(isPresented: $isBookmarkEditorPresented) {
            BookmarkEditorView(artwork: artwork, store: store) {
                showActionMessage(String(format: L10n.savedBookmarkFormat, artwork.title))
            }
            .iPadFriendlySheet()
        }
    }

    private var downloadButton: some View {
        Button {
            if downloadState == .downloaded {
                store.prepareReaderWindow(for: artwork)
                openWindow(id: "artwork-reader", value: artwork.id)
            } else {
                store.enqueueDownload(artwork)
                showActionMessage(String(format: L10n.queuedDownloadsFormat, 1))
            }
        } label: {
            Label(downloadPrimaryTitle, systemImage: downloadPrimarySystemImage)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(downloadPrimaryTitle)
        .accessibilityLabel(downloadPrimaryTitle)
    }

    private var openReaderButton: some View {
        Button {
            store.prepareReaderWindow(for: artwork)
            openWindow(id: "artwork-reader", value: artwork.id)
        } label: {
            Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(L10n.openReaderWindow)
        .accessibilityLabel(L10n.openReaderWindow)
    }

    private var shareButton: some View {
        Group {
            if let url = artwork.pixivURL {
                ShareLink(item: url) {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.share)
                .accessibilityLabel(L10n.share)
            }
        }
    }

    private var copyLinkButton: some View {
        Group {
            if let url = artwork.pixivURL {
                Button {
                    PasteboardWriter.copy(url.absoluteString)
                    showActionMessage(L10n.copied)
                } label: {
                    Label(L10n.copyLink, systemImage: "link")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.copyLink)
                .accessibilityLabel(L10n.copyLink)
            }
        }
    }

    private var searchImageButton: some View {
        Button {
            store.presentImageSourceSearch(for: artwork, pageIndex: pageIndex)
        } label: {
            Label(L10n.searchImageSource, systemImage: "magnifyingglass")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(L10n.searchImageSource)
        .accessibilityLabel(L10n.searchImageSource)
    }

    private var watchLaterButton: some View {
        Button {
            if store.isInWatchLater(artwork.id) {
                store.removeFromWatchLater(LocalArtworkHistoryItem(artwork: artwork))
                showActionMessage(L10n.watchLaterRemoved)
            } else {
                store.addToWatchLater(artwork)
                showActionMessage(L10n.watchLaterAdded)
            }
        } label: {
            Label(
                store.isInWatchLater(artwork.id) ? L10n.watchLaterRemoved : L10n.watchLaterAdded,
                systemImage: store.isInWatchLater(artwork.id) ? "clock.badge.xmark" : "clock.badge.plus"
            )
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(store.isInWatchLater(artwork.id) ? L10n.watchLaterRemoved : L10n.watchLaterAdded)
        .accessibilityLabel(store.isInWatchLater(artwork.id) ? L10n.watchLaterRemoved : L10n.watchLaterAdded)
    }

    // MARK: - More menu

    @ViewBuilder
    private func moreMenu(promoteShare: Bool, promoteSearch: Bool, promoteWatchLater: Bool) -> some View {
        Menu {
            // Open reader — always in menu as a text entry for discoverability
            Button {
                store.prepareReaderWindow(for: artwork)
                openWindow(id: "artwork-reader", value: artwork.id)
            } label: {
                Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
            }

            Divider()

            if let url = artwork.pixivURL {
                if promoteShare == false {
                    ShareLink(item: url) {
                        Label(L10n.share, systemImage: "square.and.arrow.up")
                    }
                }

                ShareLink(
                    item: artworkSummaryText,
                    subject: Text(artwork.title),
                    message: Text(artworkSummaryText)
                ) {
                    Label(L10n.shareSummary, systemImage: "text.bubble")
                }
                .help(L10n.shareSummaryHint)

                if promoteShare == false {
                    Button {
                        PasteboardWriter.copy(url.absoluteString)
                        showActionMessage(L10n.copied)
                    } label: {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                }
            }

            if let sharePageURL {
                ShareLink(item: sharePageURL) {
                    Label(L10n.shareCurrentPage, systemImage: "photo")
                }
            }

            if promoteSearch == false, currentPageURL != nil || currentLocalPageURL != nil {
                Button {
                    store.presentImageSourceSearch(for: artwork, pageIndex: pageIndex)
                } label: {
                    Label(L10n.searchImageSource, systemImage: "magnifyingglass")
                }
            }

            if let currentPageURL {
                Button {
                    PasteboardWriter.copy(currentPageURL.absoluteString)
                    showActionMessage(L10n.copied)
                } label: {
                    Label(L10n.copyCurrentPageLink, systemImage: "link")
                }

                Button {
                    store.enqueueDownloadPage(
                        artwork,
                        pageIndex: pageIndex,
                        preferOriginal: store.preferOriginalImages(for: artwork, pageCount: pageCount)
                    )
                    showActionMessage(L10n.queuedCurrentPage)
                } label: {
                    Label(L10n.downloadCurrentPage, systemImage: "arrow.down.circle")
                }
            }

            if artwork.isUgoira == false && pageCount > 1 {
                Button {
                    isPageRangeDownloadPresented = true
                } label: {
                    Label(L10n.downloadPageRange, systemImage: "text.page.badge.magnifyingglass")
                }

                Button {
                    isPageSelectionDownloadPresented = true
                } label: {
                    Label(L10n.downloadSelectedPages, systemImage: "checklist")
                }
            }

            if let currentLocalPageURL {
                Button {
                    PlatformWorkspace.revealInFiles(currentLocalPageURL)
                } label: {
                    Label(L10n.revealCurrentPage, systemImage: "folder")
                }
            }

            if let downloadedItem {
                Button {
                    _ = store.downloads.reveal(downloadedItem)
                    showActionMessage(L10n.revealedDownloadInFinder)
                } label: {
                    Label(L10n.revealDownloadedArtwork, systemImage: "folder")
                }
            }

            Divider()

            if promoteWatchLater == false {
                if store.isInWatchLater(artwork.id) {
                    Button {
                        store.removeFromWatchLater(LocalArtworkHistoryItem(artwork: artwork))
                        showActionMessage(L10n.watchLaterRemoved)
                    } label: {
                        Label(L10n.watchLaterRemoved, systemImage: "clock.badge.xmark")
                    }
                } else {
                    Button {
                        store.addToWatchLater(artwork)
                        showActionMessage(L10n.watchLaterAdded)
                    } label: {
                        Label(L10n.watchLaterAdded, systemImage: "clock.badge.plus")
                    }
                }
            }

            Divider()

            Button {
                copyArtworkSummary()
            } label: {
                Label(L10n.copyArtworkSummary, systemImage: "doc.text")
            }

            Button {
                feedbackRequest = .artwork(artwork)
            } label: {
                Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
            }

            Divider()

            Button(L10n.muteArtwork) {
                store.requestDangerAction(AppDangerAction(kind: .muteArtwork(artwork)))
            }
            Button(L10n.muteCreator) {
                store.requestDangerAction(AppDangerAction(kind: .muteCreator(artwork.user)))
            }
            if artwork.tags.isEmpty == false {
                Menu(L10n.muteTag) {
                    ForEach(artwork.tags, id: \.self) { tag in
                        Button("#\(tag.name)") {
                            store.requestDangerAction(AppDangerAction(kind: .muteTag(tag)))
                        }
                    }
                }
            }

            Divider()

            Button {
                isBulkBlockPresented = true
            } label: {
                Label(L10n.blockFromArtwork, systemImage: "hand.raised")
            }
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(L10n.moreActions)
        .accessibilityLabel(L10n.moreActions)
        .sheet(item: $feedbackRequest) { request in
            FeedbackReportSheet(request: request) {
                store.requestDangerAction(AppDangerAction(kind: .muteArtwork(artwork)))
            } onComplete: { message in
                showActionMessage(message)
            }
            .iPadFriendlySheet()
        }
    }
}

private struct DownloadStateSummary: View {
    let state: ArtworkDownloadArtworkState

    var body: some View {
        Label(state.title, systemImage: state.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .help(state.title)
    }

    private var tint: Color {
        switch state {
        case .none:
            .secondary
        case .queued:
            .secondary
        case .downloading:
            .blue
        case .downloaded:
            .green
        case .failed:
            .orange
        }
    }
}

private struct MetricView: View {
    let title: String
    let value: Int
    let systemImage: String
    var detail: String?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(detail ?? value.formatted())
                    .font(.headline)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
