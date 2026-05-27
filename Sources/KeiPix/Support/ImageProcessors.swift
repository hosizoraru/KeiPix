import CoreGraphics
import Foundation
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(Vision)
import Vision
#endif

/// Shared `CIContext` for image processors. CIContext is thread-safe
/// and heavyweight (initialises GPU/Metal state), so reusing a single
/// instance across all processor calls avoids measurable latency.
#if canImport(CoreImage)
private let sharedCIContext = CIContext()
#endif

// MARK: - Sharpen

/// Applies luminance sharpening via `CISharpenLuminance`.
/// Lightweight — runs entirely on the GPU through Core Image.
struct SharpenProcessor: ImageProcessor {
    let identifier = "sharpen"
    let displayName = L10n.imageSharpen

    /// Sharpening intensity. Range 0.0–2.0; default 0.4.
    let intensity: Float

    init(intensity: Float = 0.4) {
        self.intensity = intensity
    }

    func process(_ cgImage: CGImage) -> CGImage? {
        #if canImport(CoreImage)
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CISharpenLuminance") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: kCIInputSharpnessKey)
        guard let output = filter.outputImage else { return nil }
        return sharedCIContext.createCGImage(output, from: output.extent)
        #else
        return nil
        #endif
    }
}

// MARK: - Denoise

/// Applies noise reduction via `CINoiseReduction`.
/// Good for JPEG artifacts and camera noise on scanned artwork.
struct DenoiseProcessor: ImageProcessor {
    let identifier = "denoise"
    let displayName = L10n.imageDenoise

    /// Noise level. Range 0.0–0.1; default 0.02.
    let noiseLevel: Float
    /// Sharpness preserved after denoising. Range 0.0–2.0; default 0.4.
    let sharpness: Float

    init(noiseLevel: Float = 0.02, sharpness: Float = 0.4) {
        self.noiseLevel = noiseLevel
        self.sharpness = sharpness
    }

    func process(_ cgImage: CGImage) -> CGImage? {
        #if canImport(CoreImage)
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CINoiseReduction") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(noiseLevel, forKey: "inputNoiseLevel")
        filter.setValue(sharpness, forKey: kCIInputSharpnessKey)
        guard let output = filter.outputImage else { return nil }
        return sharedCIContext.createCGImage(output, from: output.extent)
        #else
        return nil
        #endif
    }
}

// MARK: - Smart Crop

/// Uses Vision's saliency analysis to crop to the most visually
/// interesting region. Useful for thumbnails and gallery cards.
///
/// Runs `VNGenerateAttentionBasedSaliencyImageRequest` to produce
/// a heatmap, then crops to the bounding rect of the highest-
/// attention region, adjusted to the target aspect ratio.
struct SmartCropProcessor: ImageProcessor {
    let identifier = "smartCrop"
    let displayName = L10n.smartCrop

    /// Target width/height ratio for the crop. 1.0 = square.
    let targetAspectRatio: CGFloat

    init(targetAspectRatio: CGFloat = 1.0) {
        self.targetAspectRatio = targetAspectRatio
    }

    func process(_ cgImage: CGImage) -> CGImage? {
        #if canImport(Vision)
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first else { return nil }

        // The saliency observation provides a `salientObjects` array
        // of `VNRectangleObservation` sorted by confidence. Use the
        // union of the top salient objects as the crop region.
        let salientRects = observation.salientObjects?
            .prefix(3)
            .map(\.boundingBox) ?? []

        let cropRect: CGRect
        if salientRects.isEmpty {
            // Fallback: use the whole image.
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        } else {
            cropRect = salientRects.reduce(into: salientRects[0]) { result, rect in
                result = result.union(rect)
            }
        }

        // Convert normalised Vision coordinates (origin bottom-left)
        // to CGImage coordinates (origin top-left).
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        var scaledRect = CGRect(
            x: cropRect.origin.x * imageWidth,
            y: (1 - cropRect.origin.y - cropRect.height) * imageHeight,
            width: cropRect.width * imageWidth,
            height: cropRect.height * imageHeight
        )

        // Adjust to target aspect ratio, expanding around center.
        let currentAspect = scaledRect.width / scaledRect.height
        if currentAspect > targetAspectRatio {
            // Too wide — expand height.
            let newHeight = scaledRect.width / targetAspectRatio
            let delta = newHeight - scaledRect.height
            scaledRect.origin.y -= delta / 2
            scaledRect.size.height = newHeight
        } else {
            // Too tall — expand width.
            let newWidth = scaledRect.height * targetAspectRatio
            let delta = newWidth - scaledRect.width
            scaledRect.origin.x -= delta / 2
            scaledRect.size.width = newWidth
        }

        // Clamp to image bounds.
        scaledRect = scaledRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        guard scaledRect.width > 0, scaledRect.height > 0 else { return nil }

        return cgImage.cropping(to: scaledRect)
        #else
        return nil
        #endif
    }
}
