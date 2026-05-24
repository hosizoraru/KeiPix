import SwiftUI

struct UserProfileMetricsSection: View {
    let profile: PixivUserProfile?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                ProfileMetric(title: L10n.illustrations, value: profile?.totalIllusts ?? 0, systemImage: "photo")
                ProfileMetric(title: L10n.manga, value: profile?.totalManga ?? 0, systemImage: "book.pages")
                ProfileMetric(title: L10n.publicSaves, value: profile?.totalIllustBookmarksPublic ?? 0, systemImage: "bookmark")
                ProfileMetric(title: L10n.followingCreators, value: profile?.totalFollowUsers ?? 0, systemImage: "person.2")
            }
        }
        .padding(14)
        .keiPanel(14)
    }
}

struct UserProfileDescriptionSection: View {
    let text: String?

    var body: some View {
        if let text, text.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.description, systemImage: "text.alignleft")
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(14)
            .keiPanel(14)
        }
    }
}

struct UserProfileLinksSection: View {
    let user: PixivUser
    let profile: PixivUserProfile?

    var body: some View {
        if visibleEntries.isEmpty == false || profile?.region != nil || profile?.job != nil {
            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.links, systemImage: "link")
                    .font(.headline)

                FlowLayout(spacing: 8) {
                    ForEach(visibleEntries, id: \.0) { title, url in
                        Link(destination: url) {
                            Label(title, systemImage: title == "Pixiv" ? "safari" : "link")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if let region = profile?.region, region.isEmpty == false {
                    ProfileInfoLine(title: L10n.region, value: region)
                }
                if let job = profile?.job, job.isEmpty == false {
                    ProfileInfoLine(title: L10n.job, value: job)
                }
            }
            .padding(14)
            .keiPanel(14)
        }
    }

    private var visibleEntries: [(String, URL)] {
        [
            ("Pixiv", user.pixivURL),
            ("Web", profile?.webpage),
            ("X", profile?.twitterURL),
            ("Pawoo", profile?.pawooURL)
        ].compactMap { title, url in
            url.map { (title, $0) }
        }
    }
}

struct UserProfileWorkspaceSection: View {
    let workspace: PixivUserWorkspace?

    var body: some View {
        if let workspace {
            let entries = workspace.infoEntries
            let comment = workspace.trimmedComment

            if entries.isEmpty == false || comment != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.workspace, systemImage: "paintbrush.pointed")
                        .font(.headline)

                    ForEach(entries, id: \.title) { entry in
                        ProfileInfoLine(title: entry.title, value: entry.value)
                    }

                    if let comment {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.workspaceComment)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(comment)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(14)
                .keiPanel(14)
            }
        }
    }
}

private struct ProfileMetric: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(value.formatted())
                    .font(.headline)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100, alignment: .leading)
    }
}

struct ProfileInfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }
}

extension PixivUserWorkspace {
    var infoEntries: [(title: String, value: String)] {
        [
            (L10n.tool, tool),
            (L10n.tablet, tablet),
            (L10n.mouse, mouse)
        ].compactMap { title, value in
            guard let trimmed = value?.trimmedNonEmpty else { return nil }
            return (title, trimmed)
        }
    }

    var trimmedComment: String? {
        comment?.htmlStripped.trimmedNonEmpty
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
