import SwiftUI
#if os(iOS)
import UIKit
#endif

enum ReaderPlatformKind: Equatable, Sendable {
    case phone
    case pad
    case mac

    #if os(iOS)
    @MainActor
    static var current: ReaderPlatformKind {
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
    }
    #else
    static var current: ReaderPlatformKind {
        .mac
    }
    #endif
}

struct ReaderAdaptiveLayout: Equatable, Sendable {
    static let iPadDoublePageMinimumWidth: CGFloat = 760
    static let iPadDoublePageMinimumHeight: CGFloat = 600
    static let iPadAutoDoublePageMinimumWidth: CGFloat = 940
    static let macDoublePageMinimumWidth: CGFloat = 820
    static let macDoublePageMinimumHeight: CGFloat = 600
    static let macAutoDoublePageMinimumWidth: CGFloat = 1_060

    let availableSize: CGSize
    let platform: ReaderPlatformKind

    init(availableSize: CGSize, platform: ReaderPlatformKind) {
        self.availableSize = availableSize
        self.platform = platform
    }

    var isLandscape: Bool {
        availableSize.width > availableSize.height
    }

    var validWidth: CGFloat {
        guard availableSize.width.isFinite, availableSize.width > 0 else { return 0 }
        return availableSize.width
    }

    var validHeight: CGFloat {
        guard availableSize.height.isFinite, availableSize.height > 0 else { return 0 }
        return availableSize.height
    }

    var allowsDoublePage: Bool {
        switch platform {
        case .phone:
            false
        case .pad:
            validWidth >= Self.iPadDoublePageMinimumWidth
                && validHeight >= Self.iPadDoublePageMinimumHeight
        case .mac:
            validWidth >= Self.macDoublePageMinimumWidth
                && validHeight >= Self.macDoublePageMinimumHeight
        }
    }

    var prefersAutomaticDoublePage: Bool {
        guard allowsDoublePage else { return false }
        return switch platform {
        case .phone:
            false
        case .pad:
            isLandscape && validWidth >= Self.iPadAutoDoublePageMinimumWidth
        case .mac:
            validWidth >= Self.macAutoDoublePageMinimumWidth
        }
    }

    static func usesContinuousNovelReader(platform: ReaderPlatformKind) -> Bool {
        platform == .phone
    }

    static func effectiveNovelMode(
        preferredMode: NovelReadingMode,
        pageCount: Int,
        availableSize: CGSize,
        platform: ReaderPlatformKind
    ) -> NovelReadingMode {
        guard pageCount > 1 else { return .singlePage }
        let layout = ReaderAdaptiveLayout(availableSize: availableSize, platform: platform)
        guard layout.allowsDoublePage else { return .singlePage }
        if preferredMode == .doublePage {
            return .doublePage
        }
        return .singlePage
    }

    static func effectiveArtworkMode(
        preferredMode: ArtworkReadingMode,
        pageCount: Int,
        availableSize: CGSize,
        platform: ReaderPlatformKind
    ) -> ArtworkReadingMode {
        let mode = preferredMode.effectiveMode(forPageCount: pageCount)
        guard mode == .doublePage else { return mode }
        let layout = ReaderAdaptiveLayout(availableSize: availableSize, platform: platform)
        return layout.allowsDoublePage ? .doublePage : .singlePage
    }
}

struct SinglePageReaderViewportLayout: Layout {
    let presentation: ReaderPagePresentation
    var fallbackWidth: CGFloat = 640

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(from: proposal)
        return CGSize(width: width, height: presentation.singlePageHeight(for: width))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
        }
    }

    private func resolvedWidth(from proposal: ProposedViewSize) -> CGFloat {
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return fallbackWidth
        }
        return width
    }
}

struct DoublePageReaderViewportLayout: Layout {
    let leftPresentation: ReaderPagePresentation
    let rightPresentation: ReaderPagePresentation?
    var fallbackWidth: CGFloat = 900

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(from: proposal)
        return CGSize(
            width: width,
            height: leftPresentation.doublePageHeight(for: width, pairedWith: rightPresentation)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
        }
    }

    private func resolvedWidth(from proposal: ProposedViewSize) -> CGFloat {
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return fallbackWidth
        }
        return width
    }
}
