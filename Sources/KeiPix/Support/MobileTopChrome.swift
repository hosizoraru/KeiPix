import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    func mobileFloatingTopChrome(syncID: String = "default") -> some View {
        modifier(MobileFloatingTopChromeModifier(syncID: syncID))
    }

    func mobileToolbarChromeMaterial(syncID: String = "default") -> some View {
        modifier(MobileToolbarChromeMaterialModifier(syncID: syncID))
    }
}

#if os(iOS)
private struct MobileFloatingTopChromeModifier: ViewModifier {
    let syncID: String

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .mobileToolbarChromeMaterial(syncID: syncID)
    }
}

private struct MobileToolbarChromeMaterialModifier: ViewModifier {
    let syncID: String
    @Environment(\.chromeMaterialMode) private var chromeMaterialMode

    @ViewBuilder
    func body(content: Content) -> some View {
        let chrome = content
            .background {
                NavigationBarChromeBridge(
                    chromeMaterialMode: chromeMaterialMode,
                    syncID: syncID
                )
                .allowsHitTesting(false)
            }

        if chromeMaterialMode == .liquidGlass {
            chrome.toolbarBackground(.hidden, for: .navigationBar)
        } else if chromeMaterialMode == .translucentBlur {
            chrome
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            chrome.toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct NavigationBarChromeBridge: UIViewControllerRepresentable {
    let chromeMaterialMode: ChromeMaterialMode
    let syncID: String

    func makeUIViewController(context: Context) -> Controller {
        Controller(chromeMaterialMode: chromeMaterialMode, syncID: syncID)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        if controller.chromeMaterialMode != chromeMaterialMode {
            controller.chromeMaterialMode = chromeMaterialMode
        }
        if controller.syncID != syncID {
            controller.syncID = syncID
        } else {
            controller.applyAppearance()
        }
    }

    final class Controller: UIViewController {
        private weak var appliedNavigationController: UINavigationController?
        private var lastAppliedChromeMaterialMode: ChromeMaterialMode?
        private var pendingReapplyTask: Task<Void, Never>?

        var chromeMaterialMode: ChromeMaterialMode {
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

        init(chromeMaterialMode: ChromeMaterialMode, syncID: String) {
            self.chromeMaterialMode = chromeMaterialMode
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
                lastAppliedChromeMaterialMode = nil
            }

            guard lastAppliedChromeMaterialMode != chromeMaterialMode else { return }

            let appearance = UINavigationBarAppearance()
            switch chromeMaterialMode {
            case .liquidGlass:
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = .clear
                appearance.backgroundEffect = nil
                appearance.shadowColor = .clear
                navigationController.navigationBar.isTranslucent = true
                navigationController.navigationBar.backgroundColor = .clear
            case .translucentBlur:
                appearance.configureWithTransparentBackground()
                appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
                appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.18)
                appearance.shadowColor = UIColor.separator.withAlphaComponent(0.18)
                navigationController.navigationBar.isTranslucent = true
                navigationController.navigationBar.backgroundColor = .clear
            case .plain:
                appearance.configureWithTransparentBackground()
                appearance.backgroundEffect = nil
                appearance.backgroundColor = .clear
                appearance.shadowColor = .clear
                navigationController.navigationBar.isTranslucent = true
                navigationController.navigationBar.backgroundColor = .clear
            }

            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
            navigationController.navigationBar.compactScrollEdgeAppearance = appearance
            lastAppliedChromeMaterialMode = chromeMaterialMode
        }

        private func scheduleDeferredReapply() {
            pendingReapplyTask?.cancel()
            pendingReapplyTask = Task { @MainActor [weak self] in
                await Task.yield()
                self?.lastAppliedChromeMaterialMode = nil
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
#else
private struct MobileFloatingTopChromeModifier: ViewModifier {
    let syncID: String

    func body(content: Content) -> some View {
        content
    }
}

private struct MobileToolbarChromeMaterialModifier: ViewModifier {
    let syncID: String

    func body(content: Content) -> some View {
        content
    }
}
#endif
