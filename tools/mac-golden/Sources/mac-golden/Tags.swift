// tags: the Mac's own words, lexical classes and lemmas for the fixture volumes' body texts (PLAN's S29c),
// which frus-parity language-report compares the web's tagger with. The body texts are the index's, as
// the word cloud counts them, from the app's own pipeline over the fixtures; the words are
// NaturalLanguage's, walked as the pinned WordCloudTokenizer walks a text for a part-of-speech lens.

import Foundation
import NaturalLanguage
import ParityFormat
@testable import FRUSExplorer

let tagsConfiguration = """
    The body texts are document_cache's body_text, as IndexingPipeline.fetchDocumentBodyText reads it, from \
    an index the app's own pipeline builds of the three fixture volumes in a scratch folder \
    (IndexingPipeline(fts5Store:databaseURL:volumesDirectory:resources:defaults:) with the submodule's \
    FRUSExplorer/Resources and an in-memory stamp store, indexVolume for each volume in sorted order), \
    every document with a body text, in the index's order. Each text is walked as the pinned \
    WordCloudTokenizer walks one for a part-of-speech lens: a new tagger from \
    NaturalLanguageReadiness.tagger(tagSchemes: [.lemma, .lexicalClass]), its string set and English pinned \
    over the whole text, enumerateTags by .word with NaturalLanguageReadiness.wordWalkScheme(of:), which \
    must be .lemma, omitting punctuation, whitespace and other tokens; each word's lemma the walk's tag, none \
    when it is missing or empty, and its class the .lexicalClass tag at the word's first character. \
    Offsets count Unicode scalars. A release build of the app module, with testing enabled, compiled from \
    the submodule unmodified.
    """

/// Where the tags go.
enum TagsPaths {
    /// The golden file, from the repository's root.
    static let golden = "fixtures/golden/" + GoldenFile.languageTags.rawValue
}

func tagsGolden(repo: Repository, out: URL) async throws {
    let inputs = try verifyFixtures(repo)
    let health = NaturalLanguageReadiness.health
    guard health.lemmatizes, health.classifiesWords else {
        throw ToolError("NaturalLanguage cannot lemmatize or classify words in this process (\(health)): the tags would be printed forms. Run again once Settings ▸ Data & Recovery ▸ Diagnostics reads Full")
    }
    let scratch = try Scratch()
    defer { scratch.remove() }
    let database = scratch.directory.appendingPathComponent("tags.db")
    let resources = try IndexingResources.loading(fromDirectory: repo.upstream.appendingPathComponent("FRUSExplorer/Resources"))
    let store = try FTS5Store(databaseURL: database)
    let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: database, volumesDirectory: repo.url(ParityFixtures.teiPath),
                                        resources: resources, defaults: InMemoryIndexingStampStore())
    var documents: [LanguageTagsDocument] = []
    var wordCount = 0
    for volume in ParityFixtures.volumes.sorted() {
        try await pipeline.indexVolume(volume)
        let entries = try await pipeline.documents(forVolume: volume)
        var tagged = 0
        for entry in entries {
            guard let text = try await pipeline.fetchDocumentBodyText(volumeId: volume, documentId: entry.documentId),
                  !text.isEmpty else { continue }
            let words = try naturalLanguageWords(text)
            documents.append(LanguageTagsDocument(
                volume: volume, document: entry.documentId, textSHA256: ParityFormat.Digest.sha256(text),
                scalars: text.unicodeScalars.count, words: LanguageWordCodec.encode(words, text: text)))
            wordCount += words.count
            tagged += 1
        }
        note("tags: \(volume), \(tagged) documents of \(entries.count)")
    }
    let golden = LanguageTagsGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden tags", inputs: inputs),
        configuration: tagsConfiguration,
        health: ["lemmatizes": health.lemmatizes, "classifiesWords": health.classifiesWords, "recognizesNames": health.recognizesNames],
        documents: documents)
    try GoldenJSON.write(golden, to: out)
    note("tags: \(documents.count) documents, \(wordCount) words, in \(repo.relativePath(out))")
}

/// NaturalLanguage's words of `text`, as the pinned WordCloudTokenizer's word walk reads them.
func naturalLanguageWords(_ text: String) throws -> [LanguageWord] {
    let tagger = NaturalLanguageReadiness.tagger(tagSchemes: [.lemma, .lexicalClass])
    let walk = NaturalLanguageReadiness.wordWalkScheme(of: tagger)
    guard walk == .lemma else { throw ToolError("the readiness gate left the lemma scheme out of the tagger, so the walk reads no lemma") }
    tagger.string = text
    tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
    let scalars = text.unicodeScalars
    var words: [LanguageWord] = []
    var position = text.startIndex, offset = 0
    var outOfOrder = false
    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: walk,
                         options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
        guard range.lowerBound >= position else { outOfOrder = true; return false }
        let start = offset + scalars.distance(from: position, to: range.lowerBound)
        let length = scalars.distance(from: range.lowerBound, to: range.upperBound)
        let lexicalClass = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0?.rawValue
        let lemma = tag?.rawValue
        words.append(LanguageWord(start: start, length: length, lexicalClass: lexicalClass,
                                  lemma: lemma?.isEmpty == false ? lemma : nil))
        position = range.upperBound
        offset = start + length
        return true
    }
    if outOfOrder { throw ToolError("NaturalLanguage's words came out of order") }
    return words
}
