import SwiftUI
import UniformTypeIdentifiers

/// Inline ugoira player surface. Lays out as a stack: artwork canvas on
/// top, transport bar below, optional toast row at the bottom — the
/// same vertical decomposition Apple uses for the QuickTime control
/// strip and what the macOS HIG recommends for media chrome.
///
/// **Why no overlay chrome.** The previous version stacked the play
/// button and frame counter on top of the animated frame. Glass-blurred
/// pills overlaying a frame that's already rapidly redrawing made the
/// chrome legibility-fragile and the layout crowded. Pushing transport
/// below the artwork keeps the canvas calm and matches QuickTime,
/// Photos, and Music's shared layout vocabulary.
struct UgoiraPlayerView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var player = UgoiraPlayer()
    @State private var exportedGIFURL: URL?
    @State private var exportPackage: UgoiraExportPackage?
    @State private var isExporting = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SinglePageReaderViewportLayout(presentation: canvasPresentation) {
                canvas
            }
                .frame(maxWidth: .infinity)
                .background(.quaternary)
                .backgroundExtensionEffect()

            UgoiraPlaybackBar(player: player) {
                trailingActions
            }

            if let statusMessage {
                statusRow(statusMessage)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        .task(id: artwork.id) {
            await load()
        }
        .onDisappear {
            player.pause()
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack {
            currentImage

            if player.isLoading {
                ProgressView(L10n.loadingUgoira)
                    .controlSize(.small)
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let message = player.failureMessage {
                errorOverlay(message)
            }

            VStack {
                HStack {
                    ArtworkContentBadgesView(badges: artwork.contentBadges, style: .overlay)
                    Spacer()
                }
                Spacer()
            }
            .padding(14)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            player.togglePlayback()
        }
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(artwork.title)
    }

    @ViewBuilder
    private var currentImage: some View {
        if let frame = currentFrame {
            frame.swiftUIImage
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .id(player.currentFrameIndex)
        } else {
            RemoteImageView(
                url: artwork.imageURL(at: 0, preferOriginal: store.preferOriginalImages(for: artwork)),
                contentMode: .fit
            )
        }
    }

    private var currentFrame: PlatformImage? {
        guard let animation = player.animation,
              animation.frames.indices.contains(player.currentFrameIndex) else {
            return nil
        }
        return animation.frames[player.currentFrameIndex].image
    }

    private var canvasPresentation: ReaderPagePresentation {
        ReaderPagePresentation(
            pageIndex: 0,
            aspectRatio: nil,
            fallbackAspectRatio: artwork.aspectRatio
        )
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Label(L10n.ugoiraFailedToLoad, systemImage: "exclamationmark.triangle")
                .font(.headline)
                .labelStyle(.titleAndIcon)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button(L10n.retry) {
                Task { await load(force: true) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                Task { await exportCurrentFrame() }
            } label: {
                Label(L10n.exportCurrentFrame, systemImage: "photo")
            }
            .disabled(player.hasContent == false || isExporting)

            Divider()

            Button {
                Task { await exportGIF() }
            } label: {
                Label(L10n.exportGIF, systemImage: "film")
            }
            .disabled(player.hasContent == false || isExporting)

            Button {
                Task { await exportZip() }
            } label: {
                Label(L10n.exportUgoiraZip, systemImage: "archivebox")
            }
            .disabled(isExporting)

            if let exportedGIFURL {
                Divider()

                ShareLink(item: exportedGIFURL) {
                    Label(L10n.shareExportedGIF, systemImage: "square.and.arrow.up")
                }

                Button {
                    PlatformWorkspace.revealInFiles(exportedGIFURL)
                } label: {
                    Label(L10n.revealExportedGIF, systemImage: "folder")
                }
            }
        } label: {
            if isExporting {
                ProgressView().controlSize(.small)
            } else {
                Label(L10n.ugoiraExportActions, systemImage: "square.and.arrow.up")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .labelStyle(.iconOnly)
        .fixedSize()
        .help(L10n.ugoiraExportActions)
        .accessibilityLabel(L10n.ugoiraExportActions)

        Button {
            Task { await load(force: true) }
        } label: {
            Label(L10n.reloadUgoira, systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help(L10n.reloadUgoira)
        .accessibilityLabel(L10n.reloadUgoira)
    }

    // MARK: - Loading

    private func load(force: Bool = false) async {
        if force == false, player.hasContent {
            player.play()
            return
        }

        player.beginLoading()

        do {
            let package = VisualQALaunchArgument.contains(.ugoiraPlayer)
                ? UgoiraExportPackage.visualQASample
                : try await store.loadUgoiraExportPackage(for: artwork)
            exportPackage = package
            player.install(package.animation)
        } catch {
            player.reportFailure(error.localizedDescription)
        }
    }

    private func loadedExportPackage() async throws -> UgoiraExportPackage {
        if let exportPackage {
            return exportPackage
        }
        player.beginLoading()
        let package = try await store.loadUgoiraExportPackage(for: artwork)
        exportPackage = package
        player.install(package.animation)
        return package
    }

    // MARK: - Export

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
        guard let frame = currentFrame else { return }
        guard let url = savePanelURL(extension: "png", contentType: .png, title: L10n.exportCurrentFrame) else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            guard let data = frame.pngData() else {
                showStatus(L10n.unableToExportFrame)
                return
            }
            try data.write(to: url, options: .atomic)
            showStatus(String(format: L10n.exportedFrameFormat, url.lastPathComponent))
        } catch {
            showStatus(error.localizedDescription)
        }
    }

    private func savePanelURL(extension fileExtension: String, contentType: UTType, title: String) -> URL? {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        panel.title = title
        panel.nameFieldStringValue = "\(artwork.id).\(fileExtension)"
        return panel.runModal() == .OK ? panel.url : nil
        #else
        return nil
        #endif
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

#if os(macOS)
extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif
