// The training text, its alignment to the web's own tokens, the training run and the scoring.

import FRUSLanguage
import Foundation

/// A tagged token of a training text: its start and end in Unicode scalars, and its tag.
struct Span: Equatable {
    var start: Int
    var end: Int
    var tag: String
}

/// A training text's document: its text and its tagged tokens, in order.
struct AnnotatedText {
    var text: String
    var spans: [Span]
}

/// A training text: its documents, in order.
struct TrainingCorpus {
    var name: String
    var documents: [AnnotatedText]
    /// Where one unit of training text ends and the next begins: at each line break, as the tagger reads
    /// a text, or at a blank line, for a text whose lines break inside a paragraph.
    var unitBreak: UnitBreak = .lineBreak

    enum UnitBreak { case lineBreak, blankLine }

    /// Universal Dependencies' CoNLL-U files, each token's tag its XPOS (the English Web Treebank's are the
    /// Penn Treebank's). A document is each `# newdoc`'s sentences, a line each `# newpar`'s, its
    /// sentences joined by a space; a token is found in the sentence's `# text` at the cursor, and a
    /// sentence whose tokens do not spell its text is left out.
    static func conllu(_ files: [URL]) throws -> TrainingCorpus {
        var documents: [AnnotatedText] = []
        var text = "", spans: [Span] = []
        var scalarCount = 0
        var skipped = 0
        func finishDocument() {
            if !spans.isEmpty { documents.append(AnnotatedText(text: text, spans: spans)) }
            text = ""
            spans = []
            scalarCount = 0
        }
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            var sentenceText: String?
            var tokens: [(form: String, tag: String)] = []
            var newParagraph = false
            func finishSentence() {
                defer { sentenceText = nil; tokens = []; newParagraph = false }
                guard let sentence = sentenceText, !tokens.isEmpty else { return }
                let scalars = Array(sentence.unicodeScalars)
                var cursor = 0
                var found: [Span] = []
                for token in tokens {
                    while cursor < scalars.count, scalars[cursor].properties.isWhitespace { cursor += 1 }
                    let form = Array(token.form.unicodeScalars)
                    guard cursor + form.count <= scalars.count, Array(scalars[cursor..<cursor + form.count]) == form else {
                        skipped += 1
                        return
                    }
                    found.append(Span(start: cursor, end: cursor + form.count, tag: token.tag))
                    cursor += form.count
                }
                if !text.isEmpty {
                    let separator = newParagraph ? "\n" : " "
                    text += separator
                    scalarCount += 1
                }
                for span in found {
                    spans.append(Span(start: span.start + scalarCount, end: span.end + scalarCount, tag: span.tag))
                }
                text += sentence
                scalarCount += scalars.count
            }
            for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
                if line.hasPrefix("# newdoc") {
                    finishSentence()
                    finishDocument()
                } else if line.hasPrefix("# newpar") {
                    newParagraph = true
                } else if line.hasPrefix("# text = ") {
                    sentenceText = String(line.dropFirst("# text = ".count))
                } else if line.hasPrefix("#") {
                    continue
                } else if line.isEmpty {
                    finishSentence()
                } else {
                    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
                    guard fields.count >= 5, !fields[0].contains("-"), !fields[0].contains(".") else { continue }
                    tokens.append((String(fields[1]), String(fields[4])))
                }
            }
            finishSentence()
            finishDocument()
        }
        if skipped > 0 { note("conllu: \(skipped) sentences whose tokens do not spell their text, left out") }
        return TrainingCorpus(name: files.map(\.lastPathComponent).joined(separator: ", "), documents: documents)
    }

    /// The Manually Annotated Sub-Corpus's GrAF files: each text with its Penn Treebank tokens.
    static func masc(_ folder: URL, treebank: URL?, genres: Set<String>? = nil) throws -> TrainingCorpus {
        try MASCReader.read(folder, treebank: treebank, genres: genres)
    }

    /// A file of `word<TAB>tag` lines, a blank line between lines of text: one document.
    static func tsv(_ file: URL) throws -> TrainingCorpus {
        var text = "", spans: [Span] = [], count = 0
        var lineHasWords = false
        for line in try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false) {
            if line.isEmpty {
                if lineHasWords { text += "\n"; count += 1; lineHasWords = false }
                continue
            }
            let fields = line.split(separator: "\t")
            guard fields.count == 2 else { throw ToolError("\(file.lastPathComponent): \(line) is not a word, a tab and a tag") }
            if lineHasWords { text += " "; count += 1 }
            let word = String(fields[0])
            let length = word.unicodeScalars.count
            spans.append(Span(start: count, end: count + length, tag: String(fields[1])))
            text += word
            count += length
            lineHasWords = true
        }
        return TrainingCorpus(name: file.lastPathComponent, documents: [AnnotatedText(text: text, spans: spans)])
    }

    /// The documents' lines as the trainer reads them: each re-split by the web's splitter, each token
    /// given the tag of the training token it overlaps most (the first, on a tie); a punctuation token
    /// that overlaps a word's token alone, or none, the tag the text gives that punctuation most often;
    /// and a line holding a word that overlaps no training token left out.
    func alignedLines() throws -> AlignedCorpus {
        var punctuationTags: [String: [String: Int]] = [:]
        for document in documents {
            let scalars = Array(document.text.unicodeScalars)
            for span in document.spans where span.end - span.start <= 3 {
                let text = String(String.UnicodeScalarView(scalars[span.start..<span.end]))
                if text.unicodeScalars.allSatisfy({ !$0.properties.isAlphabetic && $0.properties.numericType == nil }) {
                    punctuationTags[text, default: [:]][span.tag, default: 0] += 1
                }
            }
        }
        func punctuationTag(_ text: String) -> String {
            if let counts = punctuationTags[text], let best = counts.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }) {
                return best.key
            }
            return TagClasses.pennPunctuation(text)
        }
        var named: [(tokens: [Substring], tags: [String])] = []
        var dropped = 0, tokenCount = 0, exact = 0
        var uncovered: [String: Int] = [:]
        for document in documents {
            let text = document.text
            let tokens = WordSplitter.tokens(in: text)
            let scalars = text.unicodeScalars
            var offset = 0, position = scalars.startIndex
            func scalarOffset(_ index: String.Index) -> Int {
                offset += scalars.distance(from: position, to: index)
                position = index
                return offset
            }
            var spanIndex = 0
            var line: (tokens: [Substring], tags: [String]) = ([], [])
            var lineOK = true
            func finishLine() {
                if !line.tokens.isEmpty {
                    if lineOK { named.append(line) } else { dropped += 1 }
                }
                line = ([], [])
                lineOK = true
            }
            var previousEnd = text.startIndex
            for token in tokens {
                switch unitBreak {
                case .lineBreak:
                    if token.startsLine { finishLine() }
                case .blankLine:
                    let between = text[previousEnd..<token.range.lowerBound]
                    if between.filter({ $0 == "\n" || $0 == "\r\n" || $0 == "\r" }).count >= 2 { finishLine() }
                }
                previousEnd = token.range.upperBound
                let start = scalarOffset(token.range.lowerBound), end = scalarOffset(token.range.upperBound)
                while spanIndex < document.spans.count, document.spans[spanIndex].end <= start { spanIndex += 1 }
                var best: Span?, bestOverlap = 0
                var k = spanIndex
                while k < document.spans.count, document.spans[k].start < end {
                    let span = document.spans[k]
                    let overlap = min(end, span.end) - max(start, span.start)
                    if overlap > bestOverlap { best = span; bestOverlap = overlap }
                    k += 1
                }
                let printed = text[token.range]
                tokenCount += 1
                if let best, best.start == start, best.end == end { exact += 1 }
                switch token.kind {
                case .word:
                    guard let best else {
                        lineOK = false
                        uncovered[String(printed), default: 0] += 1
                        line.tokens.append(printed)
                        line.tags.append("")
                        continue
                    }
                    line.tokens.append(printed)
                    line.tags.append(best.tag)
                case .punctuation, .symbol:
                    let tag: String
                    if let best, !(TagClasses.penn(best.tag)?.isWordClass ?? false) || (best.end - best.start) == (end - start) {
                        tag = best.tag
                    } else {
                        tag = punctuationTag(String(printed))
                    }
                    line.tokens.append(printed)
                    line.tags.append(tag)
                }
            }
            finishLine()
        }
        if !uncovered.isEmpty {
            let common = uncovered.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(25)
            note("align: \(uncovered.values.reduce(0, +)) words overlap no training token, their lines left out; the commonest: "
                 + common.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
        }
        let tags = Set(named.flatMap(\.tags)).sorted()
        guard tags.count <= 255 else { throw ToolError("\(tags.count) tags, past the model's 255") }
        let place = Dictionary(uniqueKeysWithValues: tags.enumerated().map { ($0.element, UInt8($0.offset)) })
        let lines = named.map { TrainingLine(tokens: $0.tokens, tags: $0.tags.map { place[$0]! }) }
        return AlignedCorpus(lines: lines, tags: tags, dropped: dropped, tokens: tokenCount, exact: exact)
    }
}

/// A training text aligned to the web's tokens.
struct AlignedCorpus {
    var lines: [TrainingLine]
    var tags: [String]
    var dropped: Int
    var tokens: Int
    var exact: Int
}

/// The class each tag gives.
enum TagClasses {
    /// The class a Penn Treebank tag gives, as close to NaturalLanguage's reading as the tag can say, by
    /// probes of NaturalLanguage on macOS 27.2.1 (DEVLOG's Session 29c): possessive pronouns are its
    /// determiners, wh-adverbs and relative `which` its pronouns, `that` and the subordinating conjunctions
    /// its prepositions, modals its verbs, the possessive `'s` its particle, a list's item marker its number
    /// ("(b)"). `TO` and `CD` have rules that read more (`PerceptronModel.lexicalClass(at:tags:tokens:)`).
    static func penn(_ tag: String) -> LexicalClass? {
        switch tag {
        case "NN", "NNS", "NNP", "NNPS", "NP", "NPS": return .noun
        case "VB", "VBD", "VBG", "VBN", "VBP", "VBZ", "MD": return .verb
        case "JJ", "JJR", "JJS": return .adjective
        case "RB", "RBR", "RBS": return .adverb
        case "PRP", "WP", "EX", "WRB", "WDT": return .pronoun
        case "PRP$", "PP$", "WP$", "DT", "PDT": return .determiner
        case "IN", "TO": return .preposition
        case "RP", "POS": return .particle
        case "CC": return .conjunction
        case "CD": return .number
        case "UH": return .interjection
        case "LS": return .number
        case "FW", "SYM", "ADD", "AFX", "GW", "XX", "$", "#": return .otherWord
        case ".": return .sentenceTerminator
        case ",", ":", "NFP", "SU": return .punctuation
        case "``": return .openQuote
        case "''": return .closeQuote
        case "-LRB-", "(": return .openParenthesis
        case "-RRB-", ")": return .closeParenthesis
        case "HYPH": return .dash
        default: return nil
        }
    }

    /// The Penn Treebank's tag for a punctuation token the training text left untagged.
    static func pennPunctuation(_ text: String) -> String {
        switch text {
        case ".", "!", "?": return "."
        case ",": return ","
        case "(", "[", "{": return "-LRB-"
        case ")", "]", "}": return "-RRB-"
        case "\u{201C}", "\u{2018}", "``": return "``"
        case "\u{201D}", "\u{2019}", "''", "\"", "'": return "''"
        case "$": return "$"
        case "#": return "#"
        default: return ":"
        }
    }

    /// The class of each of `tags`, refusing a tag the table does not know.
    static func classes(_ tags: [String]) throws -> [LexicalClass] {
        try tags.map { tag in
            guard let tagClass = penn(tag) else { throw ToolError("the tag \(tag) has no class in the Penn Treebank's table") }
            return tagClass
        }
    }
}

/// A training run: the model, and what it was made from and scored at.
struct Training {
    var model: PerceptronModel
    var provenance: String
    var summary: String

    static func run(_ corpus: TrainingCorpus, passes: Int, seed: UInt64, holdOut: Int, source: String) throws -> Training {
        let aligned = try corpus.alignedLines()
        let classes = try TagClasses.classes(aligned.tags)
        var heldOut: Evaluation.Score?
        if holdOut > 0 {
            var trainer = PerceptronTrainer(tags: aligned.tags, tagClasses: classes)
            let split = aligned.lines.enumerated()
            trainer.train(split.filter { $0.offset % holdOut != 0 }.map(\.element), passes: passes, seed: seed)
            heldOut = Evaluation.score(trainer.model(), on: split.filter { $0.offset % holdOut == 0 }.map(\.element), tags: aligned.tags)
        }
        var trainer = PerceptronTrainer(tags: aligned.tags, tagClasses: classes)
        trainer.train(aligned.lines, passes: passes, seed: seed)
        let model = trainer.model()
        let bytes = model.encoded()
        let wordTokens = aligned.lines.reduce(0) { $0 + $1.tokens.count }
        var record: [String: Any] = [
            "trainingText": source,
            "corpus": corpus.name,
            "documents": corpus.documents.count,
            "lines": aligned.lines.count,
            "linesLeftOut": aligned.dropped,
            "tokens": wordTokens,
            "tokensSplitAsTheTextSplitsThemPerThousand": aligned.exact * 1000 / max(aligned.tokens, 1),
            "passes": passes,
            "seed": Int(seed),
            "passAccuracyPerThousand": trainer.passAccuracy,
            "tags": zip(aligned.tags, classes).map { "\($0) \($1.rawValue)" },
            "features": model.featureCount,
            "weights": model.weightCount,
            "dictionaryWords": model.dictionaryCount,
            "bytes": bytes.count,
            "sha256": LanguageTagger.sha256(bytes),
            "splitterRulesVersion": LanguageTagger.rulesVersion,
        ]
        if let heldOut {
            record["heldOut"] = ["everyNthLine": holdOut, "tokens": heldOut.tokens, "tagAccuracy": heldOut.tagAccuracy,
                                 "wordTokens": heldOut.words, "classAccuracy": heldOut.classAccuracy,
                                 "lensClassAccuracy": heldOut.lensAccuracy]
        }
        let json = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        var summary = "train: \(corpus.documents.count) documents, \(aligned.lines.count) lines (\(aligned.dropped) left out), \(wordTokens) tokens, "
            + "\(aligned.exact * 1000 / max(aligned.tokens, 1))/1000 split as the text splits them; "
            + "\(aligned.tags.count) tags; passes \(trainer.passAccuracy.map(String.init).joined(separator: ", ")) per thousand; "
            + "\(model.featureCount) features, \(model.weightCount) weights, \(model.dictionaryCount) dictionary words"
        if let heldOut { summary += "\nheld out: " + heldOut.report }
        return Training(model: model, provenance: String(decoding: json, as: UTF8.self), summary: summary)
    }
}

/// A model scored against a text's own tags.
enum Evaluation {
    struct Score {
        var tokens = 0, tagsRight = 0, words = 0, classesRight = 0, lensRight = 0
        var tagAccuracy: Double { Double(tagsRight) / Double(max(tokens, 1)) }
        var classAccuracy: Double { Double(classesRight) / Double(max(words, 1)) }
        var lensAccuracy: Double { Double(lensRight) / Double(max(words, 1)) }
        var report: String {
            String(format: "%d tokens, tags %.4f; %d words, classes %.4f, the lenses' four classes %.4f",
                   tokens, tagAccuracy, words, classAccuracy, lensAccuracy)
        }
    }

    /// Scores `model` over `lines`, whose tags are places in `tags`: the tags by name over every token,
    /// and the classes, NaturalLanguage's and the lenses' four, over the words, the text's own tags'
    /// classes read by the model's rules.
    static func score(_ model: PerceptronModel, on lines: [TrainingLine], tags: [String]) -> Score {
        var score = Score()
        let truthModel = TruthClasses(tags: tags)
        for line in lines {
            let guessed = model.tag(line: line.tokens)
            for index in line.tokens.indices {
                score.tokens += 1
                if model.tags[Int(guessed[index])] == tags[Int(line.tags[index])] { score.tagsRight += 1 }
                let truth = truthModel.lexicalClass(at: index, tags: line.tags, tokens: line.tokens)
                guard truth.isWordClass, line.tokens[index].first.map({ $0.isLetter || $0.isNumber }) == true else { continue }
                let guess = model.lexicalClass(at: index, tags: guessed, tokens: line.tokens)
                score.words += 1
                if guess == truth { score.classesRight += 1 }
                if guess.lensClass == truth.lensClass { score.lensRight += 1 }
            }
        }
        return score
    }
}

/// The classes a text's own tags give, by the model's rules.
struct TruthClasses {
    let model: PerceptronModel

    init(tags: [String]) {
        var trainer = PerceptronTrainer(tags: tags, tagClasses: tags.map { TagClasses.penn($0) ?? .otherWord })
        trainer.train([], passes: 0, seed: 0)
        model = trainer.model()
    }

    func lexicalClass(at index: Int, tags: [UInt8], tokens: [Substring]) -> LexicalClass {
        model.lexicalClass(at: index, tags: tags, tokens: tokens)
    }
}
