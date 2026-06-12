#if os(iOS)
import SwiftUI
import UIKit

struct NativeToolbarMenuButton: UIViewRepresentable {
    let systemImage: String
    let title: String?
    let accessibilityLabel: String
    let menu: NativeToolbarMenu
    let badgeText: String?
    let select: (String) -> Void

    init(
        systemImage: String,
        title: String? = nil,
        accessibilityLabel: String,
        menu: NativeToolbarMenu,
        badgeText: String? = nil,
        select: @escaping (String) -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.menu = menu
        self.badgeText = badgeText
        self.select = select
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = accessibilityLabel
        configure(button, coordinator: context.coordinator)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.select = select
        context.coordinator.menu = menu
        button.accessibilityLabel = accessibilityLabel
        configure(button, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(menu: menu, select: select)
    }

    private func configure(_ button: UIButton, coordinator: Coordinator) {
        let chrome = ButtonChrome(systemImage: systemImage, title: title, badgeText: badgeText)
        if coordinator.chrome != chrome {
            var configuration = UIButton.Configuration.borderless()
            configuration.image = UIImage(systemName: systemImage)
            configuration.title = title
            configuration.imagePlacement = .leading
            configuration.imagePadding = title == nil ? 0 : 6
            configuration.buttonSize = .medium
            configuration.cornerStyle = .capsule
            if badgeText != nil {
                configuration.contentInsets.trailing += 5
            }
            button.configuration = configuration
            coordinator.chrome = chrome
        }

        if button.clipsToBounds {
            button.clipsToBounds = false
        }
        if !button.showsMenuAsPrimaryAction {
            button.showsMenuAsPrimaryAction = true
        }
        coordinator.assignMenuIfNeeded(to: button, menu: menu)
        if coordinator.renderedBadgeText != badgeText {
            configureBadge(in: button)
            coordinator.renderedBadgeText = badgeText
        }
    }

    private func configureBadge(in button: UIButton) {
        button.viewWithTag(Self.badgeTag)?.removeFromSuperview()
        guard let badgeText else { return }

        let badge = UILabel()
        badge.tag = Self.badgeTag
        badge.text = badgeText
        badge.font = .monospacedDigitSystemFont(ofSize: 8, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = button.tintColor
        badge.textAlignment = .center
        badge.layer.cornerCurve = .continuous
        badge.layer.cornerRadius = 6.5
        badge.clipsToBounds = true
        badge.isAccessibilityElement = false
        badge.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
            badge.heightAnchor.constraint(equalToConstant: 13),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 13)
        ])
    }

    private static let badgeTag = 78_431

    struct ButtonChrome: Equatable {
        var systemImage: String
        var title: String?
        var badgeText: String?
    }

    @MainActor
    final class Coordinator: NSObject {
        var menu: NativeToolbarMenu
        var select: (String) -> Void
        var cachedMenuModel: NativeToolbarMenu?
        var cachedMenu: UIMenu?
        var assignedMenuModel: NativeToolbarMenu?
        var chrome: ButtonChrome?
        var renderedBadgeText: String?

        init(menu: NativeToolbarMenu, select: @escaping (String) -> Void) {
            self.menu = menu
            self.select = select
            super.init()
        }

        func renderedMenu(for menu: NativeToolbarMenu) -> UIMenu {
            if cachedMenuModel == menu, let cachedMenu {
                return cachedMenu
            }

            let renderedMenu = menu.uiMenu(coordinator: self)
            cachedMenuModel = menu
            cachedMenu = renderedMenu
            return renderedMenu
        }

        func assignMenuIfNeeded(to button: UIButton, menu: NativeToolbarMenu) {
            guard assignedMenuModel != menu else { return }

            // UIButton.menu is NSCopying; comparing the getter's object identity can
            // force redundant assignments during SwiftUI toolbar updates and dismiss
            // an open submenu.
            button.menu = renderedMenu(for: menu)
            assignedMenuModel = menu
        }
    }
}

struct NativeToolbarMenu: Equatable {
    let title: String
    let sections: [NativeToolbarMenuSection]

    init(
        title: String = "",
        sections: [NativeToolbarMenuSection]
    ) {
        self.title = title
        self.sections = sections
    }

    @MainActor
    func uiMenu(coordinator: NativeToolbarMenuButton.Coordinator) -> UIMenu {
        UIMenu(
            title: title,
            children: sections.flatMap { $0.uiElements(coordinator: coordinator) }
        )
    }
}

struct NativeToolbarMenuSection: Equatable {
    enum Presentation {
        case inline
        case palette
        case root
    }

    let title: String
    let items: [NativeToolbarMenuItem]
    let presentation: Presentation

    init(title: String = "", presentation: Presentation = .inline, items: [NativeToolbarMenuItem]) {
        self.title = title
        self.items = items
        self.presentation = presentation
    }

    @MainActor
    func uiElements(coordinator: NativeToolbarMenuButton.Coordinator) -> [UIMenuElement] {
        if presentation == .root {
            return items.map {
                $0.uiElement(coordinator: coordinator)
            }
        }
        return [uiMenu(coordinator: coordinator)]
    }

    @MainActor
    private func uiMenu(coordinator: NativeToolbarMenuButton.Coordinator) -> UIMenu {
        var options: UIMenu.Options = [.displayInline]
        if presentation == .palette {
            options.insert(.displayAsPalette)
        }

        let menu = UIMenu(
            title: title,
            subtitle: nil,
            image: nil,
            identifier: nil,
            options: options,
            preferredElementSize: presentation == .palette ? .medium : .automatic,
            children: items.map {
                $0.uiElement(
                    coordinator: coordinator,
                    prefersPaletteTitle: presentation == .palette
                )
            }
        )
        if presentation == .palette {
            let preferences = UIMenuDisplayPreferences()
            preferences.maximumNumberOfTitleLines = 2
            menu.displayPreferences = preferences
        }
        return menu
    }
}

enum NativeToolbarSubmenuPresentation: Equatable {
    case automatic
    case singleSelection

    var options: UIMenu.Options {
        switch self {
        case .automatic:
            return []
        case .singleSelection:
            return [.singleSelection]
        }
    }
}

indirect enum NativeToolbarMenuItem: Equatable {
    case action(
        id: String,
        title: String,
        systemImage: String,
        paletteTitle: String? = nil,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        isDestructive: Bool = false,
        keepsMenuPresented: Bool = false
    )
    case submenu(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        presentation: NativeToolbarSubmenuPresentation = .automatic,
        items: [NativeToolbarMenuItem]
    )

    @MainActor
    func uiElement(
        coordinator: NativeToolbarMenuButton.Coordinator,
        prefersPaletteTitle: Bool = false
    ) -> UIMenuElement {
        switch self {
        case .action(
            let id,
            let title,
            let systemImage,
            let paletteTitle,
            let isSelected,
            let isEnabled,
            let isDestructive,
            let keepsMenuPresented
        ):
            var attributes: UIMenuElement.Attributes = isEnabled ? [] : .disabled
            if isDestructive {
                attributes.insert(.destructive)
            }
            if keepsMenuPresented {
                attributes.insert(.keepsMenuPresented)
            }
            let action = UIAction(
                title: prefersPaletteTitle ? (paletteTitle ?? title) : title,
                image: UIImage(systemName: systemImage),
                identifier: UIAction.Identifier(id),
                attributes: attributes,
                state: isSelected ? .on : .off
            ) { _ in
                coordinator.select(id)
            }
            return action

        case .submenu(let title, let subtitle, let systemImage, let presentation, let items):
            return UIMenu(
                title: title,
                subtitle: subtitle,
                image: UIImage(systemName: systemImage),
                identifier: nil,
                options: presentation.options,
                children: items.map {
                    $0.uiElement(coordinator: coordinator)
                }
            )
        }
    }
}
#endif
