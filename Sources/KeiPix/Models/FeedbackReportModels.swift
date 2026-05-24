import Foundation

enum FeedbackReportReason: String, CaseIterable, Identifiable, Hashable {
    case sexualContent
    case hateSpeech
    case terroristContent
    case dangerousOrganizations
    case sensitiveEvents
    case bullyingHarassment
    case dangerousProducts
    case marijuana
    case tobaccoAlcohol
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sexualContent:
            L10n.reportReasonSexualContent
        case .hateSpeech:
            L10n.reportReasonHateSpeech
        case .terroristContent:
            L10n.reportReasonTerroristContent
        case .dangerousOrganizations:
            L10n.reportReasonDangerousOrganizations
        case .sensitiveEvents:
            L10n.reportReasonSensitiveEvents
        case .bullyingHarassment:
            L10n.reportReasonBullyingHarassment
        case .dangerousProducts:
            L10n.reportReasonDangerousProducts
        case .marijuana:
            L10n.reportReasonMarijuana
        case .tobaccoAlcohol:
            L10n.reportReasonTobaccoAlcohol
        case .other:
            L10n.reportReasonOther
        }
    }
}

enum FeedbackReportTargetKind: String, Hashable {
    case artwork
    case comment
    case creator

    var title: String {
        switch self {
        case .artwork:
            L10n.artwork
        case .comment:
            L10n.comments
        case .creator:
            L10n.creator
        }
    }
}

struct FeedbackReportRequest: Identifiable, Hashable {
    let id: String
    let kind: FeedbackReportTargetKind
    let targetTitle: String
    let targetSubtitle: String
    let targetURL: URL?
    let localMuteTitle: String?

    static func artwork(_ artwork: PixivArtwork) -> FeedbackReportRequest {
        FeedbackReportRequest(
            id: "artwork-\(artwork.id)",
            kind: .artwork,
            targetTitle: artwork.title,
            targetSubtitle: "#\(artwork.id) · \(artwork.user.name)",
            targetURL: artwork.pixivURL,
            localMuteTitle: L10n.muteArtwork
        )
    }

    static func creator(_ user: PixivUser) -> FeedbackReportRequest {
        FeedbackReportRequest(
            id: "creator-\(user.id)",
            kind: .creator,
            targetTitle: user.name,
            targetSubtitle: "@\(user.account) · #\(user.id)",
            targetURL: user.pixivURL,
            localMuteTitle: L10n.muteCreator
        )
    }

    static func comment(_ comment: PixivComment, artwork: PixivArtwork) -> FeedbackReportRequest {
        let author = comment.user.map { "\($0.name) @\($0.account)" } ?? L10n.unknown
        return FeedbackReportRequest(
            id: "comment-\(comment.id)",
            kind: .comment,
            targetTitle: String(format: L10n.commentIDFormat, comment.id),
            targetSubtitle: "\(author) · \(artwork.title)",
            targetURL: artwork.pixivURL,
            localMuteTitle: L10n.mute
        )
    }

    func summary(reason: FeedbackReportReason, note: String) -> String {
        [
            "\(L10n.feedbackTarget): \(kind.title)",
            "\(L10n.title): \(targetTitle)",
            "\(L10n.details): \(targetSubtitle)",
            "\(L10n.reportReason): \(reason.title)",
            note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "\(L10n.note): \(note)",
            targetURL.map { "\(L10n.openInPixiv): \($0.absoluteString)" }
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}
