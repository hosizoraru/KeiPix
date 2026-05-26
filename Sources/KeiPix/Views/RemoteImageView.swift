import AppKit
import SwiftUI

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
    var onImageLoaded: ((NSImage) -> Void)? = nil
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
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
                if image == nil {
                    if failed {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            }
            .clipped()
            .task(id: loadKey) {
                await load()
            }
    }

    private var loadKey: String {
        "\(localURL?.path(percentEncoded: false) ?? "")|\(url?.absoluteString ?? "")"
    }

    private func load() async {
        if let localURL, let localImage = NSImage(contentsOf: localURL) {
            failed = false
            image = localImage
            onImageLoaded?(localImage)
            return
        }

        guard let url else {
            failed = true
            return
        }
        failed = false
        // Don't clear `image` here. The previous version set
        // `image = nil` before fetching, which forced every cell that
        // was already showing a decoded image to revert to the
        // placeholder for one layout pass — yet another invalidation
        // the layout cache had to chase. Keep the old bitmap visible
        // until the new one is ready (or the load fails).
        do {
            let loadedImage = try await ImagePipeline.shared.image(for: url)
            image = loadedImage
            onImageLoaded?(loadedImage)
        } catch {
            failed = true
            image = nil
        }
    }
}
