import SwiftUI

struct UgoiraPlayerView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var animation: UgoiraAnimation?
    @State private var currentFrameIndex = 0
    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playbackTask: Task<Void, Never>?

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
                url: artwork.imageURL(at: 0, preferOriginal: store.useOriginalImagesInDetail),
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
                Text("\(currentFrameIndex + 1) / \(animation.frameCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .keiGlass(12)
            }

            Spacer()

            Button {
                Task { await loadAndPlay(forceReload: true) }
            } label: {
                Label(L10n.reloadUgoira, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .keiInteractiveGlass(12)
            .disabled(isLoading)
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
            animation = try await store.loadUgoiraAnimation(for: artwork)
            isLoading = false
            startPlayback()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
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
