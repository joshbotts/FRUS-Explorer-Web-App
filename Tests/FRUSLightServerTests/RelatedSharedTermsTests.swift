// The shares chips on Related Documents (PLAN's S29g), through the router over the synthetic export, whose vectors are the
// fixture shards: a row matched by meaning names the words it shares with the anchor in the kit's chip, and, with the
// lexical axis raised, the same words under that axis; a row that shares no word but stop words keeps the semantic match's
// percentage; and the pass, as the route runs it, tags on the queue it prefers, its words the kit's pass's. Every fixture
// pair's chips are held to the kit's over the fixture index in `RelatedDocumentsParityTests`.

import FRUSCoreKit
import FRUSLanguage
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import WordCloudKit

@testable import FRUSLightAPI

@Suite struct RelatedSharedTermsTests {
    static let volume = "frus1961-63v06"
    static let anchor = DocumentKey(volumeId: volume, documentId: "d1")
    static let second = DocumentKey(volumeId: volume, documentId: "d2")
    static let nicaragua = DocumentKey(volumeId: "frus1894Nicaragua", documentId: "d1")

    /// The web's tagger, noting the queue each of its walks runs on, as `CollocationExecutor.label` names it.
    final class QueueNotingTagger: WordCloudTagger, @unchecked Sendable {
        let inner = FRUSWordCloudTagger()
        private let lock = NSLock()
        private var noted: [String?] = []

        var queues: [String?] {
            lock.lock()
            defer { lock.unlock() }
            return noted
        }
        var identity: WordCloudTokenizerIdentity { inner.identity }
        var health: NaturalLanguageHealth { inner.health }

        private func note() {
            let queue = DispatchQueue.getSpecific(key: CollocationExecutor.label)
            lock.lock()
            noted.append(queue)
            lock.unlock()
        }

        func enumerateWords(in text: String, reading: WordCloudTagReading,
                            using body: (Range<String.Index>, String?, () -> WordCloudLexicalClass?) -> Bool) {
            note()
            inner.enumerateWords(in: text, reading: reading, using: body)
        }

        func enumerateNames(in text: String, using body: (Range<String.Index>, WordCloudNameType?) -> Bool) {
            note()
            inner.enumerateNames(in: text, using: body)
        }
    }

    /// The export's first document, "The ambassador was negotiating treaties with the minister.", and its second,
    /// "Negotiating began in May, and after many long weeks of talks the treaties came.", share one word that no stop
    /// list holds, as the tagger reduces them: "treaty", which the first prints as "treaties", so the chip names it in its
    /// dictionary form. The tagger reads the first's "negotiating" as a verb, "negotiate", and the second's, opening its
    /// sentence, as a noun it gives no lemma, so the two forms differ. The lexical axis, raised, scores the second too, and
    /// its chip names the same word.
    @Test func aRowMatchedByMeaningOrByWordingSaysWhatItShares() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await SemanticFeedbackTests.app(fixture).test(.router) { client in
            let base = "/api/v1/volumes/\(Self.volume)/documents/d1/related"
            let list = try decode(RelatedDocuments.self, try await client.execute(uri: base, method: .get))
            let second = try #require(list.rows.first { $0.volumeId == Self.volume && $0.documentId == "d2" })
            let meaning = try #require(second.chips.first { $0.axis == "semanticSimilarity" })
            #expect(meaning.text == "shares: treaty", "\(meaning.text)")
            #expect(second.semanticScore != nil && !second.chips.contains { $0.axis == "lexicalSimilarity" },
                    "the semantic axis scored it, and the lexical axis ships at 0")
            // Nicaragua's first document, "The canal concession and the Mosquito Reservation.", shares only "the", a stop
            // word: its chip says the match alone, the generator's label in the kit's arm for shared words.
            if let nicaragua = list.rows.first(where: { $0.volumeId == Self.nicaragua.volumeId }) {
                let chip = try #require(nicaragua.chips.first { $0.axis == "semanticSimilarity" })
                #expect(chip.text.hasPrefix("shares: Semantic match · ") && chip.text.hasSuffix("%"), "\(chip.text)")
            }
            let raised = try decode(RelatedDocuments.self, try await client.execute(uri: "\(base)?weights=lexicalSimilarity:1.0", method: .get))
            let worded = try #require(raised.rows.first { $0.volumeId == Self.volume && $0.documentId == "d2" })
            #expect(worded.chips.first { $0.axis == "lexicalSimilarity" }?.text == meaning.text, "\(worded.chips)")
            #expect(worded.chips.first { $0.axis == "semanticSimilarity" }?.text == meaning.text)
        }
    }

    /// The pass as the route runs it, with a tagger that notes where each of its walks runs: each of the three texts is
    /// walked once, on the pass's own queue, off the cooperative pool; and its words are the kit's pass's over the same
    /// index, lists and tagger, made apart.
    @Test func thePassTagsOnTheQueueItPrefersAndItsWordsAreTheKits() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let served = try await ServedIndexProvider(state: fixture.server.state, resources: fixture.server.resources,
                                                   volumesDirectory: fixture.server.reader.volumesDirectory).served()
        let resources = fixture.server.resources
        let lists = try await Blocking.run { RelatedDocumentsRoutes.sharedTermsLists(resources) }
        let candidates = [Self.second, Self.nicaragua]
        let tagger = QueueNotingTagger()
        let evidence = try await RelatedDocumentsRoutes.sharedTerms(anchor: Self.anchor, candidates: candidates, pipeline: served.pipeline,
                                                                    lists: lists, tagger: tagger)
        #expect(tagger.queues.count == 3 && tagger.queues.allSatisfy { $0 == RelatedDocumentsRoutes.sharedTermsQueue }, "\(tagger.queues)")
        let kits = await SemanticSharedTerms.sharedTerms(anchor: Self.anchor, candidates: candidates, pipeline: served.pipeline,
                                                         references: lists.references, languageAnalysis: tagger.health,
                                                         stopwords: lists.stopwords, tagger: FRUSWordCloudTagger())
        #expect(evidence == kits)
        #expect(Array(evidence.terms.keys) == [Self.second] && evidence.wordForm == .dictionary, "\(evidence)")
    }
}
