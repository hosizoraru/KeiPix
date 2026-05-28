import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PixivUgoiraMetadataResponse: Decodable, Sendable {
    let metadata: PixivUgoiraMetadata

    enum CodingKeys: String, CodingKey {
        case metadata = "ugoira_metadata"
    }
}

struct PixivUgoiraMetadata: Decodable, Sendable {
    let zipURLs: PixivUgoiraZipURLs
    let frames: [PixivUgoiraFrame]

    enum CodingKeys: String, CodingKey {
        case zipURLs = "zip_urls"
        case frames
    }
}

struct PixivUgoiraZipURLs: Decodable, Sendable {
    let medium: URL
}

struct PixivUgoiraFrame: Codable, Hashable, Sendable {
    let file: String
    let delay: Int
}

struct UgoiraAnimationFrame {
    let image: PlatformImage
    let delay: Duration
    let delayMilliseconds: Int
}

struct UgoiraAnimation {
    let frames: [UgoiraAnimationFrame]

    var frameCount: Int { frames.count }
    var totalDuration: Duration {
        frames.reduce(.zero) { $0 + $1.delay }
    }

    var totalDurationMilliseconds: Int {
        frames.reduce(0) { $0 + $1.delayMilliseconds }
    }

    static var visualQASample: UgoiraAnimation {
        #if os(macOS)
        let colors: [NSColor] = [.systemPink, .systemBlue, .systemGreen, .systemOrange]
        let frames = colors.enumerated().map { index, color in
            UgoiraAnimationFrame(
                image: NSImage.visualQAUgoiraFrame(index: index + 1, color: color),
                delay: .milliseconds(140),
                delayMilliseconds: 140
            )
        }
        return UgoiraAnimation(frames: frames)
        #else
        // iPadOS placeholder — real implementation in Phase 5.
        return UgoiraAnimation(frames: [])
        #endif
    }
}

enum UgoiraPlaybackSpeed: Double, CaseIterable, Identifiable, Sendable {
    case half = 0.5
    case normal = 1.0
    case fast = 1.5
    case double = 2.0

    var id: Double { rawValue }
    var multiplier: Double { rawValue }

    var title: String {
        "\(rawValue.formatted(.number.precision(.fractionLength(rawValue == 1.0 ? 0 : 1))))x"
    }

    func adjustedDelayMilliseconds(_ milliseconds: Int) -> Int {
        max(Int((Double(milliseconds) / multiplier).rounded()), 1)
    }
}

struct UgoiraExportPackage {
    let metadata: PixivUgoiraMetadata
    let zipData: Data
    let animation: UgoiraAnimation

    static var visualQASample: UgoiraExportPackage {
        UgoiraExportPackage(
            metadata: PixivUgoiraMetadata(
                zipURLs: PixivUgoiraZipURLs(medium: URL(string: "https://example.com/visual-qa-ugoira.zip")!),
                frames: UgoiraAnimation.visualQASample.frames.enumerated().map { index, frame in
                    PixivUgoiraFrame(file: "visual-qa-\(index + 1).png", delay: frame.delayMilliseconds)
                }
            ),
            zipData: Data("visual-qa-ugoira".utf8),
            animation: .visualQASample
        )
    }
}

#if os(macOS)
private extension NSImage {
    static func visualQAUgoiraFrame(index: Int, color: NSColor) -> NSImage {
        let size = NSSize(width: 960, height: 640)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        NSColor.black.withAlphaComponent(0.22).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 72, y: 72, width: size.width - 144, height: size.height - 144),
            xRadius: 36,
            yRadius: 36
        ).fill()

        let title = "KeiPix Ugoira QA"
        let subtitle = "Frame \(index)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 54, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.82)
        ]
        title.draw(at: NSPoint(x: 108, y: 342), withAttributes: attributes)
        subtitle.draw(at: NSPoint(x: 108, y: 280), withAttributes: subtitleAttributes)
        image.unlockFocus()
        return image
    }
}
#endif
