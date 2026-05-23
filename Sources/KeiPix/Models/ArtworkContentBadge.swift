import Foundation

enum ArtworkContentBadge: String, Identifiable {
    case aiGenerated
    case r18
    case r18g
    case ugoira
    case muted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiGenerated:
            L10n.aiGenerated
        case .r18:
            L10n.r18
        case .r18g:
            L10n.r18g
        case .ugoira:
            L10n.ugoira
        case .muted:
            L10n.muted
        }
    }

    var systemImage: String {
        switch self {
        case .aiGenerated:
            "sparkles"
        case .r18:
            "exclamationmark.triangle"
        case .r18g:
            "exclamationmark.octagon"
        case .ugoira:
            "play.rectangle"
        case .muted:
            "speaker.slash"
        }
    }
}
