#if os(macOS)
import SwiftUI

/// Menu Bar Extra providing quick access to common actions without
/// bringing the main window forward. Mirrors the "always-on" utility
/// pattern Pixes/Pixez expose through their status-bar tray icon.
struct MenuBarExtraView: View {
    @Bindable var store: KeiPixStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.session != nil {
            signedInMenu
        } else {
            signedOutMenu
        }
    }

    private var signedInMenu: some View {
        Group {
            accountHeader

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(L10n.openMainWindow, systemImage: "macwindow")
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button {
                Task { await store.surpriseMe() }
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(L10n.surpriseMe, systemImage: "shuffle")
            }

            Button {
                Task { await store.reloadCurrentFeed() }
            } label: {
                Label(L10n.refresh, systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                Task { await store.openPixivLinkFromClipboard() }
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(L10n.openPixivLinkFromClipboard, systemImage: "doc.on.clipboard")
            }

            if store.downloads.activeCount > 0 {
                Divider()

                Label {
                    Text("\(store.downloads.activeCount) \(L10n.downloading)")
                        .font(.caption)
                } icon: {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    if store.downloads.isPaused {
                        _ = store.downloads.resumeQueue()
                    } else {
                        _ = store.downloads.pauseQueue()
                    }
                } label: {
                    Label(
                        store.downloads.isPaused ? L10n.resumeDownloads : L10n.pauseDownloads,
                        systemImage: store.downloads.isPaused ? "play.fill" : "pause.fill"
                    )
                }
            }

            Divider()

            Button {
                openWindow(id: "main")
                store.select(.downloads)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(L10n.openDownloads, systemImage: "arrow.down.circle")
            }

            Button(L10n.quitKeiPix) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    private var signedOutMenu: some View {
        Group {
            Label(L10n.signedOut, systemImage: "person.crop.circle.badge.xmark")

            Divider()

            Button {
                store.isLoginPresented = true
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
            }

            Divider()

            Button(L10n.quitKeiPix) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    @ViewBuilder
    private var accountHeader: some View {
        if let session = store.session {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.user.name)
                        .font(.headline)
                    Text("@\(session.user.account)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
