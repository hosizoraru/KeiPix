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
        button.changesSelectionAsPrimaryAction = false
        button.preferredBehavioralStyle = .pad
        button.accessibilityLabel = accessibilityLabel
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.presentPopoverMenu(_:)),
            for: .primaryActionTriggered
        )
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
        var configuration = UIButton.Configuration.borderless()
        configuration.image = UIImage(systemName: systemImage)
        configuration.title = title
        configuration.imagePlacement = .leading
        configuration.imagePadding = title == nil ? 0 : 6
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        button.configuration = configuration

        switch menu.presentationStyle {
        case .system:
            button.showsMenuAsPrimaryAction = true
            button.menu = menu.uiMenu(coordinator: coordinator)
        case .popover:
            button.showsMenuAsPrimaryAction = false
            button.menu = nil
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var menu: NativeToolbarMenu
        var select: (String) -> Void

        init(menu: NativeToolbarMenu, select: @escaping (String) -> Void) {
            self.menu = menu
            self.select = select
            super.init()
        }

        @objc
        func presentPopoverMenu(_ sender: UIButton) {
            guard menu.presentationStyle == .popover,
                  let presenter = sender.window?.rootViewController?.topmostPresentedViewController else {
                return
            }

            let controller = NativeToolbarMenuPopoverController(menu: menu) { [weak self] id in
                self?.select(id)
            }
            controller.modalPresentationStyle = .popover

            if let popover = controller.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
                popover.permittedArrowDirections = [.up, .down]
            }

            presenter.present(controller, animated: true)
        }
    }
}

struct NativeToolbarMenu {
    enum PresentationStyle {
        case system
        case popover
    }

    let title: String
    let presentationStyle: PresentationStyle
    let sections: [NativeToolbarMenuSection]

    init(
        title: String = "",
        presentationStyle: PresentationStyle = .system,
        sections: [NativeToolbarMenuSection]
    ) {
        self.title = title
        self.presentationStyle = presentationStyle
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
    enum Presentation {
        case inline
        case palette
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
    func uiMenu(coordinator: NativeToolbarMenuButton.Coordinator) -> UIMenu {
        var options: UIMenu.Options = [.displayInline]
        if presentation == .palette {
            options.insert(.displayAsPalette)
        }

        let menu = UIMenu(
            title: title,
            options: options,
            children: items.map { $0.uiElement(coordinator: coordinator) }
        )
        if presentation == .palette {
            menu.preferredElementSize = .large
        }
        return menu
    }
}

enum NativeToolbarMenuItem {
    case action(
        id: String,
        title: String,
        systemImage: String,
        paletteTitle: String? = nil,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        isDestructive: Bool = false
    )
    case submenu(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        items: [NativeToolbarMenuItem]
    )

    @MainActor
    func uiElement(coordinator: NativeToolbarMenuButton.Coordinator) -> UIMenuElement {
        switch self {
        case .action(let id, let title, let systemImage, _, let isSelected, let isEnabled, let isDestructive):
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

        case .submenu(let title, let subtitle, let systemImage, let items):
            let menu = UIMenu(
                title: title,
                image: UIImage(systemName: systemImage),
                children: items.map { $0.uiElement(coordinator: coordinator) }
            )
            menu.subtitle = subtitle
            return menu
        }
    }

    fileprivate var actionPayload: NativeToolbarMenuActionPayload? {
        switch self {
        case .action(let id, let title, let systemImage, let paletteTitle, let isSelected, let isEnabled, let isDestructive):
            NativeToolbarMenuActionPayload(
                id: id,
                title: title,
                paletteTitle: paletteTitle,
                systemImage: systemImage,
                isSelected: isSelected,
                isEnabled: isEnabled,
                isDestructive: isDestructive
            )
        case .submenu:
            nil
        }
    }

    fileprivate var submenuPayload: NativeToolbarMenuSubmenuPayload? {
        switch self {
        case .submenu(let title, let subtitle, let systemImage, let items):
            NativeToolbarMenuSubmenuPayload(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                items: items
            )
        case .action:
            nil
        }
    }
}

private struct NativeToolbarMenuActionPayload {
    let id: String
    let title: String
    let paletteTitle: String?
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let isDestructive: Bool
}

private struct NativeToolbarMenuSubmenuPayload {
    let title: String
    let subtitle: String?
    let systemImage: String
    let items: [NativeToolbarMenuItem]
}

private final class NativeToolbarMenuPopoverController: UIViewController {
    private let menu: NativeToolbarMenu
    private let select: (String) -> Void
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(menu: NativeToolbarMenu, select: @escaping (String) -> Void) {
        self.menu = menu
        self.select = select
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .popover
        preferredContentSize = CGSize(width: 360, height: 620)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        render(title: menu.title, sections: menu.sections, showsBackButton: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let contentHeight = scrollView.contentSize.height + 20
        preferredContentSize = CGSize(
            width: 360,
            height: min(700, max(260, contentHeight))
        )
    }

    private func configureView() {
        view.backgroundColor = .clear

        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = 28
        view.addSubview(effectView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = true
        effectView.contentView.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: effectView.contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -18),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -18),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -36)
        ])
    }

    private func render(
        title: String,
        sections: [NativeToolbarMenuSection],
        showsBackButton: Bool
    ) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if showsBackButton {
            stackView.addArrangedSubview(backButton())
        }

        if title.isEmpty == false {
            stackView.addArrangedSubview(sectionHeader(title))
        }

        for (index, section) in sections.enumerated() {
            if section.title.isEmpty == false {
                stackView.addArrangedSubview(sectionHeader(section.title))
            }

            switch section.presentation {
            case .palette:
                let actions = section.items.compactMap(\.actionPayload)
                if actions.isEmpty == false {
                    stackView.addArrangedSubview(quickActionRow(actions))
                }
            case .inline:
                section.items.forEach { item in
                    stackView.addArrangedSubview(row(for: item))
                }
            }

            if index < sections.indices.last ?? 0 {
                stackView.addArrangedSubview(separator())
            }
        }

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func backButton() -> UIView {
        NativeToolbarMenuRowControl(
            title: L10n.goBack,
            subtitle: nil,
            systemImage: "chevron.left",
            isSelected: false,
            isEnabled: true,
            isDestructive: false,
            showsChevron: false
        ) { [weak self] in
            guard let self else { return }
            render(title: menu.title, sections: menu.sections, showsBackButton: false)
        }
    }

    private func sectionHeader(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }

    private func quickActionRow(_ actions: [NativeToolbarMenuActionPayload]) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .fill
        row.distribution = .fillEqually
        row.spacing = 8

        actions.forEach { action in
            row.addArrangedSubview(quickActionButton(action))
        }
        return row
    }

    private func quickActionButton(_ action: NativeToolbarMenuActionPayload) -> UIView {
        NativeToolbarMenuQuickActionControl(action: action) { [weak self] in
            self?.performAction(action.id)
        }
    }

    private func row(for item: NativeToolbarMenuItem) -> UIView {
        if let action = item.actionPayload {
            return NativeToolbarMenuRowControl(
                title: action.title,
                subtitle: nil,
                systemImage: action.systemImage,
                isSelected: action.isSelected,
                isEnabled: action.isEnabled,
                isDestructive: action.isDestructive,
                showsChevron: false
            ) { [weak self] in
                self?.performAction(action.id)
            }
        }

        if let submenu = item.submenuPayload {
            return NativeToolbarMenuRowControl(
                title: submenu.title,
                subtitle: submenu.subtitle,
                systemImage: submenu.systemImage,
                isSelected: false,
                isEnabled: true,
                isDestructive: false,
                showsChevron: true
            ) { [weak self] in
                let section = NativeToolbarMenuSection(items: submenu.items)
                self?.render(title: submenu.title, sections: [section], showsBackButton: true)
            }
        }

        return UIView()
    }

    private func separator() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func performAction(_ id: String) {
        select(id)
        dismiss(animated: true)
    }
}

private final class NativeToolbarMenuQuickActionControl: UIControl {
    private let handler: () -> Void
    private let background = UIView()

    init(action: NativeToolbarMenuActionPayload, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        isEnabled = action.isEnabled
        setup(action: action)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            background.backgroundColor = isHighlighted ? .tertiarySystemFill : .secondarySystemFill
        }
    }

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1 : 0.45
        }
    }

    override func accessibilityActivate() -> Bool {
        trigger()
        return true
    }

    private func setup(action: NativeToolbarMenuActionPayload) {
        layer.cornerRadius = 18
        accessibilityLabel = action.title
        accessibilityTraits = action.isSelected ? [.button, .selected] : [.button]

        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = .secondarySystemFill
        background.layer.cornerRadius = 18
        background.isUserInteractionEnabled = false
        addSubview(background)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 7
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let foreground = foregroundColor(for: action)

        let imageView = UIImageView(image: UIImage(systemName: action.systemImage))
        imageView.tintColor = foreground
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(imageView)

        let titleLabel = UILabel()
        titleLabel.text = action.paletteTitle ?? action.title
        titleLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: UIFont.systemFont(ofSize: 13, weight: .semibold)
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = foreground
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 2
        stack.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            imageView.widthAnchor.constraint(equalToConstant: 25),
            imageView.heightAnchor.constraint(equalToConstant: 25),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 84)
        ])

        addTarget(self, action: #selector(trigger), for: .touchUpInside)
    }

    @objc
    private func trigger() {
        guard isEnabled else { return }
        handler()
    }

    private func foregroundColor(for action: NativeToolbarMenuActionPayload) -> UIColor {
        if action.isEnabled == false {
            return .tertiaryLabel
        }
        return action.isDestructive ? .systemRed : .label
    }
}

private final class NativeToolbarMenuRowControl: UIControl {
    private let handler: () -> Void
    private let background = UIView()

    init(
        title: String,
        subtitle: String?,
        systemImage: String,
        isSelected: Bool,
        isEnabled: Bool,
        isDestructive: Bool,
        showsChevron: Bool,
        handler: @escaping () -> Void
    ) {
        self.handler = handler
        super.init(frame: .zero)
        self.isEnabled = isEnabled
        setup(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            isSelected: isSelected,
            isDestructive: isDestructive,
            showsChevron: showsChevron
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            background.backgroundColor = isHighlighted ? .tertiarySystemFill : .clear
        }
    }

    private func setup(
        title: String,
        subtitle: String?,
        systemImage: String,
        isSelected: Bool,
        isDestructive: Bool,
        showsChevron: Bool
    ) {
        layer.cornerRadius = 14
        accessibilityLabel = title
        accessibilityTraits = isSelected ? [.button, .selected] : [.button]

        background.translatesAutoresizingMaskIntoConstraints = false
        background.layer.cornerRadius = 14
        background.isUserInteractionEnabled = false
        addSubview(background)

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        let foreground = isDestructive ? UIColor.systemRed : UIColor.label
        let secondaryForeground = isDestructive ? UIColor.systemRed : UIColor.secondaryLabel

        let checkView = UIImageView(image: isSelected ? UIImage(systemName: "checkmark") : nil)
        checkView.tintColor = foreground
        checkView.contentMode = .scaleAspectFit
        checkView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        row.addArrangedSubview(checkView)

        let iconView = UIImageView(image: UIImage(systemName: systemImage))
        iconView.tintColor = foreground
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 26).isActive = true
        row.addArrangedSubview(iconView)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 1
        row.addArrangedSubview(textStack)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = foreground
        titleLabel.numberOfLines = 2
        textStack.addArrangedSubview(titleLabel)

        if let subtitle, subtitle.isEmpty == false {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
            subtitleLabel.adjustsFontForContentSizeCategory = true
            subtitleLabel.textColor = secondaryForeground
            subtitleLabel.numberOfLines = 1
            textStack.addArrangedSubview(subtitleLabel)
        }

        if showsChevron {
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevron.tintColor = .tertiaryLabel
            chevron.contentMode = .scaleAspectFit
            chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true
            row.addArrangedSubview(chevron)
        }

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])

        if isEnabled == false {
            alpha = 0.45
        }

        addTarget(self, action: #selector(trigger), for: .touchUpInside)
    }

    override func accessibilityActivate() -> Bool {
        trigger()
        return true
    }

    @objc
    private func trigger() {
        guard isEnabled else { return }
        handler()
    }
}

private extension UIViewController {
    var topmostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topmostPresentedViewController
        }
        if let navigationController = self as? UINavigationController,
           let visible = navigationController.visibleViewController {
            return visible.topmostPresentedViewController
        }
        if let tabBarController = self as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return selected.topmostPresentedViewController
        }
        return self
    }
}
#endif
