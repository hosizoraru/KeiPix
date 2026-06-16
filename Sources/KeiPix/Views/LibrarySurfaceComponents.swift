import SwiftUI
#if os(iOS)
    import UIKit
#endif

struct OS26LibrarySearchField: View {
    @Binding private var text: String
    private let placeholder: String
    private let suggestions: [String]
    private let minWidth: CGFloat
    private let idealWidth: CGFloat
    private let maxWidth: CGFloat
    private let collapsesOnPhone: Bool
    private let onClose: (() -> Void)?
    private let onSubmit: () -> Void
    @State private var isExpanded = false

    init(
        text: Binding<String>,
        placeholder: String,
        suggestions: [String] = [],
        minWidth: CGFloat = 180,
        idealWidth: CGFloat = 240,
        maxWidth: CGFloat = 320,
        collapsesOnPhone: Bool = true,
        onClose: (() -> Void)? = nil,
        onSubmit: @escaping () -> Void = {}
    ) {
        _text = text
        self.placeholder = placeholder
        self.suggestions = suggestions
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.collapsesOnPhone = collapsesOnPhone
        self.onClose = onClose
        self.onSubmit = onSubmit
    }

    var body: some View {
        #if os(iOS)
            if usesCollapsedPhoneSearch {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded = true
                    }
                } label: {
                    Label(L10n.search, systemImage: "magnifyingglass")
                        .lineLimit(1)
                }
                .os26GlassButton()
                .accessibilityLabel(placeholder)
            } else if isPhone {
                HStack(spacing: 8) {
                    nativeField
                        .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)

                    if text.isEmpty {
                        Button {
                            withAnimation(.snappy(duration: 0.16)) {
                                if let onClose {
                                    onClose()
                                } else {
                                    isExpanded = false
                                }
                            }
                        } label: {
                            Label(L10n.close, systemImage: "xmark.circle.fill")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(L10n.close)
                        .accessibilityLabel(L10n.close)
                    }
                }
            } else {
                nativeField
                    .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)
            }
        #else
            nativeField
                .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)
        #endif
    }

    private var nativeField: some View {
        NativeSearchField(
            text: $text,
            placeholder: placeholder,
            suggestions: suggestions,
            onSubmit: onSubmit,
            onTextChange: { text = $0 }
        )
        .accessibilityLabel(placeholder)
    }

    #if os(iOS)
        private var usesCollapsedPhoneSearch: Bool {
            collapsesOnPhone && isPhone && text.isEmpty && isExpanded == false
        }

        private var isPhone: Bool {
            UIDevice.current.userInterfaceIdiom == .phone
        }
    #endif
}

struct OS26LibraryTextEntryField: View {
    @Binding private var text: String
    private let placeholder: String
    private let minWidth: CGFloat

    init(
        text: Binding<String>,
        placeholder: String,
        minWidth: CGFloat = 180
    ) {
        _text = text
        self.placeholder = placeholder
        self.minWidth = minWidth
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minWidth: minWidth, minHeight: 32)
            .keiInteractiveGlass(14)
            .accessibilityLabel(placeholder)
    }
}

struct OS26LibraryActionRail<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                content
            }
        }
    }
}

struct OS26LibraryLoadingView: View {
    let title: String
    let systemImage: String

    var body: some View {
        #if os(iOS)
            NativeBottomTabScrollContentHost {
                loadingCard
            }
        #else
            loadingCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 46, height: 46)
                    .keiGlass(18)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                    SkeletonPlaceholder(width: 220, height: 12, cornerRadius: 6)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(0 ..< 5, id: \.self) { index in
                    SkeletonPlaceholder(
                        width: index.isMultiple(of: 2) ? nil : 280,
                        height: 18,
                        cornerRadius: 9
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
        .keiGlass(30)
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct OS26InlineLoadingView: View {
    let title: String
    let systemImage: String
    var minHeight: CGFloat = 140

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
                .keiGlass(18)

            VStack(spacing: 7) {
                Text(title)
                    .font(.headline)
                SkeletonPlaceholder(width: 180, height: 12, cornerRadius: 6)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .os26SkeletonSurface(24)
    }
}

struct OS26InlineUnavailableView<Actions: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var minHeight: CGFloat = 150
    private let actions: Actions

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        minHeight: CGFloat = 150,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.minHeight = minHeight
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 5) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .frame(maxWidth: 420)
                }
            }

            actions
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .os26SkeletonSurface(22)
    }
}

extension OS26InlineUnavailableView where Actions == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String, minHeight: CGFloat = 150) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, minHeight: minHeight) {
            EmptyView()
        }
    }
}

struct OS26SkeletonCardSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.separator.opacity(0.22), lineWidth: 1)
            }
    }
}

struct OS26GlassCompatibleSegmentedPicker<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    let minWidth: CGFloat
    let idealWidth: CGFloat
    let maxWidth: CGFloat
    private let content: Content

    init(
        _ title: String,
        selection: Binding<Selection>,
        minWidth: CGFloat,
        idealWidth: CGFloat,
        maxWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        _selection = selection
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                Picker(title, selection: $selection) {
                    content
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)
                .accessibilityLabel(title)

                Picker(title, selection: $selection) {
                    content
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityLabel(title)
            }
        }
    }
}

extension View {
    func os26SkeletonSurface(_ cornerRadius: CGFloat = 18) -> some View {
        modifier(OS26SkeletonCardSurface(cornerRadius: cornerRadius))
    }
}

struct OS26LibraryUnavailableView<Actions: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    private let actions: Actions

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        #if os(iOS)
            NativeBottomTabScrollContentHost {
                unavailableCard
            }
        #else
            unavailableCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    private var unavailableCard: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 72, height: 72)
                    .keiGlass(24)

                VStack(spacing: 7) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    if let subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                            .frame(maxWidth: 420)
                    }
                }

                actions
            }
            .padding(28)
            .frame(maxWidth: 520)
            .keiGlass(30)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

extension OS26LibraryUnavailableView where Actions == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage) {
            EmptyView()
        }
    }
}

struct OS26PaginationFooter: View {
    let loadingTitle: String
    let systemImage: String
    let isLoading: Bool
    var minHeight: CGFloat = 88
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)

                Text(loadingTitle)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLoading ? loadingTitle : "")
        .onAppear(perform: action)
    }
}

extension View {
    @ViewBuilder
    func os26GlassButton(prominent: Bool = false) -> some View {
        if prominent {
            buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
        } else {
            buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        }
    }

    @ViewBuilder
    func os26GlassIconButton(prominent: Bool = false) -> some View {
        if prominent {
            labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
        } else {
            labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        }
    }
}

struct OS26SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    private let content: Content
    @Environment(\.os26SettingsPageShowsHeader) private var showsHeader
    @Environment(\.os26SettingsPageUsesAdaptiveGrid) private var usesAdaptiveGrid

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = OS26SettingsPageMetrics(
                availableWidth: proxy.size.width,
                showsHeader: showsHeader,
                usesAdaptiveGrid: usesAdaptiveGrid
            )

            ScrollView {
                VStack(alignment: .leading, spacing: metrics.verticalSpacing) {
                    if showsHeader {
                        OS26SettingsPageHeader(
                            title: title,
                            subtitle: subtitle,
                            systemImage: systemImage
                        )
                    }

                    if usesAdaptiveGrid {
                        LazyVGrid(
                            columns: metrics.columns,
                            alignment: .leading,
                            spacing: metrics.gridSpacing
                        ) {
                            content
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            content
                        }
                    }
                }
                .frame(maxWidth: metrics.pageMaxWidth, alignment: .leading)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)
                .frame(maxWidth: .infinity, alignment: metrics.pageAlignment)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(showsHeader ? title : "")
        #if !os(macOS)
            .navigationBarTitleDisplayMode(showsHeader ? .automatic : .inline)
        #endif
    }
}

private struct OS26SettingsPageMetrics {
    let availableWidth: CGFloat
    let showsHeader: Bool
    let usesAdaptiveGrid: Bool

    var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: gridSpacing, alignment: .top),
            count: columnCount
        )
    }

    var columnCount: Int {
        guard usesAdaptiveGrid else { return 1 }
        let width = contentWidth
        #if os(macOS)
            if width >= 1040 { return 3 }
            if width >= 680 { return 2 }
            return 1
        #else
            if width >= 900 { return 3 }
            if width >= 590 { return 2 }
            return 1
        #endif
    }

    var contentWidth: CGFloat {
        min(pageMaxWidth, max(0, availableWidth - horizontalPadding * 2))
    }

    var pageMaxWidth: CGFloat {
        guard usesAdaptiveGrid else { return 860 }
        #if os(macOS)
            return 1180
        #else
            if availableWidth < 560 {
                return 520
            }
            if availableWidth < 900 {
                return 860
            }
            return 1160
        #endif
    }

    var horizontalPadding: CGFloat {
        #if os(macOS)
            return 28
        #else
            if availableWidth < 430 {
                return 12
            }
            if availableWidth < 900 {
                return 16
            }
            return 18
        #endif
    }

    var gridSpacing: CGFloat {
        #if os(macOS)
            return 16
        #else
            return availableWidth < 560 ? 12 : 14
        #endif
    }

    var verticalSpacing: CGFloat {
        showsHeader ? 18 : gridSpacing
    }

    var topPadding: CGFloat {
        showsHeader ? 20 : 8
    }

    var bottomPadding: CGFloat {
        #if os(macOS)
            return 20
        #else
            return availableWidth < 900 ? 14 : 20
        #endif
    }

    var pageAlignment: Alignment {
        #if os(macOS)
            return .topLeading
        #else
            return .top
        #endif
    }
}

struct OS26SettingsPageHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                icon
                titleBlock
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                icon
                titleBlock
            }
        }
        .padding(.top, 4)
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.primary)
            .frame(width: 50, height: 50)
            .keiGlass(18)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum OS26SettingsTone: Equatable {
    case neutral
    case accent
    case safety
    case privacy
    case danger
    case warning
    case network
    case downloads
    case storage

    var symbolColor: Color {
        switch self {
        case .neutral:
            .secondary
        case .accent:
            .accentColor
        case .safety:
            .green
        case .privacy:
            .indigo
        case .danger:
            .red
        case .warning:
            .orange
        case .network:
            .cyan
        case .downloads:
            .blue
        case .storage:
            .teal
        }
    }
}

struct OS26SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String?
    let tone: OS26SettingsTone
    let footer: String?
    private let content: Content

    init(
        _ title: String,
        systemImage: String? = nil,
        tone: OS26SettingsTone = .neutral,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tone.symbolColor)
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let footer, footer.isEmpty == false {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(22)
    }
}

struct OS26SettingsDivider: View {
    var body: some View {
        Divider()
            .opacity(0.55)
    }
}

struct OS26SettingsRowLabel: View {
    let title: String
    var detail: String?
    var systemImage: String?
    var tone: OS26SettingsTone = .neutral

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tone.symbolColor)
                    .frame(width: 20, alignment: .center)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail, detail.isEmpty == false {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OS26SettingsControlRow<Accessory: View>: View {
    let title: String
    var detail: String?
    var systemImage: String?
    var tone: OS26SettingsTone = .neutral
    private let accessory: Accessory
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    init(
        title: String,
        detail: String? = nil,
        systemImage: String? = nil,
        tone: OS26SettingsTone = .neutral,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.tone = tone
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            label
                .layoutPriority(1)

            accessory
                .lineLimit(1)
                .frame(width: accessoryWidth, alignment: .trailing)
                .layoutPriority(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var label: some View {
        OS26SettingsRowLabel(title: title, detail: detail, systemImage: systemImage, tone: tone)
    }

    private var accessoryWidth: CGFloat {
        #if os(iOS)
            horizontalSizeClass == .compact ? 112 : 150
        #else
            160
        #endif
    }
}

struct OS26SettingsToggleRow: View {
    let title: String
    var detail: String?
    var systemImage: String?
    var tone: OS26SettingsTone = .neutral
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            OS26SettingsRowLabel(title: title, detail: detail, systemImage: systemImage, tone: tone)
        }
    }
}

struct OS26SettingsMenuPicker<Option: Identifiable & Hashable, RowLabel: View>: View {
    let title: String
    let value: String
    var detail: String?
    var systemImage: String?
    var tone: OS26SettingsTone = .neutral
    @Binding private var selection: Option
    private let options: [Option]
    private let rowLabel: (Option, Bool) -> RowLabel

    init(
        title: String,
        value: String,
        detail: String? = nil,
        systemImage: String? = nil,
        tone: OS26SettingsTone = .neutral,
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder rowLabel: @escaping (Option, Bool) -> RowLabel
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.tone = tone
        _selection = selection
        self.options = options
        self.rowLabel = rowLabel
    }

    var body: some View {
        #if os(macOS)
            menuPicker
        #else
            inlineOptionPicker
        #endif
    }

    private var menuPicker: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    rowLabel(option, option == selection)
                }
            }
        } label: {
            OS26SettingsControlRow(title: title, detail: detail, systemImage: systemImage, tone: tone) {
                OS26SettingsPickerValueLabel(value: value, chevronSystemImage: "chevron.up.chevron.down")
                    .accessibilityValue(value)
            }
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }

    private var inlineOptionPicker: some View {
        OS26SettingsInlineOptionPicker(
            title: title,
            value: value,
            detail: detail,
            systemImage: systemImage,
            tone: tone,
            selection: $selection,
            options: options,
            rowLabel: rowLabel
        )
    }
}

struct OS26SettingsInlineOptionPicker<Option: Identifiable & Hashable, RowLabel: View>: View {
    let title: String
    let value: String
    var detail: String?
    var systemImage: String?
    var tone: OS26SettingsTone = .neutral
    @Binding private var selection: Option
    @State private var isExpanded = false
    private let options: [Option]
    private let rowLabel: (Option, Bool) -> RowLabel

    init(
        title: String,
        value: String,
        detail: String? = nil,
        systemImage: String? = nil,
        tone: OS26SettingsTone = .neutral,
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder rowLabel: @escaping (Option, Bool) -> RowLabel
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.tone = tone
        _selection = selection
        self.options = options
        self.rowLabel = rowLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                OS26SettingsControlRow(title: title, detail: detail, systemImage: systemImage, tone: tone) {
                    OS26SettingsPickerValueLabel(
                        value: value,
                        chevronSystemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .accessibilityValue(value)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue(value)
            .accessibilityHint(detail ?? "")

            if isExpanded {
                optionList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var optionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .opacity(0.45)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(options) { option in
                    optionButton(for: option)
                }
            }
        }
        .padding(.top, 2)
    }

    private func optionButton(for option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            withAnimation(.snappy(duration: 0.16)) {
                selection = option
                isExpanded = false
            }
        } label: {
            rowLabel(option, isSelected)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? tone.symbolColor : .primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tone.symbolColor.opacity(0.12))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OS26SettingsPickerValueLabel: View {
    let value: String
    let chevronSystemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: chevronSystemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

struct OS26SettingsActionButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    var isProminent = false
    var tone: OS26SettingsTone = .neutral
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
        .os26GlassButton(prominent: isProminent)
        .tint(actionTint)
    }

    private var actionTint: Color? {
        if role == .destructive {
            return .red
        }
        return tone == .neutral ? nil : tone.symbolColor
    }
}

struct OS26SettingsLinkButton: View {
    let title: String
    let systemImage: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
        .os26GlassButton()
    }
}

struct OS26SettingsStatusPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: Capsule(style: .continuous))
    }
}

private struct OS26SettingsPageShowsHeaderKey: EnvironmentKey {
    static let defaultValue = true
}

private struct OS26SettingsPageUsesAdaptiveGridKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var os26SettingsPageShowsHeader: Bool {
        get { self[OS26SettingsPageShowsHeaderKey.self] }
        set { self[OS26SettingsPageShowsHeaderKey.self] = newValue }
    }

    var os26SettingsPageUsesAdaptiveGrid: Bool {
        get { self[OS26SettingsPageUsesAdaptiveGridKey.self] }
        set { self[OS26SettingsPageUsesAdaptiveGridKey.self] = newValue }
    }
}
