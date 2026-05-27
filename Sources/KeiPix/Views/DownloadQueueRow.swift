import AppKit
import SwiftUI

/// Single row inside `DownloadQueueView`. Lives in its own file so the
/// queue view stays under SwiftLint's 1000-line ceiling and so the row
/// can evolve independently as we add the live-throughput badge,
/// Quick Look button, drag affordance, and focus indicator.
struct DownloadQueueRow: View {
    let item: ArtworkDownloadItem
    @Bindable var downloads: ArtworkDownloadStore
    let canOpen: Bool
    let isFocused: Bool
    let open: () -> Void
    let retry: () -> Void
    let reveal: () -> Void
    let quickLook: () -> Void
    let copied: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

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
                    if let sourcePageLabel = item.sourcePageLabel {
                        Text(sourcePageLabel)
                    }
                    if let queuedAfter = item.queuedAfter, queuedAfter > Date() {
                        Text(String(
                            format: L10n.retryScheduledFormat,
                            queuedAfter.formatted(date: .omitted, time: .standard)
                        ))
                    }
                    if let downloadedSize = downloads.downloadedSizeText(for: item) {
                        Text(downloadedSize)
                    }
                    // Live byte/sec badge, monospaced so the digits
                    // don't reflow as the rate changes. Renders only
                    // when the row is .downloading and the sampler
                    // has fresh samples.
                    if let throughput = downloads.throughputText(for: item) {
                        Text(throughput)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tint)
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
                    retry()
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(item.sourceImageURLs?.isEmpty != false)
                .help(L10n.retry)
            }

            if item.status == .queued || item.status == .downloading {
                Button {
                    cancel()
                } label: {
                    Label(L10n.cancelDownload, systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .help(L10n.cancelDownload)
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

            // Quick Look — same affordance Finder hands to a selected
            // file via the space bar. Disabled for queued / failed
            // rows where there's no on-disk artifact yet. The space
            // shortcut is wired at the row level (focused() + .onKeyPress)
            // rather than on the button so multiple rendered buttons
            // don't fight over a single accelerator.
            Button {
                quickLook()
            } label: {
                Label(L10n.quickLook, systemImage: "eye")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(canOpen == false)
            .help(L10n.quickLookHint)

            Button {
                reveal()
            } label: {
                Label(L10n.revealInFinder, systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.revealInFinder)

            Menu {
                if let pixivURL = item.pixivURL {
                    Button {
                        PlatformWorkspace.open(pixivURL)
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button {
                        PasteboardWriter.copy(pixivURL.absoluteString)
                        copied()
                    } label: {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                }

                Button {
                    quickLook()
                } label: {
                    Label(L10n.quickLook, systemImage: "eye")
                }
                .disabled(canOpen == false)

                Button {
                    reveal()
                } label: {
                    Label(L10n.revealInFinder, systemImage: "folder")
                }

                Divider()

                if item.status == .queued || item.status == .downloading {
                    Button(role: .destructive, action: cancel) {
                        Label(L10n.cancelDownload, systemImage: "xmark.circle")
                    }
                }

                Button(role: .destructive, action: delete) {
                    Label(L10n.deleteDownload, systemImage: "trash")
                }
                .disabled(item.status == .downloading)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.moreActions)
        }
        .padding(12)
        .keiPanel(16)
        // Subtle accent ring on the focused row so users can see which
        // entry the space bar will preview. Mirrors how Finder's list
        // view paints a halo around the selected file.
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.65), lineWidth: 2)
            }
        }
        .modifier(DownloadRowDraggableModifier(fileURL: draggableFileURL))
        .contextMenu {
            if item.status == .failed {
                Button(L10n.retry) {
                    retry()
                }
                .disabled(item.sourceImageURLs?.isEmpty != false)
            }
            Button(L10n.quickLook) {
                quickLook()
            }
            .disabled(canOpen == false)
            Button(L10n.revealInFinder) {
                reveal()
            }
            if let pixivURL = item.pixivURL {
                Button(L10n.openInPixiv) {
                    PlatformWorkspace.open(pixivURL)
                }
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(pixivURL.absoluteString)
                    copied()
                }
            }
            if item.status == .queued || item.status == .downloading {
                Button(role: .destructive, action: cancel) {
                    Text(L10n.cancelDownload)
                }
            }
            Button(role: .destructive, action: delete) {
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

    /// File URL that should be promised to Finder when the user starts
    /// dragging the row. For image-page artworks we pick the folder so
    /// the whole multi-page set drags as one bundle (Finder will surface
    /// it as a folder copy, which is the same shape the Reveal-in-Finder
    /// command opens). For Ugoira we pick the .zip file. Returns `nil`
    /// for queued / failed / cancelled rows so SwiftUI hides the drag
    /// affordance entirely.
    private var draggableFileURL: URL? {
        guard item.status == .completed else { return nil }
        switch item.resolvedArtifactKind {
        case .imagePages:
            // Prefer the folder so multi-page artworks drag as one
            // selection. Fall back to the first written file when the
            // folder path got pruned (older queue entries from before
            // we persisted `folderPath`).
            if let folderPath = item.folderPath {
                let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
                if downloads.fileManager.fileExists(atPath: folderURL.path(percentEncoded: false)) {
                    return folderURL
                }
            }
            return downloads.imageFileURLs(for: item).first
        case .ugoiraZip:
            guard let filePath = item.downloadedFilePaths?.first else { return nil }
            let url = URL(fileURLWithPath: filePath, isDirectory: false)
            return downloads.fileManager.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
        }
    }
}

/// Wraps `.draggable(...)` so a row with no readable file renders as a
/// plain row instead of an empty drag source. SwiftUI's `.draggable`
/// always installs a drag recogniser, even when the closure returns an
/// empty payload — we'd rather skip the modifier entirely so the user
/// can't start a phantom drag from a queued or failed row.
struct DownloadRowDraggableModifier: ViewModifier {
    let fileURL: URL?

    func body(content: Content) -> some View {
        if let fileURL {
            content
                .draggable(fileURL) {
                    DownloadDragPreview(fileURL: fileURL)
                }
        } else {
            content
        }
    }
}

struct DownloadDragPreview: View {
    let fileURL: URL

    var body: some View {
        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        Label(
            fileURL.lastPathComponent,
            systemImage: isDirectory ? "folder" : "doc"
        )
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }
}
