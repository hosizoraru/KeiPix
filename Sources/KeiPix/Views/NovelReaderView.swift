import AppKit
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

    // MARK: - Local UI state

    @State private var pageIndex: Int = 0
    @State private var readerLoadStarted = false
    @State private var isSettingsPresented = false
    @State private var translationEngine = NovelTranslationEngine()
    @State private var translationConfig: TranslationSession.Configuration?

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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .background(theme.backgroundColor)
        .foregroundStyle(theme.foregroundColor)
        .task(id: novel.id) {
            readerLoadStarted = true
            pageIndex = 0
            translationEngine.reset()
            await novelStore.loadNovelText(for: novel.id)
            await loadEmbeddedImages()
        }
        .onChange(of: novelStore.loadedNovelTextID) { _, newValue in
            if newValue == novel.id {
                pageIndex = 0
            }
        }
        .onChange(of: pageIndex) { _, _ in
            // Don't clear cached translations — they persist across
            // page navigation. Only trigger translation for the new
            // page if inline translation is active.
            if translationEngine.isInlineTranslationActive, translationConfig != nil {
                translationConfig?.invalidate()
            }
        }
        .translationTask(translationConfig) { session in
            guard translationEngine.isInlineTranslationActive else { return }
            await translateCurrentPage(session: session)
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
                showChapterMarkers: $showChapterMarkers
            )
            .iPadFriendlySheet()
        }
    }

    // MARK: - Translation

    private func translateCurrentPage(session: TranslationSession) async {
        let page = pageIndex
        guard translationEngine.isInlineTranslationActive else { return }

        // Skip if already cached
        if translationEngine.hasTranslation(for: page) { return }

        let paragraphs = currentPageTokens.enumerated().compactMap { index, token -> (Int, String)? in
            if case .text(let value) = token,
               let translatable = CaptionTranslationAvailability.translatableText(from: value) {
                return (index, translatable)
            }
            return nil
        }
        guard paragraphs.isEmpty == false else { return }

        translationEngine.setTranslating(pageIndex: page, total: paragraphs.count)

        // Translate paragraphs with concurrency for speed.
        // Use TaskGroup to translate multiple paragraphs in parallel.
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
            if translationEngine.isTranslating(pageIndex: pageIndex) {
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
        } else {
            GeometryReader { geo in
                if geo.size.width >= 1200, pages.count > 1 {
                    twoPageLayout(geo: geo)
                } else {
                    singlePageLayout
                }
            }
        }
    }

    // MARK: - Single page layout

    private var singlePageLayout: some View {
        ScrollView {
            pageColumn(tokens: currentPageTokens, pageIndex: pageIndex)
                .frame(maxWidth: CGFloat(maxContentWidth), alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .textSelection(.enabled)
        }
    }

    // MARK: - Two-page book layout

    private func twoPageLayout(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left page
            ScrollView {
                pageColumn(tokens: currentPageTokens, pageIndex: pageIndex)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 24)
                    .padding(.leading, 32)
                    .padding(.vertical, 24)
                    .textSelection(.enabled)
            }

            // Spine divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)

            // Right page (next page)
            ScrollView {
                if pageIndex + 1 < pages.count {
                    pageColumn(tokens: nextPageTokens, pageIndex: pageIndex + 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                        .padding(.trailing, 32)
                        .padding(.vertical, 24)
                        .textSelection(.enabled)
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
        }
    }

    // MARK: - Page column

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

    private var footer: some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    // MARK: - Page navigation

    private func goToPage(_ target: Int) {
        let clamped = min(max(target, 0), pages.count - 1)
        guard clamped != pageIndex else { return }
        pageIndex = clamped
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
        case .light: Color(nsColor: .textBackgroundColor)
        case .sepia: Color(red: 0.96, green: 0.92, blue: 0.84)
        case .dark: Color(red: 0.12, green: 0.12, blue: 0.13)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .light: Color(nsColor: .labelColor)
        case .sepia: Color(red: 0.32, green: 0.24, blue: 0.16)
        case .dark: Color(red: 0.92, green: 0.92, blue: 0.94)
        }
    }

    var embedBackgroundColor: Color {
        switch self {
        case .light: Color(nsColor: .controlBackgroundColor)
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
                    Toggle(L10n.novelReaderShowChapterMarkers, isOn: $showChapterMarkers)
                    Toggle(L10n.novelReaderUseVerticalLayout, isOn: $useVerticalLayout)
                        .disabled(true)
                        .help(L10n.novelReaderUseVerticalLayout)
                }
            }
            .formStyle(.grouped)
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 360)
    }
}
