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
        let localizable = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Resources/Localizable.xcstrings"),
            encoding: .utf8
        )

        #expect(aboutView.contains("GlassEffectContainer(spacing: 10)"))
        #expect(aboutView.contains("AboutView(presentation: .settings)"))
        #expect(aboutView.contains(".buttonStyle(.glassProminent)"))
        #expect(aboutView.contains("L10n.aboutApacheLicenseTitle"))
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
        #expect(aboutView.contains(#"AboutPill(title: "macOS 26""#) == false)
        #expect(aboutView.contains(#"OS: \("#) == false)
        #expect(aboutView.contains(#"Locale: \("#) == false)
        #expect(aboutView.contains(#"Repository: \("#) == false)
        #expect(aboutView.contains(#"License: \("#) == false)
        #expect(settingsView.contains("case .about:"))
        #expect(settingsView.contains("AboutView(presentation: .settings)"))
        #expect(SettingsCategory.allCases.contains(.about))
        #expect(SettingsCategory.about.searchTerms.contains(L10n.aboutApacheLicenseTitle))

        #expect(localizable.contains("\"KeiPix is a native Pixiv client for macOS, iPadOS, and iOS.\""))
        #expect(localizable.contains("\"value\": \"KeiPix 是面向 macOS、iPadOS 和 iOS 的原生 Pixiv 客户端。\""))
        #expect(localizable.contains("\"value\": \"打开许可证\""))
        #expect(localizable.contains("\"value\": \"复制版本信息\""))
        #expect(localizable.contains("\"value\": \"复制许可证摘要\""))
        #expect(localizable.contains("\"value\": \"复制仓库 URL\""))
        #expect(localizable.contains("\"value\": \"平台支持\""))
        #expect(localizable.contains("\"value\": \"设计原则\""))
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
