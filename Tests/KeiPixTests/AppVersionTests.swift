import Foundation
import Testing
@testable import KeiPix

@Suite("App version metadata")
struct AppVersionTests {
    @Test("Runtime metadata exposes bundle version, build number, and User-Agent product")
    func runtimeMetadataUsesBundleInfo() {
        let metadata = AppVersion(infoDictionary: [
            "CFBundleDisplayName": "KeiPix Beta",
            "CFBundleName": "KeiPix",
            "CFBundleShortVersionString": "0.2.0",
            "CFBundleVersion": "42"
        ])

        #expect(metadata.displayName == "KeiPix Beta")
        #expect(metadata.marketingVersion == "0.2.0")
        #expect(metadata.buildNumber == "42")
        #expect(metadata.versionAndBuild == "0.2.0 (42)")
        #expect(metadata.userAgentProduct == "KeiPix/0.2.0")
        #expect(metadata.desktopSafariUserAgent().contains("KeiPix/0.2.0"))
        #expect(metadata.releaseSemanticVersion == SemanticVersion(major: 0, minor: 2, patch: 0))
    }

    @Test("Version config is valid and stays aligned with XcodeGen settings")
    func versionConfigMatchesProjectSettings() throws {
        let root = try packageRoot()
        let settings = try versionSettings(root: root)
        let marketingVersion = try #require(settings["MARKETING_VERSION"])
        let buildNumber = try #require(settings["CURRENT_PROJECT_VERSION"])

        #expect(SemanticVersion(marketingVersion) != nil)
        #expect(marketingVersion.split(separator: ".").count == 3)
        #expect(try matches(buildNumber, #"^[1-9][0-9]*(\.[0-9]+){0,2}$"#))

        let project = try contents(of: root, path: "project.yml")
        #expect(project.contains("MARKETING_VERSION: \"\(marketingVersion)\""))
        #expect(project.contains("CURRENT_PROJECT_VERSION: \"\(buildNumber)\""))
    }

    @Test("Bundle plist templates consume Xcode build settings for version fields")
    func plistTemplatesUseBuildSettings() throws {
        let root = try packageRoot()
        for plist in ["App/Info.plist", "App/Info-iOS.plist", "App/Info-iPadOS.plist"] {
            let contents = try contents(of: root, path: plist)
            #expect(contents.contains("<key>CFBundleShortVersionString</key>"))
            #expect(contents.contains("<string>$(MARKETING_VERSION)</string>"), "\(plist) should use MARKETING_VERSION")
            #expect(contents.contains("<key>CFBundleVersion</key>"))
            #expect(contents.contains("<string>$(CURRENT_PROJECT_VERSION)</string>"), "\(plist) should use CURRENT_PROJECT_VERSION")
        }
    }

    @Test("Build scripts and CI read the shared version settings")
    func scriptsUseSharedVersionSettings() throws {
        let root = try packageRoot()
        let buildAndRun = try contents(of: root, path: "script/build_and_run.sh")
        let release = try contents(of: root, path: "script/build_release_app.sh")
        let workflow = try contents(of: root, path: ".github/workflows/macos-build.yml")

        #expect(buildAndRun.contains("version_settings.sh"))
        #expect(buildAndRun.contains("CFBundleShortVersionString"))
        #expect(buildAndRun.contains("CFBundleVersion"))
        #expect(release.contains("version_settings.sh"))
        #expect(release.contains("KEIPIX_MARKETING_VERSION"))
        #expect(release.contains("KEIPIX_BUILD_NUMBER"))
        #expect(release.contains("git describe") == false)
        #expect(workflow.contains("script/version_settings.sh"))
        #expect(workflow.contains("steps.version.outputs.build"))
    }

    @Test("Source uses AppVersion instead of hard-coded KeiPix slash 1.0 user agents")
    func sourceDoesNotHardCodeLegacyUserAgentVersion() throws {
        let root = try packageRoot()
        let offenders = try swiftSourceFiles(in: root.appending(path: "Sources"))
            .filter { url in
                (try? String(contentsOf: url, encoding: .utf8).contains("KeiPix/1.0")) == true
            }
            .map { $0.path(percentEncoded: false).replacingOccurrences(of: root.path(percentEncoded: false) + "/", with: "") }

        #expect(offenders.isEmpty, "Hard-coded user agents: \(offenders.joined(separator: ", "))")
    }

    private func versionSettings(root: URL) throws -> [String: String] {
        let contents = try contents(of: root, path: "Config/AppVersion.xcconfig")
        var settings: [String: String] = [:]
        for rawLine in contents.split(separator: "\n") {
            let line = rawLine.split(separator: "//", maxSplits: 1, omittingEmptySubsequences: false).first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard line.isEmpty == false else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }
            settings[parts[0]] = parts[1]
        }
        return settings
    }

    private func matches(_ value: String, _ pattern: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range)?.range == range
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

        throw AppVersionTestError.packageRootNotFound
    }

    private func contents(of root: URL, path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    private func swiftSourceFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}

private enum AppVersionTestError: Error {
    case packageRootNotFound
}
