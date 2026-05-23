import SwiftUI

struct DownloadQueueView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedDownloadedArtwork: ArtworkDownloadItem?
    @State private var selectedDownloadedImageURLs: [URL] = []

    var body: some View {
        VStack(spacing: 0) {
            DownloadQueueHeader(downloads: store.downloads)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            if store.downloads.items.isEmpty {
                EmptyStateView(
                    title: L10n.noDownloadsTitle,
                    subtitle: L10n.noDownloadsSubtitle,
                    systemImage: "arrow.down.circle"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.downloads.items) { item in
                            DownloadQueueRow(
                                item: item,
                                downloads: store.downloads,
                                canOpen: store.downloads.hasReadableImages(for: item),
                                open: {
                                    openDownloadedArtwork(item)
                                }
                            )
                        }
                    }
                    .padding(18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(L10n.downloads)
        .sheet(item: $selectedDownloadedArtwork) { item in
            DownloadedArtworkViewer(item: item, imageURLs: selectedDownloadedImageURLs)
        }
    }

    private func openDownloadedArtwork(_ item: ArtworkDownloadItem) {
        let imageURLs = store.downloads.imageFileURLs(for: item)
        guard imageURLs.isEmpty == false else { return }
        selectedDownloadedImageURLs = imageURLs
        selectedDownloadedArtwork = item
    }
}

private struct DownloadQueueHeader: View {
    @Bindable var downloads: ArtworkDownloadStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.downloads)
                    .font(.headline)
                Text(downloads.downloadDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            Button {
                downloads.openDownloadDirectory()
            } label: {
                Label(L10n.openFolder, systemImage: "folder")
            }
            .buttonStyle(.bordered)

            Button {
                downloads.clearCompleted()
            } label: {
                Label(L10n.clearCompleted, systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(downloads.items.contains { $0.status == .completed } == false)
        }
    }
}

private struct DownloadQueueRow: View {
    let item: ArtworkDownloadItem
    @Bindable var downloads: ArtworkDownloadStore
    let canOpen: Bool
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(item.status.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .keiGlass(10)
                }

                Text(item.creatorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: item.progress)
                    .opacity(item.status == .completed ? 0.55 : 1)

                HStack(spacing: 8) {
                    Text(item.progressLabel)
                    if let errorMessage = item.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else if let folderPath = item.folderPath {
                        Text(folderPath)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button {
                open()
            } label: {
                Label(L10n.openDownloadedArtwork, systemImage: "book")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .disabled(canOpen == false)
            .help(L10n.openDownloadedArtwork)

            Button {
                downloads.reveal(item)
            } label: {
                Label(L10n.revealInFinder, systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.revealInFinder)
        }
        .padding(12)
        .keiPanel(16)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .downloading:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
