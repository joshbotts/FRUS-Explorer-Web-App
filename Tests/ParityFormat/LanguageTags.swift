// The Mac's words, lexical classes and lemmas for the fixture volumes' body texts (PLAN's S29c), which
// `tools/mac-golden tags` writes from NaturalLanguage, through the kit's readiness gate as the word cloud
// walks it, and `frus-parity language-report` compares the web's tagger with. SPEC expects no parity
// here: the report is information the owner reads.

import Foundation

/// `fixtures/golden/language/tags.json`: each fixture document's body text, by its digest, and the words
/// NaturalLanguage found in it, with each word's lexical class and lemma.
public struct LanguageTagsGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    /// How the words were found, in words: the code path and the tagger's settings.
    public var configuration: String
    /// What NaturalLanguage could do on the Mac that made the file, as the readiness gate's verdict says:
    /// `lemmatizes`, `classifiesWords` and `recognizesNames`.
    public var health: [String: Bool]
    /// Every fixture document with a body text, volumes sorted, each volume's in the index's order.
    public var documents: [LanguageTagsDocument]

    public static let currentFormat = 1

    public init(provenance: Provenance, configuration: String, health: [String: Bool], documents: [LanguageTagsDocument]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.configuration = configuration
        self.health = health
        self.documents = documents
    }
}

/// One document's body text and its words.
public struct LanguageTagsDocument: Codable, Equatable, Sendable {
    public var volume: String
    public var document: String
    /// The SHA-256 of the body text's UTF-8, which the comparison holds the web's text to.
    public var textSHA256: String
    /// The body text's length in Unicode scalars.
    public var scalars: Int
    /// The words, as `LanguageWordCodec` writes them.
    public var words: String

    public init(volume: String, document: String, textSHA256: String, scalars: Int, words: String) {
        self.volume = volume
        self.document = document
        self.textSHA256 = textSHA256
        self.scalars = scalars
        self.words = words
    }
}

/// A word: where it is in its text, in Unicode scalars, its lexical class, NaturalLanguage's raw tag, and
/// its lemma, as the tagger gave them, `nil` where it gave none.
public struct LanguageWord: Equatable, Sendable {
    public var start: Int
    public var length: Int
    public var lexicalClass: String?
    public var lemma: String?

    public init(start: Int, length: Int, lexicalClass: String?, lemma: String?) {
        self.start = start
        self.length = length
        self.lexicalClass = lexicalClass
        self.lemma = lemma
    }

    public var end: Int { start + length }
}

/// A document's words as one line of text, so that a file of three volumes' words stays a few megabytes
/// and diffs document by document.
///
/// Each word is `gap,length,class` or `gap,length,class,lemma`, the words separated by single spaces:
/// - `gap`, the scalars between the end of the word before (or the text's start) and this one's start;
/// - `length`, its length in scalars;
/// - `class`, its class by the letter ``classCodes`` gives it, `-` for none, or `*` and the raw tag for
///   any other;
/// - `lemma`, left out for none; `=` for the word as printed; `~` for the word lowercased; otherwise the
///   lemma, with `%`, `,`, a space and every scalar below U+0021 percent-encoded as UTF-8.
public enum LanguageWordCodec {
    /// NaturalLanguage's word classes by their letters.
    public static let classCodes: [String: String] = [
        "Noun": "N", "Verb": "V", "Adjective": "J", "Adverb": "R", "Pronoun": "P", "Determiner": "D",
        "Particle": "T", "Preposition": "I", "Number": "M", "Conjunction": "C", "Interjection": "U",
        "Classifier": "L", "Idiom": "Y", "OtherWord": "O",
    ]
    static let classNames = Dictionary(uniqueKeysWithValues: classCodes.map { ($0.value, $0.key) })

    /// The line for `words`, which must be in order and apart, in `text`.
    public static func encode(_ words: [LanguageWord], text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var previousEnd = 0
        var fields: [String] = []
        fields.reserveCapacity(words.count)
        for word in words {
            var field = "\(word.start - previousEnd),\(word.length),"
            switch word.lexicalClass {
            case nil: field += "-"
            case let raw?: field += classCodes[raw] ?? "*" + escape(raw)
            }
            if let lemma = word.lemma {
                let printed = String(String.UnicodeScalarView(scalars[word.start..<word.end]))
                field += "," + (lemma == printed ? "=" : lemma == printed.lowercased() ? "~" : escape(lemma))
            }
            fields.append(field)
            previousEnd = word.end
        }
        return fields.joined(separator: " ")
    }

    /// The words of a line, in `text`.
    /// - Throws: `GoldenError.malformed` for a line that is not in the form, or a word outside the text.
    public static func decode(_ line: String, text: String) throws -> [LanguageWord] {
        let scalars = Array(text.unicodeScalars)
        var words: [LanguageWord] = []
        var previousEnd = 0
        for field in line.split(separator: " ") {
            let parts = field.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count == 3 || parts.count == 4, let gap = Int(parts[0]), let length = Int(parts[1]),
                  gap >= 0, length > 0, gap <= scalars.count, length <= scalars.count,
                  previousEnd + gap + length <= scalars.count else {
                throw GoldenError.malformed(GoldenFile.languageTags.rawValue, "\(field) is not a word of its text")
            }
            let start = previousEnd + gap
            let code = String(parts[2])
            let lexicalClass: String?
            if code == "-" {
                lexicalClass = nil
            } else if code.hasPrefix("*") {
                lexicalClass = try unescape(String(code.dropFirst()))
            } else if let name = classNames[code] {
                lexicalClass = name
            } else {
                throw GoldenError.malformed(GoldenFile.languageTags.rawValue, "\(code) is not a class's letter")
            }
            var lemma: String?
            if parts.count == 4 {
                let printed = String(String.UnicodeScalarView(scalars[start..<start + length]))
                switch parts[3] {
                case "=": lemma = printed
                case "~": lemma = printed.lowercased()
                default: lemma = try unescape(String(parts[3]))
                }
            }
            words.append(LanguageWord(start: start, length: length, lexicalClass: lexicalClass, lemma: lemma))
            previousEnd = start + length
        }
        return words
    }

    static func escape(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            if scalar == "%" || scalar == "," || scalar == "=" || scalar == "~" || scalar == "*" || scalar.value < 0x21 {
                for byte in String(scalar).utf8 { out += "%" + String(byte, radix: 16, uppercase: true).leftPadded() }
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    static func unescape(_ text: String) throws -> String {
        guard text.contains("%") else { return text }
        var bytes: [UInt8] = []
        var utf8 = Array(text.utf8)[...]
        while let byte = utf8.popFirst() {
            if byte == UInt8(ascii: "%") {
                guard utf8.count >= 2, let value = UInt8(String(decoding: utf8.prefix(2), as: UTF8.self), radix: 16) else {
                    throw GoldenError.malformed(GoldenFile.languageTags.rawValue, "\(text) has a broken escape")
                }
                bytes.append(value)
                utf8 = utf8.dropFirst(2)
            } else {
                bytes.append(byte)
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

extension String {
    /// The string with a leading zero when it is one character long.
    fileprivate func leftPadded() -> String { count == 1 ? "0" + self : self }
}
