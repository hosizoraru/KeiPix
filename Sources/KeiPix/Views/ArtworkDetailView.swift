import SwiftUI

struct ArtworkDetailView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Group {
            if let artwork = store.selectedArtwork {
                ArtworkInspectorView(artwork: artwork, store: store)
                    .id(artwork.id)
            } else {
                EmptyStateView(title: L10n.noArtworkTitle, subtitle: L10n.noArtworkSubtitle, systemImage: "sidebar.trailing")
            }
        }
        .navigationTitle(L10n.details)
    }
}

private struct ArtworkInspectorView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var captionExpanded = false
    @State private var tagsExpanded = false
    @State private var metadataExpanded = false
    @State private var pageIndex = 0
    @State private var readingMode: ArtworkReadingMode
    @State private var scrollTarget: Int?

    init(artwork: PixivArtwork, store: KeiPixStore) {
        self.artwork = artwork
        self.store = store
        _readingMode = State(initialValue: ArtworkReadingMode.defaultMode(for: artwork.displayPageCount))
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

                    ArtworkCommentsView(artwork: artwork, store: store)
                        .padding(.horizontal, 18)

                    ArtworkRelatedView(artwork: artwork, store: store)
                        .id(artwork.id)
                        .padding(.horizontal, 18)

                    ArtworkInformationSections(
                        artwork: artwork,
                        captionExpanded: $captionExpanded,
                        tagsExpanded: $tagsExpanded,
                        metadataExpanded: $metadataExpanded
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
            .scrollPosition(id: $scrollTarget, anchor: .top)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: pageIndex) { _, value in
                prefetchAround(value)
            }
            .onChange(of: scrollTarget) { _, value in
                guard readingMode == .continuous, let value, value != pageIndex else { return }
                pageIndex = min(max(value, 0), pageCount - 1)
            }
            .onChange(of: readingMode) { _, mode in
                guard mode != .singlePage else { return }
                scrollToPage(pageIndex, proxy: proxy)
            }
            .task(id: artwork.id) {
                resetForArtwork()
                prefetchAround(0)
            }
        }
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }

    private func resetForArtwork() {
        captionExpanded = false
        tagsExpanded = false
        metadataExpanded = false
        pageIndex = 0
        scrollTarget = nil
        readingMode = ArtworkReadingMode.defaultMode(for: pageCount)
    }

    private func scrollToPage(_ index: Int, proxy: ScrollViewProxy) {
        let clamped = min(max(index, 0), pageCount - 1)
        pageIndex = clamped
        guard readingMode != .singlePage else { return }
        withAnimation(.snappy(duration: 0.22)) {
            proxy.scrollTo(clamped, anchor: .top)
        }
    }

    private func prefetchAround(_ index: Int) {
        let urls = artwork.prefetchURLs(around: index, preferOriginal: store.useOriginalImagesInDetail)
        Task {
            await ImagePipeline.shared.prefetch(urls)
        }
    }
}
