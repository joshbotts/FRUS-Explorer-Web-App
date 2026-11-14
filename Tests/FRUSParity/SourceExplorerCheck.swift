// Check 8 (docs/SPEC.md, Verification; PLAN's S22d): every source note of the fixture volumes resolved through
// the API, `GET …/documents/{d}/sources`, and each record held to the one the app's Source Explorer export
// generator builds for the same note, `SourceExplorerExportRunner.exportRecord` (FRUS-Explorer#1894), over the
// same bundled files.
//
// The notes are the generator's own reading of the TEI, `DocumentNoteExtractor` and `DocumentYearExtractor`, as
// its run reads each volume. For each, the API's answer gives what the server resolved through the kit: the note
// it stores, the year its panels read, the parse, the keys the parse gives, the lot the central files resolve,
// the Numerical File's rolls and the collection authority's record. The record built from the answer is the
// generator's record for the note the API returned, with each of those in place of the generator's own reading;
// the rest of the record is the generator's classification of that note (its strategy, the live route it
// records, why a lot missed the bundle, the volume-sources diagnostic), and the outcome is its precedence over
// the record's resolutions. The two records must be equal, field for field, under two rules of the export's
// own, each named where it is applied:
// - a lot the bundle resolves is recorded as matched by the bundled lot-file index (`matchType` "lot", which
//   the generator's `BundledLotResolver` writes for every one), where the kit's resolution keeps the bundle
//   entry's own record of how NARA's harvest matched it; every other field of the series is compared;
// - the year: the API's is the one both of the app's views read, the dateline's
//   (`CentralFilesClassifier.documentYear(fromDateline:)`, the reader's `extractYear(from:)`), where the export
//   reads `frus:doc-dateTime-min`. They differ only where a dateline gives no year ("Moscow, undated"), for
//   which the API gives none: such a record takes the export's year when that year resolves nothing, outside
//   the Numerical File's 1906–1910, and the check counts it; inside them it keeps none, and the record differs.
//
// The generator's cores declare eight public names FRUSCoreKit declares too, CentralFilesIndex,
// CollectionAuthorityIndex, CountryRoll, LotFileEntry, NumericalFileIndex, NumericalFileRoll,
// SourceProvenanceIndex and VolumeSourcesIndex, and two the kit keeps internal: this file imports no FRUSCoreKit,
// and reads the API's JSON with its own types, as any client reads it.

import CentralFilesIndexGeneratorCore
import CollectionAuthorityGeneratorCore
import Foundation
import SourceExplorerExportGeneratorCore
import SourceNoteKit
import VolumeSourcesIndexGeneratorCore

public enum SourceExplorerCheck {

    /// A source note as the generator reads it from a volume.
    public struct Note: Sendable, Equatable {
        public let volumeId: String
        public let documentId: String
        public let note: String
        public let year: Int?
    }

    /// Every document's source note in `volumes`, read from their TEI in `directory` as the generator's run reads
    /// them, in each volume's order.
    public static func notes(teiDirectory directory: URL, volumes: [String]) throws -> [Note] {
        var notes: [Note] = []
        for volumeId in volumes {
            let data = try Data(contentsOf: directory.appendingPathComponent("\(volumeId).xml"))
            let years = DocumentYearExtractor.extract(fromXML: data)
            for note in DocumentNoteExtractor.extract(fromXML: data) {
                notes.append(Note(volumeId: volumeId, documentId: note.documentId, note: note.note,
                                  year: note.documentId.isEmpty ? nil : years[note.documentId]))
            }
        }
        return notes
    }

    /// The fields of the API's answer the check reads.
    public struct Answer: Decodable, Sendable {
        public let volumeId: String
        public let documentId: String
        public let rawSourceNote: String
        public let dateline: String?
        public let year: Int?
        public let parsed: Parsed
        public let keys: Keys
        public let offline: Offline

        public struct Parsed: Decodable, Sendable {
            public let kind: String
            public let fields: [String: String]
        }

        public struct Keys: Decodable, Sendable {
            public let supportsArchivalNeighbors: Bool
            public let archivalNeighborKey: String?
            public let lotFileNorm: String?
            public let decimalClass: String?
            public let noteMarking: String?
        }

        public struct Offline: Decodable, Sendable {
            public let lotBundle: Resolution?
            public let numericalFileRolls: [Resolution]?
            public let numericalFileCoverageGap: Bool?
            public let collectionAuthority: Authority?
        }

        public struct Resolution: Decodable, Sendable {
            public let naId: String
            public let catalogURL: String
            public let title: String
            public let recordGroup: String?
            public let matchType: String?
            public let hmsMlrEntryNumbers: [String]?
            public let levelOfDescription: String?
            public let seriesNaId: String?
            public let seriesTitle: String?
            public let seriesHmsMlrEntryNumbers: [String]?
        }

        public struct Authority: Decodable, Sendable {
            public let id: String
            public let name: String
            public let naId: String?
            public let catalogURL: String?
        }
    }

    /// The generator's inputs, the bundled files in `resources`, read as its run reads them. Unchecked: the
    /// grammar's parser is not `Sendable`, and the check uses a comparator from one task at a time, as the
    /// generator's run uses its parser.
    public struct Comparator: @unchecked Sendable {
        let parser = SourceNoteParser()
        let lotResolver: BundledLotResolver
        let centralFiles: CentralFilesIndexGeneratorCore.CentralFilesIndex
        let volumeSources: VolumeSourcesIndexGeneratorCore.VolumeSourcesIndex
        let authority: AuthorityLookup

        public init(resources: URL) throws {
            let central = resources.appendingPathComponent("central-files-index.json")
            lotResolver = try BundledLotResolver(indexURL: central)
            centralFiles = try JSONDecoder().decode(CentralFilesIndexGeneratorCore.CentralFilesIndex.self,
                                                    from: Data(contentsOf: central))
            volumeSources = try JSONDecoder().decode(
                VolumeSourcesIndexGeneratorCore.VolumeSourcesIndex.self,
                from: Data(contentsOf: resources.appendingPathComponent("volume-sources-index.json")))
            authority = try AuthorityLookup(indexURL: resources.appendingPathComponent("collection-authority.json"))
        }

        /// The generator's record for a note and year.
        public func record(volumeId: String, documentId: String, note: String, year: Int?) -> SourceExplorerExportRecord {
            SourceExplorerExportRunner.exportRecord(
                volumeId: volumeId, documentId: documentId, rawNote: note, documentYear: year, parser: parser,
                lotResolver: lotResolver, centralFiles: centralFiles, volumeSources: volumeSources, authority: authority)
        }

        /// The generator's record for the note the API answered with, each resolution the API made in place of the
        /// generator's own, and the outcome by the generator's precedence over them; and whether the year was the
        /// export's, for a dateline that gives none (the file's second rule). `exportYear` is the generator's year for
        /// the document, from its TEI.
        public func record(from answer: Answer, exportYear: Int?) -> (record: SourceExplorerExportRecord, undated: Bool) {
            // The year rule: the export's year, only where the dateline gives none and the year resolves nothing.
            var year = answer.year
            var undated = false
            if year == nil, let exportYear, !(1906...1910).contains(exportYear), !Self.namesYear(answer.dateline) {
                year = exportYear
                undated = true
            }
            let base = record(volumeId: answer.volumeId, documentId: answer.documentId, note: answer.rawSourceNote,
                              year: year)
            // The lot rule: the bundle's series, matched by the bundled lot-file index, as the export records it.
            let lotBundle = answer.offline.lotBundle.map {
                ResolvedNAID(naId: $0.naId, catalogURL: $0.catalogURL, title: $0.title, recordGroup: $0.recordGroup,
                             matchType: "lot", hmsMlrEntryNumbers: $0.hmsMlrEntryNumbers,
                             levelOfDescription: $0.levelOfDescription, seriesNaId: $0.seriesNaId,
                             seriesTitle: $0.seriesTitle, seriesHmsMlrEntryNumbers: $0.seriesHmsMlrEntryNumbers)
            }
            // Why a lot the note cites missed the bundle, the generator's rule over the API's answer: a lot the bundle
            // holds but flags, or one it does not hold.
            var lotBundleMiss: String?
            if lotBundle == nil, let rawLot = ExportClassification.rawLot(of: parser.parse(answer.rawSourceNote)) {
                lotBundleMiss = centralFiles.lotFile(normalized: BundledLotResolver.normalizeLot(rawLot))?.ancestryLacksRecordGroup == true
                    ? "flaggedAncestryLacksRecordGroup" : "notInBundle"
            }
            let rolls = answer.offline.numericalFileRolls.map {
                $0.map { NumericalRollRef(naId: $0.naId, title: $0.title, catalogURL: $0.catalogURL) }
            }
            let authority = answer.offline.collectionAuthority.map {
                AuthorityRef(id: $0.id, name: $0.name, naId: $0.naId, catalogURL: $0.catalogURL)
            }
            let resolution = ResolutionResults(
                liveLookupRoute: base.resolution.liveLookupRoute, lotBundle: lotBundle, lotBundleMiss: lotBundleMiss,
                numericalFileRolls: rolls, numericalFileCoverageGap: answer.offline.numericalFileCoverageGap,
                volumeSources: base.resolution.volumeSources, volumeSourcesKey: base.resolution.volumeSourcesKey,
                collectionAuthority: authority)
            let record = SourceExplorerExportRecord(
                id: "\(answer.volumeId)/\(answer.documentId)", rawNote: answer.rawSourceNote, documentYear: year,
                parsed: ParsedNoteDescription(kind: answer.parsed.kind, fields: answer.parsed.fields),
                strategy: base.strategy,
                derived: DerivedKeys(supportsArchivalNeighbors: answer.keys.supportsArchivalNeighbors,
                                     archivalNeighborKey: answer.keys.archivalNeighborKey,
                                     lotFileNorm: answer.keys.lotFileNorm, decimalClass: answer.keys.decimalClass,
                                     classificationMarking: answer.keys.noteMarking),
                resolution: resolution, offlineOutcome: Self.outcome(resolution).rawValue)
            return (record, undated)
        }

        /// Whether a dateline names a year, by the pattern the app's rule falls back to, so that the year rule
        /// applies only to a dateline that gives none.
        static func namesYear(_ dateline: String?) -> Bool {
            guard let dateline else { return false }
            return dateline.range(of: #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#, options: .regularExpression) != nil
        }

        /// The record's outcome, the generator's precedence (`exportRecord`'s, which it keeps private): the strongest
        /// offline resolution the record holds.
        static func outcome(_ resolution: ResolutionResults) -> OfflineOutcome {
            if resolution.lotBundle != nil { return .resolvedLotBundle }
            if resolution.numericalFileRolls?.isEmpty == false { return .resolvedNumericalFile }
            if resolution.volumeSources != nil { return .resolvedVolumeSources }
            if resolution.collectionAuthority?.naId != nil { return .resolvedAuthorityOnly }
            if resolution.liveLookupRoute != "noCatalogRoute" { return .liveRouteOnly }
            return .noResolution
        }
    }

    /// What the check found.
    public struct Result: Sendable {
        /// The notes the generator read, and those of documents with no `xml:id`, which no address names.
        public var notes = 0
        public var withoutId = 0
        /// The notes whose records are equal.
        public var identical = 0
        /// Of those, the documents whose datelines give no year, which the export dates from their TEI, by key.
        public var undatedByDateline: [String] = []
        /// Each note whose records differ, or whose answer the API refused, with what differs.
        public var differences: [String] = []
        /// The records by strategy and by outcome, for the summary line.
        public var byStrategy: [String: Int] = [:]
        public var byOutcome: [String: Int] = [:]

        public var passes: Bool { differences.isEmpty && identical == notes - withoutId && identical > 0 }

        /// The summary: how many notes of how many volumes, and the strategies and outcomes they took.
        public func summary(volumes: Int) -> String {
            let strategies = byStrategy.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            let outcomes = byOutcome.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            if passes {
                return "check 8 passes: \(identical) source notes of \(volumes) volumes, every record the export generator's; "
                    + "strategies: \(strategies); outcomes: \(outcomes)"
                    + (undatedByDateline.isEmpty ? "" : "; \(undatedByDateline.count) of them dated by the export from frus:doc-dateTime-min, their datelines giving no year")
                    + (withoutId > 0 ? "; \(withoutId) notes of documents with no id, which no address names" : "")
            }
            return "check 8 fails: \(identical) of \(notes - withoutId) source notes identical, \(differences.count) differ"
        }
    }

    /// Resolves each note through the API with `get`, which fetches a path from the server, and holds each record to
    /// the generator's.
    public static func run(notes: [Note], comparator: Comparator,
                           get: (String) async throws -> (status: Int, body: Data)) async -> Result {
        var result = Result()
        result.notes = notes.count
        for note in notes {
            guard !note.documentId.isEmpty else {
                result.withoutId += 1
                continue
            }
            let expected = comparator.record(volumeId: note.volumeId, documentId: note.documentId, note: note.note,
                                             year: note.year)
            let key = "\(note.volumeId)/\(note.documentId)"
            let answer: Answer
            do {
                let path = "/api/v1/volumes/\(segment(note.volumeId))/documents/\(segment(note.documentId))/sources"
                let response = try await get(path)
                guard response.status == 200 else {
                    result.differences.append("\(key): \(response.status) \(String(decoding: response.body.prefix(300), as: UTF8.self))")
                    continue
                }
                answer = try JSONDecoder().decode(Answer.self, from: response.body)
            } catch {
                result.differences.append("\(key): \(error)")
                continue
            }
            let (actual, undated) = comparator.record(from: answer, exportYear: note.year)
            if actual == expected {
                result.identical += 1
                if undated { result.undatedByDateline.append(key) }
                result.byStrategy[actual.strategy, default: 0] += 1
                result.byOutcome[actual.offlineOutcome, default: 0] += 1
            } else {
                result.differences.append("\(key): " + difference(actual, expected))
            }
        }
        return result
    }

    /// Each field of two records that differs, the API's value then the generator's, as JSON.
    public static func difference(_ actual: SourceExplorerExportRecord, _ expected: SourceExplorerExportRecord) -> String {
        func json<T: Encodable>(_ value: T) -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "?"
        }
        var fields: [String] = []
        func compare<T: Encodable & Equatable>(_ name: String, _ a: T, _ b: T) {
            if a != b { fields.append("\(name) is \(json(a)) through the API, \(json(b)) in the export") }
        }
        compare("rawNote", actual.rawNote, expected.rawNote)
        compare("documentYear", actual.documentYear, expected.documentYear)
        compare("parsed", actual.parsed, expected.parsed)
        compare("strategy", actual.strategy, expected.strategy)
        compare("derived", actual.derived, expected.derived)
        compare("liveLookupRoute", actual.resolution.liveLookupRoute, expected.resolution.liveLookupRoute)
        compare("lotBundle", actual.resolution.lotBundle, expected.resolution.lotBundle)
        compare("lotBundleMiss", actual.resolution.lotBundleMiss, expected.resolution.lotBundleMiss)
        compare("numericalFileRolls", actual.resolution.numericalFileRolls, expected.resolution.numericalFileRolls)
        compare("numericalFileCoverageGap", actual.resolution.numericalFileCoverageGap, expected.resolution.numericalFileCoverageGap)
        compare("volumeSources", actual.resolution.volumeSources, expected.resolution.volumeSources)
        compare("collectionAuthority", actual.resolution.collectionAuthority, expected.resolution.collectionAuthority)
        compare("offlineOutcome", actual.offlineOutcome, expected.offlineOutcome)
        return fields.joined(separator: "; ")
    }

    /// A path segment, its reserved characters escaped.
    static func segment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? value
    }
}
