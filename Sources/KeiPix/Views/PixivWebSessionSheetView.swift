import SwiftUI
import WebKit

struct PixivWebSessionSheetView: View {
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cookieCapture = PixivWebSessionCookieCapture()
    @State private var isSaving = false
    @State private var message: String?

    private var url: URL {
        if let userID = store.session?.user.id,
           let savedCollectionsURL = PixivWebURLBuilder.userBookmarkCollectionsURL(userID: String(userID)) {
            return savedCollectionsURL
        }
        return PixivWebURLBuilder.collectionsURL()
            ?? URL(string: "https://www.pixiv.net/collections")!
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderRail(
                title: L10n.connectPixivWebSession,
                subtitle: L10n.connectPixivWebSessionHint,
                leading: {
                    SheetHeaderIcon(systemImage: "globe.badge.chevron.backward", tint: .accentColor)
                },
                closeAction: closeSheet
            )

            PixivWebSessionWebView(url: url, cookieCapture: cookieCapture)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(L10n.cancel, role: .cancel, action: closeSheet)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)

                Spacer()

                Button {
                    Task { await saveWebSession() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.savePixivWebSession, systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .disabled(isSaving)
            }
        }
        .platformGlassControlBar(verticalPadding: 10, topPadding: 8, bottomPadding: 14)
    }

    private func saveWebSession() async {
        isSaving = true
        defer { isSaving = false }

        let cookies = await cookieCapture.pixivCookies()
        guard cookies.isEmpty == false else {
            message = L10n.pixivWebSessionNoCookies
            return
        }

        if await store.connectPixivWebSession(cookies: cookies) {
            dismiss()
        } else {
            message = store.errorMessage ?? L10n.pixivWebSessionConnectionFailed
        }
    }

    private func closeSheet() {
        store.isPixivWebSessionPresented = false
        dismiss()
    }
}

@MainActor
final class PixivWebSessionCookieCapture: ObservableObject {
    fileprivate var cookieStore: WKHTTPCookieStore?

    func pixivCookies() async -> [PixivWebSessionCookie] {
        guard let cookieStore else { return [] }
        let cookies = await cookieStore.allCookies()
        return PixivWebSessionCookie.pixivCookies(from: cookies)
    }
}

@MainActor
private struct PixivWebSessionWebView {
    let url: URL
    let cookieCapture: PixivWebSessionCookieCapture

    final class Coordinator: NSObject, WKNavigationDelegate {}

    private func makeWebView(coordinator: Coordinator) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.customUserAgent = AppVersion.current.desktopSafariUserAgent()
        cookieCapture.cookieStore = configuration.websiteDataStore.httpCookieStore
        webView.load(URLRequest(url: url))
        return webView
    }
}

#if os(macOS)
extension PixivWebSessionWebView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#elseif os(iOS)
extension PixivWebSessionWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#endif

private extension WKHTTPCookieStore {
    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
}
