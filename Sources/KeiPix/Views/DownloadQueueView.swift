import AppKit
import SwiftUI

struct DownloadQueueView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedPreview: DownloadedPreview?

    var body: some View {
        let visibleItems = store.downloads.filteredItems

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
            } else if visibleItems.isEmpty {
                EmptyStateView(
                    title: L10n.noMatchingDownloadsTitle,
                    subtitle: L10n.noMatchingDownloadsSubtitle,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleItems) { item in
                            DownloadQueueRow(
                                item: item,
                                downloads: store.downloads,
                                canOpen: store.downloads.hasReadableDownload(for: item),
                                open: {
                                    openDownloadedItem(item)
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
        .searchable(
            text: downloadSearchBinding,
            placement: .toolbar,
            prompt: L10n.searchDownloads
        )
        .sheet(item: $selectedPreview) { preview in
            switch preview {
            case .images(let item, let imageURLs):
                DownloadedArtworkViewer(item: item, imageURLs: imageURLs)
            case .ugoira(let item, let zipURL):
                DownloadedUgoiraViewer(item: item, zipURL: zipURL)
            }
        }
    }

    private var downloadSearchBinding: Binding<String> {
        Binding {
            store.downloads.downloadSearchText
        } set: { value in
            store.downloads.setDownloadSearchText(value)
        }
    }

    private func openDownloadedItem(_ item: ArtworkDownloadItem) {
        switch item.resolvedArtifactKind {
        case .imagePages:
            let imageURLs = store.downloads.imageFileURLs(for: item)
            guard imageURLs.isEmpty == false else { return }
            selectedPreview = .images(item: item, imageURLs: imageURLs)
        case .ugoiraZip:
            guard let filePath = item.downloadedFilePaths?.first else { return }
            selectedPreview = .ugoira(item: item, zipURL: URL(fileURLWithPath: filePath))
        }
    }
}

private enum DownloadedPreview: Identifiable {
    case images(item: ArtworkDownloadItem, imageURLs: [URL])
    case ugoira(item: ArtworkDownloadItem, zipURL: URL)

    var id: String {
        switch self {
        case .images(let item, _):
            "\(item.id.uuidString)-images"
        case .ugoira(let item, _):
            "\(item.id.uuidString)-ugoira"
        }
    }
}

private struct DownloadQueueHeader: View {
    @Bindable var downloads: ArtworkDownloadStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

                Menu {
                    Picker(L10n.sortDownloads, selection: downloadSortBinding) {
                        ForEach(DownloadQueueSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                } label: {
                    Label(downloads.downloadQueueSort.title, systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.bordered)

                Button {
                    downloads.openDownloadDirectory()
                } label: {
                    Label(L10n.openFolder, systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Menu {
                    Button {
                        downloads.retryFailedFilteredItems()
                    } label: {
                        Label(L10n.retryFailedDownloads, systemImage: "arrow.clockwise")
                    }
                    .disabled(downloads.failedFilteredCount == 0)

                    Button(role: .destructive) {
                        downloads.clearFailedFilteredItems()
                    } label: {
                        Label(L10n.clearFailedDownloads, systemImage: "trash")
                    }
                    .disabled(downloads.failedFilteredCount == 0)

                    Divider()

                    Button {
                        downloads.clearInvalidItems()
                    } label: {
                        Label(L10n.clearInvalidDownloads, systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    }

                    Button {
                        downloads.clearCompleted()
                    } label: {
                        Label(L10n.clearCompleted, systemImage: "checkmark.circle")
                    }
                    .disabled(downloads.completedCount == 0)
                } label: {
                    Label(L10n.downloadActions, systemImage: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Picker(L10n.downloadFilter, selection: downloadFilterBinding) {
                    ForEach(DownloadQueueFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 620)

                Spacer()

                Text(summaryText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(storageText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var downloadFilterBinding: Binding<DownloadQueueFilter> {
        Binding {
            downloads.downloadQueueFilter
        } set: { value in
            downloads.setDownloadQueueFilter(value)
        }
    }

    private var downloadSortBinding: Binding<DownloadQueueSort> {
        Binding {
            downloads.downloadQueueSort
        } set: { value in
            downloads.setDownloadQueueSort(value)
        }
    }

    private var summaryText: String {
        String(
            format: L10n.downloadQueueSummaryFormat,
            downloads.filteredItems.count,
            downloads.activeCount,
            downloads.completedCount
        )
    }

    private var storageText: String {
        String(format: L10n.downloadStorageSummaryFormat, downloads.filteredDownloadedSizeText)
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

                    Text(item.resolvedArtifactKind.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(item.creatorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: item.progress)
                    .opacity(item.status == .completed ? 0.55 : 1)

                HStack(spacing: 8) {
                    Text(item.progressLabel)
                    if let downloadedSize = downloads.downloadedSizeText(for: item) {
                        Text(downloadedSize)
                    }
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

            if item.status == .failed {
                Button {
                    downloads.retry(item)
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(item.sourceImageURLs?.isEmpty != false)
                .help(L10n.retry)
            }

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

            Menu {
                if let pixivURL = item.pixivURL {
                    Button {
                        NSWorkspace.shared.open(pixivURL)
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button {
                        PasteboardWriter.copy(pixivURL.absoluteString)
                    } label: {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                }

                Button {
                    downloads.reveal(item)
                } label: {
                    Label(L10n.revealInFinder, systemImage: "folder")
                }

                Divider()

                Button(role: .destructive) {
                    downloads.delete(item)
                } label: {
                    Label(L10n.deleteDownload, systemImage: "trash")
                }
                .disabled(item.status == .downloading)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.moreActions)

            Button(role: .destructive) {
                downloads.delete(item)
            } label: {
                Label(L10n.deleteDownload, systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(item.status == .downloading)
            .help(L10n.deleteDownload)
        }
        .padding(12)
        .keiPanel(16)
        .contextMenu {
            if item.status == .failed {
                Button(L10n.retry) {
                    downloads.retry(item)
                }
                .disabled(item.sourceImageURLs?.isEmpty != false)
            }
            Button(L10n.revealInFinder) {
                downloads.reveal(item)
            }
            if let pixivURL = item.pixivURL {
                Button(L10n.openInPixiv) {
                    NSWorkspace.shared.open(pixivURL)
                }
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(pixivURL.absoluteString)
                }
            }
            Button(role: .destructive) {
                downloads.delete(item)
            } label: {
                Text(L10n.deleteDownload)
            }
            .disabled(item.status == .downloading)
        }
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
