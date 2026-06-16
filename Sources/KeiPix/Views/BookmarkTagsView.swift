import SwiftUI
#if os(iOS)
import UIKit
#endif

struct BookmarkTagsView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedRestrict: BookmarkRestrict = .public
    @State private var tags: [PixivBookmarkTag] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var filterText = ""
    @State private var isSearchPresented = false
    @State private var sortMode: BookmarkTagIndexSort = .mostUsed
    @State private var autoLoadedBookmarkTagPageURLs = Set<URL>()

    private let tagCollectionLayout = NativeBookmarkTagCollectionLayout()

    var body: some View {
        bookmarkTagRootWithPageHeader
        .platformPageNavigationChrome(title: L10n.bookmarkTags, status: bookmarkTagNavigationStatus)
        .mobileRouteBadgeCount(filteredTags.count, for: .bookmarkTags)
        .mobilePageFilter(mobileBookmarkTagPageFilterSnapshot)
        .toolbar {
            bookmarkTagToolbar
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let actionMessage {
                    FloatingStatusBanner {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage {
                    FloatingStatusBanner {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .animation(.snappy(duration: 0.18), value: showsBookmarkTagSearchBar)
        .task(id: bookmarkTagLoadKey) {
            await load()
        }
    }

    @ViewBuilder
    private var bookmarkTagRoot: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if isLoading {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "tag")
            } else {
                VStack(spacing: 0) {
                    if showsBookmarkTagSearchBar {
                        header
                            .platformGlassControlBar(verticalPadding: 6, topPadding: 2)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    tagCollectionContent
                }
            }
        }
    }

    @ViewBuilder
    private var bookmarkTagRootWithPageHeader: some View {
        #if os(iOS)
        if usesPhoneBookmarkTagFilterPill {
            bookmarkTagRoot
                .platformPageHeader(
                    title: L10n.bookmarkTags,
                    status: bookmarkTagNavigationStatus,
                    statusSystemImage: "tag"
                )
        } else {
            bookmarkTagRoot
                .platformPageHeader(
                    title: L10n.bookmarkTags,
                    status: bookmarkTagNavigationStatus,
                    statusSystemImage: "tag"
                ) {
                    bookmarkTagTitleActions
                }
        }
        #else
        bookmarkTagRoot
            .platformPageHeader(
                title: L10n.bookmarkTags,
                status: bookmarkTagNavigationStatus,
                statusSystemImage: "tag"
            ) {
                bookmarkTagTitleActions
            }
        #endif
    }

    @ToolbarContentBuilder
    private var bookmarkTagToolbar: some ToolbarContent {
        #if os(iOS)
        if store.session != nil, usesPhoneBookmarkTagFilterPill {
            ToolbarItem(placement: .secondaryAction) {
                bookmarkTagActionsMenu
            }
        }
        #else
        ToolbarItem(placement: .secondaryAction) {
            EmptyView()
        }
        #endif
    }

    private var bookmarkTagLoadKey: String {
        "\(selectedRestrict.rawValue)-\(store.routeRefreshGeneration)"
    }

    private var bookmarkTagNavigationStatus: String {
        guard store.session != nil else { return "" }
        return bookmarkTagSummary
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                OS26LibrarySearchField(
                    text: bookmarkTagFilterTextBinding,
                    placeholder: L10n.searchBookmarkTags,
                    minWidth: 160,
                    idealWidth: 220,
                    maxWidth: 420,
                    collapsesOnPhone: false
                )
                .frame(minWidth: 220, idealWidth: 320, maxWidth: 520)
                .layoutPriority(1)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var bookmarkTagTitleActions: some View {
        if store.session != nil {
            OS26LibraryActionRail {
                if usesPhoneBookmarkTagFilterPill == false {
                    Button {
                        withAnimation(.snappy(duration: 0.16)) {
                            if showsBookmarkTagSearchBar, normalizedFilterText.isEmpty {
                                isSearchPresented = false
                            } else {
                                isSearchPresented = true
                            }
                        }
                    } label: {
                        Label(
                            L10n.search,
                            systemImage: normalizedFilterText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill"
                        )
                    }
                    .os26GlassIconButton(prominent: showsBookmarkTagSearchBar || normalizedFilterText.isEmpty == false)
                    .help(L10n.searchBookmarkTags)
                    .accessibilityLabel(L10n.searchBookmarkTags)

                    Button {
                        clearBookmarkTagSearch()
                    } label: {
                        Label(L10n.clearSearch, systemImage: "xmark.circle")
                    }
                    .os26GlassIconButton()
                    .disabled(normalizedFilterText.isEmpty && isSearchPresented == false)
                    .help(L10n.clearSearch)
                }

                bookmarkTagActionsMenu
            }
            .controlSize(.small)
        }
    }

    private var bookmarkTagActionsMenu: some View {
        BookmarkTagActionsMenu(
            selectedRestrict: $selectedRestrict,
            sortMode: $sortMode,
            hasActiveOptions: hasActiveBookmarkTagOptions,
            canCopyVisibleTags: filteredTags.isEmpty == false,
            copyVisibleTags: copyVisibleTags,
            resetOptions: resetBookmarkTagOptions
        )
    }

    private var showsBookmarkTagSearchBar: Bool {
        guard usesPhoneBookmarkTagFilterPill == false else { return false }
        return isSearchPresented || normalizedFilterText.isEmpty == false
    }

    private var normalizedFilterText: String {
        bookmarkTagFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bookmarkTagFilterText: String {
        bookmarkTagFilterTextBinding.wrappedValue
    }

    private var bookmarkTagFilterTextBinding: Binding<String> {
        Binding {
            if usesPhoneBookmarkTagFilterPill {
                return store.clientFilterQuery
            }
            return filterText
        } set: { value in
            if usesPhoneBookmarkTagFilterPill {
                store.clientFilterQuery = value
            } else {
                filterText = value
            }
        }
    }

    @ViewBuilder
    private var tagCollectionContent: some View {
        if tags.isEmpty, let errorMessage {
            OS26LibraryUnavailableView(
                title: L10n.errorTitle,
                subtitle: errorMessage,
                systemImage: "exclamationmark.triangle"
            ) {
                Button {
                    Task { await load(showFeedback: true) }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .os26GlassButton(prominent: true)
            }
        } else {
            NativeBookmarkTagCollectionView(
                items: bookmarkTagCollectionItems,
                layout: tagCollectionLayout
            ) { item in
                nativeBookmarkTagContent(for: item)
            }
            .nativeBottomTabContentSurface()
        }
    }

    private var bookmarkTagCollectionItems: [NativeBookmarkTagCollectionItem] {
        var items: [NativeBookmarkTagCollectionItem] = []
        if isFilteringTags == false {
            items.append(.all(count: totalVisibleCount))
            items.append(.unclassified)
        }
        items.append(contentsOf: filteredTags.map(NativeBookmarkTagCollectionItem.tag))
        if filteredTags.isEmpty {
            items.append(.emptyMessage(tags.isEmpty ? L10n.noBookmarkTags : L10n.noMatchingBookmarkTags))
        }
        if nextURL != nil {
            items.append(.loadMore(isLoading: isLoadingMore))
        }
        return items
    }

    private func nativeBookmarkTagContent(for item: NativeBookmarkTagCollectionItem) -> AnyView {
        switch item {
        case .all(let count):
            return AnyView(
                BookmarkTagCard(
                    title: L10n.allBookmarkTags,
                    count: count,
                    systemImage: "tray.full",
                    isPinned: false,
                    style: .shortcut,
                    action: { store.openBookmarks(restrict: selectedRestrict, tag: nil) }
                )
            )
        case .unclassified:
            return AnyView(
                BookmarkTagCard(
                    title: L10n.unclassified,
                    count: nil,
                    systemImage: "tag.slash",
                    isPinned: false,
                    style: .shortcut,
                    action: { store.openBookmarks(restrict: selectedRestrict, tag: "未分類") }
                )
            )
        case .tag(let tag):
            return AnyView(
                BookmarkTagCard(
                    title: tag.name,
                    count: tag.count,
                    systemImage: store.isBookmarkTagPinned(tag.name) ? "pin.fill" : "tag",
                    isPinned: store.isBookmarkTagPinned(tag.name),
                    style: .tag,
                    action: { store.openBookmarks(restrict: selectedRestrict, tag: tag.name) }
                )
                .contextMenu {
                    Button {
                        togglePin(tag.name)
                    } label: {
                        Label(
                            store.isBookmarkTagPinned(tag.name) ? L10n.unpinTag : L10n.pinTag,
                            systemImage: store.isBookmarkTagPinned(tag.name) ? "pin.slash" : "pin"
                        )
                    }

                    Button(L10n.copyTag) {
                        PasteboardWriter.copy(tag.name)
                        showActionMessage(String(format: L10n.copiedKeywordFormat, "#\(tag.name)"))
                    }
                }
            )
        case .emptyMessage(let message):
            return AnyView(
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(14)
                    .keiPanel(14)
            )
        case .loadMore(let isLoading):
            return AnyView(
                OS26PaginationFooter(
                    loadingTitle: L10n.loading,
                    systemImage: "arrow.down.circle",
                    isLoading: isLoading
                ) {
                    Task { await autoLoadMoreIfNeeded() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
    }

    private var bookmarkTagSummary: String {
        if isFilteringTags {
            return "\(filteredTags.count.formatted())/\(tags.count.formatted())"
        }
        return filteredTags.count.formatted()
    }

    private var filteredTags: [PixivBookmarkTag] {
        BookmarkTagIndexPresentation.visibleTags(
            tags,
            query: bookmarkTagFilterText,
            pinnedTags: store.pinnedBookmarkTags,
            sort: sortMode
        )
    }

    private var isFilteringTags: Bool {
        normalizedFilterText.isEmpty == false
    }

    private var totalVisibleCount: Int? {
        let total = tags.reduce(0) { $0 + $1.count }
        return total > 0 ? total : nil
    }

    private var hasActiveBookmarkTagOptions: Bool {
        selectedRestrict != .public || sortMode != .mostUsed || normalizedFilterText.isEmpty == false
    }

    private var mobileBookmarkTagPageFilterSnapshot: MobilePageFilterSnapshot? {
        #if os(iOS)
        guard usesPhoneBookmarkTagFilterPill, store.session != nil else { return nil }
        return MobilePageFilterSnapshot(
            route: .bookmarkTags,
            totalCount: tags.count,
            visibleCount: filteredTags.count,
            placeholder: L10n.searchBookmarkTags
        )
        #else
        return nil
        #endif
    }

    private var usesPhoneBookmarkTagFilterPill: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private func load(showFeedback: Bool = false) async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await store.bookmarkTagPage(restrict: selectedRestrict)
            tags = response.bookmarkTags
            nextURL = response.nextURL
            autoLoadedBookmarkTagPageURLs.removeAll()
            if showFeedback {
                showActionMessage(String(format: L10n.refreshedBookmarkTagsFormat, tags.count))
            }
        } catch {
            tags = []
            nextURL = nil
            errorMessage = error.localizedDescription
        }
    }

    private func autoLoadMoreIfNeeded() async {
        guard let nextURL, errorMessage == nil else { return }
        guard autoLoadedBookmarkTagPageURLs.contains(nextURL) == false else { return }
        autoLoadedBookmarkTagPageURLs.insert(nextURL)
        await loadMore()
    }

    private func loadMore() async {
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextBookmarkTagPage(nextURL)
            tags.append(contentsOf: response.bookmarkTags)
            self.nextURL = response.nextURL
            if response.bookmarkTags.isEmpty {
                showActionMessage(L10n.noMorePages)
            } else {
                showActionMessage(String(format: L10n.loadedBookmarkTagsFormat, response.bookmarkTags.count))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyVisibleTags() {
        let names = filteredTags.map(\.name)
        guard names.isEmpty == false else {
            showActionMessage(L10n.noBookmarkTagsToCopy)
            return
        }
        PasteboardWriter.copy(names.map { "#\($0)" }.joined(separator: "\n"))
        showActionMessage(String(format: L10n.copiedBookmarkTagsFormat, names.count))
    }

    private func clearBookmarkTagSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            bookmarkTagFilterTextBinding.wrappedValue = ""
            isSearchPresented = false
        }
    }

    private func resetBookmarkTagOptions() {
        withAnimation(.snappy(duration: 0.16)) {
            selectedRestrict = .public
            sortMode = .mostUsed
            bookmarkTagFilterTextBinding.wrappedValue = ""
            isSearchPresented = false
        }
        showActionMessage(L10n.resetBookmarkTagOptions)
    }

    private func togglePin(_ tagName: String) {
        let isPinned = store.togglePinnedBookmarkTag(tagName)
        showActionMessage(String(
            format: isPinned ? L10n.pinnedTagFormat : L10n.unpinnedTagFormat,
            "#\(tagName)"
        ))
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }
}

private struct BookmarkTagActionsMenu: View {
    @Binding var selectedRestrict: BookmarkRestrict
    @Binding var sortMode: BookmarkTagIndexSort
    let hasActiveOptions: Bool
    let canCopyVisibleTags: Bool
    let copyVisibleTags: () -> Void
    let resetOptions: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: actionsSystemImage,
            accessibilityLabel: L10n.bookmarkTagActions,
            menu: nativeActionsMenu,
            select: handleNativeAction
        )
        .frame(width: 38, height: 34)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .help(L10n.bookmarkTagActions)
        #else
        swiftUIActionsMenu
        #endif
    }

    private var actionsSystemImage: String {
        hasActiveOptions ? "slider.horizontal.3.circle.fill" : "ellipsis.circle"
    }

    private var swiftUIActionsMenu: some View {
        Menu {
            Section(L10n.bookmarkVisibility) {
                bookmarkTagPickerMenu(
                    title: L10n.bookmarkVisibility,
                    currentValueTitle: selectedRestrict.title,
                    systemImage: selectedRestrict.systemImage,
                    selection: $selectedRestrict
                ) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Label(restrict.title, systemImage: restrict.systemImage).tag(restrict)
                    }
                }
            }

            Section(L10n.viewOptions) {
                bookmarkTagPickerMenu(
                    title: L10n.sort,
                    currentValueTitle: sortMode.title,
                    systemImage: sortMode.systemImage,
                    selection: $sortMode
                ) {
                    ForEach(BookmarkTagIndexSort.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }

                Button {
                    resetOptions()
                } label: {
                    Label(L10n.resetBookmarkTagOptions, systemImage: "arrow.counterclockwise")
                }
                .disabled(hasActiveOptions == false)
            }

            Section(L10n.moreActions) {
                Button {
                    copyVisibleTags()
                } label: {
                    Label(L10n.copyVisibleBookmarkTags, systemImage: "doc.on.doc")
                }
                .disabled(canCopyVisibleTags == false)
            }
        } label: {
            Label(L10n.bookmarkTagActions, systemImage: actionsSystemImage)
        }
        .menuOrder(.fixed)
        .os26GlassIconButton(prominent: hasActiveOptions)
        .help(L10n.bookmarkTagActions)
        .accessibilityLabel(L10n.bookmarkTagActions)
    }

    private func bookmarkTagPickerMenu<SelectionValue: Hashable, Options: View>(
        title: String,
        currentValueTitle: String,
        systemImage: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder options: () -> Options
    ) -> some View {
        Picker(selection: selection) {
            options()
        } label: {
            Label(title, systemImage: systemImage)
            Text(currentValueTitle)
        }
        .pickerStyle(.menu)
    }

    #if os(iOS)
    private var nativeActionsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.bookmarkTagActions,
            cacheKey: nativeActionsMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.bookmarkVisibility,
                    presentation: .root,
                    items: [
                        NativeToolbarMenuItem.singleSelectionSubmenu(
                            title: L10n.bookmarkVisibility,
                            selectedTitle: selectedRestrict.title,
                            selectedOption: selectedRestrict,
                            systemImage: selectedRestrict.systemImage,
                            options: Array(BookmarkRestrict.allCases),
                            id: BookmarkTagActionsMenuAction.restrict,
                            optionTitle: \.title,
                            optionSystemImage: \.systemImage
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    presentation: .root,
                    items: [
                        NativeToolbarMenuItem.singleSelectionSubmenu(
                            title: L10n.sort,
                            selectedTitle: sortMode.title,
                            selectedOption: sortMode,
                            systemImage: sortMode.systemImage,
                            options: Array(BookmarkTagIndexSort.allCases),
                            id: BookmarkTagActionsMenuAction.sort,
                            optionTitle: \.title,
                            optionSystemImage: \.systemImage
                        ),
                        .action(
                            id: BookmarkTagActionsMenuAction.resetOptions,
                            title: L10n.resetBookmarkTagOptions,
                            systemImage: "arrow.counterclockwise",
                            isEnabled: hasActiveOptions
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.moreActions,
                    items: [
                        .action(
                            id: BookmarkTagActionsMenuAction.copyVisibleTags,
                            title: L10n.copyVisibleBookmarkTags,
                            systemImage: "doc.on.doc",
                            isEnabled: canCopyVisibleTags
                        )
                    ]
                )
            ]
        )
    }

    private var nativeActionsMenuCacheKey: String {
        [
            "bookmark-tag-actions",
            selectedRestrict.rawValue,
            sortMode.rawValue,
            hasActiveOptions.description,
            canCopyVisibleTags.description
        ].joined(separator: ":")
    }

    private func handleNativeAction(_ id: String) {
        if let restrict = BookmarkTagActionsMenuAction.restrict(from: id) {
            selectedRestrict = restrict
            return
        }
        if let sort = BookmarkTagActionsMenuAction.sort(from: id) {
            sortMode = sort
            return
        }

        switch id {
        case BookmarkTagActionsMenuAction.copyVisibleTags:
            copyVisibleTags()
        case BookmarkTagActionsMenuAction.resetOptions:
            resetOptions()
        default:
            break
        }
    }
    #endif
}

private enum BookmarkTagActionsMenuAction {
    static let copyVisibleTags = "bookmark-tag-actions:copy-visible-tags"
    static let resetOptions = "bookmark-tag-actions:reset-options"
    private static let restrictPrefix = "bookmark-tag-actions:restrict:"
    private static let sortPrefix = "bookmark-tag-actions:sort:"

    static func restrict(_ restrict: BookmarkRestrict) -> String {
        restrictPrefix + restrict.rawValue
    }

    static func restrict(from id: String) -> BookmarkRestrict? {
        guard id.hasPrefix(restrictPrefix) else { return nil }
        return BookmarkRestrict(rawValue: String(id.dropFirst(restrictPrefix.count)))
    }

    static func sort(_ sort: BookmarkTagIndexSort) -> String {
        sortPrefix + sort.rawValue
    }

    static func sort(from id: String) -> BookmarkTagIndexSort? {
        guard id.hasPrefix(sortPrefix) else { return nil }
        return BookmarkTagIndexSort(rawValue: String(id.dropFirst(sortPrefix.count)))
    }
}

private enum BookmarkTagCardStyle: Equatable {
    case shortcut
    case tag

    var cornerRadius: CGFloat {
        switch self {
        case .shortcut: 16
        case .tag: 14
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .shortcut: 56
        case .tag: 48
        }
    }

    var iconWidth: CGFloat {
        switch self {
        case .shortcut: 24
        case .tag: 18
        }
    }
}

private struct BookmarkTagCard: View {
    let title: String
    let count: Int?
    let systemImage: String
    let isPinned: Bool
    let style: BookmarkTagCardStyle
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: style == .shortcut ? 10 : 7) {
                Image(systemName: systemImage)
                    .font(style == .shortcut ? .callout.weight(.semibold) : .caption.weight(.bold))
                    .foregroundStyle(isPinned ? Color.accentColor : .secondary)
                    .frame(width: style.iconWidth)

                Text(title)
                    .font(style == .shortcut ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let count {
                    Text(count.formatted())
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(isPinned ? Color.accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            isPinned ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10),
                            in: Capsule()
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if style == .shortcut {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, style == .shortcut ? 12 : 10)
            .padding(.vertical, style == .shortcut ? 9 : 7)
            .frame(maxWidth: .infinity, minHeight: style.minHeight, alignment: .leading)
            .background(
                cardBackground,
                in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .stroke(
                        isPinned
                            ? Color.accentColor.opacity(0.45)
                            : Color.secondary.opacity(isHovering ? 0.26 : 0.10),
                        lineWidth: isPinned ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .scaleEffect(isHovering ? 1.012 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .keiPixHoverTracker { isHovering = $0 }
        .help(title)
        .accessibilityLabel(accessibilityText)
    }

    private var cardBackground: Color {
        if isPinned {
            return Color.accentColor.opacity(isHovering ? 0.16 : 0.11)
        }
        switch style {
        case .shortcut:
            return Color.secondary.opacity(isHovering ? 0.13 : 0.08)
        case .tag:
            return Color.secondary.opacity(isHovering ? 0.11 : 0.06)
        }
    }

    private var accessibilityText: String {
        if let count {
            return "\(title), \(count.formatted())"
        }
        return title
    }
}

private extension BookmarkRestrict {
    var systemImage: String {
        switch self {
        case .public:
            "globe"
        case .private:
            "lock"
        }
    }
}
