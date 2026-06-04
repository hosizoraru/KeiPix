import SwiftUI

struct FeedbackReportSheet: View {
    let request: FeedbackReportRequest
    let localMuteAction: (() -> Void)?
    let onComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: FeedbackReportReason = .other
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeaderRail(
                overline: L10n.feedbackAndMute,
                title: request.targetTitle,
                subtitle: request.kind.title,
                leading: {
                    SheetHeaderIcon(
                        systemImage: "exclamationmark.bubble",
                        tint: .orange
                    )
                },
                trailing: {
                    SheetHeaderActionButton(
                        title: L10n.copyReportSummary,
                        systemImage: "doc.on.doc"
                    ) {
                        PasteboardWriter.copy(reportSummary)
                        onComplete(L10n.copiedReportSummary)
                    }

                    if let url = request.targetURL {
                        SheetHeaderActionButton(
                            title: L10n.openPixivWebReportPage,
                            systemImage: "safari"
                        ) {
                            PlatformWorkspace.open(url)
                        }
                    }
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.feedbackAndMuteHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(request.targetSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Picker(L10n.reportReason, selection: $reason) {
                    ForEach(FeedbackReportReason.allCases) { reason in
                        Text(reason.title).tag(reason)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)

                TextField(L10n.note, text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .keiInteractiveGlass(16)
                    .lineLimit(2...5)

                if let localMuteAction, let localMuteTitle = request.localMuteTitle {
                    // Destructive local mute is intentionally kept in
                    // the body (not the header rail) so users have to
                    // pause and read what they're about to silence.
                    Button(role: .destructive) {
                        localMuteAction()
                        onComplete(String(format: L10n.localMuteRequestedFormat, localMuteTitle))
                        dismiss()
                    } label: {
                        Label(localMuteTitle, systemImage: "eye.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
                }
            }
            .padding(20)

            Spacer(minLength: 0)

            Divider()

            HStack {
                Button(L10n.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(L10n.done) {
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        #if os(macOS)
        .frame(width: 480)
        #endif
    }

    private var reportSummary: String {
        request.summary(reason: reason, note: note)
    }
}
