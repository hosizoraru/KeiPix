import SwiftUI
import WebKit

struct LoginSheetView: View {
    @Bindable var store: KeiPixStore
    @State private var loginURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.loginTitle)
                        .font(.headline)
                    Text(L10n.loginHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.isLoginPresented = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            .padding(14)
            .background(.bar)

            Divider()

            if let loginURL {
                PixivLoginWebView(url: loginURL) { code in
                    Task { await store.completeLogin(code: code) }
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
}

private struct PixivLoginWebView: NSViewRepresentable {
    let url: URL
    let onCode: (String) -> Void

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
