#if os(iOS)
import SwiftUI
import UIKit

struct NativeToolbarMenuButton: UIViewRepresentable {
    let systemImage: String
    let title: String?
    let accessibilityLabel: String
    let menu: NativeToolbarMenu
    let select: (String) -> Void

    init(
        systemImage: String,
        title: String? = nil,
        accessibilityLabel: String,
        menu: NativeToolbarMenu,
        select: @escaping (String) -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.menu = menu
        self.select = select
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.preferredBehavioralStyle = .pad
        button.accessibilityLabel = accessibilityLabel
        configure(button, coordinator: context.coordinator)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.select = select
        button.accessibilityLabel = accessibilityLabel
        configure(button, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(select: select)
    }

    private func configure(_ button: UIButton, coordinator: Coordinator) {
        var configuration = UIButton.Configuration.borderless()
        configuration.image = UIImage(systemName: systemImage)
        configuration.title = title
        configuration.imagePlacement = .leading
        configuration.imagePadding = title == nil ? 0 : 6
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        button.configuration = configuration
        button.menu = menu.uiMenu(coordinator: coordinator)
    }

    @MainActor
    final class Coordinator {
        var select: (String) -> Void

        init(select: @escaping (String) -> Void) {
            self.select = select
        }
    }
}

struct NativeToolbarMenu {
    let title: String
    let sections: [NativeToolbarMenuSection]

    init(title: String = "", sections: [NativeToolbarMenuSection]) {
        self.title = title
        self.sections = sections
    }

    @MainActor
    func uiMenu(coordinator: NativeToolbarMenuButton.Coordinator) -> UIMenu {
        UIMenu(
            title: title,
            children: sections.map { $0.uiMenu(coordinator: coordinator) }
        )
    }
}

struct NativeToolbarMenuSection {
    let title: String
    let items: [NativeToolbarMenuItem]

    init(title: String = "", items: [NativeToolbarMenuItem]) {
        self.title = title
        self.items = items
    }

    @MainActor
    func uiMenu(coordinator: NativeToolbarMenuButton.Coordinator) -> UIMenu {
        UIMenu(
            title: title,
            options: .displayInline,
            children: items.map { $0.uiElement(coordinator: coordinator) }
        )
    }
}

enum NativeToolbarMenuItem {
    case action(
        id: String,
        title: String,
        systemImage: String,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        isDestructive: Bool = false
    )
    case submenu(
        title: String,
        systemImage: String,
        items: [NativeToolbarMenuItem]
    )

    @MainActor
    func uiElement(coordinator: NativeToolbarMenuButton.Coordinator) -> UIMenuElement {
        switch self {
        case .action(let id, let title, let systemImage, let isSelected, let isEnabled, let isDestructive):
            let action = UIAction(
                title: title,
                image: UIImage(systemName: systemImage),
                identifier: UIAction.Identifier(id),
                attributes: isEnabled ? (isDestructive ? .destructive : []) : .disabled,
                state: isSelected ? .on : .off
            ) { _ in
                coordinator.select(id)
            }
            return action

        case .submenu(let title, let systemImage, let items):
            return UIMenu(
                title: title,
                image: UIImage(systemName: systemImage),
                children: items.map { $0.uiElement(coordinator: coordinator) }
            )
        }
    }
}
#endif
