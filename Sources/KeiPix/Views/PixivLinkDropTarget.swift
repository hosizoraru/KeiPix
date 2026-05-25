import SwiftUI
import UniformTypeIdentifiers

struct PixivLinkDropTargetModifier: ViewModifier {
    @Binding var isTargeted: Bool
    var forceOverlayVisible = false
    var openURL: (URL) -> Void
    var rejectDrop: () -> Void

    func body(content: Content) -> some View {
        content
            .onDrop(of: supportedTypeIdentifiers, isTargeted: $isTargeted) { providers in
                Task {
                    if let url = await PixivDroppedLinkReader.firstSupportedURL(from: providers) {
                        await MainActor.run { openURL(url) }
                    } else {
                        await MainActor.run { rejectDrop() }
                    }
                }
                return true
            }
            .overlay {
                if isTargeted || forceOverlayVisible {
                    PixivLinkDropOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.snappy(duration: 0.16), value: isTargeted)
            .animation(.snappy(duration: 0.16), value: forceOverlayVisible)
    }

    private var supportedTypeIdentifiers: [String] {
        [
            UTType.url.identifier,
            UTType.fileURL.identifier,
            UTType.plainText.identifier,
            UTType.text.identifier,
            "com.apple.web-internet-location"
        ]
    }
}

private struct PixivLinkDropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(L10n.dropPixivLinkToOpen)
                    .font(.headline)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
        }
    }
}

@MainActor
enum PixivDroppedLinkReader {
    static func firstSupportedURL(from providers: [NSItemProvider]) async -> URL? {
        for provider in providers {
            if let url = await loadURL(from: provider),
               PixivWebLinkResolver.destination(from: url) != nil {
                return url
            }

            if let text = await loadText(from: provider),
               let url = PixivWebLinkResolver.firstSupportedURL(in: text) {
                return url
            }
        }
        return nil
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        let identifiers = [
            UTType.url.identifier,
            UTType.fileURL.identifier,
            "com.apple.web-internet-location"
        ]
        guard let identifier = identifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let text = item as? String {
                    continuation.resume(returning: URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        let identifiers = [UTType.plainText.identifier, UTType.text.identifier]
        guard let identifier = identifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
