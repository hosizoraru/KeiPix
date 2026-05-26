import AppKit
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
    @State private var isFocusPresetEnabled = false
    @State private var isPageJumpPresented = false

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
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.bar)
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
                guard readingMode == .continuous, let value, value != pageIndex else { return }
                pageIndex = min(max(value, 0), pageCount - 1)
            }
            .onChange(of: readingMode) { _, mode in
                store.setDefaultReadingMode(mode, for: artwork, pageCount: pageCount)
                guard mode != .singlePage else { return }
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

            // Inline quality toggle — flips the per-content quality preset
            // so the user can switch between original and standard previews
            // without diving into Settings. The button reads/writes the
            // illust or manga preset based on the artwork's kind, so a
            // user reading manga doesn't accidentally flip the illust
            // default. Mirrors the HD-style affordance Pixez/Pixes ship.
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
            .help(L10n.imageQualityToggleHint)

            Button {
                isPageJumpPresented = true
            } label: {
                Label(L10n.pageJump, systemImage: "number")
            }
            .disabled(pageCount <= 1)
            .keyboardShortcut("j", modifiers: [.command])

            Button {
                enterFocusPreset()
            } label: {
                Label(L10n.fullScreenReading, systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

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
                .disabled(pageIndex <= 0)
                .accessibilityLabel(L10n.previousPage)

                Button {
                    isPageJumpPresented = true
                } label: {
                    Image(systemName: "number")
                }
                .disabled(pageCount <= 1)
                .accessibilityLabel(L10n.pageJump)

                Button {
                    scrollToPage(pageIndex + 1, proxy: proxy)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(pageIndex >= pageCount - 1)
                .accessibilityLabel(L10n.nextPage)

                Button {
                    exitFocusPreset()
                } label: {
                    Label(L10n.exitFocusReading, systemImage: "xmark")
                }
            }
            .buttonStyle(.bordered)
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
        scrollTarget = readingMode == .singlePage ? nil : restoredPageIndex
    }

    private func scrollToPage(_ index: Int, proxy: ScrollViewProxy) {
        let clamped = min(max(index, 0), pageCount - 1)
        pageIndex = clamped
        guard readingMode != .singlePage else { return }
        withAnimation(.snappy(duration: 0.22)) {
            proxy.scrollTo(clamped, anchor: .top)
        }
    }

    private func enterFocusPreset() {
        withAnimation(.snappy(duration: 0.2)) {
            isFocusPresetEnabled = true
        }
        guard let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) == false else { return }
        window.toggleFullScreen(nil)
    }

    private func exitFocusPreset() {
        withAnimation(.snappy(duration: 0.2)) {
            isFocusPresetEnabled = false
        }
        guard let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }

    private func prefetchAround(_ index: Int) {
        let urls = artwork.prefetchURLs(around: index, preferOriginal: store.preferOriginalImages(for: artwork, pageCount: pageCount))
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

                    Text("/ \(pageCount)")
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
                    .disabled(pageIndex <= 0)

                    Button(L10n.nextPage) {
                        scrollToPage(pageIndex + 1)
                        syncPageText()
                    }
                    .disabled(pageIndex >= pageCount - 1)

                    Spacer()

                    Button(L10n.cancel, action: dismiss)
                        .keyboardShortcut(.cancelAction)

                    Button(L10n.goToPage) {
                        commit()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
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
