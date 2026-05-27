import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Reverse-image-search engine identifier. Used by the persistence
/// layer (UserDefaults) and the engine picker UI to track which
/// service the user prefers.
///
/// **Why not just hardcode SauceNAO.** SauceNAO has decent coverage
/// for Pixiv but routinely misses doujin, manga panels, and 2D screen
/// caps where Ascii2D is the well-known fallback. Pixez ships both;
/// dropping the user back to "open in browser" was a real gap.
enum ImageSourceSearchEngineKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case sauceNAO
    case ascii2d

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sauceNAO: L10n.engineSauceNAO
        case .ascii2d: L10n.engineAscii2D
        }
    }

    var systemImage: String {
        switch self {
        case .sauceNAO: "fork.knife"
        case .ascii2d: "barcode.viewfinder"
        }
    }
}

/// Abstract interface every reverse-search engine implements. The
/// sheet flips between engines without re-architecting state by
/// asking the active engine for an image upload result and a web
/// fallback URL.
protocol ImageSourceSearchEngine: Sendable {
    var kind: ImageSourceSearchEngineKind { get }

    /// Performs the multipart upload and parses Pixiv artwork IDs
    /// (and optional richer evidence) out of the returned HTML.
    func search(imageData: Data, filename: String) async throws -> [SauceNAOSearchResult]

    /// Open-in-browser URL for the engine's web search. SauceNAO
    /// supports `?url=`; Ascii2D doesn't, so it returns its upload
    /// landing page so the user can drop the file manually.
    func webSearchURL(imageURL: URL?) -> URL?
}

extension ImageSourceSearchEngineKind {
    /// Concrete engine instance for a kind. Resolves at the call
    /// site so the protocol can stay stateless.
    var engine: any ImageSourceSearchEngine {
        switch self {
        case .sauceNAO: SauceNAOEngine()
        case .ascii2d: Ascii2DEngine()
        }
    }
}

// MARK: - SauceNAO adapter

struct SauceNAOEngine: ImageSourceSearchEngine {
    var kind: ImageSourceSearchEngineKind { .sauceNAO }

    func search(imageData: Data, filename: String) async throws -> [SauceNAOSearchResult] {
        try await SauceNAOClient.search(imageData: imageData, filename: filename)
    }

    func webSearchURL(imageURL: URL?) -> URL? {
        guard let imageURL else { return nil }
        return SauceNAOClient.webSearchURL(imageURL: imageURL)
    }
}

// MARK: - Ascii2D

/// Ascii2D's web search has two phases: upload to `/search/file`,
/// follow the redirect to a colour-search results page, then parse the
/// returned HTML for Pixiv artwork links. The colour endpoint indexes
/// 2D-style artwork better than SauceNAO's bag-of-features index.
///
/// **Why we share `SauceNAOSearchResult`.** Both engines surface
/// "Pixiv artwork ID" hits to the user; the consumer side only needs
/// the artwork ID to open the detail view. Adding a second result
/// type would require a parallel UI for marginal gain.
enum Ascii2DClient {
    static func search(imageData: Data, filename: String) async throws -> [SauceNAOSearchResult] {
        let boundary = "KeiPixAscii2D-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://ascii2d.net/search/file")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("KeiPix/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://ascii2d.net/", forHTTPHeaderField: "Referer")
        // Ascii2D answers `406 Not Acceptable` for clients that don't
        // explicitly opt into HTML — Flutter's http library trips on
        // this exactly the same way Pixez's Dart client does.
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.httpBody = multipartBody(
            imageData: normalizedImageData(imageData),
            filename: filename,
            boundary: boundary
        )

        let session = URLSession.ascii2dShared
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw PixivAPIError.invalidResponse
        }

        return pixivArtworkIDs(in: html).map(SauceNAOSearchResult.init(artworkID:))
    }

    /// Web fallback. Ascii2D's homepage hosts the upload form; we
    /// can't pre-fill it with an image URL the way SauceNAO accepts
    /// `?url=`, so we open the landing page and the user drops the
    /// file by hand.
    static var landingURL: URL? {
        URL(string: "https://ascii2d.net/")
    }

    private static func multipartBody(imageData: Data, filename: String, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    /// Re-uses the same downscale-to-1400 normalisation as
    /// `SauceNAOClient`. Ascii2D enforces a 5 MB cap and timeouts on
    /// larger uploads, so trimming the dimensions keeps short artworks
    /// snappy and large illustrations within budget.
    private static func normalizedImageData(_ data: Data) -> Data {
        guard let image = PlatformImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return data
        }

        let maxDimension: CGFloat = 1400
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let scale = min(1, maxDimension / max(width, height))
        let targetWidth = max(1, Int((width * scale).rounded()))
        let targetHeight = max(1, Int((height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return data
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaledImage = context.makeImage() else { return data }
        let representation = NSBitmapImageRep(cgImage: scaledImage)
        return representation.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) ?? data
    }

    /// Pixiv artwork-ID extraction from Ascii2D HTML. The colour
    /// search results page links out to Pixiv via several patterns
    /// — both the legacy `member_illust.php?illust_id=N` and modern
    /// `pixiv.net/artworks/N`. We scan all three and de-duplicate.
    static func pixivArtworkIDs(in html: String) -> [Int] {
        let patterns = [
            #"illust_id=(\d+)"#,
            #"pixiv\.net/(?:en/)?artworks/(\d+)"#,
            #"pixiv\.net/(?:en/)?i/(\d+)"#
        ]
        var seen = Set<Int>()
        var ids: [Int] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in regex.matches(in: html, range: range) where match.numberOfRanges > 1 {
                guard let captureRange = Range(match.range(at: 1), in: html),
                      let id = Int(html[captureRange]),
                      seen.insert(id).inserted else {
                    continue
                }
                ids.append(id)
            }
        }
        return ids
    }
}

private extension URLSession {
    /// Dedicated session for Ascii2D. The colour search bounces
    /// through a 302 we want to follow, and we set Accept-Language
    /// to something Ascii2D treats as a real browser so it doesn't
    /// short-circuit to the bot blocker.
    static let ascii2dShared: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept-Language": "en-US,en;q=0.9,ja;q=0.8,zh-CN;q=0.7"
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

struct Ascii2DEngine: ImageSourceSearchEngine {
    var kind: ImageSourceSearchEngineKind { .ascii2d }

    func search(imageData: Data, filename: String) async throws -> [SauceNAOSearchResult] {
        try await Ascii2DClient.search(imageData: imageData, filename: filename)
    }

    func webSearchURL(imageURL: URL?) -> URL? {
        // Ascii2D doesn't accept an `?url=` query param the way
        // SauceNAO does, so the web fallback is the upload landing
        // page rather than a deep link.
        Ascii2DClient.landingURL
    }
}
