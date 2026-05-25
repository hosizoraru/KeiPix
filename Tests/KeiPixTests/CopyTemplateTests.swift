import Testing
@testable import KeiPix

struct CopyTemplateTests {
    @Test("Artwork copy template renders metadata placeholders")
    func artworkCopyTemplateRendersMetadataPlaceholders() {
        let template = ArtworkCopyTemplate(rawValue: "${title}|${id}|${creator}|${userId}|${tags}|${AI}|${R18}|${url}")
        let text = template.render(context: .preview)

        #expect(text.contains("Blue Morning"))
        #expect(text.contains("12345678"))
        #expect(text.contains("Kei"))
        #expect(text.contains("24680"))
        #expect(text.contains("#original #landscape"))
        #expect(text.contains("AI"))
        #expect(text.contains("R-18"))
        #expect(text.contains("https://www.pixiv.net/artworks/12345678"))
    }

    @Test("Creator copy template renders tabular creator metadata")
    func creatorCopyTemplateRendersTabularCreatorMetadata() {
        let template = CreatorCopyTemplate(rawValue: "${user}\t@${account}\t${userId}\t${url}")
        let text = template.render(context: .preview)

        #expect(text == "Kei\t@kei_pixiv\t24680\thttps://www.pixiv.net/users/24680")
    }
}
