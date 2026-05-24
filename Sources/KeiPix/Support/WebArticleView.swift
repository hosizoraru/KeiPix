import SwiftUI
import WebKit

struct WebArticleView: NSViewRepresentable {
    let url: URL
    var openArtworkLink: (Int) -> Void = { _ in }
    var openUserLink: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(openArtworkLink: openArtworkLink, openUserLink: openUserLink)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.openArtworkLink = openArtworkLink
        context.coordinator.openUserLink = openUserLink
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var openArtworkLink: (Int) -> Void
        var openUserLink: (Int) -> Void

        init(openArtworkLink: @escaping (Int) -> Void, openUserLink: @escaping (Int) -> Void) {
            self.openArtworkLink = openArtworkLink
            self.openUserLink = openUserLink
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                if openNativeArtworkIfPossible(url) {
                    return nil
                }
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if let url = navigationAction.request.url {
                if openNativeArtworkIfPossible(url) {
                    return .cancel
                }

                if navigationAction.targetFrame == nil {
                    webView.load(URLRequest(url: url))
                    return .cancel
                }
            }
            return .allow
        }

        private func openNativeArtworkIfPossible(_ url: URL) -> Bool {
            guard let artworkID = PixivWebLinkResolver.artworkID(from: url) else {
                if let userID = PixivWebLinkResolver.userID(from: url) {
                    openUserLink(userID)
                    return true
                }
                return false
            }
            openArtworkLink(artworkID)
            return true
        }
    }
}
