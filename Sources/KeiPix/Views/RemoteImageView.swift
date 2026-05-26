import AppKit
import SwiftUI

/// Remote image view that always presents the same intrinsic size to
/// its parent regardless of load state.
///
/// The previous implementation flipped between an unbounded `Rectangle`
/// placeholder and an `Image.resizable().aspectRatio(contentMode:)` once
/// the bitmap decoded. Inside a `LazyVStack` cell that intrinsic-size
/// change re-fired `_LazyLayoutViewCache.withMutableCacheState`, which
/// chained back into `StackLayout.UnmanagedImplementation.resize`,
/// `placeChildren`, `sizeChildrenIdeally`, and around again — the
/// 100%-CPU spin we caught in the macOS cpu_resource diagnostic when
/// scrolling back up through a loaded Pixivision article. Memory
/// ballooned because every layout pass kicked a new `.task(id:)` that
/// re-decoded thumbnails before the previous frame's NSImage had been
/// released.
///
/// The fix is that both branches of the ZStack now expand to fill the
/// space the parent gave us (`frame(maxWidth: .infinity, maxHeight:
/// .infinity)`) and the resizable image keeps its `aspectRatio` —
/// SwiftUI uses the *parent's* proposal as the source of truth for
/// layout, so the cell's reported size never depends on whether the
/// image has arrived. Decoding stops mutating the layout, the lazy
/// cache stops invalidating, and scroll-up settles in one frame.
struct RemoteImageView: View {
    let url: URL?
    var localURL: URL? = nil
    var contentMode: ContentMode = .fill
    var onImageLoaded: ((NSImage) -> Void)? = nil
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            // Placeholder ALWAYS occupies the proposed space. Without
            // this, a Rectangle without a frame reports its ideal size
            // as 10×10 and the parent flexes to that — causing the
            // "size keeps changing as the image loads" feedback loop.
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

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // the lazy cache had to chase. Keep the old image visible
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
