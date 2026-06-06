import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Shared brand icon surface for About, Settings, and future static chrome.
///
/// The app icon is supplied by the Icon Composer package named `keipixiv`.
/// macOS loads the compiled `keipixiv.icns` from the app bundle when available.
/// UIKit can crash when loading that app-icon asset as a plain named image, so
/// iOS uses the generated `CFBundleIconFiles` PNGs instead of `UIImage(named:)`.
/// A small fallback remains for development-only resource failures.
struct KeiPixAppIconView: View {
    static let iconAssetName = "keipixiv"

    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let image = Self.loadPlatformIcon() {
                image.swiftUIImage
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackIcon
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.62)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "app.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private static func loadPlatformIcon() -> PlatformImage? {
        #if os(macOS)
        let bundles: [Bundle] = [.main, .keipixResources]
        for bundle in bundles {
            if let bundledIcon = bundle.image(forResource: iconAssetName) {
                return bundledIcon
            }
            if let iconURL = bundle.url(forResource: iconAssetName, withExtension: "icns"),
               let bundledIcon = NSImage(contentsOf: iconURL) {
                return bundledIcon
            }
        }
        if let applicationIcon = NSImage(named: NSImage.applicationIconName) {
            return applicationIcon
        }
        return nil
        #else
        let bundles: [Bundle] = [.keipixResources, .main]
        for bundle in bundles {
            for iconName in primaryIconNames(from: bundle) {
                for candidate in iconFileCandidates(for: iconName) {
                    if let url = bundle.url(forResource: candidate, withExtension: "png"),
                       let appIcon = UIImage(contentsOfFile: url.path) {
                        return appIcon
                    }
                }
            }
        }
        return nil
        #endif
    }

    #if os(iOS)
    private static func primaryIconNames(from bundle: Bundle) -> [String] {
        let iconDictionaries = [
            bundle.infoDictionary?["CFBundleIcons~ipad"] as? [String: Any],
            bundle.infoDictionary?["CFBundleIcons"] as? [String: Any]
        ]

        return iconDictionaries
            .compactMap { $0?["CFBundlePrimaryIcon"] as? [String: Any] }
            .flatMap { primaryIcon -> [String] in
                var names: [String] = []
                if let iconName = primaryIcon["CFBundleIconName"] as? String {
                    names.append(iconName)
                }
                if let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
                    names.append(contentsOf: iconFiles.reversed())
                }
                return names
            }
    }

    private static func iconFileCandidates(for baseName: String) -> [String] {
        [
            "\(baseName)@3x~ipad",
            "\(baseName)@2x~ipad",
            "\(baseName)~ipad",
            "\(baseName)@3x",
            "\(baseName)@2x",
            baseName
        ]
    }
    #endif
}
