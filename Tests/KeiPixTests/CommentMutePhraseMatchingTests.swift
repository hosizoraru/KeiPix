import Testing
@testable import KeiPix

struct CommentMutePhraseMatchingTests {
    @Test("Plain phrases match case-insensitively as substrings")
    func plainPhraseMatchesSubstring() {
        #expect(KeiPixStore.commentPhraseMatches("spam", in: "This is SPAM content"))
        #expect(KeiPixStore.commentPhraseMatches("hello", in: "say HELLO!"))
        #expect(KeiPixStore.commentPhraseMatches("yikes", in: "totally fine") == false)
    }

    @Test("Slash-wrapped phrases match as case-insensitive regular expressions")
    func regexPhraseMatchesPattern() {
        #expect(KeiPixStore.commentPhraseMatches("/^spam.*/", in: "spam everywhere"))
        #expect(KeiPixStore.commentPhraseMatches("/buy.*now/", in: "BUY this RIGHT NOW"))
        #expect(KeiPixStore.commentPhraseMatches("/^spam.*/", in: "not spam at the start") == false)
    }

    @Test("Malformed regex falls back to substring matching")
    func malformedRegexFallsBackToSubstring() {
        // `/[unclosed` is treated as a plain phrase since the closing slash
        // is missing — substring match still works.
        #expect(KeiPixStore.commentPhraseMatches("/[unclosed", in: "ends with /[unclosed"))

        // `/[bad/` parses as a slash-wrapped pattern but the regex itself is
        // invalid — falls back to substring (so the literal `/[bad/` would
        // need to appear in the comment text). Confirms the fallback path
        // doesn't crash.
        #expect(KeiPixStore.commentPhraseMatches("/[bad/", in: "totally clean") == false)
    }

    @Test("Empty regex pattern is treated as a no-op")
    func emptyRegexPatternIsIgnored() {
        // `//` parses to an empty pattern — `regexFromPhrase` rejects it and
        // the matcher falls through to substring, which won't find the empty
        // string the same way as a real regex would.
        #expect(KeiPixStore.regexFromPhrase("//") == nil)
    }
}
