// The word splitter's rules (S29c), each held to NaturalLanguage's words for the same text where the
// probes of macOS 27.2.1 recorded them (DEVLOG's Session 29c). Typographic characters are written as
// Swift's braced escapes, which tool inputs pass through untouched.

@testable import FRUSLanguage
import Testing

@Suite struct WordSplitterTests {
    /// The words of `text`, as printed.
    static func words(_ text: String) -> [String] {
        WordSplitter.words(in: text).map { String(text[$0]) }
    }

    /// Every token of `text`, as printed, with its kind's initial.
    static func tokens(_ text: String) -> [String] {
        WordSplitter.tokens(in: text).map { token in
            let kind = token.kind == .word ? "w" : token.kind == .punctuation ? "p" : "s"
            return "\(text[token.range])/\(kind)"
        }
    }

    @Test func clitics() {
        #expect(Self.words("I don't think the U.S. Government can't agree; it's the Soviets' view.") ==
                ["I", "do", "n't", "think", "the", "U.S.", "Government", "ca", "n't", "agree", "it", "'s", "the", "Soviets", "view"])
        #expect(Self.words("cannot, won't, shan't, we're, they've, I'll, she'd, I'm, Jones' book, the Ambassador's.") ==
                ["cannot", "wo", "n't", "sha", "n't", "we", "'re", "they", "'ve", "I", "'ll", "she", "'d", "I", "'m", "Jones", "book",
                 "the", "Ambassador", "'s"])
        #expect(Self.words("Let's go. Children's toys. Ma'am. o'clock. Gov't.") ==
                ["Let", "'s", "go", "Children", "'s", "toys", "Ma'am", "o'clock", "Gov't"])
        #expect(Self.words("shouldn't've DON'T KHRUSHCHEV'S 1960's") ==
                ["should", "n't", "'ve", "DO", "N'T", "KHRUSHCHEV", "'S", "1960", "'s"])
    }

    @Test func theTypographersApostrophe() {
        #expect(Self.words("The Ambassador said that the Department\u{2019}s position\u{2014}as stated\u{2014}was unchanged.") ==
                ["The", "Ambassador", "said", "that", "the", "Department", "\u{2019}s", "position", "as", "stated", "was", "unchanged"])
        #expect(Self.words("Se\u{F1}or Zelaya\u{2019}s government\u{2014}the Nicaraguan r\u{E9}gime\u{2014}refused. O\u{2019}Brien\u{2019}s na\u{EF}ve co\u{F6}peration.") ==
                ["Se\u{F1}or", "Zelaya", "\u{2019}s", "government", "the", "Nicaraguan", "r\u{E9}gime", "refused", "O\u{2019}Brien", "\u{2019}s",
                 "na\u{EF}ve", "co\u{F6}peration"])
        #expect(Self.tokens("the Soviets\u{2019} decision") == ["the/w", "Soviets/w", "\u{2019}/p", "decision/w"])
        #expect(Self.tokens("\u{2018}80s") == ["\u{2018}/p", "80s/w"])
        #expect(Self.tokens("'80s") == ["'/p", "80s/w"])
    }

    @Test func hyphens() {
        #expect(Self.words("non-aligned pre-war co-operation un-American anti-war cease-fire so-called Vice-President") ==
                ["non-aligned", "pre", "war", "co-operation", "un-American", "anti-war", "cease", "fire", "so", "called", "Vice", "President"])
        #expect(Self.words("The well-known anti-Communist leader; U.S.-Soviet relations; CO-OPERATION; Anti-Ballistic-Missile") ==
                ["The", "well", "known", "anti-Communist", "leader", "U.S.", "Soviet", "relations", "CO-OPERATION", "Anti-Ballistic", "Missile"])
        #expect(Self.tokens("1961-63 anti- war word--word anti-1960") ==
                ["1961/w", "-/p", "63/w", "anti/w", "-/p", "war/w", "word/w", "--/p", "word/w", "anti/w", "-/p", "1960/w"])
        #expect(Self.words("de-escalation self-determination two-thirds") == ["de", "escalation", "self", "determination", "two", "thirds"])
        #expect(Self.words("re\u{2010}election co\u{2011}chairman") == ["re", "election", "co\u{2011}chairman"])
    }

    @Test func abbreviations() {
        #expect(Self.words("Sen. Smith and Gen. Taylor of the Dept. of State, No. 23, Jan. 5, St. Louis, Jr. vs. Ltd. etc. i.e. U.N. U.S.S.R. Ph.D. Wash. Calif. John F. Kennedy J.F.K. spoke.") ==
                ["Sen", "Smith", "and", "Gen.", "Taylor", "of", "the", "Dept.", "of", "State", "No", "23", "Jan.", "5", "St", "Louis",
                 "Jr.", "vs.", "Ltd.", "etc.", "i.e.", "U.N", "U.S.S.R", "Ph.D.", "Wash", "Calif", "John", "F.", "Kennedy", "J.F.K.",
                 "spoke"])
        #expect(Self.words("He went to the U.S. The next day he left. It was 5 p.m. Then he slept. See Doc. 4. He cited etc. Fine.") ==
                ["He", "went", "to", "the", "U.S.", "The", "next", "day", "he", "left", "It", "was", "5", "p.m", "Then", "he", "slept",
                 "See", "Doc", "4", "He", "cited", "etc", "Fine"])
        #expect(Self.words("Mr. and Mrs. Jones met Dr. Smith, Col. Lee, Lt. Gen. Ky, Gov. Rockefeller, Rep. Ford, Prof. Kissinger, Rev. King.") ==
                ["Mr.", "and", "Mrs.", "Jones", "met", "Dr.", "Smith", "Col.", "Lee", "Lt.", "Gen.", "Ky", "Gov.", "Rockefeller",
                 "Rep.", "Ford", "Prof.", "Kissinger", "Rev.", "King"])
        #expect(Self.words("Telegram 1234 from Managua, 5 p.m., to SecState; ref: Deptel 567. Nicaragua\u{2019}s claims.") ==
                ["Telegram", "1234", "from", "Managua", "5", "p.m.", "to", "SecState", "ref", "Deptel", "567", "Nicaragua", "\u{2019}s", "claims"])
        #expect(Self.words("U.S.-Soviet relations, e.g., the test-ban talks, improved in the 1960s.") ==
                ["U.S.", "Soviet", "relations", "e.g.", "the", "test", "ban", "talks", "improved", "in", "the", "1960s"])
        #expect(Self.words("at 10:30 a.m.") == ["at", "10", "30", "a.m"], "a text's last period ends it")
        #expect(Self.tokens("etc... Fine") == ["etc/w", ".../p", "Fine/w"], "an ellipsis is punctuation of its own")
        #expect(Self.words("Mar. 4 and mar. 5; MR. X") == ["Mar.", "4", "and", "mar", "5", "MR", "X"], "the list's case matters")
    }

    @Test func numbers() {
        #expect(Self.words("Khrushchev's letter of October 26 was 1,500 words long (see Tab A).") ==
                ["Khrushchev", "'s", "letter", "of", "October", "26", "was", "1,500", "words", "long", "see", "Tab", "A"])
        #expect(Self.tokens("3.5 percent, $100, 100%, 1,500,000, 5:00, the 10th, 1st") ==
                ["3.5/w", "percent/w", ",/p", "$/s", "100/w", ",/p", "100/w", "%/p", ",/p", "1,500,000/w", ",/p", "5/w", ":/p", "00/w",
                 ",/p", "the/w", "10th/w", ",/p", "1st/w"])
        #expect(Self.words("In 1961,63 percent") == ["In", "1961,63", "percent"])
    }

    @Test func punctuationAndSymbols() {
        #expect(Self.tokens("\u{201C}Yes,\u{201D} he said. (a) [Ed. note] Foo/bar and/or A&B.") ==
                ["\u{201C}/p", "Yes/w", ",/p", "\u{201D}/p", "he/w", "said/w", "./p", "(/p", "a/w", ")/p", "[/p", "Ed./w", "note/w",
                 "]/p", "Foo/w", "//p", "bar/w", "and/w", "//p", "or/w", "A/w", "&/p", "B/w", "./p"], "an initial at the text's end")
        #expect(Self.words("Annex B.\nAnnex C. follows; John F. Kennedy") == ["Annex", "B", "Annex", "C.", "follows", "John", "F.", "Kennedy"])
        #expect(Self.tokens("+ = \u{B0} \u{A9}") == ["+/s", "=/s", "\u{B0}/s", "\u{A9}/s"])
        #expect(Self.tokens("") == [])
        #expect(Self.words("... --- !?") == [])
    }

    @Test func unicodeScalars() {
        #expect(Self.words("cafe\u{301} na\u{308}ive") == ["cafe\u{301}", "na\u{308}ive"], "a combining mark stays with its letter")
        #expect(Self.tokens("\u{301}x") == ["\u{301}/s", "x/w"], "a mark with no word before it")
        #expect(Self.words("nego\u{AD}tiation") == ["nego\u{AD}tiation"], "a soft hyphen is a format character")
        #expect(Self.words("one\u{A0}two\u{200B}three\u{2003}four") == ["one", "two", "three", "four"])
        #expect(Self.words("\u{FEFF}Moscow \u{41C}\u{43E}\u{441}\u{43A}\u{432}\u{430} \u{5317}\u{4EAC}") ==
                ["Moscow", "\u{41C}\u{43E}\u{441}\u{43A}\u{432}\u{430}", "\u{5317}\u{4EAC}"])
        #expect(Self.words("\u{2160}\u{2161} \u{BD}") == ["\u{2160}\u{2161}", "\u{BD}"], "letter and other numbers are digits")
    }

    @Test func lines() {
        let text = "First paragraph ends here.\nSecond starts\r\nhere.\n\n\u{2029}Third."
        let tokens = WordSplitter.tokens(in: text)
        #expect(tokens.filter(\.startsLine).map { String(text[$0.range]) } == ["First", "Second", "here", "Third"])
        #expect(WordSplitter.tokens(in: "  \n  word").first?.startsLine == true)
    }

    @Test func rangesAreTheTextsOwn() {
        let text = "O\u{2019}Brien\u{2019}s caf\u{E9}\u{2014}\u{1F600} U.S."
        let tokens = WordSplitter.tokens(in: text)
        #expect(tokens.map { String(text[$0.range]) }.joined() == "O\u{2019}Brien\u{2019}scaf\u{E9}\u{2014}\u{1F600}U.S.")
        for (earlier, later) in zip(tokens, tokens.dropFirst()) { #expect(earlier.range.upperBound <= later.range.lowerBound) }
    }

    @Test func eachScalarClass() {
        #expect(ScalarClass.of("a") == .letter)
        #expect(ScalarClass.of("\u{3042}") == .letter)
        #expect(ScalarClass.of("7") == .digit)
        #expect(ScalarClass.of("\u{301}") == .mark)
        #expect(ScalarClass.of("\u{200D}") == .mark)
        #expect(ScalarClass.of("'") == .apostrophe)
        #expect(ScalarClass.of("\u{2019}") == .apostrophe)
        #expect(ScalarClass.of("\u{2018}") == .punctuation)
        #expect(ScalarClass.of("-") == .hyphen)
        #expect(ScalarClass.of("\u{2013}") == .punctuation)
        #expect(ScalarClass.of(".") == .period)
        #expect(ScalarClass.of(",") == .comma)
        #expect(ScalarClass.of("\u{A0}") == .space)
        #expect(ScalarClass.of("\u{2028}") == .lineBreak)
        #expect(ScalarClass.of("$") == .symbol)
        #expect(ScalarClass.of("\u{1F600}") == .symbol)
    }
}
