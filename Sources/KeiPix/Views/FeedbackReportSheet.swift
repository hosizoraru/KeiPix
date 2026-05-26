import SwiftUI

struct FeedbackReportSheet: View {
    let request: FeedbackReportRequest
    let localMuteAction: (() -> Void)?
    let onComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: FeedbackReportReason = .other
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
                        .font(.title3.weight(.semibold))

                    Text(L10n.feedbackAndMuteHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                SheetCloseButton(style: .plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(request.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(request.targetTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text(request.targetSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Picker(L10n.reportReason, selection: $reason) {
                ForEach(FeedbackReportReason.allCases) { reason in
                    Text(reason.title).tag(reason)
                }
            }
            .pickerStyle(.menu)

            TextField(L10n.note, text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            FlowLayout(spacing: 8) {
                Button {
                    PasteboardWriter.copy(reportSummary)
                    onComplete(L10n.copiedReportSummary)
                } label: {
                    Label(L10n.copyReportSummary, systemImage: "doc.on.doc")
                }

                if let url = request.targetURL {
                    Link(destination: url) {
                        Label(L10n.openPixivWebReportPage, systemImage: "safari")
                    }
                }

                if let localMuteAction, let localMuteTitle = request.localMuteTitle {
                    Button(role: .destructive) {
                        localMuteAction()
                        onComplete(String(format: L10n.localMuteRequestedFormat, localMuteTitle))
                        dismiss()
                    } label: {
                        Label(localMuteTitle, systemImage: "eye.slash")
                    }
                }
            }

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
        }
        .padding(20)
        .frame(width: 460)
    }

    private var reportSummary: String {
        request.summary(reason: reason, note: note)
    }
}
