#if os(macOS)
import AppKit
import SwiftUI

/// Window styling utilities for custom titlebar and toolbar.
///
/// Provides AppKit-level window customization that SwiftUI's
/// `WindowGroup` can't match:
/// - Custom titlebar appearance
/// - Unified toolbar style
/// - Window background effects
/// - Traffic light positioning
enum WindowStyler {

    /// Apply a transparent titlebar with unified toolbar.
    static func applyTransparentTitlebar(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
    }

    /// Apply a unified toolbar style.
    static func applyUnifiedToolbar(_ window: NSWindow) {
        window.toolbar?.displayMode = .iconOnly
    }

    /// Set the window background to be vibrant.
    static func applyVibrantBackground(_ window: NSWindow) {
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .underWindowBackground
        visualEffect.state = .followsWindowActiveState
        window.contentView = visualEffect
    }

    /// Center the traffic light buttons vertically.
    static func centerTrafficLights(_ window: NSWindow, yOffset: CGFloat = 0) {
        guard let titlebarContainer = window.contentView?.superview?.subviews.first(where: {
            String(describing: type(of: $0)).contains("TitlebarContainer")
        }) else { return }

        for button in titlebarContainer.subviews where button is NSButton {
            button.frame.origin.y = yOffset
        }
    }

    /// Set a custom minimum window size.
    static func setMinimumSize(_ window: NSWindow, width: CGFloat, height: CGFloat) {
        window.contentMinSize = NSSize(width: width, height: height)
    }

    /// Enable window restoration.
    static func enableRestoration(_ window: NSWindow, identifier: String) {
        window.isRestorable = true
        window.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    /// Set the window to appear in the center of the screen.
    static func centerOnScreen(_ window: NSWindow) {
        window.center()
    }

    /// Enable tabbing for the window.
    static func enableTabbing(_ window: NSWindow) {
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "com.keipix.main"
    }

    /// Set the window's title visibility.
    static func setTitleVisibility(_ window: NSWindow, visible: Bool) {
        window.titleVisibility = visible ? .visible : .hidden
    }

    /// Apply a custom titlebar accessory (e.g., search field).
    static func addTitlebarAccessory(_ window: NSWindow, view: NSView, height: CGFloat = 32) {
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = view
        accessory.layoutAttribute = .right
        window.addTitlebarAccessoryViewController(accessory)
    }
}

// MARK: - SwiftUI modifier

/// View modifier that applies window styling via NSWindow.
struct WindowStylerModifier: ViewModifier {
    let transparentTitlebar: Bool
    let unifiedToolbar: Bool
    let vibrantBackground: Bool

    func body(content: Content) -> some View {
        content
            .background {
                WindowStylerBackground(
                    transparentTitlebar: transparentTitlebar,
                    unifiedToolbar: unifiedToolbar,
                    vibrantBackground: vibrantBackground
                )
            }
    }
}

private struct WindowStylerBackground: NSViewRepresentable {
    let transparentTitlebar: Bool
    let unifiedToolbar: Bool
    let vibrantBackground: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if transparentTitlebar {
                WindowStyler.applyTransparentTitlebar(window)
            }
            if unifiedToolbar {
                WindowStyler.applyUnifiedToolbar(window)
            }
            if vibrantBackground {
                WindowStyler.applyVibrantBackground(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Apply custom window styling.
    func windowStyler(
        transparentTitlebar: Bool = false,
        unifiedToolbar: Bool = false,
        vibrantBackground: Bool = false
    ) -> some View {
        modifier(WindowStylerModifier(
            transparentTitlebar: transparentTitlebar,
            unifiedToolbar: unifiedToolbar,
            vibrantBackground: vibrantBackground
        ))
    }
}
#endif
