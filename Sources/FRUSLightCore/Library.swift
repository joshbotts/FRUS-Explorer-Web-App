// The library (PLAN's S21c): a Standalone server's own folder of volumes, /data/volumes, which it writes,
// as the app's `DownloadManager` writes its `Volumes` folder: each catalogue volume as `<volumeId>.xml`,
// downloaded from the address the kit's `downloadUrl` names, and its figure images beside it in
// `<volumeId>.figures/`, from history.state.gov, as the app's figure library fetches them. A download is
// a job of the server's queue (S20d), volume after volume: it reads GitHub's listing of the corpus once,
// with the kit's decode and diff, and keeps a volume's file only once its length and git blob SHA-1, the
// kit's, are the listing's, renaming it into place over the copy it replaces; a cancel stops it between
// two volumes, and a volume a server stopped is fetched again at the next start. Every rule is the kit's,
// compiled from the submodule: the listing's entries, `downloadUrl`, the blob SHA-1, a figure's file name
// and the PNG check. The scan of a volume's figures is the app's, mirrored here and held to its source.
//
// Requests go to three places, which no user and no listing chooses: GitHub's API and raw files, and
// history.state.gov's images, or the operator's mirror of the three (`FRUS_LIBRARY_MIRROR`), which the
// tests and the smoke test point at a folder served as GitHub serves it. Under `FRUS_OFFLINE` the server
// makes none: it holds no transport at all. FoundationNetworking's URLSession makes them, through libcurl,
// which the image carries since S21c.

import FRUSCoreKit
import Foundation
import Synchronization
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Where the library's files come from

/// The three places the library asks: GitHub's API, whose contents listing names each volume's git blob
/// SHA-1 and size, GitHub's raw files, where each volume is, and history.state.gov's images. Set by the
/// operator alone, never by a request.
public struct LibrarySources: Sendable, Equatable {
    /// GitHub's API, ending in a slash.
    public let api: URL
    /// Where GitHub serves a repository's files, ending in a slash.
    public let raw: URL
    /// Where history.state.gov serves a volume's figure images, ending in a slash.
    public let figures: URL

    /// The hosts the app asks, by name; a mirror's folder holds each one's files under its name.
    public static let apiHost = "api.github.com"
    public static let rawHost = "raw.githubusercontent.com"
    public static let figuresHost = "static.history.state.gov"

    /// GitHub's and history.state.gov's own, which the app asks.
    public static let github = LibrarySources(
        api: URL(string: "https://\(apiHost)/")!, raw: URL(string: "https://\(rawHost)/")!,
        figures: URL(string: "https://\(figuresHost)/")!)

    /// A mirror at `base`, an http or https URL: one folder, served as GitHub serves its files, holding each
    /// host's under its name, as `api.github.com/repos/HistoryAtState/frus/contents/volumes`,
    /// `raw.githubusercontent.com/HistoryAtState/frus/master/volumes/<file>` and
    /// `static.history.state.gov/frus/<volumeId>/<image>` (`FRUS_LIBRARY_MIRROR`).
    public static func mirror(_ base: URL) -> LibrarySources {
        var text = base.absoluteString
        if !text.hasSuffix("/") { text += "/" }
        return LibrarySources(api: URL(string: text + apiHost + "/")!, raw: URL(string: text + rawHost + "/")!,
                              figures: URL(string: text + figuresHost + "/")!)
    }

    /// Whether these are GitHub's own: the only API a token is sent to.
    public var isGitHub: Bool { self == .github }

    /// GitHub's listing of the corpus's volumes folder, which the app's `ManifestStore` reads.
    public var listing: URL { URL(string: api.absoluteString + "repos/HistoryAtState/frus/contents/volumes")! }

    /// Where a catalogue volume is downloaded from: the kit's `downloadUrl`, as it is from GitHub, its host's
    /// part under the mirror's folder from a mirror; nil for a volume with none, as a side-loaded one has.
    public func volume(_ entry: VolumeManifestEntry) -> URL? {
        guard let given = entry.downloadUrl else { return nil }
        let host = "https://\(Self.rawHost)/"
        guard given.hasPrefix(host) else { return nil }
        if isGitHub { return URL(string: given) }
        return URL(string: raw.absoluteString + given.dropFirst(host.count))
    }

    /// Where history.state.gov serves `fileName` of `volumeId`, as the app's figure library names it
    /// (`frus/<volumeId>/<fileName>`), each part one path component, percent-encoded: nil when either is not
    /// one (`FRUSURLScheme.isSafeComponent`, the kit's).
    public func figure(volumeId: String, fileName: String) -> URL? {
        guard FRUSURLScheme.isSafeComponent(volumeId), FRUSURLScheme.isSafeComponent(fileName) else { return nil }
        return URL(string: figures.absoluteString + "frus/" + Self.escaped(volumeId) + "/" + Self.escaped(fileName))
    }

    /// One path component with every byte but the unreserved ones percent-encoded, so that no `?`, `#` or `%`
    /// in a name changes the address.
    static func escaped(_ component: String) -> String {
        let unreserved = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)
        return component.utf8.map { unreserved.contains($0) ? String(UnicodeScalar($0)) : String(format: "%%%02X", $0) }.joined()
    }
}

// MARK: - Asking

/// One answer: its status, its headers by lowercase name, and its body, when no file was given for it, or
/// the start of an error's.
public struct LibraryAnswer: Sendable, Equatable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

/// Why a request had no answer the library takes.
public enum LibraryTransportError: Error, Sendable, Equatable {
    /// Its body was longer than the request allows: the part written is removed.
    case tooLarge(limit: Int)
    /// No answer: no connection, a reset, a timeout. Its words, for the log alone.
    case unreachable(String)
    /// The file it was to be written to could not be made, written or flushed, as on a full disk. Its
    /// words, for the log alone.
    case unwritable(String)
    /// A redirect to another host, or from https, which the library does not follow.
    case redirected(String)
}

/// How the library asks: GETs only, each body bounded.
public protocol LibraryTransport: Sendable {
    /// GETs `url` with `headers`. A 2xx body of at most `limit` bytes is written to `file`, made afresh and
    /// flushed to disk before this returns, or with no file kept in the answer; any other status's body is
    /// kept, its first 64 KiB. Throws `LibraryTransportError`, or `CancellationError` when its task is
    /// cancelled.
    func get(_ url: URL, headers: [String: String], limit: Int, into file: URL?) async throws -> LibraryAnswer
}

/// FoundationNetworking's URLSession, over libcurl on Linux: nothing cached or kept but the file asked
/// for; a request that receives nothing for a minute gives up; redirects followed within the host asked
/// alone.
public final class URLSessionLibraryTransport: NSObject, LibraryTransport, URLSessionDataDelegate, @unchecked Sendable {
    /// One request under way, read and written on the session's delegate queue, whose one thread is the
    /// only one that touches it once it is begun, but for its outcome and its continuation, which the
    /// transport's lock guards.
    private final class Transfer: @unchecked Sendable {
        let limit: Int
        let file: URL?
        var handle: FileHandle?
        var status = 0
        var headers: [String: String] = [:]
        var body = Data()
        var received = 0
        var failure: LibraryTransportError?
        /// Set once an error's first 64 KiB have come, after which the rest is not read.
        var errorBodyRead = false

        init(limit: Int, file: URL?) {
            self.limit = limit
            self.file = file
        }

        var succeeded: Bool { (200..<300).contains(status) }
    }

    /// A transfer's waiter and its outcome: whichever comes second resumes the first, so that an outcome
    /// that comes before its waiter, as one cancelled before it began may, is never lost.
    private struct Waiting: Sendable {
        var continuation: CheckedContinuation<LibraryAnswer, any Error>?
        var outcome: Result<LibraryAnswer, LibraryTransportError>?
    }

    static let errorBodyLimit = 65_536

    private let transfers = Mutex<[Int: Transfer]>([:])
    private let waiting = Mutex<[Int: Waiting]>([:])
    private var session: URLSession!

    public override init() {
        super.init()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "frus-light.library"
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }

    public func get(_ url: URL, headers: [String: String], limit: Int, into file: URL?) async throws -> LibraryAnswer {
        try Task.checkCancellation()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let task = session.dataTask(with: request)
        let id = task.taskIdentifier
        // Kept before the task can begin or be cancelled, so that every callback finds it.
        transfers.withLock { $0[id] = Transfer(limit: limit, file: file) }
        waiting.withLock { $0[id] = Waiting() }
        do {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let outcome = waiting.withLock { state -> Result<LibraryAnswer, LibraryTransportError>? in
                        if let outcome = state[id]?.outcome {
                            state[id] = nil
                            return outcome
                        }
                        state[id]?.continuation = continuation
                        return nil
                    }
                    if let outcome {
                        continuation.resume(with: outcome)
                    } else {
                        task.resume()
                    }
                }
            } onCancel: {
                task.cancel()
            }
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
    }

    private func transfer(_ task: URLSessionTask) -> Transfer? {
        transfers.withLock { $0[task.taskIdentifier] }
    }

    /// Hands `outcome` to the transfer's waiter, now or once it waits.
    private func finish(_ id: Int, _ outcome: Result<LibraryAnswer, LibraryTransportError>) {
        let continuation = waiting.withLock { state -> CheckedContinuation<LibraryAnswer, any Error>? in
            guard let continuation = state[id]?.continuation else {
                state[id]?.outcome = outcome
                return nil
            }
            state[id] = nil
            return continuation
        }
        continuation?.resume(with: outcome)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let transfer = transfer(dataTask) else {
            dataTask.cancel()
            return completionHandler(.cancel)
        }
        let http = response as? HTTPURLResponse
        transfer.status = http?.statusCode ?? 0
        for (name, value) in http?.allHeaderFields ?? [:] {
            if let name = name as? String, let value = value as? String { transfer.headers[name.lowercased()] = value }
        }
        if transfer.succeeded {
            // FoundationNetworking on Linux may not stop a task for `.cancel`, so each refusal cancels it too.
            if response.expectedContentLength > Int64(transfer.limit) {
                transfer.failure = .tooLarge(limit: transfer.limit)
                dataTask.cancel()
                return completionHandler(.cancel)
            }
            if let file = transfer.file {
                // Made afresh, and never through a link left where it goes.
                try? FileManager.default.removeItem(at: file)
                guard FileManager.default.createFile(atPath: file.path, contents: nil),
                      let handle = try? FileHandle(forWritingTo: file) else {
                    transfer.failure = .unwritable("\(file.lastPathComponent) could not be made")
                    dataTask.cancel()
                    return completionHandler(.cancel)
                }
                transfer.handle = handle
            }
        }
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let transfer = transfer(dataTask), transfer.failure == nil else { return }
        transfer.received += data.count
        guard transfer.succeeded else {
            transfer.body.append(data.prefix(max(0, Self.errorBodyLimit - transfer.body.count)))
            if transfer.body.count >= Self.errorBodyLimit {
                transfer.errorBodyRead = true
                dataTask.cancel()
            }
            return
        }
        guard transfer.received <= transfer.limit else {
            transfer.failure = .tooLarge(limit: transfer.limit)
            return dataTask.cancel()
        }
        if let handle = transfer.handle {
            do {
                try handle.write(contentsOf: data)
            } catch {
                transfer.failure = .unwritable("\(transfer.file?.lastPathComponent ?? "the file") could not be written: \(error)")
                dataTask.cancel()
            }
        } else {
            transfer.body.append(data)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let from = task.originalRequest?.url
        let to = request.url
        if let from, let to, from.scheme == to.scheme, from.host == to.host, from.port == to.port {
            return completionHandler(request)
        }
        transfer(task)?.failure = .redirected(to?.host ?? "another address")
        completionHandler(nil)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let id = task.taskIdentifier
        guard let transfer = transfers.withLock({ $0.removeValue(forKey: id) }) else { return }
        var failure = transfer.failure
        if let handle = transfer.handle {
            if failure == nil, error == nil {
                do {
                    try handle.synchronize()
                } catch {
                    failure = .unwritable("\(transfer.file?.lastPathComponent ?? "the file") could not be flushed: \(error)")
                }
            }
            try? handle.close()
        }
        if let error, failure == nil, !transfer.errorBodyRead {
            failure = .unreachable(String(describing: error))
        }
        if let failure {
            if let file = transfer.file { try? FileManager.default.removeItem(at: file) }
            return finish(id, .failure(failure))
        }
        finish(id, .success(LibraryAnswer(status: transfer.status, headers: transfer.headers, body: transfer.body)))
    }
}

// MARK: - A volume's figures

/// The figure images a volume's text names (#1516): the `<graphic url>` of every `<figure>` outside its
/// title page, in document order, each once. The app's `FigureImageLibrary.graphicNames(inVolumeAt:)`, and
/// the scanner it runs, are app code (`FRUSExplorer/Downloads/DownloadManager.swift`), mirrored here and
/// held to their source by `LibraryParityTests`; a name's file name is the kit's
/// (`FigureImageName.fileName(forGraphic:)`).
public enum LibraryFigureNames {
    /// The `<graphic url>` of every `<figure>` in the volume at `url` that is not on its title page, in
    /// document order, each once — or `nil` when the file cannot be read or parsed. External entities are
    /// not resolved.
    public static func graphicNames(inVolumeAt url: URL) -> [String]? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let scanner = FigureGraphicScanner()
        parser.delegate = scanner
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return nil }
        return scanner.names
    }
}

/// Collects the graphics a volume's figures name (`LibraryFigureNames.graphicNames(inVolumeAt:)`).
private final class FigureGraphicScanner: NSObject, XMLParserDelegate {
    /// The names met so far, in document order, each once.
    private(set) var names: [String] = []
    private var seen = Set<String>()
    private var figureDepth = 0
    private var titlePageDepth = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "figure": figureDepth += 1
        case "titlePage": titlePageDepth += 1
        case "graphic":
            guard figureDepth > 0, titlePageDepth == 0, let name = attributeDict["url"],
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seen.insert(name).inserted else { return }
            names.append(name)
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch elementName {
        case "figure": figureDepth = max(0, figureDepth - 1)
        case "titlePage": titlePageDepth = max(0, titlePageDepth - 1)
        default: break
        }
    }
}

// MARK: - The library

/// Why the library refused what it was asked.
public enum LibraryRefusal: Error, Equatable, Sendable {
    /// An Import server reads the TEI folder mounted at /data/volumes, and writes nothing there.
    case importMode
    /// `FRUS_OFFLINE`: the server makes no request outside.
    case offline
    /// No catalogue volume has the id.
    case unknownVolume(String)
    /// A job waits for the volume or fetches it.
    case inProgress(String)
    /// Every volume asked for waits for a download already; for all, every volume not downloaded does.
    case nothingToDownload(all: Bool)
    /// The volume's file is not in the volumes folder.
    case notDownloaded(String)
}

/// The volumes folder of a Standalone server cannot be written: the read-only TEI mount of Import mode is
/// in its place, or the folder belongs to another user, as the one Docker made for that mount in a volume
/// an Import server used does. The server does not start.
public struct LibraryFolderError: Error, CustomStringConvertible {
    public let path: String
    public let underlying: String

    public var description: String {
        "In Standalone mode the server keeps the volumes it downloads in \(path), which it cannot write (\(underlying)). Either the read-only TEI folder of Import mode is mounted there, which compose.standalone.yaml leaves out, or the folder belongs to another user, as the one Docker made for that mount does in a volume an Import server used: give it to the server's user once with docker compose run --rm --no-deps --user 0 --cap-add CHOWN --entrypoint chown frus 10001:10001 \(path). The install guide's Standalone section says more"
    }
}

/// A Standalone server's library of volumes (PLAN's S21c): the files in its volumes folder, their states
/// in the user store's `library_volumes`, and the downloads that write them, as jobs of the server's
/// queue. The kit's corrections check reads it as it reads the app's `DownloadManager`
/// (`DownloadedVolumeFiles`). In Import mode it reads the mounted TEI folder, downloads nothing, and leaves
/// the rows a Standalone run kept aside, since they describe files that are not the mount's.
public final class VolumeLibrary: DownloadedVolumeFiles, Sendable {
    /// What the library remembers of GitHub's last listing: its ETag, its body and when it came, so that a
    /// job soon after uses it as it is, and a later one asks with `If-None-Match`, which GitHub answers 304
    /// for a listing that has not changed.
    private struct CachedListing: Sendable {
        let etag: String?
        let body: Data
        let at: Date
    }

    /// Within one job, how the image host has answered: after `figurePatience` images in a row with no
    /// answer, or one answer that it limits this server, the job asks it nothing more.
    struct FigureHost {
        var unanswered = 0
        var givenUp: String?
    }

    public let volumesDirectory: URL
    let store: any LibraryStore
    let jobs: any JobQueue
    /// The published catalogue, in the manifest's order, and by id.
    let catalogue: [VolumeManifestEntry]
    let entries: [String: VolumeManifestEntry]
    public let sources: LibrarySources
    /// How the library asks; none under `FRUS_OFFLINE` or in Import mode, so that nothing can.
    let transport: (any LibraryTransport)?
    public let mode: ServerConfiguration.Mode
    /// `FRUS_OFFLINE`: the server makes no request outside, and the library holds no transport.
    public let offline: Bool
    /// `FRUS_GITHUB_TOKEN`, sent to GitHub's own API alone.
    let githubToken: String?
    let now: @Sendable () -> Date
    let log: @Sendable (String) -> Void
    private let lastListing = Mutex<CachedListing?>(nil)
    /// Told the volumes a download job fetched once the job ends, however it ends, with any: the
    /// library's indexing queues their pass there (PLAN's S21d). Set once, at the server's start.
    private let downloadsEnd = Mutex<(@Sendable ([String]) async -> Void)?>(nil)
    /// Told a volume a download is about to give a file, a new one or another in place of a copy, before the
    /// file takes its name: the library's indexing owes it a pass (PLAN's S21f). Set once, at the server's start.
    private let fileReplaced = Mutex<(@Sendable (String) -> Void)?>(nil)

    /// The longest listing the library reads: GitHub's of 553 volumes is about 400 KB.
    static let listingLimit = 16 * 1_048_576
    /// How long a listing is used as it is, without asking again: a download soon after another, as a
    /// volume asked for after a volume, costs GitHub's limit nothing. A file corrected meanwhile fails its
    /// check against it, and is asked for again.
    static let listingReuse: TimeInterval = 300
    /// The largest figure image it takes: the corpus's largest is 3.6 MB.
    static let figureLimit = 64 * 1_048_576
    /// How many volumes in a row whose host gave no answer stop a job: the host is not answering.
    static let patience = 3
    /// How many figure images in a row with no answer end a job's asking the image host, as the app's pass
    /// over its library stops after three volumes whose transfers all failed.
    static let figurePatience = 3
    /// The space a volume leaves free on the data volume, beyond its own length, which the user store and
    /// its backups share.
    static let spareBytes: Int64 = 64 * 1_048_576
    /// The suffix of a file being written, hidden by its leading dot until it takes its name.
    static let partialSuffix = ".download"

    public init(volumesDirectory: URL, store: any LibraryStore, jobs: any JobQueue, catalogue: [VolumeManifestEntry],
                sources: LibrarySources, transport: (any LibraryTransport)?, mode: ServerConfiguration.Mode,
                offline: Bool = false, githubToken: String? = nil, now: @escaping @Sendable () -> Date = Date.init,
                log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.volumesDirectory = volumesDirectory.standardizedFileURL
        self.store = store
        self.jobs = jobs
        self.catalogue = catalogue
        entries = Dictionary(catalogue.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first })
        self.sources = sources
        self.offline = offline
        self.transport = offline ? nil : transport
        self.mode = mode
        self.githubToken = githubToken
        self.now = now
        self.log = log
    }

    /// The library `configuration` asks for: URLSession's transport in Standalone mode, and none under
    /// `FRUS_OFFLINE` or in Import mode, which download nothing.
    public static func make(configuration: ServerConfiguration, files: DataDirectory, store: any LibraryStore,
                            jobs: any JobQueue, catalogue: [VolumeManifestEntry],
                            log: @escaping @Sendable (String) -> Void) -> VolumeLibrary {
        let downloads = configuration.mode == .standalone && !configuration.offline
        return VolumeLibrary(volumesDirectory: files.volumesDirectory, store: store, jobs: jobs, catalogue: catalogue,
                             sources: configuration.libraryMirror.map(LibrarySources.mirror) ?? .github,
                             transport: downloads ? URLSessionLibraryTransport() : nil, mode: configuration.mode,
                             offline: configuration.offline, githubToken: configuration.githubToken, log: log)
    }

    /// Why this server downloads nothing, or nil when it downloads.
    public var downloadsRefusal: LibraryRefusal? {
        if mode != .standalone { return .importMode }
        if offline || transport == nil { return .offline }
        return nil
    }

    /// The server's own User-Agent, as its other requests send.
    static var userAgent: String { "FRUS-Explorer-Light/\(FRUSLightVersion.string)" }

    // MARK: Files

    /// `<volumeId>.xml` in the volumes folder, for an id that is one path component; nil for another.
    func fileURL(_ volumeId: String) -> URL? {
        guard FRUSURLScheme.isSafeComponent(volumeId) else { return nil }
        return volumesDirectory.appendingPathComponent("\(volumeId).xml", isDirectory: false)
    }

    /// The folder `<volumeId>.figures` beside it, where the app keeps a volume's figure images.
    func figuresDirectory(_ volumeId: String) -> URL? {
        guard FRUSURLScheme.isSafeComponent(volumeId) else { return nil }
        return volumesDirectory.appendingPathComponent("\(volumeId).figures", isDirectory: true)
    }

    /// What is at `url` without following a link: nil when nothing is.
    static func kind(at url: URL) -> FileAttributeType? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
    }

    /// The length and modification time of the regular file at `url`, a link followed, as the reader follows
    /// one in an Import server's TEI folder; nil when none is there. Nothing is written through a link: a
    /// file takes its name by a rename, which replaces a link in its place.
    static func regularFile(_ url: URL) -> (size: Int, modified: Date?)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = (attributes[.size] as? NSNumber)?.intValue else { return nil }
        return (size, (attributes[.modificationDate] as? Date).map(UserStoreDate.rounded))
    }

    /// The length of the regular file at `url`, or nil when none is there.
    static func regularFileSize(_ url: URL) -> Int? {
        regularFile(url)?.size
    }

    /// The length of a volume's file in the volumes folder, or nil when it is not there.
    public func fileSize(_ volumeId: String) -> Int? {
        fileURL(volumeId).flatMap(Self.regularFileSize)
    }

    /// Every volume the library has been asked for, as the store keeps it: for the admin's Library. None in
    /// Import mode, whose files are the mount's, not those a Standalone run downloaded.
    public func libraryVolumes() throws -> [LibraryVolume] {
        mode == .standalone ? try store.libraryVolumes() : []
    }

    // MARK: DownloadedVolumeFiles

    public func isVolumeDownloaded(_ volumeId: String) -> Bool {
        fileSize(volumeId) != nil
    }

    /// The file's git blob SHA-1: the one its download was checked by while the file keeps the length and
    /// the modification time it had then, as the app's `DownloadManager` keeps a hash with its file's stamp,
    /// and otherwise taken now, with the kit's `gitBlobSHA1(for:)`; nil when the volume is not downloaded.
    public func localVolumeInfo(for volumeId: String) async -> LocalVolumeInfo? {
        guard let url = fileURL(volumeId), let file = Self.regularFile(url) else { return nil }
        if mode == .standalone, let row = try? await Blocking.run({ [store] in try store.libraryVolume(volumeId) }),
           let sha = row.blobSHA, row.sizeBytes == file.size, let modified = row.modifiedAt, modified == file.modified {
            return LocalVolumeInfo(sha: sha, sizeBytes: file.size)
        }
        let sha = try? await Blocking.run { VolumeUpdateChecker.gitBlobSHA1(for: try Data(contentsOf: url, options: .alwaysMapped)) }
        return LocalVolumeInfo(sha: sha, sizeBytes: file.size)
    }

    public func isSideloaded(_ volumeId: String) async -> Bool {
        guard mode == .standalone else { return false }
        return (try? await Blocking.run { [store] in try store.libraryVolume(volumeId)?.sideloaded ?? false }) ?? false
    }

    // MARK: At a start

    /// At a start, in Standalone mode: makes the volumes folder if it is not there, checks that the server
    /// can write in it, and removes any file a download was writing when the server stopped. Throws
    /// `LibraryFolderError` when the folder cannot be written. In Import mode it does nothing: the folder is
    /// the operator's mount.
    public func prepare() throws {
        guard mode == .standalone else { return }
        let manager = FileManager.default
        let probe = volumesDirectory.appendingPathComponent(".write-check-\(UUID().uuidString)")
        do {
            try manager.createDirectory(at: volumesDirectory, withIntermediateDirectories: true)
            guard manager.createFile(atPath: probe.path, contents: Data()) else {
                throw CocoaError(.fileWriteNoPermission)
            }
            try manager.removeItem(at: probe)
        } catch {
            throw LibraryFolderError(path: volumesDirectory.path, underlying: error.localizedDescription)
        }
        for name in (try? manager.contentsOfDirectory(atPath: volumesDirectory.path)) ?? [] {
            let url = volumesDirectory.appendingPathComponent(name)
            if name.hasPrefix("."), name.hasSuffix(Self.partialSuffix) || name.hasPrefix(Self.stagingPrefix) {
                // A file a download was writing, or a side-load's staging folder (PLAN's S21e).
                try? manager.removeItem(at: url)
            } else if name.hasSuffix(".figures"), Self.kind(at: url) == .typeDirectory {
                for image in (try? manager.contentsOfDirectory(atPath: url.path)) ?? []
                where image.hasPrefix(".") && image.hasSuffix(Self.partialSuffix) {
                    try? manager.removeItem(at: url.appendingPathComponent(image))
                }
            }
        }
    }

    /// At a start, once the queue is open: every volume a stopped server left queued or downloading is
    /// downloaded again, in a job of the server's own, volume by volume, the volumes it finished kept and
    /// one the listing no longer names left out; or, where this server downloads nothing, each is marked
    /// failed with why. Gives the job, if one was queued.
    @discardableResult
    public func resumeUnfinished() async -> Job? {
        let time = now()
        let left: [LibraryVolume]
        do {
            left = try await Blocking.run { [store] in try store.requeueUnfinishedLibraryDownloads(at: time) }
        } catch {
            log("The library's unfinished downloads could not be read from the user store: \(error)")
            return nil
        }
        guard !left.isEmpty else { return nil }
        let ids = left.map(\.volumeId)
        if let refusal = downloadsRefusal {
            let sentence = refusal == .offline
                ? "The server started with FRUS_OFFLINE=true, so this download, which a restart stopped, was not resumed."
                : "The server started in Import mode, so this download, which a restart stopped, was not resumed."
            try? await Blocking.run { [store] in for id in ids { try store.recordLibraryFailure(id, error: sentence, at: time) } }
            log("\(ids.count) unfinished \(ids.count == 1 ? "download was" : "downloads were") not resumed: \(sentence)")
            return nil
        }
        do {
            let job = try await submit(ids, requestedBy: nil, subject: Self.subject(ids, resumed: true), skipUnlisted: true)
            log("Resuming the download of \(ids.count) \(ids.count == 1 ? "volume" : "volumes") a restart stopped, as job \(job.id)")
            return job
        } catch {
            log("The download of \(ids.count) volumes a restart stopped could not be queued again: \(error)")
            return nil
        }
    }

    // MARK: Downloads

    /// What to download: these catalogue volumes, or every one not downloaded.
    public enum DownloadRequest: Sendable, Equatable {
        case volumes([String])
        case all
    }

    /// Queues a download, as `requestedBy` asked: a job of the server's queue that fetches each volume asked
    /// for that no job waits for or fetches already, one after another, its figure images with it. For
    /// `all`, every catalogue volume not downloaded, and one GitHub's listing no longer names is left out.
    /// Throws `LibraryRefusal`, or what the queue throws when it cannot keep the job.
    public func download(_ request: DownloadRequest, requestedBy: String?) async throws -> Job {
        if let refusal = downloadsRefusal { throw refusal }
        let ids: [String]
        switch request {
        case .volumes(let given):
            if let unknown = given.first(where: { entries[$0] == nil }) { throw LibraryRefusal.unknownVolume(unknown) }
            ids = given
        case .all:
            ids = catalogue.map(\.volumeId).filter { !isVolumeDownloaded($0) }
        }
        let time = now()
        let queued = try await Blocking.run { [store] in try store.queueLibraryDownloads(ids, requestedBy: requestedBy, at: time) }
        guard !queued.isEmpty else {
            if case .volumes(let given) = request, Set(given).count == 1 { throw LibraryRefusal.inProgress(given[0]) }
            throw LibraryRefusal.nothingToDownload(all: request == .all)
        }
        return try await submit(queued, requestedBy: requestedBy, subject: Self.subject(queued, resumed: false),
                                skipUnlisted: request == .all)
    }

    /// The job's subject: a volume's id, or how many.
    static func subject(_ ids: [String], resumed: Bool) -> String {
        let what = ids.count == 1 ? ids[0] : "\(ids.count) volumes"
        return resumed ? "\(what), resumed after a restart" : what
    }

    private func submit(_ ids: [String], requestedBy: String?, subject: String, skipUnlisted: Bool) async throws -> Job {
        do {
            return try await jobs.submit(.libraryDownload, subject: subject, requestedBy: requestedBy, id: nil, onCancel: {
                await self.withdraw(ids)
            }) { job in
                let fetched = FetchedVolumes()
                do {
                    let line = try await self.run(ids, job: job, skipUnlisted: skipUnlisted, fetched: fetched)
                    await self.downloadsEnded(await fetched.ids)
                    return line
                } catch {
                    await self.downloadsEnded(await fetched.ids)
                    throw error
                }
            }
        } catch {
            await withdraw(ids)
            throw error
        }
    }

    /// Takes back volumes a job will not fetch: each goes back to what it was before it was asked for.
    private func withdraw(_ ids: [String]) async {
        let time = now()
        do {
            try await Blocking.run { [store] in try store.withdrawLibraryDownloads(ids, at: time) }
        } catch {
            log("The library could not take back \(ids.count) volumes a job will not fetch: \(error)")
        }
    }

    private func fail(_ id: String, _ sentence: String) async {
        let time = now()
        do {
            try await Blocking.run { [store] in try store.recordLibraryFailure(id, error: sentence, at: time) }
        } catch {
            log("The library could not record that \(id)'s download failed: \(error)")
        }
    }

    /// A volume's download failed, in the server's sentence: `unreachable` when its host gave no answer, and
    /// `stops`, the reason the rest are not tried, when no volume after it can be downloaded either, as on a
    /// full disk or under a host's rate limit.
    struct Problem: Error {
        let sentence: String
        var unreachable = false
        var stops: String?
    }

    /// The job's work: GitHub's listing once, then each volume, a step each, so that a cancel stops it
    /// between two volumes and takes back those it had not begun.
    /// Has `hook` told the volumes each download job fetched, once the job ends (PLAN's S21d).
    public func whenDownloadsEnd(_ hook: @escaping @Sendable ([String]) async -> Void) {
        downloadsEnd.withLock { $0 = hook }
    }

    private func downloadsEnded(_ fetched: [String]) async {
        guard !fetched.isEmpty, let hook = downloadsEnd.withLock({ $0 }) else { return }
        await hook(fetched)
    }

    /// Has `hook` told each volume a download is about to give a file, before the file takes its name (PLAN's
    /// S21f).
    public func whenFileWillBeReplaced(_ hook: @escaping @Sendable (String) -> Void) {
        fileReplaced.withLock { $0 = hook }
    }

    // MARK: The corrections check (PLAN's S21f)

    /// Check for Corrections, as the app's Settings ▸ Keeping Current runs it: GitHub's listing, read once
    /// (`liveDiff()`), and the kit's `VolumeUpdateChecker.updatableVolumes(known:liveInfoByVolumeId:downloadManager:)`
    /// over this library, which compares each downloaded volume's git blob SHA-1 with the listing's, or its
    /// length where either has none. Gives the volumes changed upstream since they were downloaded, in the
    /// catalogue's order, a side-loaded copy among them. Throws `LibraryRefusal` on a server that downloads
    /// nothing, and `JobFailed`, in the server's words, when the listing cannot be read.
    public func checkForCorrections() async throws -> [UpdatableVolume] {
        if let refusal = downloadsRefusal { throw refusal }
        let diff = try await liveDiff()
        return await VolumeUpdateChecker.updatableVolumes(known: diff.known, liveInfoByVolumeId: diff.liveInfoByVolumeId,
                                                          downloadManager: self)
    }

    private func run(_ ids: [String], job: JobContext, skipUnlisted: Bool, fetched: FetchedVolumes) async throws -> String? {
        var next = 0
        do {
            try await job.step("Reading GitHub's listing of the corpus's volumes", fraction: 0)
            let live: [String: LiveVolumeInfo]
            do {
                live = try await liveListing()
            } catch let failure as JobFailed {
                for id in ids { await fail(id, "Not downloaded: \(failure.jobMessage)") }
                next = ids.count
                throw failure
            }
            var downloaded = 0
            var failed: [String] = []
            var left = 0
            var unanswered = 0
            var figures = FigureHost()
            while next < ids.count {
                let id = ids[next]
                try await job.step("Downloading \(id) (\(next + 1) of \(ids.count))", fraction: Double(next) / Double(ids.count))
                next += 1
                guard let info = live[id] else {
                    if skipUnlisted {
                        await withdraw([id])
                        left += 1
                    } else {
                        await fail(id, "GitHub's listing of the corpus no longer names \(entries[id]?.filename ?? id), so it was not downloaded.")
                        failed.append(id)
                    }
                    continue
                }
                do {
                    try await fetchVolume(id, live: info, job: job, figures: &figures)
                    downloaded += 1
                    await fetched.add(id)
                    unanswered = 0
                } catch let problem as Problem {
                    await fail(id, problem.sentence)
                    failed.append(id)
                    unanswered = problem.unreachable ? unanswered + 1 : 0
                    var stop = problem.stops
                    if stop == nil, unanswered >= Self.patience {
                        stop = "\(Self.patience) volumes in a row had no answer from their host"
                    }
                    if let stop, next < ids.count {
                        let rest = Array(ids[next...])
                        for id in rest { await fail(id, "Not tried: the download stopped, since \(stop).") }
                        failed += rest
                        next = ids.count
                        throw JobFailed("Downloaded \(downloaded) of \(ids.count) volumes, then stopped, since \(stop). The Library says which were not downloaded.")
                    }
                }
            }
            let leftOut = left == 0 ? "" : " \(left) \(left == 1 ? "volume" : "volumes") GitHub's listing does not name \(left == 1 ? "was" : "were") left out."
            guard failed.isEmpty else {
                throw JobFailed("Downloaded \(downloaded) of \(ids.count) volumes; \(failed.count) could not be downloaded, which the Library says why.\(leftOut)")
            }
            return "Downloaded \(downloaded) \(downloaded == 1 ? "volume" : "volumes").\(leftOut)"
        } catch is JobCancelled {
            await withdraw(Array(ids[next...]))
            throw JobCancelled()
        }
    }

    /// GitHub's listing of the corpus's volumes, read with the kit's decode and diff: each catalogue
    /// volume's git blob SHA-1 and size, by id. One read in the last `listingReuse` seconds is used as it
    /// is; a later read is asked with the last answer's ETag, so that GitHub answers 304 for a listing that
    /// has not changed, which with a token its rate limit does not count; and with `FRUS_GITHUB_TOKEN` to
    /// GitHub's own API alone. Throws `JobFailed` in the server's words.
    func liveListing() async throws -> [String: LiveVolumeInfo] {
        try await liveDiff().liveInfoByVolumeId
    }

    /// The kit's diff of the catalogue against GitHub's listing, as `liveListing()` reads it: the catalogue's
    /// volumes the listing names (`known`) and each one's git blob SHA-1 and size (`liveInfoByVolumeId`).
    func liveDiff() async throws -> ManifestDiffResult {
        guard let transport else { throw JobFailed("The server makes no request outside (FRUS_OFFLINE=true).") }
        let time = now()
        let cached = lastListing.withLock { $0 }
        let body: Data
        if let cached, time.timeIntervalSince(cached.at) < Self.listingReuse, time >= cached.at {
            body = cached.body
        } else {
            var headers = ["User-Agent": Self.userAgent, "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"]
            if let etag = cached?.etag { headers["If-None-Match"] = etag }
            if sources.isGitHub, let githubToken { headers["Authorization"] = "Bearer \(githubToken)" }
            let host = sources.listing.host ?? LibrarySources.apiHost
            let answer: LibraryAnswer
            do {
                answer = try await transport.get(sources.listing, headers: headers, limit: Self.listingLimit, into: nil)
            } catch let error as LibraryTransportError {
                log("GitHub's listing of the volumes could not be read: \(error)")
                throw JobFailed("GitHub's listing of the corpus's volumes could not be read: \(host) gave no answer the server takes.")
            }
            switch answer.status {
            case 200:
                body = answer.body
            case 304 where cached != nil:
                body = cached!.body
            case 429:
                throw JobFailed(Self.rateLimited(answer.headers, token: sources.isGitHub && githubToken != nil))
            case 403 where answer.headers["x-ratelimit-remaining"] == "0":
                throw JobFailed(Self.rateLimited(answer.headers, token: sources.isGitHub && githubToken != nil))
            default:
                throw JobFailed("GitHub's listing of the corpus's volumes could not be read: \(host) answered \(answer.status).")
            }
            let etag = answer.status == 200 ? answer.headers["etag"].flatMap { $0.isEmpty ? nil : $0 } : cached?.etag
            lastListing.withLock { $0 = CachedListing(etag: etag, body: body, at: time) }
        }
        let listed: [GitHubLiveEntry]
        do {
            listed = try GitHubLiveEntry.volumes(inListing: body)
        } catch {
            lastListing.withLock { $0 = nil }
            throw JobFailed("GitHub's listing of the corpus's volumes could not be read: \(sources.listing.host ?? LibrarySources.apiHost)'s answer was no listing.")
        }
        // The kit's diff keys the listing by name, which a listing naming one file twice would trap on: the
        // first of each is kept.
        var names = Set<String>()
        let live = listed.filter { names.insert($0.name).inserted }
        return ManifestDiffResult.diff(bundled: catalogue, live: live)
    }

    /// The sentence for GitHub's rate limit: how many requests an hour it allows this server, and when its
    /// count starts again, from its `X-RateLimit-…` headers.
    static func rateLimited(_ headers: [String: String], token: Bool) -> String {
        let limit = headers["x-ratelimit-limit"].flatMap(Int.init)
        var sentence = "GitHub's limit of \(limit.map(String.init) ?? "60") requests an hour for this server is reached"
        if let reset = headers["x-ratelimit-reset"].flatMap(TimeInterval.init) {
            sentence += " until \(Date(timeIntervalSince1970: reset).formatted(.iso8601))"
        }
        sentence += ", so its listing of the corpus's volumes could not be read"
        return sentence + (token ? "." : ": try again then, or give the server a token (FRUS_GITHUB_TOKEN), which raises the limit.")
    }

    /// Whether an answer says its host limits this server: a 429, or a 403 with GitHub's rate-limit
    /// headers, which a host's own 403 for a file it lacks has not.
    static func isLimited(_ answer: LibraryAnswer) -> Bool {
        answer.status == 429 || (answer.status == 403 && answer.headers["x-ratelimit-remaining"] == "0")
    }

    /// The bytes free on the volume that holds `url`, or nil when the system does not say.
    static func freeBytes(at url: URL) -> Int64? {
        ((try? FileManager.default.attributesOfFileSystem(forPath: url.path))?[.systemFreeSize] as? NSNumber)?.int64Value
    }

    /// One volume: its file from the kit's `downloadUrl`, kept once its length and git blob SHA-1 are the
    /// listing's, renamed into place over any copy; or, when the file in place is that one already, kept as
    /// it is. Then its figure images. Throws `Problem`.
    private func fetchVolume(_ id: String, live: LiveVolumeInfo, job: JobContext, figures: inout FigureHost) async throws {
        guard let entry = entries[id], entry.filename == "\(id).xml", let final = fileURL(id),
              let url = sources.volume(entry), let transport else {
            throw Problem(sentence: "The catalogue gives \(id) no address to download it from.")
        }
        let host = url.host ?? "Its host"
        let time = now()
        do {
            try await Blocking.run { [store] in try store.markLibraryDownloading(id, at: time) }
        } catch {
            log("The library could not record that \(id) is downloading: \(error)")
        }
        let local = await localVolumeInfo(for: id)
        if local?.sha != live.sha || local?.sizeBytes != live.sizeBytes {
            // The user store and its backups share the volume: a download leaves room for them.
            if let free = Self.freeBytes(at: volumesDirectory), free < Int64(live.sizeBytes) + Self.spareBytes {
                let room = "the data volume has \(Self.megabytes(Int(free))) free, and \(entry.filename) needs \(Self.megabytes(live.sizeBytes)) with \(Self.megabytes(Int(Self.spareBytes))) to spare"
                throw Problem(sentence: "Not downloaded: \(room).", stops: room)
            }
            await job.progress("Downloading \(id): \(Self.megabytes(live.sizeBytes))")
            let partial = volumesDirectory.appendingPathComponent(".\(id).xml\(Self.partialSuffix)")
            let answer: LibraryAnswer
            do {
                answer = try await transport.get(url, headers: ["User-Agent": Self.userAgent], limit: live.sizeBytes, into: partial)
            } catch LibraryTransportError.tooLarge {
                throw Problem(sentence: "The file served for \(entry.filename) was longer than the \(live.sizeBytes) bytes GitHub's listing gives it, so it was not kept.")
            } catch LibraryTransportError.unwritable(let why) {
                log("\(id) could not be written to \(volumesDirectory.path): \(why)")
                throw Problem(sentence: "\(entry.filename) could not be written to the volumes folder: the server's log says why.",
                              stops: "the volumes folder could not be written")
            } catch let error as LibraryTransportError {
                log("\(id) could not be downloaded from \(host): \(error)")
                throw Problem(sentence: "\(host) gave no answer the server takes for \(entry.filename).", unreachable: true)
            }
            guard answer.status == 200 else {
                try? FileManager.default.removeItem(at: partial)
                if Self.isLimited(answer) {
                    let limit = "\(host) limits how often this server may ask it\(answer.headers["retry-after"].map { ", and asks it to wait \($0) seconds" } ?? "")"
                    throw Problem(sentence: "Not downloaded: \(limit).", stops: limit)
                }
                throw Problem(sentence: "\(host) answered \(answer.status) for \(entry.filename).")
            }
            // The check, before the file takes its place: its length and its git blob SHA-1, the listing's.
            let check = try? await Blocking.run { () -> (Int, String) in
                let data = try Data(contentsOf: partial, options: .alwaysMapped)
                return (data.count, VolumeUpdateChecker.gitBlobSHA1(for: data))
            }
            guard let (size, sha) = check, size == live.sizeBytes, sha == live.sha else {
                try? FileManager.default.removeItem(at: partial)
                throw Problem(sentence: "The file served for \(entry.filename) is not the one GitHub's listing names, so \(local == nil ? "it was not kept" : "the copy in place was kept"): GitHub may still serve the copy from before a correction, so try again in a few minutes.")
            }
            // A file the index was not made from, in place of a copy, or of none where the index holds the volume
            // from elsewhere, as a seeding export's: the library's indexing owes the volume a pass, kept before the
            // file takes its name, so that a stop meanwhile loses nothing (PLAN's S21f).
            if let hook = fileReplaced.withLock({ $0 }) { hook(id) }
            do {
                try await Blocking.run { try Self.rename(partial, over: final) }
            } catch {
                try? FileManager.default.removeItem(at: partial)
                log("\(id)'s file could not take its place: \(error)")
                throw Problem(sentence: "\(entry.filename) was downloaded and checked, but could not take its place in the volumes folder.",
                              stops: "the volumes folder could not be written")
            }
        }
        await job.progress("Fetching \(id)'s figure images")
        let found = await fetchFigures(id, volumeAt: final, host: &figures)
        var problem: String?
        if found == nil {
            problem = "Its text could not be read for the figure images it names."
        } else if let failed = found?.failed, failed > 0 {
            problem = figures.givenUp.map { "\(failed) of its figure images were not fetched, since \($0): Download asks for them again." }
                ?? "\(failed) of its figure images could not be fetched: Download asks for them again."
        }
        let record = LibraryDownloadRecord(blobSHA: live.sha, sizeBytes: live.sizeBytes, modifiedAt: Self.regularFile(final)?.modified,
                                           figuresStored: found?.stored ?? 0, figuresRefused: found?.refused ?? 0, problem: problem)
        let done = now()
        do {
            try await Blocking.run { [store] in try store.recordLibraryDownload(id, record, at: done) }
        } catch {
            log("The library could not record \(id)'s download: \(error)")
            throw Problem(sentence: "\(entry.filename) was downloaded, but the user store could not record it.")
        }
    }

    /// Renames `partial` over `final`, which it replaces whole or not at all, and flushes the folder, so
    /// that the name is on disk with the file.
    static func rename(_ partial: URL, over final: URL) throws {
        guard posixRename(partial.path, final.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
        let folder = open(final.deletingLastPathComponent().path, O_RDONLY)
        if folder >= 0 {
            _ = fsync(folder)
            close(folder)
        }
    }

    /// Writes `data` to `url`, made afresh and flushed to disk.
    static func writeFlushed(_ data: Data, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteNoPermission) }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    /// Whether the regular file at `url` opens with the PNG signature, the kit's check.
    static func holdsPNG(_ url: URL) -> Bool {
        guard regularFileSize(url) != nil, let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return FigureImagePNG.isPNG((try? handle.read(upToCount: 8)) ?? Data())
    }

    static func megabytes(_ bytes: Int) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }

    /// The figure images `volumeId`'s text at `url` names, as the app's figure library fetches them (#1516):
    /// each from history.state.gov as `<url>.png`, into `<volumeId>.figures/`, one already there and a PNG
    /// not asked for again, one the host refuses (403 or 404) left out, one whose answer is no PNG not kept;
    /// and any image there the text no longer names removed. The job stops asking the image host after
    /// `figurePatience` images in a row with no answer, or once it says it limits this server (`host`). Nil
    /// when the text cannot be read.
    private func fetchFigures(_ volumeId: String, volumeAt url: URL, host: inout FigureHost) async -> (stored: Int, refused: Int, failed: Int)? {
        guard let names = try? await Blocking.run({ LibraryFigureNames.graphicNames(inVolumeAt: url) }),
              let folder = figuresDirectory(volumeId), let transport else { return nil }
        // Each name a file name of one path component, the kit's rule, so that no name reaches outside the folder.
        var fileNames: [String] = []
        for name in names {
            if let file = FigureImageName.fileName(forGraphic: name), FRUSURLScheme.isSafeComponent(file), !fileNames.contains(file) {
                fileNames.append(file)
            }
        }
        let manager = FileManager.default
        switch Self.kind(at: folder) {
        case nil, .typeDirectory?: break
        default: try? manager.removeItem(at: folder)  // a file or a link where the folder goes is no folder of figures
        }
        // The images the text no longer names, as the app's `removeImages(notIn:for:)` removes them: images alone.
        let wanted = Set(fileNames)
        for present in (try? manager.contentsOfDirectory(atPath: folder.path)) ?? [] where present.hasSuffix(".png") && !wanted.contains(present) {
            try? manager.removeItem(at: folder.appendingPathComponent(present))
        }
        if fileNames.isEmpty {
            try? manager.removeItem(at: folder)
            return (0, 0, 0)
        }
        var (stored, refused, failed) = (0, 0, 0)
        for fileName in fileNames {
            let destination = folder.appendingPathComponent(fileName, isDirectory: false)
            if Self.holdsPNG(destination) {
                stored += 1
                continue
            }
            guard host.givenUp == nil, let remote = sources.figure(volumeId: volumeId, fileName: fileName) else {
                failed += 1
                continue
            }
            let answer: LibraryAnswer
            do {
                answer = try await transport.get(remote, headers: ["User-Agent": Self.userAgent], limit: Self.figureLimit, into: nil)
            } catch {
                log("\(volumeId)'s figure image \(fileName) could not be fetched: \(error)")
                failed += 1
                host.unanswered += 1
                if host.unanswered >= Self.figurePatience {
                    host.givenUp = "\(remote.host ?? "the image host") gave no answer for \(Self.figurePatience) images in a row"
                }
                continue
            }
            host.unanswered = 0
            if Self.isLimited(answer) {
                host.givenUp = "\(remote.host ?? "the image host") limits how often this server may ask it"
                failed += 1
                continue
            }
            // 403 is what the image host answers for a file it does not have; a 200 that is no PNG is some
            // other page, not kept.
            if answer.status == 403 || answer.status == 404 {
                refused += 1
                continue
            }
            guard (200..<300).contains(answer.status), FigureImagePNG.isPNG(answer.body) else {
                failed += 1
                continue
            }
            if Self.kind(at: folder) != .typeDirectory {
                do {
                    try manager.createDirectory(at: folder, withIntermediateDirectories: false)
                } catch {
                    log("\(volumeId)'s folder of figure images could not be made: \(error)")
                    failed += 1
                    continue
                }
            }
            let partial = folder.appendingPathComponent(".\(fileName)\(Self.partialSuffix)")
            do {
                try Self.writeFlushed(answer.body, to: partial)
                try Self.rename(partial, over: destination)
                stored += 1
            } catch {
                try? manager.removeItem(at: partial)
                log("\(volumeId)'s figure image \(fileName) could not be written: \(error)")
                failed += 1
            }
        }
        return (stored, refused, failed)
    }

    // MARK: Remove

    /// Removes a downloaded volume's file and figure images, and forgets it: refused while a job waits for
    /// it or fetches it, which the store's forgetting checks in one step, and in Import mode, whose folder
    /// is the operator's. A side-loaded volume the catalogue does not list is removed by its file's name
    /// (PLAN's S21e), with the sidecar the kit's `LocalVolumeCatalog` wrote beside it.
    public func remove(_ volumeId: String) async throws {
        guard mode == .standalone else { throw LibraryRefusal.importMode }
        guard entries[volumeId] != nil || isVolumeDownloaded(volumeId), let file = fileURL(volumeId),
              let folder = figuresDirectory(volumeId) else {
            throw LibraryRefusal.unknownVolume(volumeId)
        }
        let sidecar = volumesDirectory.appendingPathComponent("\(volumeId).frusmeta.json")
        let present = isVolumeDownloaded(volumeId) || Self.kind(at: folder) != nil
        let forgotten = try await Blocking.run { [store] in try store.forgetLibraryVolume(volumeId) }
        switch forgotten {
        case .heldByADownload: throw LibraryRefusal.inProgress(volumeId)
        case .nothing where !present: throw LibraryRefusal.notDownloaded(volumeId)
        case .nothing, .forgotten: break
        }
        try await Blocking.run {
            for url in [file, folder, sidecar] where Self.kind(at: url) != nil { try FileManager.default.removeItem(at: url) }
        }
        log("Removed \(volumeId)'s file and figure images from the library")
    }

    // MARK: Side-load (PLAN's S21e)

    /// The largest file a side-load takes, the row's.
    public static let sideloadLimit = 64 * 1_048_576
    /// The prefix of a side-load's staging folder, hidden by its dot, which `prepare()` removes at a start.
    static let stagingPrefix = ".sideload-"

    /// The volume id a side-loaded file's name gives, as the app's validator takes it (the name less its
    /// extension), or nil for a name the server takes no volume by: one that is not `<id>.xml`, or whose id
    /// is not a name of letters, digits, `.`, `_` and `-`, beginning with a letter or a digit, of 128
    /// characters at most, so that the id, which becomes a file's name, is one path component, hidden by
    /// no dot, and no other volume's sidecar or figures folder.
    public static func sideloadedVolumeId(fromFileName name: String) -> String? {
        guard name.hasSuffix(".xml") else { return nil }
        let id = String(name.dropLast(4))
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard (1...128).contains(id.count), id.allSatisfy(allowed.contains), let first = id.first, first.isLetter || first.isNumber,
              !id.hasSuffix(".figures"), !id.hasSuffix(".frusmeta"), FRUSURLScheme.isSafeComponent(id) else { return nil }
        return id
    }

    /// Why a side-load is refused.
    public enum SideloadRefusal: Error, Equatable, Sendable {
        /// An Import server's folder is the operator's mount.
        case importMode
        /// A volume of that id is in the library already, or a download waits for it or fetches it: the
        /// kit's sentence, or the server's.
        case exists(String, sentence: String)
        /// The kit's `SideloadValidator` refused the file, in its sentence.
        case notAVolume(String)
        /// The data volume would keep less than 64 MB free beyond the file.
        case noRoom(String)
    }

    /// A staging folder of its own for one upload, hidden in the volumes folder, and the file the upload is
    /// written to there, `<volumeId>.xml`, the name the kit's validator takes the volume's id from.
    public func sideloadStaging(for volumeId: String) throws -> URL {
        let folder = volumesDirectory.appendingPathComponent("\(Self.stagingPrefix)\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder.appendingPathComponent("\(volumeId).xml")
    }

    /// Side-loads the file at `staged`, which `sideloadStaging(for:)` gave and an upload wrote (PLAN's S21e):
    /// the kit's `SideloadValidator` reads it, with the parser's external entities off, as the kit's parsers
    /// keep them, and copies it into a hidden folder of the library's own; there it is flushed, and it takes
    /// its name in the volumes folder by `link(2)`, which refuses a name taken meanwhile, so that it is in
    /// place whole or not at all, as a download's file is; and its row says it was side-loaded
    /// (`sideloaded = 1`), with its length, modification time and git blob SHA-1, the kit's. The staging
    /// folder goes, however it ends. Gives the volume's id; throws `SideloadRefusal`.
    public func sideload(staged: URL, requestedBy: String?) async throws -> String {
        let folder = staged.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: folder) }
        guard mode == .standalone else { throw SideloadRefusal.importMode }
        let volumeId = staged.deletingPathExtension().lastPathComponent
        guard let destination = fileURL(volumeId) else { throw SideloadRefusal.notAVolume("The file's name names no volume.") }
        if let row = try? await Blocking.run({ [store] in try store.libraryVolume(volumeId) }), row.isUnfinished {
            throw SideloadRefusal.exists(volumeId, sentence: "A download of \(volumeId) is queued or under way.")
        }
        let size = Int64(Self.regularFileSize(staged) ?? 0)
        if let free = Self.freeBytes(at: volumesDirectory), free < 2 * size + Self.spareBytes {
            throw SideloadRefusal.noRoom("The data volume has \(Self.megabytes(Int(free))) free, and side-loading this file needs about \(Self.megabytes(Int(2 * size + Self.spareBytes))), with room for the user store and its backups.")
        }
        let checked = folder.appendingPathComponent("checked", isDirectory: true)
        try FileManager.default.createDirectory(at: checked, withIntermediateDirectories: false)
        do {
            _ = try await Blocking.run { try SideloadValidator().validate(url: staged, volumesDirectory: checked) }
        } catch let error as SideloadError {
            throw SideloadRefusal.notAVolume(error.errorDescription ?? "The file is not a FRUS volume.")
        }
        let copy = checked.appendingPathComponent("\(volumeId).xml")
        // A volume the catalogue lacks is listed by its own header, which the kit's `LocalVolumeCatalog` reads
        // (PLAN's S21e): one it cannot read would be listed nowhere, so it is refused, as the app leaves it out.
        if entries[volumeId] == nil {
            let bytes = Self.regularFileSize(copy) ?? 0
            guard try await Blocking.run({ LocalVolumeCatalog.entry(volumeId: volumeId, url: copy, sizeBytes: bytes) }) != nil else {
                throw SideloadRefusal.notAVolume("Its TEI header could not be read, so the volume could not be listed: the catalogue does not know \(volumeId), and a side-loaded volume is described by its own header.")
            }
        }
        // The kit's duplicate check is the volumes folder's here, made in one step by the link.
        let placed = try await Blocking.run { () -> Int32 in
            try Self.flush(copy)
            return link(copy.path, destination.path) == 0 ? 0 : errno
        }
        if placed == EEXIST {
            throw SideloadRefusal.exists(volumeId, sentence: SideloadError.duplicateVolume(volumeId: volumeId).errorDescription
                                             ?? "Volume \(volumeId) is already present.")
        }
        guard placed == 0 else {
            throw LibraryFolderError(path: volumesDirectory.path, underlying: String(cString: strerror(placed)))
        }
        Self.flushFolder(volumesDirectory)
        let time = now()
        guard let file = Self.regularFile(destination) else { return volumeId }
        let sha = try? await Blocking.run { VolumeUpdateChecker.gitBlobSHA1(for: try Data(contentsOf: destination, options: .alwaysMapped)) }
        do {
            try await Blocking.run { [store] in
                try store.recordLibrarySideload(volumeId, LibraryDownloadRecord(blobSHA: sha ?? "", sizeBytes: file.size, modifiedAt: file.modified,
                                                                                 figuresStored: 0, figuresRefused: 0),
                                                requestedBy: requestedBy, at: time)
            }
        } catch {
            log("The library could not record that \(volumeId) was side-loaded: \(error)")
        }
        log("Side-loaded \(volumeId), \(file.size) bytes, into the library")
        return volumeId
    }

    /// Flushes a file's bytes to the disk.
    static func flush(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else { throw CocoaError(.fileReadUnknown) }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }

    /// Flushes a folder, so that a name it took is kept through a loss of power.
    static func flushFolder(_ url: URL) {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else { return }
        _ = fsync(descriptor)
        close(descriptor)
    }
}

/// POSIX `rename(2)`, which replaces its destination in one step: a name of its own, apart from
/// `VolumeLibrary.rename(_:over:)`.
private func posixRename(_ from: String, _ to: String) -> Int32 {
    rename(from, to)
}

/// The volumes a download job fetched, as it goes, for the library's indexing (PLAN's S21d).
actor FetchedVolumes {
    private(set) var ids: [String] = []
    func add(_ id: String) { ids.append(id) }
}
