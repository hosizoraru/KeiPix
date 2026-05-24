import AppKit
import SwiftUI

struct ArtworkReaderView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var pageIndex: Int
    @Binding var readingMode: ArtworkReadingMode
    @Binding var scrollTarget: Int?
    let scrollToPage: (Int) -> Void

    @State private var interaction = ArtworkReaderInteractionState()
    @State private var pageAspectRatios: [Int: CGFloat] = [:]

    var body: some View {
        Group {
            switch readingMode {
            case .singlePage:
                ArtworkSinglePageReader(
                    artwork: artwork,
                    store: store,
                    pageIndex: $pageIndex,
                    presentation: presentation(for: pageIndex),
                    interaction: interaction,
                    movePage: movePage,
                    handlePageSwipe: handlePageSwipe,
                    onImageLoaded: updatePageAspectRatio
                )
            case .continuous:
                ArtworkContinuousReader(
                    artwork: artwork,
                    store: store,
                    pageIndex: $pageIndex,
                    presentation: presentation(for:),
                    handlePageSwipe: handlePageSwipe,
                    onImageLoaded: updatePageAspectRatio
                )
                .padding(.horizontal, 18)
            case .index:
                ArtworkPageIndexGrid(
                    artwork: artwork,
                    store: store,
                    selectedPage: pageIndex,
                    selectPage: { index in
                        readingMode = .singlePage
                        scrollToPage(index)
                    },
                    handlePageSwipe: handlePageSwipe
                )
                .padding(.horizontal, 18)
            }
        }
        .overlay {
            HStack {
                Button(L10n.previousPage) { movePage(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .hidden()
                Button(L10n.nextPage) { movePage(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .hidden()
                Button(L10n.resetZoom) { interaction.resetZoom() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .hidden()
                Button(L10n.toggleZoom) { interaction.toggleSmartZoom(in: .zero) }
                    .keyboardShortcut(.space, modifiers: [])
                    .hidden()
            }
            .accessibilityHidden(true)
        }
        .onChange(of: scrollTarget) { _, value in
            guard readingMode == .continuous, let value, value != pageIndex else { return }
            pageIndex = min(max(value, 0), pageCount - 1)
        }
        .onChange(of: pageIndex) { _, value in
            interaction.activePageIndex = value
            interaction.resetZoom()
        }
        .onChange(of: artwork.id) { _, _ in
            pageAspectRatios.removeAll()
            interaction.resetZoom()
        }
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }

    private func movePage(_ delta: Int) {
        let target = pageIndex + delta
        if (0..<pageCount).contains(target) {
            scrollToPage(target)
        } else if store.horizontalSwipeBehavior == .pageThenArtworkAtEdges {
            store.selectAdjacentArtwork(delta: delta)
        }
    }

    private func handlePageSwipe(_ event: TrackpadScrollEvent) -> Bool {
        guard store.trackpadGesturesEnabled, event.isMomentum == false, interaction.isZoomed == false else {
            return false
        }
        let result = interaction.trackSwipe(
            deltaX: event.deltaX,
            deltaY: event.deltaY,
            isFinished: event.isFinished
        )
        if let pageDelta = result.pageDelta {
            movePage(pageDelta)
        }
        return result.handled
    }

    private func presentation(for index: Int) -> ReaderPagePresentation {
        ReaderPagePresentation(
            pageIndex: index,
            aspectRatio: pageAspectRatios[index],
            fallbackAspectRatio: artwork.aspectRatio
        )
    }

    private func updatePageAspectRatio(_ image: NSImage, pageIndex: Int) {
        guard let aspectRatio = ReaderPagePresentation.aspectRatio(from: image),
              pageAspectRatios[pageIndex] != aspectRatio else {
            return
        }
        pageAspectRatios[pageIndex] = aspectRatio
    }
}

struct ArtworkReaderControls: View {
    @Binding var pageIndex: Int
    @Binding var readingMode: ArtworkReadingMode
    let pageCount: Int
    let scrollToPage: (Int) -> Void

    @State private var pageText = "1"

    var body: some View {
        VStack(spacing: 10) {
            Picker(L10n.readingMode, selection: $readingMode) {
                ForEach(ArtworkReadingMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if pageCount > 1 {
                HStack(spacing: 10) {
                    Button {
                        scrollToPage(pageIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(pageIndex <= 0)
                    .accessibilityLabel(L10n.previousPage)

                    TextField(L10n.page, text: $pageText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 62)
                        .onSubmit(commitPageText)

                    Text("/ \(pageCount)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Slider(
                        value: Binding(
                            get: { Double(pageIndex + 1) },
                            set: { scrollToPage(Int($0.rounded()) - 1) }
                        ),
                        in: 1...Double(pageCount),
                        step: 1
                    )
                    .accessibilityLabel(L10n.jumpToPage)

                    Button {
                        scrollToPage(pageIndex + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(pageIndex >= pageCount - 1)
                    .accessibilityLabel(L10n.nextPage)
                }
            }
        }
        .padding(12)
        .keiPanel(16)
        .onAppear {
            syncPageText()
        }
        .onChange(of: pageIndex) { _, _ in
            syncPageText()
        }
        .onChange(of: pageCount) { _, _ in
            syncPageText()
        }
    }

    private func syncPageText() {
        pageText = "\(min(max(pageIndex, 0), max(pageCount - 1, 0)) + 1)"
    }

    private func commitPageText() {
        let target = (Int(pageText) ?? pageIndex + 1) - 1
        scrollToPage(target)
        syncPageText()
    }
}

private struct ArtworkSinglePageReader: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var pageIndex: Int
    let presentation: ReaderPagePresentation
    let interaction: ArtworkReaderInteractionState
    let movePage: (Int) -> Void
    let handlePageSwipe: (TrackpadScrollEvent) -> Bool
    let onImageLoaded: (NSImage, Int) -> Void

    var body: some View {
        let currentPageIndex = pageIndex

        GeometryReader { proxy in
            ZStack {
                RemoteImageView(
                    url: artwork.imageURL(at: currentPageIndex, preferOriginal: store.useOriginalImagesInDetail),
                    localURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: currentPageIndex),
                    contentMode: .fit,
                    onImageLoaded: { image in
                        onImageLoaded(image, currentPageIndex)
                    }
                )
                    .scaleEffect(interaction.scale)
                    .offset(interaction.offset)

                TrackpadEventBridge(
                    isEnabled: store.trackpadGesturesEnabled,
                    onScroll: { event in
                        handleScroll(event, in: proxy.size)
                    },
                    onMagnify: { delta, phase in
                        handleMagnify(delta, phase: phase, in: proxy.size)
                    },
                    onSmartMagnify: {
                        interaction.toggleSmartZoom(in: proxy.size)
                        return true
                    },
                    onDrag: { delta in
                        guard interaction.isZoomed else { return false }
                        interaction.applyPan(deltaX: -delta.width, deltaY: -delta.height, in: proxy.size)
                        return true
                    }
                )

                if pageCount > 1 {
                    HStack {
                        PageNavigationButton(systemImage: "chevron.left", title: L10n.previousPage) {
                            movePage(-1)
                        }
                        .disabled(pageIndex <= 0)

                        Spacer()

                        PageNavigationButton(systemImage: "chevron.right", title: L10n.nextPage) {
                            movePage(1)
                        }
                        .disabled(pageIndex >= pageCount - 1)
                    }
                    .padding(.horizontal, 12)
                }

                VStack {
                    HStack {
                        if interaction.isZoomed {
                            Button {
                                interaction.resetZoom()
                            } label: {
                                Label(L10n.resetZoom, systemImage: "arrow.down.right.and.arrow.up.left")
                            }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                            .keiInteractiveGlass(12)
                        }

                        Spacer()

                        if pageCount > 1 {
                            PageBadge(index: pageIndex, count: pageCount)
                        }
                    }
                    Spacer()
                }
                .padding(14)
            }
            .clipped()
            .contentShape(Rectangle())
        }
        .aspectRatio(presentation.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
        .frame(maxHeight: presentation.singlePageMaxHeight())
        .background(.quaternary)
        .backgroundExtensionEffect()
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }

    private func handleScroll(_ event: TrackpadScrollEvent, in size: CGSize) -> Bool {
        guard store.trackpadGesturesEnabled else { return false }
        if interaction.isZoomed {
            interaction.applyPan(deltaX: event.deltaX, deltaY: event.deltaY, in: size)
            return true
        }
        return handlePageSwipe(event)
    }

    private func handleMagnify(_ delta: CGFloat, phase: NSEvent.Phase, in size: CGSize) -> Bool {
        guard store.trackpadGesturesEnabled else { return false }
        interaction.applyMagnification(delta, in: size)
        if phase.contains(.ended) || phase.contains(.cancelled) {
            interaction.finishMagnification()
        }
        return true
    }
}

private struct ArtworkContinuousReader: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var pageIndex: Int
    let presentation: (Int) -> ReaderPagePresentation
    let handlePageSwipe: (TrackpadScrollEvent) -> Bool
    let onImageLoaded: (NSImage, Int) -> Void

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<pageCount, id: \.self) { index in
                let pagePresentation = presentation(index)

                VStack(spacing: 8) {
                    RemoteImageView(
                        url: artwork.imageURL(at: index, preferOriginal: store.useOriginalImagesInDetail),
                        localURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: index),
                        contentMode: .fit,
                        onImageLoaded: { image in
                            onImageLoaded(image, index)
                        }
                    )
                        .aspectRatio(pagePresentation.aspectRatio, contentMode: .fit)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            pagePresentation.continuousWidth(in: length)
                        }
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            TrackpadEventBridge(
                                isEnabled: store.trackpadGesturesEnabled,
                                onScroll: handlePageSwipe,
                                onMagnify: { _, _ in false },
                                onSmartMagnify: { false },
                                onDrag: { _ in false }
                            )
                        }
                        .overlay(alignment: .topTrailing) {
                            PageBadge(index: index, count: pageCount)
                                .padding(10)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                    Divider()
                        .opacity(index == pageCount - 1 ? 0 : 0.55)
                }
                .id(index)
                .scrollTargetLayout()
                .onTapGesture {
                    pageIndex = index
                }
            }
        }
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }
}

private struct ArtworkPageIndexGrid: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let selectedPage: Int
    let selectPage: (Int) -> Void
    let handlePageSwipe: (TrackpadScrollEvent) -> Bool

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 92), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<pageCount, id: \.self) { index in
                Button {
                    selectPage(index)
                } label: {
                    PageThumbnail(
                        url: artwork.thumbnailURL(at: index),
                        localURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: index),
                        index: index,
                        isSelected: index == selectedPage
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.pageStatus(index + 1, pageCount))
                .id(index)
            }
        }
        .background {
            TrackpadEventBridge(
                isEnabled: true,
                onScroll: handlePageSwipe,
                onMagnify: { _, _ in false },
                onSmartMagnify: { false },
                onDrag: { _ in false }
            )
        }
        .scrollTargetLayout()
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }
}

private struct PageThumbnail: View {
    let url: URL?
    let localURL: URL?
    let index: Int
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RemoteImageView(url: url, localURL: localURL)
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .padding(4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        }
    }
}

private struct PageBadge: View {
    let index: Int
    let count: Int

    var body: some View {
        Text("\(index + 1) / \(count)")
            .font(.caption.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .keiGlass(12)
    }
}

private struct PageNavigationButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 34, height: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .keiInteractiveGlass(18)
    }
}
