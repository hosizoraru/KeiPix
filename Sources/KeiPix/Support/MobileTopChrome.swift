import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    @ViewBuilder
    func mobileFloatingTopChrome(syncID: String = "default") -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            self
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .background {
                    NavigationBarChromeBridge(
                        usesTransparentBackground: true,
                        syncID: syncID
                    )
                    .allowsHitTesting(false)
                }
        } else {
            self
                .navigationBarTitleDisplayMode(.inline)
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct NavigationBarChromeBridge: UIViewControllerRepresentable {
    let usesTransparentBackground: Bool
    let syncID: String

    func makeUIViewController(context: Context) -> Controller {
        Controller(usesTransparentBackground: usesTransparentBackground, syncID: syncID)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        if controller.usesTransparentBackground != usesTransparentBackground {
            controller.usesTransparentBackground = usesTransparentBackground
        }
        if controller.syncID != syncID {
            controller.syncID = syncID
        } else {
            controller.applyAppearance()
        }
    }

    final class Controller: UIViewController {
        private weak var appliedNavigationController: UINavigationController?
        private var lastAppliedTransparentBackground: Bool?
        private var pendingReapplyTask: Task<Void, Never>?

        var usesTransparentBackground: Bool {
            didSet {
                applyAppearance()
            }
        }

        var syncID: String {
            didSet {
                applyAppearance()
                scheduleDeferredReapply()
            }
        }

        init(usesTransparentBackground: Bool, syncID: String) {
            self.usesTransparentBackground = usesTransparentBackground
            self.syncID = syncID
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("NavigationBarChromeBridge does not support decoding")
        }

        deinit {
            pendingReapplyTask?.cancel()
        }

        override func loadView() {
            let view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyAppearance()
            scheduleDeferredReapply()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyAppearance()
            scheduleDeferredReapply()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyAppearance()
        }

        func applyAppearance() {
            guard let navigationController = resolvedNavigationController() else {
                scheduleDeferredReapply()
                return
            }

            if appliedNavigationController !== navigationController {
                appliedNavigationController = navigationController
                lastAppliedTransparentBackground = nil
            }

            guard lastAppliedTransparentBackground != usesTransparentBackground else { return }

            let appearance = UINavigationBarAppearance()
            if usesTransparentBackground {
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = .clear
                appearance.backgroundEffect = nil
                appearance.shadowColor = .clear
                navigationController.navigationBar.isTranslucent = true
                navigationController.navigationBar.backgroundColor = .clear
            } else {
                appearance.configureWithDefaultBackground()
            }

            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
            navigationController.navigationBar.compactScrollEdgeAppearance = appearance
            lastAppliedTransparentBackground = usesTransparentBackground
        }

        private func scheduleDeferredReapply() {
            pendingReapplyTask?.cancel()
            pendingReapplyTask = Task { @MainActor [weak self] in
                await Task.yield()
                self?.lastAppliedTransparentBackground = nil
                self?.applyAppearance()
            }
        }

        private func resolvedNavigationController() -> UINavigationController? {
            if let navigationController {
                return navigationController
            }

            var ancestor = parent
            while let controller = ancestor {
                if let navigationController = controller as? UINavigationController {
                    return navigationController
                }
                if let navigationController = controller.navigationController {
                    return navigationController
                }
                ancestor = controller.parent
            }

            return view.window?.rootViewController?.firstNavigationController()
        }
    }
}

private extension UIViewController {
    func firstNavigationController() -> UINavigationController? {
        if let navigationController = self as? UINavigationController {
            return navigationController
        }

        if let navigationController {
            return navigationController
        }

        for child in children {
            if let navigationController = child.firstNavigationController() {
                return navigationController
            }
        }

        if let presentedViewController,
           let navigationController = presentedViewController.firstNavigationController() {
            return navigationController
        }

        return nil
    }
}
#endif
