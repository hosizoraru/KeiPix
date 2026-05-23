import AppKit
import SwiftUI

struct RemoteImageView: View {
    let url: URL?
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
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
        .task(id: url) {
            await load()
        }
        .clipped()
    }

    private func load() async {
        guard let url else {
            failed = true
            return
        }
        failed = false
        image = nil
        do {
            image = try await ImagePipeline.shared.image(for: url)
        } catch {
            failed = true
        }
    }
}
