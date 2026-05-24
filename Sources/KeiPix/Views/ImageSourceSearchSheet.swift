import SwiftUI

struct ImageSourceSearchSheet: View {
    @Bindable var store: KeiPixStore
    let request: ImageSourceSearchRequest

    @Environment(\.dismiss) private var dismiss
    @State private var state = SearchState.idle

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(18)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: request.id) {
            await search()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteImageView(url: request.thumbnailURL, localURL: request.localImageURL)
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.imageSourceSearch)
                    .font(.title3.weight(.semibold))
                Text(request.title)
                    .font(.headline)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text(request.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ControlGroup {
                if let imageURL = request.imageURL,
                   let webSearchURL = SauceNAOClient.webSearchURL(imageURL: imageURL) {
                    Link(destination: webSearchURL) {
                        Label(L10n.openInSauceNAO, systemImage: "safari")
                    }

                    Button {
                        PasteboardWriter.copy(webSearchURL.absoluteString)
                    } label: {
                        Label(L10n.copySauceNAOLink, systemImage: "link")
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Label(L10n.close, systemImage: "xmark")
                }
            }
            .labelStyle(.iconOnly)
            .controlSize(.small)
        }
    }

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
                    Text(String(format: L10n.imageSourceResultsFormat, results.count))
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)

                    List(results) { result in
                        Button {
                            Task { await open(result) }
                        } label: {
                            Label("#\(result.artworkID)", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                PasteboardWriter.copy("https://www.pixiv.net/artworks/\(result.artworkID)")
                            } label: {
                                Label(L10n.copyLink, systemImage: "link")
                            }
                        }
                    }
                    .listStyle(.inset)
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
        .buttonStyle(.borderedProminent)
    }

    private func search() async {
        guard case .loading = state else {
            state = .loading
            do {
                let data = try await imageData()
                let results = try await SauceNAOClient.search(
                    imageData: data,
                    filename: request.filename
                )
                state = .loaded(results)
            } catch {
                state = .failed(error.localizedDescription)
            }
            return
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
