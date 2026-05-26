import Foundation
import Testing
@testable import KeiPix

@Suite("Caption translation availability gate")
struct CaptionTranslationAvailabilityTests {
    @Test("Empty and whitespace-only captions are skipped")
    func emptyCaptionsAreSkipped() {
        #expect(CaptionTranslationAvailability.translatableText(from: "") == nil)
        #expect(CaptionTranslationAvailability.translatableText(from: "   ") == nil)
        #expect(CaptionTranslationAvailability.translatableText(from: "\n\t") == nil)
        #expect(CaptionTranslationAvailability.canTranslate("") == false)
    }

    @Test("Pure-emoji and punctuation blurbs are skipped")
    func emojiOnlyCaptionsAreSkipped() {
        // Apple Translate treats these as opaque glyphs — surfacing the
        // affordance would only ever produce empty results.
        #expect(CaptionTranslationAvailability.translatableText(from: "🐱🐱🐱") == nil)
        #expect(CaptionTranslationAvailability.translatableText(from: "!!!??") == nil)
        #expect(CaptionTranslationAvailability.translatableText(from: "—") == nil)
    }

    @Test("Single-letter captions stay below the floor")
    func singleLetterCaptionsAreSkipped() {
        #expect(CaptionTranslationAvailability.translatableText(from: "a") == nil)
        #expect(CaptionTranslationAvailability.translatableText(from: "  a  ") == nil)
    }

    @Test("Two-letter captions cross the floor")
    func twoLetterCaptionsAreTranslatable() {
        #expect(CaptionTranslationAvailability.translatableText(from: "ok") == "ok")
        // CJK ideographs count as letters under Unicode, so a two-glyph
        // Japanese / Chinese caption should be translatable too.
        #expect(CaptionTranslationAvailability.translatableText(from: "可愛") == "可愛")
        #expect(CaptionTranslationAvailability.translatableText(from: "綺麗") == "綺麗")
    }

    @Test("Translatable text is trimmed of surrounding whitespace")
    func trimmingPreservesInteriorSpacing() {
        #expect(CaptionTranslationAvailability.translatableText(from: "  Hello world  ") == "Hello world")
        #expect(CaptionTranslationAvailability.translatableText(from: "\nお疲れさま\n") == "お疲れさま")
    }

    @Test("Mixed letters + emoji clear the floor on the letter count")
    func mixedCaptionsClearTheFloor() {
        // Two letters total, surrounded by emoji and punctuation —
        // still translatable since the letter count meets the minimum.
        #expect(CaptionTranslationAvailability.translatableText(from: "🌸 Hi! 🌸") == "🌸 Hi! 🌸")
        #expect(CaptionTranslationAvailability.canTranslate("🌸 Hi! 🌸"))
    }
}
