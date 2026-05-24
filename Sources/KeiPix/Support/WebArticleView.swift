import SwiftUI
import WebKit

struct WebArticleNavigationState: Equatable {
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var title: String?
    var currentURL: URL?
    var errorMessage: String?
}

struct WebArticleCommand: Equatable, Identifiable {
    enum Action: Equatable {
        case goBack
        case goForward
        case reload
    }

    let id = UUID()
    let action: Action
}

struct WebArticleView: NSViewRepresentable {
    let url: URL
    @Binding var navigationState: WebArticleNavigationState
    var command: WebArticleCommand?
    var openArtworkLink: (Int) -> Void = { _ in }
    var openUserLink: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            navigationState: $navigationState,
            openArtworkLink: openArtworkLink,
            openUserLink: openUserLink
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(Self.readerStyleScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.navigationState = $navigationState
        context.coordinator.openArtworkLink = openArtworkLink
        context.coordinator.openUserLink = openUserLink
        context.coordinator.run(command, in: webView, homeURL: url)
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
        nsView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var navigationState: Binding<WebArticleNavigationState>
        var openArtworkLink: (Int) -> Void
        var openUserLink: (Int) -> Void
        private var lastCommandID: WebArticleCommand.ID?

        init(
            navigationState: Binding<WebArticleNavigationState>,
            openArtworkLink: @escaping (Int) -> Void,
            openUserLink: @escaping (Int) -> Void
        ) {
            self.navigationState = navigationState
            self.openArtworkLink = openArtworkLink
            self.openUserLink = openUserLink
        }

        func run(_ command: WebArticleCommand?, in webView: WKWebView, homeURL: URL) {
            guard let command, command.id != lastCommandID else { return }
            lastCommandID = command.id

            switch command.action {
            case .goBack:
                if webView.canGoBack {
                    webView.goBack()
                }
            case .goForward:
                if webView.canGoForward {
                    webView.goForward()
                }
            case .reload:
                if webView.url == nil {
                    webView.load(URLRequest(url: homeURL))
                } else {
                    webView.reload()
                }
            }

            publishState(from: webView)
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
                configuration.userContentController.addUserScript(WebArticleView.readerStyleScript)
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

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            publishState(from: webView, isLoading: true, errorMessage: nil)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            publishState(from: webView, isLoading: true, errorMessage: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            publishState(from: webView, isLoading: false, errorMessage: nil)
            injectReaderStyle(into: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard isCancellationLike(error) == false else { return }
            publishState(from: webView, isLoading: false, errorMessage: error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard isCancellationLike(error) == false else { return }
            publishState(from: webView, isLoading: false, errorMessage: error.localizedDescription)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            publishState(from: webView, isLoading: false, errorMessage: L10n.webContentReloaded)
            webView.reload()
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

        private func publishState(
            from webView: WKWebView,
            isLoading: Bool? = nil,
            errorMessage: String? = nil
        ) {
            navigationState.wrappedValue = WebArticleNavigationState(
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward,
                isLoading: isLoading ?? webView.isLoading,
                title: webView.title,
                currentURL: webView.url,
                errorMessage: errorMessage
            )
        }

        private func injectReaderStyle(into webView: WKWebView) {
            webView.evaluateJavaScript(WebArticleView.readerStyleSource)
        }

        private func isCancellationLike(_ error: Error) -> Bool {
            if error is CancellationError {
                return true
            }
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
        }
    }

    private static let readerStyleScript = WKUserScript(
        source: readerStyleSource,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: false
    )

    private static let readerStyleSource = """
    (() => {
      if (document.documentElement.dataset.keipixReader === "true") { return; }
      document.documentElement.dataset.keipixReader = "true";
      const style = document.createElement("style");
      style.textContent = `
        header,
        footer,
        nav,
        [role="banner"],
        [role="navigation"],
        [class*="Header"],
        [class*="Footer"],
        [class*="GlobalNav"],
        [class*="global-nav"],
        [class*="Cookie"],
        [class*="cookie"],
        [class*="Privacy"],
        [class*="privacy"],
        .amPrivacy,
        .gtm-cookie-banner {
          display: none !important;
        }

        html,
        body {
          background: Canvas !important;
          color: CanvasText !important;
        }

        body {
          margin: 0 !important;
          padding: 0 !important;
        }

        main,
        article,
        [class*="Article"],
        [class*="article"],
        [class*="Contents"],
        [class*="contents"] {
          max-width: 880px !important;
          margin-left: auto !important;
          margin-right: auto !important;
        }

        img,
        picture,
        video {
          max-width: 100% !important;
          height: auto !important;
        }
      `;
      document.documentElement.appendChild(style);
    })();
    """
}
