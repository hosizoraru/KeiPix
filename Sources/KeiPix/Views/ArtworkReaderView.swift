import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ArtworkReaderView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var pageIndex: Int
    @Binding var readingMode: ArtworkReadingMode
    var showsImageTransformMenu = true
    @Binding var scrollTarget: Int?
    let scrollToPage: (Int) -> Void

    @State private var interaction = ArtworkReaderInteractionState()
    @State private var imageTransform = ReaderImageTransform()
    @State private var pageAspectRatios: [Int: CGFloat] = [:]
    @State private var readerAvailableSize: CGSize = .zero

    var body: some View {
        readerLayout
        .overlay(alignment: .topTrailing) {
            if showsReaderImageTransformMenu {
                readerImageTransformMenu
                    .padding(.top, 12)
                    .padding(.trailing, 12)
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
        .overlay {
            HStack {
                Button(L10n.previousPage) { movePage(-1) }
                    .shortcut(.readerPreviousPage)
                    .hidden()
                Button(L10n.nextPage) { movePage(1) }
                    .shortcut(.readerNextPage)
                    .hidden()
                Button(L10n.resetZoom) { interaction.resetZoom() }
                    .shortcut(.readerResetZoom)
                    .hidden()
                Button(L10n.toggleZoom) { interaction.toggleSmartZoom(in: .zero) }
                    .shortcut(.readerToggleZoom)
                    .hidden()
            }
            .accessibilityHidden(true)
        }
        .onChange(of: scrollTarget) { _, value in
            guard effectiveReadingMode == .continuous, let value, value != pageIndex else { return }
            pageIndex = min(max(value, 0), pageCount - 1)
        }
        .onChange(of: pageIndex) { _, value in
            interaction.activePageIndex = value
            interaction.resetZoom()
        }
        .animation(.snappy(duration: 0.2), value: pageIndex)
        .onChange(of: artwork.id) { _, _ in
            pageAspectRatios.removeAll()
            interaction.resetZoom()
            imageTransform = .identity
        }
    }

    @ViewBuilder
    private var readerLayout: some View {
        if filmstripPresentation.isVisible, effectiveReadingMode != .index {
            HStack(spacing: 12) {
                readerFilmstripRail
                    .frame(width: filmstripPresentation.railWidth)

                readerContent
            }
            .padding(.leading, 8)
        } else {
            readerContent
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        switch effectiveReadingMode {
        case .singlePage:
            ArtworkSinglePageReader(
                artwork: artwork,
                store: store,
                pageIndex: $pageIndex,
                presentation: presentation(for: pageIndex),
                imageTransform: imageTransform,
                interaction: interaction,
                movePage: movePage,
                handlePageSwipe: handlePageSwipe,
                onImageLoaded: updatePageAspectRatio
            )
        case .doublePage:
            ArtworkDoublePageReader(
                artwork: artwork,
                store: store,
                pageIndex: $pageIndex,
                presentationLeft: presentation(for: pageIndex),
                presentationRight: presentation(for: pageIndex + 1),
                imageTransform: imageTransform,
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
                imageTransform: imageTransform,
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

    private var readerFilmstripRail: some View {
        NativeReaderFilmstripCollectionView(
            items: ReaderFilmstripPresentation.pageItems(
                artworkID: artwork.id,
                pageCount: pageCount,
                remoteURL: { artwork.thumbnailURL(at: $0) },
                localURL: { store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: $0) }
            ),
            selectedPageIndex: pageIndex,
            presentation: filmstripPresentation,
            selectPage: { index in
                scrollToPage(index)
            },
            content: { item, isSelected in
                AnyView(
                    PageThumbnail(
                        url: item.remoteURL,
                        localURL: item.localURL,
                        index: item.pageIndex,
                        isSelected: isSelected
                    )
                    .frame(
                        width: filmstripPresentation.itemSize.width,
                        height: filmstripPresentation.itemSize.height
                    )
                    .accessibilityLabel(L10n.pageStatus(item.pageIndex + 1, pageCount))
                )
            }
        )
        .readerControlChrome()
        .accessibilityLabel(L10n.jumpToPage)
    }

    private var readerImageTransformMenu: some View {
        ReaderImageTransformMenu(transform: $imageTransform)
            .labelStyle(.iconOnly)
            .menuStyle(.button)
            .os26GlassButton(prominent: imageTransform.isIdentity == false)
            .controlSize(.small)
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }

    private var showsReaderImageTransformMenu: Bool {
        showsImageTransformMenu && effectiveReadingMode != .index
    }

    private var filmstripPresentation: ReaderFilmstripPresentation {
        ReaderFilmstripPresentation.resolve(
            pageCount: pageCount,
            availableSize: readerAvailableSize,
            platform: .current
        )
    }

    private var effectiveReadingMode: ArtworkReadingMode {
        guard readerAvailableSize.width > 0, readerAvailableSize.height > 0 else {
            return readingMode.effectiveMode(forPageCount: pageCount, platform: .current)
        }
        return ReaderAdaptiveLayout.effectiveArtworkMode(
            preferredMode: readingMode,
            pageCount: pageCount,
            availableSize: readerAvailableSize,
            platform: .current
        )
    }

    private func updateReaderAvailableSize(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite, size.width >= 0, size.height >= 0 else {
            return
        }
        guard readerAvailableSize != size else { return }
        readerAvailableSize = size
    }

    private func movePage(_ delta: Int) {
        // In double-page mode, advance by 2 pages
        let effectiveDelta = effectiveReadingMode == .doublePage ? delta * 2 : delta
        let target = pageIndex + effectiveDelta
        if (0..<pageCount).contains(target) {
            scrollToPage(target)
        } else if store.horizontalSwipeBehavior == .pageThenArtworkAtEdges {
            store.selectAdjacentArtwork(delta: delta)
        }
    }

    private func handlePageSwipe(_ event: ReaderScrollEvent) -> Bool {
        guard store.trackpadGesturesEnabled, event.isMomentum == false, interaction.isZoomed == false else {
            return false
        }
        let result = interaction.trackSwipe(
            deltaX: event.deltaX,
            deltaY: event.deltaY,
            velocityX: event.velocityX,
            velocityY: event.velocityY,
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

    private func updatePageAspectRatio(_ image: PlatformImage, pageIndex: Int) {
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
        GlassEffectContainer(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    if pageCount > 1 {
                        readingModeMenu
                    }

                    if pageCount > 1 {
                        pageNavigationControls
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 9) {
                    HStack(spacing: 10) {
                        if pageCount > 1 {
                            readingModeMenu
                        }

                        if pageCount > 1 {
                            compactPageNavigationControls
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    if pageCount > 1 {
                        pageSlider
                            .frame(maxWidth: 220)
                    }
                }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .readerControlChrome()
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

    private var effectiveReadingMode: ArtworkReadingMode {
        readingMode.effectiveMode(forPageCount: pageCount, platform: .current)
    }

    private var navigationPageStep: Int {
        effectiveReadingMode == .doublePage ? 2 : 1
    }

    private var readingModeMenu: some View {
        Menu {
            Section(L10n.readingMode) {
                readingModeMenuItems
            }
        } label: {
            Label(effectiveReadingMode.title, systemImage: effectiveReadingMode.systemImage)
                .lineLimit(1)
        }
        .menuStyle(.button)
        .os26GlassButton()
        .accessibilityLabel(L10n.readingMode)
        .accessibilityValue(effectiveReadingMode.title)
    }

    @ViewBuilder
    private var readingModeMenuItems: some View {
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

    private var availableReadingModes: [ArtworkReadingMode] {
        if ReaderPlatformKind.current == .phone {
            return ArtworkReadingMode.allCases.filter { $0 != .doublePage }
        }
        return ArtworkReadingMode.allCases
    }

    private var pageNavigationControls: some View {
        HStack(spacing: 8) {
            pageStepper
            pageIndicator
            pageSlider
                .frame(minWidth: 96, idealWidth: 136, maxWidth: 180)
        }
        .frame(maxWidth: 360)
    }

    private var compactPageNavigationControls: some View {
        HStack(spacing: 8) {
            pageStepper
            pageIndicator
        }
    }

    private var pageStepper: some View {
        ControlGroup {
            Button {
                scrollToPage(pageIndex - navigationPageStep)
            } label: {
                Label(L10n.previousPage, systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .disabled(pageIndex <= 0)
            .accessibilityLabel(L10n.previousPage)

            Button {
                scrollToPage(pageIndex + navigationPageStep)
            } label: {
                Label(L10n.nextPage, systemImage: "chevron.right")
            }
            .labelStyle(.iconOnly)
            .disabled(pageIndex + navigationPageStep >= pageCount)
            .accessibilityLabel(L10n.nextPage)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 3) {
            TextField(L10n.page, text: $pageText)
                .textFieldStyle(.plain)
                .font(.caption.weight(.semibold).monospacedDigit())
                .multilineTextAlignment(.center)
                .frame(width: 38)
                .onSubmit(commitPageText)

            Text(L10n.pageTotal(pageCount))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.page)
        .accessibilityValue(L10n.pageOfTotal(pageIndex + 1, pageCount))
    }

    private var pageSlider: some View {
        Slider(
            value: Binding(
                get: { Double(pageIndex + 1) },
                set: { scrollToPage(Int($0.rounded()) - 1) }
            ),
            in: 1...Double(pageCount),
            step: 1
        )
        .accessibilityLabel(L10n.jumpToPage)
        .accessibilityValue(L10n.pageOfTotal(pageIndex + 1, pageCount))
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
    let imageTransform: ReaderImageTransform
    let interaction: ArtworkReaderInteractionState
    let movePage: (Int) -> Void
    let handlePageSwipe: (ReaderScrollEvent) -> Bool
    let onImageLoaded: (PlatformImage, Int) -> Void

    var body: some View {
        let currentPageIndex = pageIndex

        SinglePageReaderViewportLayout(presentation: presentation) {
            ZStack {
                ImageScrollView(
                    imageURL: artwork.imageURL(at: currentPageIndex, preferOriginal: store.preferOriginalImages(for: artwork)),
                    localURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: currentPageIndex),
                    resetZoomTrigger: interaction.resetZoomTrigger,
                    toggleZoomTrigger: interaction.toggleZoomTrigger,
                    onImageLoaded: { image in
                        onImageLoaded(image, currentPageIndex)
                    },
                    onZoomChanged: { zoomScale in
                        interaction.updateNativeZoomScale(zoomScale)
                    },
                    onPageSwipe: { event in
                        handlePageSwipe(event)
                    }
                )
                .readerImageTransform(imageTransform)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    .zIndex(3)
                }

                VStack {
                    HStack {
                        if interaction.isZoomed {
                            Button {
                                interaction.resetZoom()
                            } label: {
                                Label(L10n.resetZoom, systemImage: "arrow.down.right.and.arrow.up.left")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .controlSize(.small)
                            .accessibilityLabel(L10n.resetZoom)
                            .help(L10n.resetZoom)
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
        .frame(maxWidth: .infinity)
        .readerCanvasChrome()
        .padding(.horizontal, 16)
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }
}

private struct ArtworkContinuousReader: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var pageIndex: Int
    let presentation: (Int) -> ReaderPagePresentation
    let imageTransform: ReaderImageTransform
    let handlePageSwipe: (ReaderScrollEvent) -> Bool
    let onImageLoaded: (PlatformImage, Int) -> Void

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<pageCount, id: \.self) { index in
                let pagePresentation = presentation(index)

                VStack(spacing: 8) {
                    RemoteImageView(
                        url: artwork.imageURL(at: index, preferOriginal: store.preferOriginalImages(for: artwork)),
                        localURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: index),
                        contentMode: .fit,
                        onImageLoaded: { image in
                            onImageLoaded(image, index)
                        }
                    )
                        .readerImageTransform(imageTransform)
                        .aspectRatio(pagePresentation.aspectRatio, contentMode: .fit)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            pagePresentation.continuousWidth(in: length)
                        }
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            Color.clear
                                .readerGestures(
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

// MARK: - Double-page reader

/// Shows two pages side by side like an open book. The left page is
/// the current page, the right page is the next page. Pages advance
/// by 2 when navigating forward/backward.
private struct ArtworkDoublePageReader: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var pageIndex: Int
    let presentationLeft: ReaderPagePresentation
    let presentationRight: ReaderPagePresentation
    let imageTransform: ReaderImageTransform
    let interaction: ArtworkReaderInteractionState
    let movePage: (Int) -> Void
    let handlePageSwipe: (ReaderScrollEvent) -> Bool
    let onImageLoaded: (PlatformImage, Int) -> Void

    var body: some View {
        DoublePageReaderViewportLayout(
            leftPresentation: presentationLeft,
            rightPresentation: pageIndex + 1 < pageCount ? presentationRight : nil
        ) {
            HStack(spacing: 0) {
                // Left page
                pageView(index: pageIndex)
                    .overlay(alignment: .topLeading) {
                        PageBadge(index: pageIndex, count: pageCount)
                            .padding(10)
                    }

                // Spine
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 1)

                // Right page
                if pageIndex + 1 < pageCount {
                    pageView(index: pageIndex + 1)
                        .overlay(alignment: .topTrailing) {
                            PageBadge(index: pageIndex + 1, count: pageCount)
                                .padding(10)
                        }
                } else {
                    // End of book
                    ZStack {
                        Color.clear
                        Image(systemName: "book.closed")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .readerCanvasChrome()
        .padding(.horizontal, 16)
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }

    @ViewBuilder
    private func pageView(index: Int) -> some View {
        ImageScrollView(
            imageURL: artwork.imageURL(at: index, preferOriginal: store.preferOriginalImages(for: artwork)),
            localURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: index),
            resetZoomTrigger: interaction.resetZoomTrigger,
            toggleZoomTrigger: interaction.toggleZoomTrigger,
            onImageLoaded: { image in
                onImageLoaded(image, index)
            },
            onZoomChanged: { zoomScale in
                interaction.updateNativeZoomScale(zoomScale)
            },
            onPageSwipe: { event in
                handlePageSwipe(event)
            }
        )
        .readerImageTransform(imageTransform)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ArtworkPageIndexGrid: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let selectedPage: Int
    let selectPage: (Int) -> Void
    let handlePageSwipe: (ReaderScrollEvent) -> Bool

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
            Color.clear
                .readerGestures(
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
                .glassEffect(.regular, in: Capsule(style: .continuous))
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
        Text(L10n.pageOfTotal(index + 1, count))
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
                .frame(width: 44, height: 56)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(title)
        .keiInteractiveGlass(18)
        .zIndex(4)
    }
}

private extension View {
    func readerImageTransform(_ transform: ReaderImageTransform) -> some View {
        self
            .rotationEffect(.degrees(transform.rotationDegrees))
            .scaleEffect(
                x: transform.isFlippedHorizontally ? -1 : 1,
                y: transform.isFlippedVertically ? -1 : 1
            )
    }

    func readerCanvasChrome(cornerRadius: CGFloat = 26) -> some View {
        self
            .keiPanel(cornerRadius, clipsContent: true)
    }

    func readerControlChrome() -> some View {
        self
            .keiGlass(20)
    }
}
