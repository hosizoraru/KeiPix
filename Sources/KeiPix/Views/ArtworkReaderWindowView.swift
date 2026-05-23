import SwiftUI

struct ArtworkReaderWindowView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Group {
            if let artwork = store.readerWindowArtwork {
                StandaloneArtworkReader(artwork: artwork, store: store)
                    .id(artwork.id)
            } else {
                EmptyStateView(
                    title: L10n.noArtworkTitle,
                    subtitle: L10n.noArtworkSubtitle,
                    systemImage: "rectangle.inset.filled"
                )
            }
        }
        .navigationTitle(L10n.readerWindow)
    }
}

private struct StandaloneArtworkReader: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

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
            VStack(spacing: 0) {
                header(proxy: proxy)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.bar)

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
                    }
                    .padding(.bottom, 18)
                }
                .scrollPosition(id: $scrollTarget, anchor: .top)
                .scrollEdgeEffectStyle(.soft, for: .top)
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
                await store.recordBrowsingHistory(for: artwork)
            }
            .onChange(of: pageIndex) { _, value in
                prefetchAround(value)
            }
        }
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }

    private func header(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(artwork.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(artwork.user.name) · \(pageCount)P")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                scrollToPage(pageIndex - 1, proxy: proxy)
            } label: {
                Label(L10n.previousPage, systemImage: "chevron.left")
            }
            .disabled(pageIndex <= 0)

            Text(L10n.pageStatus(pageIndex + 1, pageCount))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 110)

            Button {
                scrollToPage(pageIndex + 1, proxy: proxy)
            } label: {
                Label(L10n.nextPage, systemImage: "chevron.right")
            }
            .disabled(pageIndex >= pageCount - 1)
        }
    }

    private func resetForArtwork() {
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
