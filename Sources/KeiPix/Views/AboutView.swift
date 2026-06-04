import SwiftUI

/// Cross-platform About surface.
///
/// macOS still presents this as a dedicated auxiliary window from the
/// application menu, while iOS and iPadOS surface the same content from
/// Settings. The presentation is intentionally information-first: a compact
/// brand header, version/license actions, then a few scannable cards.
struct AboutView: View {
    enum Presentation {
        case window
        case settings
    }

    private let presentation: Presentation
    private let appVersion = AppVersion.current
    private var appName: String { appVersion.displayName }
    private var version: String { appVersion.marketingVersion }
    private var build: String { appVersion.buildNumber }

    @State private var statusMessage: String?

    init(presentation: Presentation = .window) {
        self.presentation = presentation
    }

    var body: some View {
        content
            .overlay(alignment: .bottom) {
                if let message = statusMessage {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: Capsule(style: .continuous))
                        .padding(.bottom, presentation == .window ? 14 : 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(.snappy(duration: 0.18)) {
                                statusMessage = nil
                            }
                        }
                }
            }
            .animation(.snappy(duration: 0.18), value: statusMessage)
    }

    @ViewBuilder
    private var content: some View {
        switch presentation {
        case .window:
            scrollContent
                .frame(width: 640, height: 620)
        case .settings:
            scrollContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: presentation.viewportAlignment)
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                actionRail
                detailsGrid
            }
            .frame(maxWidth: presentation.contentMaxWidth, alignment: .leading)
            .padding(.horizontal, presentation.horizontalPadding)
            .padding(.top, presentation.topPadding)
            .padding(.bottom, presentation.bottomPadding)
            .frame(maxWidth: .infinity, alignment: presentation.scrollContentAlignment)
        }
        .navigationTitle(presentation.navigationTitle)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(presentation == .settings ? .inline : .automatic)
        #endif
    }

    private var heroCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                appIcon
                heroText
                Spacer(minLength: 12)
                versionStack
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    appIcon
                    heroText
                }
                versionStack
            }
        }
        .padding(presentation.heroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(30)
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.62)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "photo.stack.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: presentation.iconSize, height: presentation.iconSize)
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .accessibilityHidden(true)
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(appName)
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(L10n.aboutSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 8) {
                AboutPill(title: L10n.aboutPlatformMacOS, systemImage: "macwindow")
                AboutPill(title: L10n.aboutPlatformiPadOS, systemImage: "ipad.landscape")
                AboutPill(title: L10n.aboutPlatformiOS, systemImage: "iphone")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var versionStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            AboutPill(title: L10n.versionLabel(version), systemImage: "number")
            AboutPill(title: L10n.buildLabel(build), systemImage: "hammer")
            AboutPill(title: L10n.aboutApacheLicenseTitle, systemImage: "checkmark.seal")
        }
    }

    private var actionRail: some View {
        GlassEffectContainer(spacing: 10) {
            FlowLayout(spacing: 8) {
                Link(destination: Self.repositoryURL) {
                    Label(L10n.aboutOpenOnGitHub, systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)

                Link(destination: Self.apacheLicenseURL) {
                    Label(L10n.aboutOpenLicense, systemImage: "doc.plaintext")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)

                Button {
                    copyVersionInfo()
                } label: {
                    Label(L10n.aboutCopyVersionInfo, systemImage: "doc.on.doc")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)

                Button {
                    copyDiagnosticsBundle()
                } label: {
                    Label(L10n.aboutCopyDiagnostics, systemImage: "stethoscope")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(24)
    }

    private var detailsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: presentation.cardMinimumWidth, maximum: 520), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            AboutInfoCard(
                title: L10n.aboutLicense,
                systemImage: "checkmark.seal",
                bodyText: L10n.aboutLicenseBody,
                minHeight: presentation.cardMinimumHeight
            ) {
                Button {
                    copyLicenseSummary()
                } label: {
                    Label(L10n.aboutCopyLicenseSummary, systemImage: "doc.on.doc")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }

            AboutInfoCard(
                title: L10n.aboutSourceRepository,
                systemImage: "curlybraces.square",
                bodyText: L10n.aboutRepositoryBody,
                minHeight: presentation.cardMinimumHeight
            ) {
                Button {
                    copyRepositoryURL()
                } label: {
                    Label(L10n.aboutCopyRepositoryURL, systemImage: "link")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }

            AboutInfoCard(
                title: L10n.aboutPlatformSupport,
                systemImage: "rectangle.3.group",
                bodyText: L10n.aboutPlatformSupportBody,
                minHeight: presentation.cardMinimumHeight
            )

            AboutInfoCard(
                title: L10n.aboutAcknowledgments,
                systemImage: "sparkles",
                bodyText: L10n.aboutReferenceProjectsBody,
                minHeight: presentation.cardMinimumHeight
            )

            AboutInfoCard(
                title: L10n.aboutLocalization,
                systemImage: "globe",
                bodyText: L10n.aboutLocalizationBody,
                minHeight: presentation.cardMinimumHeight
            )

            AboutInfoCard(
                title: L10n.aboutDesignPrinciples,
                systemImage: "slider.horizontal.3",
                bodyText: L10n.aboutDesignPrinciplesBody,
                minHeight: presentation.cardMinimumHeight
            )
        }
    }

    private func copyRepositoryURL() {
        PasteboardWriter.copy(Self.repositoryURL.absoluteString)
        statusMessage = L10n.aboutRepositoryCopied
    }

    private func copyLicenseSummary() {
        PasteboardWriter.copy("\(appName): \(L10n.aboutApacheLicenseTitle)\n\(Self.apacheLicenseURL.absoluteString)")
        statusMessage = L10n.aboutLicenseCopied
    }

    private func copyVersionInfo() {
        PasteboardWriter.copy(versionInfoPayload)
        statusMessage = L10n.aboutVersionInfoCopied
    }

    private func copyDiagnosticsBundle() {
        PasteboardWriter.copy(diagnosticsPayload)
        statusMessage = L10n.aboutDiagnosticsCopied
    }

    private var versionInfoPayload: String {
        """
        \(appName)
        \(L10n.versionLabel(version))
        \(L10n.buildLabel(build))
        \(L10n.aboutApacheLicenseTitle)
        """
    }

    private var diagnosticsPayload: String {
        """
        \(versionInfoPayload)
        \(L10n.aboutDiagnosticsOS): \(ProcessInfo.processInfo.operatingSystemVersionString)
        \(L10n.aboutDiagnosticsLocale): \(Locale.current.identifier)
        \(L10n.aboutDiagnosticsRepository): \(Self.repositoryURL.absoluteString)
        \(L10n.aboutDiagnosticsLicense): \(Self.apacheLicenseURL.absoluteString)
        """
    }

    static let repositoryURL = URL(string: "https://github.com/hosizoraru/KeiPix")!
    static let apacheLicenseURL = URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!
}

private struct AboutInfoCard<Actions: View>: View {
    let title: String
    let systemImage: String
    let bodyText: String
    let minHeight: CGFloat
    @ViewBuilder var actions: () -> Actions

    init(
        title: String,
        systemImage: String,
        bodyText: String,
        minHeight: CGFloat = 140,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.bodyText = bodyText
        self.minHeight = minHeight
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            Text(bodyText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            actions()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .keiGlass(22)
    }
}

private extension AboutInfoCard where Actions == EmptyView {
    init(
        title: String,
        systemImage: String,
        bodyText: String,
        minHeight: CGFloat = 140
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            bodyText: bodyText,
            minHeight: minHeight,
            actions: { EmptyView() }
        )
    }
}

private struct AboutPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule(style: .continuous))
    }
}

private extension AboutView.Presentation {
    var viewportAlignment: Alignment {
        switch self {
        case .window:
            .topLeading
        case .settings:
            #if os(macOS)
            .topLeading
            #else
            .top
            #endif
        }
    }

    var navigationTitle: String {
        switch self {
        case .window:
            L10n.aboutKeiPix
        case .settings:
            #if os(macOS)
            L10n.aboutKeiPix
            #else
            ""
            #endif
        }
    }

    var scrollContentAlignment: Alignment {
        switch self {
        case .window:
            .topLeading
        case .settings:
            #if os(macOS)
            .topLeading
            #else
            .top
            #endif
        }
    }

    var contentMaxWidth: CGFloat {
        switch self {
        case .window:
            592
        case .settings:
            #if os(macOS)
            1120
            #else
            860
            #endif
        }
    }

    var horizontalPadding: CGFloat {
        #if os(macOS)
        switch self {
        case .window:
            24
        case .settings:
            28
        }
        #else
        18
        #endif
    }

    var topPadding: CGFloat {
        switch self {
        case .window:
            22
        case .settings:
            #if os(macOS)
            18
            #else
            8
            #endif
        }
    }

    var bottomPadding: CGFloat {
        switch self {
        case .window:
            22
        case .settings:
            #if os(macOS)
            28
            #else
            16
            #endif
        }
    }

    var heroPadding: CGFloat {
        switch self {
        case .window:
            18
        case .settings:
            #if os(macOS)
            20
            #else
            14
            #endif
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .window:
            78
        case .settings:
            #if os(macOS)
            86
            #else
            70
            #endif
        }
    }

    var cardMinimumWidth: CGFloat {
        switch self {
        case .window:
            260
        case .settings:
            #if os(macOS)
            320
            #else
            360
            #endif
        }
    }

    var cardMinimumHeight: CGFloat {
        switch self {
        case .window:
            140
        case .settings:
            #if os(macOS)
            154
            #else
            132
            #endif
        }
    }
}

#Preview {
    AboutView()
}

#Preview("Settings") {
    AboutView(presentation: .settings)
}
