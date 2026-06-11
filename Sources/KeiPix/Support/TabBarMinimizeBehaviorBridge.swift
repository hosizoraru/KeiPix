#if os(iOS)
import SwiftUI
import UIKit

struct TabBarMinimizeBehaviorBridge: UIViewControllerRepresentable {
    let behavior: UITabBarController.MinimizeBehavior
    let isTabBarHidden: Bool
    let usesTransparentBackground: Bool
    let scrollsToTopOnCurrentTabReselection: Bool
    let syncID: String
    let tabBarGeometry: Binding<TabBarGeometrySnapshot?>? = nil

    func makeUIViewController(context: Context) -> Controller {
        Controller(
            behavior: behavior,
            isTabBarHidden: isTabBarHidden,
            usesTransparentBackground: usesTransparentBackground,
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
            scrollsToTopOnCurrentTabReselection: Bool,
            syncID: String,
            onGeometryChange: @escaping (TabBarGeometrySnapshot?) -> Void
        ) {
            self.behavior = behavior
            self.isTabBarHidden = isTabBarHidden
            self.usesTransparentBackground = usesTransparentBackground
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
            guard lastAppliedTransparentBackground != usesTransparentBackground else { return }

            let appearance = UITabBarAppearance()
            if usesTransparentBackground {
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = .clear
                appearance.shadowColor = .clear
                appearance.shadowImage = nil
                tabBar.isTranslucent = true
                tabBar.backgroundColor = .clear
            } else {
                appearance.configureWithDefaultBackground()
            }
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = usesTransparentBackground ? appearance : nil
            lastAppliedTransparentBackground = usesTransparentBackground
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
    let resultText: String
    let isEnabled: Bool
    let isAtContentStart: Bool
    let syncID: String

    func makeUIViewController(context: Context) -> Controller {
        Controller(
            text: $text,
            resultText: resultText,
            isEnabled: isEnabled,
            isAtContentStart: isAtContentStart,
            syncID: syncID
        )
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.text = $text
        controller.resultText = resultText
        controller.isEnabled = isEnabled
        controller.isAtContentStart = isAtContentStart
        controller.syncID = syncID
        controller.applyOverlay()
    }

    final class Controller: UIViewController, UITextFieldDelegate {
        var text: Binding<String>
        var resultText: String
        var isEnabled: Bool
        var isAtContentStart: Bool
        var syncID: String {
            didSet {
                scheduleDeferredLayout()
            }
        }

        private weak var filterField: UITextField?
        private var overlayView: UIVisualEffectView?
        private weak var appliedTabBarController: UITabBarController?
        private weak var observedScrollView: UIScrollView?
        private var scrollObservation: NSKeyValueObservation?
        private var pendingLayoutTask: Task<Void, Never>?

        init(
            text: Binding<String>,
            resultText: String,
            isEnabled: Bool,
            isAtContentStart: Bool,
            syncID: String
        ) {
            self.text = text
            self.resultText = resultText
            self.isEnabled = isEnabled
            self.isAtContentStart = isAtContentStart
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
                overlayView?.isHidden = true
                filterField?.resignFirstResponder()
                stopObservingScrollView()
                return
            }

            guard let tabBarController = resolvedTabBarController() else {
                removeOverlay()
                stopObservingScrollView()
                scheduleDeferredLayout()
                return
            }

            syncObservedScrollView(in: tabBarController)
            let contentIsAtStart = selectedContentIsAtStart(in: tabBarController) ?? isAtContentStart
            let geometry = tabBarGeometry(in: tabBarController)
            guard let layout = PhoneFeedFilterBarLayout.resolve(
                    containerSize: tabBarController.view.bounds.size,
                    tabBarGeometry: geometry,
                    contentIsAtStart: contentIsAtStart,
                    hasActiveFilter: hasActiveFilter
                  ) else {
                overlayView?.isHidden = true
                return
            }

            let overlayView = ensureOverlay(in: tabBarController)
            updateField()
            overlayView.isHidden = false
            overlayView.frame = layout.frame
            tabBarController.view.bringSubviewToFront(overlayView)
        }

        private func ensureOverlay(in tabBarController: UITabBarController) -> UIVisualEffectView {
            if let overlayView,
               appliedTabBarController === tabBarController {
                return overlayView
            }

            removeOverlay()
            let overlayView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            overlayView.layer.cornerRadius = PhoneFeedFilterBarLayout.height / 2
            overlayView.layer.cornerCurve = .continuous
            overlayView.clipsToBounds = true
            overlayView.isUserInteractionEnabled = true

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
            field.accessibilityLabel = L10n.filterArtworks
            field.leftView = searchIconView()
            field.leftViewMode = .always
            field.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
            field.translatesAutoresizingMaskIntoConstraints = false

            overlayView.contentView.addSubview(field)
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: overlayView.contentView.leadingAnchor, constant: 4),
                field.trailingAnchor.constraint(equalTo: overlayView.contentView.trailingAnchor, constant: -8),
                field.centerYAnchor.constraint(equalTo: overlayView.contentView.centerYAnchor),
                field.heightAnchor.constraint(equalToConstant: 36)
            ])

            tabBarController.view.addSubview(overlayView)
            self.overlayView = overlayView
            filterField = field
            appliedTabBarController = tabBarController
            updateField()
            return overlayView
        }

        private func removeOverlay() {
            overlayView?.removeFromSuperview()
            overlayView = nil
            filterField = nil
            appliedTabBarController = nil
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

        private func syncObservedScrollView(in tabBarController: UITabBarController) {
            let scrollView = selectedContentScrollView(in: tabBarController)
            guard observedScrollView !== scrollView else { return }
            scrollObservation = nil
            observedScrollView = scrollView
            scrollObservation = scrollView?.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    self?.applyOverlay()
                    self?.scheduleDeferredLayout()
                }
            }
            scheduleDeferredLayout()
        }

        private func stopObservingScrollView() {
            scrollObservation = nil
            observedScrollView = nil
        }

        private func selectedContentIsAtStart(in tabBarController: UITabBarController) -> Bool? {
            guard let scrollView = selectedContentScrollView(in: tabBarController) else {
                return nil
            }
            let startY = -scrollView.adjustedContentInset.top
            return scrollView.contentOffset.y <= startY + 1
        }

        private func selectedContentScrollView(in tabBarController: UITabBarController) -> UIScrollView? {
            guard let selectedViewController = tabBarController.selectedViewController else {
                return nil
            }
            if let scrollView = selectedViewController.firstRegisteredContentScrollView(for: .bottom) {
                return scrollView
            }
            if let scrollView = selectedViewController.view.firstVisibleVerticalScrollView(allowShortContent: true) {
                return scrollView
            }
            return tabBarController.view.firstVisibleVerticalScrollView(allowShortContent: true)
        }

        private var hasActiveFilter: Bool {
            text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        private func updateField() {
            filterField?.placeholder = L10n.filterArtworks
            filterField?.accessibilityLabel = L10n.filterArtworks
            filterField?.accessibilityValue = resultText
            if filterField?.text != text.wrappedValue {
                filterField?.text = text.wrappedValue
            }
        }

        @objc private func editingChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            self.text.wrappedValue = ""
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
                scrollObservation = nil
                removeOverlay()
            }
        }
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
