import CoreGraphics
import Foundation

/// A single image processing step that transforms a CGImage.
///
/// Processors run sequentially on the decode queue after the
/// initial `CGImageSource` decode and before the `PlatformImage`
/// wrap. They are `Sendable` structs with no mutable state so
/// they inherit the existing background-queue threading model
/// without additional synchronisation.
///
/// Every built-in processor uses only Apple-provided frameworks
/// (CoreImage, Vision) so no bundled models or external
/// dependencies are required.
protocol ImageProcessor: Sendable {
    /// Stable identifier persisted in UserDefaults to track
    /// which processors are active.
    var identifier: String { get }
    /// Human-readable name shown in the settings UI.
    var displayName: String { get }
    /// Transform the input image. Return `nil` to fall back to
    /// the unprocessed original.
    func process(_ cgImage: CGImage) -> CGImage?
}
