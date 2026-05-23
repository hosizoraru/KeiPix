import SwiftUI

struct ArtworkCommentsView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var isExpanded = false
    @State private var hasLoaded = false
    @State private var comments: [PixivComment] = []
    @State private var nextURL: URL?
    @State private var totalComments: Int?
    @State private var draft = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var isPosting = false
    @State private var errorMessage: String?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                composer

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if comments.isEmpty {
                    ContentUnavailableView(
                        L10n.noComments,
                        systemImage: "text.bubble",
                        description: Text(L10n.writeComment)
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if nextURL != nil {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        if isLoadingMore {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(L10n.loadMoreComments, systemImage: "ellipsis.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingMore)
                }
            }
            .padding(.top, 12)
        } label: {
            Label(title, systemImage: "text.bubble")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .disclosureGroupStyle(.automatic)
        .padding(14)
        .keiPanel(16)
        .onChange(of: isExpanded) { _, value in
            guard value, hasLoaded == false else { return }
            Task { await loadInitial() }
        }
    }

    private var title: String {
        let count = totalComments ?? artwork.totalComments
        return count > 0 ? "\(L10n.comments) (\(count.formatted()))" : L10n.comments
    }

    private var composer: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextField(L10n.writeComment, text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .disabled(isPosting)

            HStack {
                Text("\(draft.count) / 140")
                    .font(.caption)
                    .foregroundStyle(draft.count > 140 ? .red : .secondary)

                Spacer()

                Button {
                    Task { await postComment() }
                } label: {
                    if isPosting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.postComment, systemImage: "paperplane")
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .disabled(trimmedDraft.isEmpty || draft.count > 140 || isPosting)
            }
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response = try await store.comments(for: artwork)
            comments = response.comments
            nextURL = response.nextURL
            totalComments = response.totalComments
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextComments(nextURL)
            comments.append(contentsOf: response.comments)
            self.nextURL = response.nextURL
            totalComments = response.totalComments ?? totalComments
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func postComment() async {
        let comment = trimmedDraft
        guard comment.isEmpty == false else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            try await store.postComment(comment, for: artwork)
            draft = ""
            hasLoaded = false
            await loadInitial()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CommentRow: View {
    let comment: PixivComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImageView(url: comment.user?.avatarURL)
                .frame(width: 30, height: 30)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comment.user?.name ?? "")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    if let date = comment.date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                if let parentUser = comment.parentComment?.user {
                    Text("@\(parentUser.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let text = comment.comment, text.isEmpty == false {
                    Text(text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let stampURL = comment.stamp?.stampURL {
                    RemoteImageView(url: stampURL)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if comment.hasReplies {
                    Label(L10n.replies, systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
