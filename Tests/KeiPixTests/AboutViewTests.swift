import Foundation
import Testing
@testable import KeiPix

@Suite("About window")
struct AboutViewTests {

    @Test("Repository URL is well-formed and points at the canonical KeiPix repo")
    @MainActor
    func repositoryURLParses() {
        let url = AboutView.repositoryURL
        #expect(url.scheme == "https")
        #expect(url.host == "github.com")
        #expect(url.path == "/hosizoraru/KeiPix")
    }

    @Test("Apache license URL points at the canonical license text")
    @MainActor
    func apacheLicenseURLParses() {
        let url = AboutView.apacheLicenseURL
        #expect(url.scheme == "https")
        #expect(url.host == "www.apache.org")
        #expect(url.path == "/licenses/LICENSE-2.0")
    }

    @Test("Version label format substitutes the supplied value")
    func versionLabelInsertsValue() {
        let label = L10n.versionLabel("1.2.3")
        #expect(label.contains("1.2.3"))
    }

    @Test("Build label format substitutes the supplied value")
    func buildLabelInsertsValue() {
        let label = L10n.buildLabel("42")
        #expect(label.contains("42"))
    }

    @Test("Revision label format substitutes the supplied value")
    func revisionLabelInsertsValue() {
        let label = L10n.revisionLabel("v1.2.3+4")
        #expect(label.contains("v1.2.3+4"))
    }

    @Test("License metadata is Apache 2 across repo and app bundles")
    func licenseMetadataIsApache2() throws {
        let root = try packageRoot()
        let license = try String(contentsOf: root.appending(path: "LICENSE"), encoding: .utf8)
        let readme = try String(contentsOf: root.appending(path: "README.md"), encoding: .utf8)

        #expect(license.contains("Apache License"))
        #expect(license.contains("Version 2.0, January 2004"))
        #expect(readme.contains("Apache License, Version 2.0"))
        #expect(readme.contains("[LICENSE](LICENSE)"))

        for plist in ["App/Info.plist", "App/Info-iPadOS.plist", "App/Info-iOS.plist"] {
            let contents = try String(contentsOf: root.appending(path: plist), encoding: .utf8)
            #expect(contents.contains("KeiPix contributors"))
            #expect(contents.contains("Apache-2.0"), "\(plist) should advertise Apache-2.0")
            #expect(contents.contains("All rights reserved") == false, "\(plist) should not keep the pre-license copyright wording")
        }
    }

    @Test("About copy and settings entry stay discoverable")
    func aboutSurfaceIsDiscoverable() throws {
        let root = try packageRoot()
        let aboutView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/AboutView.swift"),
            encoding: .utf8
        )
        let settingsView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SettingsView.swift"),
            encoding: .utf8
        )
        let settingsCategory = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/Settings/SettingsCategory.swift"),
            encoding: .utf8
        )
        let mobileContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )
        let macOSRunner = try String(
            contentsOf: root.appending(path: "script/build_and_run.sh"),
            encoding: .utf8
        )
        let macOSReleaseBuilder = try String(
            contentsOf: root.appending(path: "script/build_release_app.sh"),
            encoding: .utf8
        )
        let macOSIconBuilder = try String(
            contentsOf: root.appending(path: "script/macos_app_icon.sh"),
            encoding: .utf8
        )
        let appIconView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/KeiPixAppIconView.swift"),
            encoding: .utf8
        )
        let localizable = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Resources/Localizable.xcstrings"),
            encoding: .utf8
        )

        #expect(aboutView.contains("GlassEffectContainer(spacing: 10)"))
        #expect(aboutView.contains("AboutView(presentation: .settings)"))
        #expect(aboutView.contains(".buttonStyle(.glassProminent)"))
        #expect(aboutView.contains("L10n.aboutApacheLicenseTitle"))
        #expect(aboutView.contains("private var metadataRail: some View"))
        #expect(aboutView.contains("private var versionStack: some View") == false)
        #expect(aboutView.contains("ViewThatFits(in: .horizontal)"))
        #expect(aboutView.contains("HStack(spacing: 8)"))
        #expect(aboutView.contains("FlowLayout(spacing: 8)"))
        #expect(aboutView.contains("versionPill"))
        #expect(aboutView.contains("buildPill"))
        #expect(aboutView.contains("licensePill"))
        #expect(aboutView.contains("private var revisionPill") == false)
        #expect(aboutView.contains("L10n.revisionLabel(revision)"))
        #expect(aboutView.contains("appVersion.gitShortCommit"))
        #expect(aboutView.contains("var viewportAlignment: Alignment"))
        #expect(aboutView.contains("var navigationTitle: String"))
        #expect(aboutView.contains(".navigationTitle(presentation.navigationTitle)"))
        #expect(aboutView.contains(".navigationBarTitleDisplayMode(presentation == .settings ? .inline : .automatic)"))
        #expect(aboutView.contains("var scrollContentAlignment: Alignment"))
        #expect(aboutView.contains("var cardMinimumHeight: CGFloat"))
        #expect(aboutView.contains("#else\n            860"))
        #expect(aboutView.contains("#else\n            360"))
        #expect(aboutView.contains("L10n.aboutPlatformMacOS"))
        #expect(aboutView.contains("L10n.aboutPlatformiPadOS"))
        #expect(aboutView.contains("L10n.aboutPlatformiOS"))
        #expect(aboutView.contains("L10n.aboutDiagnosticsOS"))
        #expect(aboutView.contains("L10n.aboutDiagnosticsLocale"))
        #expect(aboutView.contains("L10n.aboutDiagnosticsRepository"))
        #expect(aboutView.contains("L10n.aboutDiagnosticsLicense"))
        #expect(aboutView.contains("L10n.aboutDiagnosticsBuildCode"))
        #expect(aboutView.contains("L10n.aboutDiagnosticsBuildSource"))
        #expect(aboutView.contains("L10n.aboutDiagnosticsCommit"))
        #expect(aboutView.contains("KeiPixAppIconView(cornerRadius: 24)"))
        #expect(aboutView.contains(#"Image(systemName: "photo.stack.fill")"#) == false)
        #expect(appIconView.contains(#"static let iconAssetName = "keipixiv""#))
        #expect(appIconView.contains("bundle.image(forResource: iconAssetName)"))
        #expect(appIconView.contains(#"withExtension: "icns""#))
        #expect(appIconView.contains("NSImage.applicationIconName"))
        #expect(appIconView.contains("CFBundleIconFiles"))
        #expect(appIconView.contains("UIImage(contentsOfFile: url.path)"))
        #expect(appIconView.contains("UIImage(named: iconAssetName") == false)
        #expect(appIconView.contains("private var fallbackIcon: some View"))
        #expect(aboutView.contains(#"AboutPill(title: "macOS 26""#) == false)
        #expect(aboutView.contains(#"OS: \("#) == false)
        #expect(aboutView.contains(#"Locale: \("#) == false)
        #expect(aboutView.contains(#"Repository: \("#) == false)
        #expect(aboutView.contains(#"License: \("#) == false)
        #expect(settingsView.contains("case .about:"))
        #expect(settingsView.contains("AboutView(presentation: .settings)"))
        #expect(settingsView.contains("VisualQALaunchArgument.contains(.about)"))
        #expect(settingsCategory.contains("VisualQALaunchArgument.contains(.about)"))
        #expect(mobileContentView.contains("isSettingsSheetPresented = true"))
        #expect(macOSRunner.contains("--visual-qa-about|visual-qa-about"))
        #expect(macOSRunner.contains("open_app --visual-qa-about"))
        #expect(macOSRunner.contains("APP_PROCESS_SUFFIX"))
        #expect(macOSRunner.contains("terminate_running_app"))
        #expect(macOSRunner.contains("assert_app_running"))
        #expect(!macOSRunner.contains("pkill -x \"$APP_NAME\""))
        #expect(!macOSRunner.contains("pgrep -x \"$APP_NAME\""))
        #expect(macOSRunner.contains("source \"$ROOT_DIR/script/macos_app_icon.sh\""))
        #expect(macOSRunner.contains("keipix_compile_macos_app_icon \"$ROOT_DIR\" \"$APP_RESOURCES\" \"$MIN_SYSTEM_VERSION\" \"$INFO_PLIST\""))
        #expect(macOSReleaseBuilder.contains("source \"$ROOT_DIR/script/macos_app_icon.sh\""))
        #expect(macOSReleaseBuilder.contains("keipix_compile_macos_app_icon \"$ROOT_DIR\" \"$APP_RESOURCES\" \"$MIN_SYSTEM_VERSION\" \"$INFO_PLIST\""))
        #expect(macOSIconBuilder.contains("xcrun actool"))
        #expect(macOSIconBuilder.contains("--app-icon \"$app_icon_name\""))
        #expect(macOSIconBuilder.contains("CFBundleIconFile"))
        #expect(macOSIconBuilder.contains("CFBundleIconName"))
        #expect(macOSIconBuilder.contains(".icns"))
        #expect(SettingsCategory.allCases.contains(.about))
        #expect(SettingsCategory.about.searchTerms.contains(L10n.aboutApacheLicenseTitle))

        #expect(localizable.contains("\"KeiPix is a native Pixiv client for macOS, iPadOS, and iOS.\""))
        #expect(localizable.contains("\"value\": \"KeiPix 是面向 macOS、iPadOS 和 iOS 的原生 Pixiv 客户端。\""))
        #expect(localizable.contains("\"value\": \"打开许可证\""))
        #expect(localizable.contains("\"value\": \"复制版本信息\""))
        #expect(localizable.contains("\"value\": \"构建码\""))
        #expect(localizable.contains("\"value\": \"修订 %@\""))
        #expect(localizable.contains("\"value\": \"构建来源\""))
        #expect(localizable.contains("\"value\": \"提交\""))
        #expect(localizable.contains("\"value\": \"复制许可证摘要\""))
        #expect(localizable.contains("\"value\": \"复制仓库 URL\""))
        #expect(localizable.contains("\"value\": \"平台支持\""))
        #expect(localizable.contains("\"value\": \"设计原则\""))
        #expect(localizable.contains("\"value\": \"Pixez 使用 GPL-3.0，Pixes 使用 MIT 许可；二者仅作为行为参考。KeiPix 全部源码为原创 Swift；NativeBoundaryTests 会拦截参考客户端实现路径。\""))
        #expect(localizable.contains("Pixez 与 Pixes 为 GPL 许可") == false)
        #expect(localizable.contains("\"value\": \"项目在 GitHub 上开放开发。你可以在仓库中提交问题、查看提交，或审阅 Apache-2.0 源码。\""))
    }

    private func packageRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: candidate.appending(path: "Package.swift").path(percentEncoded: false)) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        var fileBased = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: fileBased.appending(path: "Package.swift").path(percentEncoded: false)) {
                return fileBased
            }
            fileBased.deleteLastPathComponent()
        }

        throw AboutViewTestError.packageRootNotFound
    }
}

private enum AboutViewTestError: Error {
    case packageRootNotFound
}
