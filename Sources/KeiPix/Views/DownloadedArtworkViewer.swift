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
    @State private var readingMode: ArtworkReadingMode = .continuous
    @State private var readerAvailableSize: CGSize = .zero
    @State private var actionMessage: String?
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .platformGlassControlBar(verticalPadding: 8, topPadding: 8, bottomPadding: 6)

            HStack(spacing: 0) {
                if imageURLs.count > 1 {
                    thumbnailRail
                        .frame(width: 112)
                        .keiPanel(18, clipsContent: true)
                        .padding(.leading, 12)
                        .padding(.vertical, 12)
                }

                Divider()

                readerContent
            }
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 680)
        #endif
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
                .labelStyle(.iconOnly)
                .help(L10n.previousPage)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(pageIndex == 0)

                Button {
                    nextPage()
                } label: {
                    Label(L10n.nextPage, systemImage: "chevron.right")
                }
                .labelStyle(.iconOnly)
                .help(L10n.nextPage)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(pageIndex + navigationPageStep >= imageURLs.count)

                Button {
                    cycleReadingMode()
                } label: {
                    Label(L10n.toggleReadingMode, systemImage: "rectangle.split.1x2")
                }
                .labelStyle(.iconOnly)
                .help(L10n.toggleReadingMode)
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
                Text(L10n.creatorPageHeader(item.creatorName, imageURLs.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Section(L10n.readingMode) {
                    ForEach(availableReadingModes) { mode in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                readingMode = mode
                            }
                        } label: {
                            Label(mode.title, systemImage: mode == effectiveReadingMode ? "checkmark.circle.fill" : mode.systemImage)
                        }
                    }
                }
            } label: {
                Label(effectiveReadingMode.title, systemImage: effectiveReadingMode.systemImage)
            }
            .menuStyle(.button)
            .os26GlassButton()
            .help(L10n.readingMode)

            #if os(macOS)
            Button {
                revealCurrentPage()
            } label: {
                Label(L10n.revealCurrentPage, systemImage: "folder")
            }
            .os26GlassIconButton()
            .help(L10n.revealCurrentPage)
            #endif

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

                #if os(macOS)
                Button {
                    revealCurrentPage()
                } label: {
                    Label(L10n.revealCurrentPage, systemImage: "folder")
                }

                Divider()
                #endif

                Button {
                    Task { await exportAsPDF() }
                } label: {
                    Label(L10n.exportAsPDF, systemImage: "doc.richtext")
                }
                .help(L10n.exportAsPDF)
                .disabled(isExporting)

                Button {
                    Task { await exportAsCollage() }
                } label: {
                    Label(L10n.exportAsCollage, systemImage: "square.grid.3x3")
                }
                .help(L10n.exportAsCollage)
                .disabled(isExporting)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .os26GlassIconButton()
            .help(L10n.moreActions)

            ShareLink(item: currentImageURL) {
                Label(L10n.shareCurrentPage, systemImage: "square.and.arrow.up")
            }
            .os26GlassIconButton()
            .help(L10n.shareCurrentPage)

            Button {
                dismiss()
            } label: {
                Label(L10n.close, systemImage: "xmark")
            }
            .os26GlassIconButton()
            .keyboardShortcut(.cancelAction)
        }
    }

    private var currentImageURL: URL {
        imageURLs[safe: pageIndex] ?? imageURLs[0]
    }

    private var nextImageURL: URL? {
        imageURLs[safe: pageIndex + 1]
    }

    private var effectiveReadingMode: ArtworkReadingMode {
        guard readerAvailableSize.width > 0, readerAvailableSize.height > 0 else {
            return readingMode.effectiveMode(forPageCount: imageURLs.count, platform: .current)
        }
        return ReaderAdaptiveLayout.effectiveArtworkMode(
            preferredMode: readingMode,
            pageCount: imageURLs.count,
            availableSize: readerAvailableSize,
            platform: .current
        )
    }

    private var navigationPageStep: Int {
        effectiveReadingMode == .doublePage ? 2 : 1
    }

    private var availableReadingModes: [ArtworkReadingMode] {
        var modes: [ArtworkReadingMode] = [.continuous, .singlePage]
        if imageURLs.count > 1, ReaderPlatformKind.current != .phone {
            modes.append(.doublePage)
        }
        return modes
    }

    @ViewBuilder
    private var readerContent: some View {
        Group {
            switch effectiveReadingMode {
            case .continuous:
                continuousReader
            case .doublePage:
                doublePageReader
            case .singlePage, .index:
                singlePageReader
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateReaderAvailableSize(proxy.size)
                    }
                    .onChange(of: proxy.size) { _, size in
                        updateReaderAvailableSize(size)
                    }
            }
        }
    }

    private func updateReaderAvailableSize(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite, size.width >= 0, size.height >= 0 else {
            return
        }
        guard readerAvailableSize != size else { return }
        readerAvailableSize = size
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

            ImageScrollView(imageURL: nil, localURL: currentImageURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(18)

            pageControls
                .padding(.bottom, 16)
        }
    }

    private var doublePageReader: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            HStack(spacing: 14) {
                ImageScrollView(imageURL: nil, localURL: currentImageURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let nextImageURL {
                    ImageScrollView(imageURL: nil, localURL: nextImageURL)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(18)

            pageControls
                .padding(.bottom, 16)
        }
    }

    private var pageControls: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    previousPage()
                } label: {
                    Label(L10n.previousPage, systemImage: "chevron.left")
                }
                .help(L10n.previousPage)
                .disabled(pageIndex == 0)
                .os26GlassIconButton()

                Text(L10n.pageStatus(pageIndex + 1, imageURLs.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 120)

                Button {
                    nextPage()
                } label: {
                    Label(L10n.nextPage, systemImage: "chevron.right")
                }
                .help(L10n.nextPage)
                .disabled(pageIndex + navigationPageStep >= imageURLs.count)
                .os26GlassIconButton()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .keiGlass(18)
        }
    }

    private func previousPage() {
        pageIndex = max(pageIndex - navigationPageStep, 0)
    }

    private func nextPage() {
        pageIndex = min(pageIndex + navigationPageStep, imageURLs.count - 1)
    }

    private func cycleReadingMode() {
        let modes = availableReadingModes
        guard let currentIndex = modes.firstIndex(of: readingMode) else {
            readingMode = modes.first ?? .singlePage
            return
        }
        readingMode = modes[(currentIndex + 1) % modes.count]
    }

    private func revealCurrentPage() {
        PlatformWorkspace.revealInFiles(currentImageURL)
    }

    private func exportAsPDF() async {
        guard isExporting == false else { return }
        isExporting = true
        defer { isExporting = false }
        let urls = imageURLs
        let title = item.title
        let outputURL = await Task.detached(priority: .userInitiated) {
            BatchExportService.exportPDF(from: urls, title: title)
        }.value

        guard let url = outputURL else {
            actionMessage = L10n.exportFailed
            return
        }
        actionMessage = L10n.exportedTo(url.lastPathComponent)
        PlatformWorkspace.revealInFiles(url)
    }

    private func exportAsCollage() async {
        guard isExporting == false else { return }
        isExporting = true
        defer { isExporting = false }
        let urls = imageURLs
        let title = item.title
        let outputURL = await Task.detached(priority: .userInitiated) {
            BatchExportService.exportCollage(from: urls, title: title)
        }.value

        guard let url = outputURL else {
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
        RemoteImageView(url: nil, localURL: url, contentMode: contentMode)
    }
}
