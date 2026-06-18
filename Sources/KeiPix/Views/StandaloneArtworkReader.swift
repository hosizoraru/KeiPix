#if os(macOS)
import AppKit
#endif
import SwiftUI

/// The actual reader chrome — header, focus overlay, page jump
/// affordance, prefetch, and progress persistence. Lives separately
/// from `ArtworkReaderWindowView` so that wrapper file stays focused
/// on the resolve-by-ID concern (the multi-window scene's value-typed
/// `WindowGroup(for: Int.self)` hands us only the artwork id).
struct StandaloneArtworkReader: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var pageIndex = 0
    @State private var readingMode: ArtworkReadingMode
    @State private var scrollTarget: Int?
    @State private var isFocusPresetEnabled = false
    @State private var isPageJumpPresented = false
    @AppStorage("reader.snapToPageBoundaries") private var snapToPageBoundaries = false

    init(artwork: PixivArtwork, store: KeiPixStore) {
        self.artwork = artwork
        self.store = store
        _readingMode = State(initialValue: store.defaultReadingMode(for: artwork))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    if isFocusPresetEnabled == false {
                        header(proxy: proxy)
                            .platformGlassControlBar(verticalPadding: 8, topPadding: 8, bottomPadding: 6)
                    }

                    ScrollView {
                        VStack(spacing: isFocusPresetEnabled ? 8 : 14) {
                            if pageCount > 1, isFocusPresetEnabled == false {
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
                        .padding(.bottom, isFocusPresetEnabled ? 6 : 18)
                    }
                    .scrollPosition(id: $scrollTarget, anchor: .top)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .modifier(
                        ConditionalScrollSnapping(
                            isEnabled: snapToPageBoundaries && effectiveReadingMode == .continuous
                        )
                    )
                }

                if isFocusPresetEnabled {
                    focusOverlay(proxy: proxy)
                }

                if isPageJumpPresented {
                    ReaderPageJumpOverlay(
                        pageIndex: $pageIndex,
                        pageCount: pageCount,
                        scrollToPage: { index in
                            scrollToPage(index, proxy: proxy)
                        },
                        dismiss: {
                            isPageJumpPresented = false
                        }
                    )
                    .padding(24)
                }
            }
            .onChange(of: scrollTarget) { _, value in
                guard effectiveReadingMode == .continuous, let value, value != pageIndex else { return }
                pageIndex = min(max(value, 0), pageCount - 1)
            }
            .onChange(of: readingMode) { _, mode in
                store.setDefaultReadingMode(mode, for: artwork, pageCount: pageCount)
                guard mode.effectiveMode(forPageCount: pageCount) != .singlePage else { return }
                scrollToPage(pageIndex, proxy: proxy)
            }
            .task(id: artwork.id) {
                resetForArtwork()
                prefetchAround(pageIndex)
                await store.recordBrowsingHistory(for: artwork)
            }
            .onChange(of: pageIndex) { _, value in
                store.saveReaderPageIndex(value, for: artwork, pageCount: pageCount)
                prefetchAround(value)
            }
        }
    }

    private var pageCount: Int {
        artwork.displayPageCount
    }

    private var effectiveReadingMode: ArtworkReadingMode {
        readingMode.effectiveMode(forPageCount: pageCount, platform: .current)
    }

    @ViewBuilder
    private func header(proxy: ScrollViewProxy) -> some View {
        if ReaderPlatformKind.current == .phone {
            compactHeader(proxy: proxy)
        } else {
            regularHeader(proxy: proxy)
        }
    }

    private func regularHeader(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            readerTitleBlock
                .layoutPriority(1)

            Spacer(minLength: 12)

            readerActionRail(proxy: proxy)
        }
    }

    private func compactHeader(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            readerTitleBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal) {
                readerActionRail(proxy: proxy)
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var readerTitleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(artwork.title)
                .font(.headline)
                .lineLimit(1)
            Text(L10n.creatorPageHeader(artwork.user.name, pageCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func readerActionRail(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            qualityButton

            if effectiveReadingMode == .continuous {
                snapToPagesButton
            }

            pageJumpButton
            focusButton
            previousPageButton(proxy: proxy)
            pageStatusText
            nextPageButton(proxy: proxy)
        }
    }

    // Inline quality toggle — flips the per-content quality preset without
    // sending users into Settings while preserving separate illust/manga defaults.
    private var qualityButton: some View {
        Button {
            store.setPreferOriginalImages(
                !store.preferOriginalImages(for: artwork, pageCount: pageCount),
                for: artwork,
                pageCount: pageCount
            )
        } label: {
            let isOriginal = store.preferOriginalImages(for: artwork, pageCount: pageCount)
            Label(
                isOriginal ? L10n.imageQualityOriginal : L10n.imageQualityStandard,
                systemImage: isOriginal ? "photo.badge.checkmark.fill" : "photo"
            )
        }
        .labelStyle(.iconOnly)
        .help(L10n.imageQualityToggleHint)
    }

    private var snapToPagesButton: some View {
        Button {
            snapToPageBoundaries.toggle()
        } label: {
            Label(
                L10n.snapToPages,
                systemImage: snapToPageBoundaries ? "arrow.down.to.line" : "arrow.down.to.line.compact"
            )
        }
        .labelStyle(.iconOnly)
        .help(L10n.snapToPages)
    }

    private var pageJumpButton: some View {
        Button {
            isPageJumpPresented = true
        } label: {
            Label(L10n.pageJump, systemImage: "number")
        }
        .labelStyle(.iconOnly)
        .help(L10n.pageJump)
        .disabled(pageCount <= 1)
        .shortcut(.readerJumpToPage)
    }

    private var focusButton: some View {
        Button {
            enterFocusPreset()
        } label: {
            Label(L10n.fullScreenReading, systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .labelStyle(.iconOnly)
        .help(L10n.fullScreenReading)
        .shortcut(.readerToggleFullscreen)
    }

    private func previousPageButton(proxy: ScrollViewProxy) -> some View {
        Button {
            scrollToPage(pageIndex - 1, proxy: proxy)
        } label: {
            Label(L10n.previousPage, systemImage: "chevron.left")
        }
        .labelStyle(.iconOnly)
        .help(L10n.previousPage)
        .disabled(pageIndex <= 0)
    }

    private var pageStatusText: some View {
        Text(L10n.pageStatus(pageIndex + 1, pageCount))
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(minWidth: 96)
    }

    private func nextPageButton(proxy: ScrollViewProxy) -> some View {
        Button {
            scrollToPage(pageIndex + 1, proxy: proxy)
        } label: {
            Label(L10n.nextPage, systemImage: "chevron.right")
        }
        .labelStyle(.iconOnly)
        .help(L10n.nextPage)
        .disabled(pageIndex >= pageCount - 1)
    }

    private func focusOverlay(proxy: ScrollViewProxy) -> some View {
        VStack {
            HStack(spacing: 10) {
                Text(artwork.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(L10n.pageStatus(pageIndex + 1, pageCount))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    scrollToPage(pageIndex - 1, proxy: proxy)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .os26GlassIconButton()
                .disabled(pageIndex <= 0)
                .accessibilityLabel(L10n.previousPage)

                Button {
                    isPageJumpPresented = true
                } label: {
                    Image(systemName: "number")
                }
                .os26GlassIconButton()
                .disabled(pageCount <= 1)
                .accessibilityLabel(L10n.pageJump)

                Button {
                    scrollToPage(pageIndex + 1, proxy: proxy)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .os26GlassIconButton()
                .disabled(pageIndex >= pageCount - 1)
                .accessibilityLabel(L10n.nextPage)

                Button {
                    exitFocusPreset()
                } label: {
                    Label(L10n.exitFocusReading, systemImage: "xmark")
                }
                .os26GlassIconButton()
                .help(L10n.exitFocusReading)
            }
            .controlSize(.small)
            .padding(12)
            .keiPanel(18)
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func resetForArtwork() {
        readingMode = store.defaultReadingMode(for: artwork, pageCount: pageCount)
        let restoredPageIndex = store.restoredReaderPageIndex(for: artwork, pageCount: pageCount)
        pageIndex = restoredPageIndex
        scrollTarget = effectiveReadingMode == .singlePage ? nil : restoredPageIndex
    }

    private func scrollToPage(_ index: Int, proxy: ScrollViewProxy) {
        let clamped = min(max(index, 0), pageCount - 1)
        pageIndex = clamped
        guard effectiveReadingMode != .singlePage else { return }
        withAnimation(.snappy(duration: 0.22)) {
            proxy.scrollTo(clamped, anchor: .top)
        }
    }

    private func enterFocusPreset() {
        withAnimation(.snappy(duration: 0.2)) {
            isFocusPresetEnabled = true
        }
        #if os(macOS)
        guard let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) == false else { return }
        window.toggleFullScreen(nil)
        #endif
    }

    private func exitFocusPreset() {
        withAnimation(.snappy(duration: 0.2)) {
            isFocusPresetEnabled = false
        }
        #if os(macOS)
        guard let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
        #endif
    }

    private func prefetchAround(_ index: Int) {
        let tier = store.imageQualityTier(for: artwork, pageCount: pageCount)
        let urls = artwork.prefetchURLs(around: index, tier: tier)
        Task {
            await ImagePipeline.shared.prefetch(urls)
        }
    }
}

private struct ReaderPageJumpOverlay: View {
    @Binding var pageIndex: Int
    let pageCount: Int
    let scrollToPage: (Int) -> Void
    let dismiss: () -> Void

    @State private var pageText = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.pageJump)
                        .font(.title3.weight(.semibold))
                    Text(L10n.pageStatus(pageIndex + 1, pageCount))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    TextField(L10n.page, text: $pageText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 82)
                        .onSubmit(commit)

                    Text(L10n.pageTotal(pageCount))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { Double(pageIndex + 1) },
                            set: { scrollToPage(Int($0.rounded()) - 1) }
                        ),
                        in: 1...Double(max(pageCount, 1)),
                        step: 1
                    )
                }

                HStack {
                    Button(L10n.previousPage) {
                        scrollToPage(pageIndex - 1)
                        syncPageText()
                    }
                    .os26GlassButton()
                    .disabled(pageIndex <= 0)

                    Button(L10n.nextPage) {
                        scrollToPage(pageIndex + 1)
                        syncPageText()
                    }
                    .os26GlassButton()
                    .disabled(pageIndex >= pageCount - 1)

                    Spacer()

                    Button(L10n.cancel, action: dismiss)
                        .os26GlassButton()
                        .keyboardShortcut(.cancelAction)

                    Button(L10n.goToPage) {
                        commit()
                        dismiss()
                    }
                    .os26GlassButton(prominent: true)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 420)
            .keiPanel(22)
        }
        .onAppear(perform: syncPageText)
        .onChange(of: pageIndex) { _, _ in
            syncPageText()
        }
    }

    private func syncPageText() {
        pageText = "\(min(max(pageIndex, 0), max(pageCount - 1, 0)) + 1)"
    }

    private func commit() {
        let target = (Int(pageText) ?? pageIndex + 1) - 1
        scrollToPage(target)
        syncPageText()
    }
}

private struct ConditionalScrollSnapping: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.scrollTargetBehavior(.viewAligned(limitBehavior: .automatic))
        } else {
            content
        }
    }
}
