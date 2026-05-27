import SwiftUI
#if os(macOS)
import AppKit
#endif

struct DownloadedArtworkViewer: View {
    let item: ArtworkDownloadItem
    let imageURLs: [URL]
    @Bindable var store: KeiPixStore

    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var isContinuous = true
    @State private var actionMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            HStack(spacing: 0) {
                if imageURLs.count > 1 {
                    thumbnailRail
                        .frame(width: 112)
                        .background(.regularMaterial)
                }

                Divider()

                if isContinuous {
                    continuousReader
                } else {
                    singlePageReader
                }
            }
        }
        .frame(minWidth: 900, minHeight: 680)
        .overlay(alignment: .bottom) {
            if let actionMessage {
                FloatingStatusBanner {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .task(id: item.id) {
            pageIndex = store.restoredDownloadedReaderPageIndex(for: item, pageCount: imageURLs.count)
        }
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
        .onChange(of: pageIndex) { _, value in
            store.saveDownloadedReaderPageIndex(value, for: item, pageCount: imageURLs.count)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    previousPage()
                } label: {
                    Label(L10n.previousPage, systemImage: "chevron.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(pageIndex == 0)

                Button {
                    nextPage()
                } label: {
                    Label(L10n.nextPage, systemImage: "chevron.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(pageIndex >= imageURLs.count - 1)

                Button {
                    isContinuous.toggle()
                } label: {
                    Label(L10n.toggleReadingMode, systemImage: "rectangle.split.1x2")
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(item.creatorName) · \(imageURLs.count)P")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker(L10n.readingMode, selection: $isContinuous) {
                Text(L10n.continuousReading).tag(true)
                Text(L10n.singlePage).tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            Button {
                revealCurrentPage()
            } label: {
                Label(L10n.revealCurrentPage, systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.revealCurrentPage)

            Menu {
                if let pixivURL = item.pixivURL {
                    Button {
                        PlatformWorkspace.open(pixivURL)
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button {
                        PasteboardWriter.copy(pixivURL.absoluteString)
                        actionMessage = L10n.copied
                    } label: {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                }

                Button {
                    revealCurrentPage()
                } label: {
                    Label(L10n.revealCurrentPage, systemImage: "folder")
                }

                Divider()

                Button {
                    exportAsPDF()
                } label: {
                    Label(L10n.exportAsPDF, systemImage: "doc.richtext")
                }
                .help(L10n.exportAsPDF)

                Button {
                    exportAsCollage()
                } label: {
                    Label(L10n.exportAsCollage, systemImage: "square.grid.3x3")
                }
                .help(L10n.exportAsCollage)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.moreActions)

            ShareLink(item: currentImageURL) {
                Label(L10n.shareCurrentPage, systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.shareCurrentPage)

            Button {
                dismiss()
            } label: {
                Label(L10n.close, systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var currentImageURL: URL {
        imageURLs[safe: pageIndex] ?? imageURLs[0]
    }

    private var thumbnailRail: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        Button {
                            pageIndex = index
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                LocalImageView(url: url, contentMode: .fill)
                                    .frame(width: 72, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text("\(index + 1)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .keiGlass(8)
                                    .padding(5)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(index == pageIndex ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: index == pageIndex ? 2 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: pageIndex) { _, value in
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private var continuousReader: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        LocalImageView(url: url, contentMode: .fit)
                            .frame(maxWidth: 860)
                            .id(index)
                            .onTapGesture {
                                pageIndex = index
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(18)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: pageIndex) { _, value in
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo(value, anchor: .top)
                }
            }
        }
    }

    private var singlePageReader: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            LocalImageView(url: currentImageURL, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(18)

            HStack(spacing: 12) {
                Button {
                    previousPage()
                } label: {
                    Label(L10n.previousPage, systemImage: "chevron.left")
                }
                .disabled(pageIndex == 0)

                Text(L10n.pageStatus(pageIndex + 1, imageURLs.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 120)

                Button {
                    nextPage()
                } label: {
                    Label(L10n.nextPage, systemImage: "chevron.right")
                }
                .disabled(pageIndex >= imageURLs.count - 1)
            }
            .padding(.bottom, 16)
        }
    }

    private func previousPage() {
        pageIndex = max(pageIndex - 1, 0)
    }

    private func nextPage() {
        pageIndex = min(pageIndex + 1, imageURLs.count - 1)
    }

    private func revealCurrentPage() {
        PlatformWorkspace.revealInFiles(currentImageURL)
    }

    private func exportAsPDF() {
        guard let url = BatchExportService.exportPDF(from: imageURLs, title: item.title) else {
            actionMessage = L10n.exportFailed
            return
        }
        actionMessage = L10n.exportedTo(url.lastPathComponent)
        PlatformWorkspace.revealInFiles(url)
    }

    private func exportAsCollage() {
        guard let url = BatchExportService.exportCollage(from: imageURLs, title: item.title) else {
            actionMessage = L10n.exportFailed
            return
        }
        actionMessage = L10n.exportedTo(url.lastPathComponent)
        PlatformWorkspace.revealInFiles(url)
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private struct LocalImageView: View {
    let url: URL
    let contentMode: ContentMode

    var body: some View {
        if let image = PlatformImage(contentsOf: url) {
            image.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            ContentUnavailableView(L10n.failed, systemImage: "photo.badge.exclamationmark")
                .frame(maxWidth: .infinity, minHeight: 180)
        }
    }
}
