// The owner's writing in an export, as the tests read it on their own, with plain SQL rather than the
// import's code (PLAN's S16e); and check 5's search of a file's bytes for it, as
// scripts/check-stripped-export searches a stripped export, with a search for its words besides.

import FRUSLightCore
import Foundation

/// What an export made with the owner's writing holds of it, read from the file.
public struct ExportWriting: Sendable, Equatable {
    public struct Text: Sendable, Equatable {
        public var volumeId: String
        public var documentId: String
        public var text: String
    }

    public var summaries: [Text] = []
    public var notes: [Text] = []
    /// `user_tags`' rows, the ids as the file holds them.
    public var tags: [(id: String, name: String)] = []
    /// Each document's tags, from `user_tag_ids`.
    public var assignments: [(volumeId: String, documentId: String, tagId: String)] = []

    public static func == (a: ExportWriting, b: ExportWriting) -> Bool {
        a.summaries == b.summaries && a.notes == b.notes && a.tags.map { "\($0.id) \($0.name)" } == b.tags.map { "\($0.id) \($0.name)" }
            && a.assignments.map { "\($0.volumeId)/\($0.documentId)/\($0.tagId)" } == b.assignments.map { "\($0.volumeId)/\($0.documentId)/\($0.tagId)" }
    }

    /// The writing the file at `url` holds, read in SQLite's immutable mode.
    public init(of url: URL) throws {
        let db = try SQLiteConnection.immutable(url)
        defer { db.close() }
        for row in try db.query("""
            SELECT volume_id, document_id, summary_text, note_text, user_tag_ids FROM document_cache ORDER BY volume_id, document_id
            """) {
            let (volume, document) = (row[0].text ?? "", row[1].text ?? "")
            if let text = row[2].text, !text.isEmpty { summaries.append(Text(volumeId: volume, documentId: document, text: text)) }
            if let text = row[3].text, !text.isEmpty { notes.append(Text(volumeId: volume, documentId: document, text: text)) }
            for id in (row[4].text ?? "").split(separator: " ") {
                assignments.append((volume, document, String(id)))
            }
        }
        tags = try db.query("SELECT tag_id, name FROM user_tags ORDER BY rowid").map { ($0[0].text ?? "", $0[1].text ?? "") }
    }

    /// Whether the file's tables hold none of it: its `user_content` index and its bytes are searched
    /// apart, as check 5 searches them.
    public var isEmpty: Bool { summaries.isEmpty && notes.isEmpty && tags.isEmpty && assignments.isEmpty }

    /// Check 5's snippets of it, as scripts/check-stripped-export takes them: from the longest line of
    /// each summary and note, its first 24 characters, and 24 from its middle when the two cannot
    /// overlap, or a line of 16 bytes or more whole; and each tag name of 12 bytes or more.
    public var snippets: Set<String> {
        var snippets: Set<String> = []
        for value in (summaries + notes).map(\.text) {
            let line = value.split(separator: "\n", omittingEmptySubsequences: false).max { $0.count < $1.count }
                .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
            let characters = Array(line)
            if characters.count >= 24 {
                snippets.insert(String(characters[0..<24]))
                if characters.count >= 72 {
                    let middle = characters.count / 2 - 12
                    snippets.insert(String(characters[middle..<middle + 24]))
                }
            } else if line.utf8.count >= 16 {
                snippets.insert(line)
            }
        }
        for tag in tags where tag.name.utf8.count >= 12 && !tag.name.contains("\n") { snippets.insert(tag.name) }
        return snippets
    }

    /// The words of it, letters only and of six or more, as written, that `corpus`, the corpus's own
    /// text, does not hold in any case: a search finer than check 5's snippets, which a line of
    /// writing would have to keep whole.
    public func words(outside corpus: String) -> Set<String> {
        let text = ((summaries + notes).map(\.text) + tags.map(\.name)).joined(separator: " ")
        let corpus = corpus.lowercased()
        return Set(text.split { !$0.isLetter }.map(String.init).filter { $0.count >= 6 && !corpus.contains($0.lowercased()) })
    }
}

/// A file's bytes, searched as check 5 searches them.
public enum FileBytes {
    /// The needles the file at `url` holds anywhere in its bytes, free pages included.
    public static func found(_ needles: Set<String>, in url: URL) throws -> Set<String> {
        let bytes = try Data(contentsOf: url)
        return needles.filter { bytes.range(of: Data($0.utf8)) != nil }
    }

    /// How many times the file at `url` holds `needle` in its bytes.
    public static func count(_ needle: String, in url: URL) throws -> Int {
        let bytes = try Data(contentsOf: url)
        let pattern = Data(needle.utf8)
        var count = 0
        var start = bytes.startIndex
        while let range = bytes.range(of: pattern, in: start..<bytes.endIndex) {
            count += 1
            start = range.upperBound
        }
        return count
    }
}
