import SwiftUI
#if os(macOS)
import AppKit
#endif

struct RemoteImageLoadKey: Hashable, Sendable {
    let rawValue: String

    init(localURL: URL?, url: URL?) {
        rawValue = "\(localURL?.path(percentEncoded: false) ?? "")|\(url?.absoluteString ?? "")"
    }
}

enum RemoteImageLoadPolicy {
    static func shouldDisplay(
        loadedImageKey: RemoteImageLoadKey?,
        currentKey: RemoteImageLoadKey
    ) -> Bool {
        loadedImageKey == currentKey
    }

    static func shouldCommit(
        requestedKey: RemoteImageLoadKey,
        activeKey: RemoteImageLoadKey?,
        isCancelled: Bool
    ) -> Bool {
        isCancelled == false && activeKey == requestedKey
    }
}

private struct RemoteImageLoadedImage {
    let key: RemoteImageLoadKey
    let image: PlatformImage
}

private struct RemoteImageLoadRequest {
    let key: RemoteImageLoadKey
    let localURL: URL?
    let url: URL?
}

/// Remote image view that fills whatever space the parent proposes.
///
/// **Why this is small.** This view used to flip its intrinsic size as
/// the bitmap loaded — a `Rectangle` placeholder ideal-sized to 10×10
/// versus a fully-decoded `Image.resizable().aspectRatio()` afterwards.
/// Inside `LazyVStack` cells that intrinsic-size flip kept feeding the
/// `_LazyLayoutViewCache.withMutableCacheState` recursion the macOS
/// cpu_resource diagnostic caught at 100% CPU when scrolling up. Even
/// after the reader switched to a regular `VStack`, the same flip
/// inflated `SpotlightArticleThumbnail` because the placeholder's
/// 10×10 ideal size let the ZStack expand past its `aspectRatio()`
/// cap and the loaded `og:image` came in at 1200 pt tall.
///
/// The right contract is: this view does **not** dictate its own size.
/// Both states (placeholder and loaded image) ask the parent for
/// whatever space the parent already chose to give. Callers then wrap
/// us in a `frame(...)` / `aspectRatio(...)` of their choosing — the
/// same way you'd pin a SwiftUI `Image` in any other view.
struct RemoteImageView: View {
    let url: URL?
    var localURL: URL? = nil
    var contentMode: ContentMode = .fill
    var onImageLoaded: ((PlatformImage) -> Void)? = nil
    @State private var loadedImage: RemoteImageLoadedImage?
    @State private var failedKey: RemoteImageLoadKey?
    @State private var activeLoadKey: RemoteImageLoadKey?

    var body: some View {
        let currentLoadKey = loadKey
        let isDisplayingCurrentImage = RemoteImageLoadPolicy.shouldDisplay(
            loadedImageKey: loadedImage?.key,
            currentKey: currentLoadKey
        )

        // `Rectangle().fill(.quaternary)` is the placeholder fill: a
        // Shape is a flexible View, so it always grows to whatever
        // proposal the parent makes (unlike a bare `Color` which is
        // a ShapeStyle, not a View). Keeping the placeholder always
        // mounted as the bottom layer means the cell has a stable
        // visual before / after / during load and the layout never
        // re-measures when the loaded bitmap swaps in.
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if isDisplayingCurrentImage == false {
                    if RemoteImageLoadPolicy.shouldDisplay(
                        loadedImageKey: failedKey,
                        currentKey: currentLoadKey
                    ) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .overlay {
                if isDisplayingCurrentImage,
                   let image = loadedImage?.image {
                    image.swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            }
            .clipped()
            .task(id: currentLoadKey) {
                await load(
                    RemoteImageLoadRequest(
                        key: currentLoadKey,
                        localURL: localURL,
                        url: url
                    )
                )
            }
    }

    private var loadKey: RemoteImageLoadKey {
        RemoteImageLoadKey(localURL: localURL, url: url)
    }

    private func load(_ request: RemoteImageLoadRequest) async {
        activeLoadKey = request.key
        failedKey = nil

        if let localURL = request.localURL {
            do {
                let localImage = try await ImagePipeline.shared.image(contentsOf: localURL)
                commit(localImage, for: request.key)
                return
            } catch {
                // Preserve the previous fallback behavior: if a downloaded
                // file moved or has not landed yet, the remote URL can still
                // keep the surface useful.
            }
            guard Task.isCancelled == false else { return }
        }

        guard let url = request.url else {
            fail(for: request.key)
            return
        }
        // Do not mutate `loadedImage` at the start of a new request. The
        // rendered bitmap is keyed below, so a reused gallery cell stops
        // showing the old artwork immediately while an unchanged URL keeps
        // its decoded image through refreshes.
        do {
            let loadedImage = try await ImagePipeline.shared.image(for: url)
            commit(loadedImage, for: request.key)
        } catch {
            fail(for: request.key)
        }
    }

    private func commit(_ image: PlatformImage, for key: RemoteImageLoadKey) {
        guard RemoteImageLoadPolicy.shouldCommit(
            requestedKey: key,
            activeKey: activeLoadKey,
            isCancelled: Task.isCancelled
        ) else {
            return
        }
        failedKey = nil
        loadedImage = RemoteImageLoadedImage(key: key, image: image)
        onImageLoaded?(image)
    }

    private func fail(for key: RemoteImageLoadKey) {
        guard RemoteImageLoadPolicy.shouldCommit(
            requestedKey: key,
            activeKey: activeLoadKey,
            isCancelled: Task.isCancelled
        ) else {
            return
        }
        failedKey = key
        if RemoteImageLoadPolicy.shouldDisplay(
            loadedImageKey: loadedImage?.key,
            currentKey: key
        ) {
            loadedImage = nil
        }
    }
}
