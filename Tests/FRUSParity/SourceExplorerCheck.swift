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
//   entry's own record of how NARA's harvest matched it: the API's must be that entry's, and every other field
//   of the series is compared;
// - the year: the API's is the one both of the app's views read, the dateline's
//   (`CentralFilesClassifier.documentYear(fromDateline:)`, the reader's `extractYear(from:)`), where the export
//   reads `frus:doc-dateTime-min`. Over the fixtures they differ only where a dateline is there and gives no year
//   ("Moscow, undated"), for which the API gives none: such a record takes the export's year when that year
//   resolves nothing, outside the Numerical File's 1906–1910, and the check counts it, which a caller may pin
//   (`--undated`). A document with no dateline gets no year this way.
//
// The API's year is held first to the kit's own reading of the dateline the API returns (`KitViewsYear`), the year
// both of the app's views read: any other year is the server's difference, before any rule below applies.
//
// The full corpus's run settled the rest (PLAN's S25b): across the corpus the two years also differ where a
// dateline gives a year and the document has no attribute, where it has no dateline, or where the attribute's
// instant at −05:00 falls in another year (FRUS-Explorer#1326). Wherever the years differ and the first rule
// does not make the records equal, the API's record is held to the generator's record for the year both of the
// app's views read, the API's: the server shows what the app shows. Each such record is counted by how the
// years differ (`YearDisagreement`), and one whose note the export's own year would resolve otherwise than the
// views' year does is listed, a question of the app's (its export reads another year than its views), never a
// difference of the server's.
//
// The full corpus's run also found a third rule of the export's own (S25b): a 1906–1910 file number in the Decimal
// File's form ("File No. 723.2515/110.") names no Numerical File case to the kit, both of the app's views' reading
// since FRUS-Explorer#722 (for #354), which shows the coverage gap, where the export generator's own core, which
// took no such rule, reads the digits before the point as a case and records that case's rolls. Such a record is
// held to the generator's with the kit's reading of the file number, asked of the kit itself (`KitNumericalFile`):
// no rolls, the gap, and the outcome by the generator's precedence; it is counted and listed, a question of the
// app's (its export lags its views, FRUS-Explorer#1974), never a difference of the server's.
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

        public init(volumeId: String, documentId: String, note: String, year: Int?) {
            self.volumeId = volumeId
            self.documentId = documentId
            self.note = note
            self.year = year
        }
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
        /// The kit's Numerical File, for the third rule: what both of the app's views read from a file number.
        let kit: KitNumericalFile
        /// The kit's reading of a dateline's year, which the API's year is held to first.
        let viewsYear = KitViewsYear()

        public init(resources: URL) throws {
            let central = resources.appendingPathComponent("central-files-index.json")
            lotResolver = try BundledLotResolver(indexURL: central)
            centralFiles = try JSONDecoder().decode(CentralFilesIndexGeneratorCore.CentralFilesIndex.self,
                                                    from: Data(contentsOf: central))
            volumeSources = try JSONDecoder().decode(
                VolumeSourcesIndexGeneratorCore.VolumeSourcesIndex.self,
                from: Data(contentsOf: resources.appendingPathComponent("volume-sources-index.json")))
            authority = try AuthorityLookup(indexURL: resources.appendingPathComponent("collection-authority.json"))
            kit = try KitNumericalFile(resources: resources)
        }

        /// The generator's record for a note and year.
        public func record(volumeId: String, documentId: String, note: String, year: Int?) -> SourceExplorerExportRecord {
            SourceExplorerExportRunner.exportRecord(
                volumeId: volumeId, documentId: documentId, rawNote: note, documentYear: year, parser: parser,
                lotResolver: lotResolver, centralFiles: centralFiles, volumeSources: volumeSources, authority: authority)
        }

        /// The generator's record with the kit's reading of a Decimal File-form file number (the third rule): where the
        /// export's core found a case's rolls for a file number the kit reads no case from, no rolls, the coverage gap
        /// the kit shows, and the outcome by the generator's precedence; and whether that changed the record.
        func readByTheKit(_ record: SourceExplorerExportRecord) -> (record: SourceExplorerExportRecord, changed: Bool) {
            let resolution = record.resolution
            guard let rolls = resolution.numericalFileRolls, record.parsed.kind == "centralFiles",
                  let file = record.parsed.fields["fileIdentifier"],
                  kit.refusesDecimalForm(file, whereTheCaseFinds: rolls.map(\.naId)) else { return (record, false) }
            let read = ResolutionResults(
                liveLookupRoute: resolution.liveLookupRoute, lotBundle: resolution.lotBundle, lotBundleMiss: resolution.lotBundleMiss,
                numericalFileRolls: nil, numericalFileCoverageGap: true, volumeSources: resolution.volumeSources,
                volumeSourcesKey: resolution.volumeSourcesKey, collectionAuthority: resolution.collectionAuthority)
            return (SourceExplorerExportRecord(id: record.id, rawNote: record.rawNote, documentYear: record.documentYear,
                                               parsed: record.parsed, strategy: record.strategy, derived: record.derived,
                                               resolution: read, offlineOutcome: Self.outcome(read).rawValue), true)
        }

        /// The generator's record for the note the API answered with, each resolution the API made in place of the
        /// generator's own, and the outcome by the generator's precedence over them; and whether the year was the
        /// export's, for a dateline that gives none (the file's second rule). `exportYear` is the generator's year for
        /// the document, from its TEI.
        public func record(from answer: Answer, exportYear: Int?) -> (record: SourceExplorerExportRecord, undated: Bool) {
            // The year rule: the export's year, only where a dateline is there and gives none, and the year resolves
            // nothing.
            var year = answer.year
            var undated = false
            if year == nil, let exportYear, !(1906...1910).contains(exportYear), let dateline = answer.dateline,
               !dateline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !Self.namesYear(dateline) {
                year = exportYear
                undated = true
            }
            let base = record(volumeId: answer.volumeId, documentId: answer.documentId, note: answer.rawSourceNote,
                              year: year)
            // The bundle's entry for the lot the note cites, as the generator's cores read it.
            let rawLot = ExportClassification.rawLot(of: parser.parse(answer.rawSourceNote))
            let bundled = rawLot.flatMap { centralFiles.lotFile(normalized: BundledLotResolver.normalizeLot($0)) }
            // The lot rule: the bundle's series, matched by the bundled lot-file index, as the export records it, where
            // the API's record of the match is the bundle entry's own; any other stands, and the record differs.
            let lotBundle = answer.offline.lotBundle.map {
                ResolvedNAID(naId: $0.naId, catalogURL: $0.catalogURL, title: $0.title, recordGroup: $0.recordGroup,
                             matchType: $0.matchType != nil && $0.matchType == bundled?.matchType ? "lot" : $0.matchType ?? "",
                             hmsMlrEntryNumbers: $0.hmsMlrEntryNumbers,
                             levelOfDescription: $0.levelOfDescription, seriesNaId: $0.seriesNaId,
                             seriesTitle: $0.seriesTitle, seriesHmsMlrEntryNumbers: $0.seriesHmsMlrEntryNumbers)
            }
            // Why a lot the note cites missed the bundle, the generator's rule over the API's answer: a lot the bundle
            // holds but flags, or one it does not hold.
            var lotBundleMiss: String?
            if lotBundle == nil, rawLot != nil {
                lotBundleMiss = bundled?.ancestryLacksRecordGroup == true ? "flaggedAncestryLacksRecordGroup" : "notInBundle"
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
        static func namesYear(_ dateline: String) -> Bool {
            dateline.range(of: #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#, options: .regularExpression) != nil
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

        /// What one note's answer gives against the generator's record: the export's own record, or the
        /// generator's for the views' year where the two years differ, or a difference.
        func compare(note: Note, response: Swift.Result<(status: Int, body: Data), any Error>) async -> Finding {
            let key = "\(note.volumeId)/\(note.documentId)"
            let (expected, decimalForm) = readByTheKit(record(volumeId: note.volumeId, documentId: note.documentId, note: note.note, year: note.year))
            let answer: Answer
            switch response {
            case .failure(let error):
                return .differs("\(key): \(error)")
            case .success(let (status, body)):
                guard status == 200 else { return .differs("\(key): \(status) \(String(decoding: body.prefix(300), as: UTF8.self))") }
                do {
                    answer = try JSONDecoder().decode(Answer.self, from: body)
                } catch {
                    return .differs("\(key): \(error)")
                }
            }
            // The views' year is the API's own word, so it is held first to the kit's own reading of the dateline the
            // API returned (`KitViewsYear`): any other year is the server's difference, whatever the export reads.
            let kitYear = await viewsYear.year(dateline: answer.dateline)
            guard kitYear == answer.year else {
                let dateline = answer.dateline.map { "\"\($0)\"" } ?? "none"
                return .differs("\(key): the API gives the year \(answer.year.map(String.init) ?? "none") for the dateline \(dateline), "
                                + "where the views' rule, the kit's, reads \(kitYear.map(String.init) ?? "none")")
            }
            let (actual, undated) = record(from: answer, exportYear: note.year)
            if actual == expected { return .identical(actual, undated: undated, decimalForm: decimalForm) }
            guard answer.year != note.year else { return .differs("\(key): " + SourceExplorerCheck.difference(actual, expected)) }
            // The years differ: the API's record for the views' year, against the generator's for it.
            let (atViewsYear, _) = record(from: answer, exportYear: nil)
            let (generated, generatedDecimalForm) = readByTheKit(record(volumeId: note.volumeId, documentId: note.documentId, note: note.note, year: answer.year))
            guard atViewsYear == generated else { return .differs("\(key): " + SourceExplorerCheck.difference(atViewsYear, generated)) }
            let kind: YearDisagreement.Kind
            switch (answer.year, note.year) {
            case (nil, _):
                let dateline = answer.dateline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                kind = dateline.isEmpty ? .noDateline : .datelineGivesNoYear
            case (_, nil): kind = .noExportYear
            default: kind = .anotherYear
            }
            // What the export's own year resolves otherwise than the views' year, the year itself apart.
            let otherwise = SourceExplorerCheck.differingFields(expected, generated.withYear(note.year)).map(\.name)
            return .identicalAtViewsYear(atViewsYear, YearDisagreement(key: key, kind: kind, viewsYear: answer.year,
                                                                       exportYear: note.year, resolvesOtherwise: otherwise),
                                         decimalForm: decimalForm || generatedDecimalForm)
        }
    }

    /// What one note's comparison found.
    public enum Finding: Sendable, Equatable {
        /// The generator's own record, with whether the first year rule dated it and the third rule read its file number.
        case identical(SourceExplorerExportRecord, undated: Bool, decimalForm: Bool)
        /// The generator's record for the views' year, where the export reads another, with whether the third rule read
        /// its file number.
        case identicalAtViewsYear(SourceExplorerExportRecord, YearDisagreement, decimalForm: Bool)
        /// What differs, or why the answer could not be read.
        case differs(String)
    }

    /// A record whose year the API, as both of the app's views, reads otherwise than the export, held to the
    /// generator's record for the views' year.
    public struct YearDisagreement: Codable, Sendable, Equatable {
        public enum Kind: String, Codable, Sendable, CaseIterable {
            /// The document has a dateline that names no year ("undated"), and an attribute.
            case datelineGivesNoYear
            /// The document has no dateline, and an attribute.
            case noDateline
            /// The dateline names a year, and the document has no attribute.
            case noExportYear
            /// The dateline's year and the attribute's differ.
            case anotherYear
        }

        public let key: String
        public let kind: Kind
        public let viewsYear: Int?
        public let exportYear: Int?
        /// The fields of the export's own record that its year makes other than the views' year makes them, the
        /// year apart: empty where the year resolves nothing.
        public let resolvesOtherwise: [String]

        public init(key: String, kind: Kind, viewsYear: Int?, exportYear: Int?, resolvesOtherwise: [String]) {
            self.key = key
            self.kind = kind
            self.viewsYear = viewsYear
            self.exportYear = exportYear
            self.resolvesOtherwise = resolvesOtherwise
        }
    }

    /// What the check found.
    public struct Result: Sendable, Codable, Equatable {
        /// The notes the generator read, and those of documents with no `xml:id`, which no address names.
        public var notes = 0
        public var withoutId = 0
        /// The notes whose records are the export's own.
        public var identical = 0
        /// Of those, the documents whose datelines give no year, which the export dates from their TEI, by key.
        public var undatedByDateline: [String] = []
        /// The notes whose records are the generator's for the year both of the app's views read, where the
        /// export reads another, each with how the years differ and what the export's year resolves otherwise.
        public var yearDisagreements: [YearDisagreement] = []
        /// The notes held with the kit's reading of a Decimal File-form file number, where the export's core reads a
        /// Numerical File case from it (the third rule), by key: the app's question, its export lagging its views.
        public var decimalFormFiles: [String] = []
        /// Each note whose records differ, or whose answer the API refused, with what differs.
        public var differences: [String] = []
        /// The records by strategy and by outcome, for the summary line.
        public var byStrategy: [String: Int] = [:]
        public var byOutcome: [String: Int] = [:]

        public init() {}

        public var passes: Bool {
            let held = identical + yearDisagreements.count
            return differences.isEmpty && held == notes - withoutId && held > 0
        }

        /// The year disagreements whose note the export's own year resolves otherwise: the app's question.
        public var exportYearQuestions: [YearDisagreement] { yearDisagreements.filter { !$0.resolvesOtherwise.isEmpty } }

        /// Takes one note's finding.
        mutating func take(_ finding: Finding) {
            switch finding {
            case .identical(let record, let undated, let decimalForm):
                identical += 1
                if undated { undatedByDateline.append(record.id) }
                if decimalForm { decimalFormFiles.append(record.id) }
                byStrategy[record.strategy, default: 0] += 1
                byOutcome[record.offlineOutcome, default: 0] += 1
            case .identicalAtViewsYear(let record, let disagreement, let decimalForm):
                yearDisagreements.append(disagreement)
                if decimalForm { decimalFormFiles.append(record.id) }
                byStrategy[record.strategy, default: 0] += 1
                byOutcome[record.offlineOutcome, default: 0] += 1
            case .differs(let difference):
                differences.append(difference)
            }
        }

        /// The summary: how many notes of how many volumes, and the strategies and outcomes they took.
        public func summary(volumes: Int) -> String {
            let strategies = byStrategy.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            let outcomes = byOutcome.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            if passes {
                var kinds: [String: Int] = [:]
                for disagreement in yearDisagreements { kinds[disagreement.kind.rawValue, default: 0] += 1 }
                let years = yearDisagreements.isEmpty ? "" :
                    "; \(yearDisagreements.count) of them for the year both of the app's views read, where the export reads another ("
                    + kinds.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
                    + "), \(exportYearQuestions.count) of which the export's own year resolves otherwise, a question of the app's"
                return "check 8 passes: \(identical + yearDisagreements.count) source notes of \(volumes) volumes, every record the export generator's; "
                    + "strategies: \(strategies); outcomes: \(outcomes)"
                    + (undatedByDateline.isEmpty ? "" : "; \(undatedByDateline.count) of them dated by the export from frus:doc-dateTime-min, their datelines giving no year")
                    + years
                    + (decimalFormFiles.isEmpty ? "" : "; \(decimalFormFiles.count) of them with the kit's reading of a 1906–1910 file number in the Decimal File's form, which names no Numerical File case to the app's views, where the export's core reads one, a question of the app's")
                    + (withoutId > 0 ? "; \(withoutId) notes of documents with no id, which no address names" : "")
            }
            return "check 8 fails: \(identical + yearDisagreements.count) of \(notes - withoutId) source notes held, \(differences.count) differ"
        }
    }

    /// The API's path for a note's document.
    static func path(_ note: Note) -> String {
        "/api/v1/volumes/\(segment(note.volumeId))/documents/\(segment(note.documentId))/sources"
    }

    /// Resolves each note through the API with `get`, which fetches a path from the server, one at a time, and holds
    /// each record to the generator's.
    public static func run(notes: [Note], comparator: Comparator,
                           get: (String) async throws -> (status: Int, body: Data)) async -> Result {
        var result = Result()
        result.notes = notes.count
        for note in notes {
            guard !note.documentId.isEmpty else {
                result.withoutId += 1
                continue
            }
            let response: Swift.Result<(status: Int, body: Data), any Error>
            do {
                response = .success(try await get(path(note)))
            } catch {
                response = .failure(error)
            }
            result.take(await comparator.compare(note: note, response: response))
        }
        return result
    }

    /// The same, with up to `parallel` answers asked at once, and each held to the generator's in the notes' order on
    /// the calling task, which alone uses the comparator. `progress` hears how many notes are done after each batch.
    public static func run(notes: [Note], comparator: Comparator, parallel: Int,
                           progress: (Int, Result) -> Void = { _, _ in },
                           get: @escaping @Sendable (String) async throws -> (status: Int, body: Data)) async -> Result {
        let width = max(1, parallel)
        var result = Result()
        result.notes = notes.count
        let addressed = notes.filter { !$0.documentId.isEmpty }
        result.withoutId = notes.count - addressed.count
        let batch = width * 64
        var start = 0
        while start < addressed.count {
            let notes = Array(addressed[start..<min(start + batch, addressed.count)])
            let responses = await answers(paths: notes.map { path($0) }, width: width, get: get)
            for (note, response) in zip(notes, responses) {
                result.take(await comparator.compare(note: note, response: response))
            }
            start += notes.count
            progress(start, result)
        }
        return result
    }

    /// What `get` answered for each path, in the paths' order, with at most `width` asked at once.
    ///
    /// Each child of the task group gives its answer as a `Heard`, a struct. The first form (S25b) gave the tuple
    /// `(Int, Swift.Result<(status: Int, body: Data), any Error>)`, whose index the debug build read back right and the
    /// release build the parity image runs read back as garbage (7359508660462642541 among indices 0 to 5), so that the
    /// force-unwrap of an answer trapped with no message (check 8 in CI's Compose smoke test). The same two fields in a
    /// struct read back right in both builds, as an `(Int, Int)` tuple does, measured in the release build itself. An
    /// index out of range, or a path whose answer was not kept, is a failure the check reports, never a trap.
    public static func answers(paths: [String], width: Int,
                               get: @escaping @Sendable (String) async throws -> (status: Int, body: Data)) async
        -> [Swift.Result<(status: Int, body: Data), any Error>] {
        let width = max(1, width)
        let kept = await withTaskGroup(of: Heard.self, returning: [Swift.Result<(status: Int, body: Data), any Error>?].self) { group in
            var kept = [Swift.Result<(status: Int, body: Data), any Error>?](repeating: nil, count: paths.count)
            for (index, path) in paths.enumerated() {
                // `width` are asked already: the next is asked once one of them is answered.
                if index >= width, let heard = await group.next(), kept.indices.contains(heard.index) {
                    kept[heard.index] = heard.response
                }
                group.addTask {
                    do {
                        return Heard(index: index, response: .success(try await get(path)))
                    } catch {
                        return Heard(index: index, response: .failure(error))
                    }
                }
            }
            while let heard = await group.next() {
                if kept.indices.contains(heard.index) { kept[heard.index] = heard.response }
            }
            return kept
        }
        return zip(paths, kept).map { path, answer in answer ?? .failure(Unanswered(path: path)) }
    }

    /// One path's answer, by the path's place: what a child of `answers`' task group gives.
    struct Heard: Sendable {
        let index: Int
        let response: Swift.Result<(status: Int, body: Data), any Error>
    }

    /// A path asked whose answer was not kept.
    struct Unanswered: Error, CustomStringConvertible {
        let path: String
        var description: String { "\(path) was asked, and no answer was kept" }
    }

    /// Each field of two records that differs, by name, with its value in each as JSON.
    public static func differingFields(_ actual: SourceExplorerExportRecord, _ expected: SourceExplorerExportRecord)
        -> [(name: String, actual: String, expected: String)] {
        func json<T: Encodable>(_ value: T) -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "?"
        }
        var fields: [(name: String, actual: String, expected: String)] = []
        func compare<T: Encodable & Equatable>(_ name: String, _ a: T, _ b: T) {
            if a != b { fields.append((name, json(a), json(b))) }
        }
        compare("id", actual.id, expected.id)
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
        compare("volumeSourcesKey", actual.resolution.volumeSourcesKey, expected.resolution.volumeSourcesKey)
        compare("collectionAuthority", actual.resolution.collectionAuthority, expected.resolution.collectionAuthority)
        compare("offlineOutcome", actual.offlineOutcome, expected.offlineOutcome)
        // A field the list does not name: both records, whole.
        if fields.isEmpty, actual != expected { fields.append(("record", json(actual), json(expected))) }
        return fields
    }

    /// Each field of two records that differs, the API's value then the generator's, as JSON.
    public static func difference(_ actual: SourceExplorerExportRecord, _ expected: SourceExplorerExportRecord) -> String {
        let fields = differingFields(actual, expected)
        if fields.count == 1, fields[0].name == "record" {
            return "the records differ: \(fields[0].actual) through the API, \(fields[0].expected) in the export"
        }
        return fields.map { "\($0.name) is \($0.actual) through the API, \($0.expected) in the export" }.joined(separator: "; ")
    }

    /// A path segment, its reserved characters escaped.
    static func segment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? value
    }
}

extension SourceExplorerExportRecord {
    /// The record with another year, every other field as it is: for asking what a year changes.
    func withYear(_ year: Int?) -> SourceExplorerExportRecord {
        SourceExplorerExportRecord(id: id, rawNote: rawNote, documentYear: year, parsed: parsed, strategy: strategy,
                                   derived: derived, resolution: resolution, offlineOutcome: offlineOutcome)
    }
}
