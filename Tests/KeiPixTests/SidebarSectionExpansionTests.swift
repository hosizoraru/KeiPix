import Foundation
import Testing
@testable import KeiPix

@Suite("Sidebar section expansion")
struct SidebarSectionExpansionTests {
    @Test("Collapsed sidebar sections persist across reconstructed expansion state")
    @MainActor
    func collapsedSectionsPersistAcrossReconstruction() {
        let suiteName = "SidebarSectionExpansionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = SidebarSectionExpansion(defaults: defaults)
        #expect(first.isExpanded(.ranking))
        #expect(first.isExpanded(.works))

        first.setExpanded(false, for: .ranking)
        #expect(first.isExpanded(.ranking) == false)

        let restored = SidebarSectionExpansion(defaults: defaults)
        #expect(restored.isExpanded(.ranking) == false)
        #expect(restored.isExpanded(.works))

        restored.setExpanded(true, for: .ranking)
        let expandedAgain = SidebarSectionExpansion(defaults: defaults)
        #expect(expandedAgain.isExpanded(.ranking))
    }
}
