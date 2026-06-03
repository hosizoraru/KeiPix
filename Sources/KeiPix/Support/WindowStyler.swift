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
@MainActor
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
        Task { @MainActor in
            apply(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            apply(to: nsView.window)
        }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
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
}

struct MainWindowSizingModifier: ViewModifier {
    let minimumWidth: CGFloat
    let minimumHeight: CGFloat
    let preferredDefaultSize: CGSize

    func body(content: Content) -> some View {
        content
            .background {
                MainWindowSizingBridge(
                    minimumSize: CGSize(width: minimumWidth, height: minimumHeight),
                    preferredDefaultSize: preferredDefaultSize
                )
            }
    }
}

private struct MainWindowSizingBridge: NSViewRepresentable {
    let minimumSize: CGSize
    let preferredDefaultSize: CGSize

    func makeNSView(context: Context) -> MainWindowSizingHostView {
        MainWindowSizingHostView(
            minimumSize: minimumSize,
            preferredDefaultSize: preferredDefaultSize
        )
    }

    func updateNSView(_ nsView: MainWindowSizingHostView, context: Context) {
        nsView.update(
            minimumSize: minimumSize,
            preferredDefaultSize: preferredDefaultSize
        )
    }
}

@MainActor
private final class MainWindowSizingHostView: NSView {
    private var minimumSize: CGSize
    private var preferredDefaultSize: CGSize
    private var didApplyInitialComfortSize = false

    init(minimumSize: CGSize, preferredDefaultSize: CGSize) {
        self.minimumSize = minimumSize
        self.preferredDefaultSize = preferredDefaultSize
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MainWindowSizingHostView does not support decoding")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleApply()
    }

    func update(minimumSize: CGSize, preferredDefaultSize: CGSize) {
        self.minimumSize = minimumSize
        self.preferredDefaultSize = preferredDefaultSize
        scheduleApply()
    }

    private func scheduleApply() {
        Task { @MainActor [weak self] in
            self?.applySizing()
        }
    }

    private func applySizing() {
        guard let window else { return }
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        let maximumContentSize = window.contentRect(forFrameRect: visibleFrame).size
        let effectiveMinimum = CGSize(
            width: min(minimumSize.width, maximumContentSize.width),
            height: min(minimumSize.height, maximumContentSize.height)
        )
        window.contentMinSize = NSSize(width: effectiveMinimum.width, height: effectiveMinimum.height)

        let targetBaseline = didApplyInitialComfortSize ? effectiveMinimum : CGSize(
            width: min(max(preferredDefaultSize.width, effectiveMinimum.width), maximumContentSize.width),
            height: min(max(preferredDefaultSize.height, effectiveMinimum.height), maximumContentSize.height)
        )
        let contentFrame = window.contentLayoutRect
        defer { didApplyInitialComfortSize = true }

        guard contentFrame.width < targetBaseline.width || contentFrame.height < targetBaseline.height else {
            return
        }

        let nextFrame = fittedFrame(
            for: window,
            targetContentSize: targetBaseline,
            visibleFrame: visibleFrame
        )
        window.setFrame(nextFrame, display: true, animate: false)
    }

    private func fittedFrame(
        for window: NSWindow,
        targetContentSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let targetFrameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: targetContentSize)).size
        let currentFrame = window.frame
        let width = min(targetFrameSize.width, visibleFrame.width)
        let height = min(targetFrameSize.height, visibleFrame.height)
        var nextFrame = CGRect(origin: currentFrame.origin, size: CGSize(width: width, height: height))
        nextFrame.origin.x = currentFrame.midX - width / 2
        nextFrame.origin.y = currentFrame.maxY - height
        nextFrame.origin.x = nextFrame.origin.x.clamped(to: visibleFrame.minX...(visibleFrame.maxX - width))
        nextFrame.origin.y = nextFrame.origin.y.clamped(to: visibleFrame.minY...(visibleFrame.maxY - height))
        return nextFrame
    }
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

    func mainWindowSizing(
        minimumWidth: CGFloat,
        minimumHeight: CGFloat,
        preferredDefaultSize: CGSize
    ) -> some View {
        modifier(MainWindowSizingModifier(
            minimumWidth: minimumWidth,
            minimumHeight: minimumHeight,
            preferredDefaultSize: preferredDefaultSize
        ))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
