#if os(macOS)
import AppKit
import SwiftUI

/// NSMenu wrapper with custom view-based menu items.
///
/// Provides richer menu items than SwiftUI's `Menu`:
/// - Custom view-based items (images, progress bars, badges)
/// - Dynamic menu updates
/// - Better keyboard shortcut display
/// - Section headers with custom styling
struct EnhancedMenuNSView: NSViewRepresentable {
    let sections: [MenuSection]
    let onItemSelected: (MenuItem) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let button = NSButton()
        button.bezelStyle = .recessed
        button.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Menu")
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        button.frame = NSRect(x: 0, y: 0, width: 28, height: 28)
        view.addSubview(button)
        view.frame = NSRect(x: 0, y: 0, width: 28, height: 28)

        context.coordinator.button = button
        context.coordinator.menu = buildMenu(target: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.menu = buildMenu(target: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onItemSelected: onItemSelected)
    }

    private func buildMenu(target: Coordinator) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for section in sections {
            if let title = section.title {
                let headerItem = NSMenuItem()
                headerItem.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
                headerItem.isEnabled = false
                menu.addItem(headerItem)
            }

            for item in section.items {
                let menuItem = NSMenuItem(
                    title: item.title,
                    action: #selector(Coordinator.handleItem(_:)),
                    keyEquivalent: item.keyEquivalent
                )
                menuItem.target = target
                menuItem.image = item.icon
                menuItem.isEnabled = item.isEnabled
                menuItem.representedObject = item
                menu.addItem(menuItem)
            }

            menu.addItem(.separator())
        }

        return menu
    }

    @MainActor
    class Coordinator: NSObject {
        let onItemSelected: (MenuItem) -> Void
        var button: NSButton?
        var menu: NSMenu?

        init(onItemSelected: @escaping (MenuItem) -> Void) {
            self.onItemSelected = onItemSelected
        }

        @objc func showMenu(_ sender: NSButton) {
            guard let menu else { return }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.frame.height), in: sender)
        }

        @objc func handleItem(_ sender: NSMenuItem) {
            guard let item = sender.representedObject as? MenuItem else { return }
            onItemSelected(item)
        }
    }
}

// MARK: - Models

struct MenuSection {
    let title: String?
    let items: [MenuItem]
}

struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: NSImage?
    let keyEquivalent: String
    let isEnabled: Bool
    let action: MenuAction

    init(
        title: String,
        icon: NSImage? = nil,
        keyEquivalent: String = "",
        isEnabled: Bool = true,
        action: MenuAction = .custom
    ) {
        self.title = title
        self.icon = icon
        self.keyEquivalent = keyEquivalent
        self.isEnabled = isEnabled
        self.action = action
    }
}

enum MenuAction {
    case custom
    case copy
    case share
    case download
    case bookmark
    case mute
    case delete
    case startCreatorSelection
    case selectAllVisibleCreators
    case clearCreatorSelection
}

// MARK: - SwiftUI wrapper

/// SwiftUI view that uses NSMenu for richer menu items.
struct EnhancedMenu: View {
    let sections: [MenuSection]
    let onItemSelected: (MenuItem) -> Void

    var body: some View {
        EnhancedMenuNSView(
            sections: sections,
            onItemSelected: onItemSelected
        )
        .frame(width: 28, height: 28)
    }
}
#endif
