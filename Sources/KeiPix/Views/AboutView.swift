import AppKit
import SwiftUI

/// About panel surfaced through the application menu's "About KeiPix" item.
///
/// macOS' default `orderFrontStandardAboutPanel` shows only the bundle's
/// short version and copyright string; for a project that leans on
/// behaviour references like Pixez/Pixes — and that ships with translators,
/// dependency notices, and a not-yet-formal license — a hand-built panel
/// keeps that context discoverable without forcing users into the README.
///
/// Presented as a dedicated `Window` scene (id `"about"`) so it picks up
/// the standard close button, restoration semantics, and Window menu entry,
/// and so the menu command can route to it via `openWindow`.
struct AboutView: View {
    private let appName = Self.bundleDisplayName
    private let version = Self.shortVersion
    private let build = Self.bundleVersion

    @State private var diagnosticsToast: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summarySection
                    repositorySection
                    acknowledgmentsSection
                    localizationSection
                    licenseSection
                }
                .padding(.vertical, 4)
            }
            footer
        }
        .padding(20)
        .frame(width: 480, height: 540)
        .overlay(alignment: .bottom) {
            if let message = diagnosticsToast {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 14)
                    .transition(.opacity)
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { diagnosticsToast = nil }
                    }
            }
        }
        .animation(.snappy, value: diagnosticsToast)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            // The repo doesn't bundle an .icns, so fall back to a SF Symbol
            // styled like the app icon. Keeps the panel from looking empty
            // while still giving an instantly recognisable visual hook.
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(appName)
                    .font(.title.weight(.semibold))
                Text(L10n.versionLabel(version))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(L10n.buildLabel(build))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var summarySection: some View {
        Text(L10n.aboutSummary)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var repositorySection: some View {
        section(L10n.aboutSourceRepository) {
            Link(destination: Self.repositoryURL) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                    Text(L10n.aboutOpenOnGitHub)
                }
                .font(.callout)
            }
        }
    }

    private var acknowledgmentsSection: some View {
        section(L10n.aboutAcknowledgments) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.aboutReferenceProjects)
                    .font(.callout.weight(.medium))
                Text(L10n.aboutReferenceProjectsBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var localizationSection: some View {
        section(L10n.aboutLocalization) {
            Text(L10n.aboutLocalizationBody)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var licenseSection: some View {
        section(L10n.aboutLicense) {
            Text(L10n.aboutLicenseBody)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                copyDiagnosticsBundle()
            } label: {
                Label(L10n.aboutCopyDiagnostics, systemImage: "doc.on.doc")
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func copyDiagnosticsBundle() {
        let payload = """
        \(appName)
        \(L10n.versionLabel(version))
        \(L10n.buildLabel(build))
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Locale: \(Locale.current.identifier)
        Repository: \(Self.repositoryURL.absoluteString)
        """
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
        diagnosticsToast = L10n.aboutDiagnosticsCopied
    }

    static let repositoryURL = URL(string: "https://github.com/hosizoraru/KeiPix")!

    private static var bundleDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "KeiPix"
    }

    private static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

#Preview {
    AboutView()
}
