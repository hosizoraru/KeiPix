import Foundation

struct NetworkDiagnosticResult: Identifiable, Hashable {
    enum Status: Hashable {
        case passed
        case failed
        case skipped
    }

    let id: String
    let title: String
    let status: Status
    let detail: String
    let duration: TimeInterval?

    var statusText: String {
        switch status {
        case .passed: L10n.passed
        case .failed: L10n.failed
        case .skipped: L10n.skipped
        }
    }

    var diagnosticsLine: String {
        let durationText = duration.map { " · \(String(format: "%.0f %@", $0 * 1000, L10n.millisecondsUnit))" } ?? ""
        return "\(title): \(statusText) · \(detail)\(durationText)"
    }
}

struct ImageCacheStatus: Hashable {
    let memoryCapacity: Int
    let memoryUsage: Int
    let diskCapacity: Int
    let diskUsage: Int

    var diskUsageText: String {
        Self.formatBytes(diskUsage)
    }

    var diskCapacityText: String {
        Self.formatBytes(diskCapacity)
    }

    var memoryUsageText: String {
        Self.formatBytes(memoryUsage)
    }

    var memoryCapacityText: String {
        Self.formatBytes(memoryCapacity)
    }

    var summaryText: String {
        "\(diskUsageText) / \(diskCapacityText)"
    }

    private static func formatBytes(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}
