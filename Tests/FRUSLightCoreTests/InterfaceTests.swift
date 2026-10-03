// The five v1 interfaces (docs/SPEC.md, What v1 should do now), each with its phase 1 implementation.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct InterfaceTests {
    // 1. Every index write goes through IndexWriter.

    @Test func localIndexWriterKeepsThePreviousIndex() throws {
        let directory = try TemporaryDirectory()
        let files = DataDirectory(root: directory.url)
        try files.prepare()
        let writer = LocalIndexWriter(files: files)
        try Data("first".utf8).write(to: files.candidateIndex)
        try writer.install(candidate: files.candidateIndex)
        try Data("second".utf8).write(to: files.candidateIndex)
        try writer.install(candidate: files.candidateIndex)
        #expect(try String(contentsOf: files.liveIndex, encoding: .utf8) == "second")
        #expect(try String(contentsOf: files.previousIndex, encoding: .utf8) == "first")
        #expect(!FileManager.default.fileExists(atPath: files.candidateIndex.path))
    }

    @Test func readOnlyIndexWriterRefuses() {
        #expect(throws: IndexWriteRefused.self) {
            try ReadOnlyIndexWriter().install(candidate: URL(fileURLWithPath: "/nonexistent"))
        }
    }

    // 2 and 3. Corrections as override rows, in a user store behind a protocol.

    @Test func userStoreMigratesOnceAndKeepsCorrections() throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent("app.db")
        let store = try SQLiteUserStore(url: url)
        #expect(try store.schemaVersion() == 1)
        let user = try store.singleUserID()
        let correction = IndexCorrection(volumeId: "frus1961-63v06", documentId: "d1", field: .isEditorialNote,
                                         value: "1", recordedBy: user)
        try store.record(correction)
        var changed = correction
        changed.value = "0"
        try store.record(changed)
        #expect(try store.corrections() == [changed], "a second correction replaces the first")

        let reopened = try SQLiteUserStore(url: url)
        #expect(try reopened.schemaVersion() == 1)
        #expect(try reopened.corrections() == [changed])
    }

    // 4. Sessions, jobs and generated files behind small interfaces.

    @Test func sessionsExpire() async {
        let clock = Clock()
        let store = InMemorySessionStore(now: { clock.now })
        let session = await store.create(for: "owner", lifetime: .seconds(60))
        #expect(session.id.count == 64)
        #expect(await store.session(id: session.id) == session)
        clock.advance(by: 61)
        #expect(await store.session(id: session.id) == nil)

        let other = await store.create(for: "owner", lifetime: .seconds(60))
        await store.remove(id: other.id)
        #expect(await store.session(id: other.id) == nil)
    }

    @Test func jobsRunOneAtATimeInOrder() async {
        let queue = InProcessJobQueue()
        let log = Log()
        let first = await queue.submit("first") {
            try await Task.sleep(for: .milliseconds(50))
            await log.append("first")
        }
        let second = await queue.submit("second") { await log.append("second") }
        let failing = await queue.submit("failing") { throw CocoaError(.fileNoSuchFile) }
        await queue.waitUntilIdle()
        #expect(await log.entries == ["first", "second"])
        #expect(await queue.record(id: first)?.state == .succeeded)
        #expect(await queue.record(id: second)?.state == .succeeded)
        #expect(await queue.record(id: failing)?.state == .failed)
        #expect(await queue.records().map(\.id) == [first, second, failing])
    }

    @Test func dataDirectoryFollowsTheSpecLayout() throws {
        let files = DataDirectory(root: URL(fileURLWithPath: "/data"))
        #expect(files.importDirectory.path == "/data/import")
        #expect(files.liveIndex.path == "/data/index/frus.db")
        #expect(files.candidateIndex.path == "/data/index/frus.db.new")
        #expect(files.previousIndex.path == "/data/index/frus.db.prev")
        #expect(files.userStore.path == "/data/app/app.db")
        #expect(files.volumesDirectory.path == "/data/volumes")
    }
}

/// A clock a test moves by hand.
final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_800_000_000)

    var now: Date { lock.withLock { current } }
    func advance(by seconds: TimeInterval) { lock.withLock { current += seconds } }
}

actor Log {
    private(set) var entries: [String] = []
    func append(_ entry: String) { entries.append(entry) }
}
