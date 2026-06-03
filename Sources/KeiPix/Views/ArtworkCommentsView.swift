import SwiftUI

struct ArtworkCommentsView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var isExpanded: Bool
    var visualQAResponse: PixivCommentResponse?

    @State private var hasLoaded = false
    @State private var comments: [PixivComment] = []
    @State private var nextURL: URL?
    @State private var totalComments: Int?
    @State private var draft = ""
    @State private var replyTarget: PixivComment?
    @State private var isEmojiPickerPresented = false
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
                                artwork: artwork,
                                store: store,
                                reply: { target in replyTarget = target },
                                copied: { showStatus(L10n.copiedComment) },
                                status: showStatus
                            )
                        }
                    }
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                }

                if let errorMessage {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .lineLimit(3)
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
            .padding(.top, 10)
        } label: {
            ArtworkInspectorSectionHeader(
                title: L10n.comments,
                subtitle: headerSubtitle,
                systemImage: "text.bubble"
            )
            .contentShape(Rectangle())
        }
        .disclosureGroupStyle(.automatic)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .keiGlass(18)
        .task(id: isExpanded) {
            guard isExpanded, hasLoaded == false else { return }
            await loadInitial()
        }
    }

    private var headerSubtitle: String? {
        let count = totalComments ?? artwork.totalComments
        return count > 0 ? count.formatted() : nil
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
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
                .disabled(isPosting)

            HStack {
                Button {
                    isEmojiPickerPresented.toggle()
                } label: {
                    Label(L10n.commentEmoji, systemImage: "face.smiling")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(L10n.commentEmoji)
                .popover(isPresented: $isEmojiPickerPresented, arrowEdge: .bottom) {
                    PixivCommentEmojiPicker(
                        insert: { emoji in
                            insertEmoji(emoji)
                            // Stay open so the user can stack emojis in
                            // one go, matching Pixiv Web. The popover
                            // dismisses via the Done button below or by
                            // clicking outside.
                        },
                        dismiss: {
                            isEmojiPickerPresented = false
                        }
                    )
                }
                .disabled(isPosting)

                Text(L10n.commentDraftCount(draft.count))
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

    private func insertEmoji(_ emoji: PixivCommentEmoji) {
        draft += emoji.token
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response: PixivCommentResponse
            if let visualQAResponse {
                response = visualQAResponse
            } else {
                response = try await store.comments(for: artwork)
            }
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
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let reply: (PixivComment) -> Void
    let copied: () -> Void
    let status: (String) -> Void

    @State private var replies: [PixivComment] = []
    @State private var nextURL: URL?
    @State private var isLoadingReplies = false
    @State private var isExpanded = false
    @State private var isMutedCommentRevealed = false
    @State private var errorMessage: String?

    var body: some View {
        let muteReasons = store.commentMuteReasons(for: comment)

        VStack(alignment: .leading, spacing: 8) {
            if store.hideMutedContent, muteReasons.isEmpty == false, isMutedCommentRevealed == false {
                MutedCommentPlaceholder(reasons: muteReasons) {
                    isMutedCommentRevealed = true
                }
            } else {
                CommentRow(comment: comment, store: store, muteReasons: muteReasons) {
                    reply(comment)
                } copied: {
                    copied()
                } status: { message in
                    status(message)
                }
                .environment(\.feedbackReportArtwork, artwork)
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
                        FilteredReplyCommentRow(
                            comment: replyComment,
                            artwork: artwork,
                            store: store,
                            reply: {
                                reply(replyComment)
                            },
                            copied: {
                                copied()
                            },
                            status: status
                        )
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

            if (store.hideMutedContent == false || muteReasons.isEmpty || isMutedCommentRevealed),
               comment.hasReplies || replies.isEmpty == false {
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

private struct FilteredReplyCommentRow: View {
    let comment: PixivComment
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let reply: () -> Void
    let copied: () -> Void
    let status: (String) -> Void

    @State private var isMutedCommentRevealed = false

    var body: some View {
        let muteReasons = store.commentMuteReasons(for: comment)

        if store.hideMutedContent, muteReasons.isEmpty == false, isMutedCommentRevealed == false {
            MutedCommentPlaceholder(reasons: muteReasons) {
                isMutedCommentRevealed = true
            }
        } else {
            CommentRow(comment: comment, store: store, muteReasons: muteReasons) {
                reply()
            } copied: {
                copied()
            } status: { message in
                status(message)
            }
            .environment(\.feedbackReportArtwork, artwork)
        }
    }
}

private struct MutedCommentPlaceholder: View {
    let reasons: [CommentMuteReason]
    let reveal: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(reasonText, systemImage: "eye.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button {
                reveal()
            } label: {
                Label(L10n.showComment, systemImage: "eye")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .help(reasonText)
    }

    private var reasonText: String {
        String(format: L10n.hiddenCommentReasonFormat, reasons.map(\.title).joined(separator: " · "))
    }
}

private struct CommentRow: View {
    let comment: PixivComment
    @Bindable var store: KeiPixStore
    let muteReasons: [CommentMuteReason]
    let reply: () -> Void
    let copied: () -> Void
    let status: (String) -> Void
    @Environment(\.feedbackReportArtwork) private var artwork
    @State private var feedbackRequest: FeedbackReportRequest?

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
                    PixivCommentEmojiTextView(text: text)
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

                if muteReasons.isEmpty == false {
                    FlowLayout(spacing: 6) {
                        ForEach(muteReasons.map(\.title), id: \.self) { reason in
                            Label(reason, systemImage: "eye.slash")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .foregroundStyle(.secondary)
                                .background(.regularMaterial, in: Capsule())
                        }
                    }
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

                        // Per-comment translate. Gated by
                        // `CaptionTranslationAvailability` so emoji-only
                        // comments don't get a noisy affordance.
                        ArtworkTranslateButton(text: text)
                    }

                    Menu {
                        Button {
                            if let artwork {
                                feedbackRequest = .comment(comment, artwork: artwork)
                            }
                        } label: {
                            Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
                        }
                        .disabled(artwork == nil)

                        Divider()

                        if let user = comment.user {
                            Button {
                                muteCommenter(user)
                            } label: {
                                Label(L10n.muteCreator, systemImage: "person.slash")
                            }
                            .disabled(store.mutedUsers[user.id] != nil)
                        }

                        if let phrase = mutedPhraseCandidate {
                            Button {
                                mutePhrase(phrase)
                            } label: {
                                Label(L10n.muteCommentPhrase, systemImage: "text.quote")
                            }
                            .disabled(store.mutedCommentPhrases.contains(phrase))
                        }
                    } label: {
                        Label(L10n.mute, systemImage: "eye.slash")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                    .disabled(comment.user == nil && mutedPhraseCandidate == nil)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .sheet(item: $feedbackRequest) { request in
            FeedbackReportSheet(request: request, localMuteAction: localMuteAction) { message in
                status(message)
            }
            .iPadFriendlySheet()
        }
    }

    private var mutedPhraseCandidate: String? {
        guard let text = comment.comment else { return nil }
        let normalized = store.normalizedCommentPhrase(text)
        return normalized.isEmpty ? nil : normalized
    }

    private func muteCommenter(_ user: PixivUser) {
        store.muteUser(user)
        store.undoAction = AppUndoAction(kind: .unmuteCreator(user))
        status(String(format: L10n.mutedCreatorFormat, user.name))
    }

    private func mutePhrase(_ phrase: String) {
        store.muteCommentPhrase(phrase)
        store.undoAction = AppUndoAction(kind: .unmuteCommentPhrase(phrase))
        status(String(format: L10n.mutedCommentPhraseFormat, phrase))
    }

    private var localMuteAction: (() -> Void)? {
        if let user = comment.user {
            return { muteCommenter(user) }
        }
        if let phrase = mutedPhraseCandidate {
            return { mutePhrase(phrase) }
        }
        return nil
    }
}

private struct FeedbackReportArtworkKey: EnvironmentKey {
    static let defaultValue: PixivArtwork? = nil
}

private extension EnvironmentValues {
    var feedbackReportArtwork: PixivArtwork? {
        get { self[FeedbackReportArtworkKey.self] }
        set { self[FeedbackReportArtworkKey.self] = newValue }
    }
}
