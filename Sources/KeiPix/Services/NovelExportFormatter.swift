import Foundation

enum NovelExportFormat: CaseIterable, Sendable {
    case txt
    case markdown
    case html

    var fileExtension: String {
        switch self {
        case .txt: "txt"
        case .markdown: "md"
        case .html: "html"
        }
    }
}

enum NovelExportFormatter {
    static func build(format: NovelExportFormat, text: PixivNovelText, novel: PixivNovel) -> String {
        build(
            format: format,
            text: text,
            title: novel.title,
            authorName: novel.user.name,
            novelID: novel.id
        )
    }

    static func build(
        format: NovelExportFormat,
        text: PixivNovelText,
        title: String,
        authorName: String,
        novelID: Int
    ) -> String {
        switch format {
        case .txt:
            buildTXT(text: text, title: title, authorName: authorName)
        case .markdown:
            buildMarkdown(text: text, title: title, authorName: authorName)
        case .html:
            buildHTML(text: text, title: title, authorName: authorName, novelID: novelID)
        }
    }

    private static func buildTXT(text: PixivNovelText, title: String, authorName: String) -> String {
        var lines: [String] = []
        lines.append(title)
        lines.append(authorName)
        lines.append(String(repeating: "-", count: 40))
        lines.append("")
        for token in NovelTextTokenizer.tokenize(text.novelText) {
            switch token {
            case .text(let value): lines.append(value)
            case .newPage: lines.append("\n---\n")
            case .chapter(let title): lines.append("\n## \(title)\n")
            case .pixivImage(let id, _): lines.append("[illust:\(id)]")
            case .uploadedImage(let key): lines.append("[image:\(key)]")
            case .jumpURL(let label, let url): lines.append("[\(label)](\(url.absoluteString))")
            case .ruby(let base, let reading): lines.append("\(base)(\(reading))")
            case .jumpPage(let page): lines.append("[page \(page)]")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func buildMarkdown(text: PixivNovelText, title: String, authorName: String) -> String {
        var lines: [String] = []
        lines.append("# \(title)")
        lines.append("**\(authorName)**")
        lines.append("")
        lines.append("---")
        lines.append("")
        for token in NovelTextTokenizer.tokenize(text.novelText) {
            switch token {
            case .text(let value): lines.append(value)
            case .newPage: lines.append("\n---\n")
            case .chapter(let title): lines.append("\n## \(title)\n")
            case .pixivImage(let id, _): lines.append("![illust:\(id)](https://www.pixiv.net/artworks/\(id))")
            case .uploadedImage(let key): lines.append("![image:\(key)](\(key))")
            case .jumpURL(let label, let url): lines.append("[\(label)](\(url.absoluteString))")
            case .ruby(let base, let reading): lines.append("\(base)(\(reading))")
            case .jumpPage(let page): lines.append("[page \(page)](#page-\(page))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func buildHTML(text: PixivNovelText, title: String, authorName: String, novelID: Int) -> String {
        var body: [String] = [
            "<h1>\(escapeHTML(title))</h1>",
            "<p class=\"novel-author\">\(escapeHTML(authorName))</p>",
            "<p class=\"novel-source\"><a href=\"https://www.pixiv.net/novel/show.php?id=\(novelID)\">pixiv novel \(novelID)</a></p>"
        ]
        var chapterIndex = 0

        for token in NovelTextTokenizer.tokenize(text.novelText) {
            switch token {
            case .text(let value):
                appendTextParagraphs(value, to: &body)
            case .newPage:
                body.append("<hr class=\"page-break\">")
            case .chapter(let title):
                chapterIndex += 1
                body.append("<h2 id=\"chapter-\(chapterIndex)\">\(escapeHTML(title))</h2>")
            case .pixivImage(let id, let page):
                let suffix = page.map { "-\($0)" } ?? ""
                body.append(#"<figure class="novel-image"><a href="https://www.pixiv.net/artworks/\#(id)">illust:\#(id)\#(suffix)</a></figure>"#)
            case .uploadedImage(let key):
                body.append(#"<figure class="novel-image">image:\#(escapeHTML(key))</figure>"#)
            case .jumpURL(let label, let url):
                body.append(#"<p><a href="\#(escapeHTMLAttribute(url.absoluteString))">\#(escapeHTML(label))</a></p>"#)
            case .ruby(let base, let reading):
                body.append("<p><ruby>\(escapeHTML(base))<rt>\(escapeHTML(reading))</rt></ruby></p>")
            case .jumpPage(let page):
                body.append("<p><a href=\"#page-\(page)\">page \(page)</a></p>")
            }
        }

        return """
        <!doctype html>
        <html lang="ja">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Yu Gothic", sans-serif; line-height: 1.78; margin: 2.5rem auto; max-width: 46rem; padding: 0 1rem; color: #1d1d1f; }
            h1 { line-height: 1.2; margin-bottom: 0.25rem; }
            h2 { margin-top: 2rem; }
            .novel-author, .novel-source { color: #6e6e73; }
            .page-break { border: 0; border-top: 1px solid #d2d2d7; margin: 2rem 0; }
            .novel-image { margin: 1.5rem 0; color: #6e6e73; }
            rt { font-size: 0.65em; }
          </style>
        </head>
        <body>
        \(body.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    private static func appendTextParagraphs(_ value: String, to body: inout [String]) {
        let paragraphs = value
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        for paragraph in paragraphs {
            body.append("<p>\(escapeHTML(paragraph))</p>")
        }
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func escapeHTMLAttribute(_ value: String) -> String {
        escapeHTML(value)
    }
}
