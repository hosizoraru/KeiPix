import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DownloadedUgoiraViewer: View {
    let item: ArtworkDownloadItem
    let zipURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var animation: UgoiraAnimation?
    @State private var currentFrameIndex = 0
    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var message: String?
    @State private var playbackTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            ZStack {
                if let animation, animation.frames.indices.contains(currentFrameIndex) {
                    Image(nsImage: animation.frames[currentFrameIndex].image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(18)
                } else if isLoading {
                    ProgressView(L10n.loadingUgoira)
                        .padding(16)
                        .keiPanel(16)
                } else if let message {
                    ContentUnavailableView(message, systemImage: "play.rectangle")
                } else {
                    ContentUnavailableView(L10n.previewUgoira, systemImage: "play.rectangle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)

            controls
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .frame(minWidth: 760, minHeight: 560)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    togglePlayback()
                } label: {
                    Label(isPlaying ? L10n.pauseUgoira : L10n.playUgoira, systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(animation == nil || isLoading)

                Button {
                    revealZip()
                } label: {
                    Label(L10n.revealInFinder, systemImage: "folder")
                }
            }
        }
        .task(id: zipURL) {
            await load()
        }
        .onDisappear {
            stopPlayback()
        }
    }

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
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Label(
                    isPlaying ? L10n.pauseUgoira : L10n.playUgoira,
                    systemImage: isPlaying ? "pause.fill" : "play.fill"
                )
            }
            .buttonStyle(.glassProminent)
            .disabled(animation == nil || isLoading)

            if let animation {
                Text("\(currentFrameIndex + 1) / \(animation.frameCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .keiGlass(12)
            }

            if isExporting {
                ProgressView()
                    .controlSize(.small)
            }

            if let message, animation != nil {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                revealZip()
            } label: {
                Label(L10n.revealInFinder, systemImage: "folder")
            }
            .buttonStyle(.bordered)

            Menu {
                if let pixivURL = item.pixivURL {
                    Button {
                        NSWorkspace.shared.open(pixivURL)
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button {
                        PasteboardWriter.copy(pixivURL.absoluteString)
                        showTransientMessage(L10n.copied)
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
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .buttonStyle(.bordered)

            Button {
                Task { await exportGIF() }
            } label: {
                Label(L10n.exportGIF, systemImage: "film")
            }
            .buttonStyle(.bordered)
            .disabled(animation == nil || isLoading || isExporting)
        }
    }

    private func load() async {
        guard let frames = item.ugoiraFrames, frames.isEmpty == false else {
            message = L10n.ugoiraMetadataMissing
            return
        }

        stopPlayback()
        isLoading = true
        message = nil
        currentFrameIndex = 0

        do {
            let data = try Data(contentsOf: zipURL)
            animation = try UgoiraFrameDecoder.decode(zipData: data, frames: frames)
            isLoading = false
            startPlayback()
        } catch {
            isLoading = false
            message = error.localizedDescription
        }
    }

    private func exportGIF() async {
        guard let animation else { return }
        guard let url = saveGIFURL() else { return }

        isExporting = true
        message = nil
        defer { isExporting = false }

        do {
            try await Task.detached(priority: .userInitiated) {
                try UgoiraGIFExporter.export(animation: animation, to: url)
            }.value
            message = L10n.exported
        } catch {
            message = error.localizedDescription
        }
    }

    private func saveGIFURL() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(item.artworkID).gif"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let animation, animation.frames.isEmpty == false else { return }
        stopPlayback()
        isPlaying = true
        playbackTask = Task {
            while Task.isCancelled == false {
                let frame = animation.frames[currentFrameIndex]
                try? await Task.sleep(for: frame.delay)
                guard Task.isCancelled == false else { return }
                currentFrameIndex = (currentFrameIndex + 1) % animation.frameCount
            }
        }
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    private func revealZip() {
        NSWorkspace.shared.activateFileViewerSelecting([zipURL])
    }

    private func showTransientMessage(_ value: String) {
        message = value
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if message == value {
                message = nil
            }
        }
    }
}
