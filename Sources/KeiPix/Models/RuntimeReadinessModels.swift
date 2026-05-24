import Foundation

struct RuntimeReadinessRow: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    let isReady: Bool?
}

struct RuntimeReadinessSnapshot: Hashable {
    let checkedAt: Date
    let rows: [RuntimeReadinessRow]
    let diagnosticsText: String
}

@MainActor
extension KeiPixStore {
    var runtimeReadinessSnapshot: RuntimeReadinessSnapshot {
        let checkedAt = Date()
        let rows = runtimeReadinessRows
        return RuntimeReadinessSnapshot(
            checkedAt: checkedAt,
            rows: rows,
            diagnosticsText: runtimeReadinessDiagnosticsText(checkedAt: checkedAt, rows: rows)
        )
    }

    func copyRuntimeReadinessDiagnostics() {
        PasteboardWriter.copy(runtimeReadinessSnapshot.diagnosticsText)
    }

    private var runtimeReadinessRows: [RuntimeReadinessRow] {
        [
            sessionReadinessRow,
            routeReadinessRow,
            feedReadinessRow,
            selectionReadinessRow,
            downloadReadinessRow,
            filterReadinessRow,
            mutedReadinessRow,
            privacyReadinessRow,
            trackpadReadinessRow
        ]
    }

    private var sessionReadinessRow: RuntimeReadinessRow {
        let value: String
        if let session {
            value = showsSidebarAccountIdentity ? "#\(session.user.id)" : L10n.hidden
        } else {
            value = L10n.signedOut
        }

        return RuntimeReadinessRow(
            id: "session",
            title: L10n.session,
            value: session == nil ? value : "\(L10n.signedIn) · \(value)",
            systemImage: "person.crop.circle.badge.checkmark",
            isReady: session != nil
        )
    }

    private var routeReadinessRow: RuntimeReadinessRow {
        RuntimeReadinessRow(
            id: "route",
            title: L10n.currentRoute,
            value: selectedRoute.title,
            systemImage: selectedRoute.systemImage,
            isReady: selectedRoute.usesArtworkFeed ? session != nil : true
        )
    }

    private var feedReadinessRow: RuntimeReadinessRow {
        let value = String(
            format: L10n.feedReadinessFormat,
            artworks.count,
            allArtworks.count,
            hasNextPage ? L10n.nextPageAvailable : L10n.noMorePages
        )
        return RuntimeReadinessRow(
            id: "feed",
            title: L10n.feed,
            value: value,
            systemImage: "photo.stack",
            isReady: selectedRoute.usesArtworkFeed ? artworks.isEmpty == false : true
        )
    }

    private var selectionReadinessRow: RuntimeReadinessRow {
        let value: String
        if let selectedArtwork {
            value = "#\(selectedArtwork.id) · \(String(format: L10n.pageCountFormat, selectedArtwork.pageCount))"
        } else {
            value = L10n.noSelection
        }

        return RuntimeReadinessRow(
            id: "selection",
            title: L10n.selectedArtwork,
            value: value,
            systemImage: "cursorarrow.rays",
            isReady: selectedRoute.usesArtworkFeed ? selectedArtwork != nil : nil
        )
    }

    private var downloadReadinessRow: RuntimeReadinessRow {
        let value = String(
            format: L10n.downloadReadinessFormat,
            downloads.items.count,
            downloads.activeCount,
            downloads.completedCount
        )
        return RuntimeReadinessRow(
            id: "downloads",
            title: L10n.downloads,
            value: value,
            systemImage: "arrow.down.circle",
            isReady: true
        )
    }

    private var filterReadinessRow: RuntimeReadinessRow {
        let activeFilters = [
            hideMutedContent ? L10n.muted : nil,
            hideAIArtworks ? L10n.aiGenerated : nil,
            hideR18Artworks ? L10n.r18 : nil,
            hideR18GArtworks ? L10n.r18g : nil
        ].compactMap(\.self)

        return RuntimeReadinessRow(
            id: "filters",
            title: L10n.contentFilters,
            value: activeFilters.isEmpty ? L10n.allAges : activeFilters.joined(separator: " · "),
            systemImage: "line.3.horizontal.decrease.circle",
            isReady: true
        )
    }

    private var mutedReadinessRow: RuntimeReadinessRow {
        RuntimeReadinessRow(
            id: "muted",
            title: L10n.mutedContent,
            value: String(format: L10n.mutedContentCountFormat, mutedTags.count + mutedUsers.count + mutedArtworks.count),
            systemImage: "eye.slash",
            isReady: true
        )
    }

    private var privacyReadinessRow: RuntimeReadinessRow {
        let values = [
            privacyModeEnabled ? L10n.privacyMode : nil,
            showAccountIdentity ? nil : L10n.accountIdentityHidden,
            screenCaptureProtectionEnabled ? L10n.screenProtection : nil
        ].compactMap(\.self)

        return RuntimeReadinessRow(
            id: "privacy",
            title: L10n.privacy,
            value: values.isEmpty ? L10n.disabled : values.joined(separator: " · "),
            systemImage: "hand.raised",
            isReady: true
        )
    }

    private var trackpadReadinessRow: RuntimeReadinessRow {
        let value = trackpadGesturesEnabled
            ? "\(L10n.enabled) · \(horizontalSwipeBehavior.title)"
            : L10n.disabled
        return RuntimeReadinessRow(
            id: "trackpad",
            title: L10n.trackpad,
            value: value,
            systemImage: "rectangle.and.hand.point.up.left",
            isReady: trackpadGesturesEnabled
        )
    }

    private func runtimeReadinessDiagnosticsText(checkedAt: Date, rows: [RuntimeReadinessRow]) -> String {
        var lines = [
            "KeiPix Runtime Readiness",
            "Checked: \(Self.runtimeReadinessDateFormatter.string(from: checkedAt))",
            "Native: Swift + SwiftUI + AppKit bridges",
            ""
        ]
        lines += rows.map { "\($0.title): \($0.value)" }
        lines += [
            "",
            "Downloads: \(downloads.downloadDirectoryPath)"
        ]
        return lines.joined(separator: "\n")
    }

    private static let runtimeReadinessDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
