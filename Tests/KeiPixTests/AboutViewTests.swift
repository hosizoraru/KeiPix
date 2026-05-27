import Foundation
import Testing
@testable import KeiPix

@Suite("About window")
struct AboutViewTests {

    @Test("Repository URL is well-formed and points at the canonical KeiPix repo")
    func repositoryURLParses() {
        let url = AboutView.repositoryURL
        #expect(url.scheme == "https")
        #expect(url.host == "github.com")
        #expect(url.path == "/hosizoraru/KeiPix")
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
}
