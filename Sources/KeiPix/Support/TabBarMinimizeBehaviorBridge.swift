#if os(iOS)
import SwiftUI
import UIKit

struct TabBarMinimizeBehaviorBridge: UIViewControllerRepresentable {
    let behavior: UITabBarController.MinimizeBehavior
    let isTabBarHidden: Bool
    let usesTransparentBackground: Bool
    let scrollsToTopOnCurrentTabReselection: Bool
    let syncID: String

    func makeUIViewController(context: Context) -> Controller {
        Controller(
            behavior: behavior,
            isTabBarHidden: isTabBarHidden,
            usesTransparentBackground: usesTransparentBackground,
            scrollsToTopOnCurrentTabReselection: scrollsToTopOnCurrentTabReselection,
            syncID: syncID
        )
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
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
            syncID: String
        ) {
            self.behavior = behavior
            self.isTabBarHidden = isTabBarHidden
            self.usesTransparentBackground = usesTransparentBackground
            self.scrollsToTopOnCurrentTabReselection = scrollsToTopOnCurrentTabReselection
            self.syncID = syncID
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
            return selectedViewController.view.firstVisibleVerticalScrollView()
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

        let selectedItemFrame = selectedItemFrame(
            in: tabBar,
            selectedIndex: selectedIndex
        )
        return TabBarReselectionHitPolicy(
            itemCount: items.count,
            selectedIndex: selectedIndex,
            tabBarWidth: tabBar.bounds.width,
            selectedItemFrame: selectedItemFrame
        )
        .isSelectedItemTap(at: point)
    }

    private func selectedItemFrame(in tabBar: UITabBar, selectedIndex: Int) -> CGRect? {
        let itemControls = tabBar.subviews.compactMap { subview -> UIControl? in
            guard let control = subview as? UIControl,
                  control.isHidden == false,
                  control.alpha > 0.01,
                  control.frame.isEmpty == false else {
                return nil
            }
            return control
        }
        .sorted { first, second in
            switch tabBar.effectiveUserInterfaceLayoutDirection {
            case .rightToLeft:
                first.frame.minX > second.frame.minX
            default:
                first.frame.minX < second.frame.minX
            }
        }

        guard itemControls.indices.contains(selectedIndex) else { return nil }
        return itemControls[selectedIndex].frame.intersection(tabBar.bounds)
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
    func firstVisibleVerticalScrollView() -> UIScrollView? {
        if let scrollView = self as? UIScrollView,
           scrollView.window != nil,
           scrollView.isHidden == false,
           scrollView.alpha > 0.01,
           scrollView.contentSize.height > scrollView.bounds.height {
            return scrollView
        }

        for subview in subviews.reversed() {
            if let scrollView = subview.firstVisibleVerticalScrollView() {
                return scrollView
            }
        }

        return nil
    }
}
#endif
