import SwiftUI

extension View {
    @ViewBuilder
    func nativeBottomTabContentSurface(isEnabled: Bool = true) -> some View {
        #if os(iOS)
        self.backgroundExtensionEffect(isEnabled: isEnabled)
        #else
        self
        #endif
    }
}

#if os(iOS)
import UIKit

@MainActor
func configureScrollViewForBottomTabContent(_ scrollView: UIScrollView) {
    scrollView.backgroundColor = .clear
    scrollView.alwaysBounceVertical = true
    scrollView.showsVerticalScrollIndicator = true
    scrollView.contentInsetAdjustmentBehavior = .automatic
}

@MainActor
func configureCollectionViewForBottomTabContent(_ scrollView: UICollectionView) {
    configureScrollViewForBottomTabContent(scrollView)
}

@MainActor
final class NativeContentScrollRegistration {
    private weak var registeredContentScrollViewController: UIViewController?

    func register(_ scrollView: UIScrollView, edge: NSDirectionalRectEdge = .bottom) {
        guard scrollView.window != nil else { return }
        guard let viewController = enclosingViewController(for: scrollView) else { return }

        if registeredContentScrollViewController !== viewController {
            registeredContentScrollViewController?.setContentScrollView(nil, for: edge)
            registeredContentScrollViewController = viewController
        }

        guard viewController.contentScrollView(for: edge) !== scrollView else { return }
        viewController.setContentScrollView(scrollView, for: edge)
    }

    func registerNearestScrollView(containing view: UIView, edge: NSDirectionalRectEdge = .bottom) {
        guard let scrollView = enclosingScrollView(for: view) else { return }
        configureScrollViewForBottomTabContent(scrollView)
        register(scrollView, edge: edge)
    }

    func unregister(edge: NSDirectionalRectEdge = .bottom) {
        registeredContentScrollViewController?.setContentScrollView(nil, for: edge)
        registeredContentScrollViewController = nil
    }

    private func enclosingViewController(for view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }

    private func enclosingScrollView(for view: UIView) -> UIScrollView? {
        var candidate = view.superview
        while let current = candidate {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            candidate = current.superview
        }
        return nil
    }
}

final class NativeContentAwareCollectionView: UICollectionView {
    var onHierarchyAvailable: ((UICollectionView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        notifyHierarchyAvailableIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        notifyHierarchyAvailableIfNeeded()
    }

    private func notifyHierarchyAvailableIfNeeded() {
        guard window != nil else { return }
        onHierarchyAvailable?(self)
    }
}

struct NativeBottomTabScrollContentHost<Content: View>: View {
    private let showsIndicators: Bool
    private let content: Content

    init(
        showsIndicators: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, proxy.size.height), alignment: .center)
                    .background {
                        NativeContentScrollRegistrationAnchor()
                            .allowsHitTesting(false)
                    }
            }
            .scrollIndicators(showsIndicators ? .visible : .hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .nativeBottomTabContentSurface()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NativeContentScrollRegistrationAnchor: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> NativeContentScrollRegistrationAnchorView {
        let view = NativeContentScrollRegistrationAnchorView()
        view.onHierarchyAvailable = { [weak coordinator = context.coordinator] view in
            coordinator?.registerNearestScrollView(containing: view)
        }
        return view
    }

    func updateUIView(_ uiView: NativeContentScrollRegistrationAnchorView, context: Context) {
        uiView.onHierarchyAvailable = { [weak coordinator = context.coordinator] view in
            coordinator?.registerNearestScrollView(containing: view)
        }
        context.coordinator.registerNearestScrollView(containing: uiView)
    }

    @MainActor
    final class Coordinator {
        private let contentScrollRegistration = NativeContentScrollRegistration()

        deinit {
            let contentScrollRegistration = contentScrollRegistration
            Task { @MainActor in
                contentScrollRegistration.unregister()
            }
        }

        func registerNearestScrollView(containing view: UIView) {
            contentScrollRegistration.registerNearestScrollView(containing: view)
        }
    }
}

private final class NativeContentScrollRegistrationAnchorView: UIView {
    var onHierarchyAvailable: ((UIView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        notifyHierarchyAvailableIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        notifyHierarchyAvailableIfNeeded()
    }

    private func notifyHierarchyAvailableIfNeeded() {
        guard window != nil else { return }
        onHierarchyAvailable?(self)
    }
}
#endif
