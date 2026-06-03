import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

/// Standalone sheet viewer for an already-downloaded ugoira ZIP. Shares
/// `UgoiraPlayer` + `UgoiraPlaybackBar` with the inline reader so both
/// surfaces stay visually and behaviourally consistent — same play
/// button, same scrubber, same speed picker.
struct DownloadedUgoiraViewer: View {
    let item: ArtworkDownloadItem
    let zipURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player = UgoiraPlayer()
    @State private var exportedGIFURL: URL?
    @State private var isExporting = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .platformGlassControlBar(verticalPadding: 8, topPadding: 8, bottomPadding: 6)

            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)

            UgoiraPlaybackBar(player: player) {
                trailingActions
            }

            if let statusMessage {
                statusRow(statusMessage)
            }
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 560)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    player.togglePlayback()
                } label: {
                    Label(
                        player.isPlaying ? L10n.pauseUgoira : L10n.playUgoira,
                        systemImage: player.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .labelStyle(.iconOnly)
                .help(player.isPlaying ? L10n.pauseUgoira : L10n.playUgoira)
                .keyboardShortcut(.space, modifiers: [])
                .disabled(player.hasContent == false)
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    revealZip()
                } label: {
                    Label(L10n.revealInFinder, systemImage: "folder")
                }
                .labelStyle(.iconOnly)
                .help(L10n.revealInFinder)
            }
        }
        .task(id: zipURL) {
            await load()
        }
        .onDisappear {
            player.pause()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(item.creatorName) · \(item.progressLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            ShareLink(item: zipURL) {
                Label(L10n.share, systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.share)

            Button {
                dismiss()
            } label: {
                Label(L10n.close, systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            .help(L10n.close)
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack {
            if let frame = currentFrame {
                frame.swiftUIImage
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
                    .padding(18)
                    .id(player.currentFrameIndex)
            } else if player.isLoading {
                ProgressView(L10n.loadingUgoira)
                    .controlSize(.small)
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let message = player.failureMessage {
                ContentUnavailableView {
                    Label(L10n.ugoiraFailedToLoad, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button(L10n.retry) {
                        Task { await load(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView(L10n.previewUgoira, systemImage: "play.rectangle")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            player.togglePlayback()
        }
    }

    private var currentFrame: PlatformImage? {
        guard let animation = player.animation,
              animation.frames.indices.contains(player.currentFrameIndex) else {
            return nil
        }
        return animation.frames[player.currentFrameIndex].image
    }

    // MARK: - Status row

    private func statusRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            if isExporting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .platformGlassControlBar(verticalPadding: 6, topPadding: 4, bottomPadding: 8)
        .transition(.opacity)
    }

    // MARK: - Trailing actions

    @ViewBuilder
    private var trailingActions: some View {
        Menu {
            Button {
                Task { await exportGIF() }
            } label: {
                Label(L10n.exportGIF, systemImage: "film")
            }
            .disabled(player.hasContent == false || isExporting)

            ShareLink(item: zipURL) {
                Label(L10n.shareUgoiraZip, systemImage: "archivebox")
            }

            if let exportedGIFURL {
                ShareLink(item: exportedGIFURL) {
                    Label(L10n.shareExportedGIF, systemImage: "square.and.arrow.up")
                }

                Button {
                    PlatformWorkspace.revealInFiles(exportedGIFURL)
                } label: {
                    Label(L10n.revealExportedGIF, systemImage: "folder")
                }
            }

            Divider()

            if let pixivURL = item.pixivURL {
                Button {
                    PlatformWorkspace.open(pixivURL)
                } label: {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }

                Button {
                    PasteboardWriter.copy(pixivURL.absoluteString)
                    showStatus(L10n.copied)
                } label: {
                    Label(L10n.copyLink, systemImage: "link")
                }
            }

            Button {
                revealZip()
            } label: {
                Label(L10n.revealInFinder, systemImage: "folder")
            }
        } label: {
            if isExporting {
                ProgressView().controlSize(.small)
            } else {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .labelStyle(.iconOnly)
        .fixedSize()
        .help(L10n.moreActions)
        .accessibilityLabel(L10n.moreActions)
    }

    // MARK: - Loading

    private func load(force: Bool = false) async {
        guard let frames = item.ugoiraFrames, frames.isEmpty == false else {
            player.reportFailure(L10n.ugoiraMetadataMissing)
            return
        }

        if force == false, player.hasContent {
            player.play()
            return
        }

        player.beginLoading()

        do {
            let data = try Data(contentsOf: zipURL)
            let animation = try UgoiraFrameDecoder.decode(zipData: data, frames: frames)
            player.install(animation)
        } catch {
            player.reportFailure(error.localizedDescription)
        }
    }

    // MARK: - Export

    private func exportGIF() async {
        guard let animation = player.animation else { return }
        guard let url = saveGIFURL() else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            try await Task.detached(priority: .userInitiated) {
                try UgoiraGIFExporter.export(animation: animation, to: url)
            }.value
            exportedGIFURL = url
            showStatus(String(format: L10n.exportedGIFFormat, url.lastPathComponent))
        } catch {
            showStatus(error.localizedDescription)
        }
    }

    private func saveGIFURL() -> URL? {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(item.artworkID).gif"
        return panel.runModal() == .OK ? panel.url : nil
        #else
        return nil
        #endif
    }

    private func revealZip() {
        PlatformWorkspace.revealInFiles(zipURL)
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}
