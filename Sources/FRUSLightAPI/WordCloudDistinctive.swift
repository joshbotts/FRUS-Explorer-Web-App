// Distinctive (PLAN's S29f): the Word Cloud's second measure, Size words by: Distinctive, which ranks a scope's live count
// (S29e) through the kit's `KeynessCloud.rank` (S29b) against the language family's reference (S29d) counted in the
// count's word form, as the app's view ranks the terms its cloud counted (`WordCloudView.recomputeKeyness`): the count's
// terms less the words hidden from this cloud alone, its true token total, the terms it fetched against the loader's
// limit, the reader's tuning and diplomatic layer, the count's own verdict and the server's tagger's identity. The
// references are the kit's reading of the family's two files by URL (`KeynessReferences(dictionaryAt:printedAt:
// lexiconsAt:stopwordsAt:)`), so that the kit's rule refuses a reader's settings the reference was not counted under, a
// reference another tokenizer counted, or word lists other than those it was counted over, each in the app's words
// (`WordCloudView.keynessUnavailableView`); the words for a count whose form has no reference are the server's, since the
// app's are a device's whose lemmatizer fails for a while (FRUS-Explorer#1972, open).
//
// A family's list holds the fifty words its scope uses most and no token total, too few for a ranking, where the app
// re-ranks the thousand its count kept (`WordCloudLoader.standardTermLimit`): Distinctive counts the corpus, a subseries
// and a volume live, as the app's view does, and where the served index holds none of the scope's text it says so, in
// the web's words, beside the family's list.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import WordCloudKit

/// A cloud's Distinctive reading (PLAN's S29f): the kit's ranking of the scope's live count against the family's
/// reference, or why there is none, in the app's words.
public struct CloudDistinctive: Codable, Equatable, Sendable {
    /// `ranked`, or `unavailable` with its reason and the page's words for it.
    public var state: String
    /// Why there is no ranking: the kit's `KeynessCloud.Unavailable` (`noArtifact`, `lensNotPriced`,
    /// `configurationMismatch`, `languageAnalysisUnavailable`, `noTermsAboveFloor`, `nothingOverRepresented`), or the
    /// web's `noCount`, a scope whose text the served index does not hold, and `noIndex`, while no index is served.
    public var reason: String?
    /// The title and the detail the page says a refusal in, "No Distinctiveness Ranking".
    public var message: CloudAnswer.Message?
    /// For `configurationMismatch`, the kit's names of what differs (`KeynessBaselineFile.Configuration.Mismatch`).
    public var mismatches: [String]?
    /// The words used more here than across the corpus, most distinctive first, as the app's keyness list draws them.
    public var scores: [Score]
    /// The cloud's layout input, `KeynessCloud.layoutTerms`: each score scaled to a size, never a count to show.
    public var layout: [CloudAnswer.Term]
    /// The header's count line under Distinctive, which counts the words ranked (`headerCountLine`'s shown terms).
    public var countLine: String?
    /// What the ranking can and cannot see, under the measure bar (`WordCloudView.keynessCaveat`).
    public var caveat: String?
    /// The line a ranking of printed forms says (`WordCloudDisplayState.comparedAsPrintedNote`), the server's words.
    public var comparedAsPrinted: String?
    /// The ranking's facts, as the kit's `KeynessCloud.Ranking` holds them.
    public var candidateCount: Int?
    public var rankedAmongTopFrequent: Bool?
    public var minimumScopeCount: Int?
    public var referenceRetained: Int?
    public var referenceDistinct: Int?
    public var referenceCutoffCount: Int?
    public var generated: String?
    /// `dictionary` or `printed`: the form the count and the reference were both counted in.
    public var wordForm: String?

    /// One word of the ranking: the kit's `KeynessScore`, with the multiple the app's row says and whether the word is
    /// rarer corpus-wide than the reference prices (`Ranking.isUnpriced`).
    public struct Score: Codable, Equatable, Sendable {
        public var term: String
        /// Occurrences in the scope, and in the corpus reference.
        public var scopeCount: Int
        public var referenceCount: Int
        /// Signed log-likelihood, G², which the list is ranked on.
        public var logLikelihood: Double
        /// Log₂ of the two relative frequencies, and the plain multiple it is (`foldOverRepresentation`).
        public var logRatio: Double
        public var fold: Double
        public var unpriced: Bool
        /// On the sentiment lens, the lexicon's polarity: 1, -1, or 0 for none.
        public var polarity: Int?
    }
}

extension CloudRules {
    /// `wordcloud.keyness.unavailable.title`.
    static var keynessTitle: String { appWords("wordcloud.keyness.unavailable.title", "No Distinctiveness Ranking") }

    /// The Distinctive reading of a live count, `WordCloudView.recomputeKeyness` on the server: the kit's ranking of the
    /// count's terms less `hidden`, the words hidden from this cloud alone (`visibleTerms(excluding:)`), against
    /// `references`, judged by the count's own verdict (`keynessLanguageAnalysis`: the result's stamp, else the tagger's)
    /// and the server's tagger's identity, under the reader's tuning and diplomatic layer.
    static func distinctive(_ result: WordCloudResult, lens: WordCloudLens, settings: CloudSettings, hidden: Set<String>,
                            references: KeynessReferences, lexicons: WordCloudLexiconSet) -> CloudDistinctive {
        let outcome = KeynessCloud.rank(
            terms: result.visibleTerms(excluding: hidden),
            scopeTotal: result.totalTokenCount,
            // The FETCHED count, not the visible one: a hide must not turn a truncated fetch into a claim of completeness.
            fetchedTermCount: result.terms.count,
            termLimit: WordCloudLive.termLimit,
            lens: lens,
            tuning: settings.tuning,
            includeDiplomatic: settings.includeDiplomatic,
            languageAnalysis: result.languageAnalysis ?? WordCloudLive.tagger.health,
            references: references,
            tokenizer: WordCloudLive.tagger.identity)
        switch outcome {
        case .unavailable(let reason):
            return unavailable(reason)
        case .ranked(let ranking):
            var reading = CloudDistinctive(state: "ranked", scores: [], layout: [])
            reading.scores = ranking.scores.map { score in
                CloudDistinctive.Score(term: score.term, scopeCount: score.scopeCount, referenceCount: score.referenceCount,
                                       logLikelihood: score.logLikelihood, logRatio: score.logRatio,
                                       fold: score.foldOverRepresentation, unpriced: ranking.isUnpriced(score),
                                       polarity: lens.colorsBySentiment ? lexicons.polarity(of: score.term.lowercased()) : nil)
            }
            reading.layout = KeynessCloud.layoutTerms(ranking.scores).map {
                CloudAnswer.Term(term: $0.term, count: $0.count,
                                 polarity: lens.colorsBySentiment ? lexicons.polarity(of: $0.term.lowercased()) : nil)
            }
            // `headerCountLine(for:shownTerms:documentCount:)` under keyness: the ranking's size, which is what is shown.
            reading.countLine = countLine(terms: ranking.scores.count, documents: result.documentCount)
            reading.caveat = keynessCaveat(ranking)
            reading.comparedAsPrinted = comparedAsPrintedNote(ranking)
            reading.candidateCount = ranking.candidateCount
            reading.rankedAmongTopFrequent = ranking.rankedAmongTopFrequent
            reading.minimumScopeCount = ranking.minimumScopeCount
            reading.referenceRetained = ranking.referenceRetained
            reading.referenceDistinct = ranking.referenceDistinct
            reading.referenceCutoffCount = ranking.referenceCutoffCount
            reading.generated = ranking.generated
            reading.wordForm = ranking.wordForm.rawValue
            return reading
        }
    }

    /// The refusal of `reason`, in the app's words (`keynessUnavailableView`).
    static func unavailable(_ reason: KeynessCloud.Unavailable) -> CloudDistinctive {
        var reading = CloudDistinctive(state: "unavailable", scores: [], layout: [])
        reading.reason = name(of: reason)
        reading.message = .init(title: keynessTitle, detail: keynessDetail(reason))
        if case .configurationMismatch(let mismatches) = reason { reading.mismatches = mismatches.map(\.rawValue) }
        return reading
    }

    /// A scope whose text the served index does not hold, beside the family's list, the web's own words: its fifty words
    /// carry no token total, too few for a ranking.
    static var withoutCount: CloudDistinctive {
        var reading = CloudDistinctive(state: "unavailable", scores: [], layout: [])
        reading.reason = "noCount"
        reading.message = .init(title: keynessTitle,
                                detail: "Distinctive ranks a count of this scope’s own documents, and this server’s index holds none of them, so there is nothing to rank. Its language family’s list keeps only the words the scope uses most.")
        return reading
    }

    /// The same while no index is served, none imported yet or one being installed, compacted or reset, the web's words.
    static var withoutIndex: CloudDistinctive {
        var reading = CloudDistinctive(state: "unavailable", scores: [], layout: [])
        reading.reason = "noIndex"
        reading.message = .init(title: keynessTitle,
                                detail: "Distinctive ranks a count of this scope’s own documents, and this server serves no index at the moment, so there is nothing to count. Its language family’s list keeps only the words the scope uses most.")
        return reading
    }

    /// The kit's name of a reason, `KeynessCloud.Unavailable`'s case.
    static func name(of reason: KeynessCloud.Unavailable) -> String {
        switch reason {
        case .pending: "pending"
        case .noArtifact: "noArtifact"
        case .lensNotPriced: "lensNotPriced"
        case .configurationMismatch: "configurationMismatch"
        case .languageAnalysisUnavailable: "languageAnalysisUnavailable"
        case .noTermsAboveFloor: "noTermsAboveFloor"
        case .nothingOverRepresented: "nothingOverRepresented"
        }
    }

    /// `WordCloudView.keynessUnavailableView(_:)`'s detail: why there is no ranking, always with the reason, and with the
    /// fix when there is one. A count in a form no reference this server holds was counted in is said in the server's
    /// words, the kit's health's terms, since the app's say that a device's lemmatizer may recover (FRUS-Explorer#1972).
    static func keynessDetail(_ reason: KeynessCloud.Unavailable) -> String {
        switch reason {
        case .pending:
            appWords("wordcloud.keyness.unavailable.pending", "Loading the bundled corpus reference…")
        case .noArtifact:
            appWords("wordcloud.keyness.unavailable.noArtifact", "The bundled corpus reference could not be loaded, so there is nothing to measure this scope against.")
        case .lensNotPriced(let lens):
            String(format: appWords("wordcloud.keyness.unavailable.lens %@", "The “%@” lens has no corpus reference. Names of people, places, and organizations are not counted across the whole corpus, so there is nothing to compare this scope against. Switch to another lens, or size words by frequency."),
                   label(lens))
        case .configurationMismatch(let mismatches):
            String(format: appWords("wordcloud.keyness.unavailable.mismatch %@", "Your settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to compare this scope with the corpus."),
                   mismatchDescription(mismatches))
        case .languageAnalysisUnavailable:
            "These words were counted as printed, because this server’s tagger does not reduce them to their dictionary forms, and this server holds no corpus reference counted as printed to compare them with. Size words by frequency instead."
        case .noTermsAboveFloor(let minimum):
            String(format: appWords("wordcloud.keyness.unavailable.floor %lld", "No word occurs at least %lld times in this scope. A word appearing once or twice can top a keyness ranking without saying anything about the documents, so nothing is ranked."),
                   Int64(minimum))
        case .nothingOverRepresented:
            appWords("wordcloud.keyness.unavailable.nothingDistinctive", "Nothing here is used more than it is across the corpus. This scope’s vocabulary is typical of the series.")
        }
    }

    /// `WordCloudView.keynessCaveat(_:)`: what the ranking can and cannot see, stated on screen: whether the cloud's term
    /// limit or the floor bounded the candidates, and the reference's cut, below which a word is unpriced, not absent.
    static func keynessCaveat(_ ranking: KeynessCloud.Ranking) -> String {
        var parts: [String] = []
        if ranking.rankedAmongTopFrequent {
            parts.append(String(format: appWords("wordcloud.keyness.caveat.truncated %lld", "Ranked among this scope’s %lld most frequent words."),
                                Int64(ranking.candidateCount)))
        } else {
            parts.append(String(format: appWords("wordcloud.keyness.caveat.complete %lld", "Ranked over every word occurring at least %lld times here."),
                                Int64(ranking.minimumScopeCount)))
        }
        if ranking.referenceCutoffCount > 1 {
            parts.append(String(format: appWords("wordcloud.keyness.caveat.reference %lld", "Words occurring fewer than %lld times corpus-wide are unpriced and score as if new."),
                                Int64(ranking.referenceCutoffCount)))
        }
        return parts.joined(separator: " ")
    }

    /// `WordCloudDisplayState.comparedAsPrintedNote(_:)`: the line a ranking of printed forms says, or none for one of
    /// dictionary forms, in the server's words, since the app's are a device's whose lemmatizer fails for a while. This
    /// server's tagger reduces words to their dictionary forms, so its counts never say it.
    static func comparedAsPrintedNote(_ ranking: KeynessCloud.Ranking) -> String? {
        guard ranking.wordForm == .printed else { return nil }
        return "Counted and compared as printed: this server’s tagger does not reduce words to their dictionary forms, so “negotiate” and “negotiated” are two words, here and in the corpus reference. A device that does reduce them can rank these words differently."
    }
}
