import SwiftUI

struct NovelRelatedView: View {
    let novelID: Int
    @Bindable var store: KeiPixStore
    @Binding var isExpanded: Bool
    @State private var selectedSeries: NovelSeriesChapterPresentation?

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                if novelStore.isLoadingRelatedNovels {
                    OS26InlineLoadingView(
                        title: L10n.loading,
                        systemImage: "sparkles.rectangle.stack",
                        minHeight: 150
                    )
                } else if novelStore.relatedNovels.isEmpty {
                    OS26InlineUnavailableView(
                        title: L10n.noRelatedNovels,
                        systemImage: "sparkles.rectangle.stack",
                        minHeight: 150
                    )
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(novelStore.relatedNovels) { related in
                            NovelCardView(
                                novel: related,
                                openSeries: seriesButtonAction(for: related)
                            )
                                .onTapGesture {
                                    Task { await novelStore.openNovel(related) }
                                }
                        }
                    }
                }

                if let error = novelStore.relatedNovelsError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if novelStore.relatedNovelsNextURL != nil {
                    OS26PaginationFooter(
                        loadingTitle: L10n.loading,
                        systemImage: "ellipsis.circle",
                        isLoading: novelStore.isLoadingRelatedNovels,
                        minHeight: 96
                    ) {
                        Task { await novelStore.loadMoreRelatedNovels() }
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Label(title, systemImage: "sparkles.rectangle.stack")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .disclosureGroupStyle(.automatic)
        .padding(14)
        .keiGlass(18)
        .task(id: isExpanded) {
            guard isExpanded else { return }
            await novelStore.loadRelatedNovels(for: novelID)
        }
        .sheet(item: $selectedSeries) { presentation in
            NovelSeriesChapterSheet(store: store, presentation: presentation) { chapter in
                Task { await novelStore.openNovel(chapter) }
            }
            #if os(macOS)
            .frame(minWidth: 680, idealWidth: 760, minHeight: 520, idealHeight: 680)
            #endif
            .os26SheetChrome(.chapterList)
        }
    }

    private var title: String {
        let count = novelStore.relatedNovels.count
        return count > 0
            ? "\(L10n.relatedNovels) (\(count.formatted()))"
            : L10n.relatedNovels
    }

    private func seriesButtonAction(for novel: PixivNovel) -> (() -> Void)? {
        guard let presentation = NovelSeriesChapterPresentation(novel: novel) else { return nil }
        return { selectedSeries = presentation }
    }
}
