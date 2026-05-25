import AppKit
import Foundation

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
    let image: NSImage
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
}
