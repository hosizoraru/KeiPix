import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum UgoiraGIFExporter {
    static func export(animation: UgoiraAnimation, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            animation.frames.count,
            nil
        ) else {
            throw PixivAPIError.invalidResponse
        }

        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        for frame in animation.frames {
            guard let cgImage = frame.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw PixivAPIError.invalidResponse
            }
            let frameProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: max(Double(frame.delayMilliseconds) / 1000.0, 0.01)
                ]
            ]
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw PixivAPIError.invalidResponse
        }
    }
}
