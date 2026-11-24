// The family's self-test (PLAN's S29c): a fixed text, tagged, and the SHA-256 of what came of it, which
// `frus-light language-selftest` prints and the smoke test holds to the digest committed in
// `fixtures/language/selftest.sha256` on each architecture, as FRUSLanguageTests does on the swift job.
// The text gathers what each rule decides: clitics, hyphens, abbreviations, numbers, a heading in
// capitals, accented letters and the typographer's punctuation.

/// The family's self-test: ``text`` tagged, line by line, and the digest of the lines.
public enum LanguageSelftest {
    /// The fixed text.
    public static let text = """
        SECRET
        Telegram From the Department of State to the Embassy in Nicaragua
        The Secretary of State met Soviet Ambassador Dobrynin at 10:30 a.m. on October 26, 1962. He didn't \
        think the U.S. Government\u{2019}s position\u{2014}as stated in Deptel 1234\u{2014}was unchanged; the \
        Russians\u{2019} views weren't either.
        Mr. Rusk said that negotiations on a test-ban treaty, anti-Communist sentiment and co-operation with \
        the r\u{E9}gime would be discussed, e.g., at the Joint Chiefs of Staff's meeting of Sept. 5.
        \u{201C}We can't agree,\u{201D} Khrushchev wrote; the President hoped for better relations and fewer \
        missiles in Cuba by 1963. It's 3.5 percent of $1,500 million.
        """

    /// The lines the digest covers: the identity, then each word of ``text``, its start and end in Unicode
    /// scalars, the word, its tag, its class and its lemma, or `-` for none, separated by tabs.
    public static func lines(_ tagger: LanguageTagger) -> [String] {
        var lines = ["identity\t\(tagger.identity.name)\t\(tagger.identity.version)\t\(tagger.identity.modelSHA256)\t\(tagger.identity.listsSHA256)"]
        let scalars = text.unicodeScalars
        for word in tagger.tagged(text) {
            let start = scalars.distance(from: scalars.startIndex, to: word.range.lowerBound)
            let end = scalars.distance(from: scalars.startIndex, to: word.range.upperBound)
            lines.append("\(start)\t\(end)\t\(text[word.range])\t\(word.tag)\t\(word.lexicalClass.rawValue)\t\(word.lemma ?? "-")")
        }
        return lines
    }

    /// The SHA-256 of ``lines(_:)``, each ending in a line feed.
    public static func digest(_ tagger: LanguageTagger) -> String {
        LanguageTagger.sha256(Array(lines(tagger).map { $0 + "\n" }.joined().utf8))
    }
}
