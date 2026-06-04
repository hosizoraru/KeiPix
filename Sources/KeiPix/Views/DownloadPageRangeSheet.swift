import SwiftUI

struct DownloadPageRangeSheet: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let initialPageIndex: Int
    let pageCount: Int
    let onComplete: (Int, ClosedRange<Int>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startPage: Int
    @State private var endPage: Int

    init(
        artwork: PixivArtwork,
        store: KeiPixStore,
        initialPageIndex: Int,
        pageCount: Int,
        onComplete: @escaping (Int, ClosedRange<Int>) -> Void
    ) {
        self.artwork = artwork
        self.store = store
        self.initialPageIndex = initialPageIndex
        self.pageCount = max(pageCount, 1)
        self.onComplete = onComplete

        let initialPage = min(max(initialPageIndex + 1, 1), max(pageCount, 1))
        _startPage = State(initialValue: initialPage)
        _endPage = State(initialValue: initialPage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.downloadPageRange)
                        .font(.title3.weight(.semibold))
                    Text(rangeSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                SheetCloseButton(style: .plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                pageStepper(title: L10n.startPage, value: startPageBinding)
                pageStepper(title: L10n.endPage, value: endPageBinding)
            }

            HStack(spacing: 8) {
                Button(L10n.currentPageToEnd) {
                    startPage = min(max(initialPageIndex + 1, 1), pageCount)
                    endPage = pageCount
                }
                .controlSize(.small)

                Button(L10n.allPages) {
                    startPage = 1
                    endPage = pageCount
                }
                .controlSize(.small)
            }

            Divider()

            HStack {
                Spacer()
                Button(L10n.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    enqueueRange()
                } label: {
                    Label(L10n.addToDownloadQueue, systemImage: "arrow.down.circle")
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 360)
    }

    private func pageStepper(title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...pageCount) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted())
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var startPageBinding: Binding<Int> {
        Binding {
            startPage
        } set: { value in
            startPage = min(max(value, 1), pageCount)
            if endPage < startPage {
                endPage = startPage
            }
        }
    }

    private var endPageBinding: Binding<Int> {
        Binding {
            endPage
        } set: { value in
            endPage = min(max(value, 1), pageCount)
            if startPage > endPage {
                startPage = endPage
            }
        }
    }

    private var oneBasedRange: ClosedRange<Int> {
        min(startPage, endPage)...max(startPage, endPage)
    }

    private var zeroBasedRange: ClosedRange<Int> {
        (oneBasedRange.lowerBound - 1)...(oneBasedRange.upperBound - 1)
    }

    private var selectedPageCount: Int {
        oneBasedRange.upperBound - oneBasedRange.lowerBound + 1
    }

    private var rangeSummary: String {
        String(
            format: L10n.downloadPageRangeSummaryFormat,
            oneBasedRange.lowerBound,
            oneBasedRange.upperBound,
            selectedPageCount,
            pageCount
        )
    }

    private func enqueueRange() {
        let queuedCount = store.enqueueDownloadPages(
            artwork,
            pageRange: zeroBasedRange,
            preferOriginal: store.preferOriginalImages(for: artwork, pageCount: pageCount)
        )
        onComplete(queuedCount, oneBasedRange)
        dismiss()
    }
}
