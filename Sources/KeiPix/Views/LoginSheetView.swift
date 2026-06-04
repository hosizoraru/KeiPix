import SwiftUI
import WebKit

struct LoginSheetView: View {
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss
    @State private var loginURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderRail(
                title: L10n.loginTitle,
                subtitle: L10n.loginHint,
                leading: {
                    SheetHeaderIcon(
                        systemImage: "person.crop.circle.badge.plus",
                        tint: .accentColor
                    )
                },
                closeAction: closeSheet
            )

            if let loginURL {
                PixivLoginWebView(url: loginURL) { code in
                    Task {
                        await store.completeLogin(code: code)
                        dismiss()
                    }
                }
            } else {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            loginURL = await store.loginURL()
        }
    }

    private func closeSheet() {
        store.isLoginPresented = false
        dismiss()
    }
}

private struct PixivLoginWebView {
    let url: URL
    let onCode: (String) -> Void

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if let code = Self.authorizationCode(from: url) {
                onCode(code)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        private static func authorizationCode(from url: URL) -> String? {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                return code
            }

            if url.scheme == "pixiv",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                return code
            }

            return nil
        }
    }
}

#if os(macOS)
extension PixivLoginWebView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#elseif os(iOS)
extension PixivLoginWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#endif
