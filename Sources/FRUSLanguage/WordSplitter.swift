// The web's word splitter (PLAN's S29c): a text's tokens, found over its Unicode scalars, since Linux's
// Foundation splits no text into words (`NSString.EnumerationOptions.byWords` is unavailable in
// swift-corelibs-foundation, checked on 23 November).
//
// The rules follow what NaturalLanguage's tokenizer does with English, as probes of it on macOS 27.2.1
// found on 24 November (DEVLOG's Session 29c), so that the web's words are the Mac's wherever a rule can
// say so. NaturalLanguage's tokenizer is lexicon-driven, and its lexicon is not ours to copy, so where it
// decides word by word (which abbreviations keep their period, which hyphenated prefixes stay joined)
// the rules name the words the probes found and no more.
//
// ## The rules
//
// A scalar is a *letter* (general category L), a *digit* (Nd and Nl), a *fraction* (No: ½, ²), a *mark*
// (M, and the format characters such as the soft hyphen and the zero-width joiners), an *apostrophe*
// (U+0027, U+2019), a *hyphen* (U+002D, U+2010, U+2011), a *period*, a *comma*, a *space* (Z, the controls,
// U+200B and U+FEFF), a *line break* (U+000A to U+000D, U+0085, U+2028, U+2029), or else *punctuation*
// (P) or a *symbol* (S).
//
// 1. A word begins at a letter or a digit and runs over letters, digits and marks. A fraction is a word
//    of its own ("1" "½").
// 2. A period between two letters stays in the word ("U.S", "e.g", "J.F.K", "a.m"), and so does a period
//    or a comma between two digits ("1,500", "3.5"). A colon splits ("10", ":", "30").
// 3. An apostrophe after a letter or a digit and before a letter stays in the word ("O’Brien",
//    "o'clock", "Gov't", "IL-28’s"), unless a letter comes before it and what follows it to the word's
//    end is a clitic, `s`, `re`, `ve`, `ll`, `d` or `m`, in any case, which is then a word of its own
//    that begins with the apostrophe ("Department" "’s", "it" "'s", "we" "'re"). A word that ends in
//    `n't` after a letter loses it as a word of its own ("do" "n't", "ca" "n't", "wo" "n't"). Clitics
//    come off the end one at a time, so "shouldn't've" is "should" "n't" "'ve". French's elided `d` and
//    `l`, in any case, are words of their own with their apostrophe ("chargé d’" "affaires", "L’"
//    "Express"). An apostrophe anywhere else is punctuation ("Soviets" "’", "'" "80s").
// 4. A hyphen splits ("cease" "-" "fire", "U.S." "-" "Soviet"), except the first one after a word's
//    first part when that part is `un`, `co`, `non` or `anti`, in lowercase, and a letter follows it:
//    then it stays ("anti-Communist", "co-operation", "non-aligned", "un-American", where "Non"
//    "-" "Aligned" splits).
// 5. A period after a word, and not before another period, stays in it, unless it ends the text:
//    - after a title or another abbreviation ``alwaysKeepsPeriod`` lists ("Mr.", "Gen.", "Sept.",
//      "pp."), or one of the capitals ``alwaysKeptInitials`` lists, as an initial ("S.", "F.");
//    - after an initialism, a word holding a period between letters ("U.S.", "N.S.", "a.m."), but for
//      those ``initialismsEndingSentences`` lists ("p.m.", "U.N."), which keep it only as below;
//    - after any other word, number or letter, when the next scalar that is not a space is a lowercase
//      letter, a comma, a colon, a semicolon, a hyphen, a dash or a slash ("Libya. b.", "etc.,",
//      "ibid., p. 5", "3. a"), which no sentence follows.
//    Every other period is punctuation ("Libya." before a capital is "Libya" ".", as are "No. 1" and a
//    text's last period). The lists and the rules are what NaturalLanguage does, word for word, with
//    the fixture volumes' 14,000 periods after a word (DEVLOG's Session 29c).
// 6. Every other scalar that is not a space or a line break is a token of its own, punctuation or a
//    symbol, but for a run of periods ("...") or of hyphens ("--"), which is one. A mark with no word
//    before it is a symbol with the marks after it.
//
// The words are what a word walk reports, as NaturalLanguage's walk with `.omitPunctuation`,
// `.omitWhitespace` and `.omitOther` does: numbers, abbreviations and clitics among them. The tagger
// tags punctuation and symbols too, since its training text has them, and reports none.

/// A token of a text: its range, its kind, and whether a line break comes before it.
public struct LanguageToken: Sendable, Equatable {
    /// What a token is.
    public enum Kind: UInt8, Sendable, Equatable {
        /// A word, which a word walk reports: letters or digits, with the scalars the rules keep in it.
        case word
        /// Punctuation, which a word walk leaves out.
        case punctuation
        /// A symbol, which a word walk leaves out.
        case symbol
    }

    /// The token's range in the text it came from, on Unicode scalar boundaries.
    public let range: Range<String.Index>
    /// What the token is.
    public let kind: Kind
    /// Whether a line break comes between this token and the one before it, or this is the text's first
    /// token. The tagger reads each line as a unit.
    public let startsLine: Bool

    /// Creates a token.
    public init(range: Range<String.Index>, kind: Kind, startsLine: Bool) {
        self.range = range
        self.kind = kind
        self.startsLine = startsLine
    }
}

/// The web's word splitter: the rules at the top of this file (PLAN's S29c).
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29c): initial implementation
public enum WordSplitter {

    /// The words whose period always stays with them (rule 5), but at the text's end, as NaturalLanguage keeps
    /// it on macOS 27.2.1: the titles it keeps before a name and the abbreviations of dates, references and
    /// companies it keeps before a capital or a number. Case matters, as it does there. Each entry is the word
    /// without its period.
    public static let alwaysKeepsPeriod: Set<String> = [
        "Mr", "Mrs", "Ms", "Dr", "Gen", "Capt", "Col", "Lt", "Gov", "Rep", "Prof", "Rev", "Jr",
        "Jan", "Feb", "Mar", "Aug", "Sept", "Oct", "Nov", "Dec",
        "Inc", "Corp", "Ltd", "Bros", "Dept", "Ed",
        "vs", "cf", "viz", "ca", "pp", "ff", "op", "cit",
    ]

    /// The capitals whose period always stays with them as an initial (rule 5), but at the text's end: the
    /// ones NaturalLanguage keeps before a capital ("B. B. Seat", "H. F. Bingham"'s "F."), where it ends a
    /// sentence after the others ("H." "A." of "H. A. Herbert" is "H" ".").
    public static let alwaysKeptInitials: Set<Unicode.Scalar> = ["A", "B", "D", "E", "F", "G", "I", "K", "L", "M", "O", "Q", "S", "T", "U", "Z"]

    /// The initialisms whose period stays with them only as another word's does (rule 5), since
    /// NaturalLanguage ends a sentence after them before a capital or a number.
    public static let initialismsEndingSentences: Set<String> = ["p.m", "U.N", "U.S.S.R"]

    /// The first parts after which a hyphen stays in the word (rule 4), in lowercase as they must be printed.
    public static let joiningPrefixes: Set<String> = ["un", "co", "non", "anti"]

    /// The clitics that come off a word's end with their apostrophe (rule 3), lowercased, besides `n't`.
    public static let clitics: Set<String> = ["s", "re", "ve", "ll", "d", "m"]

    /// The tokens of `text`, in order.
    /// - Parameter text: Any text.
    /// - Returns: Its words, punctuation and symbols, by the rules at the top of this file.
    public static func tokens(in text: String) -> [LanguageToken] {
        var splitter = Splitter(text)
        return splitter.run()
    }

    /// The words of `text`, in order: ``tokens(in:)``'s words alone.
    public static func words(in text: String) -> [Range<String.Index>] {
        tokens(in: text).compactMap { $0.kind == .word ? $0.range : nil }
    }
}

/// What a scalar is to the splitter.
enum ScalarClass: UInt8 {
    case letter, digit, fraction, mark, apostrophe, hyphen, period, comma, space, lineBreak, punctuation, symbol

    /// The class of `scalar`, by the rules at the top of this file.
    static func of(_ scalar: Unicode.Scalar) -> ScalarClass {
        let value = scalar.value
        switch value {
        case 0x27, 0x2019: return .apostrophe
        case 0x2D, 0x2010, 0x2011: return .hyphen
        case 0x2E: return .period
        case 0x2C: return .comma
        case 0x0A...0x0D, 0x85, 0x2028, 0x2029: return .lineBreak
        case 0x41...0x5A, 0x61...0x7A: return .letter
        case 0x30...0x39: return .digit
        case 0x20, 0x09, 0x00...0x08, 0x0E...0x1F, 0x7F, 0x200B, 0xFEFF: return .space
        default: break
        }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            return .letter
        case .nonspacingMark, .spacingMark, .enclosingMark, .format:
            return .mark
        case .decimalNumber, .letterNumber:
            return .digit
        case .otherNumber:
            return .fraction
        case .spaceSeparator, .control:
            return .space
        case .lineSeparator, .paragraphSeparator:
            return .lineBreak
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return .punctuation
        default:
            return .symbol
        }
    }
}

/// One run of the splitter over a text.
private struct Splitter {
    let scalars: [Unicode.Scalar]
    /// Each scalar's index in the text, and the text's end after them.
    let positions: [String.Index]
    let classes: [ScalarClass]
    var tokens: [LanguageToken] = []
    var lineBreakPending = true

    init(_ text: String) {
        let view = text.unicodeScalars
        var scalars: [Unicode.Scalar] = []
        var positions: [String.Index] = []
        scalars.reserveCapacity(text.utf8.count)
        positions.reserveCapacity(text.utf8.count + 1)
        var index = view.startIndex
        while index < view.endIndex {
            scalars.append(view[index])
            positions.append(index)
            view.formIndex(after: &index)
        }
        positions.append(view.endIndex)
        self.scalars = scalars
        self.positions = positions
        self.classes = scalars.map(ScalarClass.of)
    }

    var count: Int { scalars.count }

    mutating func run() -> [LanguageToken] {
        tokens.reserveCapacity(count / 4)
        var k = 0
        while k < count {
            switch classes[k] {
            case .space:
                k += 1
            case .lineBreak:
                lineBreakPending = true
                k += 1
            case .letter, .digit:
                k = emitWord(from: k)
            case .fraction:
                var end = k + 1
                while end < count, classes[end] == .mark { end += 1 }
                emit(k, end, .word)
                k = end
            case .period, .hyphen:
                let run = classes[k]
                var end = k + 1
                while end < count, classes[end] == run { end += 1 }
                emit(k, end, .punctuation)
                k = end
            case .mark:
                var end = k + 1
                while end < count, classes[end] == .mark { end += 1 }
                emit(k, end, .symbol)
                k = end
            case .symbol:
                emit(k, k + 1, .symbol)
                k += 1
            case .apostrophe, .comma, .punctuation:
                emit(k, k + 1, .punctuation)
                k += 1
            }
        }
        return tokens
    }

    mutating func emit(_ start: Int, _ end: Int, _ kind: LanguageToken.Kind) {
        tokens.append(LanguageToken(range: positions[start]..<positions[end], kind: kind, startsLine: lineBreakPending))
        lineBreakPending = false
    }

    /// Emits the word that starts at `start`, with its clitics and its period, and returns where the
    /// splitter goes on.
    mutating func emitWord(from start: Int) -> Int {
        let end = wordEnd(from: start)
        var wordStart = start
        // French's elided d' and l', a word of their own (rule 3).
        if end - start >= 3, ["d", "l"].contains(lowercasedASCII(start, start + 1)), classes[start + 1] == .apostrophe,
           classes[start + 2] == .letter {
            emit(start, start + 2, .word)
            wordStart = start + 2
        }
        var pieces = splitClitics(wordStart, end)
        var next = end
        // Rule 5: the period after the last piece.
        if end < count, classes[end] == .period, !(end + 1 < count && classes[end + 1] == .period),
           keepsPeriod(pieces[pieces.count - 1], periodAt: end) {
            pieces[pieces.count - 1].1 = end + 1
            next = end + 1
        }
        for piece in pieces { emit(piece.0, piece.1, .word) }
        return next
    }

    /// Where the word that starts at `start` ends, by rules 1 to 4, before its clitics come off.
    func wordEnd(from start: Int) -> Int {
        var j = start + 1
        var lastBase = classes[start]
        var joinedHyphen = false
        while j < count {
            let here = classes[j]
            let following: ScalarClass? = j + 1 < count ? classes[j + 1] : nil
            switch here {
            case .letter, .digit:
                lastBase = here
                j += 1
            case .mark:
                j += 1
            case .period where (lastBase == .letter && following == .letter) || (lastBase == .digit && following == .digit):
                j += 1
            case .comma where lastBase == .digit && following == .digit:
                j += 1
            case .apostrophe where (lastBase == .letter || lastBase == .digit) && following == .letter:
                j += 1
            case .hyphen where !joinedHyphen && following == .letter && startsWithJoiningPrefix(start, j):
                joinedHyphen = true
                j += 1
            default:
                return j
            }
        }
        return j
    }

    /// Whether the scalars from `start` up to `end` are one of the joining prefixes, in lowercase.
    func startsWithJoiningPrefix(_ start: Int, _ end: Int) -> Bool {
        guard (2...4).contains(end - start), (start..<end).allSatisfy({ (0x61...0x7A).contains(scalars[$0].value) }) else { return false }
        return WordSplitter.joiningPrefixes.contains(lowercasedASCII(start, end) ?? "")
    }

    /// The scalars from `start` up to `end`, lowercased, when every one is an ASCII letter.
    func lowercasedASCII(_ start: Int, _ end: Int) -> String? {
        var text = ""
        for k in start..<end {
            let value = scalars[k].value
            switch value {
            case 0x41...0x5A: text.unicodeScalars.append(Unicode.Scalar(value + 0x20)!)
            case 0x61...0x7A: text.unicodeScalars.append(scalars[k])
            default: return nil
            }
        }
        return text
    }

    /// Whether any scalar from `start` up to `end` is a letter.
    func hasLetter(_ start: Int, _ end: Int) -> Bool {
        (start..<end).contains { classes[$0] == .letter }
    }

    /// The class of the last scalar before `position`, from `start`, that is not a mark.
    func lastBase(before position: Int, from start: Int) -> ScalarClass? {
        var k = position - 1
        while k >= start, classes[k] == .mark { k -= 1 }
        return k >= start ? classes[k] : nil
    }

    /// The word from `start` up to `end` in pieces, its clitics off its end (rule 3).
    func splitClitics(_ start: Int, _ end: Int) -> [(Int, Int)] {
        var headEnd = end
        var clitics: [(Int, Int)] = []
        while true {
            // n't, after a letter.
            if headEnd - start >= 4, classes[headEnd - 2] == .apostrophe,
               lowercasedASCII(headEnd - 3, headEnd - 2) == "n", lowercasedASCII(headEnd - 1, headEnd) == "t",
               hasLetter(start, headEnd - 3) {
                clitics.append((headEnd - 3, headEnd))
                headEnd -= 3
                continue
            }
            // 's, 're, 've, 'll, 'd, 'm, after a letter.
            var found = false
            for length in 1...2 {
                let apostrophe = headEnd - length - 1
                guard apostrophe > start, classes[apostrophe] == .apostrophe,
                      let suffix = lowercasedASCII(apostrophe + 1, headEnd), WordSplitter.clitics.contains(suffix),
                      lastBase(before: apostrophe, from: start) == .letter else { continue }
                clitics.append((apostrophe, headEnd))
                headEnd = apostrophe
                found = true
                break
            }
            if !found { break }
        }
        return [(start, headEnd)] + clitics.reversed()
    }

    /// Whether the period at `period` stays in `piece`, the word before it (rule 5).
    func keepsPeriod(_ piece: (Int, Int), periodAt period: Int) -> Bool {
        let (start, end) = piece
        // The next scalar that is not a space; a line break or the text's end keeps no period.
        var k = period + 1
        while k < count, classes[k] == .space { k += 1 }
        guard k < count, classes[k] != .lineBreak else { return false }
        let base = (start + 1..<end).allSatisfy({ classes[$0] == .mark }) ? scalars[start] : nil
        if let base, WordSplitter.alwaysKeptInitials.contains(base) { return true }
        let text = String(String.UnicodeScalarView(scalars[start..<end]))
        if WordSplitter.alwaysKeepsPeriod.contains(text) { return true }
        let initialism = (start + 1..<end).contains { classes[$0] == .period && classes[$0 - 1] == .letter }
        if initialism, !WordSplitter.initialismsEndingSentences.contains(text) { return true }
        // A period no sentence follows: before a lowercase letter, a comma, a colon, a semicolon, a hyphen,
        // a dash or a slash.
        switch scalars[k].value {
        case 0x2C, 0x3A, 0x3B, 0x2D, 0x2010, 0x2011, 0x2013, 0x2014, 0x2F: return true
        default: return classes[k] == .letter && scalars[k].properties.isLowercase
        }
    }
}
