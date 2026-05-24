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
    @State private var replyTarget: PixivComment?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

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
                            CommentThreadRow(
                                comment: comment,
                                store: store,
                                reply: { target in replyTarget = target },
                                copied: { showStatus(L10n.copiedComment) }
                            )
                        }
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let errorMessage {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)

                        Spacer(minLength: 0)

                        Button {
                            Task { await loadInitial() }
                        } label: {
                            Label(L10n.retry, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
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
            if let replyTarget {
                HStack(spacing: 8) {
                    Label(replyTargetTitle(replyTarget), systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        self.replyTarget = nil
                    } label: {
                        Label(L10n.cancelReply, systemImage: "xmark.circle")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }

            TextField(replyTarget.map(replyTargetTitle) ?? L10n.writeComment, text: $draft, axis: .vertical)
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

    private func replyTargetTitle(_ comment: PixivComment) -> String {
        String(format: L10n.replyToFormat, comment.user?.name ?? L10n.comments)
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
            try await store.postComment(comment, for: artwork, parentCommentID: replyTarget?.id)
            draft = ""
            replyTarget = nil
            hasLoaded = false
            await loadInitial()
            showStatus(L10n.postedComment)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}

private struct CommentThreadRow: View {
    let comment: PixivComment
    @Bindable var store: KeiPixStore
    let reply: (PixivComment) -> Void
    let copied: () -> Void

    @State private var replies: [PixivComment] = []
    @State private var nextURL: URL?
    @State private var isLoadingReplies = false
    @State private var isExpanded = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CommentRow(comment: comment) {
                reply(comment)
            } copied: {
                copied()
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if replies.isEmpty, isLoadingReplies == false {
                        Text(L10n.noReplies)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }

                    ForEach(replies) { replyComment in
                        CommentRow(comment: replyComment) {
                            reply(replyComment)
                        } copied: {
                            copied()
                        }
                        .padding(.leading, 28)
                    }

                    if nextURL != nil {
                        Button {
                            Task { await loadMoreReplies() }
                        } label: {
                            Label(isLoadingReplies ? L10n.loading : L10n.loadMoreComments, systemImage: "ellipsis.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isLoadingReplies)
                        .padding(.leading, 28)
                    }
                }
            }

            if comment.hasReplies || replies.isEmpty == false {
                Button {
                    Task { await toggleReplies() }
                } label: {
                    if isLoadingReplies {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(isExpanded ? L10n.hideReplies : L10n.viewReplies, systemImage: "arrowshape.turn.up.left")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoadingReplies)
                .padding(.leading, 40)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(.leading, 40)
            }
        }
    }

    private func toggleReplies() async {
        if replies.isEmpty == false {
            isExpanded.toggle()
            return
        }
        await loadInitialReplies()
    }

    private func loadInitialReplies() async {
        isLoadingReplies = true
        errorMessage = nil
        defer { isLoadingReplies = false }

        do {
            let response = try await store.commentReplies(for: comment)
            replies = response.comments
            nextURL = response.nextURL
            isExpanded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMoreReplies() async {
        guard let nextURL else { return }
        isLoadingReplies = true
        errorMessage = nil
        defer { isLoadingReplies = false }

        do {
            let response = try await store.nextComments(nextURL)
            replies.append(contentsOf: response.comments)
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CommentRow: View {
    let comment: PixivComment
    let reply: () -> Void
    let copied: () -> Void

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

                HStack(spacing: 8) {
                    Button {
                        reply()
                    } label: {
                        Label(L10n.reply, systemImage: "arrowshape.turn.up.left")
                    }
                    .buttonStyle(.borderless)

                    if let text = comment.comment, text.isEmpty == false {
                        Button {
                            PasteboardWriter.copy(text)
                            copied()
                        } label: {
                            Label(L10n.copyComment, systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
