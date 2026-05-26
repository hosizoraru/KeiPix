import Foundation

struct MutedUserEntry: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct MutedArtworkEntry: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
}

struct MutedContentArchive: Codable, Sendable {
    var schemaVersion = 1
    let exportedAt: Date
    let tags: [String]
    let users: [MutedUserEntry]
    let artworks: [MutedArtworkEntry]
    let commentPhrases: [String]

    init(
        schemaVersion: Int = 1,
        exportedAt: Date,
        tags: [String],
        users: [MutedUserEntry],
        artworks: [MutedArtworkEntry],
        commentPhrases: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.tags = tags
        self.users = users
        self.artworks = artworks
        self.commentPhrases = commentPhrases
    }

    var totalCount: Int {
        tags.count + users.count + artworks.count + commentPhrases.count
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case tags
        case users
        case artworks
        case commentPhrases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        users = try container.decodeIfPresent([MutedUserEntry].self, forKey: .users) ?? []
        artworks = try container.decodeIfPresent([MutedArtworkEntry].self, forKey: .artworks) ?? []
        commentPhrases = try container.decodeIfPresent([String].self, forKey: .commentPhrases) ?? []
    }
}

enum BulkMuteTarget: String, CaseIterable, Identifiable, Hashable, Sendable {
    case artworks
    case creators
    case tags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artworks:
            L10n.visibleArtworks
        case .creators:
            L10n.visibleCreators
        case .tags:
            L10n.visibleTags
        }
    }

    var systemImage: String {
        switch self {
        case .artworks:
            "photo.badge.exclamationmark"
        case .creators:
            "person.crop.circle.badge.xmark"
        case .tags:
            "tag.slash"
        }
    }
}

struct BulkMutePreviewEntry: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String?
}

struct BulkMutePreview: Identifiable, Hashable, Sendable {
    let id = UUID()
    let target: BulkMuteTarget
    let entries: [BulkMutePreviewEntry]
    let affectedArtworkCount: Int
    let omittedEntryCount: Int

    var canApply: Bool {
        entries.isEmpty == false
    }
}

struct MuteSyncDiagnosticSummary: Hashable, Sendable {
    let localTagCount: Int
    let localUserCount: Int
    let localArtworkCount: Int
    let localCommentPhraseCount: Int
    let remoteTagCount: Int
    let remoteUserCount: Int
    let muteLimitCount: Int
    let remoteTagCountMissingLocally: Int
    let remoteUserCountMissingLocally: Int
    let localTagCountMissingRemotely: Int
    let localUserCountMissingRemotely: Int

    var detailText: String {
        String(
            format: L10n.muteSyncReadOnlyDetailFormat,
            remoteTagCount,
            remoteUserCount,
            localTagCount,
            localUserCount,
            remoteTagCountMissingLocally,
            remoteUserCountMissingLocally,
            localTagCountMissingRemotely,
            localUserCountMissingRemotely,
            muteLimitCount
        )
    }

    var localOnlyDetailText: String {
        String(
            format: L10n.muteSyncLocalOnlyDetailFormat,
            localArtworkCount,
            localCommentPhraseCount
        )
    }

    init(
        localTags: Set<String>,
        localUsers: [Int: String],
        localArtworks: [Int: String],
        localCommentPhrases: Set<String>,
        remoteTags: [String],
        remoteUserIDs: [Int],
        muteLimitCount: Int
    ) {
        let normalizedLocalTags = Set(localTags.map(Self.normalizedTag))
        let normalizedRemoteTags = Set(remoteTags.map(Self.normalizedTag))
        let localUserIDs = Set(localUsers.keys)
        let remoteUserIDSet = Set(remoteUserIDs)

        localTagCount = localTags.count
        localUserCount = localUsers.count
        localArtworkCount = localArtworks.count
        localCommentPhraseCount = localCommentPhrases.count
        remoteTagCount = remoteTags.count
        remoteUserCount = remoteUserIDs.count
        self.muteLimitCount = muteLimitCount
        remoteTagCountMissingLocally = normalizedRemoteTags.subtracting(normalizedLocalTags).count
        remoteUserCountMissingLocally = remoteUserIDSet.subtracting(localUserIDs).count
        localTagCountMissingRemotely = normalizedLocalTags.subtracting(normalizedRemoteTags).count
        localUserCountMissingRemotely = localUserIDs.subtracting(remoteUserIDSet).count
    }

    private static func normalizedTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum CommentMuteReason: Hashable, Sendable {
    case user(String)
    case phrase(String)

    var title: String {
        switch self {
        case .user(let name):
            String(format: L10n.mutedCommentUserReasonFormat, name)
        case .phrase(let phrase):
            String(format: L10n.mutedCommentPhraseReasonFormat, phrase)
        }
    }
}

struct PixivMuteList: Decodable, Sendable {
    let mutedTags: [PixivMutedTag]
    let mutedUsers: [PixivMutedUser]
    let muteLimitCount: Int

    enum CodingKeys: String, CodingKey {
        case mutedTags = "muted_tags"
        case mutedUsers = "muted_users"
        case muteLimitCount = "mute_limit_count"
    }
}

struct PixivMutedTag: Decodable, Hashable, Sendable {
    let tag: String
    let tagTranslation: String?

    enum CodingKeys: String, CodingKey {
        case tag
        case tagTranslation = "tag_translation"
    }
}

struct PixivMutedUser: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let account: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name = "user_name"
        case account = "user_account"
        case profileImageURLs = "user_profile_image_urls"
    }

    enum ProfileKeys: String, CodingKey {
        case medium
        case px170 = "px_170x170"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        account = try container.decodeIfPresent(String.self, forKey: .account)

        let profile = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profileImageURLs)
        avatarURL = profile?.decodeCleanURLIfPresent(forKey: .medium)
            ?? profile?.decodeCleanURLIfPresent(forKey: .px170)
    }
}

struct PixivRestrictedModeSettings: Decodable, Sendable {
    let isRestrictedModeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case isRestrictedModeEnabled = "is_restricted_mode_enabled"
    }
}

/// Response shape for `/v1/user/ai-show-settings(/edit)`.
///
/// `show_ai = true` means the account-wide preference asks Pixiv to keep
/// AI-generated artworks visible across clients; `false` is Pixiv's
/// "partially hidden" mode. Pixez ships the same toggle under "AI work
/// display settings" and reads/writes the same field.
struct PixivAIShowSettings: Decodable, Sendable {
    let showAI: Bool

    enum CodingKeys: String, CodingKey {
        case showAI = "show_ai"
    }
}
