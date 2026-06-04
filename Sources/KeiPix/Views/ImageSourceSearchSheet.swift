import SwiftUI

/// Reverse-image-search sheet. Drives a state machine for one engine
/// at a time and lets the user flip between SauceNAO and Ascii2D
/// without dismissing the sheet — Pixez ships both because each
/// catches what the other misses (SauceNAO is bag-of-features-strong
/// for Pixiv illustrations; Ascii2D's colour search wins on doujin
/// covers, manga panels, and subtle redraws).
///
/// The engine selection is persisted on the store so the user's last
/// preference survives across sheet invocations.
struct ImageSourceSearchSheet: View {
    @Bindable var store: KeiPixStore
    let request: ImageSourceSearchRequest

    @Environment(\.dismiss) private var dismiss
    @State private var state = SearchState.idle
    @State private var lastSearchedEngine: ImageSourceSearchEngineKind?

    private var engine: any ImageSourceSearchEngine {
        store.imageSourceSearchEngine.engine
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderRail(
                overline: L10n.imageSourceSearch,
                title: request.title,
                subtitle: request.detail,
                leading: {
                    SheetHeaderThumbnail(
                        url: request.thumbnailURL,
                        size: 56,
                        cornerRadius: 10
                    )
                },
                trailing: {
                    enginePicker
                    webFallbackActions
                }
            )

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: request.id) {
            await search()
        }
        .onChange(of: store.imageSourceSearchEngine) { _, _ in
            // Switching engines mid-sheet: clear the previous results
            // and re-run against the freshly selected engine so the
            // panel reflects the user's intent within one click.
            Task { await search() }
        }
    }

    // MARK: - Engine picker

    private var enginePicker: some View {
        Picker(L10n.imageSourceSearchEngine, selection: engineBinding) {
            ForEach(ImageSourceSearchEngineKind.allCases) { kind in
                Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .help(L10n.imageSourceSearchEngine)
        .accessibilityLabel(L10n.imageSourceSearchEngine)
    }

    private var engineBinding: Binding<ImageSourceSearchEngineKind> {
        Binding(
            get: { store.imageSourceSearchEngine },
            set: { store.setImageSourceSearchEngine($0) }
        )
    }

    @ViewBuilder
    private var webFallbackActions: some View {
        if let webSearchURL = engine.webSearchURL(imageURL: request.imageURL) {
            SheetHeaderActionButton(
                title: openInTitle,
                systemImage: "safari"
            ) {
                PlatformWorkspace.open(webSearchURL)
            }

            SheetHeaderActionButton(
                title: copyTitle,
                systemImage: "link"
            ) {
                PasteboardWriter.copy(webSearchURL.absoluteString)
            }
        }
    }

    private var openInTitle: String {
        switch store.imageSourceSearchEngine {
        case .sauceNAO: L10n.openInSauceNAO
        case .ascii2d: L10n.openInAscii2D
        }
    }

    private var copyTitle: String {
        switch store.imageSourceSearchEngine {
        case .sauceNAO: L10n.copySauceNAOLink
        case .ascii2d: L10n.copyAscii2DLink
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text(L10n.searchingImageSource)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let results):
            if results.isEmpty {
                ContentUnavailableView {
                    Label(L10n.noImageSourceResults, systemImage: "magnifyingglass")
                } description: {
                    Text(L10n.noImageSourceResultsHint)
                } actions: {
                    retryButton
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Label(L10n.imageSourceSearch, systemImage: "magnifyingglass")
                            .font(.headline)

                        Text(String(format: L10n.imageSourceResultsFormat, results.count))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassEffect(.regular, in: Capsule(style: .continuous))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { result in
                                resultRow(result)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label(L10n.imageSourceSearchFailed, systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
                    .textSelection(.enabled)
            } actions: {
                retryButton
            }
        }
    }

    private var retryButton: some View {
        Button {
            Task { await search() }
        } label: {
            Label(L10n.retry, systemImage: "arrow.clockwise")
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
    }

    private func resultRow(_ result: SauceNAOSearchResult) -> some View {
        Button {
            Task { await open(result) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text("#\(result.artworkID)")
                        .font(.callout.weight(.semibold))
                    Text(L10n.openInPixiv)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .contextMenu {
            Button {
                PasteboardWriter.copy("https://www.pixiv.net/artworks/\(result.artworkID)")
            } label: {
                Label(L10n.copyLink, systemImage: "link")
            }
        }
    }

    // MARK: - Search

    private func search() async {
        state = .loading
        let activeKind = store.imageSourceSearchEngine
        let activeEngine = activeKind.engine
        do {
            let data = try await imageData()
            let results = try await activeEngine.search(
                imageData: data,
                filename: request.filename
            )
            // Guard against a stale completion clobbering a fresher
            // engine swap: if the user picked a different engine while
            // we were waiting on the network, drop this result on the
            // floor and let the newer task win.
            guard activeKind == store.imageSourceSearchEngine else { return }
            state = .loaded(results)
            lastSearchedEngine = activeKind
        } catch {
            guard activeKind == store.imageSourceSearchEngine else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private func imageData() async throws -> Data {
        if let localImageURL = request.localImageURL {
            return try Data(contentsOf: localImageURL)
        }
        guard let imageURL = request.imageURL else {
            throw PixivAPIError.invalidResponse
        }
        return try await ImagePipeline.shared.data(for: imageURL)
    }

    private func open(_ result: SauceNAOSearchResult) async {
        await store.openArtworkFromWebLink(result.artworkID)
        dismiss()
    }
}

private enum SearchState {
    case idle
    case loading
    case loaded([SauceNAOSearchResult])
    case failed(String)
}
