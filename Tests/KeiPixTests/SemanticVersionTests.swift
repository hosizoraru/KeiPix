import Foundation
import Testing
@testable import KeiPix

@Suite("Semantic version comparator")
struct SemanticVersionTests {

    @Test("Three-component releases parse and round-trip cleanly")
    func threeComponentRoundTrip() throws {
        let parsed = try #require(SemanticVersion("1.2.3"))
        #expect(parsed.major == 1)
        #expect(parsed.minor == 2)
        #expect(parsed.patch == 3)
        #expect(parsed.prerelease == nil)
        #expect(parsed.displayString == "1.2.3")
    }

    @Test("Leading v / V is stripped so v0.1.0 and 0.1.0 compare equal")
    func leadingVeeStripped() throws {
        let lower = try #require(SemanticVersion("v0.1.0"))
        let upper = try #require(SemanticVersion("V0.1.0"))
        let plain = try #require(SemanticVersion("0.1.0"))
        #expect(lower == plain)
        #expect(upper == plain)
    }

    @Test("Two-component versions pad with a trailing .0")
    func twoComponentPadding() throws {
        let parsed = try #require(SemanticVersion("0.1"))
        #expect(parsed == SemanticVersion(major: 0, minor: 1, patch: 0))
    }

    @Test("Build metadata after + is dropped before parsing")
    func buildMetadataDropped() throws {
        let parsed = try #require(SemanticVersion("0.2.0+commit.abc123"))
        #expect(parsed == SemanticVersion(major: 0, minor: 2, patch: 0))
    }

    @Test("Pre-release tag is preserved and sorts before final")
    func prereleasesSortBeforeFinal() throws {
        let candidate = try #require(SemanticVersion("0.2.0-rc.1"))
        let final = try #require(SemanticVersion("0.2.0"))
        #expect(candidate.prerelease == "rc.1")
        #expect(candidate < final)
    }

    @Test("Patch ordering: 0.1.0 < 0.1.1 < 0.2.0")
    func patchOrdering() throws {
        let lhs = try #require(SemanticVersion("0.1.0"))
        let mid = try #require(SemanticVersion("0.1.1"))
        let rhs = try #require(SemanticVersion("0.2.0"))
        #expect(lhs < mid)
        #expect(mid < rhs)
    }

    @Test("Equal versions compare equal regardless of leading v")
    func equalityIgnoresLeadingVee() throws {
        let lhs = try #require(SemanticVersion("v0.1.0"))
        let rhs = try #require(SemanticVersion("0.1.0"))
        #expect(lhs == rhs)
        #expect((lhs < rhs) == false)
        #expect((rhs < lhs) == false)
    }

    @Test("Empty / non-numeric strings fail to parse rather than producing zeros")
    func parserRejectsGarbage() {
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("   ") == nil)
        #expect(SemanticVersion("not.a.version") == nil)
        #expect(SemanticVersion("1.2.3.4") == nil)
    }

    @Test("Decoding wraps the parser so JSON tag_name decoding can fail loud")
    func codableDecodesValidString() throws {
        let json = Data(#""0.2.0""#.utf8)
        let decoded = try JSONDecoder().decode(SemanticVersion.self, from: json)
        #expect(decoded == SemanticVersion(major: 0, minor: 2, patch: 0))
    }

    @Test("Decoding rejects garbage so a malformed tag_name surfaces instead of silently downgrading")
    func codableRejectsGarbage() {
        let json = Data(#""potato""#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(SemanticVersion.self, from: json)
        }
    }
}
