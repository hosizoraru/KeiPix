import SwiftUI

struct ArtworkDetailView: View {
    @Bindable var store: KeiPixStore
    var showsNavigationChrome = true

    var body: some View {
        Group {
            if let artwork = store.selectedArtwork {
                ArtworkInspectorView(artwork: artwork, store: store)
                    .id(artwork.id)
            } else {
                EmptyStateView(title: L10n.noArtworkTitle, subtitle: L10n.noArtworkSubtitle, systemImage: "sidebar.trailing")
            }
        }
        .navigationTitle(showsNavigationChrome ? L10n.details : "")
        .toolbar {
            if showsNavigationChrome {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 4) {
                        Button {
                            store.navigateBack()
                        } label: {
                            Label(L10n.goBack, systemImage: "chevron.left")
                        }
                        .labelStyle(.iconOnly)
                        .help(L10n.goBack)
                        .accessibilityLabel(L10n.goBack)
                        .disabled(store.canNavigateBack == false)

                        Button {
                            store.navigateForward()
                        } label: {
                            Label(L10n.goForward, systemImage: "chevron.right")
                        }
                        .labelStyle(.iconOnly)
                        .help(L10n.goForward)
                        .accessibilityLabel(L10n.goForward)
                        .disabled(store.canNavigateForward == false)
                    }
                }
            }
        }
    }
}

private struct ArtworkInspectorView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var expansionState: ArtworkDetailExpansionState
    @State private var pageIndex = 0
    @State private var readingMode: ArtworkReadingMode
    @State private var scrollTarget: Int?

    init(artwork: PixivArtwork, store: KeiPixStore) {
        self.artwork = artwork
        self.store = store
        _expansionState = State(initialValue: store.artworkDetailExpansionState(for: artwork))
        _readingMode = State(initialValue: store.defaultReadingMode(for: artwork))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    if pageCount > 1 {
                        ArtworkReaderControls(
                            pageIndex: $pageIndex,
                            readingMode: $readingMode,
                            pageCount: pageCount,
                            scrollToPage: { index in
                                scrollToPage(index, proxy: proxy)
                            }
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                    }

                    if artwork.isUgoira {
                        UgoiraPlayerView(artwork: artwork, store: store)
                    } else {
                        ArtworkReaderView(
                            artwork: artwork,
                            store: store,
                            pageIndex: $pageIndex,
                            readingMode: $readingMode,
                            scrollTarget: $scrollTarget,
                            scrollToPage: { index in
                                scrollToPage(index, proxy: proxy)
                            }
                        )
                    }

                    ArtworkSummaryView(artwork: artwork, store: store, pageIndex: pageIndex, pageCount: pageCount)
                        .padding(.horizontal, 18)

                    // Information (caption / tags / metadata) sits
                    // right under the summary so the most-used
                    // metadata — translated tags, mute targets,
                    // artwork ID — is the first thing the user
                    // reaches after the action strip. Pixiv Web's
                    // own desktop layout follows the same ordering.
                    ArtworkInformationSections(
                        artwork: artwork,
                        store: store,
                        captionExpanded: detailExpansionBinding(\.isCaptionExpanded),
                        tagsExpanded: detailExpansionBinding(\.isTagsExpanded),
                        metadataExpanded: detailExpansionBinding(\.isMetadataExpanded)
                    )
                    .padding(.horizontal, 18)

                    ArtworkSeriesView(
                        artwork: artwork,
                        store: store,
                        isExpanded: detailExpansionBinding(\.isSeriesExpanded),
                        visualQAResponse: visualQASeriesResponse
                    )
                        .id(artwork.id)
                        .padding(.horizontal, 18)

                    // Comments and related stay below the
                    // metadata so the artwork-centric reading flow
                    // (look at the work → read what the artist
                    // said → see related works) lands before the
                    // social fold.
                    ArtworkCommentsView(
                        artwork: artwork,
                        store: store,
                        isExpanded: detailExpansionBinding(\.isCommentsExpanded),
                        visualQAResponse: visualQACommentsResponse
                    )
                        .id(Self.commentsAnchorID)
                        .padding(.horizontal, 18)

                    ArtworkRelatedView(
                        artwork: artwork,
                        store: store,
                        isExpanded: detailExpansionBinding(\.isRelatedExpanded),
                        visualQAResponse: visualQARelatedResponse
                    )
                        .id(artwork.id)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
            .scrollPosition(id: $scrollTarget, anchor: .top)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: pageIndex) { _, value in
                store.saveReaderPageIndex(value, for: artwork, pageCount: pageCount)
                prefetchAround(value)
            }
            .onChange(of: scrollTarget) { _, value in
                guard effectiveReadingMode == .continuous, let value, value != pageIndex else { return }
                pageIndex = min(max(value, 0), pageCount - 1)
            }
            .onChange(of: readingMode) { _, mode in
                store.setDefaultReadingMode(mode, for: artwork, pageCount: pageCount)
                guard mode.effectiveMode(forPageCount: pageCount) != .singlePage else { return }
                scrollToPage(pageIndex, proxy: proxy)
            }
            .task(id: artwork.id) {
                resetForArtwork()
                prefetchAround(pageIndex)
                await store.recordBrowsingHistory(for: artwork)
                await scrollForVisualQA(proxy: proxy)
            }
        }
    }

    private static let commentsAnchorID = "artwork-detail-comments"

    private var pageCount: Int {
        artwork.displayPageCount
    }

    private var effectiveReadingMode: ArtworkReadingMode {
        readingMode.effectiveMode(forPageCount: pageCount)
    }

    private var usesArtworkDetailSocialVisualQA: Bool {
        #if DEBUG
        return VisualQALaunchArgument.contains(.artworkDetailSocial)
        #else
        return false
        #endif
    }

    private var visualQASeriesResponse: PixivArtworkSeriesResponse? {
        #if DEBUG
        return usesArtworkDetailSocialVisualQA ? VisualQASampleData.seriesResponse : nil
        #else
        return nil
        #endif
    }

    private var visualQACommentsResponse: PixivCommentResponse? {
        #if DEBUG
        return usesArtworkDetailSocialVisualQA ? VisualQASampleData.artworkDetailSocialComments : nil
        #else
        return nil
        #endif
    }

    private var visualQARelatedResponse: PixivFeedResponse? {
        #if DEBUG
        return usesArtworkDetailSocialVisualQA ? VisualQASampleData.artworkDetailSocialRelatedResponse : nil
        #else
        return nil
        #endif
    }

    private func resetForArtwork() {
        expansionState = store.artworkDetailExpansionState(for: artwork)
        readingMode = store.defaultReadingMode(for: artwork, pageCount: pageCount)
        let restoredPageIndex = store.restoredReaderPageIndex(for: artwork, pageCount: pageCount)
        pageIndex = restoredPageIndex
        scrollTarget = effectiveReadingMode == .singlePage ? nil : restoredPageIndex
    }

    private func detailExpansionBinding(_ keyPath: WritableKeyPath<ArtworkDetailExpansionState, Bool>) -> Binding<Bool> {
        Binding {
            expansionState[keyPath: keyPath]
        } set: { value in
            expansionState[keyPath: keyPath] = value
            store.saveArtworkDetailExpansionState(expansionState, for: artwork)
        }
    }

    private func scrollToPage(_ index: Int, proxy: ScrollViewProxy) {
        let clamped = min(max(index, 0), pageCount - 1)
        pageIndex = clamped
        guard effectiveReadingMode != .singlePage else { return }
        withAnimation(.snappy(duration: 0.22)) {
            proxy.scrollTo(clamped, anchor: .top)
        }
    }

    private func scrollForVisualQA(proxy: ScrollViewProxy) async {
        guard usesArtworkDetailSocialVisualQA else { return }
        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.snappy(duration: 0.22)) {
            proxy.scrollTo(Self.commentsAnchorID, anchor: .top)
        }
    }

    private func prefetchAround(_ index: Int) {
        let urls = artwork.prefetchURLs(around: index, preferOriginal: store.preferOriginalImages(for: artwork))
        Task {
            await ImagePipeline.shared.prefetch(urls)
        }
    }
}
