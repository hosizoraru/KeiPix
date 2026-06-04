import CoreGraphics

#if os(macOS)
struct MacBrowserWorkspaceLayout: Equatable {
    enum DetailKind: Equatable {
        case artwork
        case spotlight
        case novel
    }

    let availableWidth: CGFloat
    let route: PixivRoute
    let isDetailRequested: Bool
    let hasSelection: Bool

    private let dividerWidth: CGFloat = 1

    var detailKind: DetailKind? {
        if route == .spotlight {
            .spotlight
        } else if route.usesNovelFeed {
            .novel
        } else if route.usesArtworkFeed {
            .artwork
        } else {
            nil
        }
    }

    var supportsDetailPanel: Bool {
        detailKind != nil
    }

    var feedMinimumWidth: CGFloat {
        switch detailKind {
        case .spotlight:
            560
        case .novel:
            620
        case .artwork:
            640
        case nil:
            route.isCreatorRoute ? 720 : 560
        }
    }

    var detailMinimumWidth: CGFloat {
        switch detailKind {
        case .spotlight:
            420
        case .novel:
            380
        case .artwork:
            360
        case nil:
            0
        }
    }

    var detailMaximumWidth: CGFloat {
        switch detailKind {
        case .spotlight:
            620
        case .novel:
            520
        case .artwork:
            500
        case nil:
            0
        }
    }

    var detailWidthFraction: CGFloat {
        switch detailKind {
        case .spotlight:
            0.42
        case .novel:
            0.38
        case .artwork:
            0.34
        case nil:
            0
        }
    }

    var showsDetailPanel: Bool {
        guard supportsDetailPanel, isDetailRequested, hasSelection else {
            return false
        }
        return availableWidth >= feedMinimumWidth + detailMinimumWidth + dividerWidth
    }

    var detailWidth: CGFloat {
        guard showsDetailPanel else {
            return 0
        }
        let widthFromRatio = max(detailMinimumWidth, availableWidth * detailWidthFraction)
        let widthAllowedByFeed = max(detailMinimumWidth, availableWidth - feedMinimumWidth - dividerWidth)
        return min(widthFromRatio, detailMaximumWidth, widthAllowedByFeed)
    }

    var feedWidth: CGFloat {
        guard showsDetailPanel else {
            return availableWidth
        }
        return max(feedMinimumWidth, availableWidth - detailWidth - dividerWidth)
    }
}
#endif
