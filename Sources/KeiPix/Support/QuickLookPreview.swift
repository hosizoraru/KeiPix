#if os(macOS)
import AppKit
import Quartz
import SwiftUI

/// Quick Look preview for artwork images on macOS.
///
/// Wraps QLPreviewPanel to show a full-size preview of the selected
/// artwork when the user presses Space bar. Follows the same
/// pattern as Finder's Quick Look.
struct QuickLookPreviewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let previewItems: [QuickLookItem]

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) {
                if previewItems.isEmpty == false {
                    isPresented.toggle()
                }
                return .handled
            }
            .background {
                if isPresented {
                    QuickLookPanelController(
                        isPresented: $isPresented,
                        items: previewItems
                    )
                }
            }
    }
}

/// Data source for Quick Look preview.
struct QuickLookItem: Identifiable {
    let id: Int
    let title: String
    let url: URL?
    let image: PlatformImage?

    var previewItemURL: URL? { url }
    var previewItemTitle: String? { title }
}

/// NSViewController that manages the QLPreviewPanel.
private struct QuickLookPanelController: NSViewControllerRepresentable {
    @Binding var isPresented: Bool
    let items: [QuickLookItem]

    func makeNSViewController(context: Context) -> QuickLookPanelHostingController {
        let controller = QuickLookPanelHostingController()
        controller.items = items
        controller.isPresented = $isPresented
        return controller
    }

    func updateNSViewController(_ nsViewController: QuickLookPanelHostingController, context: Context) {
        nsViewController.items = items
        nsViewController.isPresented = $isPresented
        if isPresented {
            nsViewController.showPanel()
        } else {
            nsViewController.hidePanel()
        }
    }
}

@MainActor
private class QuickLookPanelHostingController: NSViewController, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    var items: [QuickLookItem] = []
    var isPresented: Binding<Bool> = .constant(false)

    override func loadView() {
        view = NSView()
    }

    func showPanel() {
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        QLPreviewPanel.shared()?.orderOut(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int {
        items.count
    }

    func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> any QLPreviewItem {
        let item = items[index]
        if let url = item.url {
            return url as QLPreviewItem
        }
        // For in-memory images, write to a temp file
        if let image = item.image, let tiffData = image.tiffRepresentation {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("keipix-quicklook-\(item.id).tiff")
            try? tiffData.write(to: tempURL)
            return tempURL as QLPreviewItem
        }
        return NSURL(string: "about:blank")! as QLPreviewItem
    }

    // MARK: - QLPreviewPanelDelegate

    func previewPanel(_ panel: QLPreviewPanel, handle event: NSEvent) -> Bool {
        if event.type == .keyDown, event.keyCode == 49 { // Space
            isPresented.wrappedValue = false
            return true
        }
        return false
    }
}

extension View {
    /// Present Quick Look preview on Space bar press (macOS only).
    func quickLookPreview(isPresented: Binding<Bool>, items: [QuickLookItem]) -> some View {
        modifier(QuickLookPreviewModifier(isPresented: isPresented, previewItems: items))
    }
}
#endif
