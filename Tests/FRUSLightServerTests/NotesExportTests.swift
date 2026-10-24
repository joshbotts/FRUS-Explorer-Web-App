// GET /api/v1/me/notes/export through the router (PLAN's S15d): every note's file as the kit renders it
// for the Mac's Export Notes as Markdown, byte for byte, with the citation the app's exporter gives,
// the served index's row and the manifest's entry, and none for a document neither holds; in one ZIP,
// which a reader written here, with a CRC-32 of its own, finds whole.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSRichText
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct NotesExportTests {
    /// An entry as an unzip finds it.
    struct ReadEntry: Equatable {
        var name: String
        var bytes: [UInt8]
        var time: Int
        var date: Int
        /// The modification time of Info-ZIP's extended timestamp, in seconds since 1970, or nil.
        var modified: Int?
    }

    /// The modification time an entry's extra fields give, as Info-ZIP's "UT" field (0x5455)
    /// holds it when its flags' bit 0 is set: a signed 32-bit count of seconds since 1970.
    static func modified(in extra: [UInt8]) -> Int? {
        var at = 0
        while at + 4 <= extra.count {
            let (id, size) = (le16(extra, at), le16(extra, at + 2))
            if id == 0x5455, size >= 5, extra[at + 4] & 1 == 1 { return Int(Int32(bitPattern: le32(extra, at + 5))) }
            at += 4 + size
        }
        return nil
    }

    static func le16(_ zip: [UInt8], _ at: Int) -> Int { Int(zip[at]) | Int(zip[at + 1]) << 8 }

    static func le32(_ zip: [UInt8], _ at: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(zip[at + $1]) << (8 * UInt32($1)) }
    }

    /// CRC-32 bit by bit, not by the writer's table.
    static func crc(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        return ~crc
    }

    /// The entries of a ZIP, read from its end of central directory, each held to its local header
    /// and its CRC; the archive must be nothing but its entries and its directory.
    static func entries(of zip: [UInt8], sourceLocation: SourceLocation = #_sourceLocation) throws -> [ReadEntry] {
        try #require(zip.count >= 22, sourceLocation: sourceLocation)
        let end = zip.count - 22
        try #require(le32(zip, end) == 0x0605_4B50, "the end of central directory, with no comment", sourceLocation: sourceLocation)
        let count = le16(zip, end + 10)
        #expect(le16(zip, end + 8) == count && le16(zip, end + 4) == 0 && le16(zip, end + 6) == 0, sourceLocation: sourceLocation)
        let (size, start) = (Int(le32(zip, end + 12)), Int(le32(zip, end + 16)))
        try #require(start + size == end, sourceLocation: sourceLocation)
        var entries: [ReadEntry] = []
        var at = start
        var local = 0
        for _ in 0..<count {
            try #require(le32(zip, at) == 0x0201_4B50, sourceLocation: sourceLocation)
            let nameLength = le16(zip, at + 28)
            let name = String(decoding: zip[(at + 46)..<(at + 46 + nameLength)], as: UTF8.self)
            let offset = Int(le32(zip, at + 42))
            try #require(offset == local && le32(zip, offset) == 0x0403_4B50, "\(name)'s local header", sourceLocation: sourceLocation)
            #expect(Array(zip[(offset + 4)..<(offset + 30)]) == Array(zip[(at + 6)..<(at + 32)]),
                    "\(name): the local header's fields are the directory's", sourceLocation: sourceLocation)
            #expect(le16(zip, at + 8) & 0x0800 != 0 && le16(zip, at + 10) == 0, "UTF-8 names, stored", sourceLocation: sourceLocation)
            let (compressed, uncompressed) = (Int(le32(zip, at + 20)), Int(le32(zip, at + 24)))
            #expect(compressed == uncompressed, sourceLocation: sourceLocation)
            let data = offset + 30 + nameLength + le16(zip, offset + 28)
            let bytes = Array(zip[data..<(data + compressed)])
            #expect(le32(zip, at + 16) == crc(bytes), "\(name)'s CRC-32", sourceLocation: sourceLocation)
            #expect(String(decoding: zip[(offset + 30)..<(offset + 30 + nameLength)], as: UTF8.self) == name, sourceLocation: sourceLocation)
            let extraStart = at + 46 + nameLength
            let extra = Array(zip[extraStart..<(extraStart + le16(zip, at + 30))])
            #expect(Array(zip[(offset + 30 + nameLength)..<data]) == extra, "\(name): the local header's extra fields are the directory's",
                    sourceLocation: sourceLocation)
            entries.append(ReadEntry(name: name, bytes: bytes, time: le16(zip, at + 12), date: le16(zip, at + 14),
                                     modified: modified(in: extra)))
            local = data + compressed
            at += 46 + nameLength + le16(zip, at + 30) + le16(zip, at + 32)
        }
        #expect(local == start && at == end, "nothing between the entries and the directory", sourceLocation: sourceLocation)
        return entries
    }

    /// The done-when's export: each note's file is the kit's `render` of it, byte for byte, named as
    /// the kit names it, with its tags' names and the exporter's citation of an indexed document.
    @Test func everyNoteIsExportedAsTheKitRendersIt() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        // An import's note on a volume the manifest lacks, with a lowercase id, no times and a tag that has gone.
        let imported = "c0ffee00-0000-4000-8000-0000000000c0"
        try fixture.rows.addNote(imported, volumeId: "frus9999v99", documentId: "d1", tagIds: [UUID().uuidString],
                                 bodyText: "Imported.", createdAt: nil, lastModified: nil)
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let tag = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Laos \"quoted\" \\ here"}"#))
            for (volume, document, body) in [("frus1961-63v06", "d1", "On an indexed document.\n\nTwo paragraphs."),
                                             ("frus1961-63v06", "d9", "On a document the index lacks."),
                                             ("frus1894Nicaragua", "d1", "On another volume.")] {
                let made = try await browser.send(.post, "/api/v1/me/volumes/\(volume)/documents/\(document)/notes",
                                                  NoteJSON(bodyText: body, runs: .formatted([RichTextRun(text: body, bold: true)]),
                                                           userTagIds: [tag.id]).json)
                #expect(made.status == .created)
            }
            let response = try await browser.get("/api/v1/me/notes/export")
            #expect(response.status == .ok && response.headers[.contentType] == "application/zip")
            #expect(response.headers[.contentDisposition] == #"attachment; filename="FRUSResearchNotes.zip""#)
            #expect(response.headers[.cacheControl] == "no-store")
            let entries = try Self.entries(of: Array(buffer: response.body))

            // The kit's files, rendered here from the store's notes, the index and the manifest.
            let notes = try fixture.store.notes(for: "owner")
            let served = try await ServedIndexProvider(state: fixture.server.state, resources: fixture.server.resources,
                                                       volumesDirectory: fixture.server.reader.volumesDirectory).served()
            var expected: [ResearchNoteMarkdownExport] = []
            for note in notes {
                let documents = try? await served.pipeline.documents(forVolume: note.volumeId)
                let entry = documents?.first { $0.documentId == note.documentId }
                let citation = try entry.map { entry in
                    HistoryAtStateCitationFormatter().format(
                        document: FRUSDocumentMetadata(citing: entry, printedNumber: entry.documentNumber),
                        volume: FRUSVolumeMetadata(try #require(fixture.server.resources.volume(note.volumeId))))
                }
                expected.append(ResearchNoteMarkdownExport.render(
                    noteId: try #require(UUID(uuidString: note.id)), documentId: note.documentId, volumeId: note.volumeId,
                    bodyText: note.bodyText, userTagIds: note.userTagIds.compactMap(UUID.init(uuidString:)),
                    createdAt: note.createdAt, lastModified: note.lastModified, citation: citation,
                    tagNamesById: [try #require(UUID(uuidString: tag.id)): tag.name]))
            }
            #expect(entries.map(\.name) == expected.map(\.filename), "one file per note, in All Notes' order")
            for (entry, file) in zip(entries, expected) {
                #expect(entry.bytes == Array(file.content.utf8), "\(file.filename), byte for byte")
            }
            #expect(entries.count == 4 && entries.last?.name == "frus9999v99-d1-C0FFEE00.md", "the kit's name, its id's prefix in uppercase")

            // The citation is the indexed documents' alone.
            let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, String(decoding: $0.bytes, as: UTF8.self)) })
            let indexed = try #require(byName.first { $0.key.hasPrefix("frus1961-63v06-d1-") }?.value)
            #expect(indexed.contains("\ncitation: \"_Foreign Relations of the United States_, 1961–1963"), "\(indexed)")
            #expect(try #require(byName.first { $0.key.hasPrefix("frus1894Nicaragua-d1-") }?.value).contains("\ncitation: "))
            let lacking = try #require(byName.first { $0.key.hasPrefix("frus1961-63v06-d9-") })
            let id = lacking.key.dropFirst("frus1961-63v06-d9-".count).prefix(8)
            #expect(lacking.key == "frus1961-63v06-d9-\(id).md")
            #expect(lacking.value == """
                ---
                documentId: d9
                volumeId: frus1961-63v06
                url: https://history.state.gov/historicaldocuments/frus1961-63v06/d9
                tags: ["Laos \\"quoted\\" \\\\ here"]
                created: 2026-10-24T00:00:00Z
                modified: 2026-10-24T00:00:00Z
                ---

                On a document the index lacks.

                """)
            #expect(byName["frus9999v99-d1-C0FFEE00.md"] == """
                ---
                documentId: d1
                volumeId: frus9999v99
                url: https://history.state.gov/historicaldocuments/frus9999v99/d1
                ---

                Imported.

                """, "no citation, no tag that has gone, and no times")
            // Each file's time is its note's: 24 October 2026, midnight; 1 January 1980 for none.
            #expect(entries.dropLast().allSatisfy { $0.time == 0 && $0.date == (46 << 9 | 10 << 5 | 24) })
            #expect(entries.last?.time == 0 && entries.last?.date == (1 << 5 | 1))
            #expect(entries.map(\.modified) == notes.map { ($0.lastModified ?? $0.createdAt).map { Int($0.timeIntervalSince1970) } })
            #expect(entries.first?.modified == 1_792_800_000 && entries.last?.modified == nil, "the exact time, and none for none")
        }
    }

    /// A file's time is its note's last change, else its making: in the DOS fields, in UTC, which
    /// carry no zone, and exactly in Info-ZIP's extended timestamp, which a reader anywhere reads
    /// as the same instant.
    @Test func eachFilesTimeIsItsNotesLatest() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addNote("A0000000-0000-4000-8000-00000000000A", createdAt: "2026-03-01T12:00:01.000Z", lastModified: nil)
        try fixture.rows.addNote("B0000000-0000-4000-8000-00000000000B", createdAt: "2026-03-01T12:00:00.000Z",
                                 lastModified: "2026-10-23T20:00:00.500Z")
        try await fixture.app.test(.router) { client in
            let entries = try Self.entries(of: Array(buffer: try await Browser(client: client).get("/api/v1/me/notes/export").body))
            #expect(entries.map(\.name) == ["frus1961-63v06-d1-B0000000.md", "frus1961-63v06-d1-A0000000.md"])
            #expect(entries.map(\.modified) == [1_792_785_600, 1_772_366_401], "its last change, to the second, else its making")
            #expect(entries[0].date == 46 << 9 | 10 << 5 | 23 && entries[0].time == 20 << 11)
            #expect(entries[1].date == 46 << 9 | 3 << 5 | 1 && entries[1].time == 12 << 11, "two seconds at a time")
        }
    }

    @Test func anExportWithNoNotesIsAnEmptyArchive() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let response = try await Browser(client: client).get("/api/v1/me/notes/export")
            #expect(response.status == .ok && response.body.readableBytes == 22)
            #expect(try Self.entries(of: Array(buffer: response.body)).isEmpty)
            #expect(problemCode(try await Browser(client: client).get("/api/v1/me/notes/export?format=zip")) == "UNKNOWN_PARAMETER")
        }
    }

    @Test func theArchivesCRCAndTimesAreZIPs() throws {
        #expect(StoredZIP.crc32(Array("123456789".utf8)) == 0xCBF4_3926, "the standard check value")
        #expect(StoredZIP.crc32([]) == 0 && Self.crc([]) == 0)
        let bytes = (0..<5_000).map { UInt8(truncatingIfNeeded: $0 &* 31) }
        #expect(StoredZIP.crc32(bytes) == Self.crc(bytes))
        let time = Date(timeIntervalSince1970: 1_792_847_533)  // 2026-10-24T13:12:13Z
        #expect(StoredZIP.dosTime(time) == (UInt16(13 << 11 | 12 << 5 | 6), UInt16(46 << 9 | 10 << 5 | 24)), "two seconds at a time")
        #expect(StoredZIP.dosTime(nil) == (0, UInt16(1 << 5 | 1)))
        #expect(StoredZIP.dosTime(Date(timeIntervalSince1970: 0)) == (0, UInt16(1 << 5 | 1)), "before 1980, its first day")
        let archive = try #require(StoredZIP.archive([
            StoredZIP.Entry(name: "a.md", bytes: Array("first\n".utf8), modified: time),
            StoredZIP.Entry(name: "é.md", bytes: [], modified: nil),
        ]))
        #expect(try Self.entries(of: archive) == [
            ReadEntry(name: "a.md", bytes: Array("first\n".utf8), time: 13 << 11 | 12 << 5 | 6, date: 46 << 9 | 10 << 5 | 24,
                      modified: 1_792_847_533),
            ReadEntry(name: "é.md", bytes: [], time: 0, date: 1 << 5 | 1, modified: nil),
        ])
        #expect(StoredZIP.timestamp(time) == [0x55, 0x54, 5, 0, 1] + [0xAD, 0xAE, 0xDC, 0x6A], "UT, five bytes, the modification time")
        #expect(StoredZIP.timestamp(Date(timeIntervalSince1970: -1.5)) == [0x55, 0x54, 5, 0, 1, 0xFE, 0xFF, 0xFF, 0xFF], "signed")
        #expect(StoredZIP.timestamp(nil).isEmpty)
    }

    /// APPNOTE's ZIP64 markers, 0xFFFF in a count and 0xFFFFFFFF in a size or offset, are never
    /// written, since this writer writes no ZIP64 record they would send a reader to: 65,534
    /// entries are an archive, and 65,535 are none.
    @Test func anArchiveNeverWritesAZIP64Marker() throws {
        let empty = StoredZIP.Entry(name: "", bytes: [], modified: nil)
        #expect(StoredZIP.archive(Array(repeating: empty, count: 0xFFFF)) == nil)
        let most = try #require(StoredZIP.archive(Array(repeating: empty, count: 0xFFFE)))
        let end = most.count - 22
        #expect(Self.le32(most, end) == 0x0605_4B50 && Self.le16(most, end + 8) == 0xFFFE && Self.le16(most, end + 10) == 0xFFFE)
    }
}
