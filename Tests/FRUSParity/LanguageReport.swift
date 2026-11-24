// The web tagger's agreement with the Mac's (PLAN's S29c): over the fixture volumes' body texts, the words
// both split the same, the lexical classes and the lemmas of those words, by part and by class, and the
// words the web's tagger tags a second. Information the owner reads: SPEC expects no parity here.

import FRUSCoreKit
import FRUSLanguage
import Foundation
import ParityFormat
import WordCloudKit

/// The comparison of the web's tagger with the Mac's over the golden file's documents.
public enum LanguageComparison {
    /// A document's body text and the Mac's words in it.
    public struct Document: Sendable {
        public let volume: String
        public let document: String
        public let text: String
        public let mac: [LanguageWord]
    }

    /// The body texts the golden file names, read from `pipeline`'s index, each held to the digest and the
    /// length the Mac recorded, with the Mac's words decoded against it.
    /// - Throws: `GoldenError.malformed` when a document is missing, its text differs from the Mac's or its
    ///   words do not read.
    public static func documents(golden: LanguageTagsGolden, pipeline: IndexingPipeline) async throws -> [Document] {
        var documents: [Document] = []
        for record in golden.documents {
            guard let text = try await pipeline.fetchDocumentBodyText(volumeId: record.volume, documentId: record.document) else {
                throw GoldenError.malformed(GoldenFile.languageTags.rawValue, "\(record.volume)/\(record.document) is not in the index")
            }
            guard ParityFormat.Digest.sha256(text) == record.textSHA256, text.unicodeScalars.count == record.scalars else {
                throw GoldenError.malformed(GoldenFile.languageTags.rawValue,
                                            "\(record.volume)/\(record.document)'s body text is not the one the Mac tagged")
            }
            documents.append(Document(volume: record.volume, document: record.document, text: text,
                                      mac: try LanguageWordCodec.decode(record.words, text: text)))
        }
        return documents
    }

    /// The web's words of `text`, as the golden file keeps the Mac's: offsets in Unicode scalars, the class's
    /// raw value and the lemma.
    public static func webWords(_ text: String, tagger: LanguageTagger) -> [LanguageWord] {
        let scalars = text.unicodeScalars
        var position = text.startIndex, offset = 0
        return tagger.tagged(text).map { word in
            let start = offset + scalars.distance(from: position, to: word.range.lowerBound)
            let length = scalars.distance(from: word.range.lowerBound, to: word.range.upperBound)
            position = word.range.upperBound
            offset = start + length
            return LanguageWord(start: start, length: length, lexicalClass: word.lexicalClass.rawValue, lemma: word.lemma)
        }
    }

    /// The form a word cloud counts a word in: its lemma lowercased, or, where it has none, the word as
    /// printed, lowercased and plural-folded by the kit's rule (`WordCloudTokenizer`'s, which reads no tagger).
    public static func countedForm(lemma: String?, printed: String) -> String {
        if let lemma, !lemma.isEmpty { return lemma.lowercased().replacingOccurrences(of: "\u{2019}", with: "'") }
        return WordCloudTokenizer.singularize(printed.lowercased())
    }

    /// The class a word cloud's lenses read a raw class as: noun, verb, adjective or other.
    public static func lensClass(_ raw: String?) -> String {
        switch raw {
        case "Noun": return "noun"
        case "Verb": return "verb"
        case "Adjective": return "adjective"
        default: return "other"
        }
    }

    /// The report over `documents`, the web's words from `tagger`.
    public static func report(documents: [Document], golden: LanguageTagsGolden, tagger: LanguageTagger) -> LanguageReport {
        var report = LanguageReport(family: tagger.identity.description, modelSHA256: tagger.identity.modelSHA256,
                                    listsSHA256: tagger.identity.listsSHA256, mac: golden.provenance.platform.os,
                                    documents: documents.count)
        var classPairs: [String: [String: Int]] = [:], lensPairs: [String: [String: Int]] = [:]
        var macOnly: [String: Int] = [:], webOnly: [String: Int] = [:]
        var classMisses: [String: Int] = [:], lemmaMisses: [String: Int] = [:]
        var lemmaByClass: [String: (count: Int, raw: Int, counted: Int)] = [:]
        for document in documents {
            let scalars = Array(document.text.unicodeScalars)
            func printed(_ word: LanguageWord) -> String { String(String.UnicodeScalarView(scalars[word.start..<word.end])) }
            let web = webWords(document.text, tagger: tagger)
            report.words.mac += document.mac.count
            report.words.web += web.count
            var webBySpan: [Int: LanguageWord] = [:]
            for word in web { webBySpan[word.start << 20 | word.length] = word }
            var matched = Set<Int>()
            for macWord in document.mac {
                let key = macWord.start << 20 | macWord.length
                guard let webWord = webBySpan[key] else { macOnly[printed(macWord), default: 0] += 1; continue }
                matched.insert(key)
                report.words.both += 1
                let macClass = macWord.lexicalClass ?? "none", webClass = webWord.lexicalClass ?? "none"
                classPairs[macClass, default: [:]][webClass, default: 0] += 1
                lensPairs[lensClass(macWord.lexicalClass), default: [:]][lensClass(webWord.lexicalClass), default: 0] += 1
                let text = printed(macWord)
                if macClass != webClass { classMisses["\(text): \(macClass) → \(webClass)", default: 0] += 1 }
                let macLemma = macWord.lemma.map { $0.lowercased().replacingOccurrences(of: "\u{2019}", with: "'") }
                let webLemma = webWord.lemma?.lowercased()
                let rawAgrees = macLemma == webLemma
                let countedAgrees = countedForm(lemma: macWord.lemma, printed: text) == countedForm(lemma: webWord.lemma, printed: text)
                var tally = lemmaByClass[macClass] ?? (0, 0, 0)
                tally.count += 1
                if rawAgrees { tally.raw += 1 }
                if countedAgrees { tally.counted += 1 }
                lemmaByClass[macClass] = tally
                if !countedAgrees, ["Noun", "Verb", "Adjective"].contains(macClass) {
                    lemmaMisses["\(text): \(macWord.lemma ?? "–") → \(webWord.lemma ?? "–")", default: 0] += 1
                }
            }
            for word in web where !matched.contains(word.start << 20 | word.length) { webOnly[printed(word), default: 0] += 1 }
        }
        report.classes = ClassAgreement(pairs: classPairs)
        report.lensClasses = ClassAgreement(pairs: lensPairs)
        report.lemmas = lemmaByClass.keys.sorted().map { key in
            let tally = lemmaByClass[key]!
            return LanguageReport.LemmaRow(macClass: key, words: tally.count, lemmasAgree: tally.raw, countedFormsAgree: tally.counted)
        }
        func top(_ counts: [String: Int]) -> [String] {
            counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(30).map { "\($0.key) ×\($0.value)" }
        }
        report.macWordsNotSplitAlike = top(macOnly)
        report.webWordsNotSplitAlike = top(webOnly)
        report.commonestClassDifferences = top(classMisses)
        report.commonestLemmaDifferences = top(lemmaMisses)
        return report
    }

    /// The words `tagger` tags a second over `documents`' texts, the best of `runs` passes, each tagging every
    /// text once, and the splitter's alone.
    public static func speed(documents: [Document], tagger: LanguageTagger, runs: Int = 3) -> LanguageReport.Speed {
        let clock = ContinuousClock()
        var words = 0, best = Duration.seconds(1_000_000), bestSplit = Duration.seconds(1_000_000)
        for _ in 0..<max(runs, 1) {
            var count = 0
            let tagging = clock.measure {
                for document in documents { count += tagger.tagged(document.text).count }
            }
            words = count
            best = min(best, tagging)
            let splitting = clock.measure {
                for document in documents { count &+= WordSplitter.tokens(in: document.text).count }
            }
            bestSplit = min(bestSplit, splitting)
        }
        func perSecond(_ duration: Duration) -> Int {
            let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
            return seconds > 0 ? Int((Double(words) / seconds).rounded()) : 0
        }
        return LanguageReport.Speed(words: words, wordsTaggedPerSecond: perSecond(best), wordsSplitPerSecond: perSecond(bestSplit),
                                    processors: ProcessInfo.processInfo.activeProcessorCount)
    }
}

/// How often two taggers' classes agree over the words both split alike, overall and by the Mac's class.
public struct ClassAgreement: Codable, Equatable, Sendable {
    public struct Row: Codable, Equatable, Sendable {
        public var macClass: String
        /// The words the Mac gave this class.
        public var mac: Int
        /// Of those, the words the web gave it too.
        public var agree: Int
        /// The words the web gave this class.
        public var web: Int
        /// The classes the web gave the Mac's words of this class, by count.
        public var webClasses: [String: Int]
    }

    public var words = 0
    public var agree = 0
    public var rows: [Row] = []

    public init() {}

    init(pairs: [String: [String: Int]]) {
        var webTotals: [String: Int] = [:]
        for (_, row) in pairs { for (webClass, count) in row { webTotals[webClass, default: 0] += count } }
        for macClass in Set(pairs.keys).union(webTotals.keys).sorted() {
            let row = pairs[macClass] ?? [:]
            let mac = row.values.reduce(0, +)
            words += mac
            agree += row[macClass] ?? 0
            rows.append(Row(macClass: macClass, mac: mac, agree: row[macClass] ?? 0, web: webTotals[macClass] ?? 0, webClasses: row))
        }
    }

    public var share: Double { words == 0 ? 0 : Double(agree) / Double(words) }
}

/// What `frus-parity language-report` gives.
public struct LanguageReport: Codable, Equatable, Sendable {
    public struct Words: Codable, Equatable, Sendable {
        /// The Mac's words, the web's, and the words both split alike, at the same place and length.
        public var mac = 0, web = 0, both = 0
        /// Of the Mac's words, the share the web split alike.
        public var recall: Double { mac == 0 ? 0 : Double(both) / Double(mac) }
        /// Of the web's words, the share the Mac split alike.
        public var precision: Double { web == 0 ? 0 : Double(both) / Double(web) }
    }

    public struct LemmaRow: Codable, Equatable, Sendable {
        public var macClass: String
        public var words: Int
        /// Words whose lemmas are the same, lowercased, or both missing.
        public var lemmasAgree: Int
        /// Words a word cloud counts in the same form: the lemma, or the printed word plural-folded.
        public var countedFormsAgree: Int
    }

    public struct Speed: Codable, Equatable, Sendable {
        public var words: Int
        public var wordsTaggedPerSecond: Int
        public var wordsSplitPerSecond: Int
        public var processors: Int
    }

    public var family: String
    public var modelSHA256: String
    public var listsSHA256: String
    /// The Mac whose NaturalLanguage made the golden file.
    public var mac: String
    public var documents: Int
    public var words = Words()
    public var classes = ClassAgreement()
    public var lensClasses = ClassAgreement()
    public var lemmas: [LemmaRow] = []
    public var speed: Speed?
    public var macWordsNotSplitAlike: [String] = []
    public var webWordsNotSplitAlike: [String] = []
    public var commonestClassDifferences: [String] = []
    public var commonestLemmaDifferences: [String] = []

    init(family: String, modelSHA256: String, listsSHA256: String, mac: String, documents: Int) {
        self.family = family
        self.modelSHA256 = modelSHA256
        self.listsSHA256 = listsSHA256
        self.mac = mac
        self.documents = documents
    }

    /// The lemmas' agreement over every word both split alike: words, lemmas agreeing, counted forms agreeing.
    public var lemmaTotals: (words: Int, lemmas: Int, counted: Int) {
        lemmas.reduce((0, 0, 0)) { ($0.0 + $1.words, $0.1 + $1.lemmasAgree, $0.2 + $1.countedFormsAgree) }
    }

    /// The report as the owner reads it.
    public var text: String {
        func percent(_ part: Int, _ whole: Int) -> String { whole == 0 ? "–" : String(format: "%.2f%%", 100 * Double(part) / Double(whole)) }
        var lines = [
            "The web's tagger against the Mac's, over the \(documents) fixture documents' body texts",
            "  family \(family) (model \(modelSHA256.prefix(12)), lists \(listsSHA256.prefix(12))); the Mac's NaturalLanguage on \(mac)",
            "",
            "Words (the splitter): the Mac's \(words.mac), the web's \(words.web), split alike \(words.both):",
            "  \(percent(words.both, words.mac)) of the Mac's words, \(percent(words.both, words.web)) of the web's",
            "",
            "Lexical classes (the tagger), over the \(classes.words) words split alike: \(percent(classes.agree, classes.words)) agree",
            "  the lenses' four (noun, verb, adjective, other): \(percent(lensClasses.agree, lensClasses.words)) agree",
        ]
        for row in lensClasses.rows {
            lines.append("    \(row.macClass.padding(toLength: 10, withPad: " ", startingAt: 0)) Mac \(row.mac), web \(row.web), both \(row.agree): "
                         + "\(percent(row.agree, row.mac)) of the Mac's, \(percent(row.agree, row.web)) of the web's")
        }
        lines.append("  by NaturalLanguage's class:")
        for row in classes.rows where row.mac > 0 || row.web > 0 {
            let others = row.webClasses.filter { $0.key != row.macClass }.sorted { $0.value > $1.value }.prefix(3)
                .map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            lines.append("    \(row.macClass.padding(toLength: 13, withPad: " ", startingAt: 0)) Mac \(row.mac), web \(row.web), both \(row.agree): "
                         + "\(percent(row.agree, row.mac)) of the Mac's" + (others.isEmpty ? "" : "; else \(others)"))
        }
        let totals = lemmaTotals
        lines += [
            "",
            "Lemmas (the lemmatizer), over the \(totals.words) words split alike: \(percent(totals.lemmas, totals.words)) the same lemma, "
                + "\(percent(totals.counted, totals.words)) counted in the same form",
        ]
        for row in lemmas where row.words > 0 {
            lines.append("    \(row.macClass.padding(toLength: 13, withPad: " ", startingAt: 0)) \(row.words) words: \(percent(row.lemmasAgree, row.words)) "
                         + "the same lemma, \(percent(row.countedFormsAgree, row.words)) the same counted form")
        }
        if let speed {
            lines += ["", "Speed: \(speed.words) words tagged at \(speed.wordsTaggedPerSecond) a second (split alone, \(speed.wordsSplitPerSecond)), "
                      + "one core of \(speed.processors)"]
        }
        lines += ["", "The Mac's words the web splits otherwise, commonest first:", "  " + macWordsNotSplitAlike.joined(separator: "; "),
                  "The web's words the Mac splits otherwise:", "  " + webWordsNotSplitAlike.joined(separator: "; "),
                  "The commonest class differences (Mac → web):", "  " + commonestClassDifferences.joined(separator: "; "),
                  "The commonest counted-form differences among nouns, verbs and adjectives (Mac's lemma → web's):",
                  "  " + commonestLemmaDifferences.joined(separator: "; ")]
        return lines.joined(separator: "\n")
    }
}
