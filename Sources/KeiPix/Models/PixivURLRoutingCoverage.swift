import Foundation

struct PixivURLRoutingSample: Identifiable {
    let id: String
    let input: String
    let expectedDestination: PixivWebDestination

    var passes: Bool {
        PixivWebLinkResolver.firstDestination(in: input) == expectedDestination
    }
}

enum PixivURLRoutingCoverage {
    static let samples: [PixivURLRoutingSample] = [
        PixivURLRoutingSample(
            id: "artwork-web",
            input: "Open https://www.pixiv.net/artworks/123456.",
            expectedDestination: .artwork(123456)
        ),
        PixivURLRoutingSample(
            id: "creator-web",
            input: "<https://www.pixiv.net/users/789>",
            expectedDestination: .user(789)
        ),
        PixivURLRoutingSample(
            id: "tag-web",
            input: "https://www.pixiv.net/tags/OC/artworks",
            expectedDestination: .tag("OC")
        ),
        PixivURLRoutingSample(
            id: "pixiv-scheme",
            input: "pixiv://illusts/345",
            expectedDestination: .artwork(345)
        ),
        PixivURLRoutingSample(
            id: "keipix-nested",
            input: "keipix://open?url=https://www.pixiv.net/tags/OC",
            expectedDestination: .tag("OC")
        ),
        PixivURLRoutingSample(
            id: "pixivision",
            input: "https://www.pixivision.net/en/a/10000",
            expectedDestination: .pixivisionArticle(
                id: 10000,
                url: URL(string: "https://www.pixivision.net/en/a/10000")!
            )
        )
    ]

    static var passes: Bool {
        samples.allSatisfy(\.passes)
    }

    static var summary: String {
        let passedCount = samples.filter(\.passes).count
        return "\(passedCount)/\(samples.count)"
    }
}
