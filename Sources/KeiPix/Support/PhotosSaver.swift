#if os(iOS)
import Photos
import UIKit

/// Saves downloaded artwork images to the Photos library on iPadOS.
///
/// Uses PHPhotoLibrary for modern Photos framework access with
/// proper authorization handling.
enum PhotosSaver {
    /// Save an image file to the Photos library.
    /// Returns true on success, false on failure or cancellation.
    @MainActor
    static func saveImage(from url: URL) async -> Bool {
        // Request authorization if needed
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return false
        }

        // Load the image from the file URL
        guard let image = UIImage(contentsOfFile: url.path) else {
            return false
        }

        // Save to Photos library
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }

    /// Save image data to the Photos library.
    @MainActor
    static func saveImageData(_ data: Data) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return false
        }

        guard let image = UIImage(data: data) else {
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }
}
#endif
