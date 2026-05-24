import AppKit
import SwiftUI

struct RemoteImageView: View {
    let url: URL?
    var localURL: URL? = nil
    var contentMode: ContentMode = .fill
    var onImageLoaded: ((NSImage) -> Void)? = nil
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        if failed {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
            }
        }
        .task(id: loadKey) {
            await load()
        }
        .clipped()
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
        image = nil
        do {
            let loadedImage = try await ImagePipeline.shared.image(for: url)
            image = loadedImage
            onImageLoaded?(loadedImage)
        } catch {
            failed = true
        }
    }
}
