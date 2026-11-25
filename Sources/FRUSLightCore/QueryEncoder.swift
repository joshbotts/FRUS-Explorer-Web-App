// Search by meaning's encoder (PLAN's S27b): llama.cpp's llama-server, built at the commit the pinned app
// names, over EmbeddingGemma 2's GGUF in the image, which the image's build held to the bundled index's
// digest. The server starts it as a child at the first query, on 127.0.0.1 alone with a key of that start's
// own, waits for its health, embeds each query under the kit's prompt, stops it after the app's 180 idle
// seconds and at the server's end, and starts it again when a query finds it gone. The app runs the same
// model in its own process through llama.cpp's C API (`SemanticQueryEncoder`); the server runs llama.cpp's
// own server beside it, so that the encoder's memory is given back when it stops, and a crash of the
// encoder is never the server's.
//
// What the encoder answers is the app's: the query is `SemanticQueryPrompt.queryPrefix` and the reader's
// words, tokenized with the model's special tokens, as the app's `llama_tokenize` call does; a query past
// the app's 2,048 tokens is refused, never cut; and the pooled vector arrives as the model computed it,
// unnormalised, so that it is normalised here exactly as the app normalises it, in double precision. Each
// exchange with the child is one HTTP/1.1 request on a connection of its own, through NIO, as the PDF
// service's are.

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
import NIOCore
import NIOPosix
import SemanticVectorsKit
import Synchronization
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - The model

/// The search model in the image, as the bundled vectors' index names the model they were made with.
public struct SearchModel: Sendable, Equatable, Codable {
    /// The file's name, the app's (`SemanticModelStore`).
    public static let fileName = "embeddinggemma-2-Q8_0.gguf"
    /// The length the app publishes (`SemanticModelStore.publishedBytes`), which the image's build holds the file to.
    public static let publishedBytes = 309_855_456
    /// The longest query, in tokens: the app's (`SemanticQueryEncoder.maxTokens`), the one physical batch a
    /// query is embedded in, since the model's attention cannot split one. A query past it is refused, never cut.
    public static let maxTokens = 2_048
    /// The bundled index the server reads the model's digest from.
    public static let indexFile = "semantic-vectors-index.json"
    /// The kit's prompt for a query, which the reader's words follow.
    public static let queryPrefix = SemanticQueryPrompt.queryPrefix

    /// The model's name in the bundled provenance, `embeddinggemma-2-Q8_0`.
    public var name: String
    /// The SHA-256 the bundled provenance names, which the file must have, in lowercase hex.
    public var sha256: String
    /// The width the model answers with: the provenance's native width, 768.
    public var dimensions: Int

    public init(name: String, sha256: String, dimensions: Int) {
        self.name = name
        self.sha256 = sha256
        self.dimensions = dimensions
    }

    /// What the bundled index in `resources` says of the model, read through the kit's types.
    public static func bundled(in resources: URL) throws -> SearchModel {
        let url = resources.appendingPathComponent(indexFile)
        do {
            let index = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self, from: Data(contentsOf: url))
            return SearchModel(name: index.provenance.model, sha256: index.provenance.modelFileSHA256.lowercased(),
                               dimensions: index.provenance.nativeDims)
        } catch {
            throw EncoderRefusal.unavailable("the bundled vectors' index, \(url.path), could not be read: \(error)")
        }
    }

    /// The SHA-256 of the file at `url`, read in 4 MB slices, as the app's store hashes the model.
    public static func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let slice = try handle.read(upToCount: 4 * 1_048_576), !slice.isEmpty {
            hash.update(data: slice)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - What the encoder is given, and what it answers

/// How the server runs its encoder: `FRUS_ENCODER`, the binary and the model in the image, the model the
/// bundled index names, and the app's idle window.
public struct EncoderSettings: Sendable {
    /// `FRUS_ENCODER`: off, the encoder never starts, and the server offers no search by meaning.
    public var enabled: Bool
    /// llama.cpp's `llama-server`, the image's.
    public var binary: URL
    /// The GGUF the image holds.
    public var model: URL
    /// What the bundled index names, which the model's file must be; nil when the index could not be read,
    /// which keeps the encoder from starting, and `bundledProblem` says why.
    public var bundled: SearchModel?
    public var bundledProblem: String?
    /// How long the encoder stays loaded after its last query: the app's 180 seconds
    /// (`SemanticOnDeviceEncoder.encoderIdleSeconds`).
    public var idleTimeout: Duration
    /// The longest the server waits for a start's health, and for a query's answer.
    public var startTimeout: Duration
    public var queryTimeout: Duration
    /// How long a stop waits for the child to end after it is asked to, before it is killed.
    public var stopTimeout: Duration

    /// The app's idle window.
    public static let appIdleTimeout: Duration = .seconds(180)

    public init(enabled: Bool, binary: URL, model: URL, bundled: SearchModel?, bundledProblem: String? = nil,
                idleTimeout: Duration = EncoderSettings.appIdleTimeout, startTimeout: Duration = .seconds(120),
                queryTimeout: Duration = .seconds(120), stopTimeout: Duration = .seconds(10)) {
        self.enabled = enabled
        self.binary = binary
        self.model = model
        self.bundled = bundled
        self.bundledProblem = bundledProblem
        self.idleTimeout = idleTimeout
        self.startTimeout = startTimeout
        self.queryTimeout = queryTimeout
        self.stopTimeout = stopTimeout
    }

    /// The server's: `FRUS_ENCODER` and the image's binary and model, with the bundled index read from the
    /// app's data files.
    public init(configuration: ServerConfiguration) {
        var bundled: SearchModel?
        var problem: String?
        do {
            bundled = try SearchModel.bundled(in: configuration.resourcesDirectory)
        } catch {
            problem = "\(error)"
        }
        self.init(enabled: configuration.encoder, binary: configuration.encoderBinary, model: configuration.encoderModel,
                  bundled: bundled, bundledProblem: problem)
    }
}

/// One query embedded: the 768 values the app's encoder gives for it, of unit length as the app's are.
public struct QueryEmbedding: Sendable, Equatable {
    /// The vector, normalised in double precision as the app's `SemanticQueryEncoder` normalises it.
    public var vector: [Double]
    /// The tokens the query took, its prompt and the model's special tokens included.
    public var tokens: Int
    /// The time it took, a start of the encoder included.
    public var seconds: Double
    /// Whether this query started the encoder.
    public var started: Bool
}

/// Why a query was not embedded, in words a reader is shown.
public enum EncoderRefusal: Error, Equatable, Sendable, CustomStringConvertible {
    /// `FRUS_ENCODER=off`.
    case off
    /// The image lacks the binary or the model, or the model is not the one the bundled vectors were made with.
    case unavailable(String)
    /// The query has no words.
    case emptyQuery
    /// The query is past the app's 2,048 tokens; nil when it was refused by its length before it was tokenized.
    case tooLong(tokens: Int?)
    /// The encoder did not start, or did not answer.
    case failed(String)

    /// The app's words for a query too long for the model (`search.semantic.error.tooLong`), which the server
    /// gives as they are: SemanticMirrorParityTests holds them to the app's.
    public static let tooLongWords = "This search is too long for the model. Try a shorter phrasing."
    /// The app's words for a search the encoder could not run (`search.semantic.error.failed.mac`).
    public static let failedWords = "Semantic search could not run. Try again."

    public var description: String {
        switch self {
        case .off:
            "This server does not search by meaning: FRUS_ENCODER is off, so its encoder does not start."
        case .unavailable(let reason):
            "This server cannot search by meaning: \(reason)."
        case .emptyQuery:
            "A search by meaning needs words to search for."
        case .tooLong(let tokens?):
            "\(Self.tooLongWords) It is \(tokens.formatted(.number.locale(Locale(identifier: "en_US")))) tokens, of \(SearchModel.maxTokens.formatted(.number.locale(Locale(identifier: "en_US")))) at most."
        case .tooLong(nil):
            Self.tooLongWords
        case .failed(let reason):
            "\(Self.failedWords) The encoder \(reason)."
        }
    }
}

/// What Administration ▸ Semantic's Search Model and `frus-light semantic` say: the model in the image, its
/// size and digest held to the bundled index's, the engine, and the encoder's setting and state.
public struct EncoderReport: Codable, Sendable, Equatable {
    public struct Model: Codable, Sendable, Equatable {
        /// The model's name in the bundled provenance, and the file's name and path.
        public var name: String?
        public var file: String
        public var path: String
        /// Whether the file is there, and its length; the length the app publishes.
        public var present: Bool
        public var bytes: Int?
        public var publishedBytes: Int
        /// Its SHA-256, read once a server runs, and the one the bundled index names.
        public var sha256: String?
        public var bundledSHA256: String?
        /// Whether the file is the bundled index's model; nil while that cannot be told.
        public var verified: Bool?
        /// The licence the model is under.
        public var licence: String
    }

    public struct Engine: Codable, Sendable, Equatable {
        public var path: String
        public var present: Bool
        /// The binary's own `--version` line, such as `version: 0.6.0-dev (build 1, commit a0e6dc7)`, and the
        /// commit it names.
        public var version: String?
        public var commit: String?
    }

    /// `FRUS_ENCODER`: `on` or `off`.
    public var setting: String
    /// `off`, `unavailable`, `idle`, `starting`, `loaded` or `stopping`.
    public var state: String
    public var model: Model
    public var engine: Engine
    /// The app's idle window, in seconds.
    public var idleSeconds: Int
    /// While it is loaded: since when, its process, and the memory it holds, where the system says.
    public var loadedAt: String?
    public var pid: Int?
    public var residentBytes: Int?
    /// The last query's time, and when the encoder stops unless another comes.
    public var lastQueryAt: String?
    public var stopsAt: String?
    /// The queries embedded and the starts since the server started.
    public var queries: Int
    public var starts: Int
    /// The longest query, in tokens.
    public var maxTokens: Int
    /// What last went wrong, in words, while it still holds.
    public var problem: String?
}

// MARK: - The encoder

/// The server's one encoder: a `llama-server` child it starts and stops, which serves one query at a time.
public actor QueryEncoder {
    public nonisolated let settings: EncoderSettings
    private let log: @Sendable (String) -> Void

    /// The child while it runs: starting until its health answers, then loaded.
    private var child: Child?
    /// The start under way, which a second query waits for.
    private var starting: Task<Child, any Error>?
    /// Queries being embedded now, which an idle stop waits for.
    private var inFlight = 0
    /// Moved by each query, so that an idle stop scheduled before it stops nothing.
    private var useStamp = 0
    private var idleStop: Task<Void, Never>?
    private var lastQuery: Date?
    private var queries = 0
    private var starts = 0
    /// What last went wrong, until a start succeeds.
    private var problem: String?
    /// Set once the server is ending, after which nothing starts.
    private var shutDown = false
    /// The model's check, run once: its digest against the bundled index's.
    private var modelCheck: Task<ModelCheck, Never>?
    private var engineVersion: Task<String?, Never>?

    public init(settings: EncoderSettings, log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.settings = settings
        self.log = log
    }

    /// An encoder that never starts, for a router a test builds without one.
    public static let none = QueryEncoder(settings: EncoderSettings(
        enabled: false, binary: URL(fileURLWithPath: "/nonexistent/llama-server"),
        model: URL(fileURLWithPath: "/nonexistent/\(SearchModel.fileName)"), bundled: nil))

    // MARK: Embedding

    /// The longest query the server sends the encoder, in bytes of UTF-8: one far past 2,048 tokens of any
    /// text, refused as too long without asking the model.
    public static let longestQueryBytes = 65_536

    /// Embeds `query`, the reader's words, under the kit's prompt, starting the encoder if it is not running,
    /// and once more if it was found gone.
    public func embed(_ query: String) async throws -> QueryEmbedding {
        guard settings.enabled else { throw EncoderRefusal.off }
        let words = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { throw EncoderRefusal.emptyQuery }
        guard query.utf8.count <= Self.longestQueryBytes else { throw EncoderRefusal.tooLong(tokens: nil) }
        let began = ContinuousClock.now
        inFlight += 1
        useStamp += 1
        idleStop?.cancel()
        defer {
            inFlight -= 1
            lastQuery = Date()
            scheduleIdleStop()
        }
        // The reader's words as they came, after the prompt, as the app appends them.
        let prompt = SearchModel.queryPrefix + query
        var started = false
        for attempt in 1...2 {
            let (running, didStart) = try await runningChild()
            started = started || didStart
            do {
                let tokens = try await running.tokenCount(prompt, timeout: settings.queryTimeout)
                guard tokens <= SearchModel.maxTokens else { throw EncoderRefusal.tooLong(tokens: tokens) }
                let raw = try await running.pooledEmbedding(prompt, timeout: settings.queryTimeout)
                guard let width = settings.bundled?.dimensions, raw.count == width else {
                    throw EncoderRefusal.failed("answered \(raw.count) values, where the model gives \(settings.bundled?.dimensions ?? 0)")
                }
                queries += 1
                return QueryEmbedding(vector: Self.normalised(raw), tokens: tokens, seconds: Self.seconds(ContinuousClock.now - began),
                                      started: started)
            } catch let error as EncoderRefusal {
                throw error
            } catch ChildError.tooLarge(let tokens) {
                throw EncoderRefusal.tooLong(tokens: tokens)
            } catch {
                // Gone between two queries, as a kill leaves it: started again, once.
                if attempt == 1, !running.isRunning {
                    forget(running, because: "stopped before it answered: \(running.exitDescription())")
                    continue
                }
                throw EncoderRefusal.failed("did not answer: \(error)")
            }
        }
        throw EncoderRefusal.failed("stopped twice before it answered")
    }

    /// The pooled vector normalised as the app's encoder normalises it (`SemanticQueryEncoder.encode`): the
    /// sum of squares in double precision, and each value times its inverse square root.
    public static func normalised(_ pooled: [Double]) -> [Double] {
        var sum = 0.0
        for value in pooled { sum += value * value }
        let norm = sum > 0 ? 1.0 / sum.squareRoot() : 0.0
        return pooled.map { $0 * norm }
    }

    // MARK: The child's lifetime

    /// The child, started if it is not running, and whether this call started it.
    private func runningChild() async throws -> (Child, Bool) {
        if let child, child.isReady, child.isRunning { return (child, false) }
        if let child, !child.isRunning {
            forget(child, because: "stopped: \(child.exitDescription())")
        }
        if let starting { return (try await starting.value, false) }
        guard !shutDown else { throw EncoderRefusal.failed("is stopping with the server") }
        let task = Task { try await self.start() }
        starting = task
        defer { starting = nil }
        do {
            return (try await task.value, true)
        } catch {
            throw error
        }
    }

    /// Starts the child: the model checked first, once; then `llama-server` on a free port of 127.0.0.1 with
    /// a key of its own, until its health answers. A start whose port another took in the meantime is tried
    /// again on another.
    private func start() async throws -> Child {
        let check = await checkModel()
        if let refusal = check.refusal {
            problem = refusal.description
            throw refusal
        }
        var lastFailure = ""
        for _ in 1...2 {
            let began = ContinuousClock.now
            let child: Child
            do {
                child = try Child.launch(settings: settings, log: log) { [weak self] pid in
                    Task { await self?.childEnded(pid: pid) }
                }
            } catch {
                problem = "could not start: \(error)"
                throw EncoderRefusal.failed("could not start: \(error)")
            }
            self.child = child
            starts += 1
            do {
                try await child.waitUntilReady(within: settings.startTimeout)
                problem = nil
                log("The encoder started: \(settings.binary.lastPathComponent) on 127.0.0.1:\(child.port), process \(child.pid), ready in \(Self.spoken(ContinuousClock.now - began)), over \(settings.model.path)")
                return child
            } catch {
                await child.stop(within: settings.stopTimeout)
                await child.waitForOutput(within: .seconds(3))
                if self.child === child { self.child = nil }
                lastFailure = "\(error)"
                let output = child.lastLines(12)
                log("The encoder did not start: \(error)\(output.isEmpty ? "" : ". Its last words:\n" + output.joined(separator: "\n"))")
                // A port taken before the child bound it is the one failure worth a second start.
                guard output.contains(where: { $0.localizedCaseInsensitiveContains("bind") }) else { break }
            }
        }
        problem = "did not start: \(lastFailure)"
        throw EncoderRefusal.failed("did not start: \(lastFailure)")
    }

    /// Called from the child's termination handler.
    private func childEnded(pid: Int32) {
        guard let child, child.pid == pid, !child.stopRequested else { return }
        forget(child, because: "stopped: \(child.exitDescription())")
    }

    /// Lets go of a child that has ended without being asked, saying so; the next query starts another.
    private func forget(_ ended: Child, because reason: String) {
        guard child === ended else { return }
        child = nil
        problem = "The encoder \(reason). The next search by meaning starts it again."
        let output = ended.lastLines(12)
        log("The encoder \(reason)\(output.isEmpty ? "" : ". Its last words:\n" + output.joined(separator: "\n"))")
    }

    private func scheduleIdleStop() {
        guard inFlight == 0, child != nil else { return }
        let stamp = useStamp
        idleStop?.cancel()
        idleStop = Task { [settings] in
            try? await Task.sleep(for: settings.idleTimeout)
            guard !Task.isCancelled else { return }
            await self.stopIfIdle(since: stamp)
        }
    }

    private func stopIfIdle(since stamp: Int) async {
        guard stamp == useStamp, inFlight == 0, let child, starting == nil else { return }
        self.child = nil
        await child.stop(within: settings.stopTimeout)
        log("The encoder stopped after \(Self.spoken(settings.idleTimeout)) without a search, giving back its memory: the next search by meaning starts it again")
    }

    /// Stops the child, at the server's end. Nothing starts after it.
    public func shutdown() async {
        shutDown = true
        idleStop?.cancel()
        starting?.cancel()
        if let child {
            self.child = nil
            await child.stop(within: settings.stopTimeout)
            log("The encoder stopped with the server")
        }
    }

    // MARK: The model's check

    struct ModelCheck: Sendable {
        var bytes: Int?
        var sha256: String?
        var refusal: EncoderRefusal?
    }

    /// The binary and the model there, and the model the bundled index's: read once, as hashing reads its
    /// 310 MB.
    private func checkModel() async -> ModelCheck {
        if let modelCheck { return await modelCheck.value }
        let settings = settings
        let task = Task<ModelCheck, Never> {
            guard let bundled = settings.bundled else {
                return ModelCheck(refusal: .unavailable(settings.bundledProblem ?? "the bundled vectors' index could not be read"))
            }
            guard Self.isExecutable(settings.binary) else {
                return ModelCheck(refusal: .unavailable("the image holds no encoder at \(settings.binary.path)"))
            }
            guard let bytes = Self.size(of: settings.model) else {
                return ModelCheck(refusal: .unavailable("the image holds no search model at \(settings.model.path)"))
            }
            let digest: String
            do {
                digest = try await Blocking.run { try SearchModel.digest(of: settings.model) }
            } catch {
                return ModelCheck(bytes: bytes, refusal: .unavailable("its search model at \(settings.model.path) could not be read: \(error)"))
            }
            guard digest == bundled.sha256 else {
                return ModelCheck(bytes: bytes, sha256: digest, refusal: .unavailable(
                    "its search model, \(settings.model.path), is not the one the bundled vectors were made with: its SHA-256 is \(digest), where the bundled index names \(bundled.sha256)"))
            }
            return ModelCheck(bytes: bytes, sha256: digest)
        }
        modelCheck = task
        return await task.value
    }

    nonisolated static func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }

    nonisolated static func size(of url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }

    // MARK: The report

    /// What Administration ▸ Semantic's Search Model says. It reads the model's digest the first time it is
    /// asked, and the engine's version.
    public func report() async -> EncoderReport {
        let check = await checkModel()
        let version = await engine()
        let bundled = settings.bundled
        let present = Self.size(of: settings.model)
        var state: String
        if !settings.enabled {
            state = "off"
        } else if check.refusal != nil {
            state = "unavailable"
        } else if starting != nil {
            state = "starting"
        } else if let child, child.isRunning, child.isReady {
            state = "loaded"
        } else {
            state = "idle"
        }
        var report = EncoderReport(
            setting: settings.enabled ? "on" : "off", state: state,
            model: .init(name: bundled?.name, file: settings.model.lastPathComponent, path: settings.model.path,
                         present: present != nil, bytes: present, publishedBytes: SearchModel.publishedBytes,
                         sha256: check.sha256, bundledSHA256: bundled?.sha256,
                         verified: check.sha256.map { $0 == bundled?.sha256 }, licence: "Apache 2.0"),
            engine: .init(path: settings.binary.path, present: Self.isExecutable(settings.binary), version: version,
                          commit: version.flatMap(Self.commit(inVersion:))),
            idleSeconds: Int(settings.idleTimeout.components.seconds), queries: queries, starts: starts,
            maxTokens: SearchModel.maxTokens,
            problem: check.refusal.map(\.description) ?? problem)
        if state == "loaded", let child {
            report.loadedAt = child.readyAt?.formatted(.iso8601)
            report.pid = Int(child.pid)
            report.residentBytes = Self.residentBytes(of: child.pid)
        }
        if let lastQuery {
            report.lastQueryAt = lastQuery.formatted(.iso8601)
            if state == "loaded", inFlight == 0 {
                report.stopsAt = lastQuery.addingTimeInterval(Self.seconds(settings.idleTimeout)).formatted(.iso8601)
            }
        }
        return report
    }

    /// The binary's `--version` line, read once.
    private func engine() async -> String? {
        if let engineVersion { return await engineVersion.value }
        let binary = settings.binary
        let task = Task<String?, Never> { await Self.versionLine(of: binary) }
        engineVersion = task
        return await task.value
    }

    /// `llama-server --version`'s line, `version: 0.6.0-dev (build 1, commit a0e6dc7)`, or nil.
    public static func versionLine(of binary: URL) async -> String? {
        guard isExecutable(binary) else { return nil }
        return try? await Blocking.run {
            let process = Process()
            process.executableURL = binary
            process.arguments = ["--version"]
            process.environment = Child.environment(key: nil)
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            process.standardInput = FileHandle.nullDevice
            try process.run()
            try? output.fileHandleForWriting.close()
            let data = (try? output.fileHandleForReading.readToEnd()) ?? Data()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline).map(String.init)
                .first { $0.hasPrefix("version:") }
        }
    }

    /// The commit a version line names: `a0e6dc7` of `version: 0.6.0-dev (build 1, commit a0e6dc7)`, as the
    /// app's fixture script reads it.
    public static func commit(inVersion line: String) -> String? {
        line.firstMatch(of: /version: \S+ \((?:build \d+, commit )?([0-9a-f]{7,40})\)/).map { String($0.1) }
    }

    /// The memory a process holds, its resident set, where /proc says: Linux's.
    public static func residentBytes(of pid: Int32) -> Int? {
        guard let status = try? String(contentsOfFile: "/proc/\(pid)/status", encoding: .utf8),
              let line = status.split(separator: "\n").first(where: { $0.hasPrefix("VmRSS:") }),
              let kilobytes = line.split(whereSeparator: \.isWhitespace).dropFirst().first.flatMap({ Int($0) })
        else { return nil }
        return kilobytes * 1_024
    }

    /// A `llama-server` this machine runs over `model` from `binary`, as /proc names it: its process and the
    /// port its command line gives.
    public struct RunningProcess: Sendable, Equatable {
        public var pid: Int32
        public var port: Int?
    }

    /// The encoders running from `binary` over `model`, read from /proc as `ps` reads it, for `frus-light
    /// semantic`, which is not the server and so holds no child of its own; none where there is no /proc.
    public static func runningProcesses(binary: URL, model: URL) -> [RunningProcess] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: "/proc") else { return [] }
        var found: [RunningProcess] = []
        for entry in entries {
            guard let pid = Int32(entry), let data = FileManager.default.contents(atPath: "/proc/\(entry)/cmdline") else { continue }
            let arguments = data.split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
            guard arguments.first == binary.path,
                  let given = arguments.firstIndex(of: "--model").map({ $0 + 1 }).flatMap({ arguments.indices.contains($0) ? arguments[$0] : nil }),
                  given == model.path else { continue }
            let port = arguments.firstIndex(of: "--port").map { $0 + 1 }.flatMap { arguments.indices.contains($0) ? Int(arguments[$0]) : nil }
            found.append(RunningProcess(pid: pid, port: port))
        }
        return found.sorted { $0.pid < $1.pid }
    }

    nonisolated static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// A duration as the log says it.
    nonisolated static func spoken(_ duration: Duration) -> String {
        let seconds = seconds(duration)
        if seconds >= 60, seconds.truncatingRemainder(dividingBy: 60) == 0 { return "\(Int(seconds) / 60) minutes" }
        return seconds >= 10 ? "\(Int(seconds.rounded())) seconds" : String(format: "%.1f seconds", seconds)
    }
}

// MARK: - The child

/// Why an exchange with the child failed.
enum ChildError: Error, CustomStringConvertible {
    /// It could not be reached, or did not answer in time.
    case unreachable(String)
    /// It answered with an error: its status and its message.
    case refused(status: Int, message: String)
    /// Its answer could not be read.
    case badAnswer(String)
    /// It refused a query past its batch, with the tokens it counted.
    case tooLarge(tokens: Int?)
    /// It ended before its health answered.
    case ended(String)

    var description: String {
        switch self {
        case .unreachable(let reason): reason
        case .refused(let status, let message): "answered \(status)\(message.isEmpty ? "" : ": \(message)")"
        case .badAnswer(let reason): reason
        case .tooLarge(let tokens): "refused \(tokens.map { "\($0) tokens" } ?? "the query") as too many for its batch"
        case .ended(let reason): reason
        }
    }
}

/// One `llama-server` process, from its start to its end: its port and key, its health, its last words, and
/// the two requests a query makes.
final class Child: @unchecked Sendable {
    let process: Process
    let pid: Int32
    let port: Int
    /// The key this start was given, which every request but the health check sends.
    private let key: String
    private let state = Mutex<(readyAt: Date?, stopRequested: Bool, lines: [String], partial: String, outputEnded: Bool)>(
        (nil, false, [], "", false))

    /// The lines of its output kept, its last.
    static let keptLines = 60

    private init(process: Process, port: Int, key: String) {
        self.process = process
        self.pid = process.processIdentifier
        self.port = port
        self.key = key
    }

    var isRunning: Bool { process.isRunning }
    var isReady: Bool { state.withLock { $0.readyAt != nil } }
    var readyAt: Date? { state.withLock { $0.readyAt } }
    var stopRequested: Bool { state.withLock { $0.stopRequested } }

    func lastLines(_ count: Int) -> [String] { state.withLock { Array($0.lines.suffix(count)) } }

    /// How it ended, in words: its status or the signal that ended it.
    func exitDescription() -> String {
        guard !process.isRunning else { return "it is still running" }
        let status = process.terminationStatus
        switch process.terminationReason {
        case .uncaughtSignal: return "ended by signal \(status)\(Self.signalName(status).map { " (\($0))" } ?? "")"
        case .exit: return "exited with status \(status)"
        @unknown default: return "ended with status \(status)"
        }
    }

    static func signalName(_ signal: Int32) -> String? {
        [4: "SIGILL: this processor may lack an instruction the build needs", 6: "SIGABRT", 9: "SIGKILL", 11: "SIGSEGV", 15: "SIGTERM"][signal]
    }

    /// The child's environment: the paths, the locale and the allocator's arenas the parent's has, the image's
    /// `MALLOC_ARENA_MAX` among them, and the start's key, nothing else, so that none of the server's own
    /// settings, a password among them, reaches it, and no `LLAMA_ARG_*` of the environment changes what the
    /// command line asks.
    static let passedOn: Set<String> = ["PATH", "HOME", "TZ", "LANG", "LC_ALL", "LC_CTYPE", "TMPDIR", "MALLOC_ARENA_MAX"]

    static func environment(key: String?) -> [String: String] {
        let parent = ProcessInfo.processInfo.environment
        var environment = parent.filter { passedOn.contains($0.key) }
        if environment["PATH"] == nil { environment["PATH"] = "/usr/local/bin:/usr/bin:/bin" }
        if let key { environment["LLAMA_API_KEY"] = key }
        return environment
    }

    /// The command line: the model, embeddings alone, 127.0.0.1 at `port`, and the app's context and batch
    /// (`SemanticQueryEncoder.load`): the model's own context, a physical batch of the app's 2,048 tokens, one
    /// sequence, pooling and attention as the GGUF declares them, and no warm-up, as the app loads the model;
    /// with none of the server's web UI, slots' list or automatic fitting.
    static func arguments(model: URL, port: Int) -> [String] {
        ["--model", model.path, "--embedding", "--host", "127.0.0.1", "--port", String(port),
         "--ctx-size", "0", "--batch-size", String(SearchModel.maxTokens), "--ubatch-size", String(SearchModel.maxTokens),
         "--parallel", "1", "--fit", "off", "--no-warmup", "--no-webui", "--no-slots", "--log-colors", "off"]
    }

    /// Starts `llama-server` on a free port of 127.0.0.1, with a key of its own, its output read as it comes.
    static func launch(settings: EncoderSettings, log: @escaping @Sendable (String) -> Void,
                       ended: @escaping @Sendable (Int32) -> Void) throws -> Child {
        let port = try freePort()
        var bytes = [UInt8](repeating: 0, count: 32)
        var generator = SystemRandomNumberGenerator()
        for index in bytes.indices { bytes[index] = UInt8.random(in: .min ... .max, using: &generator) }
        let key = bytes.map { String(format: "%02x", $0) }.joined()
        let process = Process()
        process.executableURL = settings.binary
        process.arguments = arguments(model: settings.model, port: port)
        process.environment = environment(key: key)
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        process.terminationHandler = { process in ended(process.processIdentifier) }
        try process.run()
        try? output.fileHandleForWriting.close()
        let child = Child(process: process, port: port, key: key)
        let reading = output.fileHandleForReading
        Thread.detachNewThread {
            while let data = try? reading.read(upToCount: 65_536), !data.isEmpty {
                child.take(data)
            }
            try? reading.close()
            child.state.withLock { $0.outputEnded = true }
        }
        return child
    }

    /// Keeps the child's output by line, its last `keptLines`.
    private func take(_ data: Data) {
        state.withLock { state in
            let text = state.partial + String(decoding: data, as: UTF8.self)
            var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            state.partial = lines.removeLast()
            for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                state.lines.append(line.count > 400 ? String(line.prefix(400)) + "…" : line)
            }
            if state.lines.count > Self.keptLines { state.lines.removeFirst(state.lines.count - Self.keptLines) }
        }
    }

    /// Waits for `GET /health` to answer 200, as `llama-server` does once its model is loaded, asking every
    /// tenth of a second; throws if the child ends first, or `within` passes.
    func waitUntilReady(within limit: Duration) async throws {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard process.isRunning else { throw ChildError.ended("it \(exitDescription()) before its health answered") }
            if let answer = try? await exchange(request("GET", "/health"), timeout: .seconds(2)), answer.status == 200 {
                state.withLock { $0.readyAt = Date() }
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ChildError.unreachable("its health did not answer within \(QueryEncoder.spoken(limit))")
    }

    /// Waits up to `within` for the last of its output, once it has ended, so that its last words are kept.
    func waitForOutput(within limit: Duration) async {
        let deadline = ContinuousClock.now + limit
        while !state.withLock({ $0.outputEnded }), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Asks it to end, with SIGTERM, and after `within` ends it with SIGKILL.
    func stop(within limit: Duration) async {
        state.withLock { $0.stopRequested = true }
        guard process.isRunning else { return }
        process.terminate()
        let deadline = ContinuousClock.now + limit
        while process.isRunning, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if process.isRunning {
            kill(pid, SIGKILL)
            while process.isRunning { try? await Task.sleep(for: .milliseconds(20)) }
        }
    }

    // MARK: The requests

    /// The tokens `prompt` takes, with the model's special tokens, as the embedding tokenizes it.
    func tokenCount(_ prompt: String, timeout: Duration) async throws -> Int {
        struct Body: Encodable {
            let content: String
            let add_special = true
            let parse_special = true
        }
        struct Answer: Decodable { let tokens: [Int] }
        let answer = try await exchange(request("POST", "/tokenize", json: Body(content: prompt)), timeout: timeout)
        guard answer.status == 200 else { throw Self.refusal(answer) }
        do {
            return try JSONDecoder().decode(Answer.self, from: answer.body).tokens.count
        } catch {
            throw ChildError.badAnswer("its tokens could not be read: \(error)")
        }
    }

    /// The pooled vector of `prompt`, unnormalised (`embd_normalize` −1), each value the model's own float.
    func pooledEmbedding(_ prompt: String, timeout: Duration) async throws -> [Double] {
        struct Body: Encodable {
            let content: String
            let embd_normalize = -1
        }
        struct Row: Decodable { let embedding: [[Double]] }
        let answer = try await exchange(request("POST", "/embedding", json: Body(content: prompt)), timeout: timeout)
        guard answer.status == 200 else { throw Self.refusal(answer) }
        let rows: [Row]
        do {
            rows = try JSONDecoder().decode([Row].self, from: answer.body)
        } catch {
            throw ChildError.badAnswer("its vector could not be read: \(error)")
        }
        guard rows.count == 1, let pooled = rows[0].embedding.first, rows[0].embedding.count == 1 else {
            throw ChildError.badAnswer("it answered \(rows.count) rows, where one pooled vector was asked for")
        }
        return pooled
    }

    /// An error answer as `llama-server` writes one, `{"error": {"code", "message", "type"}}`; one that
    /// says a query is past its batch, as the tokens it counted.
    static func refusal(_ answer: HTTPAnswer) -> ChildError {
        struct Body: Decodable {
            struct Inner: Decodable { let message: String? }
            let error: Inner?
        }
        let message = (try? JSONDecoder().decode(Body.self, from: answer.body))?.error?.message
            ?? String(decoding: answer.body.prefix(300), as: UTF8.self)
        if message.contains("too large to process") {
            return .tooLarge(tokens: message.firstMatch(of: /input \((\d+) tokens\)/).flatMap { Int($0.1) })
        }
        return .refused(status: answer.status, message: message)
    }

    func request(_ method: String, _ path: String) -> [UInt8] {
        var head = "\(method) \(path) HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n"
        if path != "/health" { head += "Authorization: Bearer \(key)\r\n" }
        head += "\r\n"
        return Array(head.utf8)
    }

    func request(_ method: String, _ path: String, json body: some Encodable) -> [UInt8] {
        let data = (try? JSONEncoder().encode(body)) ?? Data("{}".utf8)
        var head = "\(method) \(path) HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n"
        head += "Authorization: Bearer \(key)\r\nContent-Type: application/json\r\nContent-Length: \(data.count)\r\n\r\n"
        return Array(head.utf8) + Array(data)
    }

    /// One exchange with the child on 127.0.0.1, which `timeout` bounds; its answer is at most 16 MB.
    func exchange(_ request: [UInt8], timeout: Duration) async throws -> HTTPAnswer {
        let port = port
        return try await withThrowingTaskGroup(of: HTTPAnswer.self) { group in
            group.addTask { try await Self.send(request, port: port) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ChildError.unreachable("it did not answer within \(QueryEncoder.spoken(timeout))")
            }
            defer { group.cancelAll() }
            guard let answer = try await group.next() else { throw CancellationError() }
            return answer
        }
    }

    private static func send(_ request: [UInt8], port: Int) async throws -> HTTPAnswer {
        let channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>
        do {
            channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                .connectTimeout(.seconds(5))
                .connect(host: "127.0.0.1", port: port) { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                    }
                }
        } catch {
            try Task.checkCancellation()
            throw ChildError.unreachable("no connection to 127.0.0.1:\(port): \(error)")
        }
        let underlying = channel.channel
        return try await withTaskCancellationHandler {
            try await channel.executeThenClose { inbound, outbound in
                var reader = HTTPAnswer.Reader(limit: 16 * 1_048_576)
                do {
                    try await outbound.write(ByteBuffer(bytes: request))
                    for try await buffer in inbound {
                        try reader.append(buffer.readableBytesView)
                        if let answer = try reader.answer(ended: false) { return answer }
                    }
                } catch {
                    try Task.checkCancellation()
                    if let answer = try? reader.answer(ended: true) { return answer }
                    throw ChildError.unreachable("the connection to 127.0.0.1:\(port) failed: \(error)")
                }
                guard let answer = try? reader.answer(ended: true) else {
                    throw ChildError.badAnswer("its answer ended early")
                }
                return answer
            }
        } onCancel: {
            underlying.close(promise: nil)
        }
    }

    /// A port of 127.0.0.1 no one listens on now: the system's choice for a socket bound to port 0.
    static func freePort() throws -> Int {
        #if canImport(Glibc)
        let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard fd >= 0 else { throw ChildError.unreachable("no socket for a port: \(String(cString: strerror(errno)))") }
        defer { close(fd) }
        var address = sockaddr_in()
        #if canImport(Darwin)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0 else { throw ChildError.unreachable("no port of 127.0.0.1 is free: \(String(cString: strerror(errno)))") }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        guard named == 0 else { throw ChildError.unreachable("the free port could not be read: \(String(cString: strerror(errno)))") }
        return Int(UInt16(bigEndian: address.sin_port))
    }
}
