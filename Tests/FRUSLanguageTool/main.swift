// frus-language: the web tagger's tool (PLAN's S29c). It reads WordNet's database files into the lists
// the lemmatizer reads, trains the lexical-class tagger's model from a tagged text, writes the two files
// FRUSLanguage compiles them from, and evaluates a model on text it was not trained on. It runs in
// swift:6.4-noble through scripts/swift, on a text kept outside the repository: neither WordNet's files
// nor the training text are committed, only what is made of them, with their provenance.

import FRUSLanguage
import Foundation

let usage = """
    usage: frus-language wordnet  --dict <WordNet's dict folder> --licence <its LICENSE file> --source <provenance> [--out <swift file>]
           frus-language train    --conllu <file>[,<file>...] | --masc <folder> [--treebank <folder>] [--genres <a,b>] | --tsv <file>
                                  --source <provenance> [--passes <n>] [--seed <n>] [--hold-out <n>]
                                  [--out <swift file>] [--model <file>]
           frus-language evaluate --conllu <file>[,<file>...] | --masc <folder> [--treebank <folder>] | --tsv <file> [--hold-out <n>] [--model <file>]
           frus-language tag      <text file> [--model <file>]
           frus-language selftest [--write <file>]

      wordnet   WordNet's exception lists and single-word lemmas, in the lemmatizer's canonical text
                (default out: Sources/FRUSLanguage/EmbeddedWordNet.swift)
      train     the averaged perceptron over the text's lines, each re-split by the web's splitter and
                given the tag of the training token it overlaps most; with --hold-out n, every nth line is
                kept out of training and the model is scored on it (default out:
                Sources/FRUSLanguage/EmbeddedModel.swift; --model also writes the model's own file)
      evaluate  the model's tags and classes against a text's, over every nth line with --hold-out n, or
                every line (the embedded model, or --model's file)
      tag       a text file's words, tags, classes and lemmas, one word a line
      selftest  the self-test's lines and digest over the embedded model and lists; --write writes the digest and
                the family's identity to the file the tests and the smoke test hold the binary to
                (fixtures/language/selftest.sha256)

    --source is the provenance the generated file records: the text's name, address, licence and digest.
    """

/// A command and its options.
struct Arguments {
    let command: String
    var options: [String: String] = [:]
    var positional: [String] = []

    init(_ arguments: [String]) throws {
        guard let command = arguments.first else { throw ToolError("no command") }
        self.command = command
        var rest = arguments.dropFirst()
        while let next = rest.popFirst() {
            if next.hasPrefix("--") {
                guard let value = rest.popFirst() else { throw ToolError("\(next) needs a value") }
                guard options.updateValue(value, forKey: next) == nil else { throw ToolError("\(next) given twice") }
            } else {
                positional.append(next)
            }
        }
    }

    mutating func take(_ name: String) -> String? { options.removeValue(forKey: name) }

    mutating func int(_ name: String, default value: Int) throws -> Int {
        guard let text = take(name) else { return value }
        guard let number = Int(text), number >= 0 else { throw ToolError("\(name) takes a whole number") }
        return number
    }

    func finish() throws {
        if let name = options.keys.sorted().first { throw ToolError("\(command) takes no \(name)") }
    }
}

struct ToolError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func note(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}

/// The training text the options name.
func corpus(_ arguments: inout Arguments) throws -> TrainingCorpus {
    let conllu = arguments.take("--conllu"), masc = arguments.take("--masc"), tsv = arguments.take("--tsv")
    switch (conllu, masc, tsv) {
    case let (files?, nil, nil):
        return try TrainingCorpus.conllu(files.split(separator: ",").map { URL(fileURLWithPath: String($0)) })
    case let (nil, folder?, nil):
        let genres = arguments.take("--genres").map { Set($0.split(separator: ",").map(String.init)) }
        return try TrainingCorpus.masc(URL(fileURLWithPath: folder), treebank: arguments.take("--treebank").map { URL(fileURLWithPath: $0) },
                                       genres: genres)
    case let (nil, nil, file?):
        return try TrainingCorpus.tsv(URL(fileURLWithPath: file))
    default:
        throw ToolError("name one text: --conllu, --masc or --tsv")
    }
}

/// The tagger over a model's file, with that file's identity, or the embedded one.
func tagger(model path: String?) throws -> LanguageTagger {
    guard let path else { return LanguageTagger.shared }
    let shared = LanguageTagger.shared
    let bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: path)))
    return LanguageTagger(model: try PerceptronModel(decoding: bytes), lemmatizer: shared.lemmatizer,
                          identity: LanguageIdentity(name: shared.identity.name, rulesVersion: LanguageTagger.rulesVersion,
                                                     modelSHA256: LanguageTagger.sha256(bytes), listsSHA256: shared.identity.listsSHA256))
}

do {
    var arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    switch arguments.command {
    case "wordnet":
        guard let dict = arguments.take("--dict"), let licence = arguments.take("--licence"),
              let source = arguments.take("--source") else {
            throw ToolError("wordnet needs --dict, --licence and --source")
        }
        let out = arguments.take("--out") ?? "Sources/FRUSLanguage/EmbeddedWordNet.swift"
        try arguments.finish()
        let lists = try WordNetLists.read(dict: URL(fileURLWithPath: dict))
        let text = WordNetLists.canonicalText(lists)
        let licenceText = try String(contentsOf: URL(fileURLWithPath: licence), encoding: .utf8)
        try Generated.writeWordNet(text: text, source: source, licence: licenceText, lists: lists, to: URL(fileURLWithPath: out))
        for part in WordNetPart.allCases {
            note("wordnet: \(part.rawValue): \(lists[part]!.exceptions.count) exceptions, \(lists[part]!.lemmas.count) lemmas")
        }
        note("wordnet: \(text.utf8.count) bytes, SHA-256 \(LanguageTagger.sha256(Array(text.utf8))), in \(out)")
    case "train":
        let corpus = try corpus(&arguments)
        guard let source = arguments.take("--source") else { throw ToolError("train needs --source") }
        let passes = try arguments.int("--passes", default: 5)
        let seed = try arguments.int("--seed", default: 1)
        let holdOut = try arguments.int("--hold-out", default: 0)
        let out = arguments.take("--out") ?? "Sources/FRUSLanguage/EmbeddedModel.swift"
        let modelPath = arguments.take("--model")
        try arguments.finish()
        let run = try Training.run(corpus, passes: passes, seed: UInt64(seed), holdOut: holdOut, source: source)
        let bytes = run.model.encoded()
        if let modelPath { try Data(bytes).write(to: URL(fileURLWithPath: modelPath)) }
        try Generated.writeModel(bytes: bytes, provenance: run.provenance, to: URL(fileURLWithPath: out))
        note(run.summary)
        note("train: \(bytes.count) bytes, SHA-256 \(LanguageTagger.sha256(bytes)), in \(out)")
    case "evaluate":
        let corpus = try corpus(&arguments)
        let holdOut = try arguments.int("--hold-out", default: 0)
        let model = arguments.take("--model")
        try arguments.finish()
        let aligned = try corpus.alignedLines()
        let tagger = try tagger(model: model)
        let test = holdOut > 0 ? aligned.lines.enumerated().filter { $0.offset % holdOut == 0 }.map(\.element) : aligned.lines
        let score = Evaluation.score(tagger.model, on: test, tags: aligned.tags)
        print(score.report)
    case "tag":
        guard let path = arguments.positional.first, arguments.positional.count == 1 else { throw ToolError("tag takes one file") }
        let model = arguments.take("--model")
        try arguments.finish()
        let text = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        let tagger = try tagger(model: model)
        for word in tagger.tagged(text) {
            print("\(text[word.range])\t\(word.tag)\t\(word.lexicalClass.rawValue)\t\(word.lemma ?? "-")")
        }
    case "selftest":
        let write = arguments.take("--write")
        try arguments.finish()
        let tagger = LanguageTagger.shared
        for line in LanguageSelftest.lines(tagger) { print(line) }
        let digest = LanguageSelftest.digest(tagger)
        print("digest \(digest)")
        if let write {
            try Data("\(digest)  \(tagger.identity)\n".utf8).write(to: URL(fileURLWithPath: write))
            note("selftest: \(digest), \(tagger.identity), in \(write)")
        }
    default:
        throw ToolError("unknown command \(arguments.command)")
    }
} catch let error as ToolError {
    note("frus-language: \(error)\n\(usage)")
    exit(2)
} catch {
    note("frus-language: \(error)")
    exit(1)
}
