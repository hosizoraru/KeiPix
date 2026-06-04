#if os(macOS)
import AppKit
#endif
import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif

/// Body-text reader presented as a sheet from `NovelDetailView`.
///
/// Features:
/// - Two-page book layout on wide screens (> 1200pt)
/// - Bilingual / immersive inline translation
/// - Per-page translation caching
/// - Keyboard navigation (←/→)
struct NovelReaderView: View {
    @Bindable var store: KeiPixStore
    let novel: PixivNovel

    @Environment(\.dismiss) private var dismiss

    // MARK: - Persistent settings

    @AppStorage("novelReader.textSize") private var textSize: Double = 17
    @AppStorage("novelReader.lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("novelReader.paragraphSpacing") private var paragraphSpacing: Double = 8
    @AppStorage("novelReader.maxContentWidth") private var maxContentWidth: Double = 720
    @AppStorage("novelReader.theme") private var themeRawValue: String = NovelReaderTheme.light.rawValue
    @AppStorage("novelReader.fontFamily") private var fontFamilyRawValue: String = NovelReaderFontFamily.system.rawValue
    @AppStorage("novelReader.useVerticalLayout") private var useVerticalLayout: Bool = false
    @AppStorage("novelReader.showChapterMarkers") private var showChapterMarkers: Bool = true
    @AppStorage("novelReader.readingMode") private var readingModeRaw: String = NovelReadingMode.singlePage.rawValue
    @AppStorage("novelReader.translationMode") private var translationModeRaw: String = NovelTranslationMode.bilingual.rawValue
    @AppStorage("novelReader.translationActive") private var translationActive: Bool = false

    // MARK: - Local UI state

    @State private var pageIndex: Int = 0
    @State private var readerLoadStarted = false
    @State private var isSettingsPresented = false
    @State private var translationEngine = NovelTranslationEngine()
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var swipeOffset: CGFloat = 0
    @State private var swipeEdgeLeading = false
    @State private var swipeEdgeTrailing = false
    @State private var effectivePagedReadingMode: NovelReadingMode = .singlePage

    private var novelStore: NovelFeatureStore { store.novels }

    private var theme: NovelReaderTheme {
        NovelReaderTheme(rawValue: themeRawValue) ?? .light
    }

    private var fontFamily: NovelReaderFontFamily {
        NovelReaderFontFamily(rawValue: fontFamilyRawValue) ?? .system
    }

    private var pages: [[NovelToken]] {
        Self.splitPages(novelStore.loadedNovelTokens)
    }

    private var currentPageTokens: [NovelToken] {
        guard pages.indices.contains(pageIndex) else { return [] }
        return pages[pageIndex]
    }

    private var nextPageTokens: [NovelToken] {
        let next = pageIndex + 1
        guard pages.indices.contains(next) else { return [] }
        return pages[next]
    }

    private var usesContinuousNovelReader: Bool {
        ReaderAdaptiveLayout.usesContinuousNovelReader(platform: readerPlatform)
    }

    private var readerPlatform: ReaderPlatformKind {
        .current
    }

    private var continuousReaderTokens: [NovelToken] {
        pages.flatMap { $0 }
    }

    private var continuousTranslatedTexts: [Int: String] {
        var translated: [Int: String] = [:]
        var continuousIndex = 0

        for pageIndex in pages.indices {
            let page = pages[pageIndex]
            for tokenIndex in page.indices {
                if let value = translationEngine.translatedText(pageIndex: pageIndex, tokenIndex: tokenIndex) {
                    translated[continuousIndex] = value
                }
                continuousIndex += 1
            }
        }

        return translated
    }

    private var isContinuousTranslationInProgress: Bool {
        pages.indices.contains { translationEngine.isTranslating(pageIndex: $0) }
    }

    private var isReaderTranslationInProgress: Bool {
        usesContinuousNovelReader
            ? isContinuousTranslationInProgress
            : translationEngine.isTranslating(pageIndex: pageIndex)
    }

    private var showsReaderFooter: Bool {
        guard usesContinuousNovelReader else { return true }
        return novelStore.loadedNovelText?.seriesPrev != nil || novelStore.loadedNovelText?.seriesNext != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if showsReaderFooter {
                Divider()
                footer
            }
        }
        .background(theme.backgroundColor)
        .foregroundStyle(theme.foregroundColor)
        .task(id: novel.id) {
            readerLoadStarted = true
            pageIndex = 0
            translationEngine.reset()
            // Restore persisted translation preferences
            translationEngine.translationMode = NovelTranslationMode(rawValue: translationModeRaw) ?? .bilingual
            if translationActive {
                translationEngine.isInlineTranslationActive = true
                translationConfig = TranslationLanguageResolver.configuration(for: store.translationTargetLanguage)
            }
            await novelStore.loadNovelText(for: novel.id)
            await loadEmbeddedImages()
        }
        .onChange(of: novelStore.loadedNovelTextID) { _, newValue in
            if newValue == novel.id {
                pageIndex = 0
            }
        }
        .onChange(of: pageIndex) { _, _ in
            guard usesContinuousNovelReader == false else { return }
            // Don't clear cached translations — they persist across
            // page navigation. Only trigger translation for the new
            // page if inline translation is active.
            if translationEngine.isInlineTranslationActive, translationConfig != nil {
                translationConfig?.invalidate()
            }
            // VoiceOver announcement for page change
            #if os(macOS)
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                let announcement = String(format: L10n.novelPageProgressFormat, pageIndex + 1, pages.count)
                NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [.announcement: announcement])
            }
            #endif
        }
        .onChange(of: readingModeRaw) { _, _ in
            guard usesContinuousNovelReader == false else { return }
            // When switching to double-page mode, translate the next
            // page if translation is active.
            let mode = NovelReadingMode(rawValue: readingModeRaw) ?? .singlePage
            if mode == .doublePage, translationEngine.isInlineTranslationActive, translationConfig != nil {
                translationConfig?.invalidate()
            }
        }
        .translationTask(translationConfig) { session in
            guard translationEngine.isInlineTranslationActive else { return }
            if usesContinuousNovelReader {
                await translateContinuousReaderPages(session: session)
            } else {
                await translateCurrentPage(session: session)
                // In double-page mode, also translate the next page
                let mode = NovelReadingMode(rawValue: readingModeRaw) ?? .singlePage
                if mode == .doublePage, pageIndex + 1 < pages.count {
                    await translatePage(pageIndex + 1, session: session)
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            NovelReaderSettingsView(
                textSize: $textSize,
                lineSpacing: $lineSpacing,
                paragraphSpacing: $paragraphSpacing,
                maxContentWidth: $maxContentWidth,
                themeRawValue: $themeRawValue,
                fontFamilyRawValue: $fontFamilyRawValue,
                useVerticalLayout: $useVerticalLayout,
                showChapterMarkers: $showChapterMarkers,
                readingModeRaw: $readingModeRaw,
                translationModeRaw: $translationModeRaw
            )
            .os26SheetChrome(.form)
        }
    }

    // MARK: - Translation

    private func translateCurrentPage(session: TranslationSession) async {
        await translatePage(pageIndex, session: session)
    }

    private func translateContinuousReaderPages(session: TranslationSession) async {
        for page in pages.indices {
            guard translationEngine.isInlineTranslationActive else { return }
            await translatePage(page, session: session)
        }
    }

    private func translatePage(_ page: Int, session: TranslationSession) async {
        guard translationEngine.isInlineTranslationActive else { return }
        if translationEngine.hasTranslation(for: page) { return }

        guard pages.indices.contains(page) else { return }
        let tokens = pages[page]

        let paragraphs = tokens.enumerated().compactMap { index, token -> (Int, String)? in
            if case .text(let value) = token,
               let translatable = CaptionTranslationAvailability.translatableText(from: value) {
                return (index, translatable)
            }
            return nil
        }
        guard paragraphs.isEmpty == false else { return }

        translationEngine.setTranslating(pageIndex: page, total: paragraphs.count)

        var results: [Int: String] = [:]
        let total = paragraphs.count

        await withTaskGroup(of: (Int, String)?.self) { group in
            for (tokenIndex, paragraphText) in paragraphs {
                guard translationEngine.isInlineTranslationActive else { break }
                group.addTask {
                    if let response = try? await session.translate(paragraphText) {
                        return (tokenIndex, response.targetText)
                    }
                    return nil
                }
            }

            for await result in group {
                if let (tokenIndex, translated) = result {
                    results[tokenIndex] = translated
                }
                translationEngine.updateProgress(completed: results.count, total: total)
            }
        }
        translationEngine.applyResults(results, for: page)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(novel.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(novel.user.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Bookmark
            Button {
                Task {
                    await novelStore.toggleBookmark(
                        novel: novel,
                        restrict: store.defaultBookmarkRestrict
                    )
                }
            } label: {
                Label(
                    novel.isBookmarked ? L10n.novelRemoveBookmark : L10n.novelBookmark,
                    systemImage: novel.isBookmarked ? "bookmark.fill" : "bookmark"
                )
                .labelStyle(.iconOnly)
            }
            .help(novel.isBookmarked ? L10n.novelRemoveBookmark : L10n.novelBookmark)
            .keyboardShortcut("b", modifiers: [])

            if usesContinuousNovelReader == false {
                readingModeButton
            }

            // Translation mode picker (bilingual / immersive)
            translationModeMenu

            // Settings
            Button {
                isSettingsPresented = true
            } label: {
                Label(L10n.novelReaderSettings, systemImage: "textformat.size")
                    .labelStyle(.iconOnly)
            }
            .help(L10n.novelReaderSettings)
            .keyboardShortcut(",", modifiers: .command)

            // Close
            Button {
                dismiss()
            } label: {
                Label(L10n.close, systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }

    private var readingModeButton: some View {
        Button {
            let current = NovelReadingMode(rawValue: readingModeRaw) ?? .singlePage
            readingModeRaw = (current == .singlePage ? NovelReadingMode.doublePage : .singlePage).rawValue
        } label: {
            let current = NovelReadingMode(rawValue: readingModeRaw) ?? .singlePage
            Label(current.title, systemImage: current.systemImage)
                .labelStyle(.iconOnly)
        }
        .help(L10n.readingMode)
        .keyboardShortcut("d", modifiers: .command)
    }

    private var translationModeMenu: some View {
        HStack(spacing: 6) {
            Menu {
                // Toggle translation on/off
                Button {
                    toggleTranslation()
                } label: {
                    Label(
                        translationEngine.isInlineTranslationActive ? L10n.disable : L10n.enable,
                        systemImage: translationEngine.isInlineTranslationActive ? "xmark.circle" : "character.bubble"
                    )
                }
                .keyboardShortcut("t", modifiers: [])

                Divider()

                // Mode picker — checkmark on selected item
                ForEach(NovelTranslationMode.allCases) { mode in
                    Button {
                        translationEngine.translationMode = mode
                        translationModeRaw = mode.rawValue
                        if translationEngine.isInlineTranslationActive {
                            translationConfig?.invalidate()
                        }
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                    .disabled(translationEngine.translationMode == mode)
                }
            } label: {
                Label(L10n.translate, systemImage: translationEngine.isInlineTranslationActive
                      ? translationEngine.translationMode.systemImage
                      : "character.bubble")
                .labelStyle(.iconOnly)
            }
            .help(translationEngine.isInlineTranslationActive
                  ? translationEngine.translationMode.helpText
                  : L10n.translate)
            .accessibilityLabel(L10n.translate)
            .tint(translationEngine.isInlineTranslationActive ? .accentColor : nil)

            // Progress indicator during translation
            if isReaderTranslationInProgress {
                ProgressView(value: translationEngine.translationProgress)
                    .progressViewStyle(.circular)
                    .controlSize(.mini)
                    .help(String(format: L10n.translationProgressFormat,
                                 translationEngine.translationCompleted,
                                 translationEngine.translationTotal))
            }
        }
    }

    private func toggleTranslation() {
        translationEngine.isInlineTranslationActive.toggle()
        translationActive = translationEngine.isInlineTranslationActive
        if translationEngine.isInlineTranslationActive {
            translationConfig = TranslationLanguageResolver.configuration(for: store.translationTargetLanguage)
        } else {
            translationEngine.clearAll()
            translationConfig = nil
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !readerLoadStarted || novelStore.isLoadingNovelText {
            loadingState
        } else if let error = novelStore.novelTextError {
            errorState(error)
        } else if novelStore.loadedNovelText == nil || novelStore.loadedNovelTokens.isEmpty {
            unavailableState
        } else if usesContinuousNovelReader {
            continuousReaderLayout
        } else {
            GeometryReader { geo in
                let mode = resolvedPagedReadingMode(for: geo.size)
                Group {
                    if mode == .doublePage, pages.count > 1 {
                        twoPageLayout(geo: geo)
                    } else {
                        singlePageLayout
                    }
                }
                .onAppear {
                    effectivePagedReadingMode = mode
                }
                .onChange(of: geo.size) { _, _ in
                    effectivePagedReadingMode = mode
                }
                .onChange(of: readingModeRaw) { _, _ in
                    effectivePagedReadingMode = mode
                }
                .onChange(of: pages.count) { _, _ in
                    effectivePagedReadingMode = mode
                }
            }
            .animation(.snappy(duration: 0.2), value: pageIndex)
            .animation(.snappy(duration: 0.2), value: readingModeRaw)
        }
        }

    // MARK: - Continuous mobile layout

    @ViewBuilder
    private var continuousReaderLayout: some View {
        let tokens = continuousReaderTokens
        if usesNativeNovelTextPage(tokens) {
            NativeNovelContinuousTextView(
                tokens: tokens,
                fontFamily: fontFamily,
                textSize: textSize,
                lineSpacing: lineSpacing,
                paragraphSpacing: paragraphSpacing,
                theme: theme,
                translatedTexts: continuousTranslatedTexts,
                translationMode: translationEngine.translationMode,
                isTranslationActive: translationEngine.isInlineTranslationActive,
                isTranslating: isContinuousTranslationInProgress,
                showChapterMarkers: showChapterMarkers,
                maxContentWidth: CGFloat(maxContentWidth)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.backgroundColor)
        } else {
            ScrollView {
                continuousTokenColumn
                    .frame(maxWidth: CGFloat(maxContentWidth), alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .textSelection(.enabled)
            }
            .scrollIndicators(.visible)
            .background(theme.backgroundColor)
        }
    }

    private var continuousTokenColumn: some View {
        VStack(alignment: .leading, spacing: CGFloat(paragraphSpacing)) {
            ForEach(pages.indices, id: \.self) { sectionIndex in
                if sectionIndex > 0 {
                    Divider()
                        .padding(.vertical, 10)
                }
                ForEach(Array(pages[sectionIndex].enumerated()), id: \.offset) { tokenIndex, token in
                    tokenView(token, tokenIndex: tokenIndex, pageIndex: sectionIndex)
                }
            }
        }
    }

    // MARK: - Single page layout

    private var singlePageLayout: some View {
        ZStack {
            readerPageSurface(
                tokens: currentPageTokens,
                pageIndex: pageIndex,
                maxWidth: CGFloat(maxContentWidth),
                horizontalPadding: 32,
                verticalPadding: 24,
                alignment: .center
            )
            .offset(x: swipeOffset)

            // Edge glow during swipe
            swipeEdgeOverlays
        }
        .background {
            Color.clear
                .readerGestures(
                    isEnabled: store.trackpadGesturesEnabled,
                    onScroll: handlePageSwipe,
                    onMagnify: { _, _ in false },
                    onSmartMagnify: { false },
                    onDrag: { _ in false }
                )
        }
    }

    // MARK: - Two-page book layout

    private func twoPageLayout(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left page
            readerPageSurface(
                tokens: currentPageTokens,
                pageIndex: pageIndex,
                maxWidth: nil,
                horizontalPadding: 0,
                verticalPadding: 24,
                leadingPadding: 32,
                trailingPadding: 24,
                alignment: .trailing
            )

            // Spine divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)

            // Right page (next page)
            if pageIndex + 1 < pages.count {
                readerPageSurface(
                    tokens: nextPageTokens,
                    pageIndex: pageIndex + 1,
                    maxWidth: nil,
                    horizontalPadding: 0,
                    verticalPadding: 24,
                    leadingPadding: 24,
                    trailingPadding: 32,
                    alignment: .leading
                )
            } else {
                // Last page — show end mark
                VStack {
                    Spacer()
                    Image(systemName: "book.closed")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(L10n.novelEnd)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .offset(x: swipeOffset)
        .overlay {
            swipeEdgeOverlays
        }
        .background {
            Color.clear
                .readerGestures(
                    isEnabled: store.trackpadGesturesEnabled,
                    onScroll: handlePageSwipe,
                    onMagnify: { _, _ in false },
                    onSmartMagnify: { false },
                    onDrag: { _ in false }
                )
        }
    }

    // MARK: - Swipe edge glow

    @ViewBuilder
    private var swipeEdgeOverlays: some View {
        HStack(spacing: 0) {
            // Leading edge glow (swiping right → go back)
            if swipeEdgeLeading {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 60)
                .allowsHitTesting(false)
            }

            Spacer()

            // Trailing edge glow (swiping left → go forward)
            if swipeEdgeTrailing {
                LinearGradient(
                    colors: [.clear, Color.accentColor.opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 60)
                .allowsHitTesting(false)
            }
        }
        .animation(.snappy(duration: 0.15), value: swipeEdgeLeading || swipeEdgeTrailing)
    }

    // MARK: - Page column

    @ViewBuilder
    private func readerPageSurface(
        tokens: [NovelToken],
        pageIndex: Int,
        maxWidth: CGFloat?,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        leadingPadding: CGFloat? = nil,
        trailingPadding: CGFloat? = nil,
        alignment: Alignment
    ) -> some View {
        let leading = leadingPadding ?? horizontalPadding
        let trailing = trailingPadding ?? horizontalPadding
        if usesNativeNovelTextPage(tokens) {
            nativeNovelTextPage(tokens: tokens, pageIndex: pageIndex)
                .frame(maxWidth: maxWidth ?? .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, leading)
                .padding(.trailing, trailing)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        } else {
            ScrollView {
                pageColumn(tokens: tokens, pageIndex: pageIndex)
                    .frame(maxWidth: maxWidth ?? .infinity, alignment: alignment)
                    .frame(maxWidth: .infinity, alignment: alignment)
                    .padding(.leading, leading)
                    .padding(.trailing, trailing)
                    .padding(.vertical, verticalPadding)
                    .textSelection(.enabled)
            }
        }
    }

    private func usesNativeNovelTextPage(_ tokens: [NovelToken]) -> Bool {
        tokens.contains { token in
            switch token {
            case .pixivImage, .uploadedImage:
                true
            case .text, .newPage, .chapter, .jumpURL, .ruby, .jumpPage:
                false
            }
        } == false
    }

    private func nativeNovelTextPage(tokens: [NovelToken], pageIndex: Int) -> some View {
        NativeNovelTextPageView(
            tokens: tokens,
            fontFamily: fontFamily,
            textSize: textSize,
            lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing,
            theme: theme,
            translatedTexts: translatedTexts(for: tokens, pageIndex: pageIndex),
            translationMode: translationEngine.translationMode,
            isTranslationActive: translationEngine.isInlineTranslationActive,
            isTranslating: translationEngine.isTranslating(pageIndex: pageIndex),
            showChapterMarkers: showChapterMarkers
        )
    }

    private func translatedTexts(for tokens: [NovelToken], pageIndex: Int) -> [Int: String] {
        var result: [Int: String] = [:]
        for index in tokens.indices {
            if let translated = translationEngine.translatedText(pageIndex: pageIndex, tokenIndex: index) {
                result[index] = translated
            }
        }
        return result
    }

    private func pageColumn(tokens: [NovelToken], pageIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(paragraphSpacing)) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                tokenView(token, tokenIndex: index, pageIndex: pageIndex)
            }
        }
    }

    // MARK: - Token rendering

    @ViewBuilder
    private func tokenView(_ token: NovelToken, tokenIndex: Int = 0, pageIndex: Int = 0) -> some View {
        switch token {
        case .text(let value):
            textTokenView(value, tokenIndex: tokenIndex, pageIndex: pageIndex)
        case .newPage:
            EmptyView()
        case .chapter(let title):
            if showChapterMarkers {
                chapterMarker(title)
            }
        case .pixivImage(let illustID, _):
            embeddedArtworkView(illustID: illustID)
        case .uploadedImage(let key):
            uploadedImageView(key: key)
        case .jumpURL(let label, let url):
            Link(destination: url) {
                Label(label.isEmpty ? url.absoluteString : label, systemImage: "link")
                    .font(bodyFont.weight(.medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .ruby(let base, let reading):
            Text("\(Text(base).font(bodyFont))\(Text(" (\(reading))").font(rubyAnnotationFont))")
                .frame(maxWidth: .infinity, alignment: .leading)
        case .jumpPage(let target):
            Text(String(format: L10n.novelJumpPageFormat, target))
                .font(bodyFont.weight(.medium).italic())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func textTokenView(_ value: String, tokenIndex: Int, pageIndex: Int) -> some View {
        if translationEngine.isInlineTranslationActive,
           let translated = translationEngine.translatedText(pageIndex: pageIndex, tokenIndex: tokenIndex) {
            switch translationEngine.translationMode {
            case .bilingual:
                // Bilingual: original on top, translation below with accent bar
                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(bodyFont)
                        .lineSpacing(CGFloat(max(lineSpacing - 2, 0)))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(translated)
                        .font(bodyFont)
                        .lineSpacing(CGFloat(max(lineSpacing - 2, 0)))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(.tertiary)
                                .frame(width: 3)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .immersive:
                // Immersive: translation replaces original
                Text(translated)
                    .font(bodyFont)
                    .lineSpacing(CGFloat(max(lineSpacing - 2, 0)))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if translationEngine.isTranslating(pageIndex: pageIndex) {
            // Show original while translating
            Text(value)
                .font(bodyFont)
                .lineSpacing(CGFloat(max(lineSpacing - 2, 0)))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(0.6)
        } else {
            Text(value)
                .font(bodyFont)
                .lineSpacing(CGFloat(max(lineSpacing - 2, 0)))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if usesContinuousNovelReader {
            continuousReaderFooter
        } else {
            pagedReaderFooter
        }
    }

    private var continuousReaderFooter: some View {
        HStack(spacing: 12) {
            seriesPreviousButton

            Spacer(minLength: 0)

            seriesNextButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private var pagedReaderFooter: some View {
        HStack(spacing: 12) {
            seriesPreviousButton

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    goToPage(pageIndex - 1)
                } label: {
                    Label(L10n.previousPage, systemImage: "arrow.left")
                        .labelStyle(.iconOnly)
                }
                .disabled(pageIndex == 0 || pages.isEmpty)
                .keyboardShortcut(.leftArrow, modifiers: [])

                if pages.isEmpty == false {
                    Text(String(format: L10n.novelPageProgressFormat, pageIndex + 1, pages.count))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Button {
                    goToPage(pageIndex + 1)
                } label: {
                    Label(L10n.nextPage, systemImage: "arrow.right")
                        .labelStyle(.iconOnly)
                }
                .disabled(pageIndex >= pages.count - 1 || pages.isEmpty)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            Spacer(minLength: 0)

            seriesNextButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private var seriesPreviousButton: some View {
        Button {
            if let prev = novelStore.loadedNovelText?.seriesPrev {
                navigateToSeriesEntry(id: prev.id)
            }
        } label: {
            Label(L10n.novelPreviousInSeries, systemImage: "chevron.backward.circle")
                .labelStyle(.iconOnly)
        }
        .disabled(novelStore.loadedNovelText?.seriesPrev == nil)
        .help(L10n.novelPreviousInSeries)
    }

    private var seriesNextButton: some View {
        Button {
            if let next = novelStore.loadedNovelText?.seriesNext {
                navigateToSeriesEntry(id: next.id)
            }
        } label: {
            Label(L10n.novelNextInSeries, systemImage: "chevron.forward.circle")
                .labelStyle(.iconOnly)
        }
        .disabled(novelStore.loadedNovelText?.seriesNext == nil)
        .help(L10n.novelNextInSeries)
    }

    // MARK: - Page navigation

    private func resolvedPagedReadingMode(for availableSize: CGSize) -> NovelReadingMode {
        ReaderAdaptiveLayout.effectiveNovelMode(
            preferredMode: NovelReadingMode(rawValue: readingModeRaw) ?? .singlePage,
            pageCount: pages.count,
            availableSize: availableSize,
            platform: readerPlatform
        )
    }

    private func goToPage(_ target: Int) {
        let clamped = min(max(target, 0), pages.count - 1)
        guard clamped != pageIndex else { return }
        pageIndex = clamped
    }

    // MARK: - Trackpad gestures

    @State private var accumulatedSwipeX: CGFloat = 0

    private func handlePageSwipe(_ event: ReaderScrollEvent) -> Bool {
        guard store.trackpadGesturesEnabled, event.isMomentum == false else {
            return false
        }

        // Only handle horizontal swipes
        guard abs(event.deltaX) > abs(event.deltaY) * 1.35 else {
            if event.isFinished {
                accumulatedSwipeX = 0
                resetSwipeVisual()
            }
            return false
        }

        accumulatedSwipeX += event.deltaX

        // Visual feedback — show edge glow and subtle offset
        let clampedOffset = max(-40, min(40, accumulatedSwipeX * 0.3))
        swipeOffset = clampedOffset
        swipeEdgeLeading = accumulatedSwipeX > 30
        swipeEdgeTrailing = accumulatedSwipeX < -30

        let threshold: CGFloat = 80
        if abs(accumulatedSwipeX) >= threshold {
            let delta = accumulatedSwipeX > 0 ? -1 : 1
            accumulatedSwipeX = 0
            resetSwipeVisual()

            let effectiveDelta = effectivePagedReadingMode == .doublePage ? delta * 2 : delta
            goToPage(pageIndex + effectiveDelta)
            return true
        }

        if event.isFinished {
            accumulatedSwipeX = 0
            resetSwipeVisual()
        }
        return true
    }

    private func resetSwipeVisual() {
        withAnimation(.snappy(duration: 0.2)) {
            swipeOffset = 0
            swipeEdgeLeading = false
            swipeEdgeTrailing = false
        }
    }

    // MARK: - Loading / error states

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(L10n.novelLoadingText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(L10n.novelTextUnavailable)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await novelStore.loadNovelText(for: novel.id) }
            } label: {
                Label(L10n.retry, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableState: some View {
        EmptyStateView(
            title: L10n.novelTextUnavailable,
            subtitle: L10n.novelTextUnavailableHint,
            systemImage: "doc.text.magnifyingglass"
        )
    }

    // MARK: - Helpers

    private func chapterMarker(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.justify")
                .foregroundStyle(.secondary)
            Text(String(format: L10n.novelChapterFormat, title))
                .font(bodyFont.weight(.semibold))
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func embeddedArtworkView(illustID: Int) -> some View {
        let imageURL = novelStore.embeddedArtworkURLs[illustID]
        let pixivURL = URL(string: "https://www.pixiv.net/artworks/\(illustID)")
        return VStack(alignment: .leading, spacing: 6) {
            if let imageURL {
                RemoteImageView(url: imageURL)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.novelEmbeddedImage)
                            .font(.callout.weight(.medium))
                        Text(L10n.pixivIllustRef(illustID))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let pixivURL {
                        Button {
                            PlatformWorkspace.open(pixivURL)
                        } label: {
                            Label(L10n.openInPixiv, systemImage: "arrow.up.right.square")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(10)
                .background(theme.embedBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func uploadedImageView(key: String) -> some View {
        let imageURL = novelStore.uploadedImageURLs[key]
        return VStack(alignment: .leading, spacing: 6) {
            if let imageURL {
                RemoteImageView(url: imageURL)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "photo.stack")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.novelEmbeddedUploadedImage)
                            .font(.callout.weight(.medium))
                        Text(key)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(theme.embedBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadEmbeddedImages() async {
        let artworkIDs = Set(novelStore.loadedNovelTokens.compactMap { token -> Int? in
            if case .pixivImage(let id, _) = token { return id }
            return nil
        })
        let hasUploadedImages = novelStore.loadedNovelTokens.contains { token in
            if case .uploadedImage = token { return true }
            return false
        }

        async let uploadedTask: Void = {
            if hasUploadedImages {
                await novelStore.loadUploadedImages(for: novel.id)
            }
        }()

        await withTaskGroup(of: Void.self) { group in
            for illustID in artworkIDs {
                group.addTask {
                    await novelStore.loadEmbeddedArtworkURL(illustID: illustID)
                }
            }
        }
        await uploadedTask
    }

    private func navigateToSeriesEntry(id: Int) {
        Task {
            await novelStore.refreshNovelDetail(novelID: id)
            if let resolved = novelStore.selectedNovel, resolved.id == id {
                await novelStore.openNovel(resolved)
            } else {
                await novelStore.loadNovelText(for: id)
            }
        }
    }

    private var bodyFont: Font {
        switch fontFamily {
        case .system:
            return .system(size: CGFloat(textSize))
        case .serif:
            return .system(size: CGFloat(textSize), weight: .regular, design: .serif)
        case .monospaced:
            return .system(size: CGFloat(textSize), weight: .regular, design: .monospaced)
        }
    }

    private var rubyAnnotationFont: Font {
        switch fontFamily {
        case .system:
            return .system(size: CGFloat(max(textSize - 4, 9)))
        case .serif:
            return .system(size: CGFloat(max(textSize - 4, 9)), weight: .regular, design: .serif)
        case .monospaced:
            return .system(size: CGFloat(max(textSize - 4, 9)), weight: .regular, design: .monospaced)
        }
    }

    static func splitPages(_ tokens: [NovelToken]) -> [[NovelToken]] {
        guard tokens.isEmpty == false else { return [] }
        var pages: [[NovelToken]] = []
        var current: [NovelToken] = []
        for token in tokens {
            if case .newPage = token {
                if current.isEmpty == false {
                    pages.append(current)
                    current = []
                }
            } else {
                current.append(token)
            }
        }
        if current.isEmpty == false {
            pages.append(current)
        }
        return pages.isEmpty ? [tokens] : pages
    }
}

// MARK: - Novel reading mode

enum NovelReadingMode: String, CaseIterable, Identifiable {
    case singlePage
    case doublePage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePage: return L10n.singlePage
        case .doublePage: return L10n.doublePage
        }
    }

    var systemImage: String {
        switch self {
        case .singlePage: return "rectangle"
        case .doublePage: return "rectangle.split.2x1"
        }
    }
}

// MARK: - Theme + font models

enum NovelReaderTheme: String, CaseIterable, Identifiable {
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: L10n.novelReaderThemeLight
        case .sepia: L10n.novelReaderThemeSepia
        case .dark: L10n.novelReaderThemeDark
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: Color.platformTextBackground
        case .sepia: Color(red: 0.96, green: 0.92, blue: 0.84)
        case .dark: Color(red: 0.12, green: 0.12, blue: 0.13)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .light: Color.platformLabel
        case .sepia: Color(red: 0.32, green: 0.24, blue: 0.16)
        case .dark: Color(red: 0.92, green: 0.92, blue: 0.94)
        }
    }

    var embedBackgroundColor: Color {
        switch self {
        case .light: Color.platformControlBackground
        case .sepia: Color(red: 0.92, green: 0.86, blue: 0.76)
        case .dark: Color(red: 0.18, green: 0.18, blue: 0.20)
        }
    }
}

enum NovelReaderFontFamily: String, CaseIterable, Identifiable {
    case system
    case serif
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.novelReaderFontSystem
        case .serif: L10n.novelReaderFontSerif
        case .monospaced: L10n.novelReaderFontMonospaced
        }
    }
}

// MARK: - Settings sheet

struct NovelReaderSettingsView: View {
    @Binding var textSize: Double
    @Binding var lineSpacing: Double
    @Binding var paragraphSpacing: Double
    @Binding var maxContentWidth: Double
    @Binding var themeRawValue: String
    @Binding var fontFamilyRawValue: String
    @Binding var useVerticalLayout: Bool
    @Binding var showChapterMarkers: Bool
    @Binding var readingModeRaw: String
    @Binding var translationModeRaw: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.novelReaderSettings)
                    .font(.title3.bold())
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Label(L10n.close, systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut(.cancelAction)
            }

            Form {
                Section {
                    Slider(value: $textSize, in: 12...28, step: 1) {
                        Text(L10n.novelReaderTextSize)
                    } minimumValueLabel: {
                        Text("12").font(.caption)
                    } maximumValueLabel: {
                        Text("28").font(.caption)
                    }

                    Slider(value: $lineSpacing, in: 0...16, step: 1) {
                        Text(L10n.novelReaderLineSpacing)
                    } minimumValueLabel: {
                        Text("0").font(.caption)
                    } maximumValueLabel: {
                        Text("16").font(.caption)
                    }

                    Slider(value: $paragraphSpacing, in: 0...24, step: 1) {
                        Text(L10n.novelReaderParagraphSpacing)
                    } minimumValueLabel: {
                        Text("0").font(.caption)
                    } maximumValueLabel: {
                        Text("24").font(.caption)
                    }

                    Slider(value: $maxContentWidth, in: 480...960, step: 40) {
                        Text(L10n.novelReaderMaxWidth)
                    } minimumValueLabel: {
                        Text("480").font(.caption)
                    } maximumValueLabel: {
                        Text("960").font(.caption)
                    }
                }

                Section {
                    Picker(L10n.novelReaderTheme, selection: $themeRawValue) {
                        ForEach(NovelReaderTheme.allCases) { theme in
                            Text(theme.title).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(L10n.novelReaderFontFamily, selection: $fontFamilyRawValue) {
                        ForEach(NovelReaderFontFamily.allCases) { font in
                            Text(font.title).tag(font.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker(L10n.readingMode, selection: $readingModeRaw) {
                        ForEach(NovelReadingMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker(L10n.translate, selection: $translationModeRaw) {
                        ForEach(NovelTranslationMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(L10n.translate)
                } footer: {
                    Text(L10n.translationTargetLanguageHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle(L10n.novelReaderShowChapterMarkers, isOn: $showChapterMarkers)
                    Toggle(L10n.novelReaderUseVerticalLayout, isOn: $useVerticalLayout)
                        .disabled(true)
                        .help(L10n.novelReaderUseVerticalLayout)
                }
            }
            .formStyle(.grouped)
        }
        .padding(20)
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 360)
        #endif
    }
}
