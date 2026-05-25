import Foundation

struct PixivCommentResponse: Decodable, Sendable {
    let totalComments: Int?
    let comments: [PixivComment]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case totalComments = "total_comments"
        case comments
        case nextURL = "next_url"
    }

    init(totalComments: Int?, comments: [PixivComment], nextURL: URL?) {
        self.totalComments = totalComments
        self.comments = comments
        self.nextURL = nextURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalComments = try container.decodeIfPresent(Int.self, forKey: .totalComments)
        comments = try container.decodeIfPresent([PixivComment].self, forKey: .comments) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

struct PixivComment: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let comment: String?
    let date: Date?
    let user: PixivUser?
    let parentComment: PixivParentComment?
    let hasReplies: Bool
    let stamp: PixivCommentStamp?

    enum CodingKeys: String, CodingKey {
        case id
        case comment
        case date
        case user
        case parentComment = "parent_comment"
        case hasReplies = "has_replies"
        case stamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        user = try container.decodeIfPresent(PixivUser.self, forKey: .user)
        parentComment = try container.decodeIfPresent(PixivParentComment.self, forKey: .parentComment)
        hasReplies = try container.decodeIfPresent(Bool.self, forKey: .hasReplies) ?? false
        stamp = try container.decodeIfPresent(PixivCommentStamp.self, forKey: .stamp)
    }
}

struct PixivParentComment: Decodable, Hashable, Sendable {
    let id: Int?
    let comment: String?
    let user: PixivUser?
}

struct PixivCommentStamp: Decodable, Hashable, Sendable {
    let stampID: Int?
    let stampURL: URL?

    enum CodingKeys: String, CodingKey {
        case stampID = "stamp_id"
        case stampURL = "stamp_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stampID = try container.decodeIfPresent(Int.self, forKey: .stampID)
        stampURL = container.decodeCleanURLIfPresent(forKey: .stampURL)
    }
}
