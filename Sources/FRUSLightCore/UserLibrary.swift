// The `library_volumes` table (PLAN's S21c), migration 7's: the volumes a Standalone server has been
// asked to download, each with its download's state, and for the file in the volumes folder its git
// blob SHA-1, its size, when it was downloaded, whether it was side-loaded, and the figure images
// fetched beside it. A row left queued or downloading by a server that stopped is what the next start
// fetches again (`VolumeLibrary.resumeUnfinished()`), volume by volume. Each method is written once, on
// `RelationalUserStore`, in SQL both stores read, and each write changes nothing the kit's search reads.

import Foundation

/// A catalogue volume the library has been asked for, as the store keeps it.
public struct LibraryVolume: Sendable, Equatable {
    /// Its download's state.
    public enum State: String, Sendable, Codable, CaseIterable {
        /// A job waits to fetch it.
        case queued
        /// A job fetches it now, or did when the server stopped.
        case downloading
        /// Its file took its place, checked.
        case downloaded
        /// Its last download failed, `error` says why; a file in place before it is kept.
        case failed
    }

    public let volumeId: String
    public var state: State
    /// The git blob SHA-1 of the file in the volumes folder, in the form GitHub's listing gives a
    /// file's, checked against the listing before the file took its place; nil while none has.
    public var blobSHA: String?
    /// The file's length in bytes.
    public var sizeBytes: Int?
    /// The file's modification time when its download recorded it: with its length, what says that the
    /// file is still the one `blobSHA` was taken of, as the app keeps a hash with its file's stamp.
    public var modifiedAt: Date?
    public var downloadedAt: Date?
    /// Whether the file is one an admin side-loaded under the catalogue volume's name (PLAN's S21e).
    public var sideloaded: Bool
    /// The figure images beside the file, and the names the image host refused, at its download.
    public var figuresStored: Int?
    public var figuresRefused: Int?
    /// Why its download failed, or what of it was left undone, in the server's own sentence.
    public var error: String?
    /// Who asked for its download, nil for the server itself, and when.
    public var requestedBy: String?
    public var queuedAt: Date?
    public var updatedAt: Date

    public init(volumeId: String, state: State, blobSHA: String? = nil, sizeBytes: Int? = nil, modifiedAt: Date? = nil, downloadedAt: Date? = nil,
                sideloaded: Bool = false, figuresStored: Int? = nil, figuresRefused: Int? = nil, error: String? = nil,
                requestedBy: String? = nil, queuedAt: Date? = nil, updatedAt: Date) {
        self.volumeId = volumeId
        self.state = state
        self.blobSHA = blobSHA
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt.map(UserStoreDate.rounded)
        self.downloadedAt = downloadedAt.map(UserStoreDate.rounded)
        self.sideloaded = sideloaded
        self.figuresStored = figuresStored
        self.figuresRefused = figuresRefused
        self.error = error
        self.requestedBy = requestedBy
        self.queuedAt = queuedAt.map(UserStoreDate.rounded)
        self.updatedAt = UserStoreDate.rounded(updatedAt)
    }

    /// Whether a job waits for it or fetches it.
    public var isUnfinished: Bool { state == .queued || state == .downloading }
}

/// What a download's check found of a volume's file, as the store keeps it once the file took its place.
public struct LibraryDownloadRecord: Sendable, Equatable {
    public var blobSHA: String
    public var sizeBytes: Int
    /// The file's modification time once it took its place.
    public var modifiedAt: Date?
    public var figuresStored: Int
    public var figuresRefused: Int
    /// What was left undone, such as a figure image whose transfer failed, or nil.
    public var problem: String?

    public init(blobSHA: String, sizeBytes: Int, modifiedAt: Date? = nil, figuresStored: Int, figuresRefused: Int, problem: String? = nil) {
        self.blobSHA = blobSHA
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt.map(UserStoreDate.rounded)
        self.figuresStored = figuresStored
        self.figuresRefused = figuresRefused
        self.problem = problem
    }
}

/// What forgetting a volume found: its row forgotten, a download holding it, or no row.
public enum LibraryForgetting: Sendable, Equatable {
    case forgotten
    case heldByADownload
    case nothing
}

/// Where the library keeps its volumes' states: the user store's `library_volumes` (PLAN's S21c).
public protocol LibraryStore: Sendable {
    /// Every volume the library has been asked for, by id.
    func libraryVolumes() throws -> [LibraryVolume]
    /// One, or nil when it has never been asked for, or was removed.
    func libraryVolume(_ volumeId: String) throws -> LibraryVolume?
    /// Queues, as `requestedBy` asked at `time`, each of `volumeIds` that no job waits for or fetches
    /// already, in one transaction, so that two requests never queue one volume twice; gives those it
    /// queued, in the order given. What a row says of a file in place is kept.
    func queueLibraryDownloads(_ volumeIds: [String], requestedBy: String?, at time: Date) throws -> [String]
    /// A job begins to fetch it.
    func markLibraryDownloading(_ volumeId: String, at time: Date) throws
    /// Its file took its place at `time`, as `record` says, or was found in place already: when the file is
    /// the one the row named, its download's time is kept.
    func recordLibraryDownload(_ volumeId: String, _ record: LibraryDownloadRecord, at time: Date) throws
    /// Its download failed, why in the server's sentence; what the row says of a file in place is kept.
    func recordLibraryFailure(_ volumeId: String, error: String, at time: Date) throws
    /// Takes back the volumes a job was stopped before fetching: each still queued or downloading goes
    /// back to `downloaded` when a file had taken its place before, and otherwise loses its row.
    func withdrawLibraryDownloads(_ volumeIds: [String], at time: Date) throws
    /// Forgets the volume, whose files are to be removed, unless a download waits for it or fetches it,
    /// checked in the same transaction.
    func forgetLibraryVolume(_ volumeId: String) throws -> LibraryForgetting
    /// Every volume a job waits for or fetches, the earliest asked for first.
    func unfinishedLibraryDownloads() throws -> [LibraryVolume]
    /// What a server that stopped left: every volume a job waited for or fetched, queued again in one
    /// transaction, the earliest asked for first, which the next start fetches again.
    func requeueUnfinishedLibraryDownloads(at time: Date) throws -> [LibraryVolume]
}

extension RelationalUserStore: LibraryStore {
    private static let libraryColumns = """
        volume_id, state, blob_sha, size_bytes, downloaded_at, sideloaded, figures_stored, figures_refused, error,
        requested_by, queued_at, updated_at, modified_at
        """

    private static func text(_ value: String?) -> SQLiteValue { value.map(SQLiteValue.text) ?? .null }
    private static func integer(_ value: Int?) -> SQLiteValue { value.map { .integer(Int64($0)) } ?? .null }
    private static func stamp(_ time: Date) -> SQLiteValue { .text(UserStoreDate.text(UserStoreDate.rounded(time))) }

    public func libraryVolumes() throws -> [LibraryVolume] {
        try reading { db in
            try db.query("SELECT \(Self.libraryColumns) FROM library_volumes ORDER BY volume_id", []).map(Self.libraryVolume)
        }
    }

    public func libraryVolume(_ volumeId: String) throws -> LibraryVolume? {
        try reading { db in
            try db.query("SELECT \(Self.libraryColumns) FROM library_volumes WHERE volume_id = ?", [.text(volumeId)])
                .first.map(Self.libraryVolume)
        }
    }

    public func queueLibraryDownloads(_ volumeIds: [String], requestedBy: String?, at time: Date) throws -> [String] {
        try writing(outsideSearch: true) { db in
            var queued: [String] = []
            var seen = Set<String>()
            for id in volumeIds where seen.insert(id).inserted {
                let state = try db.scalar("SELECT state FROM library_volumes WHERE volume_id = ?", [.text(id)])?.text
                if state == LibraryVolume.State.queued.rawValue || state == LibraryVolume.State.downloading.rawValue { continue }
                _ = try db.query(
                    """
                    INSERT INTO library_volumes (volume_id, state, requested_by, queued_at, updated_at) VALUES (?, 'queued', ?, ?, ?)
                    ON CONFLICT (volume_id) DO UPDATE SET state = 'queued', error = NULL, requested_by = excluded.requested_by,
                        queued_at = excluded.queued_at, updated_at = excluded.updated_at
                    """, [.text(id), Self.text(requestedBy), Self.stamp(time), Self.stamp(time)])
                queued.append(id)
            }
            return queued
        }
    }

    public func markLibraryDownloading(_ volumeId: String, at time: Date) throws {
        try writing(outsideSearch: true) { db in
            _ = try db.query("UPDATE library_volumes SET state = 'downloading', updated_at = ? WHERE volume_id = ?",
                             [Self.stamp(time), .text(volumeId)])
        }
    }

    public func recordLibraryDownload(_ volumeId: String, _ record: LibraryDownloadRecord, at time: Date) throws {
        try writing(outsideSearch: true) { db in
            _ = try db.query(
                """
                INSERT INTO library_volumes (volume_id, state, blob_sha, size_bytes, downloaded_at, sideloaded, figures_stored,
                    figures_refused, error, updated_at, modified_at) VALUES (?, 'downloaded', ?, ?, ?, 0, ?, ?, ?, ?, ?)
                ON CONFLICT (volume_id) DO UPDATE SET state = 'downloaded', blob_sha = excluded.blob_sha,
                    size_bytes = excluded.size_bytes, modified_at = excluded.modified_at,
                    downloaded_at = CASE WHEN library_volumes.blob_sha = excluded.blob_sha AND library_volumes.downloaded_at IS NOT NULL
                        THEN library_volumes.downloaded_at ELSE excluded.downloaded_at END,
                    sideloaded = 0,
                    figures_stored = excluded.figures_stored, figures_refused = excluded.figures_refused, error = excluded.error,
                    updated_at = excluded.updated_at
                """,
                [.text(volumeId), .text(record.blobSHA), Self.integer(record.sizeBytes), Self.stamp(time),
                 Self.integer(record.figuresStored), Self.integer(record.figuresRefused), Self.text(record.problem), Self.stamp(time),
                 record.modifiedAt.map(Self.stamp) ?? .null])
        }
    }

    public func recordLibraryFailure(_ volumeId: String, error: String, at time: Date) throws {
        try writing(outsideSearch: true) { db in
            _ = try db.query(
                """
                INSERT INTO library_volumes (volume_id, state, error, updated_at) VALUES (?, 'failed', ?, ?)
                ON CONFLICT (volume_id) DO UPDATE SET state = 'failed', error = excluded.error, updated_at = excluded.updated_at
                """, [.text(volumeId), .text(error), Self.stamp(time)])
        }
    }

    public func withdrawLibraryDownloads(_ volumeIds: [String], at time: Date) throws {
        guard !volumeIds.isEmpty else { return }
        try writing(outsideSearch: true) { db in
            for id in Set(volumeIds) {
                _ = try db.query(
                    """
                    UPDATE library_volumes SET state = 'downloaded', error = NULL, updated_at = ?
                        WHERE volume_id = ? AND state IN ('queued', 'downloading') AND blob_sha IS NOT NULL
                    """, [Self.stamp(time), .text(id)])
                _ = try db.query("DELETE FROM library_volumes WHERE volume_id = ? AND state IN ('queued', 'downloading')",
                                 [.text(id)])
            }
        }
    }

    public func forgetLibraryVolume(_ volumeId: String) throws -> LibraryForgetting {
        try writing(outsideSearch: true) { db in
            switch try db.scalar("SELECT state FROM library_volumes WHERE volume_id = ?", [.text(volumeId)])?.text {
            case nil:
                return .nothing
            case LibraryVolume.State.queued.rawValue?, LibraryVolume.State.downloading.rawValue?:
                return .heldByADownload
            default:
                _ = try db.query("DELETE FROM library_volumes WHERE volume_id = ?", [.text(volumeId)])
                return .forgotten
            }
        }
    }

    public func unfinishedLibraryDownloads() throws -> [LibraryVolume] {
        try reading { db in
            try db.query(
                """
                SELECT \(Self.libraryColumns) FROM library_volumes WHERE state IN ('queued', 'downloading')
                    ORDER BY queued_at ASC NULLS FIRST, volume_id
                """, []).map(Self.libraryVolume)
        }
    }

    public func requeueUnfinishedLibraryDownloads(at time: Date) throws -> [LibraryVolume] {
        try writing(outsideSearch: true) { db in
            _ = try db.query("UPDATE library_volumes SET state = 'queued', updated_at = ? WHERE state = 'downloading'",
                             [Self.stamp(time)])
            return try db.query(
                """
                SELECT \(Self.libraryColumns) FROM library_volumes WHERE state = 'queued'
                    ORDER BY queued_at ASC NULLS FIRST, volume_id
                """, []).map(Self.libraryVolume)
        }
    }

    private static func libraryVolume(_ row: [SQLiteValue]) -> LibraryVolume {
        LibraryVolume(
            volumeId: row[0].text ?? "", state: row[1].text.flatMap(LibraryVolume.State.init(rawValue:)) ?? .failed,
            blobSHA: row[2].text, sizeBytes: row[3].integer.map(Int.init), modifiedAt: row[12].text.flatMap(UserStoreDate.date),
            downloadedAt: row[4].text.flatMap(UserStoreDate.date),
            sideloaded: row[5].integer == 1, figuresStored: row[6].integer.map(Int.init), figuresRefused: row[7].integer.map(Int.init),
            error: row[8].text, requestedBy: row[9].text, queuedAt: row[10].text.flatMap(UserStoreDate.date),
            updatedAt: row[11].text.flatMap(UserStoreDate.date) ?? Date(timeIntervalSince1970: 0))
    }
}
