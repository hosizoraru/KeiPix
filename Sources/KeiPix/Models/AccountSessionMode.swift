import Foundation

enum AccountSessionMode: String, CaseIterable, Identifiable, Sendable {
    case real
    case guest
    case visualQA

    var id: String { rawValue }

    var title: String {
        switch self {
        case .real:
            L10n.realAccount
        case .guest:
            L10n.guestAccount
        case .visualQA:
            L10n.testModeAccount
        }
    }

    var subtitle: String {
        switch self {
        case .real:
            L10n.realAccountSubtitle
        case .guest:
            L10n.guestAccountSubtitle
        case .visualQA:
            L10n.testModeAccountSubtitle
        }
    }

    var systemImage: String {
        switch self {
        case .real:
            "person.crop.circle"
        case .guest:
            "sparkles.rectangle.stack"
        case .visualQA:
            "checkmark.seal"
        }
    }

    var usesLocalSampleData: Bool {
        switch self {
        case .real:
            false
        case .guest, .visualQA:
            true
        }
    }
}
