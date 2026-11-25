// Related Documents' shares chips (PLAN's S29g): a row matched by meaning or by wording says what it shares with the
// anchor, as the app's view says it once its pass over the rows shown has run
// (`RelatedDocumentsContent.attachSemanticEvidence(claimedKey:)`). The pass is the kit's,
// `SemanticSharedTerms.sharedTerms(anchor:candidates:pipeline:references:languageAnalysis:stopwords:tagger:isolation:)`
// (S29b): over the anchor's and the rows' bodies in the served index, the language family's reference (S29d), which prices
// each word by how rarely the corpus uses it, and the web's tagger (S29c), which reduces every word to its dictionary
// form, at most three words a row, the rarest first, each as the anchor spells it, or as the tagger reduced it where the
// anchor's text holds no such form. Its words are written under each of the two axes that scored the row, joined as the
// kit's chip splits them, and the kit's `whyRelatedChips` reads them as "shares: …"; a row it names none for keeps its
// generator's label, so that the semantic axis's chip says "shares: Semantic match · 71%", as the app's does.
//
// The pass tags, so it runs in a turn of a gate of its own, bounded as the word counts' is (S29e), so that a list never
// waits for a count or a scan of Collocates, and on a serial queue of its own that the task prefers (S29f's
// `CollocationExecutor`), off the main actor the ranking runs on and off Swift's cooperative pool. The web's own: the server
// keeps the walks of the texts it tagged last (`KeptWalks`), since a document recurs, in its neighbours' lists and in every
// list a reader ranks again as they tune it, where the app's view tags each row again at each reload; and the list comes
// with its words, where the app's shows its rows first and fills the words in when its pass lands.
// The kit's note on words compared as printed (`Evidence.printedFormsNote`) is never said here, since the tagger's words
// are never printed forms.

import FRUSCoreKit
import FRUSLanguage
import FRUSLightCore
import Foundation
import WordCloudKit

extension RelatedDocumentsRoutes {
    /// The axes whose chip names the words a row shares with the anchor (`attachSemanticEvidence(claimedKey:)`'s
    /// `vocabularyAxes`): one pass serves both, its words written under each that scored the row.
    static let vocabularyAxes: [SimilarityAxis] = [.semanticSimilarity, .lexicalSimilarity]

    /// The label of the serial queue the pass prefers, which a job on it finds as `CollocationExecutor.label`'s value.
    static let sharedTermsQueue = "frus-light.shared-terms"

    /// The tagger the pass walks with: the web's, keeping the walks of the last 500,000 words it walked.
    static let sharedTermsTagger = KeptWalks(WordCloudLive.tagger, wordLimit: 500_000)

    /// The pass's turns, half the processors from one to four, as the word counts' gate gives theirs: a gate of its own, so
    /// that a list waits for no count of a cloud or scan of Collocates, which hold their turns for seconds, where the app's
    /// list never waits for its pass.
    static let sharedTermsGate = CountGate(limit: min(4, ProcessInfo.processInfo.activeProcessorCount / 2))

    /// The shared words' lists: the app's stop lists, which the pass's tokenizer reads with the diplomatic one, and the
    /// language family's references as the kit reads them, which price its words; each decoded once, on first use, as
    /// Distinctive and Collocates read them.
    static func sharedTermsLists(_ resources: ServerResources) -> (stopwords: WordCloudStopwordSet, references: KeynessReferences) {
        (resources.familyClouds.stopwords(in: resources.directory),
         resources.familyClouds.references(language: resources.languageDirectory, lists: resources.directory))
    }

    /// `rows` with the words each shares with the anchor named, for its semantic and lexical chips, on the rows either
    /// axis scored (`attachSemanticEvidence(claimedKey:)`): the kit's pass over the anchor and those rows in `pipeline`,
    /// the family's references, at the verdict of the web's tagger, and the tagger, its words joined as the kit's chip
    /// splits them and written under each of the two axes that scored the row. A row it names no word for keeps its
    /// generator's label: the semantic axis's, "Semantic match · 71%", which the kit's chip reads as "shares: Semantic
    /// match · 71%", the app's chip too, and the lexical axis's percentage. A task cancelled before its turn of the pass
    /// leaves the rows as they are.
    static func namingSharedTerms(_ rows: [RelatedDocumentRow], anchor: DocumentKey, pipeline: IndexingPipeline,
                                  resources: ServerResources) async -> [RelatedDocumentRow] {
        let vocabularyAxes = Self.vocabularyAxes
        let scoredRows = rows.filter { row in
            vocabularyAxes.contains { row.axisScores[$0] != nil }
        }
        guard !scoredRows.isEmpty else { return rows }
        guard let lists = try? await Blocking.run({ sharedTermsLists(resources) }),
              let evidence = try? await sharedTerms(anchor: anchor, candidates: scoredRows.map(\.key), pipeline: pipeline,
                                                    lists: lists, tagger: sharedTermsTagger)
        else { return rows }
        guard !evidence.terms.isEmpty else { return rows }
        var rows = rows
        for index in rows.indices {
            guard let found = evidence.terms[rows[index].key], !found.isEmpty else { continue }
            for axis in vocabularyAxes where rows[index].axisScores[axis] != nil {
                rows[index].axisEvidenceLabel[axis] = found.joined(separator: "\u{1F}")
            }
        }
        return rows
    }

    /// The kit's pass as the route runs it: in a turn of its own gate, on a serial queue of its own that the task prefers
    /// and moves onto first, isolated to nothing so that it runs there, with `tagger` at its own verdict, which reads the
    /// reference in its form. A task cancelled before the pass begins throws, and once it has begun the pass runs to its
    /// end, as the kit's has no point at which it stops.
    static func sharedTerms<Tagger: WordCloudTagger & Sendable>(
        anchor: DocumentKey, candidates: [DocumentKey], pipeline: IndexingPipeline,
        lists: (stopwords: WordCloudStopwordSet, references: KeynessReferences), tagger: Tagger
    ) async throws -> SemanticSharedTerms.Evidence {
        try await sharedTermsGate.run {
            try await CollocationExecutor.run(label: sharedTermsQueue) {
                try Task.checkCancellation()
                return await SemanticSharedTerms.sharedTerms(
                    anchor: anchor, candidates: candidates, pipeline: pipeline, references: lists.references,
                    languageAnalysis: tagger.health, stopwords: lists.stopwords, tagger: tagger, isolation: nil)
            }
        }
    }
}

/// A tagger that keeps the walks of the texts it has walked, and gives a kept text's walk again without tagging it (PLAN's
/// S29g), the web's own: Related Documents' pass tags the anchor's body and each row's, and a document recurs, in the next
/// list of a neighbour and in every list a reader ranks again as they tune it.
///
/// A walk is the tagger's alone, a function of the text and of what the walk reads, so a text's walk is kept by the
/// text's UTF-8 bytes, never by `String`'s equality, which holds two canonically equivalent texts spelt in other scalars
/// equal, and by the reading: each word's range, as UTF-8 offsets into the text, its lemma, and its lexical class, read as
/// the walk is made when the walk reads classes. A kept walk is given in the same order, each range made again in the text
/// it is given for, which holds the same bytes; so the words a tokenizer counts from a kept walk are the words it counts
/// from the tagger's own. A walk its reader stopped is not kept. The walks kept hold at most `wordLimit` words: past it,
/// the least recently given are let go until they hold nine tenths of it, so that a text kept past the limit lets go of
/// several at once; a text of more words than the limit is walked and not kept.
final class KeptWalks<Inner: WordCloudTagger & Sendable>: WordCloudTagger, @unchecked Sendable {
    /// One word of a walk.
    struct Word: Sendable {
        /// Its range in the text, as UTF-8 offsets.
        let start: UInt32
        let end: UInt32
        let lemma: String?
        let lexicalClass: WordCloudLexicalClass?
    }

    /// A walk's key: its reading, and its text, compared and hashed by its UTF-8 bytes.
    private struct Key: Hashable {
        let reading: Int
        let text: String

        init(reading: Int, text: String) {
            var text = text
            text.makeContiguousUTF8()
            self.reading = reading
            self.text = text
        }

        static func == (left: Key, right: Key) -> Bool {
            guard left.reading == right.reading, left.text.utf8.count == right.text.utf8.count else { return false }
            if let compared = left.text.utf8.withContiguousStorageIfAvailable({ leftBytes in
                right.text.utf8.withContiguousStorageIfAvailable { rightBytes in
                    leftBytes.elementsEqual(rightBytes)
                }
            }), let same = compared {
                return same
            }
            return left.text.utf8.elementsEqual(right.text.utf8)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(reading)
            hasher.combine(text.utf8.count)
            if text.utf8.withContiguousStorageIfAvailable({ hasher.combine(bytes: UnsafeRawBufferPointer($0)) }) == nil {
                for byte in text.utf8 { hasher.combine(byte) }
            }
        }
    }

    private struct Kept {
        let words: [Word]
        var given: UInt64
    }

    let inner: Inner
    let wordLimit: Int
    private let lock = NSLock()
    private var kept: [Key: Kept] = [:]
    private var keptWords = 0
    private var clock: UInt64 = 0

    init(_ inner: Inner, wordLimit: Int) {
        self.inner = inner
        self.wordLimit = wordLimit
    }

    var identity: WordCloudTokenizerIdentity { inner.identity }
    var health: NaturalLanguageHealth { inner.health }

    /// How many texts' walks are kept, and how many words they hold.
    var count: (texts: Int, words: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (kept.count, keptWords)
    }

    func enumerateWords(in text: String, reading: WordCloudTagReading,
                        using body: (_ range: Range<String.Index>, _ lemma: String?,
                                     _ lexicalClass: () -> WordCloudLexicalClass?) -> Bool) {
        let key = Key(reading: reading.rawValue, text: text)
        let utf8 = text.utf8
        if let words = given(key) {
            for word in words {
                let start = utf8.index(utf8.startIndex, offsetBy: Int(word.start))
                let end = utf8.index(utf8.startIndex, offsetBy: Int(word.end))
                guard body(start..<end, word.lemma, { word.lexicalClass }) else { return }
            }
            return
        }
        var words: [Word] = []
        var whole = utf8.count <= Int(UInt32.max)
        inner.enumerateWords(in: text, reading: reading) { range, lemma, lexicalClass in
            let found = reading.contains(.lexicalClasses) ? lexicalClass() : nil
            if whole {
                words.append(Word(start: UInt32(utf8.distance(from: utf8.startIndex, to: range.lowerBound)),
                                  end: UInt32(utf8.distance(from: utf8.startIndex, to: range.upperBound)),
                                  lemma: lemma, lexicalClass: found))
            }
            guard body(range, lemma, { found }) else {
                whole = false
                return false
            }
            return true
        }
        // Kept at its own length, with no room to grow, which a walk built word by word holds.
        if whole { keep(words.withUnsafeBufferPointer(Array.init), under: key) }
    }

    /// Names are not kept: the pass reads none.
    func enumerateNames(in text: String,
                        using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool) {
        inner.enumerateNames(in: text, using: body)
    }

    /// The kept walk for `key`, marked as given now.
    private func given(_ key: Key) -> [Word]? {
        lock.lock()
        defer { lock.unlock() }
        guard var found = kept[key] else { return nil }
        clock += 1
        found.given = clock
        kept[key] = found
        return found.words
    }

    /// Keeps `words` under `key`; once the words kept pass the limit, lets the least recently given walks go until they
    /// hold nine tenths of it.
    private func keep(_ words: [Word], under key: Key) {
        guard words.count <= wordLimit else { return }
        lock.lock()
        defer { lock.unlock() }
        clock += 1
        if let previous = kept.updateValue(Kept(words: words, given: clock), forKey: key) {
            keptWords -= previous.words.count
        }
        keptWords += words.count
        guard keptWords > wordLimit else { return }
        let lowWater = wordLimit - wordLimit / 10
        for (oldest, walk) in kept.sorted(by: { $0.value.given < $1.value.given }) {
            guard keptWords > lowWater, oldest != key else { break }
            kept[oldest] = nil
            keptWords -= walk.words.count
        }
    }
}
