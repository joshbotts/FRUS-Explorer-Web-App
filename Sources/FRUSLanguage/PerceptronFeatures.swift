// The perceptron's features (PLAN's S29c): what the tagger and its trainer read of each token in its
// line, hashed to 32-bit keys by integer arithmetic alone, so that a model scores the same on every
// architecture.
//
// The templates are those of Matthew Honnibal's averaged perceptron tagger ("A good part-of-speech
// tagger in about 200 lines of Python", 2013), which the textblob and NLTK taggers keep: the word, its
// last three and first scalars, the two tags before it, the words two either side and the suffixes of
// its neighbours, with a word's shape added, since the FRUS corpus prints headings in capitals and names
// a great many people and places. Words are normalised as that tagger normalises them: a hyphenated word
// is `!HYPHEN`, a four-digit number `!YEAR`, any other that starts with a digit `!DIGITS`, and the rest
// lowercased. Every token is first read with the typewriter's punctuation for the typographer's (`’s` as
// `'s`, `“` as `"`, `—` as `--`), since the FRUS corpus prints the one and the training text mostly the
// other, and a clitic or a quotation mark is the same token either way.

/// The hashes the features are made of.
enum FeatureHash {
    /// FNV-1a over a string's UTF-8 bytes.
    @inline(__always)
    static func fnv(_ text: Substring) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// FNV-1a over a string's UTF-8 bytes.
    @inline(__always)
    static func fnv(_ text: String) -> UInt64 { fnv(text[...]) }

    /// A template's key for one or two values, folded to 32 bits: SplitMix64's finaliser over the
    /// template and the values, which needs nothing but wrapping integer arithmetic.
    @inline(__always)
    static func key(_ template: UInt64, _ a: UInt64, _ b: UInt64 = 0) -> UInt32 {
        var h = template &* 0x9E37_79B9_7F4A_7C15
        h ^= a
        h = (h ^ (h >> 30)) &* 0xBF58_476D_1CE4_E5B9
        h ^= b &* 0xC2B2_AE3D_27D4_EB4F
        h = (h ^ (h >> 27)) &* 0x94D0_49BB_1331_11EB
        h ^= h >> 31
        return UInt32(truncatingIfNeeded: h) ^ UInt32(truncatingIfNeeded: h >> 32)
    }
}

/// The feature templates, by their number in the key.
enum FeatureTemplate: UInt64 {
    case bias = 1
    case suffix = 2
    case prefix = 3
    case previousTag = 4
    case tagBeforeThat = 5
    case twoTags = 6
    case word = 7
    case previousTagAndWord = 8
    case previousWord = 9
    case previousSuffix = 10
    case wordBeforeThat = 11
    case nextWord = 12
    case nextSuffix = 13
    case wordAfterThat = 14
    case shape = 15
}

/// What the features read of each token of a line, computed once a line.
struct LineFeatures {
    /// The normalised word's hash, with the two padding markers on each side.
    let words: [UInt64]
    /// The normalised word's last three scalars' hash, with the padding.
    let wordSuffixes: [UInt64]
    /// The printed word's last three scalars' hash, lowercased in a word all in capitals.
    let suffixes: [UInt64]
    /// The printed word's first scalar's hash.
    let prefixes: [UInt64]
    /// The printed word's shape.
    let shapes: [UInt64]
    /// The printed word's hash, by which the tag dictionary is read.
    let printed: [UInt64]

    /// The padding's normalised words and their suffixes: `-START-` and `-START2-` before a line,
    /// `-END-` and `-END2-` after it, as Honnibal's tagger pads its context.
    static let start = FeatureHash.fnv("-START-"), start2 = FeatureHash.fnv("-START2-")
    static let end = FeatureHash.fnv("-END-"), end2 = FeatureHash.fnv("-END2-")
    static let startSuffix = FeatureHash.fnv("RT-"), start2Suffix = FeatureHash.fnv("T2-")
    static let endSuffix = FeatureHash.fnv("ND-"), end2Suffix = FeatureHash.fnv("D2-")

    /// The tag values of the two positions before a line.
    static let startTag: UInt64 = 0xFFFF_0001, start2Tag: UInt64 = 0xFFFF_0002

    init<Words: Collection>(_ tokens: Words) where Words.Element == Substring {
        var words: [UInt64] = [Self.start2, Self.start]
        var wordSuffixes: [UInt64] = [Self.start2Suffix, Self.startSuffix]
        var suffixes: [UInt64] = [], prefixes: [UInt64] = [], shapes: [UInt64] = [], printed: [UInt64] = []
        let count = tokens.count
        words.reserveCapacity(count + 4)
        wordSuffixes.reserveCapacity(count + 4)
        suffixes.reserveCapacity(count)
        prefixes.reserveCapacity(count)
        shapes.reserveCapacity(count)
        printed.reserveCapacity(count)
        for printedToken in tokens {
            let token = Self.typewriter(printedToken)
            let shape = Shape(token)
            let normalised = Self.normalise(token, shape: shape)
            words.append(FeatureHash.fnv(normalised))
            wordSuffixes.append(FeatureHash.fnv(Self.lastThree(normalised)))
            let suffix = Self.lastThree(token)
            suffixes.append(FeatureHash.fnv(shape.allCapitals ? Substring(suffix.lowercased()) : suffix))
            prefixes.append(FeatureHash.fnv(token.unicodeScalars.first.map { Substring(String($0)) } ?? ""))
            shapes.append(shape.code)
            printed.append(FeatureHash.fnv(token))
        }
        words += [Self.end, Self.end2]
        wordSuffixes += [Self.endSuffix, Self.end2Suffix]
        self.words = words
        self.wordSuffixes = wordSuffixes
        self.suffixes = suffixes
        self.prefixes = prefixes
        self.shapes = shapes
        self.printed = printed
    }

    /// `token` with the typewriter's punctuation for the typographer's: U+2018, U+2019 and U+201B as `'`,
    /// U+201C, U+201D and U+201F as `"`, U+2013 as `-`, U+2014 as `--` and U+2026 as `...`.
    static func typewriter(_ token: Substring) -> Substring {
        guard token.unicodeScalars.contains(where: { (0x2013...0x2026).contains($0.value) }) else { return token }
        var out = String.UnicodeScalarView()
        for scalar in token.unicodeScalars {
            switch scalar.value {
            case 0x2018, 0x2019, 0x201B: out.append("'")
            case 0x201C, 0x201D, 0x201F: out.append("\"")
            case 0x2013: out.append("-")
            case 0x2014: out.append(contentsOf: "--".unicodeScalars)
            case 0x2026: out.append(contentsOf: "...".unicodeScalars)
            default: out.append(scalar)
            }
        }
        return Substring(String(out))
    }

    /// The last three scalars of `text`, or all of it when it is shorter.
    static func lastThree(_ text: Substring) -> Substring {
        let scalars = text.unicodeScalars
        guard let start = scalars.index(scalars.endIndex, offsetBy: -3, limitedBy: scalars.startIndex) else { return text }
        return Substring(scalars[start...])
    }

    /// The word as the features read it: `!HYPHEN`, `!YEAR`, `!DIGITS` or lowercased.
    static func normalise(_ token: Substring, shape: Shape) -> Substring {
        if shape.hyphenated { return "!HYPHEN" }
        if shape.fourDigits { return "!YEAR" }
        if shape.startsWithDigit { return "!DIGITS" }
        return shape.lowercase ? token : Substring(token.lowercased())
    }

    /// The keys of the token at `index` of the line, given the tags of the two tokens before it,
    /// written into `keys`, which holds 15.
    func keys(at index: Int, previous: UInt64, beforeThat: UInt64, into keys: inout [UInt32]) {
        let i = index + 2
        keys[0] = FeatureHash.key(FeatureTemplate.bias.rawValue, 0)
        keys[1] = FeatureHash.key(FeatureTemplate.suffix.rawValue, suffixes[index])
        keys[2] = FeatureHash.key(FeatureTemplate.prefix.rawValue, prefixes[index])
        keys[3] = FeatureHash.key(FeatureTemplate.previousTag.rawValue, previous)
        keys[4] = FeatureHash.key(FeatureTemplate.tagBeforeThat.rawValue, beforeThat)
        keys[5] = FeatureHash.key(FeatureTemplate.twoTags.rawValue, previous, beforeThat)
        keys[6] = FeatureHash.key(FeatureTemplate.word.rawValue, words[i])
        keys[7] = FeatureHash.key(FeatureTemplate.previousTagAndWord.rawValue, previous, words[i])
        keys[8] = FeatureHash.key(FeatureTemplate.previousWord.rawValue, words[i - 1])
        keys[9] = FeatureHash.key(FeatureTemplate.previousSuffix.rawValue, wordSuffixes[i - 1])
        keys[10] = FeatureHash.key(FeatureTemplate.wordBeforeThat.rawValue, words[i - 2])
        keys[11] = FeatureHash.key(FeatureTemplate.nextWord.rawValue, words[i + 1])
        keys[12] = FeatureHash.key(FeatureTemplate.nextSuffix.rawValue, wordSuffixes[i + 1])
        keys[13] = FeatureHash.key(FeatureTemplate.wordAfterThat.rawValue, words[i + 2])
        keys[14] = FeatureHash.key(FeatureTemplate.shape.rawValue, shapes[index])
    }

    /// How many keys a token has.
    static let keyCount = 15
}

/// A printed word's shape, which the features read and the normalisation follows.
struct Shape {
    var hasUpper = false, hasLower = false, hasDigit = false, hasPeriod = false, hasOther = false
    var firstUpper = false, startsWithDigit = false, hyphenated = false, fourDigits = false
    var lowercase: Bool { !hasUpper }
    var allCapitals: Bool { hasUpper && !hasLower }

    init(_ token: Substring) {
        var count = 0, digits = 0
        var first = true
        for scalar in token.unicodeScalars {
            count += 1
            let properties = scalar.properties
            if scalar.value == 0x2D || scalar.value == 0x2010 || scalar.value == 0x2011 {
                if !first { hyphenated = true }
                hasOther = true
            } else if scalar.value == 0x2E {
                hasPeriod = true
            } else if properties.numericType != nil {
                hasDigit = true
                digits += 1
                if first { startsWithDigit = true }
            } else if properties.isUppercase {
                hasUpper = true
                if first { firstUpper = true }
            } else if properties.isLowercase {
                hasLower = true
            } else if !properties.isAlphabetic {
                hasOther = true
            }
            first = false
        }
        fourDigits = count == 4 && digits == 4
    }

    /// The shape as a feature value: digits, capitals, an initial capital, lowercase or other, with a
    /// period's mark.
    var code: UInt64 {
        let base: UInt64
        if hasDigit { base = 1 }
        else if allCapitals { base = 2 }
        else if firstUpper { base = 3 }
        else if hasLower { base = 4 }
        else { base = 5 }
        return base | (hasPeriod ? 0x10 : 0) | (hasUpper && hasLower && !firstUpper ? 0x20 : 0)
    }
}
