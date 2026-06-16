import Foundation

/// Registry of all available image processors. The settings UI
/// and `ImagePipeline` both look up processors by identifier
/// through this registry.
enum ImageProcessorRegistry {
    /// Conservative default for the app-controls quick toggle.
    /// Smart Crop is intentionally opt-in because it can change composition.
    static let defaultActiveProcessorIdentifiers = [
        SharpenProcessor().identifier
    ]

    /// Every processor the app ships with, in the order they
    /// appear in the settings UI.
    static let allProcessors: [any ImageProcessor] = [
        SharpenProcessor(),
        DenoiseProcessor(),
        SmartCropProcessor(),
    ]

    /// Returns the processor matching `identifier`, or `nil` if
    /// no built-in processor has that identifier.
    static func processor(for identifier: String) -> (any ImageProcessor)? {
        allProcessors.first { $0.identifier == identifier }
    }
}
