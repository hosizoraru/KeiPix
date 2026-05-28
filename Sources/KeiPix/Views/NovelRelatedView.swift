import SwiftUI

struct NovelRelatedView: View {
    let novelID: Int
    @Bindable var store: KeiPixStore
    @Binding var isExpanded: Bool

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                if novelStore.isLoadingRelatedNovels {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if novelStore.relatedNovels.isEmpty {
                    ContentUnavailableView(
                        L10n.noRelatedNovels,
                        systemImage: "sparkles.rectangle.stack"
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(novelStore.relatedNovels) { related in
                            NovelCardView(novel: related)
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
                    Button {
                        Task { await novelStore.loadMoreRelatedNovels() }
                    } label: {
                        Label(L10n.loadMoreRelatedNovels, systemImage: "ellipsis.circle")
                    }
                    .buttonStyle(.bordered)
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
        .keiPanel(16)
        .task(id: isExpanded) {
            guard isExpanded else { return }
            await novelStore.loadRelatedNovels(for: novelID)
        }
    }

    private var title: String {
        let count = novelStore.relatedNovels.count
        return count > 0
            ? "\(L10n.relatedNovels) (\(count.formatted()))"
            : L10n.relatedNovels
    }
}
