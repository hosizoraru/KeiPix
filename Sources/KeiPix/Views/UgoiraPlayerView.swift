import SwiftUI
import UniformTypeIdentifiers

struct UgoiraPlayerView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var animation: UgoiraAnimation?
    @State private var currentFrameIndex = 0
    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var exportedGIFURL: URL?
    @State private var exportPackage: UgoiraExportPackage?
    @State private var playbackTask: Task<Void, Never>?
    @State private var playbackSpeed: UgoiraPlaybackSpeed = .normal

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                currentImage
                    .scaleEffect(animation == nil ? 1 : 1)

                VStack {
                    HStack {
                        ArtworkContentBadgesView(badges: artwork.contentBadges, style: .overlay)
                        Spacer()
                        if let animation {
                            UgoiraFrameBadge(index: currentFrameIndex, count: animation.frameCount)
                        }
                    }
                    Spacer()
                    controls
                }
                .padding(14)

                if isLoading {
                    ProgressView(L10n.loadingUgoira)
                        .padding(14)
                        .keiPanel(16)
                }

                if let errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                        Text(errorMessage)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        Button(L10n.retry) {
                            Task { await loadAndPlay() }
                        }
                    }
                    .padding(16)
                    .keiPanel(18)
                    .frame(maxWidth: min(proxy.size.width - 48, 360))
                }

                if let statusMessage {
                    VStack {
                        Spacer()
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .keiGlass(14)
                            .padding(.bottom, 56)
                    }
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                togglePlayback()
            }
        }
        .aspectRatio(artwork.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
        .frame(maxHeight: ReaderPagePresentation(pageIndex: 0, aspectRatio: nil, fallbackAspectRatio: artwork.aspectRatio).singlePageMaxHeight())
        .background(.quaternary)
        .backgroundExtensionEffect()
        .clipped()
        .task(id: artwork.id) {
            await loadAndPlay()
        }
        .onDisappear {
            stopPlayback()
        }
        .onChange(of: playbackSpeed) {
            if isPlaying {
                startPlayback()
            }
        }
    }

    @ViewBuilder
    private var currentImage: some View {
        if let animation, animation.frames.indices.contains(currentFrameIndex) {
            Image(nsImage: animation.frames[currentFrameIndex].image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            RemoteImageView(
                url: artwork.imageURL(at: 0, preferOriginal: store.preferOriginalImages(for: artwork)),
                contentMode: .fit
            )
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
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
                Text(ugoiraSummary(animation))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .keiGlass(12)
            }

            Spacer()

            Menu {
                Picker(L10n.playbackSpeed, selection: $playbackSpeed) {
                    ForEach(UgoiraPlaybackSpeed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }
            } label: {
                Label(playbackSpeed.title, systemImage: "speedometer")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .controlSize(.small)
            .labelStyle(.iconOnly)
            .keiInteractiveGlass(12)
            .disabled(animation == nil || isLoading)
            .help("\(L10n.playbackSpeed) · \(playbackSpeed.title)")
            .accessibilityLabel(L10n.playbackSpeed)

            Menu {
                Button {
                    Task { await exportCurrentFrame() }
                } label: {
                    Label(L10n.exportCurrentFrame, systemImage: "photo")
                }
                .disabled(animation == nil || isLoading || isExporting)

                Divider()

                Button {
                    Task { await exportGIF() }
                } label: {
                    Label(L10n.exportGIF, systemImage: "film")
                }
                .disabled(animation == nil || isLoading || isExporting)

                Button {
                    Task { await exportZip() }
                } label: {
                    Label(L10n.exportUgoiraZip, systemImage: "archivebox")
                }
                .disabled(isLoading || isExporting)

                if let exportedGIFURL {
                    Divider()

                    ShareLink(item: exportedGIFURL) {
                        Label(L10n.shareExportedGIF, systemImage: "square.and.arrow.up")
                    }

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([exportedGIFURL])
                    } label: {
                        Label(L10n.revealExportedGIF, systemImage: "folder")
                    }
                }
            } label: {
                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(L10n.ugoiraExportActions, systemImage: "square.and.arrow.up")
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .controlSize(.small)
            .labelStyle(.iconOnly)
            .keiInteractiveGlass(12)
            .disabled(isLoading)
            .help(L10n.ugoiraExportActions)
            .accessibilityLabel(L10n.ugoiraExportActions)

            Button {
                Task { await loadAndPlay(forceReload: true) }
            } label: {
                Label(L10n.reloadUgoira, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .labelStyle(.iconOnly)
            .keiInteractiveGlass(12)
            .disabled(isLoading)
            .help(L10n.reloadUgoira)
            .accessibilityLabel(L10n.reloadUgoira)
        }
    }

    private func loadAndPlay(forceReload: Bool = false) async {
        guard forceReload || animation == nil else {
            startPlayback()
            return
        }

        stopPlayback()
        isLoading = true
        errorMessage = nil
        currentFrameIndex = 0

        do {
            let package = VisualQALaunchArgument.contains(.ugoiraPlayer)
                ? UgoiraExportPackage.visualQASample
                : try await store.loadUgoiraExportPackage(for: artwork)
            exportPackage = package
            animation = package.animation
            isLoading = false
            startPlayback()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func exportGIF() async {
        let package: UgoiraExportPackage
        do {
            package = try await loadedExportPackage()
        } catch {
            showStatus(error.localizedDescription)
            return
        }

        guard let url = savePanelURL(extension: "gif", contentType: .gif, title: L10n.exportGIF) else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            try await Task.detached(priority: .userInitiated) {
                try UgoiraGIFExporter.export(animation: package.animation, to: url)
            }.value
            exportedGIFURL = url
            showStatus(String(format: L10n.exportedGIFFormat, url.lastPathComponent))
        } catch {
            showStatus(error.localizedDescription)
        }
    }

    private func exportZip() async {
        let package: UgoiraExportPackage
        do {
            package = try await loadedExportPackage()
        } catch {
            showStatus(error.localizedDescription)
            return
        }

        guard let url = savePanelURL(extension: "zip", contentType: .zip, title: L10n.exportUgoiraZip) else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            try package.zipData.write(to: url, options: .atomic)
            showStatus(String(format: L10n.exportedZipFormat, url.lastPathComponent))
        } catch {
            showStatus(error.localizedDescription)
        }
    }

    private func exportCurrentFrame() async {
        guard let animation, animation.frames.indices.contains(currentFrameIndex) else { return }
        guard let url = savePanelURL(extension: "png", contentType: .png, title: L10n.exportCurrentFrame) else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            guard let data = animation.frames[currentFrameIndex].image.pngData() else {
                showStatus(L10n.unableToExportFrame)
                return
            }
            try data.write(to: url, options: .atomic)
            showStatus(String(format: L10n.exportedFrameFormat, url.lastPathComponent))
        } catch {
            showStatus(error.localizedDescription)
        }
    }

    private func loadedExportPackage() async throws -> UgoiraExportPackage {
        if let exportPackage {
            return exportPackage
        }
        isLoading = true
        defer { isLoading = false }
        let package = try await store.loadUgoiraExportPackage(for: artwork)
        exportPackage = package
        animation = package.animation
        return package
    }

    private func savePanelURL(extension fileExtension: String, contentType: UTType, title: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        panel.title = title
        panel.nameFieldStringValue = "\(artwork.id).\(fileExtension)"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func ugoiraSummary(_ animation: UgoiraAnimation) -> String {
        let seconds = Double(animation.totalDurationMilliseconds) / 1000.0
        return "\(currentFrameIndex + 1) / \(animation.frameCount) · \(seconds.formatted(.number.precision(.fractionLength(1))))s"
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
                try? await Task.sleep(for: .milliseconds(playbackSpeed.adjustedDelayMilliseconds(frame.delayMilliseconds)))
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
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

private struct UgoiraFrameBadge: View {
    let index: Int
    let count: Int

    var body: some View {
        Text("\(index + 1) / \(count)")
            .font(.caption.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .keiGlass(12)
    }
}
