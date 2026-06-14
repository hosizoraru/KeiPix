#if os(iOS)
import Photos

/// Saves downloaded artwork images to the Photos library on iOS and iPadOS.
///
/// Uses add-only authorization and imports the downloaded file resource
/// directly so Photos can preserve the resource filename and infer image
/// metadata from the file.
enum PhotosSaver {
    /// Save an image file to the Photos library.
    /// Returns true on success, false on failure or cancellation.
    @MainActor
    static func saveImage(from url: URL, originalFilename: String? = nil) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = originalFilename ?? url.lastPathComponent
                request.addResource(with: .photo, fileURL: url, options: options)
            }
            return true
        } catch {
            return false
        }
    }

    /// Save image data to the Photos library.
    @MainActor
    static func saveImageData(_ data: Data, originalFilename: String? = nil) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                if let originalFilename {
                    options.originalFilename = originalFilename
                }
                request.addResource(with: .photo, data: data, options: options)
            }
            return true
        } catch {
            return false
        }
    }
}
#endif
