// GET /api/v1/me/notes/export (PLAN's S15d): Export Notes as Markdown, every note of the user as the
// Mac's Data export writes it, one file each from the kit's `ResearchNoteMarkdownExport`, with the
// citation the app's exporter gives it (`ResearchDataExporter.markdownExports`). The app shares the
// files themselves; a browser saves one download, so they come in one ZIP, the web's own, stored
// rather than compressed, which needs no library.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

enum NotesExport {
    /// The download's name: the folder the app writes the files into is `FRUSResearchNotes-<UUID>`.
    static let fileName = "FRUSResearchNotes.zip"

    /// The ZIP of every note's file, as an attachment. A note whose id is no UUID, which only a
    /// damaged import could leave, has no file, as the kit's renderer takes the app's `UUID`.
    static func response(notes: [NoteRecord], tags: [UserTagRecord], provider: ServedIndexProvider,
                         resources: ServerResources) async throws -> Response {
        let files = await files(notes, tags: tags, provider: provider, resources: resources)
        let modified = Dictionary(notes.map { (NoteRoutes.wire($0.id), $0.lastModified ?? $0.createdAt) },
                                  uniquingKeysWith: { first, _ in first })
        guard let archive = StoredZIP.archive(files.map {
            StoredZIP.Entry(name: $0.filename, bytes: Array($0.content.utf8), modified: modified[$0.id.uuidString] ?? nil)
        }) else {
            throw APIProblem(.internalServerError, code: "EXPORT_TOO_LARGE",
                             detail: "The notes are more than one ZIP without ZIP64 can hold: 65,534 files and 4 GiB.")
        }
        var headers = HTTPFields()
        headers[.contentType] = "application/zip"
        headers[.contentDisposition] = "attachment; filename=\"\(fileName)\""
        headers[.cacheControl] = "no-store"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: archive)))
    }

    /// Each note's file, in the order given, as `ResearchDataExporter.markdownExports` renders it:
    /// the kit's `render` with the note's values, its tags' names, a tag named twice taking its first
    /// name as the exporter's dictionary does, and the document's citation.
    static func files(_ notes: [NoteRecord], tags: [UserTagRecord], provider: ServedIndexProvider,
                      resources: ServerResources) async -> [ResearchNoteMarkdownExport] {
        let tagNamesById = Dictionary(tags.compactMap { tag in UUID(uuidString: tag.id).map { ($0, tag.name) } },
                                      uniquingKeysWith: { first, _ in first })
        let served = try? await provider.servedIfReady()
        var volumes: [String: [DocumentBrowserEntry]?] = [:]
        var files: [ResearchNoteMarkdownExport] = []
        for note in notes {
            guard let id = UUID(uuidString: note.id) else { continue }
            if volumes[note.volumeId] == nil, let served {
                volumes[note.volumeId] = .some(try? await served.pipeline.documents(forVolume: note.volumeId))
            }
            let documents = volumes[note.volumeId] ?? nil
            files.append(ResearchNoteMarkdownExport.render(
                noteId: id, documentId: note.documentId, volumeId: note.volumeId, bodyText: note.bodyText,
                userTagIds: note.userTagIds.compactMap(UUID.init(uuidString:)), createdAt: note.createdAt,
                lastModified: note.lastModified,
                citation: citation(of: note.documentId, among: documents, volume: resources.volume(note.volumeId)),
                tagNamesById: tagNamesById))
        }
        return files
    }

    /// The exporter's citation: the kit's history.state.gov style, of the served index's row for the
    /// document and the manifest's entry for its volume; nil when no index is served, the volume is
    /// not in the manifest or not indexed, or the document is not in it. Not the reader's Cite,
    /// which falls back to the TEI.
    static func citation(of documentId: String, among documents: [DocumentBrowserEntry]?,
                         volume: VolumeManifestEntry?) -> String? {
        guard let volume, let documents, let entry = documents.first(where: { $0.documentId == documentId }) else { return nil }
        return HistoryAtStateCitationFormatter().format(
            document: FRUSDocumentMetadata(citing: entry, printedNumber: entry.documentNumber),
            volume: FRUSVolumeMetadata(volume))
    }
}

/// A ZIP archive of stored (uncompressed) entries, each with its CRC-32, as APPNOTE 6.3.10 sets
/// them out: a local header and the bytes for each, then the central directory and its end.
enum StoredZIP {
    struct Entry: Sendable {
        var name: String
        var bytes: [UInt8]
        /// The file's time, or nil for the format's first, 1 January 1980.
        var modified: Date?
    }

    /// APPNOTE's marker in a 16-bit count, and in a 32-bit size or offset, that sends a reader to a
    /// ZIP64 record (4.4.1.4), which this writer never writes: a value must stay below it.
    private static let marker16 = 0xFFFF
    private static let marker32 = 0xFFFF_FFFF

    /// The archive, or nil when it needs ZIP64: 65,535 entries or more, or a size or offset that
    /// reaches 4 GiB.
    static func archive(_ entries: [Entry]) -> [UInt8]? {
        guard entries.count < marker16 else { return nil }
        var out: [UInt8] = []
        var directory: [UInt8] = []
        for entry in entries {
            let name = Array(entry.name.utf8)
            guard name.count <= 0xFFFF, entry.bytes.count < marker32, out.count < marker32 else { return nil }
            let (size, offset) = (UInt32(entry.bytes.count), UInt32(out.count))
            let (time, date) = dosTime(entry.modified)
            let crc = crc32(entry.bytes)
            let extra = timestamp(entry.modified)
            // Version 2.0, UTF-8 names (bit 11), stored (method 0).
            let common = le16(20) + le16(0x0800) + le16(0) + le16(time) + le16(date) + le32(crc) + le32(size) + le32(size)
                + le16(UInt16(name.count)) + le16(UInt16(extra.count))
            out += le32(0x0403_4B50) + common + name + extra + entry.bytes
            // Made by version 2.0 on MS-DOS, no comment, disk 0, no attributes.
            directory += le32(0x0201_4B50) + le16(20) + common + le16(0) + le16(0) + le16(0) + le32(0) + le32(offset) + name + extra
        }
        guard out.count < marker32, directory.count < marker32, out.count + directory.count < marker32 else { return nil }
        let (start, length) = (UInt32(out.count), UInt32(directory.count))
        out += directory
        out += le32(0x0605_4B50) + le16(0) + le16(0) + le16(UInt16(entries.count)) + le16(UInt16(entries.count))
            + le32(length) + le32(start) + le16(0)
        return out
    }

    /// CRC-32 as ZIP takes it: the reflected polynomial 0xEDB88320, from all ones, inverted.
    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
        return value
    }

    /// Info-ZIP's extended timestamp ("UT", 0x5455) of a file's time: its modification time alone,
    /// flag bit 0, as seconds since 1970 in UTC, a signed 32-bit count, the same nine bytes in the
    /// local header and the directory. The DOS fields carry no zone, and a reader takes them as its
    /// own local time; one that reads this field, as Info-ZIP's unzip and libarchive do, shows the
    /// note's true time. None for a file with no time.
    static func timestamp(_ date: Date?) -> [UInt8] {
        guard let date else { return [] }
        let seconds = Int32(clamping: Int(date.timeIntervalSince1970.rounded(.down)))
        return le16(0x5455) + le16(5) + [0x01] + le32(UInt32(bitPattern: seconds))
    }

    /// MS-DOS's time and date of `date` in UTC, two seconds at a time, from 1980 to 2107: the web's
    /// own zone, since a server cannot know its reader's, beside the exact time in `timestamp`.
    static func dosTime(_ date: Date?) -> (time: UInt16, date: UInt16) {
        guard let date else { return (0, 1 << 5 | 1) }
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = parts.year ?? 1980
        guard year >= 1980 else { return (0, 1 << 5 | 1) }
        guard year <= 2107 else { return (23 << 11 | 59 << 5 | 29, 127 << 9 | 12 << 5 | 31) }
        let time = (parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | (parts.second ?? 0) / 2
        return (UInt16(time), UInt16((year - 1980) << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1)))
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func le16(_ value: UInt16) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8)] }

    private static func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)]
    }
}
