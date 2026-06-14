#if DEBUG
import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum VisualQASampleData {
    static let novelSeriesVisualQAID = 77_001
    static let novelSeriesVisualQATitle = "雨夜，然后捡到花嫁性偶"

    static let guestSession: PixivSession = {
        let payload = """
        {
          "accessToken": "guest-preview-access-token",
          "refreshToken": "guest-preview-refresh-token",
          "user": {
            "id": "5000",
            "name": "Guest Preview",
            "account": "guest_preview",
            "is_premium": false
          }
        }
        """
        return try! JSONDecoder().decode(PixivSession.self, from: Data(payload.utf8))
    }()

    static let sampleSession: PixivSession = {
        let payload = """
        {
          "accessToken": "visual-qa-access-token",
          "refreshToken": "visual-qa-refresh-token",
          "user": {
            "id": "5001",
            "name": "Visual QA",
            "account": "visual_qa",
            "is_premium": false
          }
        }
        """
        return try! JSONDecoder().decode(PixivSession.self, from: Data(payload.utf8))
    }()

    static let pixivActivityItems: [PixivActivityItem] = [
        PixivActivityItem(
            id: "visual-activity-posted-1",
            kind: .postedArtwork,
            actor: PixivActivityActor(userID: 5002, name: "夜更かし", avatarURL: nil),
            target: PixivActivityTarget(
                kind: .artwork,
                id: "93700",
                title: "星の降る通学路",
                url: URL(string: "https://www.pixiv.net/artworks/93700"),
                thumbnailURL: nil,
                thumbnailAspectRatio: 0.74,
                author: PixivActivityActor(userID: 5002, name: "夜更かし", avatarURL: nil)
            ),
            occurredAt: Date(timeIntervalSinceNow: -420),
            summary: "フォロー中のクリエイターが新しいイラストを投稿しました。"
        ),
        PixivActivityItem(
            id: "visual-activity-bookmark-1",
            kind: .bookmarkedArtwork,
            actor: PixivActivityActor(userID: 5003, name: "Mika Archive", avatarURL: nil),
            target: PixivActivityTarget(
                kind: .artwork,
                id: "93710",
                title: "Bookmark sheet QA sample",
                url: URL(string: "https://www.pixiv.net/artworks/93710"),
                thumbnailURL: nil,
                thumbnailAspectRatio: 1.45,
                author: PixivActivityActor(userID: 5010, name: "Archive Artist", avatarURL: nil)
            ),
            occurredAt: Date(timeIntervalSinceNow: -2_400),
            summary: "公開ブックマークに追加された作品です。",
            bookmarkTag: PixivActivityBookmarkTag(name: "生徒会にも穴はある！", url: nil)
        ),
        PixivActivityItem(
            id: "visual-activity-follow-1",
            kind: .followedUser,
            actor: PixivActivityActor(userID: 5004, name: "Blue Route", avatarURL: nil),
            target: PixivActivityTarget(
                kind: .user,
                id: "5005",
                title: "朝焼け工房",
                url: URL(string: "https://www.pixiv.net/users/5005"),
                thumbnailURL: nil
            ),
            occurredAt: Date(timeIntervalSinceNow: -8_800),
            summary: "フォロー中のユーザーが別のクリエイターをフォローしました。"
        ),
        PixivActivityItem(
            id: "visual-activity-unknown-1",
            kind: .unknown,
            actor: PixivActivityActor(userID: 5006, name: "Signal", avatarURL: nil),
            target: nil,
            occurredAt: Date(timeIntervalSinceNow: -18_000),
            summary: "Pixiv Web 側から届いた補助的な動向です。"
        )
    ]

    static let artworkDetailSocialArtwork = decodeArtwork(
        id: 93700,
        title: "Detail reader rail QA manga",
        createdAt: 1_779_638_400,
        pageCount: 12,
        width: 1400,
        height: 1900,
        tags: ["manga", "AI", "series", "comments", "reader"],
        isAI: true,
        isBookmarked: true,
        caption: "A local visual QA fixture that keeps the native reader, detail inspector, series section, comments, related works, tags, and metadata visible without touching a real Pixiv account."
    )

    static let bookmarkEditorArtwork = decodeArtwork(
        id: 93710,
        title: "Bookmark sheet QA sample",
        createdAt: 1_779_638_400,
        pageCount: 1,
        width: 2200,
        height: 1500,
        tags: ["BlueArchive", "ブルアカ", "小鳥遊ホシノ", "可愛い", "女の子", "illustration"],
        isAI: false,
        isBookmarked: true,
        caption: "A local visual QA fixture for the bookmark editor sheet on compact iOS, portrait iPad, landscape iPad, and macOS."
    )

    static let bookmarkEditorPreviewState = BookmarkEditorPreviewState(
        isBookmarked: true,
        restrict: .public,
        selectedTags: ["BlueArchive", "小鳥遊ホシノ", "お気に入り"],
        libraryTags: [
            PixivBookmarkTag(name: "BlueArchive", count: 32),
            PixivBookmarkTag(name: "小鳥遊ホシノ", count: 18),
            PixivBookmarkTag(name: "お気に入り", count: 52),
            PixivBookmarkTag(name: "可愛い", count: 26),
            PixivBookmarkTag(name: "女の子", count: 40),
            PixivBookmarkTag(name: "reference", count: 11),
            PixivBookmarkTag(name: "wallpaper", count: 9)
        ]
    )

    static var novelBookmarkEditorNovel: PixivNovel {
        novelFeedNovels.first { $0.isBookmarked == false } ?? novelFeedNovels[0]
    }

    static let novelBookmarkEditorSuggestions = [
        PixivBookmarkTag(name: "原创", count: 28),
        PixivBookmarkTag(name: "短篇", count: 22),
        PixivBookmarkTag(name: "読書", count: 18),
        PixivBookmarkTag(name: "海", count: 12),
        PixivBookmarkTag(name: "日常", count: 9),
        PixivBookmarkTag(name: "later", count: 5)
    ]

    static let workSubscriptions: [WorkSubscription] = {
        var mixed = WorkSubscription(
            creatorID: 71_001,
            creatorName: "Longform Visual QA Creator",
            creatorAccount: "visual_longform"
        )
        mixed.lastCheckedAt = Date(timeIntervalSince1970: 1_780_156_800)
        _ = mixed.recordSeenWorkIDs([101, 100], for: .illustrations)
        _ = mixed.recordSeenWorkIDs([102, 101, 100], for: .illustrations)
        _ = mixed.recordSeenWorkIDs([301], for: .manga)
        _ = mixed.recordSeenWorkIDs([302, 301], for: .manga)
        _ = mixed.recordSeenWorkIDs([901], for: .novels)
        _ = mixed.recordSeenWorkIDs([903, 902, 901], for: .novels)

        var illustrationOnly = WorkSubscription(
            creatorID: 71_002,
            creatorName: "Illustration Only Artist",
            creatorAccount: "illust_only"
        )
        illustrationOnly.lastCheckedAt = Date(timeIntervalSince1970: 1_779_984_000)
        _ = illustrationOnly.setTracking(false, for: .manga)
        _ = illustrationOnly.setTracking(false, for: .novels)
        _ = illustrationOnly.recordSeenWorkIDs([201, 200], for: .illustrations)

        var storyAndManga = WorkSubscription(
            creatorID: 71_003,
            creatorName: "Serial Manga and Novel Circle",
            creatorAccount: "serial_circle"
        )
        storyAndManga.lastCheckedAt = Date(timeIntervalSince1970: 1_779_897_600)
        _ = storyAndManga.setTracking(false, for: .illustrations)
        _ = storyAndManga.recordSeenWorkIDs([401], for: .manga)
        _ = storyAndManga.recordSeenWorkIDs([402, 401], for: .manga)
        _ = storyAndManga.recordSeenWorkIDs([801], for: .novels)

        return [mixed, illustrationOnly, storyAndManga]
    }()

    static let novelFeedNovels: [PixivNovel] = [
        decodeNovel(
            id: 94_100,
            title: "亚原子集群意识体的嗜好性使用 - 对艾尔芙蕾妲・塞安娜的长期观察报告",
            caption: "本文献给 Alcientia(user/15371509)，以称颂她对全身贞操带及全身胶衣的热爱与慷慨。<br />这是一条故意很长的小说简介，用来确认窄屏卡片不会再把数字和标签挤成竖排。",
            createdAt: 1_779_724_800,
            tags: ["R-18", "中文", "ラバースーツ", "拘束", "調教", "AI"],
            pageCount: 71,
            textLength: 18_189,
            totalBookmarks: 33_999,
            totalView: 285_999,
            isOriginal: true,
            isBookmarked: true,
            xRestrict: 1,
            novelAIType: 2,
            isFollowed: true,
            seriesID: novelSeriesVisualQAID,
            seriesTitle: novelSeriesVisualQATitle
        ),
        decodeNovel(
            id: 94_101,
            title: "第一章 - 东京部的雨夜",
            caption: "教练好。短标题和中等长度简介应当保持轻巧，不需要为了和长标题卡片对齐而浪费额外高度。",
            createdAt: 1_779_638_400,
            tags: ["R-18G", "贞操带", "边缘控制", "恋爱", "BDSM"],
            pageCount: 50,
            textLength: 14_869,
            totalBookmarks: 358,
            totalView: 5_900,
            xRestrict: 2,
            seriesID: novelSeriesVisualQAID,
            seriesTitle: novelSeriesVisualQATitle
        ),
        decodeNovel(
            id: 94_102,
            title: "静海",
            caption: "彼岸归航。一个更接近日常推荐流的样本，覆盖普通标签和未收藏状态。",
            createdAt: 1_779_552_000,
            tags: ["原创", "短篇", "海", "日常", "読書"],
            pageCount: 12,
            textLength: 7_776,
            totalBookmarks: 75,
            totalView: 1_639
        ),
        decodeNovel(
            id: 94_103,
            title: "Night train archive / 夜行列车手记",
            caption: "Mixed language captions and tags should remain legible in the compact strip without forcing the row taller.",
            createdAt: 1_779_465_600,
            tags: ["original", "travel", "夜景", "列車", "longtagvalidation"],
            pageCount: 24,
            textLength: 42_018,
            totalBookmarks: 1_204,
            totalView: 68_441,
            isOriginal: true,
            seriesID: novelSeriesVisualQAID,
            seriesTitle: novelSeriesVisualQATitle
        )
    ]

    static let novelTranslationSmokeNovel = decodeNovel(
        id: 94_190,
        title: "Translation Smoke - 雨の図書室",
        caption: "Local fixture for validating Apple Translation in the native novel reader without touching Pixiv network or a real account.",
        createdAt: 1_779_811_200,
        tags: ["原创", "短篇", "翻訳QA", "reader", "日常"],
        pageCount: 3,
        textLength: 1_180,
        totalBookmarks: 128,
        totalView: 4_096,
        isOriginal: true,
        isBookmarked: true,
        isFollowed: true,
        seriesID: novelSeriesVisualQAID,
        seriesTitle: novelSeriesVisualQATitle
    )

    static let novelTranslationSmokeText = PixivNovelText(
        novelMarker: PixivNovelMarker(page: 0),
        novelText: """
        [chapter:雨の図書室]
        雨の日の図書室は、ページをめくる音だけがやさしく響いていた。
        彼女は窓際の席で、小さな青いしおりを本に挟みながら言った。
        「今日は翻訳の煙試験をします。長い本文でも、読者が待たされないように。」

        [[rb:言葉 > ことば]]は静かに並び、必要なところから先に訳されていく。
        詳細は https://www.pixiv.net/novel/show.php?id=94190 に残しておく。

        [newpage]
        [chapter:二つ目のページ]
        彼はうなずき、机の上に置いたノートへ短いメモを書いた。
        まず表示中のページを訳す。次に隣のページ、そして近いページを少しずつ先読みする。
        もし言語モデルの準備が必要なら、本文は消さずに、そのまま読める状態を保つ。

        [pixivimage:94000]
        画像の印は翻訳せず、本文だけを自然に扱う。

        [newpage]
        [chapter:最後の確認]
        雨がやむころ、図書室の明かりは少しだけ暖かく見えた。
        これで iPhone と iPad の実機が戻ってきたら、すぐに同じ画面から翻訳を確認できる。
        """,
        seriesPrev: PixivNovelStub(id: 94_189, title: "Previous smoke chapter"),
        seriesNext: PixivNovelStub(id: 94_191, title: "Next smoke chapter")
    )

    static let novelDetailComments = PixivCommentResponse(
        totalComments: 4,
        comments: decodeComments("""
        {
          "comments": [
            {
              "id": 74101,
              "comment": "This series chapter finally makes the quiet harbor scene click (happy)",
              "date": null,
              "user": {
                "id": 6201,
                "name": "Novel Comment QA",
                "account": "novel_comment_qa",
                "profile_image_urls": {
                  "medium": "https://example.com/novel-comment-qa-avatar.jpg"
                }
              },
              "has_replies": true,
              "stamp": null
            },
            {
              "id": 74102,
              "comment": "The compact detail panel keeps the thread readable before related novels.",
              "date": null,
              "user": {
                "id": 6202,
                "name": "Reader Flow QA",
                "account": "reader_flow_qa"
              },
              "parent_comment": {
                "id": 74101,
                "comment": "This series chapter finally makes the quiet harbor scene click (happy)",
                "user": {
                  "id": 6201,
                  "name": "Novel Comment QA",
                  "account": "novel_comment_qa"
                }
              },
              "has_replies": false,
              "stamp": null
            },
            {
              "id": 74103,
              "comment": "Emoji tokens still render through the shared Pixiv comment text view (heart)",
              "date": null,
              "user": {
                "id": 6203,
                "name": "Emoji QA",
                "account": "emoji_qa"
              },
              "has_replies": false,
              "stamp": null
            },
            {
              "id": 74104,
              "comment": null,
              "date": null,
              "user": {
                "id": 6204,
                "name": "Stamp Novel QA",
                "account": "stamp_novel_qa"
              },
              "has_replies": false,
              "stamp": {
                "stamp_id": 102,
                "stamp_url": "https://example.com/novel-comment-stamp.png"
              }
            }
          ],
          "next_url": null,
          "total_comments": 4
        }
        """),
        nextURL: nil
    )

    static func novelSeriesResponse(seriesID: Int, currentNovel: PixivNovel?) -> PixivNovelSeriesResponse? {
        var chapters = novelFeedNovels.filter { $0.series?.id == seriesID }
        if let currentNovel,
           currentNovel.series?.id == seriesID,
           chapters.contains(where: { $0.id == currentNovel.id }) == false {
            chapters.append(currentNovel)
        }
        guard chapters.isEmpty == false else { return nil }
        let title = chapters.first?.series?.title ?? novelSeriesVisualQATitle
        guard let owner = chapters.first?.user ?? currentNovel?.user else { return nil }
        let detail = PixivNovelSeriesDetail(
            id: seriesID,
            title: title,
            caption: "Visual QA sample series for the native novel chapter chooser.",
            isOriginal: true,
            isConcluded: false,
            contentCount: chapters.count,
            totalCharacterCount: chapters.reduce(0) { $0 + $1.textLength },
            user: owner,
            displayText: title,
            watchlistAdded: true
        )
        return PixivNovelSeriesResponse(
            detail: detail,
            firstNovel: chapters.first,
            latestNovel: chapters.last,
            novels: chapters,
            nextURL: nil
        )
    }

    static let seriesParentArtwork = decodeArtwork(
        id: 92000,
        title: "Sample long manga series",
        createdAt: 1_779_552_000,
        pageCount: 12,
        width: 1600,
        height: 2200,
        tags: ["manga", "R-18", "AI"],
        isAI: true,
        xRestrict: 1,
        isBookmarked: true
    )

    static let seriesResponse = PixivArtworkSeriesResponse(
        detail: PixivArtworkSeriesDetail(
            id: 702_001,
            title: "Long Manga Reading QA Series",
            caption: "A visual QA fixture for validating native series sheet density, sorting, filtering, sensitive badges, and long multi-page cards.",
            createDate: Date(timeIntervalSince1970: 1_775_059_200),
            coverImageURLs: PixivImageSet(squareMedium: nil, medium: nil, large: nil, original: nil),
            workCount: 48,
            user: PixivUser(id: 5_001, name: "Series QA Creator", account: "series_qa"),
            watchlistAdded: true
        ),
        firstArtwork: seriesParentArtwork,
        illusts: [
            seriesParentArtwork,
            decodeArtwork(
                id: 92001,
                title: "Chapter 2 - Wide two-page spread",
                createdAt: 1_779_465_600,
                pageCount: 2,
                width: 2800,
                height: 1100,
                tags: ["wide", "manga"],
                isBookmarked: false
            ),
            decodeArtwork(
                id: 92002,
                title: "Chapter 3 - Tall scrolling chapter",
                createdAt: 1_779_379_200,
                pageCount: 24,
                width: 1200,
                height: 3200,
                tags: ["tall", "manga"],
                isBookmarked: false
            ),
            decodeArtwork(
                id: 92003,
                title: "Chapter 4 - Sensitive preview masked",
                createdAt: 1_779_292_800,
                pageCount: 8,
                width: 1600,
                height: 2200,
                tags: ["R-18G", "manga"],
                xRestrict: 2,
                isBookmarked: true
            ),
            decodeArtwork(
                id: 92004,
                title: "Chapter 5 - Ugoira appendix",
                createdAt: 1_779_206_400,
                pageCount: 1,
                width: 1400,
                height: 1400,
                tags: ["ugoira", "appendix"],
                type: "ugoira",
                isBookmarked: false
            )
        ],
        nextURL: URL(string: "https://app-api.pixiv.net/v1/illust/series/next")
    )

    static let cachedFeedSnapshot = FeedSnapshot(
        key: "visual-qa|cached-feed",
        routeRawValue: PixivRoute.illustrations.rawValue,
        title: "Cached Illustrations",
        savedAt: Date(timeIntervalSince1970: 1_779_379_200),
        artworks: [
            decodeArtwork(
                id: 93000,
                title: "Cached wide illustration",
                createdAt: 1_779_379_200,
                pageCount: 1,
                width: 2600,
                height: 1200,
                tags: ["wide", "cached"],
                isBookmarked: false
            ),
            decodeArtwork(
                id: 93001,
                title: "Cached multi-page manga",
                createdAt: 1_779_292_800,
                pageCount: 32,
                width: 1200,
                height: 2400,
                tags: ["manga", "cached"],
                isBookmarked: true
            ),
            decodeArtwork(
                id: 93002,
                title: "Cached R-18 sample",
                createdAt: 1_779_206_400,
                pageCount: 4,
                width: 1600,
                height: 2200,
                tags: ["R-18", "cached"],
                xRestrict: 1,
                isBookmarked: false
            ),
            decodeArtwork(
                id: 93003,
                title: "Cached AI square sample",
                createdAt: 1_779_120_000,
                pageCount: 1,
                width: 1800,
                height: 1800,
                tags: ["AI", "cached"],
                isAI: true,
                isBookmarked: false
            )
        ],
        nextURL: URL(string: "https://app-api.pixiv.net/v1/illust/recommended?offset=30")
    )

    static let feedbackReportRequest = FeedbackReportRequest.artwork(
        decodeArtwork(
            id: 93600,
            title: "Feedback and local mute QA sample",
            createdAt: 1_779_292_800,
            pageCount: 3,
            width: 1800,
            height: 2400,
            tags: ["R-18", "AI", "feedback"],
            isAI: true,
            xRestrict: 1,
            isBookmarked: false
        )
    )

    static let artworkDetailSocialComments = PixivCommentResponse(
        totalComments: 3,
        comments: decodeComments("""
        {
          "comments": [
            {
              "id": 73001,
              "comment": "The wide composition reads cleanly in the native inspector (happy)",
              "date": null,
              "user": {
                "id": 6101,
                "name": "Comment QA Artist",
                "account": "comment_qa",
                "profile_image_urls": {
                  "medium": "https://example.com/comment-qa-avatar.jpg"
                }
              },
              "has_replies": true,
              "stamp": null
            },
            {
              "id": 73002,
              "comment": "Series, related works, emoji tokens, and feedback menus stay inside KeiPix.",
              "date": null,
              "user": {
                "id": 6102,
                "name": "Native Route QA",
                "account": "native_route_qa"
              },
              "parent_comment": {
                "id": 73001,
                "comment": "The wide composition reads cleanly in the native inspector (happy)",
                "user": {
                  "id": 6101,
                  "name": "Comment QA Artist",
                  "account": "comment_qa"
                }
              },
              "has_replies": false,
              "stamp": null
            },
            {
              "id": 73003,
              "comment": null,
              "date": null,
              "user": {
                "id": 6103,
                "name": "Stamp QA",
                "account": "stamp_qa"
              },
              "has_replies": false,
              "stamp": {
                "stamp_id": 101,
                "stamp_url": "https://example.com/comment-stamp.png"
              }
            }
          ],
          "next_url": null,
          "total_comments": 3
        }
        """),
        nextURL: nil
    )

    static let artworkDetailSocialRelatedResponse = PixivFeedResponse(
        illusts: Array(galleryLayoutArtworks.prefix(6)),
        nextURL: nil
    )

    static let creatorProfileDetail: PixivUserDetail = {
        let payload = """
        {
          "user": {
            "id": 5001,
            "name": "Series QA Creator",
            "account": "series_qa",
            "comment": "Creates long manga chapters, wide spreads, and sample works for native macOS creator workflow QA.",
            "is_followed": true
          },
          "profile": {
            "webpage": "https://www.pixiv.net/users/5001",
            "region": "Tokyo",
            "job": "Illustrator",
            "total_follow_users": 128,
            "total_mypixiv_users": 24,
            "total_illusts": 42,
            "total_manga": 18,
            "total_illust_bookmarks_public": 320,
            "background_image_url": null,
            "twitter_url": "https://x.com/series_qa",
            "pawoo_url": null,
            "is_premium": false
          },
          "workspace": {
            "tool": "SwiftUI QA Brush",
            "tablet": "Trackpad",
            "mouse": "Magic Mouse",
            "comment": "Local fixture for profile metrics, links, relationship shortcuts, related creators, and recent works."
          }
        }
        """
        return try! JSONDecoder().decode(PixivUserDetail.self, from: Data(payload.utf8))
    }()

    static let creatorProfileRecentWorks: [PixivArtwork] = [
        decodeArtwork(
            id: 93610,
            title: "Creator profile wide spread",
            createdAt: 1_779_206_400,
            pageCount: 2,
            width: 2600,
            height: 1300,
            tags: ["creator", "wide"],
            type: "illust",
            isBookmarked: true
        ),
        decodeArtwork(
            id: 93611,
            title: "Creator profile manga chapter",
            createdAt: 1_779_120_000,
            pageCount: 36,
            width: 1200,
            height: 2400,
            tags: ["creator", "manga"],
            isBookmarked: false
        ),
        decodeArtwork(
            id: 93612,
            title: "Creator profile AI badge",
            createdAt: 1_779_033_600,
            pageCount: 1,
            width: 1800,
            height: 1800,
            tags: ["creator", "AI"],
            type: "illust",
            isAI: true,
            isBookmarked: false
        )
    ]

    static let creatorProfileRelatedUsers: [PixivUserPreview] = [
        PixivUserPreview(
            user: PixivUser(id: 5101, name: "Related QA Artist", account: "related_qa", isFollowed: false),
            illusts: Array(creatorProfileRecentWorks.prefix(2)),
            isMuted: false
        ),
        PixivUserPreview(
            user: PixivUser(id: 5102, name: "Muted QA Creator", account: "muted_qa", isFollowed: true),
            illusts: Array(creatorProfileRecentWorks.suffix(2)),
            isMuted: true
        )
    ]

    static let galleryLayoutArtworks: [PixivArtwork] = [
        decodeArtwork(
            id: 94000,
            title: "Panoramic city illustration",
            createdAt: 1_779_552_000,
            pageCount: 1,
            width: 3600,
            height: 1200,
            tags: ["wide", "city"],
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94008,
            title: "Wide feed regular landscape A",
            createdAt: 1_779_508_800,
            pageCount: 1,
            width: 1800,
            height: 1200,
            tags: ["landscape", "wide"],
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94009,
            title: "Wide feed regular landscape B",
            createdAt: 1_779_506_400,
            pageCount: 1,
            width: 1920,
            height: 1200,
            tags: ["landscape", "wide"],
            isBookmarked: true
        ),
        decodeArtwork(
            id: 94010,
            title: "Wide feed illustration crop",
            createdAt: 1_779_504_000,
            pageCount: 1,
            width: 2100,
            height: 1300,
            tags: ["illustration", "wide"],
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94011,
            title: "Wide feed character scene",
            createdAt: 1_779_501_600,
            pageCount: 1,
            width: 2400,
            height: 1400,
            tags: ["character", "wide"],
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94012,
            title: "Wide feed group scene",
            createdAt: 1_779_499_200,
            pageCount: 2,
            width: 2560,
            height: 1440,
            tags: ["group", "wide"],
            isBookmarked: true
        ),
        decodeArtwork(
            id: 94013,
            title: "Wide feed near spread",
            createdAt: 1_779_496_800,
            pageCount: 1,
            width: 2200,
            height: 1200,
            tags: ["spread", "wide"],
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94001,
            title: "Tall manga chapter",
            createdAt: 1_779_465_600,
            pageCount: 28,
            width: 1100,
            height: 3200,
            tags: ["manga", "tall"],
            isBookmarked: true
        ),
        decodeArtwork(
            id: 94002,
            title: "Square AI study",
            createdAt: 1_779_379_200,
            pageCount: 1,
            width: 1800,
            height: 1800,
            tags: ["AI"],
            isAI: true,
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94003,
            title: "Sensitive vertical sample",
            createdAt: 1_779_292_800,
            pageCount: 6,
            width: 1300,
            height: 2200,
            tags: ["R-18"],
            xRestrict: 1,
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94004,
            title: "Two-page spread",
            createdAt: 1_779_206_400,
            pageCount: 2,
            width: 2600,
            height: 1300,
            tags: ["spread"],
            isBookmarked: true
        ),
        decodeArtwork(
            id: 94005,
            title: "Compact card baseline",
            createdAt: 1_779_120_000,
            pageCount: 1,
            width: 1500,
            height: 2100,
            tags: ["portrait"],
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94006,
            title: "Ugoira layout sample",
            createdAt: 1_779_033_600,
            pageCount: 1,
            width: 1600,
            height: 1200,
            tags: ["ugoira"],
            type: "ugoira",
            isBookmarked: false
        ),
        decodeArtwork(
            id: 94007,
            title: "R-18G layout sample",
            createdAt: 1_778_947_200,
            pageCount: 4,
            width: 1600,
            height: 2400,
            tags: ["R-18G"],
            xRestrict: 2,
            isBookmarked: true
        )
    ]

    static func localFeed(for route: PixivRoute, searchText: String = "") -> PixivFeedResponse {
        var works = galleryLayoutArtworks
        switch route {
        case .search:
            let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty == false {
                works = works.filter { artwork in
                    artwork.title.localizedCaseInsensitiveContains(normalized)
                        || artwork.user.name.localizedCaseInsensitiveContains(normalized)
                        || artwork.tags.contains { tag in
                            tag.name.localizedCaseInsensitiveContains(normalized)
                        }
                }
            }
        case .mangaRecommended, .newManga, .mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly, .mangaRankingDailyR18:
            works = works.filter { $0.type == "manga" || $0.pageCount > 1 }
        case .rankingDailyAI:
            works = works.filter(\.isAI)
        case .rankingDailyR18, .rankingWeeklyR18:
            works = works.filter(\.isR18)
        case .rankingDailyR18AI:
            works = works.filter { $0.isR18 && $0.isAI }
        case .rankingWeeklyR18G:
            works = works.filter(\.isR18G)
        case .history:
            works = Array(works.reversed())
        default:
            break
        }
        return PixivFeedResponse(illusts: works, nextURL: nil)
    }

    @MainActor
    static func downloadedReaderItem() -> ArtworkDownloadItem {
        let pageURLs = writeDownloadedReaderSamplePages()
        let createdAt = Date(timeIntervalSince1970: 1_779_638_400)
        return ArtworkDownloadItem(
            id: UUID(uuidString: "9D14D638-1F6E-4B18-9BC5-7E4D94A51234") ?? UUID(),
            artworkID: 96_000,
            title: "Downloaded reader QA manga",
            creatorName: "Local QA Creator",
            creatorID: 5_001,
            tags: ["manga", "wide", "downloaded"],
            isAI: false,
            isR18: false,
            isR18G: false,
            artifactKind: .imagePages,
            pageCount: pageURLs.count,
            completedPages: pageURLs.count,
            status: .completed,
            folderPath: downloadedReaderSampleDirectory.path(percentEncoded: false),
            sourceImageURLs: pageURLs.enumerated().map { index, _ in
                URL(string: "https://example.com/downloaded-reader-\(index + 1).png")!
            },
            sourcePageIndexes: Array(pageURLs.indices),
            sourceTotalPageCount: pageURLs.count,
            downloadedFilePaths: pageURLs.map { $0.path(percentEncoded: false) },
            errorMessage: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    @MainActor
    static func downloadedQueueItems() -> [ArtworkDownloadItem] {
        let completed = downloadedReaderItem()
        let activeCreatedAt = Date(timeIntervalSince1970: 1_779_638_520)
        let failedCreatedAt = Date(timeIntervalSince1970: 1_779_638_460)
        let active = ArtworkDownloadItem(
            id: UUID(uuidString: "CA03894B-9347-402E-9F76-5C7372B43BE1") ?? UUID(),
            artworkID: 96_010,
            title: "Queued multi-page sample",
            creatorName: "Local QA Creator",
            creatorID: 5_001,
            tags: ["queue", "sample"],
            isAI: false,
            isR18: false,
            isR18G: false,
            artifactKind: .imagePages,
            pageCount: 3,
            completedPages: 1,
            status: .downloading,
            folderPath: nil,
            sourceImageURLs: (1...3).compactMap { index in
                URL(string: "https://example.com/download-queue-active-\(index).png")
            },
            sourcePageIndexes: [0, 1, 2],
            sourceTotalPageCount: 3,
            downloadedFilePaths: nil,
            errorMessage: nil,
            createdAt: activeCreatedAt,
            updatedAt: activeCreatedAt
        )
        let failed = ArtworkDownloadItem(
            id: UUID(uuidString: "10839D35-F0B9-40FB-93FA-1B92DCE8397D") ?? UUID(),
            artworkID: 96_020,
            title: "Failed retry sample",
            creatorName: "Network QA",
            creatorID: 5_002,
            tags: ["failed", "retry"],
            isAI: false,
            isR18: false,
            isR18G: false,
            artifactKind: .imagePages,
            pageCount: 2,
            completedPages: 0,
            status: .failed,
            folderPath: nil,
            sourceImageURLs: (1...2).compactMap { index in
                URL(string: "https://example.com/download-queue-failed-\(index).png")
            },
            sourcePageIndexes: [0, 1],
            sourceTotalPageCount: 2,
            downloadedFilePaths: nil,
            errorMessage: "Visual QA retry sample",
            createdAt: failedCreatedAt,
            updatedAt: failedCreatedAt
        )
        return [active, failed, completed]
    }

    private static func decodeArtwork(
        id: Int,
        title: String,
        createdAt: Int,
        pageCount: Int,
        width: Int,
        height: Int,
        tags: [String],
        type: String = "manga",
        isAI: Bool = false,
        xRestrict: Int = 0,
        isBookmarked: Bool,
        caption: String = ""
    ) -> PixivArtwork {
        let tagPayload = tags.map { #"{"name":"\#($0)","translated_name":null}"# }.joined(separator: ",")
        let payload = """
        {
          "id": \(id),
          "title": "\(title)",
          "type": "\(type)",
          "image_urls": {
            "medium": "https://example.com/\(id)-medium.jpg",
            "large": "https://example.com/\(id)-large.jpg"
          },
          "caption": "\(caption)",
          "create_date": \(createdAt),
          "user": {
            "id": 5001,
            "name": "Series QA Creator",
            "account": "series_qa"
          },
          "tags": [\(tagPayload)],
          "page_count": \(pageCount),
          "width": \(width),
          "height": \(height),
          "total_view": \(10_000 + id),
          "total_bookmarks": \(1_000 + id),
          "total_comments": \(id % 17),
          "is_bookmarked": \(isBookmarked),
          "is_muted": false,
          "illust_ai_type": \(isAI ? 2 : 0),
          "sanity_level": 4,
          "x_restrict": \(xRestrict),
          "series": {
            "id": 702001,
            "title": "Long Manga Reading QA Series"
          }
        }
        """
        return try! JSONDecoder().decode(PixivArtwork.self, from: Data(payload.utf8))
    }

    private static func decodeNovel(
        id: Int,
        title: String,
        caption: String,
        createdAt: Int,
        tags: [String],
        pageCount: Int,
        textLength: Int,
        totalBookmarks: Int,
        totalView: Int,
        isOriginal: Bool = false,
        isBookmarked: Bool = false,
        xRestrict: Int = 0,
        novelAIType: Int = 0,
        isFollowed: Bool = false,
        seriesID: Int? = nil,
        seriesTitle: String? = nil
    ) -> PixivNovel {
        let tagPayload = tags.map { #"{"name":"\#($0)","translated_name":null}"# }.joined(separator: ",")
        let seriesPayload: String
        if let seriesID, let seriesTitle {
            let escapedSeriesTitle = seriesTitle
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            seriesPayload = #"{"id":\#(seriesID),"title":"\#(escapedSeriesTitle)"}"#
        } else {
            seriesPayload = "{}"
        }
        let payload = """
        {
          "id": \(id),
          "title": "\(title)",
          "caption": "\(caption)",
          "restrict": 0,
          "x_restrict": \(xRestrict),
          "is_original": \(isOriginal),
          "image_urls": {
            "square_medium": "https://example.com/novel-\(id)-square.jpg",
            "medium": "https://example.com/novel-\(id)-medium.jpg",
            "large": "https://example.com/novel-\(id)-large.jpg"
          },
          "create_date": \(createdAt),
          "tags": [\(tagPayload)],
          "page_count": \(pageCount),
          "text_length": \(textLength),
          "user": {
            "id": 5001,
            "name": "Novel QA Creator",
            "account": "novel_qa",
            "is_followed": \(isFollowed)
          },
          "series": \(seriesPayload),
          "is_bookmarked": \(isBookmarked),
          "total_bookmarks": \(totalBookmarks),
          "total_view": \(totalView),
          "total_comments": \(id % 23),
          "visible": true,
          "is_muted": false,
          "is_mypixiv_only": false,
          "is_x_restricted": \(xRestrict > 0),
          "novel_ai_type": \(novelAIType)
        }
        """
        return try! JSONDecoder().decode(PixivNovel.self, from: Data(payload.utf8))
    }

    private static func decodeComments(_ payload: String) -> [PixivComment] {
        try! JSONDecoder().decode(PixivCommentResponse.self, from: Data(payload.utf8)).comments
    }

    private static var downloadedReaderSampleDirectory: URL {
        FileManager.default.temporaryDirectory
            .appending(path: "KeiPixVisualQA/downloaded-reader", directoryHint: .isDirectory)
    }

    private static func writeDownloadedReaderSamplePages() -> [URL] {
        let directory = downloadedReaderSampleDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pages: [(CGSize, PlatformColor, String)] = [
            (CGSize(width: 1100, height: 1500), PlatformColor.systemBlue, "01 Portrait"),
            (CGSize(width: 2200, height: 1100), PlatformColor.systemPurple, "02 Wide Spread"),
            (CGSize(width: 1200, height: 2400), PlatformColor.systemGreen, "03 Tall Manga"),
            (CGSize(width: 1800, height: 1800), PlatformColor.systemOrange, "04 Square")
        ]

        return pages.enumerated().compactMap { index, page in
            let url = directory.appending(path: String(format: "page-%02d.png", index + 1))
            do {
                try writeSampleImage(size: page.0, color: page.1, label: page.2, to: url)
                return url
            } catch {
                return nil
            }
        }
    }

    private static func writeSampleImage(size: CGSize, color: PlatformColor, label: String, to url: URL) throws {
        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        color.withAlphaComponent(0.86).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        PlatformColor.black.withAlphaComponent(0.18).setStroke()
        let stripe = NSBezierPath()
        stripe.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.12))
        stripe.line(to: CGPoint(x: size.width * 0.88, y: size.height * 0.88))
        stripe.lineWidth = max(18, min(size.width, size.height) * 0.035)
        stripe.stroke()

        let text = NSString(string: label)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(54, min(size.width, size.height) * 0.08), weight: .semibold),
            .foregroundColor: PlatformColor.white,
            .paragraphStyle: paragraph
        ]
        let textRect = CGRect(
            x: size.width * 0.08,
            y: size.height * 0.44,
            width: size.width * 0.84,
            height: size.height * 0.18
        )
        text.draw(in: textRect, withAttributes: attributes)
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
        #elseif os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        let data = renderer.pngData { _ in
            color.withAlphaComponent(0.86).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            PlatformColor.black.withAlphaComponent(0.18).setStroke()
            let stripe = UIBezierPath()
            stripe.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.12))
            stripe.addLine(to: CGPoint(x: size.width * 0.88, y: size.height * 0.88))
            stripe.lineWidth = max(18, min(size.width, size.height) * 0.035)
            stripe.stroke()

            let text = NSString(string: label)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(54, min(size.width, size.height) * 0.08), weight: .semibold),
                .foregroundColor: PlatformColor.white,
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(
                x: size.width * 0.08,
                y: size.height * 0.44,
                width: size.width * 0.84,
                height: size.height * 0.18
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        try data.write(to: url, options: .atomic)
        #endif
    }
}

@MainActor
extension KeiPixStore {
    func activateVisualQATestMode(preserveStoredAccounts: Bool = true, persist: Bool = true) {
        accountSessionMode = .visualQA
        if persist {
            UserDefaults.standard.set(AccountSessionMode.visualQA.rawValue, forKey: "accountSessionMode")
            UserDefaults.standard.set(true, forKey: "accountSessionModeUserSelected")
        }
        session = VisualQASampleData.sampleSession
        pixivWebSession = nil
        if preserveStoredAccounts == false {
            storedAccounts = [PixivStoredAccount(session: VisualQASampleData.sampleSession)]
        }
        restrictedModeEnabled = false
        isLoginPresented = false
        presentLocalSampleFeed(for: selectedRoute.usesArtworkFeed ? selectedRoute : .illustrations)
    }

    func activateVisualQASampleSession() {
        activateVisualQATestMode(preserveStoredAccounts: false, persist: false)
    }

    func presentDiscoverDashboardVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .home
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
    }

    func presentPixivActivityVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .pixivActivity
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        selectedPixivCollection = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        allArtworks = []
        artworks = []
        searchPopularPreviewArtworks = []
        nextURL = nil
        pixivActivityFeedScope = .all
        pixivWebSession = PixivWebSession(
            userID: String(VisualQASampleData.sampleSession.user.id),
            connectedAt: Date(),
            cookies: [
                PixivWebSessionCookie(
                    name: "PHPSESSID",
                    value: "visual-qa-session",
                    domain: ".pixiv.net",
                    path: "/",
                    expiresAt: Date(timeIntervalSinceNow: 86_400),
                    isSecure: true
                )
            ]
        )
        pixivActivityItems = VisualQASampleData.pixivActivityItems
        pixivActivityNewItemIDs = ["visual-activity-posted-1"]
        pixivActivityLastRefreshNewCount = 1
        pixivActivityLastRefreshNewItemIDs = ["visual-activity-posted-1"]
        pixivActivityItemsByScope = [.all: pixivActivityItems]
        pixivActivityNewMarkerDatesByScope = [.all: ["visual-activity-posted-1": Date()]]
        pixivActivityNextPage = URL(string: "https://www.pixiv.net/stacc/my/home/all/all/21830200000/.json?mode=stream&tt=visual-qa")
        pixivActivityNextPageByScope = [.all: pixivActivityNextPage].compactMapValues { $0 }
        pixivActivityLoadedAt = Date()
        pixivActivityLoadedAtByScope = [.all: pixivActivityLoadedAt].compactMapValues { $0 }
        pixivActivityLoadedInCurrentSession = true
        pixivActivityLoadedInCurrentSessionScopes = [.all]
        pixivActivityErrorMessage = nil
        isLoadingPixivActivityFeed = false
        isLoadingMorePixivActivityFeed = false
    }

    func presentGalleryLayoutVisualQA(mode: GalleryLayoutMode) {
        activateVisualQASampleSession()
        selectedRoute = .illustrations
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        allArtworks = VisualQASampleData.galleryLayoutArtworks
        artworks = VisualQASampleData.galleryLayoutArtworks
        selectedArtwork = VisualQASampleData.galleryLayoutArtworks.first
        searchPopularPreviewArtworks = []
        nextURL = nil
        activeFeedSnapshotRestoration = nil
        galleryLayoutMode = mode
    }

    func presentSearchWorkspaceVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .search
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchText = "wide"
        savedSearches = ["landscape", "blue archive", "original"]
        searchHistory = ["wide", "watercolor", "夜景"]
        resetSearchOptions()

        let response = VisualQASampleData.localFeed(for: .search, searchText: searchText)
        allArtworks = response.illusts
        nextURL = response.nextURL
        searchPopularPreviewArtworks = Array(response.illusts.prefix(4))
        applyContentFilters()
    }

    func presentNovelFeedVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .novelRecommended
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchPopularPreviewArtworks = []
        novelGalleryLayoutMode = .grid
        novels.presentVisualQAFeed(
            novels: VisualQASampleData.novelFeedNovels,
            nextURL: URL(string: "https://app-api.pixiv.net/v1/novel/recommended/next")
        )
    }

    func presentNovelTranslationSmokeVisualQA() -> PixivNovel {
        activateVisualQASampleSession()
        selectedRoute = .novelRecommended
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchPopularPreviewArtworks = []
        novelGalleryLayoutMode = .grid
        translationTargetLanguage = .english
        novels.presentVisualQANovelReader(
            novel: VisualQASampleData.novelTranslationSmokeNovel,
            text: VisualQASampleData.novelTranslationSmokeText
        )
        return VisualQASampleData.novelTranslationSmokeNovel
    }

    func presentWorkSubscriptionsVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .workSubscriptions
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchPopularPreviewArtworks = []
        allArtworks = []
        artworks = []
        nextURL = nil
        workSubscriptions = VisualQASampleData.workSubscriptions
    }

    func presentRankingVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .rankingDaily
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        allArtworks = VisualQASampleData.galleryLayoutArtworks
        artworks = VisualQASampleData.galleryLayoutArtworks
        selectedArtwork = VisualQASampleData.galleryLayoutArtworks.first
        searchPopularPreviewArtworks = []
        nextURL = nil
        activeFeedSnapshotRestoration = nil
        galleryLayoutMode = .threeColumnMasonry
        setUseRankingDate(false)
        setRankingDate(Self.latestSelectableRankingDate())
    }

    func presentMutedContentVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .mutedContent
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchPopularPreviewArtworks = []
        allArtworks = []
        artworks = []
        nextURL = nil
        mutedTags = ["R-18", "AI", "spoiler", "horror"]
        mutedUsers = [
            81001: "Muted QA Creator",
            81002: "Private Preview Artist",
            81003: "Long Name Creator For Sidebar Density"
        ]
        mutedArtworks = [
            91001: "Muted wide artwork sample",
            91002: "Muted manga chapter sample",
            91003: "Muted R-18G sample"
        ]
        mutedCommentPhrases = [
            "spoiler phrase",
            "sales bot",
            "machine translated bait"
        ]
    }

    func presentUgoiraPlayerVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .illustrations
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchPopularPreviewArtworks = []
        let works = VisualQASampleData.galleryLayoutArtworks
        allArtworks = works
        artworks = works
        selectedArtwork = works.first { $0.isUgoira } ?? works.first
        nextURL = nil
        galleryLayoutMode = .threeColumnMasonry
    }

    func presentDownloadQueueVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .downloads
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedArtwork = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        allArtworks = []
        artworks = []
        searchPopularPreviewArtworks = []
        nextURL = nil
        let items = VisualQASampleData.downloadedQueueItems()
        downloads.downloadDirectoryPath = items.first(where: { $0.status == .completed })?.folderPath
            ?? downloads.downloadDirectoryPath
        downloads.downloadSearchText = ""
        downloads.downloadQueueFilter = .all
        downloads.downloadQueueSort = .newest
        downloads.items = items
    }

    func presentDownloadedReaderVisualQA() {
        presentDownloadQueueVisualQA()
    }

    func presentArtworkDetailSocialVisualQA() {
        activateVisualQASampleSession()
        let artwork = VisualQASampleData.artworkDetailSocialArtwork
        selectedRoute = .illustrations
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchPopularPreviewArtworks = []
        allArtworks = [artwork] + VisualQASampleData.artworkDetailSocialRelatedResponse.illusts
        artworks = allArtworks
        selectedArtwork = artwork
        nextURL = nil
        galleryLayoutMode = .twoColumnMasonry
        saveArtworkDetailExpansionState(
            ArtworkDetailExpansionState(
                isCaptionExpanded: true,
                isSeriesExpanded: true,
                isCommentsExpanded: true,
                isRelatedExpanded: true,
                isTagsExpanded: true,
                isMetadataExpanded: true
            ),
            for: artwork
        )
    }

    func presentLocalSampleFeed(for route: PixivRoute) {
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedRoute = route
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        activeFeedSnapshotRestoration = nil
        searchPopularPreviewArtworks = []
        let response = VisualQASampleData.localFeed(for: route, searchText: searchText)
        allArtworks = response.illusts
        nextURL = response.nextURL
        applyContentFilters()
    }

    func presentCachedFeedVisualQA() {
        activateVisualQASampleSession()
        selectedRoute = .illustrations
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        allArtworks = VisualQASampleData.cachedFeedSnapshot.artworks
        artworks = VisualQASampleData.cachedFeedSnapshot.artworks
        selectedArtwork = VisualQASampleData.cachedFeedSnapshot.artworks.first
        searchPopularPreviewArtworks = []
        nextURL = VisualQASampleData.cachedFeedSnapshot.nextURL
        activeFeedSnapshotRestoration = FeedSnapshotRestoration(
            snapshot: VisualQASampleData.cachedFeedSnapshot,
            error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
            restoredAt: Date(timeIntervalSince1970: 1_779_465_600)
        )
    }
}
#endif
