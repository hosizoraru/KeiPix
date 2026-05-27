import SwiftUI

// MARK: - Cross-platform type aliases

/// Primary image type. `NSImage` on macOS, `UIImage` on iPadOS.
/// Every call site that passes or stores an image should use this
/// alias so the `#if` switch lives in exactly one place.
#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
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
}
