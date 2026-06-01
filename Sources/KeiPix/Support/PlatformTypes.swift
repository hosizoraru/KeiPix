import CoreGraphics
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Cross-platform type aliases

/// Primary image type. `NSImage` on macOS, `UIImage` on iPadOS.
/// Every call site that passes or stores an image should use this
/// alias so the `#if` switch lives in exactly one place.
#if os(macOS)
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
#else
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#endif

/// Convenience initialiser so callers can write
/// `PlatformImage(contentsOf: url)` on both platforms.
#if os(iOS) || os(watchOS) || os(tvOS)
extension UIImage {
    convenience init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data)
    }
}
#endif

// MARK: - SwiftUI ↔ Platform bridging

extension PlatformImage {
    /// Wraps the platform image in a SwiftUI `Image`.
    var swiftUIImage: Image {
        #if os(macOS)
        Image(nsImage: self)
        #else
        Image(uiImage: self)
        #endif
    }

    /// Extracts a CGImage regardless of whether the backing image is
    /// AppKit's `NSImage` or UIKit's `UIImage`.
    var platformCGImage: CGImage? {
        #if os(macOS)
        cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        cgImage
        #endif
    }

    /// Encodes a CGImage as JPEG using the platform-native bitmap path.
    static func jpegData(from cgImage: CGImage, compressionQuality: CGFloat) -> Data? {
        #if os(macOS)
        let representation = NSBitmapImageRep(cgImage: cgImage)
        return representation.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
        #else
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: compressionQuality)
        #endif
    }
}

extension Color {
    static var platformControlBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var platformWindowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var platformTextBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var platformLabel: Color {
        #if os(macOS)
        Color(nsColor: .labelColor)
        #else
        Color(uiColor: .label)
        #endif
    }

    static var platformSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
}
