import Testing
@testable import KeiPix

struct BatchDownloadModelsTests {
    @Test("Loaded feed batch download can expand across next pages")
    func loadedFeedPlanCanFetchNextPages() {
        let plan = BatchDownloadPlan.make(
            scope: .loadedFeed,
            loadedArtworkCount: 24,
            hasNextPage: true,
            requestedLimit: 80,
            requestedRemotePageLimit: 4
        )

        #expect(plan.maxLimit == 100)
        #expect(plan.limit == 80)
        #expect(plan.allowsRemotePages)
        #expect(plan.remotePageLimit == 4)
        #expect(plan.estimatedRemotePageRequests == 4)
    }

    @Test("Selected batch download stays bounded to selected works")
    func selectedPlanDoesNotFetchNextPages() {
        let plan = BatchDownloadPlan.make(
            scope: .selectedWorks,
            loadedArtworkCount: 6,
            hasNextPage: true,
            requestedLimit: 80,
            requestedRemotePageLimit: 4
        )

        #expect(plan.maxLimit == 6)
        #expect(plan.limit == 6)
        #expect(plan.allowsRemotePages == false)
        #expect(plan.remotePageLimit == 0)
        #expect(plan.estimatedRemotePageRequests == 0)
    }
}
