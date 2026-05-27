import Foundation
import Testing
@testable import KeiPix

@Suite("Release update checker")
struct ReleaseUpdateCheckerTests {

    @Test("Decodes the slice of GitHub's release JSON the banner consumes")
    func decodesGitHubReleasePayload() throws {
        let json = """
        {
            "tag_name": "v0.2.0",
            "name": "KeiPix 0.2.0",
            "body": "First public alpha.",
            "html_url": "https://github.com/hosizoraru/KeiPix/releases/tag/v0.2.0",
            "published_at": "2026-05-15T10:00:00Z",
            "draft": false,
            "prerelease": false
        }
        """.data(using: .utf8)!

        let decoded = try ReleaseUpdateChecker.decodeRelease(from: json)
        #expect(decoded.tagName == "v0.2.0")
        #expect(decoded.displayName == "KeiPix 0.2.0")
        #expect(decoded.version == SemanticVersion(major: 0, minor: 2, patch: 0))
        #expect(decoded.body == "First public alpha.")
        #expect(decoded.htmlURL.absoluteString == "https://github.com/hosizoraru/KeiPix/releases/tag/v0.2.0")
        #expect(decoded.publishedAt != nil)
    }

    @Test("Falls back to tag name when GitHub's name field is empty")
    func falsBackToTagNameWhenNameIsEmpty() throws {
        let json = """
        {
            "tag_name": "0.3.0",
            "name": "",
            "body": "",
            "html_url": "https://github.com/hosizoraru/KeiPix/releases/tag/0.3.0"
        }
        """.data(using: .utf8)!

        let decoded = try ReleaseUpdateChecker.decodeRelease(from: json)
        #expect(decoded.displayName == "0.3.0")
        #expect(decoded.body == "")
    }

    @Test("Throws malformedTag when GitHub publishes a tag we can't parse")
    func throwsOnMalformedTag() {
        let json = """
        {
            "tag_name": "not-a-version",
            "html_url": "https://github.com/hosizoraru/KeiPix/releases/tag/garbage"
        }
        """.data(using: .utf8)!

        #expect(throws: ReleaseUpdateCheckerError.self) {
            _ = try ReleaseUpdateChecker.decodeRelease(from: json)
        }
    }

    @Test("ReleaseUpdate round-trips through Codable so the persisted snapshot survives a relaunch")
    func releaseUpdateRoundTrips() throws {
        let original = ReleaseUpdate(
            version: SemanticVersion(major: 0, minor: 2, patch: 0),
            tagName: "v0.2.0",
            displayName: "KeiPix 0.2.0",
            body: "Notes",
            htmlURL: URL(string: "https://github.com/hosizoraru/KeiPix/releases/tag/v0.2.0")!,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(ReleaseUpdate.self, from: data)
        #expect(restored == original)
    }
}
