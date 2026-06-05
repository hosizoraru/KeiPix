#if os(iOS)
import SwiftUI
import UIKit

struct TabBarMinimizeBehaviorBridge: UIViewControllerRepresentable {
    let behavior: UITabBarController.MinimizeBehavior
    let isTabBarHidden: Bool
    let usesTransparentBackground: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller(
            behavior: behavior,
            isTabBarHidden: isTabBarHidden,
            usesTransparentBackground: usesTransparentBackground
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
    }

    final class Controller: UIViewController {
        private var hasDeferredApply = false
        private var hasAppliedTabBarState = false
        private weak var appliedTabBarController: UITabBarController?
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

        init(
            behavior: UITabBarController.MinimizeBehavior,
            isTabBarHidden: Bool,
            usesTransparentBackground: Bool
        ) {
            self.behavior = behavior
            self.isTabBarHidden = isTabBarHidden
            self.usesTransparentBackground = usesTransparentBackground
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
            if lastAppliedBehavior != behavior || tabBarController.tabBarMinimizeBehavior != behavior {
                tabBarController.tabBarMinimizeBehavior = behavior
                lastAppliedBehavior = behavior
            }
            if lastAppliedTabBarHidden != isTabBarHidden || tabBarController.isTabBarHidden != isTabBarHidden {
                tabBarController.setTabBarHidden(isTabBarHidden, animated: hasAppliedTabBarState)
                lastAppliedTabBarHidden = isTabBarHidden
            }
            hasAppliedTabBarState = true
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
}
#endif
