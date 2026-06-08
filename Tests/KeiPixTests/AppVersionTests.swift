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
        #expect(metadata.versionName == "0.2.0")
        #expect(metadata.buildNumber == "42")
        #expect(metadata.buildVersion == "42")
        #expect(metadata.versionCode == 42)
        #expect(metadata.versionAndBuild == "0.2.0 (42)")
        #expect(metadata.userAgentProduct == "KeiPix/0.2.0")
        #expect(metadata.desktopSafariUserAgent().contains("KeiPix/0.2.0"))
        #expect(metadata.releaseSemanticVersion == SemanticVersion(major: 0, minor: 2, patch: 0))
    }

    @Test("Dotted Apple build versions expose a stable numeric version code")
    func dottedBuildVersionsExposeVersionCode() {
        let metadata = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "0.2.0",
            "CFBundleVersion": "7.8.9"
        ])

        #expect(metadata.buildNumber == "7.8.9")
        #expect(metadata.versionCode == 7_008_009)
    }

    @Test("Version config is valid and stays aligned with XcodeGen settings")
    func versionConfigMatchesProjectSettings() throws {
        let root = try packageRoot()
        let settings = try versionSettings(root: root)
        let marketingVersion = try #require(settings["MARKETING_VERSION"])
        let buildNumber = try #require(settings["CURRENT_PROJECT_VERSION"])

        #expect(SemanticVersion(marketingVersion) != nil)
        #expect(marketingVersion.split(separator: ".").count == 3)
        #expect(try matches(buildNumber, #"^[1-9][0-9]*(\.(0|[1-9][0-9]{0,2})){0,2}$"#))

        let project = try contents(of: root, path: "project.yml")
        #expect(project.contains("MARKETING_VERSION: \"\(marketingVersion)\""))
        #expect(project.contains("CURRENT_PROJECT_VERSION: \"\(buildNumber)\""))
    }

    @Test("Version settings script exposes release aliases for scripts and feeds")
    func versionSettingsScriptExportsReleaseAliases() throws {
        let root = try packageRoot()
        let settings = try versionSettings(root: root)
        let marketingVersion = try #require(settings["MARKETING_VERSION"])
        let buildNumber = try #require(settings["CURRENT_PROJECT_VERSION"])

        let output = try run(["/bin/bash", "script/version_settings.sh", "--print-json"], in: root)
        let data = try #require(output.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["marketingVersion"] as? String == marketingVersion)
        #expect(json["versionName"] as? String == marketingVersion)
        #expect(json["buildNumber"] as? String == buildNumber)
        #expect(intValue(json["versionCode"]) == expectedVersionCode(from: buildNumber))
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
        let liveContainer = try contents(of: root, path: "script/generate_livecontainer_apps_nightly.sh")
        let workflow = try contents(of: root, path: ".github/workflows/macos-build.yml")

        #expect(buildAndRun.contains("version_settings.sh"))
        #expect(buildAndRun.contains("CFBundleShortVersionString"))
        #expect(buildAndRun.contains("CFBundleVersion"))
        #expect(release.contains("version_settings.sh"))
        #expect(release.contains("KEIPIX_MARKETING_VERSION"))
        #expect(release.contains("KEIPIX_BUILD_NUMBER"))
        #expect(release.contains("git describe") == false)
        #expect(liveContainer.contains("version_settings.sh"))
        #expect(liveContainer.contains("KEIPIX_VERSION_NAME"))
        #expect(liveContainer.contains("KEIPIX_VERSION_CODE"))
        #expect(workflow.contains("script/version_settings.sh"))
        #expect(workflow.contains("script/generate_livecontainer_apps_nightly.sh"))
        #expect(workflow.contains("apps_nightly.json"))
        #expect(workflow.contains("steps.version.outputs.build"))
    }

    @Test("LiveContainer nightly source uses stable release assets and shared version metadata")
    func liveContainerNightlySourceUsesSharedVersionMetadata() throws {
        let root = try packageRoot()
        let settings = try versionSettings(root: root)
        let marketingVersion = try #require(settings["MARKETING_VERSION"])
        let buildNumber = try #require(settings["CURRENT_PROJECT_VERSION"])
        let versionCode = expectedVersionCode(from: buildNumber)
        let source = try jsonObject(at: root.appending(path: "apps_nightly.json"))

        #expect(source["name"] as? String == "KeiPix Nightly")
        #expect(source["identifier"] as? String == "com.keipix.source.nightly")
        #expect((source["sourceURL"] as? String)?.contains("/releases/download/nightly/apps_nightly.json") == true)
        #expect((source["website"] as? String)?.hasPrefix("https://github.com/hosizoraru/KeiPix") == true)

        let apps = try #require(source["apps"] as? [[String: Any]])
        try assertLiveContainerApp(
            in: apps,
            name: "KeiPix iOS",
            bundleIdentifier: "com.keipix.client.ios",
            ipaName: "KeiPix-iOS-\(marketingVersion)-build.\(buildNumber)-unsigned.ipa",
            marketingVersion: marketingVersion,
            buildNumber: buildNumber,
            versionCode: versionCode
        )
        try assertLiveContainerApp(
            in: apps,
            name: "KeiPix iPadOS",
            bundleIdentifier: "com.keipix.client.ipad",
            ipaName: "KeiPix-iPadOS-\(marketingVersion)-build.\(buildNumber)-unsigned.ipa",
            marketingVersion: marketingVersion,
            buildNumber: buildNumber,
            versionCode: versionCode
        )
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

    private func expectedVersionCode(from buildNumber: String) -> Int {
        let components = buildNumber.split(separator: ".").compactMap { Int($0) }
        guard let first = components.first else { return 0 }
        guard components.count > 1 else { return first }
        return components.prefix(3).reduce(0) { partial, component in
            partial * 1_000 + component
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertLiveContainerApp(
        in apps: [[String: Any]],
        name: String,
        bundleIdentifier: String,
        ipaName: String,
        marketingVersion: String,
        buildNumber: String,
        versionCode: Int
    ) throws {
        let app = try #require(apps.first { $0["bundleIdentifier"] as? String == bundleIdentifier })
        #expect(app["name"] as? String == name)
        #expect(app["version"] as? String == marketingVersion)
        #expect(app["versionName"] as? String == marketingVersion)
        #expect(app["buildNumber"] as? String == buildNumber)
        #expect(intValue(app["versionCode"]) == versionCode)
        #expect(app["downloadURL"] as? String == "https://github.com/hosizoraru/KeiPix/releases/download/nightly/\(ipaName)")
        #expect((app["localizedDescription"] as? String)?.isEmpty == false)

        let versions = try #require(app["versions"] as? [[String: Any]])
        let latest = try #require(versions.first)
        #expect(latest["version"] as? String == marketingVersion)
        #expect(latest["versionName"] as? String == marketingVersion)
        #expect(latest["buildNumber"] as? String == buildNumber)
        #expect(intValue(latest["versionCode"]) == versionCode)
        #expect(latest["downloadURL"] as? String == "https://github.com/hosizoraru/KeiPix/releases/download/nightly/\(ipaName)")
    }

    private func run(_ arguments: [String], in root: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: arguments[0])
        process.arguments = Array(arguments.dropFirst())
        process.currentDirectoryURL = root

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AppVersionTestError.commandFailed(arguments.joined(separator: " "), error)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
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
    case commandFailed(String, String)
}
