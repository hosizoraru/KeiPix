#if os(iOS)
import SwiftUI
import UIKit

struct TabBarMinimizeBehaviorBridge: UIViewControllerRepresentable {
    let behavior: UITabBarController.MinimizeBehavior
    let isTabBarHidden: Bool
    let usesTransparentBackground: Bool
    let chromeMaterialMode: ChromeMaterialMode
    let scrollsToTopOnCurrentTabReselection: Bool
    let syncID: String
    let tabBarGeometry: Binding<TabBarGeometrySnapshot?>? = nil

    func makeUIViewController(context: Context) -> Controller {
        Controller(
            behavior: behavior,
            isTabBarHidden: isTabBarHidden,
            usesTransparentBackground: usesTransparentBackground,
            chromeMaterialMode: chromeMaterialMode,
            scrollsToTopOnCurrentTabReselection: scrollsToTopOnCurrentTabReselection,
            syncID: syncID,
            onGeometryChange: { geometry in
                tabBarGeometry?.wrappedValue = geometry
            }
        )
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onGeometryChange = { geometry in
            tabBarGeometry?.wrappedValue = geometry
        }
        if controller.behavior != behavior {
            controller.behavior = behavior
        }
        if controller.isTabBarHidden != isTabBarHidden {
            controller.isTabBarHidden = isTabBarHidden
        }
        if controller.usesTransparentBackground != usesTransparentBackground {
            controller.usesTransparentBackground = usesTransparentBackground
        }
        if controller.chromeMaterialMode != chromeMaterialMode {
            controller.chromeMaterialMode = chromeMaterialMode
        }
        if controller.scrollsToTopOnCurrentTabReselection != scrollsToTopOnCurrentTabReselection {
            controller.scrollsToTopOnCurrentTabReselection = scrollsToTopOnCurrentTabReselection
        }
        if controller.syncID != syncID {
            controller.syncID = syncID
        } else {
            controller.applyBehavior()
        }
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        private var hasDeferredApply = false
        private var hasAppliedTabBarState = false
        private weak var appliedTabBarController: UITabBarController?
        private weak var appliedReselectionTabBar: UITabBar?
        private var reselectionGestureRecognizer: CurrentTabReselectionGestureRecognizer?
        private var pendingReapplyTask: Task<Void, Never>?
        private var lastAppliedBehavior: UITabBarController.MinimizeBehavior?
        private var lastAppliedTabBarHidden: Bool?
        private var lastAppliedTransparentBackground: Bool?
        private var lastAppliedChromeMaterialMode: ChromeMaterialMode?
        private var lastPublishedGeometry: TabBarGeometrySnapshot?
        var onGeometryChange: (TabBarGeometrySnapshot?) -> Void

        var behavior: UITabBarController.MinimizeBehavior {
            didSet {
                applyBehavior()
            }
        }

        var isTabBarHidden: Bool {
            didSet {
                applyBehavior()
            }
        }

        var usesTransparentBackground: Bool {
            didSet {
                applyBehavior()
            }
        }

        var chromeMaterialMode: ChromeMaterialMode {
            didSet {
                applyBehavior()
            }
        }

        var scrollsToTopOnCurrentTabReselection: Bool {
            didSet {
                applyBehavior()
            }
        }

        var syncID: String {
            didSet {
                applyBehavior()
                scheduleDeferredReapply()
            }
        }

        init(
            behavior: UITabBarController.MinimizeBehavior,
            isTabBarHidden: Bool,
            usesTransparentBackground: Bool,
            chromeMaterialMode: ChromeMaterialMode,
            scrollsToTopOnCurrentTabReselection: Bool,
            syncID: String,
            onGeometryChange: @escaping (TabBarGeometrySnapshot?) -> Void
        ) {
            self.behavior = behavior
            self.isTabBarHidden = isTabBarHidden
            self.usesTransparentBackground = usesTransparentBackground
            self.chromeMaterialMode = chromeMaterialMode
            self.scrollsToTopOnCurrentTabReselection = scrollsToTopOnCurrentTabReselection
            self.syncID = syncID
            self.onGeometryChange = onGeometryChange
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("TabBarMinimizeBehaviorBridge does not support decoding")
        }

        override func loadView() {
            let view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyBehavior()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyBehavior()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyBehavior()
        }

        func applyBehavior() {
            guard let tabBarController = resolvedTabBarController() else {
                publishGeometry(nil)
                guard hasDeferredApply == false else { return }
                hasDeferredApply = true
                Task { @MainActor [weak self] in
                    self?.hasDeferredApply = false
                    self?.applyBehavior()
                }
                return
            }
            hasDeferredApply = false
            if appliedTabBarController !== tabBarController {
                appliedTabBarController = tabBarController
                lastAppliedBehavior = nil
                lastAppliedTabBarHidden = nil
                lastAppliedTransparentBackground = nil
                lastAppliedChromeMaterialMode = nil
            }
            applyAppearance(to: tabBarController.tabBar)
            syncSelectedTabContentScrollView()
            if lastAppliedBehavior != behavior || tabBarController.tabBarMinimizeBehavior != behavior {
                tabBarController.tabBarMinimizeBehavior = behavior
                lastAppliedBehavior = behavior
            }
            if lastAppliedTabBarHidden != isTabBarHidden || tabBarController.isTabBarHidden != isTabBarHidden {
                tabBarController.setTabBarHidden(isTabBarHidden, animated: hasAppliedTabBarState)
                lastAppliedTabBarHidden = isTabBarHidden
            }
            updateCurrentTabReselectionGesture(on: tabBarController.tabBar)
            publishGeometry(
                TabBarGeometrySnapshot(
                    tabBarFrame: tabBarController.tabBar.convert(tabBarController.tabBar.bounds, to: view),
                    selectedItemFrame: TabBarItemFrameResolver.selectedItemVisualFrame(in: tabBarController.tabBar).map {
                        tabBarController.tabBar.convert($0, to: view)
                    }
                )
            )
            hasAppliedTabBarState = true
        }

        private func scheduleDeferredReapply() {
            pendingReapplyTask?.cancel()
            pendingReapplyTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard Task.isCancelled == false else { return }
                self?.applyBehavior()
                try? await Task.sleep(for: .milliseconds(120))
                guard Task.isCancelled == false else { return }
                self?.applyBehavior()
            }
        }

        private func publishGeometry(_ geometry: TabBarGeometrySnapshot?) {
            guard geometry != lastPublishedGeometry else { return }
            lastPublishedGeometry = geometry
            onGeometryChange(geometry)
        }

        private func updateCurrentTabReselectionGesture(on tabBar: UITabBar) {
            guard scrollsToTopOnCurrentTabReselection else {
                removeCurrentTabReselectionGesture()
                return
            }

            if appliedReselectionTabBar === tabBar,
               reselectionGestureRecognizer != nil {
                return
            }

            removeCurrentTabReselectionGesture()
            let recognizer = CurrentTabReselectionGestureRecognizer(
                target: self,
                action: #selector(handleCurrentTabReselection(_:))
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            tabBar.addGestureRecognizer(recognizer)
            appliedReselectionTabBar = tabBar
            reselectionGestureRecognizer = recognizer
        }

        private func removeCurrentTabReselectionGesture() {
            if let recognizer = reselectionGestureRecognizer {
                appliedReselectionTabBar?.removeGestureRecognizer(recognizer)
            }
            appliedReselectionTabBar = nil
            reselectionGestureRecognizer = nil
        }

        @objc private func handleCurrentTabReselection(_ recognizer: CurrentTabReselectionGestureRecognizer) {
            guard recognizer.state == .ended,
                  recognizer.beganOnSelectedItem else {
                return
            }
            scrollSelectedTabContentToTop()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func scrollSelectedTabContentToTop() {
            guard let scrollView = selectedTabContentScrollView() else {
                return
            }

            scrollView.layoutIfNeeded()
            let target = CGPoint(
                x: scrollView.contentOffset.x,
                y: -scrollView.adjustedContentInset.top
            )
            guard abs(scrollView.contentOffset.y - target.y) > 1 else { return }
            scrollView.setContentOffset(target, animated: UIAccessibility.isReduceMotionEnabled == false)
        }

        private func selectedTabContentScrollView() -> UIScrollView? {
            guard let selectedViewController = appliedTabBarController?.selectedViewController else {
                return nil
            }
            if let scrollView = selectedViewController.firstRegisteredContentScrollView(for: .bottom) {
                return scrollView
            }
            if let scrollView = selectedViewController.view.firstVisibleVerticalScrollView(allowShortContent: true) {
                return scrollView
            }
            return appliedTabBarController?.view.firstVisibleVerticalScrollView(allowShortContent: true)
        }

        private func syncSelectedTabContentScrollView() {
            guard let selectedViewController = appliedTabBarController?.selectedViewController else {
                return
            }

            guard let scrollView = selectedTabContentScrollView() else {
                if selectedViewController.contentScrollView(for: .bottom) != nil {
                    selectedViewController.setContentScrollView(nil, for: .bottom)
                }
                return
            }

            configureScrollViewForBottomTabContent(scrollView)
            if selectedViewController.contentScrollView(for: .bottom) !== scrollView {
                selectedViewController.setContentScrollView(scrollView, for: .bottom)
            }
        }

        private func applyAppearance(to tabBar: UITabBar) {
            guard lastAppliedTransparentBackground != usesTransparentBackground ||
                  lastAppliedChromeMaterialMode != chromeMaterialMode else { return }

            let appearance = UITabBarAppearance()
            if chromeMaterialMode == .plain {
                appearance.configureWithTransparentBackground()
                appearance.backgroundEffect = nil
                appearance.backgroundColor = .clear
                appearance.shadowColor = .clear
                appearance.shadowImage = nil
                tabBar.isTranslucent = true
                tabBar.backgroundColor = .clear
            } else if usesTransparentBackground {
                appearance.configureWithTransparentBackground()
                switch chromeMaterialMode {
                case .liquidGlass:
                    appearance.backgroundEffect = nil
                    appearance.backgroundColor = .clear
                case .translucentBlur:
                    appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
                    appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.18)
                case .plain:
                    break
                }
                appearance.shadowColor = .clear
                appearance.shadowImage = nil
                tabBar.isTranslucent = true
                tabBar.backgroundColor = .clear
            } else {
                appearance.configureWithDefaultBackground()
                tabBar.isTranslucent = true
                tabBar.backgroundColor = nil
            }
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = (usesTransparentBackground || chromeMaterialMode == .plain) ? appearance : nil
            lastAppliedTransparentBackground = usesTransparentBackground
            lastAppliedChromeMaterialMode = chromeMaterialMode
        }

        private func resolvedTabBarController() -> UITabBarController? {
            if let tabBarController {
                return tabBarController
            }

            var ancestor = parent
            while let controller = ancestor {
                if let tabBarController = controller as? UITabBarController {
                    return tabBarController
                }
                ancestor = controller.parent
            }

            return view.window?.rootViewController?.firstTabBarController()
        }

        deinit {
            MainActor.assumeIsolated {
                pendingReapplyTask?.cancel()
                let tabBar = appliedReselectionTabBar
                let recognizer = reselectionGestureRecognizer
                if let recognizer {
                    tabBar?.removeGestureRecognizer(recognizer)
                }
            }
        }
    }
}

struct PhoneFeedFilterBarOverlayBridge: UIViewControllerRepresentable {
    @Binding var text: String
    let placeholder: String
    let resultText: String
    let isEnabled: Bool
    let chromeMaterialMode: ChromeMaterialMode
    let syncID: String

    func makeUIViewController(context: Context) -> Controller {
        Controller(
            text: $text,
            placeholder: placeholder,
            resultText: resultText,
            isEnabled: isEnabled,
            chromeMaterialMode: chromeMaterialMode,
            syncID: syncID
        )
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.text = $text
        controller.placeholder = placeholder
        controller.resultText = resultText
        controller.isEnabled = isEnabled
        controller.chromeMaterialMode = chromeMaterialMode
        controller.syncID = syncID
        controller.applyOverlay()
    }

    final class Controller: UIViewController, UITextFieldDelegate {
        var text: Binding<String>
        var placeholder: String
        var resultText: String
        var isEnabled: Bool
        var chromeMaterialMode: ChromeMaterialMode {
            didSet {
                if oldValue != chromeMaterialMode {
                    removeChrome()
                }
                scheduleDeferredLayout()
            }
        }
        var syncID: String {
            didSet {
                if oldValue != syncID {
                    isPanelPresented = false
                    filterField?.resignFirstResponder()
                }
                scheduleDeferredLayout()
            }
        }

        private weak var filterField: UITextField?
        private weak var pillControl: UIControl?
        private weak var pillIconView: UIImageView?
        private weak var pillLabel: UILabel?
        private var glassContainerView: UIView?
        private var pillView: UIVisualEffectView?
        private var panelView: UIVisualEffectView?
        private var isPanelPresented = false
        private weak var appliedTabBarController: UITabBarController?
        private var pendingLayoutTask: Task<Void, Never>?

        init(
            text: Binding<String>,
            placeholder: String,
            resultText: String,
            isEnabled: Bool,
            chromeMaterialMode: ChromeMaterialMode,
            syncID: String
        ) {
            self.text = text
            self.placeholder = placeholder
            self.resultText = resultText
            self.isEnabled = isEnabled
            self.chromeMaterialMode = chromeMaterialMode
            self.syncID = syncID
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("PhoneFeedFilterBarOverlayBridge does not support decoding")
        }

        override func loadView() {
            let view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyOverlay()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyOverlay()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyOverlay()
        }

        func applyOverlay() {
            guard isEnabled else {
                glassContainerView?.isHidden = true
                pillView?.isHidden = true
                panelView?.isHidden = true
                filterField?.resignFirstResponder()
                return
            }

            guard let tabBarController = resolvedTabBarController() else {
                removeChrome()
                scheduleDeferredLayout()
                return
            }

            let geometry = tabBarGeometry(in: tabBarController)
            ensureChrome(in: tabBarController)
            updateField()
            updatePill()
            guard let layout = PhoneFeedFilterChromeLayout.resolve(
                    containerSize: tabBarController.view.bounds.size,
                    tabBarGeometry: geometry,
                    preferredPillWidth: resolvedPillWidth()
                  ) else {
                glassContainerView?.isHidden = true
                pillView?.isHidden = true
                panelView?.isHidden = true
                return
            }

            apply(layout, in: tabBarController)
        }

        private func ensureChrome(in tabBarController: UITabBarController) {
            if glassContainerView != nil,
               pillView != nil,
               panelView != nil,
               appliedTabBarController === tabBarController {
                return
            }

            removeChrome()

            let glassContainerView = makeGlassContainer()
            glassContainerView.frame = tabBarController.view.bounds
            glassContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            glassContainerView.backgroundColor = .clear

            let pillView = makeGlassOverlay(
                cornerRadius: PhoneFeedFilterChromeLayout.pillHeight / 2,
                isInteractive: true,
                mode: chromeMaterialMode
            )
            let pillControl = UIControl(frame: .zero)
            pillControl.addTarget(self, action: #selector(showFilterPanel), for: .touchUpInside)
            pillControl.translatesAutoresizingMaskIntoConstraints = false
            pillControl.accessibilityTraits = .button

            let pillIconView = UIImageView(image: UIImage(
                systemName: "line.3.horizontal.decrease",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            ))
            pillIconView.contentMode = .center
            pillIconView.translatesAutoresizingMaskIntoConstraints = false

            let pillLabel = UILabel()
            pillLabel.font = .preferredFont(forTextStyle: .footnote)
            pillLabel.adjustsFontForContentSizeCategory = true
            pillLabel.adjustsFontSizeToFitWidth = true
            pillLabel.minimumScaleFactor = 0.86
            pillLabel.numberOfLines = 1
            pillLabel.textAlignment = .center
            pillLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            pillLabel.translatesAutoresizingMaskIntoConstraints = false

            let pillStack = UIStackView(arrangedSubviews: [pillIconView, pillLabel])
            pillStack.axis = .horizontal
            pillStack.alignment = .center
            pillStack.distribution = .fill
            pillStack.spacing = 6
            pillStack.isUserInteractionEnabled = false
            pillStack.translatesAutoresizingMaskIntoConstraints = false

            pillControl.addSubview(pillStack)
            pillView.contentView.addSubview(pillControl)
            NSLayoutConstraint.activate([
                pillControl.leadingAnchor.constraint(equalTo: pillView.contentView.leadingAnchor),
                pillControl.trailingAnchor.constraint(equalTo: pillView.contentView.trailingAnchor),
                pillControl.topAnchor.constraint(equalTo: pillView.contentView.topAnchor),
                pillControl.bottomAnchor.constraint(equalTo: pillView.contentView.bottomAnchor),
                pillStack.centerXAnchor.constraint(equalTo: pillControl.centerXAnchor),
                pillStack.centerYAnchor.constraint(equalTo: pillControl.centerYAnchor),
                pillStack.leadingAnchor.constraint(greaterThanOrEqualTo: pillControl.leadingAnchor, constant: 10),
                pillStack.trailingAnchor.constraint(lessThanOrEqualTo: pillControl.trailingAnchor, constant: -10),
                pillIconView.widthAnchor.constraint(equalToConstant: 16),
                pillIconView.heightAnchor.constraint(equalToConstant: 16)
            ])

            let panelView = makeGlassOverlay(
                cornerRadius: PhoneFeedFilterChromeLayout.panelHeight / 2,
                isInteractive: true,
                mode: chromeMaterialMode
            )
            let field = UITextField(frame: .zero)
            field.delegate = self
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.returnKeyType = .done
            field.borderStyle = .none
            field.backgroundColor = .clear
            field.textColor = .label
            field.tintColor = .label
            field.font = .preferredFont(forTextStyle: .subheadline)
            field.adjustsFontForContentSizeCategory = true
            field.clearButtonMode = .whileEditing
            field.leftView = searchIconView()
            field.leftViewMode = .always
            field.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
            field.translatesAutoresizingMaskIntoConstraints = false

            let closeButton = UIButton(type: .system)
            closeButton.setImage(
                UIImage(
                    systemName: "xmark.circle.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
                ),
                for: .normal
            )
            closeButton.tintColor = .tertiaryLabel
            closeButton.accessibilityLabel = L10n.close
            closeButton.addTarget(self, action: #selector(hideFilterPanel), for: .touchUpInside)
            closeButton.translatesAutoresizingMaskIntoConstraints = false

            panelView.contentView.addSubview(field)
            panelView.contentView.addSubview(closeButton)
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor, constant: 4),
                field.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
                field.centerYAnchor.constraint(equalTo: panelView.contentView.centerYAnchor),
                field.heightAnchor.constraint(equalToConstant: 36),
                closeButton.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor, constant: -8),
                closeButton.centerYAnchor.constraint(equalTo: panelView.contentView.centerYAnchor),
                closeButton.widthAnchor.constraint(equalToConstant: 32),
                closeButton.heightAnchor.constraint(equalToConstant: 32)
            ])

            tabBarController.view.addSubview(glassContainerView)
            glassContentView(in: glassContainerView).addSubview(pillView)
            glassContentView(in: glassContainerView).addSubview(panelView)
            self.glassContainerView = glassContainerView
            self.pillView = pillView
            self.panelView = panelView
            self.pillControl = pillControl
            self.pillIconView = pillIconView
            self.pillLabel = pillLabel
            filterField = field
            appliedTabBarController = tabBarController
            updateField()
            updatePill()
        }

        private func makeGlassContainer() -> UIView {
            if chromeMaterialMode == .liquidGlass, #available(iOS 26.0, *) {
                let effect = UIGlassContainerEffect()
                effect.spacing = 14
                let containerView = PassThroughVisualEffectView(effect: effect)
                containerView.isUserInteractionEnabled = true
                return containerView
            }

            let containerView = PassThroughView(frame: .zero)
            containerView.isUserInteractionEnabled = true
            return containerView
        }

        private func glassContentView(in containerView: UIView) -> UIView {
            (containerView as? UIVisualEffectView)?.contentView ?? containerView
        }

        private func makeGlassOverlay(
            cornerRadius: CGFloat,
            isInteractive: Bool,
            mode: ChromeMaterialMode
        ) -> UIVisualEffectView {
            let overlayView: UIVisualEffectView
            if mode == .liquidGlass, #available(iOS 26.0, *) {
                let glassEffect = UIGlassEffect(style: .regular)
                glassEffect.isInteractive = isInteractive
                glassEffect.tintColor = UIColor.secondarySystemBackground.withAlphaComponent(0.18)
                overlayView = UIVisualEffectView(effect: glassEffect)
            } else if mode == .translucentBlur {
                overlayView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
            } else {
                overlayView = UIVisualEffectView(effect: nil)
                overlayView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
            }
            overlayView.layer.cornerRadius = cornerRadius
            overlayView.layer.cornerCurve = .continuous
            overlayView.clipsToBounds = true
            overlayView.isUserInteractionEnabled = true
            overlayView.layer.borderWidth = 0.5
            overlayView.layer.borderColor = UIColor.separator.withAlphaComponent(0.18).cgColor
            overlayView.alpha = 0
            return overlayView
        }

        private func removeChrome() {
            glassContainerView?.removeFromSuperview()
            pillView?.removeFromSuperview()
            panelView?.removeFromSuperview()
            glassContainerView = nil
            pillView = nil
            panelView = nil
            pillControl = nil
            pillIconView = nil
            pillLabel = nil
            filterField = nil
            appliedTabBarController = nil
        }

        private func apply(_ layout: PhoneFeedFilterChromeLayout, in tabBarController: UITabBarController) {
            guard let pillView, let panelView else { return }
            glassContainerView?.frame = tabBarController.view.bounds
            glassContainerView?.isHidden = false

            let updates = {
                pillView.frame = layout.pillFrame
                panelView.frame = layout.panelFrame
                pillView.alpha = self.isPanelPresented ? 0 : 1
                panelView.alpha = self.isPanelPresented ? 1 : 0
                pillView.isHidden = self.isPanelPresented
                panelView.isHidden = self.isPanelPresented == false
            }

            if UIAccessibility.isReduceMotionEnabled {
                updates()
            } else {
                UIView.animate(
                    withDuration: 0.18,
                    delay: 0,
                    options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut],
                    animations: updates
                )
            }

            if let glassContainerView {
                tabBarController.view.bringSubviewToFront(glassContainerView)
            }
            glassContentView(in: glassContainerView ?? tabBarController.view).bringSubviewToFront(pillView)
            glassContentView(in: glassContainerView ?? tabBarController.view).bringSubviewToFront(panelView)
        }

        private func searchIconView() -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 32))
            container.isUserInteractionEnabled = false
            let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass", withConfiguration: configuration))
            iconView.tintColor = .secondaryLabel
            iconView.contentMode = .center
            iconView.frame = CGRect(x: 6, y: 0, width: 20, height: 32)
            container.addSubview(iconView)
            return container
        }

        private var hasActiveFilter: Bool {
            text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        private func updatePill() {
            let title = hasActiveFilter ? L10n.filtering : L10n.feedFilter
            pillLabel?.text = title
            pillLabel?.textColor = hasActiveFilter ? .systemBlue : .label
            pillIconView?.tintColor = hasActiveFilter ? .systemBlue : .secondaryLabel
            pillControl?.accessibilityLabel = title
            pillControl?.accessibilityValue = resultText
            configureGlassTint()
        }

        private func updateField() {
            filterField?.placeholder = placeholder
            filterField?.accessibilityLabel = placeholder
            filterField?.accessibilityValue = resultText
            if filterField?.text != text.wrappedValue {
                filterField?.text = text.wrappedValue
            }
            configureGlassTint()
        }

        private func configureGlassTint() {
            guard chromeMaterialMode == .liquidGlass, #available(iOS 26.0, *) else {
                let activeTint = UIColor.systemBlue.withAlphaComponent(0.12)
                let restingAlpha: CGFloat = chromeMaterialMode == .plain ? 0.92 : 0.34
                pillView?.backgroundColor = hasActiveFilter
                    ? activeTint
                    : UIColor.secondarySystemBackground.withAlphaComponent(restingAlpha)
                panelView?.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(
                    chromeMaterialMode == .plain ? 0.94 : 0.28
                )
                return
            }
            let activeTint = UIColor.systemBlue.withAlphaComponent(0.16)
            let restingTint = UIColor.secondarySystemBackground.withAlphaComponent(0.18)
            (pillView?.effect as? UIGlassEffect)?.tintColor = hasActiveFilter ? activeTint : restingTint
            (panelView?.effect as? UIGlassEffect)?.tintColor = UIColor.secondarySystemBackground.withAlphaComponent(0.22)
        }

        private func resolvedPillWidth() -> CGFloat {
            let labelWidth = pillLabel?.intrinsicContentSize.width ?? 0
            return 10 + 16 + 6 + labelWidth + 10
        }

        @objc private func editingChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
            updatePill()
        }

        @objc private func showFilterPanel() {
            guard isEnabled else { return }
            isPanelPresented = true
            applyOverlay()
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.filterField?.becomeFirstResponder()
            }
        }

        @objc private func hideFilterPanel() {
            isPanelPresented = false
            filterField?.resignFirstResponder()
            applyOverlay()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            self.text.wrappedValue = ""
            updatePill()
            return true
        }

        private func tabBarGeometry(in tabBarController: UITabBarController) -> TabBarGeometrySnapshot {
            let tabBar = tabBarController.tabBar
            return TabBarGeometrySnapshot(
                tabBarFrame: tabBar.convert(tabBar.bounds, to: tabBarController.view),
                selectedItemFrame: TabBarItemFrameResolver.selectedItemVisualFrame(in: tabBar).map {
                    tabBar.convert($0, to: tabBarController.view)
                }
            )
        }

        private func scheduleDeferredLayout() {
            pendingLayoutTask?.cancel()
            pendingLayoutTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard Task.isCancelled == false else { return }
                self?.applyOverlay()
                try? await Task.sleep(for: .milliseconds(120))
                guard Task.isCancelled == false else { return }
                self?.applyOverlay()
            }
        }

        private func resolvedTabBarController() -> UITabBarController? {
            if let tabBarController {
                return tabBarController
            }

            var ancestor = parent
            while let controller = ancestor {
                if let tabBarController = controller as? UITabBarController {
                    return tabBarController
                }
                ancestor = controller.parent
            }

            return view.window?.rootViewController?.firstTabBarController()
        }

        deinit {
            MainActor.assumeIsolated {
                pendingLayoutTask?.cancel()
                removeChrome()
            }
        }
    }
}

private final class PassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        return hitView === self ? nil : hitView
    }
}

private final class PassThroughVisualEffectView: UIVisualEffectView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView === self || hitView === contentView {
            return nil
        }
        return hitView
    }
}

private final class CurrentTabReselectionGestureRecognizer: UITapGestureRecognizer {
    private(set) var beganOnSelectedItem = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        beganOnSelectedItem = touches.first.map { touch in
            isSelectedTabBarItemTap(at: touch.location(in: view))
        } ?? false
        super.touchesBegan(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        beganOnSelectedItem = false
        super.touchesCancelled(touches, with: event)
    }

    private func isSelectedTabBarItemTap(at point: CGPoint) -> Bool {
        guard let tabBar = view as? UITabBar,
              let items = tabBar.items,
              let selectedItem = tabBar.selectedItem,
              let selectedIndex = items.firstIndex(of: selectedItem) else {
            return false
        }

        let selectedItemFrame = TabBarItemFrameResolver.selectedItemHitFrame(in: tabBar)
        return TabBarReselectionHitPolicy(
            itemCount: items.count,
            selectedIndex: selectedIndex,
            tabBarWidth: tabBar.bounds.width,
            selectedItemFrame: selectedItemFrame
        )
        .isSelectedItemTap(at: point)
    }
}

@MainActor
private enum TabBarItemFrameResolver {
    private static let minimumVisibleDockSide: CGFloat = 44
    private static let maximumVisibleDockSide: CGFloat = 64
    private static let visibleDockPadding: CGFloat = 20

    static func selectedItemHitFrame(in tabBar: UITabBar) -> CGRect? {
        selectedItemView(in: tabBar)?.frame.intersection(tabBar.bounds)
    }

    static func selectedItemVisualFrame(in tabBar: UITabBar) -> CGRect? {
        guard let selectedView = selectedItemView(in: tabBar) else {
            return nil
        }

        let fallbackFrame = selectedView.frame.intersection(tabBar.bounds)
        guard let contentFrame = visibleContentFrame(in: selectedView, convertedTo: tabBar) else {
            return fallbackFrame
        }

        let side = min(
            maximumVisibleDockSide,
            max(minimumVisibleDockSide, max(contentFrame.width, contentFrame.height) + visibleDockPadding)
        )
        let frame = CGRect(
            x: contentFrame.midX - side / 2,
            y: contentFrame.midY - side / 2,
            width: side,
            height: side
        )
        let boundedFrame = frame.intersection(tabBar.bounds)
        return boundedFrame.isNull ? fallbackFrame : boundedFrame
    }

    private static func selectedItemView(in tabBar: UITabBar) -> UIView? {
        if let control = selectedItemControl(in: tabBar) {
            return control
        }
        return visibleDockView(in: tabBar)
    }

    private static func selectedItemControl(in tabBar: UITabBar) -> UIControl? {
        guard let items = tabBar.items,
              let selectedItem = tabBar.selectedItem,
              let selectedIndex = items.firstIndex(of: selectedItem) else {
            return nil
        }

        let itemControls = visibleItemControls(in: tabBar)

        if itemControls.count == 1 {
            return itemControls[0]
        }

        guard itemControls.indices.contains(selectedIndex) else { return nil }
        return itemControls[selectedIndex]
    }

    private static func visibleDockView(in tabBar: UITabBar) -> UIView? {
        let maxDockSide = max(maximumVisibleDockSide, tabBar.bounds.height * 1.5)
        return visiblePresentationViews(in: tabBar)
            .filter { ($0 is UIControl) == false }
            .filter { view in
                let frame = view.frame.intersection(tabBar.bounds)
                return frame.isNull == false
                    && frame.width <= maxDockSide
                    && frame.height <= maxDockSide
            }
            .sorted { first, second in
                first.frame.width * first.frame.height > second.frame.width * second.frame.height
            }
            .first
    }

    private static func visibleItemControls(in tabBar: UITabBar) -> [UIControl] {
        visiblePresentationViews(in: tabBar).compactMap { subview in
            subview as? UIControl
        }
        .sorted { first, second in
            switch tabBar.effectiveUserInterfaceLayoutDirection {
            case .rightToLeft:
                first.frame.minX > second.frame.minX
            default:
                first.frame.minX < second.frame.minX
            }
        }
    }

    private static func visiblePresentationViews(in tabBar: UITabBar) -> [UIView] {
        tabBar.subviews.filter { subview in
            let frame = subview.frame.intersection(tabBar.bounds)
            return subview.isHidden == false
                && subview.alpha > 0.01
                && subview.frame.isEmpty == false
                && frame.isNull == false
                && frame.width > 0
                && frame.height > 0
        }
    }

    private static func visibleContentFrame(in view: UIView, convertedTo rootView: UIView) -> CGRect? {
        var frame: CGRect?
        if view is UIImageView || view is UILabel {
            frame = view.convert(view.bounds, to: rootView)
        }

        for subview in view.subviews where subview.isHidden == false && subview.alpha > 0.01 && subview.bounds.isEmpty == false {
            guard let subviewFrame = visibleContentFrame(in: subview, convertedTo: rootView) else {
                continue
            }
            frame = frame.map { $0.union(subviewFrame) } ?? subviewFrame
        }

        return frame
    }
}

private extension UIViewController {
    func firstTabBarController() -> UITabBarController? {
        if let tabBarController = self as? UITabBarController {
            return tabBarController
        }

        for child in children {
            if let tabBarController = child.firstTabBarController() {
                return tabBarController
            }
        }

        if let presentedViewController,
           let tabBarController = presentedViewController.firstTabBarController() {
            return tabBarController
        }

        return nil
    }

    func firstRegisteredContentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
        if let scrollView = contentScrollView(for: edge),
           scrollView.window != nil {
            return scrollView
        }

        if let navigationController = self as? UINavigationController,
           let scrollView = navigationController.visibleViewController?
            .firstRegisteredContentScrollView(for: edge) {
            return scrollView
        }

        if let tabBarController = self as? UITabBarController,
           let scrollView = tabBarController.selectedViewController?
            .firstRegisteredContentScrollView(for: edge) {
            return scrollView
        }

        for child in children.reversed() {
            if let scrollView = child.firstRegisteredContentScrollView(for: edge) {
                return scrollView
            }
        }

        return nil
    }
}

private extension UIView {
    func firstVisibleVerticalScrollView(allowShortContent: Bool = false) -> UIScrollView? {
        if let scrollView = self as? UIScrollView,
           scrollView.window != nil,
           scrollView.isHidden == false,
           scrollView.alpha > 0.01,
           scrollView.bounds.height > 0,
           scrollView.contentSize.height > 0,
           (allowShortContent || scrollView.contentSize.height > scrollView.bounds.height) {
            return scrollView
        }

        for subview in subviews.reversed() {
            if let scrollView = subview.firstVisibleVerticalScrollView(allowShortContent: allowShortContent) {
                return scrollView
            }
        }

        return nil
    }
}
#endif
