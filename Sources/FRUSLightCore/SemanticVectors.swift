// The semantic vectors on the server (PLAN's S26c). The bundled tier is read on its first use, through the kit's
// readers: `semantic-vectors-index.json` and the mapped `semantic-vectors-binary.bin` as a pair, refused as the kit
// refuses a pair whose digests differ (`SemanticBundledTiers`), with the bundled shard manifest of their generation,
// `semantic-shards-manifest.json`. The second tier, a shard a volume, is in the image, all 553, by the owner's answer
// of 23 November, so that a server holds every vector from its first start, offline too, and downloads none: there is
// no job, no download and no removal, and a reader's request fetches nothing. A shard is opened from the image's
// read-only folder through the kit's `SemanticShard`, which validates it against the bundled provenance and the
// volume's count, and held to the manifest's length and SHA-256, as the app holds a shard before it keeps it; one
// refused is counted, with why, in the app's words (`SemanticStorageReport`, mirrored below in a server's).
//
// `SemanticVectors` answers SemanticVectorsKit's `SemanticShardSource`, the one read FRUSCoreKit's semantic passes
// make of a host's shards (S26a), for Related Documents' semantic axis (S26d) and search by meaning (S27d). The map
// (S28b) takes its vectors' index from the same read, so the bundled files are read once for both.

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
import SemanticVectorsKit

// MARK: - The bundled files

/// The bundled shard manifest, `semantic-shards-manifest.json`: each published shard's volume, length and SHA-256,
/// written by the app's generator in the run that wrote the bundled tier.
public struct SemanticShardManifest: Codable, Sendable, Equatable {
    public struct Shard: Codable, Sendable, Equatable {
        public var volumeID: String
        public var bytes: Int
        public var sha256: String

        public init(volumeID: String, bytes: Int, sha256: String) {
            self.volumeID = volumeID
            self.bytes = bytes
            self.sha256 = sha256
        }
    }

    /// The generation the shards were written for, as the bundled index's `provenanceDigest` names it.
    public var provenanceDigest: String
    /// The day of the run, and the schema and width it names; read where present, as the app reads only the shards.
    public var generated: String?
    public var schema: Int?
    public var shippingDims: Int?
    public var shards: [Shard]

    /// The published total, the denominator the app's storage screen gives as "of 553".
    public var publishedBytes: Int { shards.reduce(0) { $0 + $1.bytes } }
}

/// The bundled generation, read once: the pair as the kit reads it, and the manifest of its shards.
public struct SemanticBundle: Sendable {
    /// The row index and the mapped corpus tier, which agree on their provenance.
    public let tiers: SemanticBundledTiers
    public let manifest: SemanticShardManifest
    /// Each published shard's length and digest, by volume.
    public let expectations: [String: SemanticShardManifest.Shard]

    public var index: SemanticVectorIndex { tiers.index }
    public var corpus: SemanticCorpusVectors { tiers.corpus }
    public var provenance: SemanticVectorsArtifacts.Provenance { tiers.index.provenance }
    /// The generation's name: its provenance digest's first eight hex digits, the folder the vectors' host keeps
    /// its shards in (`generations/89481b18/`), as the app's fetcher names it.
    public var generation: String { String(provenance.digestHex.prefix(8)) }
}

/// Why the bundled vectors are refused, whole: a file missing, a file the kit cannot read, a pair whose digests
/// differ, or a manifest of another generation. Nothing semantic is served from a refused generation, as the app
/// serves nothing from a pair it refused.
public struct SemanticBundleRefusal: Error, Sendable, Equatable, CustomStringConvertible {
    /// The bundled file the refusal is about.
    public var file: String
    public var reason: SemanticUnavailable

    public init(file: String, reason: SemanticUnavailable) {
        self.file = file
        self.reason = reason
    }

    /// The refusal in words, after the app's: the file, and what is wrong with it.
    public var description: String {
        switch reason {
        case .noArtifact:
            "\(file) is not among this server's data files"
        case let .provenanceMismatch(expected, found):
            "\(file) was made from the vectors \(found.prefix(8)), where the bundled index names \(expected.prefix(8))"
        case let .malformedArtifact(why):
            "\(file) could not be read: \(why)"
        default:
            "\(file): \(reason)"
        }
    }
}

// MARK: - A shard refused

/// Why the server does not use a volume's shard.
public enum SemanticShardRefusal: Sendable, Equatable {
    /// The bundled manifest publishes no shard for the volume: ordinary, not a fault, as the app's `noArtifact`.
    case notPublished
    /// The manifest publishes one, and the image's folder does not hold it.
    case missing
    /// The kit's `SemanticShard` refused the file: another generation's, another length or count, or no shard.
    case unusable(SemanticUnavailable)
    /// The file's length or SHA-256 is not the one the bundled manifest names, as the app's fetcher refuses one
    /// that did not arrive intact.
    case notTheManifests(expected: String, found: String)

    /// Whether the refusal is a fault the pane lists: every one but a volume with no shard published.
    public var isFault: Bool { self != .notPublished }

    /// The sentence the pane shows: the app's (`SemanticStorageReport.describe`), in a server's words.
    public var sentence: String {
        switch self {
        case .notPublished: SemanticStorageWords.notPublished
        case .missing: SemanticStorageWords.missing
        case .unusable(.provenanceMismatch): SemanticStorageWords.otherVersion
        case .unusable(.pending): SemanticStorageWords.pending
        case .unusable: SemanticStorageWords.damaged
        case .notTheManifests: SemanticStorageWords.notIntact
        }
    }

    /// What the server found, for an admin who reads further.
    public var detail: String {
        switch self {
        case .notPublished: "The bundled manifest lists no shard for this volume."
        case .missing: "The bundled manifest lists it; the image's folder has no such file."
        case let .unusable(.provenanceMismatch(expected, found)):
            "Its header names the vectors \(found.prefix(8)); the bundled index's are \(expected.prefix(8))."
        case let .unusable(.malformedArtifact(why)): "\(why.prefix(1).uppercased())\(why.dropFirst())."
        case .unusable(.noArtifact): "The file could not be read."
        case let .unusable(other): "\(other)."
        case let .notTheManifests(expected, found): "The bundled manifest names \(expected); the file is \(found)."
        }
    }
}

/// The words of the app's storage screen (`SemanticStorageReport` and `SemanticStorageSection`), in a server's: the
/// shards "in the image" where the app's are downloaded "on this device", and nothing to download or remove.
/// SemanticStorageMirrorParityTests holds each to the app's line it follows.
public enum SemanticStorageWords {
    /// The app's `settings.vectors.header`.
    public static let header = "Semantic Vectors"
    /// The app's `settings.vectors.downloaded.label`, "Downloaded": the server's shards are in its image.
    public static let heldLabel = "In the Image"
    /// The app's `settings.vectors.downloaded.value`, "%lld of %lld".
    public static func heldValue(_ held: Int, of published: Int) -> String {
        "\(grouped(held)) of \(grouped(published))"
    }
    /// The app's `settings.vectors.downloaded.detail`, "%@ of %@ on this device.".
    public static func heldDetail(_ bytes: Int, of published: Int) -> String {
        "\(fileSize(bytes)) of \(fileSize(published)) on this server."
    }

    /// The app's `settings.vectors.problems.label`.
    public static let problemsLabel = "Problems"
    /// The app's `settings.vectors.problems.none.v2` and `.some.v2`, which say that its list is partial: the app
    /// notices a problem only when it downloads or searches a volume. The server checks every shard in its image
    /// against the bundled manifest before it says what it found, so its sentence says so instead.
    public static func problemsCaption(_ count: Int, checked: Int) -> String {
        let scope = switch checked {
        case 0: "The image holds none of the files the bundled manifest names."
        case 1: "The server checked the one file in its image against the bundled manifest."
        default: "The server checked all \(grouped(checked)) files in its image against the bundled manifest."
        }
        return count == 0 ? "Nothing has gone wrong. \(scope)" : "\(grouped(count)) found. \(scope)"
    }

    /// The app's `settings.vectors.refused.provenance.v2`, without its remedy, since nothing in the image can be removed
    /// or downloaded again.
    public static let otherVersion = "This file was made for a different version of the app, so it cannot be used with this one."
    /// The app's `settings.vectors.refused.malformed`, the file in the image where the app's is on disk.
    public static let damaged = "The file in the image is damaged and was not used."
    /// The app's `settings.vectors.refused.missing.v2`, "The file is no longer on this device.".
    public static let missing = "The file is not in the image."
    /// The published shards the folder lacks, counted, the first five named, and the sentence for each.
    public static func missingLine(_ volumes: [String]) -> String {
        let named = volumes.prefix(5).joined(separator: ", ")
        let more = volumes.count > 5 ? " and \(grouped(volumes.count - 5)) more" : ""
        return "\(grouped(volumes.count)): \(named)\(more). \(missing)"
    }
    /// The app's `settings.vectors.error.integrity.v2`, for a file that is not the one the bundled manifest names.
    public static let notIntact = "The file did not arrive intact, so the server does not use it."
    /// The app's `settings.vectors.error.notPublished.v2`.
    public static let notPublished = "There is no file available for this volume."
    /// The app's `settings.vectors.refused.pending`.
    public static let pending = "Still preparing."

    /// The app's `settings.vectors.unavailable.label` and `.detail.v2`, in a server's words.
    public static let unavailableLabel = "Not available"
    public static let unavailable = "This server cannot match documents by subject, so that part of Related Documents is unavailable. Nothing is wrong with its library."

    /// A count, grouped as the app's `%lld` writes one in English.
    static func grouped(_ count: Int) -> String {
        count.formatted(.number.locale(Locale(identifier: "en_US")))
    }

    /// A size as the app's section writes one, `ByteCountFormatter`'s `.file` style: decimal units, whole bytes and
    /// kilobytes, megabytes to one place and larger units to two, a fraction of zero left out, and "Zero KB" for none.
    /// Written out, so that Linux gives the Mac's words.
    public static func fileSize(_ bytes: Int) -> String {
        guard bytes > 0 else { return "Zero KB" }
        if bytes < 1_000 { return "\(grouped(bytes)) \(bytes == 1 ? "byte" : "bytes")" }
        let units: [(String, Double, Int)] = [("KB", 1e3, 0), ("MB", 1e6, 1), ("GB", 1e9, 2), ("TB", 1e12, 2)]
        var chosen = units[0]
        for unit in units where Double(bytes) >= unit.1 * 0.9995 { chosen = unit }
        let value = Double(bytes) / chosen.1
        let text = value.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(0...chosen.2)))
        return "\(text) \(chosen.0)"
    }
}

// MARK: - What the pane and the command say

/// Administration ▸ Semantic's Vectors and `frus-light semantic`'s: the bundled generation, its model and its count,
/// and the shards in the image of those the manifest publishes, each checked, and any refused, with why.
public struct SemanticVectorsReport: Codable, Sendable, Equatable {
    public struct Generation: Codable, Sendable, Equatable {
        /// The provenance digest, in hex, and its first eight digits, the generation's name.
        public var digest: String
        public var name: String
        /// The day the bundled tier was made.
        public var generated: String
        /// The model the corpus was embedded with, its native width and the width the vectors ship at.
        public var model: String
        public var nativeDimensions: Int
        public var dimensions: Int
        public var documents: Int
        public var volumes: Int
        /// The candidates the Hamming stage hands the int8 rerank, and the recall the app measured for it.
        public var rerankPool: Int
        public var measuredRecallAt10: Double

        public init(digest: String, name: String, generated: String, model: String, nativeDimensions: Int, dimensions: Int,
                    documents: Int, volumes: Int, rerankPool: Int, measuredRecallAt10: Double) {
            self.digest = digest
            self.name = name
            self.generated = generated
            self.model = model
            self.nativeDimensions = nativeDimensions
            self.dimensions = dimensions
            self.documents = documents
            self.volumes = volumes
            self.rerankPool = rerankPool
            self.measuredRecallAt10 = measuredRecallAt10
        }
    }

    public struct Refused: Codable, Sendable, Equatable {
        public var volumeId: String
        /// The sentence the pane shows, the app's in a server's words.
        public var reason: String
        /// What the server found.
        public var detail: String

        public init(volumeId: String, reason: String, detail: String) {
            self.volumeId = volumeId
            self.reason = reason
            self.detail = detail
        }
    }

    public struct Shards: Codable, Sendable, Equatable {
        /// The image's folder.
        public var folder: String
        /// The shards the folder holds of those the manifest publishes, and their bytes, from its listing.
        public var held: Int
        public var heldBytes: Int
        public var published: Int
        public var publishedBytes: Int
        /// The shards checked since the server started, each opened through the kit's `SemanticShard` and held to
        /// the manifest's length and SHA-256, and those of them the server uses.
        public var checked: Int
        public var verified: Int
        /// The files the server refused, by volume, and the published shards the folder does not hold.
        public var refused: [Refused]
        public var missing: [String]
    }

    /// `available`, or `unavailable` when the bundled vectors are refused, and why.
    public var state: String
    public var problem: String?
    public var generation: Generation?
    public var shards: Shards?
}

/// Which of the semantic features this server serves, as `/api/v1/status` says it (PLAN's S26c): the vectors, the
/// map, the encoder, and the two readings later rows add, Related Documents' semantic axis (S26d) and search by
/// meaning (S27d), each false until its row serves it. Read from what the server has loaded or listed, never by
/// hashing a file.
public struct SemanticFeatures: Codable, Sendable, Equatable {
    /// The bundled tier, its index and its binary as a pair, with the shard manifest of their generation; and that
    /// generation's name.
    public var vectors: Bool
    public var generation: String?
    /// The shards the image's folder holds, of those the manifest publishes.
    public var shardsHeld: Int
    public var shardsPublished: Int
    /// Semantic Analytics' map (S28b): its files agree with the vectors.
    public var map: Bool
    /// Search by meaning's encoder: `FRUS_ENCODER` on, with its binary and its model in the image.
    public var encoder: Bool
    /// Related Documents' semantic axis, S26d's.
    public var relatedDocuments: Bool
    /// Search by meaning, S27d's.
    public var searchByMeaning: Bool

    public init(vectors: Bool, generation: String?, shardsHeld: Int, shardsPublished: Int, map: Bool, encoder: Bool,
                relatedDocuments: Bool = false, searchByMeaning: Bool = false) {
        self.vectors = vectors
        self.generation = generation
        self.shardsHeld = shardsHeld
        self.shardsPublished = shardsPublished
        self.map = map
        self.encoder = encoder
        self.relatedDocuments = relatedDocuments
        self.searchByMeaning = searchByMeaning
    }
}

extension EncoderSettings {
    /// Whether the encoder can start, as `/api/v1/status` says it: `FRUS_ENCODER` on, the bundled index read, and the
    /// binary and the model in the image. The model's digest, which the encoder reads at its first use, is not read here.
    public var canStart: Bool {
        enabled && bundled != nil && FileManager.default.isExecutableFile(atPath: binary.path)
            && FileManager.default.fileExists(atPath: model.path)
    }
}

// MARK: - The vectors

/// The server's semantic vectors: the bundled generation, read on its first use, and the image's shards, each opened
/// on its first use and kept mapped, as the app's store keeps them.
public actor SemanticVectors: SemanticShardSource {
    /// The bundled files, in the server's data files.
    public static let indexFile = "semantic-vectors-index.json"
    public static let binaryFile = "semantic-vectors-binary.bin"
    public static let manifestFile = "semantic-shards-manifest.json"

    /// The app's data files, and the shards' folder.
    public nonisolated let resources: URL
    public nonisolated let shards: URL

    /// The pair and the manifest, read once on first use, refusals and all.
    private struct Loaded: Sendable {
        var tiers: Result<SemanticBundledTiers, SemanticBundleRefusal>
        var bundle: Result<SemanticBundle, SemanticBundleRefusal>
    }
    private var loading: Task<Loaded, Never>?

    /// What a shard's check found.
    private enum Check: Sendable {
        case usable(SemanticShard)
        case refused(SemanticShardRefusal)
    }
    /// Shards opened and kept mapped, the refusals, and the volumes whose shard has been held to the manifest.
    private var mapped: [String: SemanticShard] = [:]
    private var refused: [String: SemanticShardRefusal] = [:]
    private var verified: Set<String> = []
    private var opening: [String: Task<Check, Never>] = [:]
    /// The check of every published shard, which the report runs once: each volume's verdict, with no shard kept.
    private var checkingAll: Task<[(String, SemanticShardRefusal?)], Never>?
    /// The folder's listing, read once: the image's folder does not change while the server runs.
    private var listing: [String: Int]?

    public init(resources: URL, shards: URL) {
        self.resources = resources
        self.shards = shards
    }

    /// The server's: the app's data files and the image's shards, as the configuration names them.
    public init(configuration: ServerConfiguration) {
        self.init(resources: configuration.resourcesDirectory, shards: configuration.semanticShards)
    }

    /// The bundled pair, as the kit reads it, or why it is refused.
    public func tiers() async -> Result<SemanticBundledTiers, SemanticBundleRefusal> {
        await loaded().tiers
    }

    /// The bundled generation, the pair with its shard manifest, or why it is refused.
    public func bundle() async -> Result<SemanticBundle, SemanticBundleRefusal> {
        await loaded().bundle
    }

    private func loaded() async -> Loaded {
        if let loading { return await loading.value }
        let resources = resources
        let task = Task<Loaded, Never> {
            (try? await Blocking.run { Self.read(from: resources) })
                ?? Loaded(tiers: .failure(.init(file: Self.indexFile, reason: .pending)),
                          bundle: .failure(.init(file: Self.indexFile, reason: .pending)))
        }
        loading = task
        return await task.value
    }

    /// Reads the bundled files in `resources`: the pair through the kit's `SemanticBundledTiers`, which refuses a
    /// binary whose header names other vectors than the index, and the manifest, which must name their generation.
    private static func read(from resources: URL) -> Loaded {
        for name in [indexFile, binaryFile]
        where !FileManager.default.fileExists(atPath: resources.appendingPathComponent(name).path) {
            let refusal = SemanticBundleRefusal(file: name, reason: .noArtifact)
            return Loaded(tiers: .failure(refusal), bundle: .failure(refusal))
        }
        let tiers: SemanticBundledTiers
        do throws(SemanticUnavailable) {
            tiers = try SemanticBundledTiers(indexAt: resources.appendingPathComponent(indexFile),
                                             binaryAt: resources.appendingPathComponent(binaryFile))
        } catch {
            // The kit gives an index it cannot read as `malformedArtifact("index: …")`, and the binary's own refusals.
            let reason = error
            let refusal: SemanticBundleRefusal
            if case .malformedArtifact(let why) = reason, why.hasPrefix("index: ") {
                refusal = SemanticBundleRefusal(file: indexFile, reason: .malformedArtifact(String(why.dropFirst("index: ".count))))
            } else {
                refusal = SemanticBundleRefusal(file: binaryFile, reason: reason)
            }
            return Loaded(tiers: .failure(refusal), bundle: .failure(refusal))
        }
        return Loaded(tiers: .success(tiers), bundle: manifest(in: resources, for: tiers).map {
            SemanticBundle(tiers: tiers, manifest: $0,
                           expectations: Dictionary($0.shards.map { ($0.volumeID, $0) }, uniquingKeysWith: { first, _ in first }))
        })
    }

    /// The bundled manifest, held to the pair's generation, as the app holds it at wiring time.
    private static func manifest(in resources: URL, for tiers: SemanticBundledTiers) -> Result<SemanticShardManifest, SemanticBundleRefusal> {
        let url = resources.appendingPathComponent(manifestFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(SemanticBundleRefusal(file: manifestFile, reason: .noArtifact))
        }
        let manifest: SemanticShardManifest
        do {
            manifest = try JSONDecoder().decode(SemanticShardManifest.self, from: Data(contentsOf: url))
        } catch {
            return .failure(SemanticBundleRefusal(file: manifestFile, reason: .malformedArtifact("\(error)")))
        }
        let expected = tiers.index.provenance.digestHex
        guard manifest.provenanceDigest.lowercased() == expected else {
            return .failure(SemanticBundleRefusal(file: manifestFile, reason: .provenanceMismatch(expected: expected, found: manifest.provenanceDigest)))
        }
        return .success(manifest)
    }

    // MARK: The shards

    /// Where a volume's shard is: `<volumeID>.vec` in the folder, as the app's store names it.
    public nonisolated func shardURL(for volumeID: String) -> URL {
        shards.appendingPathComponent("\(volumeID).vec")
    }

    /// The shard for a volume, opened through the kit's `SemanticShard` and held to the bundled manifest the first
    /// time it is asked for, then kept mapped; nil when the server has no usable one, which is recorded with why.
    public func shard(for volumeID: String) async -> SemanticShard? {
        if let shard = mapped[volumeID] { return shard }
        if refused[volumeID] != nil { return nil }
        guard case .success(let bundle) = await bundle() else { return nil }
        if let shard = mapped[volumeID] { return shard }
        if refused[volumeID] != nil { return nil }
        let task: Task<Check, Never>
        if let running = opening[volumeID] {
            task = running
        } else {
            let hashing = !verified.contains(volumeID)
            let url = shardURL(for: volumeID)
            task = Task { await Self.check(volumeID, in: bundle, at: url, hashing: hashing) }
            opening[volumeID] = task
        }
        let check = await task.value
        opening[volumeID] = nil
        switch check {
        case .usable(let shard):
            mapped[volumeID] = shard
            verified.insert(volumeID)
            return shard
        case .refused(let refusal):
            refused[volumeID] = refusal
            return nil
        }
    }

    /// Why a volume has no usable shard, once something has asked for it; nil when it has one or was not asked about.
    public func refusal(for volumeID: String) -> SemanticShardRefusal? { refused[volumeID] }

    /// The volumes whose shard is mapped.
    public var mappedVolumeIDs: Set<String> { Set(mapped.keys) }

    /// Checks a shard off the cooperative pool: the kit's `SemanticShard` first, which names another generation's
    /// file as one, then, unless it was held to the manifest before, its length and SHA-256 against the manifest's.
    private static func check(_ volumeID: String, in bundle: SemanticBundle, at url: URL, hashing: Bool) async -> Check {
        guard let expectation = bundle.expectations[volumeID] else { return .refused(.notPublished) }
        let provenance = bundle.provenance
        let count = bundle.index.volume(volumeID)?.documentCount
        return (try? await Blocking.run { checkNow(url, expectation: expectation, provenance: provenance, count: count, hashing: hashing) })
            ?? .refused(.unusable(.pending))
    }

    private static func checkNow(_ url: URL, expectation: SemanticShardManifest.Shard, provenance: SemanticVectorsArtifacts.Provenance,
                                 count: Int?, hashing: Bool) -> Check {
        guard FileManager.default.fileExists(atPath: url.path) else { return .refused(.missing) }
        let shard: SemanticShard
        do {
            shard = try SemanticShard(contentsOf: url, provenance: provenance, expectedDocumentCount: count)
        } catch let reason as SemanticUnavailable {
            return .refused(.unusable(reason))
        } catch {
            return .refused(.unusable(.malformedArtifact("\(error)")))
        }
        guard hashing else { return .usable(shard) }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return .refused(.unusable(.noArtifact)) }
        guard data.count == expectation.bytes else {
            return .refused(.notTheManifests(expected: "\(SemanticStorageWords.grouped(expectation.bytes)) bytes",
                                             found: "\(SemanticStorageWords.grouped(data.count)) bytes"))
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == expectation.sha256.lowercased() else {
            return .refused(.notTheManifests(expected: "SHA-256 \(expectation.sha256)", found: "SHA-256 \(digest)"))
        }
        return .usable(shard)
    }

    /// Checks every published shard not yet checked, once, as `checkNow` checks one, keeping its verdict and not its
    /// mapping: what the report says is then the whole folder's, where the app's screen can say only what it has noticed.
    public func checkEveryShard() async {
        if checkingAll == nil {
            guard case .success(let bundle) = await bundle() else { return }
            if checkingAll == nil {
                let pending = bundle.manifest.shards.filter { !verified.contains($0.volumeID) && refused[$0.volumeID] == nil }
                    .map { ($0, shardURL(for: $0.volumeID)) }
                checkingAll = Task {
                    (try? await Blocking.run {
                        pending.map { expectation, url -> (String, SemanticShardRefusal?) in
                            let check = Self.checkNow(url, expectation: expectation, provenance: bundle.provenance,
                                                      count: bundle.index.volume(expectation.volumeID)?.documentCount, hashing: true)
                            // The verdict alone: the shard is unmapped here, and mapped again when something asks for it.
                            if case .refused(let refusal) = check { return (expectation.volumeID, refusal) }
                            return (expectation.volumeID, nil)
                        }
                    }) ?? []
                }
            }
        }
        guard let checkingAll else { return }
        record(await checkingAll.value)
    }

    /// Records a check's verdicts, a refusal or none, where a shard's own opening has not recorded its volume first.
    private func record(_ verdicts: [(String, SemanticShardRefusal?)]) {
        for (volumeID, refusal) in verdicts where mapped[volumeID] == nil && refused[volumeID] == nil {
            if let refusal { refused[volumeID] = refusal } else { verified.insert(volumeID) }
        }
    }

    /// The `.vec` files the folder holds, by volume, with their lengths, read once.
    private func held() async -> [String: Int] {
        if let listing { return listing }
        let folder = shards
        let found: [String: Int] = (try? await Blocking.run { () -> [String: Int] in
            var lengths: [String: Int] = [:]
            for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasSuffix(".vec") {
                let attributes = try? FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(name).path)
                lengths[String(name.dropLast(4))] = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            }
            return lengths
        }) ?? [:]
        listing = found
        return found
    }

    // MARK: What the server says

    /// The report the pane and `frus-light semantic` give: the generation and its shards, every one checked first.
    public func report() async -> SemanticVectorsReport {
        switch await bundle() {
        case .failure(let refusal):
            return SemanticVectorsReport(state: "unavailable", problem: "The bundled vectors are refused: \(refusal).",
                                         generation: nil, shards: nil)
        case .success(let bundle):
            await checkEveryShard()
            let held = await held()
            let published = bundle.manifest.shards
            let heldPublished = published.filter { held[$0.volumeID] != nil }
            // The files opened: those the server uses and those it refused, a published shard missing from the folder apart.
            let faults = published.compactMap { shard in refused[shard.volumeID].map { (shard.volumeID, $0) } }
                .filter { $0.1.isFault && $0.1 != .missing }
            let index = bundle.index.file
            return SemanticVectorsReport(
                state: "available", problem: nil,
                generation: .init(digest: bundle.provenance.digestHex, name: bundle.generation, generated: index.generated,
                                  model: bundle.provenance.model, nativeDimensions: bundle.provenance.nativeDims,
                                  dimensions: bundle.provenance.shippingDims, documents: index.documentCount,
                                  volumes: index.volumes.count, rerankPool: index.retrieval.rerankPool,
                                  measuredRecallAt10: index.retrieval.measuredRecallAt10),
                shards: .init(folder: shards.path, held: heldPublished.count, heldBytes: heldPublished.reduce(0) { $0 + (held[$1.volumeID] ?? 0) },
                              published: published.count, publishedBytes: bundle.manifest.publishedBytes,
                              checked: published.filter { verified.contains($0.volumeID) }.count + faults.count,
                              verified: published.filter { verified.contains($0.volumeID) }.count,
                              refused: faults.map { .init(volumeId: $0.0, reason: $0.1.sentence, detail: $0.1.detail) },
                              missing: published.map(\.volumeID).filter { refused[$0] == .missing }))
        }
    }

    /// What `/api/v1/status` says of the vectors: loaded or refused, and the shards the folder holds of those
    /// published, from its listing, hashing nothing.
    public func features(map: Bool, encoder: Bool) async -> SemanticFeatures {
        switch await bundle() {
        case .failure:
            return SemanticFeatures(vectors: false, generation: nil, shardsHeld: 0, shardsPublished: 0, map: map, encoder: encoder)
        case .success(let bundle):
            let held = await held()
            return SemanticFeatures(vectors: true, generation: bundle.generation,
                                    shardsHeld: bundle.manifest.shards.filter { held[$0.volumeID] != nil }.count,
                                    shardsPublished: bundle.manifest.shards.count, map: map, encoder: encoder)
        }
    }
}
