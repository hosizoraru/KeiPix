import Foundation

enum NonNovelQAPriority: String, CaseIterable, Codable, Hashable {
    case p0 = "P0"
    case p1 = "P1"
    case p2 = "P2"

    var title: String { rawValue }
}

enum NonNovelQAStatus: String, CaseIterable, Codable, Hashable {
    case passed
    case needsEvidence
    case actionRequired
    case skipped

    var title: String {
        switch self {
        case .passed:
            L10n.passed
        case .needsEvidence:
            L10n.needsEvidence
        case .actionRequired:
            L10n.actionRequired
        case .skipped:
            L10n.skipped
        }
    }

    var systemImage: String {
        switch self {
        case .passed:
            "checkmark.circle"
        case .needsEvidence:
            "clock.badge.questionmark"
        case .actionRequired:
            "exclamationmark.triangle"
        case .skipped:
            "minus.circle"
        }
    }
}

struct NonNovelQAItem: Identifiable, Codable, Hashable {
    let id: String
    let priority: NonNovelQAPriority
    let title: String
    let requirement: String
    let status: NonNovelQAStatus
    let evidence: String
    let nextAction: String
    let systemImage: String

    var diagnosticsLine: String {
        "[\(priority.title)] \(title): \(status.title) · \(evidence) · \(nextAction)"
    }
}

struct NonNovelQAMatrixSnapshot: Codable, Hashable {
    let checkedAt: Date
    let items: [NonNovelQAItem]

    var diagnosticsText: String {
        var lines = [
            "KeiPix Non-Novel QA Matrix",
            "Checked: \(Self.dateFormatter.string(from: checkedAt))",
            "Native: Swift + SwiftUI",
            ""
        ]
        lines += items.map(\.diagnosticsLine)
        return lines.joined(separator: "\n")
    }

    func progressRows() -> [(priority: NonNovelQAPriority, passed: Int, total: Int)] {
        NonNovelQAPriority.allCases.map { priority in
            let matching = items.filter { $0.priority == priority }
            let passed = matching.filter { $0.status == .passed }.count
            return (priority, passed, matching.count)
        }
    }

    func items(for priority: NonNovelQAPriority) -> [NonNovelQAItem] {
        items.filter { $0.priority == priority }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
