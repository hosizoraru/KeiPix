import SwiftUI
#if os(iOS)
import UIKit
#endif

struct CreatorListStatusBanner: View {
    let errorMessage: String?
    let bulkStatusText: String?
    let isRunningBulkAction: Bool
    let isCheckingFollowVisibility: Bool
    let undoAction: CreatorUndoAction?
    let performUndo: (CreatorUndoAction) -> Void

    var body: some View {
        FloatingStatusBanner {
            VStack(alignment: .leading, spacing: 6) {
                if let undoAction {
                    HStack(spacing: 10) {
                        Text(undoAction.message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Button(L10n.undo) {
                            performUndo(undoAction)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }

                if isCheckingFollowVisibility {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.checkingFollowVisibility)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                if isRunningBulkAction {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.runningCreatorAction)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                if let bulkStatusText {
                    Text(bulkStatusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

/// Thin search bar that lives at the top of the creator list body.
///
/// The previous `CreatorListHeader` mixed the search field with five
/// other controls (filter / sort / layout / bulk actions / refresh)
/// in a `FlowLayout` band. Apple's HIG and stock surfaces (Mail, Music,
/// Photos) keep search at the body edge but push view options /
/// destructive bulk actions into the toolbar so the body stays
/// scannable. `CreatorListSearchBar` is the slim body half — the rest
/// moved into `UserPreviewListView.toolbar`.
struct CreatorListSearchBar: View {
    let mode: UserPreviewListMode
    var showsRestrictPicker = true
    @Binding var restrict: BookmarkRestrict
    @Binding var creatorSearchText: String
    let globalSearchKeyword: String
    let clearGlobalSearch: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if mode.usesRestrictPicker && showsRestrictPicker {
                Picker(L10n.followingCreators, selection: $restrict) {
                    Text(L10n.publicRestrict).tag(BookmarkRestrict.public)
                    Text(L10n.privateRestrict).tag(BookmarkRestrict.private)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)
                .accessibilityLabel(L10n.followingCreators)
            }

            if mode.requiresSearchKeyword, globalSearchKeyword.isEmpty == false {
                CreatorSearchScopeChip(
                    keyword: globalSearchKeyword,
                    clear: clearGlobalSearch
                )
            }

            NativeSearchField(
                text: $creatorSearchText,
                placeholder: L10n.searchCreatorsInList,
                suggestions: [],
                onSubmit: {},
                onTextChange: { creatorSearchText = $0 }
            )
            .frame(maxWidth: 560)

            Spacer(minLength: 0)
        }
        .controlSize(.small)
    }
}

private struct CreatorSearchScopeChip: View {
    let keyword: String
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(.secondary)

            Text(keyword)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 220)

            Button {
                clear()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.clearSearch)
            .accessibilityLabel(L10n.clearSearch)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 32)
        .keiInteractiveGlass(16)
    }
}

/// View-options menu rendered in the creator list's toolbar. The root
/// menu stays short and descriptive; each control is a submenu whose
/// row title says what it changes and whose subtitle shows the current
/// value.
struct CreatorListViewOptionsMenu: View {
    let mode: UserPreviewListMode
    let selectedRoute: PixivRoute?
    @Binding var restrict: BookmarkRestrict
    @Binding var creatorFilter: CreatorListFilter
    @Binding var creatorSort: CreatorListSort
    @Binding var layoutMode: CreatorListLayoutMode
    let selectRoute: (PixivRoute) -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: "slider.horizontal.3",
            accessibilityLabel: L10n.viewOptions,
            menu: nativeViewOptionsMenu,
            select: handleNativeViewOptionsAction
        )
        .fixedSize(horizontal: true, vertical: false)
        #else
        swiftUIViewOptionsMenu
        #endif
    }

    private var swiftUIViewOptionsMenu: some View {
        Menu {
            Section(L10n.viewOptions) {
                if let selectedRoute,
                   let family = selectedRoute.routeScopeFamily {
                    creatorRouteScopeMenu(family: family, selectedRoute: selectedRoute)
                }

                if mode.usesRestrictPicker {
                    creatorListPickerMenu(
                        title: L10n.followingCreators,
                        currentValueTitle: restrict.title,
                        systemImage: restrict == .public ? "globe" : "lock",
                        selection: $restrict
                    ) {
                        Text(L10n.publicRestrict).tag(BookmarkRestrict.public)
                        Text(L10n.privateRestrict).tag(BookmarkRestrict.private)
                    }
                }

                creatorListPickerMenu(
                    title: L10n.creatorListLayout,
                    currentValueTitle: layoutMode.title,
                    systemImage: layoutMode.systemImage,
                    selection: $layoutMode
                ) {
                    ForEach(CreatorListLayoutMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }

                creatorListPickerMenu(
                    title: L10n.creatorFilter,
                    currentValueTitle: creatorFilter.title,
                    systemImage: "line.3.horizontal.decrease.circle",
                    selection: $creatorFilter
                ) {
                    ForEach(CreatorListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                creatorListPickerMenu(
                    title: L10n.creatorSort,
                    currentValueTitle: creatorSort.title,
                    systemImage: "arrow.up.arrow.down",
                    selection: $creatorSort
                ) {
                    ForEach(CreatorListSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            }
        } label: {
            Label(L10n.viewOptions, systemImage: "slider.horizontal.3")
        }
        .menuOrder(.fixed)
        .labelStyle(.iconOnly)
        .help(L10n.viewOptions)
    }

    #if os(iOS)
    private var nativeViewOptionsMenu: NativeToolbarMenu {
        var items: [NativeToolbarMenuItem] = []
        if let selectedRoute,
           let family = selectedRoute.routeScopeFamily {
            items.append(
                NativeToolbarMenuItem.singleSelectionSubmenu(
                    title: family.title,
                    selectedTitle: selectedRoute.title,
                    selectedOption: selectedRoute,
                    systemImage: family.systemImage,
                    options: family.routes,
                    id: CreatorListViewOptionsAction.route,
                    optionTitle: \.title,
                    optionSystemImage: \.systemImage
                )
            )
        }

        if mode.usesRestrictPicker {
            items.append(
                NativeToolbarMenuItem.singleSelectionSubmenu(
                    title: L10n.followingCreators,
                    selectedTitle: restrict.title,
                    selectedOption: restrict,
                    systemImage: restrictSystemImage(restrict),
                    options: BookmarkRestrict.allCases,
                    id: CreatorListViewOptionsAction.restrict,
                    optionTitle: \.title,
                    optionSystemImage: restrictSystemImage
                )
            )
        }

        items.append(
            NativeToolbarMenuItem.singleSelectionSubmenu(
                title: L10n.creatorListLayout,
                selectedTitle: layoutMode.title,
                selectedOption: layoutMode,
                systemImage: layoutMode.systemImage,
                options: CreatorListLayoutMode.allCases,
                id: CreatorListViewOptionsAction.layout,
                optionTitle: \.title,
                optionSystemImage: \.systemImage
            )
        )
        items.append(
            NativeToolbarMenuItem.singleSelectionSubmenu(
                title: L10n.creatorFilter,
                selectedTitle: creatorFilter.title,
                selectedOption: creatorFilter,
                systemImage: creatorFilterSystemImage(creatorFilter),
                options: CreatorListFilter.allCases,
                id: CreatorListViewOptionsAction.filter,
                optionTitle: \.title,
                optionSystemImage: creatorFilterSystemImage
            )
        )
        items.append(
            NativeToolbarMenuItem.singleSelectionSubmenu(
                title: L10n.creatorSort,
                selectedTitle: creatorSort.title,
                selectedOption: creatorSort,
                systemImage: creatorSortSystemImage(creatorSort),
                options: CreatorListSort.allCases,
                id: CreatorListViewOptionsAction.sort,
                optionTitle: \.title,
                optionSystemImage: creatorSortSystemImage
            )
        )

        return NativeToolbarMenu(
            title: L10n.viewOptions,
            cacheKey: nativeViewOptionsMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    presentation: .root,
                    items: items
                )
            ]
        )
    }

    private var nativeViewOptionsMenuCacheKey: String {
        [
            "creator-list-view-options",
            mode.key,
            selectedRoute?.rawValue ?? "no-route",
            restrict.rawValue,
            creatorFilter.rawValue,
            creatorSort.rawValue,
            layoutMode.rawValue
        ].joined(separator: ":")
    }

    private func handleNativeViewOptionsAction(_ id: String) {
        if let selectedRestrict = CreatorListViewOptionsAction.restrict(from: id) {
            restrict = selectedRestrict
            return
        }
        if let route = CreatorListViewOptionsAction.route(from: id) {
            selectRoute(route)
            return
        }
        if let selectedLayoutMode = CreatorListViewOptionsAction.layoutMode(from: id) {
            layoutMode = selectedLayoutMode
            return
        }
        if let selectedCreatorFilter = CreatorListViewOptionsAction.filter(from: id) {
            creatorFilter = selectedCreatorFilter
            return
        }
        if let selectedCreatorSort = CreatorListViewOptionsAction.sort(from: id) {
            creatorSort = selectedCreatorSort
        }
    }
    #endif

    private func creatorRouteScopeMenu(family: PixivRouteScopeFamily, selectedRoute: PixivRoute) -> some View {
        Menu {
            ForEach(family.routes) { route in
                Button {
                    selectRoute(route)
                } label: {
                    Label(route.title, systemImage: route == selectedRoute ? "checkmark" : route.systemImage)
                }
            }
        } label: {
            Label(family.title, systemImage: family.systemImage)
            Text(selectedRoute.title)
        }
    }

    private func creatorListPickerMenu<SelectionValue: Hashable, Options: View>(
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

    private func restrictSystemImage(_ restrict: BookmarkRestrict) -> String {
        restrict == .public ? "globe" : "lock"
    }

    private func creatorFilterSystemImage(_ filter: CreatorListFilter) -> String {
        switch filter {
        case .all:
            "line.3.horizontal.decrease.circle"
        case .followed:
            "person.crop.circle.badge.checkmark"
        case .unfollowed:
            "person.crop.circle.badge.questionmark"
        case .muted:
            "speaker.slash"
        }
    }

    private func creatorSortSystemImage(_ sort: CreatorListSort) -> String {
        switch sort {
        case .defaultOrder:
            "arrow.up.arrow.down"
        case .name:
            "textformat"
        case .account:
            "at"
        case .previewWorks:
            "photo.stack"
        case .followState:
            "person.crop.circle.badge.checkmark"
        }
    }
}

private enum CreatorListViewOptionsAction {
    private static let routePrefix = "creator-list-view-options:route:"
    private static let restrictPrefix = "creator-list-view-options:restrict:"
    private static let layoutPrefix = "creator-list-view-options:layout:"
    private static let filterPrefix = "creator-list-view-options:filter:"
    private static let sortPrefix = "creator-list-view-options:sort:"

    static func route(_ route: PixivRoute) -> String {
        routePrefix + route.rawValue
    }

    static func route(from id: String) -> PixivRoute? {
        guard id.hasPrefix(routePrefix) else { return nil }
        return PixivRoute(rawValue: String(id.dropFirst(routePrefix.count)))
    }

    static func restrict(_ restrict: BookmarkRestrict) -> String {
        restrictPrefix + restrict.rawValue
    }

    static func restrict(from id: String) -> BookmarkRestrict? {
        guard id.hasPrefix(restrictPrefix) else { return nil }
        return BookmarkRestrict(rawValue: String(id.dropFirst(restrictPrefix.count)))
    }

    static func layout(_ mode: CreatorListLayoutMode) -> String {
        layoutPrefix + mode.rawValue
    }

    static func layoutMode(from id: String) -> CreatorListLayoutMode? {
        guard id.hasPrefix(layoutPrefix) else { return nil }
        return CreatorListLayoutMode(rawValue: String(id.dropFirst(layoutPrefix.count)))
    }

    static func filter(_ filter: CreatorListFilter) -> String {
        filterPrefix + filter.rawValue
    }

    static func filter(from id: String) -> CreatorListFilter? {
        guard id.hasPrefix(filterPrefix) else { return nil }
        return CreatorListFilter(rawValue: String(id.dropFirst(filterPrefix.count)))
    }

    static func sort(_ sort: CreatorListSort) -> String {
        sortPrefix + sort.rawValue
    }

    static func sort(from id: String) -> CreatorListSort? {
        guard id.hasPrefix(sortPrefix) else { return nil }
        return CreatorListSort(rawValue: String(id.dropFirst(sortPrefix.count)))
    }
}

/// Selection-entry menu rendered in the creator list's toolbar. Author
/// operations run through explicit selection now; the toolbar only starts
/// selection or manages the current visible selection.
struct CreatorListBulkActionsMenu: View {
    let isSelectionMode: Bool
    let selectedCount: Int
    let visiblePreviewsCount: Int
    let startSelection: () -> Void
    let selectAllVisibleCreators: () -> Void
    let clearSelection: () -> Void

    var body: some View {
        #if os(macOS)
        EnhancedMenu(sections: enhancedMenuSections) { item in
            handleEnhancedMenuItem(item)
        }
        .help(L10n.creatorActions)
        #else
        swiftUIMenu
        #endif
    }

    private var swiftUIMenu: some View {
        Menu {
            Button {
                startSelection()
            } label: {
                Label(L10n.selectionMode, systemImage: "checkmark.circle")
            }
            .disabled(visiblePreviewsCount == 0)

            Button {
                selectAllVisibleCreators()
            } label: {
                Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
            }
            .disabled(visiblePreviewsCount == 0)

            if selectedCount > 0 {
                Divider()

                Button {
                    clearSelection()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }
            }
        } label: {
            if selectedCount > 0 {
                Label(String(format: L10n.selectedCreatorsFormat, selectedCount), systemImage: "checkmark.circle.fill")
            } else if isSelectionMode {
                Label(L10n.creatorSelection, systemImage: "checkmark.circle")
            } else {
                Label(L10n.creatorActions, systemImage: "ellipsis.circle")
            }
        }
        .labelStyle(.iconOnly)
        .help(L10n.creatorActions)
    }

    #if os(macOS)
    private var enhancedMenuSections: [MenuSection] {
        [
            MenuSection(
                title: L10n.creatorSelection,
                items: [
                    MenuItem(
                        title: L10n.selectionMode,
                        icon: menuIcon("checkmark.circle"),
                        isEnabled: visiblePreviewsCount > 0,
                        action: .startCreatorSelection
                    ),
                    MenuItem(
                        title: L10n.selectAll,
                        icon: menuIcon("checkmark.circle.fill"),
                        isEnabled: visiblePreviewsCount > 0,
                        action: .selectAllVisibleCreators
                    )
                ]
            )
        ] + clearSelectionMenuSections
    }

    private var clearSelectionMenuSections: [MenuSection] {
        guard selectedCount > 0 else { return [] }
        return [
            MenuSection(
                title: String(format: L10n.selectedCreatorsFormat, selectedCount),
                items: [
                    MenuItem(
                        title: L10n.clearSelection,
                        icon: menuIcon("xmark.circle"),
                        action: .clearCreatorSelection
                    )
                ]
            )
        ]
    }

    private func handleEnhancedMenuItem(_ item: MenuItem) {
        switch item.action {
        case .startCreatorSelection:
            startSelection()
        case .selectAllVisibleCreators:
            selectAllVisibleCreators()
        case .clearCreatorSelection:
            clearSelection()
        default:
            break
        }
    }

    private func menuIcon(_ systemName: String) -> NSImage? {
        NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
    }
    #endif
}

struct CreatorSelectionFloatingActions: View {
    let selectedCount: Int
    let canSelectAll: Bool
    let canCopyLinks: Bool
    let canCopySummary: Bool
    let canCheckFollowVisibility: Bool
    let canFollowPublic: Bool
    let canFollowPrivate: Bool
    let canMute: Bool
    let canUnfollow: Bool
    let isRunningBulkAction: Bool
    let isCheckingFollowVisibility: Bool
    let selectAllVisibleCreators: () -> Void
    let clearSelection: () -> Void
    let copySelectedCreatorLinks: () -> Void
    let copySelectedCreatorSummary: () -> Void
    let checkSelectedFollowVisibility: () -> Void
    let requestBulkAction: (CreatorBulkAction) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            selectionAccessoryControls
                .frame(maxWidth: accessoryMaxWidth)
        }
        .controlSize(.regular)
        .frame(maxWidth: accessoryMaxWidth)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var selectionAccessoryControls: some View {
        if usesCompactAccessory {
            compactAccessoryControls
        } else {
            ViewThatFits(in: .horizontal) {
                wideAccessoryControls
                compactAccessoryControls
            }
        }
    }

    private var compactAccessoryControls: some View {
        HStack(spacing: 8) {
            selectionActionsMenu
                .buttonStyle(.glassProminent)
                .frame(minWidth: 164, maxWidth: .infinity)

            closeButton
        }
    }

    private var wideAccessoryControls: some View {
        HStack(spacing: 10) {
            Label(accessoryTitle, systemImage: accessorySystemImage)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .frame(minWidth: 160, alignment: .leading)

            Divider()
                .frame(height: 26)

            Button {
                selectAllVisibleCreators()
            } label: {
                Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
            }
            .disabled(canSelectAll == false)

            if selectedCount > 0 {
                Button {
                    checkSelectedFollowVisibility()
                } label: {
                    Label(L10n.checkFollowVisibility, systemImage: "checkmark.seal")
                }
                .disabled(canCheckFollowVisibility == false || isCheckingFollowVisibility)

                Button {
                    copySelectedCreatorLinks()
                } label: {
                    Label(L10n.copySelectedCreatorLinks, systemImage: "link")
                }
                .disabled(canCopyLinks == false)

                Button {
                    copySelectedCreatorSummary()
                } label: {
                    Label(L10n.copySelectedCreatorSummary, systemImage: "doc.text")
                }
                .disabled(canCopySummary == false)

                batchActionsMenu

                Button {
                    clearSelection()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }
            }

            closeButton
        }
        .buttonStyle(.glass)
    }

    private var selectionActionsMenu: some View {
        Menu {
            Button {
                selectAllVisibleCreators()
            } label: {
                Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
            }
            .disabled(canSelectAll == false)

            if selectedCount > 0 {
                Button {
                    clearSelection()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }

                Divider()

                Button {
                    checkSelectedFollowVisibility()
                } label: {
                    Label(L10n.checkFollowVisibility, systemImage: "checkmark.seal")
                }
                .disabled(canCheckFollowVisibility == false || isCheckingFollowVisibility)

                Button {
                    copySelectedCreatorLinks()
                } label: {
                    Label(L10n.copySelectedCreatorLinks, systemImage: "link")
                }
                .disabled(canCopyLinks == false)

                Button {
                    copySelectedCreatorSummary()
                } label: {
                    Label(L10n.copySelectedCreatorSummary, systemImage: "doc.text")
                }
                .disabled(canCopySummary == false)

                batchActionsMenu
            }
        } label: {
            Label(accessoryTitle, systemImage: accessorySystemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .help(accessoryTitle)
        .accessibilityLabel(accessoryTitle)
    }

    private var batchActionsMenu: some View {
        Menu {
            Button {
                requestBulkAction(.followPublic)
            } label: {
                Label(L10n.followSelectedPublicly, systemImage: "person.crop.circle.badge.plus")
            }
            .disabled(isRunningBulkAction || canFollowPublic == false)

            Button {
                requestBulkAction(.followPrivate)
            } label: {
                Label(L10n.followSelectedPrivately, systemImage: "lock.circle")
            }
            .disabled(isRunningBulkAction || canFollowPrivate == false)

            Divider()

            Button(role: .destructive) {
                requestBulkAction(.mute)
            } label: {
                Label(L10n.muteSelectedCreators, systemImage: "eye.slash")
            }
            .disabled(isRunningBulkAction || canMute == false)

            Button(role: .destructive) {
                requestBulkAction(.unfollow)
            } label: {
                Label(L10n.unfollowSelectedCreators, systemImage: "person.crop.circle.badge.minus")
            }
            .disabled(isRunningBulkAction || canUnfollow == false)
        } label: {
            Label(L10n.batchActions, systemImage: "person.2.badge.gearshape")
        }
    }

    private var closeButton: some View {
        Button {
            clearSelection()
        } label: {
            Label(L10n.close, systemImage: "xmark")
                .labelStyle(.iconOnly)
        }
        .help(L10n.close)
        .accessibilityLabel(L10n.close)
        .buttonStyle(.glass)
        .frame(width: 44, height: 44)
    }

    private var accessoryTitle: String {
        if selectedCount > 0 {
            return String(format: L10n.selectedCreatorsFormat, selectedCount)
        }
        return L10n.creatorSelection
    }

    private var accessorySystemImage: String {
        selectedCount > 0 ? "checkmark.circle.fill" : "checkmark.circle"
    }

    private var usesCompactAccessory: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var accessoryMaxWidth: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 340 : 980
        #else
        1040
        #endif
    }
}

struct CreatorPreviewListContent: View {
    let mode: UserPreviewListMode
    let layoutMode: CreatorListLayoutMode
    let searchKeyword: String
    let previews: [PixivUserPreview]
    let visiblePreviews: [PixivUserPreview]
    let nextURL: URL?
    let errorMessage: String?
    let isLoadingInitial: Bool
    let isLoadingMore: Bool
    let followRestrictsByUserID: [Int: BookmarkRestrict]
    let updatingCreatorIDs: Set<Int>
    let isCreatorSelectionMode: Bool
    let selectedCreatorIDs: Set<Int>
    let showContentBadges: Bool
    let maskSensitivePreviews: Bool
    let retry: () -> Void
    let loadMore: () -> Void
    let openProfile: (PixivUser) -> Void
    let openIllustrations: (PixivUser) -> Void
    let openManga: (PixivUser) -> Void
    let followCreator: (PixivUser, BookmarkRestrict?) -> Void
    let requestUnfollow: (PixivUser) -> Void
    let requestMuteCreator: (PixivUser) -> Void
    let requestFeedback: (PixivUser) -> Void
    let copyCreatorLink: (PixivUser) -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
    let toggleCreatorSelection: (Int) -> Void
    let isPinnedCreator: (PixivUser) -> Bool
    let togglePinnedCreator: (PixivUser) -> Void
    let selectArtwork: (PixivArtwork) -> Void
    let autoLoadContextKey: String
    let creatorPreviewArtworkCacheGeneration: Int
    let cachedCreatorPreviewArtworks: (PixivUser) -> [PixivArtwork]
    /// Lazy fetcher used when `layoutMode == .single`. The single-card
    /// shelf calls into this to surface more than the 3 illustrations
    /// Pixiv ships in the recommended-users / related-users response.
    let loadCreatorPreviewArtworks: (PixivUser) async throws -> [PixivArtwork]
    @State private var sparseVisibleCreatorTopUpContext = ""
    @State private var sparseVisibleCreatorTopUpCount = 0

    var body: some View {
        if mode.requiresSearchKeyword, searchKeyword.isEmpty {
            CreatorSearchLandingState()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoadingInitial {
            CreatorPreviewListLoadingPlaceholder(layoutMode: layoutMode)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else if previews.isEmpty {
            emptyState
        } else if visiblePreviews.isEmpty {
            ScrollView {
                noMatchingCreators
                    .padding(.leading, listMetrics.insets.leading)
                    .padding(.trailing, listMetrics.insets.trailing)
                    .padding(.top, listMetrics.insets.top)
                    .padding(.bottom, listMetrics.insets.bottom)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            NativeCreatorPreviewCollectionView(
                items: creatorCollectionItems,
                layout: NativeCreatorPreviewCollectionLayout(mode: layoutMode),
                contentReloadToken: creatorContentReloadToken,
                onNearContentEnd: loadMoreFromNearContentEnd
            ) { item in
                nativeCreatorPreviewContent(for: item)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: sparseVisibleCreatorTopUpKey) {
                autoTopUpSparseVisibleCreatorsIfNeeded()
            }
            #if os(iOS)
            .backgroundExtensionEffect(isEnabled: true)
            #endif
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let errorMessage {
            OS26LibraryUnavailableView(
                title: L10n.errorTitle,
                subtitle: errorMessage,
                systemImage: "exclamationmark.triangle"
            ) {
                Button {
                    retry()
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .os26GlassButton(prominent: true)
            }
        } else {
            OS26LibraryUnavailableView(
                title: emptyTitle,
                subtitle: emptyHint,
                systemImage: mode.emptySystemImage
            )
        }
    }

    private var emptyTitle: String {
        if case .pinned = mode {
            return L10n.noPinnedCreators
        }
        return L10n.noCreators
    }

    private var emptyHint: String {
        if case .pinned = mode {
            return L10n.noPinnedCreatorsHint
        }
        return ""
    }

    private var noMatchingCreators: some View {
        VStack(spacing: NativeCollectionLayoutMetrics.informationCardContentSpacing) {
            OS26InlineUnavailableView(
                title: L10n.noMatchingCreators,
                systemImage: "person.crop.circle.badge.questionmark",
                minHeight: 260
            )

            if nextURL != nil {
                CreatorPaginationFooter(isLoadingMore: isLoadingMore, loadMore: loadMore)
                    .task(id: sparseVisibleCreatorTopUpKey) {
                        autoTopUpSparseVisibleCreatorsIfNeeded()
                    }
                    .frame(maxWidth: 420)
            }
        }
    }

    private var listMetrics: NativeCollectionMetrics {
        NativeCollectionLayoutMetrics.informationCards
    }

    private var creatorCollectionItems: [NativeCreatorPreviewCollectionItem] {
        var items = visiblePreviews.map(NativeCreatorPreviewCollectionItem.preview)
        if nextURL != nil {
            items.append(.loadMore)
        }
        return items
    }

    private var shouldAutoTopUpSparseVisibleCreators: Bool {
        nextURL != nil
            && isLoadingInitial == false
            && isLoadingMore == false
            && visiblePreviews.count < Self.minimumAutoFilledCreatorCount
    }

    private var sparseVisibleCreatorTopUpKey: String {
        [
            autoLoadContextKey,
            visiblePreviews.count.description,
            previews.count.description,
            nextURL?.absoluteString ?? "end",
            isLoadingMore.description
        ].joined(separator: "-")
    }

    private static let minimumAutoFilledCreatorCount = 6
    private static let maximumSparseAutoTopUpPages = 2

    private func loadMoreFromNearContentEnd() {
        if visiblePreviews.count < Self.minimumAutoFilledCreatorCount {
            autoTopUpSparseVisibleCreatorsIfNeeded()
        } else {
            loadMore()
        }
    }

    private func autoTopUpSparseVisibleCreatorsIfNeeded() {
        guard shouldAutoTopUpSparseVisibleCreators else { return }
        if sparseVisibleCreatorTopUpContext != autoLoadContextKey {
            sparseVisibleCreatorTopUpContext = autoLoadContextKey
            sparseVisibleCreatorTopUpCount = 0
        }
        guard sparseVisibleCreatorTopUpCount < Self.maximumSparseAutoTopUpPages else { return }
        sparseVisibleCreatorTopUpCount += 1
        loadMore()
    }

    private var creatorContentReloadToken: Int {
        var hasher = Hasher()
        hasher.combine(layoutMode.rawValue)
        hasher.combine(showContentBadges)
        hasher.combine(maskSensitivePreviews)
        hasher.combine(isLoadingMore)
        hasher.combine(creatorPreviewArtworkCacheGeneration)
        hasher.combine(isCreatorSelectionMode)
        hasher.combine(selectedCreatorIDs.count)
        for userID in selectedCreatorIDs.sorted() {
            hasher.combine(userID)
        }
        for preview in visiblePreviews {
            hasher.combine(preview.user)
            hasher.combine(preview.isMuted)
            hasher.combine(followRestrictsByUserID[preview.user.id])
            hasher.combine(updatingCreatorIDs.contains(preview.user.id))
            for artwork in preview.illusts.prefix(6) {
                hasher.combine(artwork.id)
                hasher.combine(artwork.thumbnailURL?.absoluteString)
                hasher.combine(artwork.pageCount)
                hasher.combine(artwork.xRestrict)
                hasher.combine(artwork.isAI)
            }
        }
        return hasher.finalize()
    }

    private func nativeCreatorPreviewContent(for item: NativeCreatorPreviewCollectionItem) -> AnyView {
        switch item {
        case .preview(let preview):
            return AnyView(
                UserPreviewCard(
                    preview: preview,
                    followRestrict: followRestrictsByUserID[preview.user.id],
                    isUpdating: updatingCreatorIDs.contains(preview.user.id),
                    showContentBadges: showContentBadges,
                    maskSensitivePreviews: maskSensitivePreviews,
                    expandedPreview: layoutMode.usesExpandedPreview,
                    openProfile: { openProfile(preview.user) },
                    openIllustrations: { openIllustrations(preview.user) },
                    openManga: { openManga(preview.user) },
                    followCreator: { restrict in followCreator(preview.user, restrict) },
                    requestUnfollow: { requestUnfollow(preview.user) },
                    requestMuteCreator: { requestMuteCreator(preview.user) },
                    requestFeedback: { requestFeedback(preview.user) },
                    copyCreatorLink: { copyCreatorLink(preview.user) },
                    copyArtworkLink: copyArtworkLink,
                    isSelectionMode: isCreatorSelectionMode,
                    isSelected: selectedCreatorIDs.contains(preview.user.id),
                    toggleSelection: { toggleCreatorSelection(preview.user.id) },
                    isPinned: isPinnedCreator(preview.user),
                    togglePinnedCreator: { togglePinnedCreator(preview.user) },
                    selectArtwork: selectArtwork,
                    cachedPreviewArtworks: cachedCreatorPreviewArtworks(preview.user),
                    loadExpandedArtworks: { try await loadCreatorPreviewArtworks(preview.user) }
                )
            )
        case .loadMore:
            return AnyView(
                CreatorPaginationFooter(isLoadingMore: isLoadingMore, loadMore: loadMore)
                    .task(id: sparseVisibleCreatorTopUpKey) {
                        autoTopUpSparseVisibleCreatorsIfNeeded()
                    }
            )
        case .artwork:
            return AnyView(EmptyView())
        }
    }
}

private struct CreatorSearchLandingState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: NativeCollectionLayoutMetrics.informationCardContentSpacing) {
            Label {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.enterSearchKeyword)
                        .font(.headline)
                    Text(L10n.searchCreatorsInList)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label(L10n.searchCreators, systemImage: "magnifyingglass")
                Text(L10n.search)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule(style: .continuous))
        }
        .padding(NativeCollectionLayoutMetrics.informationCardPadding)
        .frame(maxWidth: 520, alignment: .leading)
        .keiGlass(22)
        .padding(.leading, NativeCollectionLayoutMetrics.informationCards.insets.leading)
        .padding(.trailing, NativeCollectionLayoutMetrics.informationCards.insets.trailing)
        .padding(.top, NativeCollectionLayoutMetrics.informationCards.insets.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityLabel(L10n.enterSearchKeyword)
    }
}

private struct CreatorPreviewListLoadingPlaceholder: View {
    let layoutMode: CreatorListLayoutMode

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: metrics.itemSpacing) {
                ForEach(0..<placeholderCount, id: \.self) { _ in
                    CreatorPreviewSkeletonCard(expanded: layoutMode.usesExpandedPreview)
                }
            }
            .padding(.leading, metrics.insets.leading)
            .padding(.trailing, metrics.insets.trailing)
            .padding(.top, metrics.insets.top)
            .padding(.bottom, metrics.insets.bottom)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .allowsHitTesting(false)
        .accessibilityLabel(L10n.loading)
    }

    private var placeholderCount: Int {
        layoutMode.usesExpandedPreview ? 4 : 8
    }

    private var metrics: NativeCollectionMetrics {
        NativeCollectionLayoutMetrics.informationCards
    }

    private var columns: [GridItem] {
        let minimum: CGFloat = layoutMode.usesExpandedPreview ? 380 : 280
        return [
            GridItem(.adaptive(minimum: minimum, maximum: layoutMode.usesExpandedPreview ? 540 : 380), spacing: metrics.itemSpacing)
        ]
    }
}

private struct CreatorPreviewSkeletonCard: View {
    let expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: NativeCollectionLayoutMetrics.informationCardContentSpacing) {
            HStack(alignment: .center, spacing: 12) {
                SkeletonPlaceholder(width: 44, height: 44, cornerRadius: 22)

                VStack(alignment: .leading, spacing: 7) {
                    SkeletonPlaceholder(width: nil, height: 16, cornerRadius: 8)
                        .frame(maxWidth: 150)
                    SkeletonPlaceholder(width: nil, height: 12, cornerRadius: 6)
                        .frame(maxWidth: 96)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SkeletonPlaceholder(width: 28, height: 28, cornerRadius: 14)
            }

            HStack(spacing: 8) {
                SkeletonPlaceholder(width: 54, height: 22, cornerRadius: 11)
                SkeletonPlaceholder(width: 64, height: 22, cornerRadius: 11)
                SkeletonPlaceholder(width: 44, height: 22, cornerRadius: 11)
                Spacer(minLength: 0)
            }

            if expanded {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonPlaceholder(width: nil, height: 108, cornerRadius: 14)
                    }
                }
            } else {
                SkeletonPlaceholder(width: nil, height: 88, cornerRadius: 14)
            }
        }
        .padding(NativeCollectionLayoutMetrics.informationCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .os26SkeletonSurface(20)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CreatorPaginationFooter: View {
    let isLoadingMore: Bool
    let loadMore: () -> Void

    var body: some View {
        OS26PaginationFooter(
            loadingTitle: L10n.loading,
            systemImage: "arrow.down.circle",
            isLoading: isLoadingMore,
            minHeight: 160
        ) {
            loadMore()
        }
    }
}
