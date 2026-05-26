import SwiftUI

/// Lets the user pick an arbitrary subset of pages from a multi-page artwork
/// to send to the download queue.
///
/// Mirrors the pattern Pixez ships in `_showMutiChoiceDialog`: each page is a
/// thumbnail tile that toggles selection on tap, with `Select All` / `Clear`
/// shortcuts and a counter showing how many pages will be saved. Built on
/// SwiftUI's `LazyVGrid` so large galleries render without choking the layout
/// pass.
struct DownloadPageSelectionSheet: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let initialPageIndex: Int
    let pageCount: Int
    let onComplete: (Int, [Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPages: Set<Int>

    init(
        artwork: PixivArtwork,
        store: KeiPixStore,
        initialPageIndex: Int,
        pageCount: Int,
        onComplete: @escaping (Int, [Int]) -> Void
    ) {
        self.artwork = artwork
        self.store = store
        self.initialPageIndex = initialPageIndex
        self.pageCount = max(pageCount, 1)
        self.onComplete = onComplete

        let clamped = min(max(initialPageIndex, 0), max(pageCount - 1, 0))
        _selectedPages = State(initialValue: [clamped])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.selectPagesToSave)
                        .font(.title3.weight(.semibold))
                    Text(String(format: L10n.pagesSelectedFormat, selectedPages.count, pageCount))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                SheetCloseButton(style: .plain)
            }

            HStack(spacing: 8) {
                Button(L10n.selectAllPages) {
                    selectedPages = Set(0..<pageCount)
                }
                .controlSize(.small)
                .disabled(selectedPages.count == pageCount)

                Button(L10n.clearPageSelection) {
                    selectedPages.removeAll()
                }
                .controlSize(.small)
                .disabled(selectedPages.isEmpty)
            }

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        pageTile(index: index)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 360)

            Divider()

            HStack {
                Spacer()
                Button(L10n.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    enqueueSelection()
                } label: {
                    Label(L10n.addToDownloadQueue, systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPages.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 540)
    }

    private var gridColumns: [GridItem] {
        // Three columns at the chosen sheet width fit a 3:2 thumbnail nicely
        // without forcing the user to scroll for typical 4–8 page sets.
        Array(repeating: GridItem(.flexible(minimum: 110), spacing: 12), count: 3)
    }

    private func pageTile(index: Int) -> some View {
        let isSelected = selectedPages.contains(index)
        return Button {
            toggle(index)
        } label: {
            ZStack(alignment: .topTrailing) {
                RemoteImageView(
                    url: artwork.imageURL(at: index, preferOriginal: false),
                    contentMode: .fill
                )
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.85))
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 22, height: 22)
                    )
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                Text("\(index + 1)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                    .padding(6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ index: Int) {
        if selectedPages.contains(index) {
            selectedPages.remove(index)
        } else {
            selectedPages.insert(index)
        }
    }

    private func enqueueSelection() {
        let indexes = selectedPages.sorted()
        let queuedCount = store.enqueueDownloadPages(
            artwork,
            pageIndexes: indexes,
            preferOriginal: store.preferOriginalImages(for: artwork, pageCount: pageCount)
        )
        onComplete(queuedCount, indexes)
        dismiss()
    }
}
