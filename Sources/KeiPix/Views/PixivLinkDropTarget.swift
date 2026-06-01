import SwiftUI
import UniformTypeIdentifiers

/// Modifier that turns any view into a Pixiv-link drop target. Built on
/// SwiftUI's `dropDestination(for:)` (Transferable) instead of legacy
/// `NSItemProvider` plumbing — Apple's modern API auto-handles `URL`,
/// `String`, and Apple-style web internet locations and gives us a typed
/// payload with no continuation dance.
///
/// We accept either `URL` or `String` because Safari, Notes, and Messages
/// each prefer different transferred shapes (URL vs. selected text), and
/// older Pixiv links are sometimes pasted as raw text. The first viable
/// payload that passes `PixivWebLinkResolver` wins; the rest are ignored.
struct PixivLinkDropTargetModifier: ViewModifier {
    @Binding var isTargeted: Bool
    var forceOverlayVisible = false
    var openURL: (URL) -> Void
    var rejectDrop: () -> Void

    func body(content: Content) -> some View {
        content
            .dropDestination(for: PixivLinkDropPayload.self) { payloads, _ in
                Task { @MainActor in
                    if let url = PixivDroppedLinkReader.firstSupportedURL(from: payloads) {
                        openURL(url)
                    } else {
                        rejectDrop()
                    }
                }
                return true
            } isTargeted: { value in
                isTargeted = value
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

/// Transferable payload that captures whatever the source app handed us
/// — a real `URL`, plain text, or an Apple web internet location — so
/// the drop handler can normalise everything into one place.
///
/// `Transferable` lets us declare each shape via `ProxyRepresentation`
/// and let the framework run the legwork (type negotiation, async
/// loading, sandbox-aware reads) that we used to hand-roll with
/// `NSItemProvider.loadItem`.
struct PixivLinkDropPayload: Transferable, Sendable {
    var rawText: String

    static var transferRepresentation: some TransferRepresentation {
        // URL first — Safari address bar drags surface as `public.url`.
        ProxyRepresentation { (url: URL) in
            PixivLinkDropPayload(rawText: url.absoluteString)
        }
        // Plain text — Notes / Messages selections come through as
        // `public.utf8-plain-text`.
        ProxyRepresentation { (text: String) in
            PixivLinkDropPayload(rawText: text)
        }
    }
}

@MainActor
enum PixivDroppedLinkReader {
    /// Returns the first transferred payload that resolves to a known
    /// Pixiv destination. Tries the payload as a literal URL first, then
    /// scans embedded text — mirrors how a Pixiv link can hide inside a
    /// tweet, a Discord paste, or an email signature.
    static func firstSupportedURL(from payloads: [PixivLinkDropPayload]) -> URL? {
        for payload in payloads {
            let trimmed = payload.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }

            if let url = URL(string: trimmed),
               PixivWebLinkResolver.destination(from: url) != nil {
                return url
            }

            if let url = PixivWebLinkResolver.firstSupportedURL(in: trimmed) {
                return url
            }
        }
        return nil
    }

    static func firstSupportedURL(from rawTexts: [String]) -> URL? {
        firstSupportedURL(from: rawTexts.map(PixivLinkDropPayload.init(rawText:)))
    }
}
