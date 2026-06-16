import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private struct ChromeMaterialModeKey: EnvironmentKey {
    static let defaultValue: ChromeMaterialMode = .liquidGlass
}

extension EnvironmentValues {
    var chromeMaterialMode: ChromeMaterialMode {
        get { self[ChromeMaterialModeKey.self] }
        set { self[ChromeMaterialModeKey.self] = newValue }
    }
}

extension View {
    func keiGlass(_ radius: CGFloat = 18) -> some View {
        modifier(KeiGlassModifier(radius: radius, isInteractive: false))
    }

    func keiInteractiveGlass(_ radius: CGFloat = 18) -> some View {
        modifier(KeiGlassModifier(radius: radius, isInteractive: true))
    }

    @ViewBuilder
    func platformGlassControlBar(
        verticalPadding: CGFloat = 8,
        topPadding: CGFloat = 4,
        bottomPadding: CGFloat = 8
    ) -> some View {
        modifier(PlatformGlassControlBarModifier(
            verticalPadding: verticalPadding,
            topPadding: topPadding,
            bottomPadding: bottomPadding
        ))
    }

    func keiPanel(_ radius: CGFloat = 16, clipsContent: Bool = false) -> some View {
        modifier(KeiPanelModifier(radius: radius, clipsContent: clipsContent))
    }

    @ViewBuilder
    func macOSWindowCompanionBackground() -> some View {
        #if os(macOS)
        if #available(macOS 27.0, *) {
            self.background(.windowBackground)
        } else {
            self.background(.background)
        }
        #else
        self.background(.background)
        #endif
    }

    func cardPadding() -> some View {
        padding(14)
    }
}

private struct KeiGlassModifier: ViewModifier {
    let radius: CGFloat
    let isInteractive: Bool
    @Environment(\.chromeMaterialMode) private var chromeMaterialMode

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = ButtonBorderShape.roundedRectangle(radius: radius)
        switch chromeMaterialMode {
        case .liquidGlass:
            if isInteractive {
                content
                    .containerShape(shape)
                    .glassEffect(.regular.interactive(), in: shape)
            } else {
                content
                    .containerShape(shape)
                    .glassEffect(.regular, in: shape)
            }
        case .translucentBlur:
            content
                .containerShape(shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.separator.opacity(0.22), lineWidth: 1)
                }
        case .plain:
            content
                .containerShape(shape)
                .background(Color.keiPlainChromeFill, in: shape)
                .overlay {
                    shape.stroke(.separator.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

private struct PlatformGlassControlBarModifier: ViewModifier {
    let verticalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    @Environment(\.chromeMaterialMode) private var chromeMaterialMode

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        if chromeMaterialMode == .liquidGlass {
            GlassEffectContainer(spacing: 12) {
                barContent(content, horizontalPadding: 12, radius: 16)
            }
                .padding(.horizontal, 18)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        } else {
            barContent(content, horizontalPadding: 12, radius: 16)
                .padding(.horizontal, 18)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
        #else
        if chromeMaterialMode == .liquidGlass {
            GlassEffectContainer(spacing: 12) {
                barContent(content, horizontalPadding: 14, radius: 20)
            }
                .padding(.horizontal, 18)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        } else {
            barContent(content, horizontalPadding: 14, radius: 20)
                .padding(.horizontal, 18)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
        #endif
    }

    @ViewBuilder
    private func barContent(_ content: Content, horizontalPadding: CGFloat, radius: CGFloat) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .keiGlass(radius)
    }
}

private struct KeiPanelModifier: ViewModifier {
    let radius: CGFloat
    let clipsContent: Bool
    @Environment(\.chromeMaterialMode) private var chromeMaterialMode

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = ButtonBorderShape.roundedRectangle(radius: radius)
        let panel = panelBody(content, shape: shape)
        if clipsContent {
            panel.clipShape(shape)
        } else {
            panel
        }
    }

    @ViewBuilder
    private func panelBody(_ content: Content, shape: ButtonBorderShape) -> some View {
        switch chromeMaterialMode {
        case .liquidGlass:
            content
                .containerShape(shape)
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 1)
                }
        case .translucentBlur:
            content
                .containerShape(shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.separator.opacity(0.22), lineWidth: 1)
                }
        case .plain:
            content
                .containerShape(shape)
                .background(Color.keiPlainChromeFill, in: shape)
                .overlay {
                    shape.stroke(.separator.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

private extension Color {
    static var keiPlainChromeFill: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor).opacity(0.94)
        #else
        Color(uiColor: .secondarySystemBackground).opacity(0.94)
        #endif
    }
}

extension String {
    var htmlStripped: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
