import AppKit
import Foundation

enum SauceNAOClient {
    static func webSearchURL(imageURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "saucenao.com"
        components.path = "/search.php"
        components.queryItems = [
            URLQueryItem(name: "url", value: imageURL.absoluteString)
        ]
        return components.url
    }

    static func search(imageData: Data, filename: String) async throws -> [SauceNAOSearchResult] {
        let boundary = "KeiPixSauceNAO-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://saucenao.com/search.php")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("KeiPix/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = multipartBody(
            imageData: normalizedImageData(imageData),
            filename: filename,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw PixivAPIError.invalidResponse
        }

        return pixivArtworkIDs(in: html).map(SauceNAOSearchResult.init(artworkID:))
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

    private static func normalizedImageData(_ data: Data) -> Data {
        guard let image = NSImage(data: data),
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

    private static func pixivArtworkIDs(in html: String) -> [Int] {
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

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
