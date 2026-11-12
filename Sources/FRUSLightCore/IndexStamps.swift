// The indexer's stamps beside a Standalone server's index (PLAN's S21d): what the app keeps in
// `UserDefaults`, the date-index, FTS-schema, person-rollup and broken-references stamps and the
// interrupted-indexing sentinel, kept for the server in one file beside the index, `index-stamps.json`,
// with the server's own record of each volume whose indexing failed or was stopped. The file is written
// whole under a hidden name, flushed, and renamed over the old at each change, so that a restart reads
// the stamps as they were before a change or after it, never part of one.

import FRUSCoreKit
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A volume whose last pass did not index it, as the server keeps it against the volume (PLAN's S21d):
/// the stage the kit's progress stream gave last before `.failed`, why, in the server's sentence, and
/// whether the pass failed or was stopped. A pass that indexes the volume removes it.
public struct IndexingFailureRecord: Codable, Sendable, Equatable {
    /// `failed`: the volume could not be indexed, and is not tried again unless asked, or downloaded
    /// again. `stopped`: an admin's cancel or a problem of the server's, not the volume's, cut its pass
    /// short, and the next pass that is asked for or follows a download takes it again.
    public enum Kind: String, Codable, Sendable { case failed, stopped }

    public var kind: Kind
    /// Where its pass was, from the kit's progress stream: `starting` before its first update,
    /// `reading` its XML, `storingDocuments`, or `storingTables` once its documents had been stored.
    public var stage: String
    /// Why, in the server's words: never a key, nor anything of a user's research.
    public var sentence: String
    public var at: Date

    public init(kind: Kind, stage: String, sentence: String, at: Date) {
        self.kind = kind
        self.stage = stage
        self.sentence = sentence
        self.at = at
    }
}

/// The upgrade of a Standalone server's index a start began (PLAN's S21e), kept beside the stamps while it is
/// under way: the date-index version the index was at, the kit's it is re-indexed for from the cached XML,
/// and the volumes the kit's pass over every volume has still to take, which `/readyz` names. An upgrade a
/// stop of the server cut short is begun again by the next start, whose pass takes every volume again, as
/// the app's launch runs its pass again.
public struct IndexUpgradeRecord: Codable, Sendable, Equatable {
    public var from: Int
    public var to: Int
    /// The volumes the upgrade has still to re-index, in the order it takes them.
    public var remaining: [String]
    public var began: Date

    public init(from: Int, to: Int, remaining: [String], began: Date) {
        self.from = from
        self.to = to
        self.remaining = remaining
        self.began = began
    }
}

/// The kit's stamp store for a Standalone server's index (`IndexingStampStore`), kept in a file beside
/// it, with the server's record of the volumes its passes did not index.
///
/// It answers as the app's `UserDefaults` and the kit's `InMemoryIndexingStampStore` do for what the
/// pipeline and the state tracker store: an integer reads back through `integer(forKey:)` and
/// `string(forKey:)`, a string through `string(forKey:)` and, when it holds a number,
/// `integer(forKey:)`, and data through `data(forKey:)`. Each change is written at once, whole, under a
/// hidden name beside the file, flushed, renamed over it and the folder flushed, so that a restart reads
/// the file as it was before the change or after it. A write that fails keeps the change in memory,
/// says so in `writeProblem` and the log, and is made again with the next change; what a restart then
/// reads errs towards work done again, a rollup rebuilt or a volume indexed again, never towards work
/// skipped.
public final class IndexStampFile: IndexingStampStore, @unchecked Sendable {
    /// The file's name, beside the index.
    public static let fileName = "index-stamps.json"

    /// What the file holds.
    struct Contents: Codable, Equatable {
        /// The file's own format, so that a later one can tell this one.
        var format = 1
        /// The kit's stamps, by the kit's keys.
        var stamps: [String: Value] = [:]
        /// The server's record of the volumes a pass did not index, by volume id.
        var failures: [String: IndexingFailureRecord] = [:]
        /// The upgrade a start began, while it is under way (PLAN's S21e); absent in a file from before.
        var upgrade: IndexUpgradeRecord?
        /// The volumes a removal has begun to take out of the index whose files are still to go (PLAN's
        /// S21e), which the next start's removes; absent in a file from before.
        var removals: [String]?
        /// Whether a reset has begun and its pass over every volume not ended (PLAN's S21e): the next start
        /// empties the index again and runs the pass.
        var resetting: Bool?
    }

    /// A stamp, as the kit stores it.
    enum Value: Codable, Equatable {
        case integer(Int)
        case string(String)
        case data(Data)

        private enum CodingKeys: String, CodingKey { case integer, string, data }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let value = try container.decodeIfPresent(Int.self, forKey: .integer) {
                self = .integer(value)
            } else if let value = try container.decodeIfPresent(String.self, forKey: .string) {
                self = .string(value)
            } else {
                self = .data(try container.decode(Data.self, forKey: .data))
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .integer(let value): try container.encode(value, forKey: .integer)
            case .string(let value): try container.encode(value, forKey: .string)
            case .data(let value): try container.encode(value, forKey: .data)
            }
        }
    }

    public let url: URL
    private let lock = NSLock()
    private var contents: Contents
    private var problem: String?
    private let log: @Sendable (String) -> Void

    /// The stamps the file at `url` holds, or none when there is no file. A file that cannot be read as
    /// stamps, which only a hand's edit or another program makes, is set aside under a name of its own
    /// beside it, `index-stamps.json.unreadable-<time>`, and the store begins with none, as for an index
    /// with no stamps: the kit's gated passes run again, which each are made to. The hidden files a stop
    /// left mid-write are removed.
    public init(url: URL, now: Date = Date(), log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.url = url.standardizedFileURL
        self.log = log
        let folder = self.url.deletingLastPathComponent()
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        where name.hasPrefix(".\(Self.fileName).") && name.hasSuffix(".new") {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
        guard let data = FileManager.default.contents(atPath: self.url.path) else {
            contents = Contents()
            return
        }
        if let read = try? Self.decoder.decode(Contents.self, from: data), read.format == 1 {
            contents = read
            return
        }
        let aside = self.url.path + ".unreadable-" + UserStoreDate.text(now).replacingOccurrences(of: ":", with: "-")
        if rename(self.url.path, aside) == 0 {
            log("\(self.url.path) could not be read as the index's stamps, so it was set aside as \(aside), and the stamps begin again: the passes after indexing run again at the next indexing")
        } else {
            log("\(self.url.path) could not be read as the index's stamps, and could not be set aside (\(String(cString: strerror(errno)))): the stamps begin again, and replace it at their first change")
        }
        contents = Contents()
    }

    /// Why the last write of the file failed, or nil when the file holds what the store does.
    public var writeProblem: String? { locked { problem } }

    // MARK: IndexingStampStore

    public func integer(forKey defaultName: String) -> Int {
        locked {
            switch contents.stamps[defaultName] {
            case .integer(let value)?: value
            case .string(let value)?: Int(value) ?? 0
            default: 0
            }
        }
    }

    public func string(forKey defaultName: String) -> String? {
        locked {
            switch contents.stamps[defaultName] {
            case .string(let value)?: value
            case .integer(let value)?: String(value)
            default: nil
            }
        }
    }

    public func data(forKey defaultName: String) -> Data? {
        locked {
            if case .data(let value)? = contents.stamps[defaultName] { return value }
            return nil
        }
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        let stamp: Value?
        switch value {
        case nil: stamp = nil
        case let value as Int: stamp = .integer(value)
        case let value as Bool: stamp = .integer(value ? 1 : 0)
        case let value as any BinaryInteger: stamp = .integer(Int(truncatingIfNeeded: value))
        case let value as String: stamp = .string(value)
        case let value as Data: stamp = .data(value)
        default:
            log("An index stamp of a kind the server does not keep, \(type(of: value!)), under \(defaultName), was not kept")
            return
        }
        change { $0.stamps[defaultName] = stamp }
    }

    public func removeObject(forKey defaultName: String) {
        change { $0.stamps[defaultName] = nil }
    }

    // MARK: The volumes a pass did not index

    /// Every volume a pass did not index, by its id.
    public func failures() -> [String: IndexingFailureRecord] { locked { contents.failures } }

    /// Keeps `record` against `volumeId`, in place of any before it.
    public func recordFailure(_ record: IndexingFailureRecord, for volumeId: String) {
        change { $0.failures[volumeId] = record }
    }

    /// Forgets what was kept against `volumeId`, once a pass has indexed it.
    public func clearFailure(of volumeId: String) {
        change { $0.failures[volumeId] = nil }
    }

    /// Forgets every stamp and record: for an index that another took the place of, as an import's, or
    /// that a reset emptied (PLAN's S21e).
    public func reset() {
        change { $0 = Contents() }
    }

    // MARK: The upgrade and the removals under way (PLAN's S21e)

    /// The upgrade a start began, while it is under way.
    public func upgrade() -> IndexUpgradeRecord? { locked { contents.upgrade } }

    /// Begins an upgrade from `from` to `to`, of `volumes`, in their order, in place of any before it.
    public func beginUpgrade(from: Int, to: Int, volumes: [String], at time: Date) {
        change { $0.upgrade = IndexUpgradeRecord(from: from, to: to, remaining: volumes, began: time) }
    }

    /// The upgrade has re-indexed `volumeId`, or has no more to do with it, as when it left the index.
    public func upgradeDone(_ volumeId: String) {
        change { contents in
            guard let upgrade = contents.upgrade, upgrade.remaining.contains(volumeId) else { return }
            contents.upgrade?.remaining.removeAll { $0 == volumeId }
        }
    }

    /// The upgrade has ended: its record goes.
    public func endUpgrade() {
        change { $0.upgrade = nil }
    }

    /// Whether a reset has begun and its pass over every volume not ended.
    public func isResetting() -> Bool { locked { contents.resetting == true } }

    /// A reset begins, or goes on past the stamps' clearing to its pass.
    public func markResetting() {
        change { $0.resetting = true }
    }

    /// The reset's pass over every volume has ended.
    public func endResetting() {
        change { $0.resetting = nil }
    }

    /// The volumes a removal has begun to take out of the index whose files are still to go.
    public func removals() -> [String] { locked { contents.removals ?? [] } }

    /// A removal of `volumeId` begins: kept before its first write to the index.
    public func beginRemoval(_ volumeId: String) {
        change { contents in
            guard !(contents.removals ?? []).contains(volumeId) else { return }
            contents.removals = (contents.removals ?? []) + [volumeId]
        }
    }

    /// The removal of `volumeId` has ended, its files gone with it.
    public func endRemoval(_ volumeId: String) {
        change { contents in
            guard let removals = contents.removals, removals.contains(volumeId) else { return }
            let left = removals.filter { $0 != volumeId }
            contents.removals = left.isEmpty ? nil : left
        }
    }

    // MARK: Writing

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Makes `edit` and writes the file, unless nothing changed and the file holds it already. The lock
    /// is held through the write, so that two changes reach the file in the order they were made.
    private func change(_ edit: (inout Contents) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var next = contents
        edit(&next)
        guard next != contents || problem != nil else { return }
        contents = next
        let failure = Self.save(next, to: url)
        if let failure, failure != problem {
            log("The index's stamps could not be written to \(url.path), and are kept in memory until a later write succeeds: \(failure)")
        } else if failure == nil, problem != nil {
            log("The index's stamps were written to \(url.path) again")
        }
        problem = failure
    }

    /// Writes `contents` whole to a hidden file beside `url`, flushes it, renames it over `url` and
    /// flushes the folder. Gives why it failed, or nil.
    static func save(_ contents: Contents, to url: URL) -> String? {
        let bytes: Data
        do {
            bytes = try encoder.encode(contents)
        } catch {
            return "the stamps could not be encoded: \(error)"
        }
        let folder = url.deletingLastPathComponent().path
        let staged = folder + "/." + fileName + "." + UUID().uuidString + ".new"
        func failure(_ action: String) -> String { "could not \(action): \(String(cString: strerror(errno)))" }
        let descriptor = open(staged, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else { return failure("create \(staged)") }
        var written = 0
        while written < bytes.count {
            let put = bytes.withUnsafeBytes { write(descriptor, $0.baseAddress! + written, $0.count - written) }
            if put < 0 {
                if errno == EINTR { continue }
                let reason = failure("write \(staged)")
                close(descriptor)
                unlink(staged)
                return reason
            }
            written += put
        }
        guard fsync(descriptor) == 0 else {
            let reason = failure("flush \(staged)")
            close(descriptor)
            unlink(staged)
            return reason
        }
        close(descriptor)
        guard rename(staged, url.path) == 0 else {
            let reason = failure("rename \(staged) to \(url.path)")
            unlink(staged)
            return reason
        }
        // The new name is kept through a loss of power, where the folder can be flushed.
        let directory = open(folder, O_RDONLY | O_CLOEXEC)
        if directory >= 0 {
            _ = fsync(directory)
            close(directory)
        }
        return nil
    }
}
