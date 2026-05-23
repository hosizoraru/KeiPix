import AppKit
import SwiftUI

struct WindowCaptureProtectionBridge: NSViewRepresentable {
    let isProtected: Bool

    func makeNSView(context: Context) -> NSView {
        CaptureProtectionView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.sharingType = isProtected ? .none : .readOnly
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        nsView.window?.sharingType = .readOnly
    }
}

private final class CaptureProtectionView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        isHidden = true
    }
}
