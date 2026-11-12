// The app's data files, FRUSExplorer/Resources from the pinned commit, read once at start, and the
// archival indexes a collection's Sources & Archives block reads once it first asks (PLAN's S18e).

import FRUSCoreKit
import FRUSLightCore
import Foundation

/// What the server reads from the app's data files. The manifest, the broken-refs index and the
/// page map are decoded at start; the indexing resources, which search reads for subject filters,
/// decode each file on first use.
public final class ServerResources: Sendable {
    /// The folder they were read from.
    public let directory: URL
    /// The published catalogue's 553 volumes, in `manifest.json`'s order, read by the kit's
    /// `FixedVolumeCatalogue`, which decodes it as the app's `ManifestStore` does.
    public let manifest: [VolumeManifestEntry]
    /// Each volume's position in `manifest`, by volume id.
    private let positions: [String: Int]
    /// The reader's broken-refs index, which degrades dead cross-references.
    public let brokenRefs: BrokenRefsIndex
    /// The bundled page map, `cited-page-map.json`: the documents on each printed page of another
    /// volume the corpus cites, which the kit's `PageLink` reads for a page link into a volume the
    /// served index does not hold, as the app's readers read `CitedPageMapStore.shared`. The kit's
    /// own copy, `IndexingResources.citedPages`, is internal to it and read only by the indexer.
    public let citedPages: CitedPageMap
    /// The five files that change what an index holds, for the kit's search stack.
    public let indexing: IndexingResources
    /// The three indexes a collection's Sources & Archives block links a lot through (PLAN's S18e),
    /// decoded on first use.
    private let archival = ArchivalIndexFiles()
    /// The editors' annotations, `volume-annotations-index.json`, decoded on first use (Annotations.swift).
    private let annotations = VolumeAnnotationsFile()
    /// The subject vocabulary, `volume-subject-profiles-index.json`, decoded on first use (ProjectFocus.swift).
    private let subjects = SubjectProfilesFile()
    /// The document subject index, `document-subject-index.json`, decoded on first use (RelatedDocuments.swift).
    private let documentSubjects = DocumentSubjectIndexFile()
    /// The corpus-wide citation index, `resolved-edge-index.json`, decoded on first use (ServedIndex.swift).
    private let resolvedEdges = ResolvedEdgeIndexFile()
    /// The catalogue overlay (PLAN's S21e): the volumes a Standalone server's library holds that the published
    /// catalogue does not list, side-loaded, each described by the kit's `LocalVolumeCatalog` from its own header.
    private let local = LocalVolumes()

    /// The files the server cannot start without: those it reads here, and the five
    /// `IndexingResources` requires.
    public static let requiredFiles = ["manifest.json", "broken-refs-index.json"]
        + IndexingResources.indexResourceNames.map { "\($0).json" }.filter { $0 != "broken-refs-index.json" }

    /// Reads the data files in `directory`. Throws `ServerResourcesError` naming every missing
    /// file, or the one that will not decode.
    public static func load(from directory: URL) throws -> ServerResources {
        let missing = requiredFiles.filter {
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
        guard missing.isEmpty else { throw ServerResourcesError.missing(directory: directory.path, files: missing) }
        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            do {
                return try JSONDecoder().decode(type, from: Data(contentsOf: directory.appendingPathComponent(name)))
            } catch {
                throw ServerResourcesError.unreadable(directory: directory.path, file: name, reason: "\(error)")
            }
        }
        let manifest: [VolumeManifestEntry]
        do {
            manifest = try FixedVolumeCatalogue(contentsOf: directory.appendingPathComponent("manifest.json")).citableEntries
        } catch {
            throw ServerResourcesError.unreadable(directory: directory.path, file: "manifest.json", reason: "\(error)")
        }
        let brokenRefs = try decode(BrokenRefsIndex.self, "broken-refs-index.json")
        let citedPages = try decode(CitedPageMap.self, "cited-page-map.json")
        return ServerResources(directory: directory, manifest: manifest, brokenRefs: brokenRefs, citedPages: citedPages,
                               indexing: try IndexingResources.loading(fromDirectory: directory))
    }

    init(directory: URL, manifest: [VolumeManifestEntry], brokenRefs: BrokenRefsIndex, citedPages: CitedPageMap,
         indexing: IndexingResources) {
        self.directory = directory
        self.manifest = manifest
        var positions: [String: Int] = [:]
        for (position, entry) in manifest.enumerated() where positions[entry.volumeId] == nil {
            positions[entry.volumeId] = position
        }
        self.positions = positions
        self.brokenRefs = brokenRefs
        self.citedPages = citedPages
        self.indexing = indexing
    }

    /// The same data files with a catalogue overlay of its own, empty: for a test whose side-loads no other
    /// test sharing the process's resources should see.
    func withOwnCatalogueOverlay() -> ServerResources {
        ServerResources(directory: directory, manifest: manifest, brokenRefs: brokenRefs, citedPages: citedPages, indexing: indexing)
    }

    /// The manifest's entry for `volumeId`, or the catalogue overlay's for a volume side-loaded under an id
    /// the published catalogue lacks (PLAN's S21e), as the app's `ManifestStore.entry(forVolumeId:)` reads
    /// its local entries; nil for any other. Only an id one of them names is ever joined into a path: a
    /// manifest id, or the name of a volume's file in a Standalone server's own folder, which the side-load
    /// checked before it took its place.
    public func volume(_ volumeId: String) -> VolumeManifestEntry? {
        positions[volumeId].map { manifest[$0] } ?? local.entry(volumeId)
    }

    /// A document's page on history.state.gov, or nil for a side-loaded volume's, whose page the server
    /// cannot vouch for, as the app's `canonicalDocumentURL` gives none (PLAN's S21e).
    public func canonicalURL(volumeId: String, documentId: String) -> String? {
        volume(volumeId)?.provenance == .sideloaded ? nil : FRUSCanonicalURL.string(volumeId: volumeId, documentId: documentId)
    }

    /// The volumes the catalogue overlay holds, by id: side-loaded, each marked `.sideloaded` (PLAN's S21e).
    public var localVolumes: [VolumeManifestEntry] { local.entries() }

    /// Reads the catalogue overlay again from a Standalone server's volumes folder, through the kit's
    /// `LocalVolumeCatalog.reconcile(in:known:)`, as the app's boot and its corpus-change refresh do: a sidecar
    /// for each volume file the catalogue lacks that has none, minted from the file's own header, beside it;
    /// a sidecar whose file is gone removed. Off the cooperative pool: it reads each new file's header.
    public func refreshLocalVolumes(in volumesDirectory: URL) async {
        let known = Set(positions.keys)
        // Two refreshes at once keep the later's listing, whichever ends first.
        let ticket = local.ticket()
        // The reconcile throws nothing; the run's own error, should the queue fail it, leaves the overlay as it was.
        guard let entries = try? await Blocking.run({ LocalVolumeCatalog.reconcile(in: volumesDirectory, known: known) }) else { return }
        local.set(entries, ticket: ticket)
    }

    /// `ArchivalIndexes.bundled`, app code: `central-files-index.json`, `volume-sources-index.json` and
    /// `lot-claimants-index.json`, each decoded once, as its store in the app decodes it, and none for a
    /// file missing or malformed, which the block reads as the app's does, linking what the others can.
    public var archivalIndexes: ArchivalIndexes { archival.indexes(in: directory) }

    /// `VolumeAnnotationsStore.shared`, app code: the editors' annotations, decoded once by the kit's
    /// `VolumeAnnotationsIndex`, with each layer's reach; nil for a file missing or malformed.
    var volumeAnnotations: VolumeAnnotationsData? { annotations.data(in: directory) }

    /// `VolumeSubjectProfilesStore.shared`, app code: the subjects a project's focus is chosen from,
    /// decoded once by the kit's `VolumeSubjectProfiles`; or why the server has none, for a file
    /// missing or malformed, as the app has none, and for one that names a subject twice.
    var subjectProfiles: SubjectProfilesFile.Read { subjects.read(in: directory) }

    /// `DocumentSubjectStore.shared`, app code: the detected subjects of each document, which Related
    /// Documents' shared-topics axis scores and names, decoded once by the kit's `DocumentSubjectIndex`;
    /// nil for a file missing or malformed, and the axis then contributes nothing, as the app's does.
    var documentSubjectIndex: DocumentSubjectIndex? { documentSubjects.index(in: directory) }

    /// `ResolvedEdgeIndexStore.shared`, app code: the bundled corpus-wide citation index, which the
    /// cross-reference store reads where a graph is built, decoded once by the kit's
    /// `ResolvedEdgeIndex(contentsOf:)`; nil for a file missing or malformed, and a graph's inbound half
    /// is then the index's own table alone, as the app's is when its store fails to load.
    var resolvedEdgeIndex: ResolvedEdgeIndex? { resolvedEdges.index(in: directory) }
}

/// The catalogue overlay's entries, set whole each time it is read again.
private final class LocalVolumes: @unchecked Sendable {
    private let lock = NSLock()
    private var byId: [String: VolumeManifestEntry] = [:]
    private var ordered: [VolumeManifestEntry] = []
    /// The refreshes asked for, and the latest whose listing is kept.
    private var issued = 0
    private var applied = 0

    func ticket() -> Int {
        lock.lock()
        defer { lock.unlock() }
        issued += 1
        return issued
    }

    func entry(_ volumeId: String) -> VolumeManifestEntry? {
        lock.lock()
        defer { lock.unlock() }
        return byId[volumeId]
    }

    func entries() -> [VolumeManifestEntry] {
        lock.lock()
        defer { lock.unlock() }
        return ordered
    }

    func set(_ entries: [VolumeManifestEntry], ticket: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard ticket > applied else { return }
        applied = ticket
        ordered = entries.sorted { $0.volumeId < $1.volumeId }
        byId = Dictionary(ordered.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

/// The corpus-wide citation index, decoded the first time a served index's stack opens: 1.1 MB of JSON.
private final class ResolvedEdgeIndexFile: @unchecked Sendable {
    private let lock = NSLock()
    private var held: ResolvedEdgeIndex??

    func index(in directory: URL) -> ResolvedEdgeIndex? {
        lock.lock()
        defer { lock.unlock() }
        if let held { return held }
        let index = try? ResolvedEdgeIndex(contentsOf: directory.appendingPathComponent("resolved-edge-index.json"))
        held = .some(index)
        return index
    }
}

/// The archival indexes, decoded the first time a collection asks for them: 4.5 MB of JSON that a
/// server with no Sources & Archives block never reads.
private final class ArchivalIndexFiles: @unchecked Sendable {
    private let lock = NSLock()
    private var loaded: ArchivalIndexes?

    func indexes(in directory: URL) -> ArchivalIndexes {
        lock.lock()
        defer { lock.unlock() }
        if let loaded { return loaded }
        func decode<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
            (try? Data(contentsOf: directory.appendingPathComponent(name))).flatMap { try? JSONDecoder().decode(type, from: $0) }
        }
        let indexes = ArchivalIndexes(centralFiles: decode(CentralFilesIndex.self, "central-files-index.json"),
                                      volumeSources: decode(VolumeSourcesIndex.self, "volume-sources-index.json"),
                                      claimants: decode(LotClaimantsIndex.self, "lot-claimants-index.json"))
        loaded = indexes
        return indexes
    }
}

/// The app's data files are not where the configuration says.
public enum ServerResourcesError: Error, CustomStringConvertible, Equatable {
    case missing(directory: String, files: [String])
    case unreadable(directory: String, file: String, reason: String)

    public var description: String {
        switch self {
        case .missing(let directory, let files):
            return "\(directory) lacks \(files.joined(separator: ", ")). FRUS_RESOURCES_DIR must name a copy of FRUSExplorer/Resources from the pinned FRUS-Explorer commit; the image has one at \(ServerConfiguration.imageResourcesDirectory.path)"
        case .unreadable(let directory, let file, let reason):
            return "\(directory)/\(file) cannot be read: \(reason)"
        }
    }
}
