import Foundation
import Testing
@testable import KeiPix

@Suite("MyPixiv endpoint wiring")
struct MyPixivEndpointTests {
    @Test("User MyPixiv endpoint targets the requested user")
    func userMyPixivURLUsesUserID() throws {
        let url = try PixivAPI.myPixivUsersURL(userID: 42)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/v1/user/mypixiv")
        #expect(components.queryItems?.contains(URLQueryItem(name: "user_id", value: "42")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "filter", value: "for_android")) == true)
    }

    @Test("Illustration MyPixiv endpoint uses Pixiv's v2 path")
    func illustMyPixivURLUsesV2Path() throws {
        let url = try PixivAPI.myPixivIllustsURL(userID: 42)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/v2/illust/mypixiv")
        #expect(components.queryItems?.contains(URLQueryItem(name: "user_id", value: "42")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "filter", value: "for_android")) == true)
    }

    @Test("Novel MyPixiv endpoint uses Pixeval's v2 path")
    func novelMyPixivURLUsesV2Path() throws {
        let url = try PixivAPI.myPixivNovelsURL(userID: 42)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/v2/novel/mypixiv")
        #expect(components.queryItems?.contains(URLQueryItem(name: "user_id", value: "42")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "filter", value: "for_android")) == true)
    }

    @Test("User profile decodes MyPixiv count")
    func userProfileDecodesMyPixivCount() throws {
        let payload = """
        {
          "webpage": "https://example.com",
          "region": "Tokyo",
          "job": "Illustrator",
          "total_follow_users": 12,
          "total_mypixiv_users": 34,
          "total_illusts": 56,
          "total_manga": 7,
          "total_illust_bookmarks_public": 890,
          "background_image_url": null,
          "twitter_url": null,
          "pawoo_url": null,
          "is_premium": false
        }
        """

        let profile = try JSONDecoder().decode(PixivUserProfile.self, from: Data(payload.utf8))
        #expect(profile.totalMyPixivUsers == 34)
    }

    @Test("Creator MyPixiv list mode keeps a stable key and title")
    func creatorMyPixivModeUsesStableKeyAndTitle() {
        let user = PixivUser(id: 42, name: "Creator", account: "creator", avatarURL: nil, isFollowed: true)
        let mode = UserPreviewListMode.userMyPixiv(user)

        #expect(mode.key == "user-mypixiv-42")
        #expect(mode.title.contains(L10n.myPixivUsers))
        #expect(mode.usesRestrictPicker == false)
    }
}
