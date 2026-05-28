import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Long-lived state for the Advanced QA page.
///
/// Each detail page in the Settings sidebar is rebuilt every time the user
/// switches sidebar selection (NavigationSplitView destroys and recreates the
/// `detail` view), so any `@State` declared on the page is wiped. Lifting the
/// runtime-readiness state into an `@Observable` lets it survive those
/// transitions — diagnostic results, cache info and copy banners stay put when
/// the user navigates to General and back.
@MainActor
@Observable
final class RuntimeReadinessState {
    var didCopyDiagnostics = false
    var didCopyChecklist = false
    var isRunningReadOnlyQA = false
    var isRunningAccountHealthDiagnostics = false
    var isRunningDiagnostics = false
    var isRunningSearchDiagnostics = false
    var isRunningNonNovelQA = false
    var isRunningMutableActionQA = false
    var isRunningDirectNavigationDiagnostics = false
    var isRunningCommentFeedbackDiagnostics = false
    var isRunningMuteSyncDiagnostics = false
    var isLoadingCommentFeedbackPreview = false
    var isMutableActionQAAuthorizationPresented = false
    var feedbackPreviewRequest: FeedbackReportRequest?
    var accountHealthResults: [NetworkDiagnosticResult] = []
    var networkResults: [NetworkDiagnosticResult] = []
    var searchResults: [NetworkDiagnosticResult] = []
    var mutableActionQAResults: [NetworkDiagnosticResult] = []
    var directNavigationResults: [NetworkDiagnosticResult] = []
    var commentFeedbackResults: [NetworkDiagnosticResult] = []
    var muteSyncResults: [NetworkDiagnosticResult] = []
    var cacheStatus: ImageCacheStatus?
    var cacheMessage: String?
}

struct RuntimeReadinessView: View {
    let store: KeiPixStore
    @Bindable var state: RuntimeReadinessState

    // MARK: - State forwarders
    //
    // The runtime-readiness state was lifted onto `SettingsCoordinator` so the
    // page can survive sidebar switches in `NavigationSplitView`. The body and
    // helper methods below predate that move and still reference the values by
    // their bare names. Rather than touch every site, expose thin
    // get/`nonmutating set` forwarders that proxy through to `state`. The
    // setters are `nonmutating` because `state` is a reference type — mutating
    // its stored properties does not mutate the View struct itself.
    private var didCopyDiagnostics: Bool {
        get { state.didCopyDiagnostics }
        nonmutating set { state.didCopyDiagnostics = newValue }
    }
    private var didCopyChecklist: Bool {
        get { state.didCopyChecklist }
        nonmutating set { state.didCopyChecklist = newValue }
    }
    private var isRunningReadOnlyQA: Bool {
        get { state.isRunningReadOnlyQA }
        nonmutating set { state.isRunningReadOnlyQA = newValue }
    }
    private var isRunningAccountHealthDiagnostics: Bool {
        get { state.isRunningAccountHealthDiagnostics }
        nonmutating set { state.isRunningAccountHealthDiagnostics = newValue }
    }
    private var isRunningDiagnostics: Bool {
        get { state.isRunningDiagnostics }
        nonmutating set { state.isRunningDiagnostics = newValue }
    }
    private var isRunningSearchDiagnostics: Bool {
        get { state.isRunningSearchDiagnostics }
        nonmutating set { state.isRunningSearchDiagnostics = newValue }
    }
    private var isRunningNonNovelQA: Bool {
        get { state.isRunningNonNovelQA }
        nonmutating set { state.isRunningNonNovelQA = newValue }
    }
    private var isRunningMutableActionQA: Bool {
        get { state.isRunningMutableActionQA }
        nonmutating set { state.isRunningMutableActionQA = newValue }
    }
    private var isRunningDirectNavigationDiagnostics: Bool {
        get { state.isRunningDirectNavigationDiagnostics }
        nonmutating set { state.isRunningDirectNavigationDiagnostics = newValue }
    }
    private var isRunningCommentFeedbackDiagnostics: Bool {
        get { state.isRunningCommentFeedbackDiagnostics }
        nonmutating set { state.isRunningCommentFeedbackDiagnostics = newValue }
    }
    private var isRunningMuteSyncDiagnostics: Bool {
        get { state.isRunningMuteSyncDiagnostics }
        nonmutating set { state.isRunningMuteSyncDiagnostics = newValue }
    }
    private var isLoadingCommentFeedbackPreview: Bool {
        get { state.isLoadingCommentFeedbackPreview }
        nonmutating set { state.isLoadingCommentFeedbackPreview = newValue }
    }
    private var isMutableActionQAAuthorizationPresented: Bool {
        get { state.isMutableActionQAAuthorizationPresented }
        nonmutating set { state.isMutableActionQAAuthorizationPresented = newValue }
    }
    private var feedbackPreviewRequest: FeedbackReportRequest? {
        get { state.feedbackPreviewRequest }
        nonmutating set { state.feedbackPreviewRequest = newValue }
    }
    private var accountHealthResults: [NetworkDiagnosticResult] {
        get { state.accountHealthResults }
        nonmutating set { state.accountHealthResults = newValue }
    }
    private var networkResults: [NetworkDiagnosticResult] {
        get { state.networkResults }
        nonmutating set { state.networkResults = newValue }
    }
    private var searchResults: [NetworkDiagnosticResult] {
        get { state.searchResults }
        nonmutating set { state.searchResults = newValue }
    }
    private var mutableActionQAResults: [NetworkDiagnosticResult] {
        get { state.mutableActionQAResults }
        nonmutating set { state.mutableActionQAResults = newValue }
    }
    private var directNavigationResults: [NetworkDiagnosticResult] {
        get { state.directNavigationResults }
        nonmutating set { state.directNavigationResults = newValue }
    }
    private var commentFeedbackResults: [NetworkDiagnosticResult] {
        get { state.commentFeedbackResults }
        nonmutating set { state.commentFeedbackResults = newValue }
    }
    private var muteSyncResults: [NetworkDiagnosticResult] {
        get { state.muteSyncResults }
        nonmutating set { state.muteSyncResults = newValue }
    }
    private var cacheStatus: ImageCacheStatus? {
        get { state.cacheStatus }
        nonmutating set { state.cacheStatus = newValue }
    }
    private var cacheMessage: String? {
        get { state.cacheMessage }
        nonmutating set { state.cacheMessage = newValue }
    }

    var body: some View {
        let snapshot = store.runtimeReadinessSnapshot
        #if DEBUG
        let qaSnapshot = store.lastNonNovelQAMatrixSnapshot ?? NonNovelQAMatrixSnapshot(
            checkedAt: snapshot.checkedAt,
            items: KeiPixStore.nonNovelQABaselineItems
        )
        #else
        let qaSnapshot: NonNovelQAMatrixSnapshot? = nil
        #endif

        Section(L10n.runtimeReadiness) {
            Text(L10n.runtimeReadinessHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            if usesRuntimeReadinessVisualQA {
                NonNovelQAMatrixView(
                    snapshot: qaSnapshot,
                    runQA: {
                        Task { await runNonNovelQA() }
                    },
                    copyQA: {
                        PasteboardWriter.copy(qaSnapshot.diagnosticsText)
                        cacheMessage = L10n.copiedQAMatrix
                    },
                    isRunning: isRunningNonNovelQA
                )

                Divider()

                MutableActionReadinessView(
                    items: snapshot.mutableActionItems,
                    didCopyChecklist: didCopyChecklist,
                    copyChecklist: {
                        PasteboardWriter.copy(snapshot.mutableActionChecklistText)
                        didCopyChecklist = true
                    }
                )
                .task(id: didCopyChecklist) {
                    await dismissChecklistCopyStatusIfNeeded()
                }

                Divider()
            }

            ForEach(snapshot.rows) { row in
                RuntimeReadinessRowView(row: row)
            }

            if let cacheStatus {
                RuntimeReadinessRowView(row: RuntimeReadinessRow(
                    id: "image-cache-live",
                    title: L10n.imageCache,
                    value: String(format: L10n.cacheUsageFormat, cacheStatus.diskUsageText, cacheStatus.diskCapacityText),
                    systemImage: "externaldrive",
                    isReady: true
                ))
            }

            if networkResults.isEmpty == false {
                Divider()

                ForEach(networkResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if accountHealthResults.isEmpty == false {
                Divider()

                ForEach(accountHealthResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if searchResults.isEmpty == false {
                Divider()

                ForEach(searchResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if mutableActionQAResults.isEmpty == false {
                Divider()

                ForEach(mutableActionQAResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if directNavigationResults.isEmpty == false {
                Divider()

                ForEach(directNavigationResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if commentFeedbackResults.isEmpty == false {
                Divider()

                ForEach(commentFeedbackResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            if muteSyncResults.isEmpty == false {
                Divider()

                ForEach(muteSyncResults) { result in
                    NetworkDiagnosticResultRow(result: result)
                }
            }

            Divider()

            if usesRuntimeReadinessVisualQA == false {
                MutableActionReadinessView(
                    items: snapshot.mutableActionItems,
                    didCopyChecklist: didCopyChecklist,
                    copyChecklist: {
                        PasteboardWriter.copy(snapshot.mutableActionChecklistText)
                        didCopyChecklist = true
                    }
                )
                .task(id: didCopyChecklist) {
                    await dismissChecklistCopyStatusIfNeeded()
                }

                Divider()
            }

            if usesRuntimeReadinessVisualQA == false {
                NonNovelQAMatrixView(
                    snapshot: qaSnapshot,
                    runQA: {
                        Task { await runNonNovelQA() }
                    },
                    copyQA: {
                        PasteboardWriter.copy(qaSnapshot.diagnosticsText)
                        cacheMessage = L10n.copiedQAMatrix
                    },
                    isRunning: isRunningNonNovelQA
                )
            }

            FlowLayout(spacing: 8) {
                Button {
                    Task { await runReadOnlyQA() }
                } label: {
                    Label(L10n.runReadOnlyQA, systemImage: "checklist.checked")
                }
                .buttonStyle(.glassProminent)
                .disabled(isRunningReadOnlyQA)

                Button {
                    Task { await runNonNovelQA() }
                } label: {
                    Label(L10n.runNonNovelQAMatrix, systemImage: "tablecells")
                }
                .disabled(isRunningNonNovelQA)

                Button {
                    Task { await runDiagnostics() }
                } label: {
                    Label(L10n.runNetworkDiagnostics, systemImage: "network.badge.shield.half.filled")
                }
                .disabled(isRunningDiagnostics)

                Button {
                    Task { await runAccountHealthDiagnostics() }
                } label: {
                    Label(L10n.runAccountHealthDiagnostics, systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(isRunningAccountHealthDiagnostics)

                Button {
                    Task { await runSearchDiagnostics() }
                } label: {
                    Label(L10n.runSearchDiagnostics, systemImage: "magnifyingglass.circle")
                }
                .disabled(isRunningSearchDiagnostics)

                Button(role: .destructive) {
                    isMutableActionQAAuthorizationPresented = true
                } label: {
                    Label(L10n.runMutableActionQA, systemImage: "checkmark.shield")
                }
                .disabled(isRunningMutableActionQA)

                Button {
                    Task { await runDirectNavigationDiagnostics() }
                } label: {
                    Label(L10n.runIDNavigationDiagnostics, systemImage: "number.circle")
                }
                .disabled(isRunningDirectNavigationDiagnostics)

                Button {
                    Task { await runCommentFeedbackDiagnostics() }
                } label: {
                    Label(L10n.runCommentFeedbackDiagnostics, systemImage: "text.bubble")
                }
                .disabled(isRunningCommentFeedbackDiagnostics)

                Button {
                    Task { await runMuteSyncDiagnostics() }
                } label: {
                    Label(L10n.runMuteSyncDiagnostics, systemImage: "eye.slash")
                }
                .disabled(isRunningMuteSyncDiagnostics)

                Button {
                    Task { await previewCommentFeedback() }
                } label: {
                    Label(L10n.previewCommentFeedback, systemImage: "exclamationmark.bubble")
                }
                .disabled(isLoadingCommentFeedbackPreview)

                Button {
                    Task { await refreshCacheStatus() }
                } label: {
                    Label(L10n.refreshCacheStatus, systemImage: "externaldrive.badge.magnifyingglass")
                }

                Button(role: .destructive) {
                    Task { await clearImageCache() }
                } label: {
                    Label(L10n.clearImageCache, systemImage: "trash")
                }
            }

            if isRunningDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningAccountHealthDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningAccountHealthDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningReadOnlyQA {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningReadOnlyQA)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningNonNovelQA {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningNonNovelQAMatrix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningSearchDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningSearchDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningMutableActionQA {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningMutableActionQA)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningDirectNavigationDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningIDNavigationDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningCommentFeedbackDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningCommentFeedbackDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isRunningMuteSyncDiagnostics {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.runningMuteSyncDiagnostics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoadingCommentFeedbackPreview {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.loadingCommentFeedbackPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let cacheMessage {
                Text(cacheMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button {
                copyDiagnostics(snapshot)
                didCopyDiagnostics = true
            } label: {
                Label(L10n.copyDiagnostics, systemImage: "doc.on.doc")
            }
            .task(id: didCopyDiagnostics) {
                await dismissCopyStatusIfNeeded()
            }

            Button {
                saveDiagnostics(snapshot)
            } label: {
                Label(L10n.saveDiagnostics, systemImage: "square.and.arrow.down")
            }

            if didCopyDiagnostics {
                Text(L10n.copiedDiagnostics)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await refreshCacheStatus()
        }
        .sheet(isPresented: $state.isMutableActionQAAuthorizationPresented) {
            MutableActionQAAuthorizationSheet {
                Task { await runMutableActionQA() }
            }
            .iPadFriendlySheet()
        }
        .sheet(item: $state.feedbackPreviewRequest) { request in
            FeedbackReportSheet(request: request, localMuteAction: nil) { message in
                cacheMessage = message
            }
            .iPadFriendlySheet()
        }
    }

    private func runReadOnlyQA() async {
        isRunningReadOnlyQA = true
        defer { isRunningReadOnlyQA = false }
        #if DEBUG
        async let nonNovelQA = store.runNonNovelQAMatrix()
        #endif
        async let network = store.runNetworkDiagnostics()
        async let search = store.runSearchDiagnostics()
        async let directNavigation = store.runDirectNavigationDiagnostics()
        async let commentFeedback = store.runCommentFeedbackDiagnostics()
        async let muteSync = store.runMuteSyncDiagnostics()
        #if DEBUG
        _ = await nonNovelQA
        #endif
        networkResults = await network
        searchResults = await search
        directNavigationResults = await directNavigation
        commentFeedbackResults = await commentFeedback
        muteSyncResults = await muteSync
        await refreshCacheStatus()
    }

    private var usesRuntimeReadinessVisualQA: Bool {
        VisualQALaunchArgument.contains(.runtimeReadiness)
    }

    private func runNonNovelQA() async {
        #if DEBUG
        isRunningNonNovelQA = true
        defer { isRunningNonNovelQA = false }
        _ = await store.runNonNovelQAMatrix()
        #endif
    }

    private func runDiagnostics() async {
        isRunningDiagnostics = true
        defer { isRunningDiagnostics = false }
        networkResults = await store.runNetworkDiagnostics()
        await refreshCacheStatus()
    }

    private func runAccountHealthDiagnostics() async {
        isRunningAccountHealthDiagnostics = true
        defer { isRunningAccountHealthDiagnostics = false }
        accountHealthResults = await store.runAccountHealthDiagnostics()
    }

    private func runSearchDiagnostics() async {
        isRunningSearchDiagnostics = true
        defer { isRunningSearchDiagnostics = false }
        searchResults = await store.runSearchDiagnostics()
    }

    private func runMutableActionQA() async {
        isRunningMutableActionQA = true
        defer { isRunningMutableActionQA = false }
        mutableActionQAResults = await store.runReversibleMutableActionQA()
    }

    private func runDirectNavigationDiagnostics() async {
        isRunningDirectNavigationDiagnostics = true
        defer { isRunningDirectNavigationDiagnostics = false }
        directNavigationResults = await store.runDirectNavigationDiagnostics()
    }

    private func runCommentFeedbackDiagnostics() async {
        isRunningCommentFeedbackDiagnostics = true
        defer { isRunningCommentFeedbackDiagnostics = false }
        commentFeedbackResults = await store.runCommentFeedbackDiagnostics()
    }

    private func runMuteSyncDiagnostics() async {
        isRunningMuteSyncDiagnostics = true
        defer { isRunningMuteSyncDiagnostics = false }
        muteSyncResults = await store.runMuteSyncDiagnostics()
    }

    private func previewCommentFeedback() async {
        isLoadingCommentFeedbackPreview = true
        defer { isLoadingCommentFeedbackPreview = false }
        do {
            feedbackPreviewRequest = try await store.commentFeedbackPreviewRequest()
        } catch {
            cacheMessage = error.localizedDescription
        }
    }

    private func refreshCacheStatus() async {
        cacheStatus = await store.imageCacheStatus()
    }

    private func clearImageCache() async {
        cacheStatus = await store.clearImageCache()
        cacheMessage = L10n.imageCacheCleared
        try? await Task.sleep(for: .seconds(2.5))
        if cacheMessage == L10n.imageCacheCleared {
            cacheMessage = nil
        }
    }

    private func copyDiagnostics(_ snapshot: RuntimeReadinessSnapshot) {
        PasteboardWriter.copy(diagnosticsReport(snapshot))
    }

    private func saveDiagnostics(_ snapshot: RuntimeReadinessSnapshot) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.title = L10n.saveDiagnostics
        panel.nameFieldStringValue = "keipix-diagnostics-\(Self.fileDateFormatter.string(from: Date())).txt"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try diagnosticsReport(snapshot).write(to: url, atomically: true, encoding: .utf8)
            cacheMessage = L10n.savedDiagnostics
        } catch {
            cacheMessage = "\(L10n.unableToSaveDiagnostics): \(error.localizedDescription)"
        }
        #endif
    }

    private func diagnosticsReport(_ snapshot: RuntimeReadinessSnapshot) -> String {
        var lines = [snapshot.diagnosticsText]
        if let cacheStatus {
            lines.append("Image Cache: \(cacheStatus.summaryText)")
        }
        if networkResults.isEmpty == false {
            lines.append("")
            lines.append("Network Diagnostics")
            lines += networkResults.map(\.diagnosticsLine)
        }
        if accountHealthResults.isEmpty == false {
            lines.append("")
            lines.append("Account Health Diagnostics")
            lines += accountHealthResults.map(\.diagnosticsLine)
        }
        if searchResults.isEmpty == false {
            lines.append("")
            lines.append("Search Diagnostics")
            lines += searchResults.map(\.diagnosticsLine)
        }
        if mutableActionQAResults.isEmpty == false {
            lines.append("")
            lines.append("Mutable Action QA Results")
            lines += mutableActionQAResults.map(\.diagnosticsLine)
        }
        if directNavigationResults.isEmpty == false {
            lines.append("")
            lines.append("ID Navigation Diagnostics")
            lines += directNavigationResults.map(\.diagnosticsLine)
        }
        if commentFeedbackResults.isEmpty == false {
            lines.append("")
            lines.append("Comment Feedback Diagnostics")
            lines += commentFeedbackResults.map(\.diagnosticsLine)
        }
        if muteSyncResults.isEmpty == false {
            lines.append("")
            lines.append("Mute Sync Diagnostics")
            lines += muteSyncResults.map(\.diagnosticsLine)
        }
        if let nonNovelQASnapshot = store.lastNonNovelQAMatrixSnapshot {
            lines.append("")
            lines.append(nonNovelQASnapshot.diagnosticsText)
        }
        return lines.joined(separator: "\n")
    }

    private func dismissCopyStatusIfNeeded() async {
        guard didCopyDiagnostics else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if didCopyDiagnostics {
            didCopyDiagnostics = false
        }
    }

    private func dismissChecklistCopyStatusIfNeeded() async {
        guard didCopyChecklist else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if didCopyChecklist {
            didCopyChecklist = false
        }
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

struct MutableActionReadinessView: View {
    let items: [MutableActionQAItem]
    let didCopyChecklist: Bool
    let copyChecklist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(L10n.mutableActionReadiness, systemImage: "checklist")
                    .font(.headline)

                Spacer()

                Button {
                    copyChecklist()
                } label: {
                    Label(L10n.copyQAReviewChecklist, systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }

            Text(L10n.mutableActionReadinessHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    MutableActionReadinessRow(item: item)
                }
            }

            if didCopyChecklist {
                Text(L10n.copiedQAReviewChecklist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NonNovelQAMatrixView: View {
    let snapshot: NonNovelQAMatrixSnapshot
    let runQA: () -> Void
    let copyQA: () -> Void
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(L10n.nonNovelQAMatrix, systemImage: "tablecells")
                    .font(.headline)

                Spacer()

                Button(action: runQA) {
                    Label(L10n.runNonNovelQAMatrix, systemImage: "play.circle")
                }
                .controlSize(.small)
                .disabled(isRunning)

                Button(action: copyQA) {
                    Label(L10n.copyQAMatrix, systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }

            Text(L10n.nonNovelQAMatrixHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(snapshot.progressRows(), id: \.priority) { row in
                    Label("\(row.priority.title) \(row.passed)/\(row.total)", systemImage: row.passed == row.total ? "checkmark.circle" : "clock.badge.questionmark")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(row.passed == row.total ? .green : .orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(NonNovelQAPriority.allCases, id: \.self) { priority in
                    let items = snapshot.items(for: priority)
                    if items.isEmpty == false {
                        NonNovelQAPrioritySection(priority: priority, items: items)
                    }
                }
            }
            .font(.caption)
            .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

private struct NonNovelQAPrioritySection: View {
    let priority: NonNovelQAPriority
    let items: [NonNovelQAItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(priority.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(priorityColor)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    NonNovelQAMatrixRow(item: item)

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 28)
                    }
                }
            }
            .padding(.vertical, 2)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var priorityColor: Color {
        switch priority {
        case .p0:
            .red
        case .p1:
            .orange
        case .p2:
            .secondary
        }
    }
}

private struct NonNovelQAMatrixRow: View {
    let item: NonNovelQAItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Label(item.status.title, systemImage: item.status.systemImage)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(item.evidence)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .help(item.evidence)

                if item.status != .passed {
                    Text(item.nextAction)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .help(item.requirement)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch item.status {
        case .passed:
            .green
        case .needsEvidence:
            .orange
        case .actionRequired:
            .red
        case .skipped:
            .secondary
        }
    }
}

private struct MutableActionReadinessRow: View {
    let item: MutableActionQAItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: item.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            Spacer(minLength: 16)

            Label(item.status.title, systemImage: item.status.systemImage)
                .font(.caption)
                .foregroundStyle(statusColor)
                .labelStyle(.titleAndIcon)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .verified:
            .green
        case .needsTestAccount:
            .orange
        case .needsExplicitApproval:
            .red
        }
    }
}

private struct NetworkDiagnosticResultRow: View {
    let result: NetworkDiagnosticResult

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .lineLimit(1)
                    Text(result.statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 18)
            }

            Spacer(minLength: 16)

            Text(detailText)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .help(detailText)
        }
    }

    private var detailText: String {
        if let duration = result.duration {
            return "\(result.detail) · \(String(format: "%.0f ms", duration * 1000))"
        }
        return result.detail
    }

    private var systemImage: String {
        switch result.status {
        case .passed:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        case .skipped:
            "minus.circle"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .passed:
            .green
        case .failed:
            .red
        case .skipped:
            .secondary
        }
    }
}

private struct RuntimeReadinessRowView: View {
    let row: RuntimeReadinessRow

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(row.title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: row.systemImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 18)
            }

            Spacer(minLength: 16)

            Text(row.value)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .help(row.value)
        }
    }

    private var statusColor: Color {
        switch row.isReady {
        case .some(true):
            .green
        case .some(false):
            .orange
        case .none:
            .secondary
        }
    }
}
