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
        .disabled(isUpdatingFollow)
        .sheet(item: $feedbackRequest) { request in
            FeedbackReportSheet(request: request) {
                store.requestDangerAction(AppDangerAction(kind: .muteCreator(artwork.user)))
            } onComplete: { message in
                showActionMessage(message)
            }
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

                HStack(spacing: 10) {
                    Button {
                        isBookmarkEditorPresented = true
                    } label: {
                        Label(artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark, systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .sheet(isPresented: $isBookmarkEditorPresented) {
                        BookmarkEditorView(artwork: artwork, store: store) {
                            showActionMessage(String(format: L10n.savedBookmarkFormat, artwork.title))
                        }
                    }

                    Button {
                        if downloadState == .downloaded {
                            store.prepareReaderWindow(for: artwork)
                            openWindow(id: "artwork-reader")
                        } else {
                            store.enqueueDownload(artwork)
                            showActionMessage(String(format: L10n.queuedDownloadsFormat, 1))
                        }
                    } label: {
                        Label(downloadPrimaryTitle, systemImage: downloadPrimarySystemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        store.prepareReaderWindow(for: artwork)
                        openWindow(id: "artwork-reader")
                    } label: {
                        Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Menu {
                        Button {
                            store.prepareReaderWindow(for: artwork)
                            openWindow(id: "artwork-reader")
                        } label: {
                            Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
                        }

                        Divider()

                        if let url = artwork.pixivURL {
                            ShareLink(item: url) {
                                Label(L10n.share, systemImage: "square.and.arrow.up")
                            }

                            Button {
                                PasteboardWriter.copy(url.absoluteString)
                                showActionMessage(L10n.copied)
                            } label: {
                                Label(L10n.copyLink, systemImage: "link")
                            }
                        }

                        if let sharePageURL {
                            ShareLink(item: sharePageURL) {
                                Label(L10n.shareCurrentPage, systemImage: "photo")
                            }
                        }

                        if currentPageURL != nil || currentLocalPageURL != nil {
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
                                    preferOriginal: store.useOriginalImagesInDetail
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
                                NSWorkspace.shared.activateFileViewerSelecting([currentLocalPageURL])
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .sheet(item: $feedbackRequest) { request in
                        FeedbackReportSheet(request: request) {
                            store.requestDangerAction(AppDangerAction(kind: .muteArtwork(artwork)))
                        } onComplete: { message in
                            showActionMessage(message)
                        }
                    }
                }

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
        }
        .sheet(isPresented: $isPageSelectionDownloadPresented) {
            DownloadPageSelectionSheet(
                artwork: artwork,
                store: store,
                initialPageIndex: pageIndex,
                pageCount: pageCount,
                onComplete: showPageSelectionDownloadMessage
            )
        }
        .sheet(isPresented: $isBulkBlockPresented) {
            BulkBlockSheet(artwork: artwork, store: store) { applied in
                showBulkBlockMessage(applied)
            }
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
        artwork.imageURL(at: pageIndex, preferOriginal: store.useOriginalImagesInDetail)
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
