import SwiftUI

struct OS26LibrarySearchField: View {
    @Binding private var text: String
    private let placeholder: String
    private let suggestions: [String]
    private let minWidth: CGFloat
    private let idealWidth: CGFloat
    private let maxWidth: CGFloat
    private let onSubmit: () -> Void

    init(
        text: Binding<String>,
        placeholder: String,
        suggestions: [String] = [],
        minWidth: CGFloat = 180,
        idealWidth: CGFloat = 240,
        maxWidth: CGFloat = 320,
        onSubmit: @escaping () -> Void = {}
    ) {
        _text = text
        self.placeholder = placeholder
        self.suggestions = suggestions
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.onSubmit = onSubmit
    }

    var body: some View {
        NativeSearchField(
            text: $text,
            placeholder: placeholder,
            suggestions: suggestions,
            onSubmit: onSubmit,
            onTextChange: { text = $0 }
        )
        .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)
        .accessibilityLabel(placeholder)
    }
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
                ForEach(0..<5, id: \.self) { index in
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension OS26LibraryUnavailableView where Actions == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage) {
            EmptyView()
        }
    }
}

struct OS26LoadMoreButton: View {
    let title: String
    let loadingTitle: String
    let systemImage: String
    let isLoading: Bool
    var minHeight: CGFloat = 132
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : systemImage)
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(isLoading ? loadingTitle : title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? loadingTitle : title)
    }
}

extension View {
    @ViewBuilder
    func os26GlassButton(prominent: Bool = false) -> some View {
        if prominent {
            self
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
        } else {
            self
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        }
    }

    @ViewBuilder
    func os26GlassIconButton(prominent: Bool = false) -> some View {
        if prominent {
            self
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
        } else {
            self
                .labelStyle(.iconOnly)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OS26SettingsPageHeader(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage
                )

                content
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(title)
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        28
        #else
        18
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
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OS26SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String?
    let footer: String?
    private let content: Content

    init(
        _ title: String,
        systemImage: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
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

struct OS26SettingsActionButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
        .os26GlassButton(prominent: isProminent)
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
