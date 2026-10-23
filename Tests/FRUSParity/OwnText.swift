// A section's own text (joshbotts/FRUS-Explorer#1536): the row the index holds for the text a
// section prints outside the documents and sections it holds, which the app's Browse lists first in
// the section. Which row it is, is the kit's `VolumeSection.ownTextEntry(among:)`. This holds what a
// server answers for every section, through its API, to that rule over the same index: in
// FRUSParityTests over the kit's own fixture volumes for those rows, and from `frus-parity own-text`
// over an install's export.

import FRUSCoreKit
import FTS5Store
import Foundation
import ParityFormat

/// The kit's fixture volumes for a section's own text, which no volume in `fixtures/tei` has: each
/// is a FRUSCoreKit suite's `volumeXML`, copied into `fixtures/own-text` (its README says more).
public enum OwnTextFixtures {
    public struct Volume: Sendable {
        public let id: String
        /// The kit's suite that declares it.
        public let suite: String
    }

    public static let volumes = [
        Volume(id: "frus1969-76v01", suite: "SectionOwnTextTests"),
        Volume(id: "frus1945-50Intel", suite: "IndexVersion70Tests"),
    ]

    /// Their folder, from the repository root.
    public static let path = "fixtures/own-text"
    /// The kit's test file that declares them, from the submodule's root.
    public static let sourcePath = "FRUSExplorerTests/FRUSCoreKit/IndexingPipelineTests.swift"

    public static func folder(_ layout: RepositoryLayout) -> URL {
        layout.root.appendingPathComponent(path, isDirectory: true)
    }

    /// The text of `suite`'s `static let volumeXML`, as Swift reads the multi-line literal in
    /// `source`: the lines between its delimiters, less the closing delimiter's indentation. Throws
    /// when the suite declares no such literal, or one Swift would read otherwise than its lines:
    /// one with a backslash, which begins an escape or an interpolation, or a line indented less
    /// than its delimiter.
    public static func literal(of suite: String, in source: String) throws -> String {
        let lines = source.components(separatedBy: "\n")
        guard let declaration = lines.firstIndex(where: { $0.hasPrefix("struct \(suite) {") }),
              let opening = lines[declaration...].firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "static let volumeXML = \"\"\""
              }),
              let closing = lines[(opening + 1)...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "\"\"\"" })
        else { throw IndexBuildError("\(suite) declares no volumeXML literal in \(sourcePath)") }
        let indent = String(lines[closing].prefix { $0 == " " })
        var text: [String] = []
        for line in lines[(opening + 1)..<closing] {
            if line.contains("\\") { throw IndexBuildError("\(suite)'s volumeXML holds a backslash, which Swift reads as an escape") }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                text.append("")
            } else if line.hasPrefix(indent) {
                text.append(String(line.dropFirst(indent.count)))
            } else {
                throw IndexBuildError("\(suite)'s volumeXML has a line indented less than its closing delimiter")
            }
        }
        return text.joined(separator: "\n")
    }

    /// The volume id `suite` indexes its fixture under: its first `static let volumeId`.
    public static func volumeId(of suite: String, in source: String) throws -> String {
        let lines = source.components(separatedBy: "\n")
        let prefix = "static let volumeId = \""
        guard let declaration = lines.firstIndex(where: { $0.hasPrefix("struct \(suite) {") }),
              let line = lines[declaration...].first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }),
              let id = line.trimmingCharacters(in: .whitespaces).dropFirst(prefix.count).split(separator: "\"").first
        else { throw IndexBuildError("\(suite) declares no volumeId in \(sourcePath)") }
        return String(id)
    }
}

/// The kit's side of the check: an index's rows and outline for a volume, read through the kit.
public struct OwnTextVolume: Sendable {
    public let volumeId: String
    /// The outline the index stores (`cachedVolumeStructure(forVolumeId:)`).
    public let sections: [VolumeSection]
    /// The index's rows for the volume, in the kit's order (`documents(forVolume:)`), among which
    /// the app's Browse finds a section's own text.
    public let rows: [DocumentBrowserEntry]
    /// The volume's reading order (`readingSequence(forVolume:)`), whose neighbours the reader shows.
    public let readingOrder: [String]

    public init(_ volumeId: String, pipeline: IndexingPipeline) async throws {
        self.volumeId = volumeId
        sections = try await pipeline.cachedVolumeStructure(forVolumeId: volumeId)?.sections ?? []
        rows = try await pipeline.documents(forVolume: volumeId)
        readingOrder = try await pipeline.readingSequence(forVolume: volumeId).map(\.documentId)
    }
}

/// Holds what a server's API answers for each section's own text to the kit's rule. It reads the
/// API's JSON as a client does, by the field names SPEC gives, so it serves a server it did not
/// build too.
public enum OwnTextCheck {
    /// What one run found.
    public struct Report: Sendable {
        public var volumes = 0
        public var sections = 0
        /// Sections whose page was read.
        public var pages = 0
        /// Sections that can have a row of their own text by the kit's rule (`ownTextRowId`): they
        /// hold a document or a section, and have an id of their own.
        public var candidates = 0
        /// The rows the index holds for them, by what the section holds.
        public var rowsInSectionsWithDocuments = 0
        public var rowsInSectionsWithOnlySections = 0
        /// Rows whose section is a front-matter kind.
        public var frontMatterRows = 0
        /// Rows the API says the reader can open, cannot open, or does not say (no TEI).
        public var readableRows = 0
        public var unreadableRows = 0
        public var rowsWithoutTEI = 0
        /// Rows whose reader's neighbours were read.
        public var neighboursRead = 0
        /// Section ids that repeat within a volume, whose second page could not be asked for.
        public var repeatedIds = 0
        /// Each difference, named by its volume and section.
        public var mismatches: [String] = []

        public init() {}

        public var rows: Int { rowsInSectionsWithDocuments + rowsInSectionsWithOnlySections }

        public var summary: String {
            func n(_ value: Int) -> String { value.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US"))) }
            var text = "\(n(volumes)) volumes, \(n(sections)) sections, \(n(pages)) pages read; "
            text += "\(n(candidates)) sections that can have a row of their own text, \(n(rows)) that have one "
            text += "(\(n(rowsInSectionsWithDocuments)) holding documents, \(n(rowsInSectionsWithOnlySections)) holding only sections, "
            text += "\(n(frontMatterRows)) of front-matter kinds); the reader opens \(n(readableRows)), "
            text += "\(n(unreadableRows)) not, \(n(rowsWithoutTEI)) without TEI; \(n(neighboursRead)) rows' neighbours read"
            if repeatedIds > 0 { text += "; \(n(repeatedIds)) repeated section ids" }
            return text + "; \(n(mismatches.count)) differences"
        }
    }

    /// What the reader's API is asked.
    public enum Neighbours: Sendable {
        /// Each row's neighbours, against the kit's reading order.
        case each
        case none
    }

    struct SectionAnswer: Decodable {
        let sectionId: String
        let hasOwnText: Bool
        let subsections: [SectionAnswer]
    }

    struct VolumeAnswer: Decodable {
        let structure: [SectionAnswer]?
        let structureSource: String?
    }

    struct RowAnswer: Decodable, Equatable, CustomStringConvertible {
        let documentId: String
        let header: String
        let displayTitle: String
        let documentNumber: String?
        let dateline: String?
        let isEditorialNote: Bool
        let inIndex: Bool
        let readable: Bool?

        var description: String {
            "\(documentId) \"\(header)\" as \"\(displayTitle)\", number \(documentNumber ?? "none"), dateline \(dateline ?? "none"), "
                + "editorial note \(isEditorialNote), in the index \(inIndex), readable \(readable.map(String.init) ?? "unsaid")"
        }
    }

    struct PageAnswer: Decodable {
        let section: SectionAnswer
        let ownText: RowAnswer?
    }

    struct DocumentAnswer: Decodable {
        struct Neighbour: Decodable { let documentId: String }
        let previous: Neighbour?
        let next: Neighbour?
    }

    /// Checks one volume against the kit: its outline as the API gives it is the index's; each
    /// section's `hasOwnText` is the kit's rule over the index's rows; each section's page names
    /// the row the rule finds, as the server writes a row, or none; and, with `neighbours`, each
    /// row opens in the reader between the entries the kit's reading order puts around it.
    /// `readable` says whether the reader can open a row, when the caller knows, as a parse of the
    /// volume's TEI by the kit says.
    public static func check(_ volume: OwnTextVolume, readable: Set<String>? = nil, neighbours: Neighbours = .each,
                             get: (String) async throws -> LiveAPI.Response, into report: inout Report) async throws {
        let v = volume.volumeId
        report.volumes += 1
        func fail(_ text: String) { report.mismatches.append("\(v): \(text)") }

        let answer = try decode(VolumeAnswer.self, try await get("/api/v1/volumes/\(v)"), path: "/api/v1/volumes/\(v)")
        if answer.structureSource != "index" { fail("the outline came from \(answer.structureSource ?? "nowhere"), not the index") }
        var answered: [String: Bool] = [:]
        var answeredOrder: [String] = []
        func walk(_ sections: [SectionAnswer]) {
            for section in sections {
                answeredOrder.append(section.sectionId)
                if answered[section.sectionId] == nil { answered[section.sectionId] = section.hasOwnText }
                walk(section.subsections)
            }
        }
        walk(answer.structure ?? [])

        var expectedOrder: [String] = []
        var flat: [VolumeSection] = []
        func flatten(_ sections: [VolumeSection]) {
            for section in sections {
                expectedOrder.append(section.sectionId)
                flat.append(section)
                flatten(section.subsections)
            }
        }
        flatten(volume.sections)
        if answeredOrder != expectedOrder {
            fail("the outline's \(answeredOrder.count) sections are not the index's \(expectedOrder.count)")
            return
        }

        var seen = Set<String>()
        for section in flat {
            report.sections += 1
            let id = section.sectionId
            let expected = section.ownTextEntry(among: volume.rows)
            if section.ownTextRowId != nil { report.candidates += 1 }
            if expected != nil {
                if section.documentIds.isEmpty { report.rowsInSectionsWithOnlySections += 1 } else { report.rowsInSectionsWithDocuments += 1 }
                if section.isFrontMatterKind { report.frontMatterRows += 1 }
            }
            guard seen.insert(id).inserted else {
                report.repeatedIds += 1
                continue
            }
            if answered[id] != (expected != nil) {
                fail("\(id) says hasOwnText \(answered[id].map(String.init) ?? "nothing"), the kit's rule \(expected != nil)")
            }
            let path = "/api/v1/volumes/\(v)/sections/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)"
            let page = try decode(PageAnswer.self, try await get(path), path: path)
            report.pages += 1
            if page.section.hasOwnText != (expected != nil) {
                fail("\(id)'s page says hasOwnText \(page.section.hasOwnText), the kit's rule \(expected != nil)")
            }
            // The row as the server writes one of a section's documents, the title by the kit's rule
            // for lists; whether the reader can open it is held to the kit's parse below.
            let row = expected.map { entry in
                RowAnswer(documentId: entry.documentId, header: entry.header,
                          displayTitle: DocumentDisplayTitle.text(
                              .init(header: entry.header.isEmpty ? nil : entry.header, documentNumber: entry.documentNumber,
                                    isEditorialNote: entry.isEditorialNote),
                              documentId: entry.documentId),
                          documentNumber: entry.documentNumber, dateline: entry.dateline,
                          isEditorialNote: entry.isEditorialNote, inIndex: true,
                          readable: page.ownText?.readable)
            }
            if page.ownText != row {
                fail("\(id)'s page lists \(page.ownText.map(\.description) ?? "no row of its own text"), the kit's rule \(row.map(\.description) ?? "none")")
            }
            guard let row else { continue }
            switch page.ownText?.readable {
            case true?: report.readableRows += 1
            case false?: report.unreadableRows += 1
            case nil: report.rowsWithoutTEI += 1
            }
            if let readable, page.ownText?.readable != readable.contains(row.documentId) {
                fail("\(id)'s row is readable \(page.ownText?.readable.map(String.init) ?? "unsaid"), the kit's parse \(readable.contains(row.documentId))")
            }
            if case .each = neighbours {
                let path = "/api/v1/volumes/\(v)/documents/\(row.documentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? row.documentId)"
                let document = try decode(DocumentAnswer.self, try await get(path), path: path)
                report.neighboursRead += 1
                let position = volume.readingOrder.firstIndex(of: row.documentId)
                let previous = position.flatMap { $0 > 0 ? volume.readingOrder[$0 - 1] : nil }
                let next = position.flatMap { $0 + 1 < volume.readingOrder.count ? volume.readingOrder[$0 + 1] : nil }
                if position == nil { fail("\(row.documentId) is not in the kit's reading order") }
                if document.previous?.documentId != previous || document.next?.documentId != next {
                    fail("\(row.documentId) opens between \(document.previous?.documentId ?? "nothing") and \(document.next?.documentId ?? "nothing"), the kit's order between \(previous ?? "nothing") and \(next ?? "nothing")")
                }
            }
        }
    }

    /// The volumes an index holds, by id, from `document_cache`.
    public static func volumes(in database: URL) throws -> [String] {
        try ParityDatabase.immutable(database).strings("SELECT DISTINCT volume_id FROM document_cache ORDER BY volume_id")
    }

    /// The kit's read-only, immutable stack over an index, as the server opens its live index.
    public static func readOnlyPipeline(_ database: URL) throws -> IndexingPipeline {
        let store = try FTS5Store(readingDatabaseAt: database)
        return try IndexingPipeline(readingIndexAt: database, fts5Store: store, resources: .none,
                                    volumesDirectory: database.deletingLastPathComponent())
    }

    static func decode<T: Decodable>(_ type: T.Type, _ response: LiveAPI.Response, path: String) throws -> T {
        guard response.status == 200 else {
            throw LiveAPI.Failure("\(path): \(response.status) \(String(decoding: response.body.prefix(300), as: UTF8.self))")
        }
        return try JSONDecoder().decode(type, from: response.body)
    }
}
