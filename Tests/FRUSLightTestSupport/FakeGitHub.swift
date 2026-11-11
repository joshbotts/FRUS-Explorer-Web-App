// A folder served as GitHub serves it, in memory (PLAN's S21c): GitHub's listing of the corpus's volumes,
// each volume's file and history.state.gov's figure images, at a mirror's addresses, for the library's
// tests, which make no request outside. It records every request, answers one as a test asks, and holds
// one at a gate.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Synchronization

/// GitHub and history.state.gov, as the library asks them, in memory.
public final class FakeGitHub: LibraryTransport, Sendable {
    /// A request as it was made.
    public struct Request: Sendable, Equatable {
        public let url: String
        public let headers: [String: String]
    }

    private struct Volume: Sendable {
        var data: Data
        /// What the listing says of it: its blob SHA-1 and length, the file's own unless a test says otherwise.
        var sha: String
        var size: Int
    }

    private struct State: Sendable {
        var volumes: [String: Volume] = [:]
        var figures: [String: Data] = [:]
        var answers: [String: LibraryAnswer] = [:]
        var gates: [String: JobGate] = [:]
        var requests: [Request] = []
    }

    public let sources: LibrarySources
    private let state = Mutex(State())

    /// The mirror the fake answers for, as `FRUS_LIBRARY_MIRROR` would name it.
    public static let mirror = URL(string: "http://library.test/mirror/")!

    public init(sources: LibrarySources = .mirror(FakeGitHub.mirror)) {
        self.sources = sources
    }

    // MARK: What it serves

    /// Serves `data` as the volume file `filename`, listed with its own blob SHA-1 and length unless
    /// `listedSHA` or `listedSize` say otherwise.
    public func serve(_ filename: String, data: Data, listedSHA: String? = nil, listedSize: Int? = nil) {
        let volume = Volume(data: data, sha: listedSHA ?? VolumeUpdateChecker.gitBlobSHA1(for: data), size: listedSize ?? data.count)
        state.withLock { $0.volumes[filename] = volume }
    }

    /// Serves a volume of fixtures/tei, by its id.
    public func serveFixture(_ volumeId: String) throws {
        serve("\(volumeId).xml", data: try Data(contentsOf: RepositoryFiles.tei.appendingPathComponent("\(volumeId).xml")))
    }

    /// Serves `data` as the figure image `fileName` of `volumeId`.
    public func serveFigure(_ volumeId: String, _ fileName: String, data: Data) {
        state.withLock { $0.figures["\(volumeId)/\(fileName)"] = data }
    }

    /// Answers `url` with `answer`, whatever it serves there.
    public func answer(_ url: URL, with answer: LibraryAnswer) {
        state.withLock { $0.answers[url.absoluteString] = answer }
    }

    /// Holds each request for `url` at `gate` until it opens.
    public func hold(_ url: URL, at gate: JobGate) {
        state.withLock { $0.gates[url.absoluteString] = gate }
    }

    /// Every request made, in order.
    public var requests: [Request] { state.withLock { $0.requests } }

    /// How many requests were made for `url`.
    public func count(_ url: URL) -> Int { requests.filter { $0.url == url.absoluteString }.count }

    /// The address of a served volume's file.
    public func volumeURL(_ filename: String) -> URL {
        URL(string: sources.raw.absoluteString + "HistoryAtState/frus/master/volumes/" + filename)!
    }

    /// The listing GitHub's contents API gives, of every volume served and a file that is no volume.
    public func listingBody() -> Data {
        let volumes = state.withLock { $0.volumes }
        var entries: [[String: Any]] = volumes.keys.sorted().map { name in
            let volume = volumes[name]!
            return ["name": name, "path": "volumes/\(name)", "sha": volume.sha, "size": volume.size, "type": "file",
                    "url": "https://api.github.com/repos/HistoryAtState/frus/contents/volumes/\(name)?ref=master",
                    "download_url": "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(name)"]
        }
        entries.append(["name": "README.md", "path": "volumes/README.md", "sha": String(repeating: "0", count: 40), "size": 120,
                        "type": "file", "download_url": "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/README.md"])
        return try! JSONSerialization.data(withJSONObject: entries, options: [.sortedKeys])
    }

    // MARK: LibraryTransport

    public func get(_ url: URL, headers: [String: String], limit: Int, into file: URL?) async throws -> LibraryAnswer {
        let gate = state.withLock { state -> JobGate? in
            state.requests.append(Request(url: url.absoluteString, headers: headers))
            return state.gates[url.absoluteString]
        }
        if let gate { await gate.wait() }
        let answer = state.withLock { $0.answers[url.absoluteString] } ?? served(url, headers: headers)
        guard (200..<300).contains(answer.status) else { return answer }
        guard answer.body.count <= limit else { throw LibraryTransportError.tooLarge(limit: limit) }
        guard let file else { return answer }
        try? FileManager.default.removeItem(at: file)
        guard FileManager.default.createFile(atPath: file.path, contents: answer.body) else {
            throw LibraryTransportError.unreachable("\(file.lastPathComponent) could not be written")
        }
        return LibraryAnswer(status: answer.status, headers: answer.headers)
    }

    private func served(_ url: URL, headers: [String: String]) -> LibraryAnswer {
        let address = url.absoluteString
        if address == sources.listing.absoluteString {
            let body = listingBody()
            let etag = "\"\(VolumeUpdateChecker.gitBlobSHA1(for: body))\""
            if headers["If-None-Match"] == etag { return LibraryAnswer(status: 304, headers: ["etag": etag]) }
            return LibraryAnswer(status: 200, headers: ["etag": etag, "content-type": "application/json"], body: body)
        }
        let raw = sources.raw.absoluteString + "HistoryAtState/frus/master/volumes/"
        if address.hasPrefix(raw), let volume = state.withLock({ $0.volumes[String(address.dropFirst(raw.count))] }) {
            return LibraryAnswer(status: 200, headers: ["content-type": "text/plain"], body: volume.data)
        }
        let figures = sources.figures.absoluteString + "frus/"
        if address.hasPrefix(figures), let key = String(address.dropFirst(figures.count)).removingPercentEncoding,
           let image = state.withLock({ $0.figures[key] }) {
            return LibraryAnswer(status: 200, headers: ["content-type": "image/png"], body: image)
        }
        // What history.state.gov answers for an image it does not have, and GitHub for a file.
        return LibraryAnswer(status: address.hasPrefix(figures) ? 403 : 404, body: Data("Not here".utf8))
    }

    // MARK: Images

    /// A PNG's first bytes, its signature and header, then `marker`, so that each image a test serves is its own.
    public static func png(_ marker: String) -> Data {
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1])
        data.append(Data(marker.utf8))
        return data
    }
}
