// The language family's files (PLAN's S29d): the clouds and keyness references the app's generator,
// `CloudVectorsRunner.run(tagger:cloudLenses:environment:)`, counts with the web's tagger over the corpus's
// TEI, under the family's identity, committed under resources/language with their provenance, which
// `frus-language clouds` writes beside them and scripts/make-language runs. The server reads them for every
// cloud, held to its tagger's identity, so that the web counts in one family.

import Foundation
import WordCloudKit

/// The family's four files and their provenance.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29d): initial implementation
public enum LanguageFamily {
    /// The two cloud files and the two references the generator writes from one pass, in the order it writes
    /// them: the corpus and its subseries, the volumes, and the references in dictionary and printed forms.
    public static let fileNames = ["cloud-vectors-core.json", "cloud-vectors-volumes.json",
                                   "keyness-baseline.json", "keyness-baseline-printed.json"]

    /// The provenance's file, beside the four.
    public static let provenanceFileName = "provenance.json"

    /// Where the four were made from: the family, the corpus at its commit, the app's lists at the pin, the
    /// lenses and the day, and each file's length and SHA-256, so that a file changed by hand, or left behind by
    /// a run that made the others, is seen. Nothing in it says how long a run took or on what machine, so two
    /// runs that write the same files write the same provenance.
    public struct Provenance: Codable, Equatable, Sendable {
        /// The tagger the files were counted with: its name, its version and the digests the version is made of.
        public var family: LanguageIdentity
        /// The TEI they were counted from.
        public var corpus: Corpus
        /// The pinned app commit whose generator, catalogue and word lists the run read.
        public var upstream: String
        /// The catalogue's volumes and their subseries, which the counts are rolled up by: the part of the manifest a
        /// count depends on, so that a new title moves nothing here and a new volume does.
        public var catalogue: Catalogue
        /// The app's files the run read besides the TEI: the catalogue and the two word lists, by SHA-256.
        public var inputs: [Input]
        /// The lenses the cloud files carry, in their order; the references price the same six.
        public var lenses: [String]
        /// The day the files are stamped with (`GENERATED_DATE`).
        public var generated: String
        /// The four files, each with its length and SHA-256.
        public var files: [File]
        /// The command that makes them again, byte for byte, at the pin it names: the corpus's commit and the day
        /// (``LanguageFamily/remakeCommand(commit:generated:)``).
        public var remake: String

        /// The corpus's repository and commit, and what the run counted of it.
        public struct Corpus: Codable, Equatable, Sendable {
            public var repository: String
            public var commit: String
            /// The catalogue's volumes counted, and their documents, as the files' provenance gives them.
            public var volumes: Int
            public var documents: Int
        }

        /// The catalogue's volumes, and the SHA-256 of a line for each, its id and its subseries, sorted
        /// (``LanguageFamily/catalogueDigest(of:)``).
        public struct Catalogue: Codable, Equatable, Sendable {
            public var volumes: Int
            public var sha256: String
        }

        /// An input file of the app's, by its name and SHA-256.
        public struct Input: Codable, Equatable, Sendable {
            public var name: String
            public var sha256: String
        }

        /// One of the four files.
        public struct File: Codable, Equatable, Sendable {
            public var name: String
            public var bytes: Int
            public var sha256: String
        }

        public init(family: LanguageIdentity, corpus: Corpus, upstream: String, catalogue: Catalogue, inputs: [Input],
                    lenses: [String], generated: String, files: [File], remake: String) {
            self.family = family
            self.corpus = corpus
            self.upstream = upstream
            self.catalogue = catalogue
            self.inputs = inputs
            self.lenses = lenses
            self.generated = generated
            self.files = files
            self.remake = remake
        }
    }

    /// The command that makes the files again, byte for byte at the same pin, which the provenance records: the corpus's
    /// commit, which the script clones a folder that does not exist at, and the day the files are stamped with.
    public static func remakeCommand(commit: String, generated: String) -> String {
        "scripts/make-language --corpus <a folder outside the repository> --commit \(commit) --generated \(generated)"
    }

    /// The catalogue's volumes and subseries in `manifest`, the app's `manifest.json`: how many, and the SHA-256 of a line
    /// for each, `<volumeId>\t<subseries>\n`, sorted, so that the manifest's order and every other field it holds play
    /// no part.
    public static func catalogue(of manifest: URL) throws -> Provenance.Catalogue {
        struct Entry: Decodable { let volumeId: String; let subseries: String }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: manifest))
        let lines = entries.map { "\($0.volumeId)\t\($0.subseries)\n" }.sorted().joined()
        return Provenance.Catalogue(volumes: entries.count, sha256: LanguageTagger.sha256(Array(lines.utf8)))
    }

    /// The provenance of the four files in `folder`, as a run wrote them: their lengths and digests, and the
    /// volumes, documents, day and lenses the core file records.
    /// - Parameters:
    ///   - folder: The folder the run wrote.
    ///   - family: The tagger's identity.
    ///   - repository: The corpus's repository.
    ///   - commit: The commit of it the run counted.
    ///   - upstream: The pinned app commit.
    ///   - inputs: The app's files the run read: the catalogue, `manifest.json`, first, and the two word lists.
    public static func provenance(of folder: URL, family: LanguageIdentity, repository: String, commit: String,
                                  upstream: String, inputs: [URL]) throws -> Provenance {
        guard let manifest = inputs.first else { throw CocoaError(.fileNoSuchFile) }
        let core = try CloudVectorsFile(contentsOf: folder.appendingPathComponent(fileNames[0]))
        let files = try fileNames.map { name in
            let bytes = [UInt8](try Data(contentsOf: folder.appendingPathComponent(name)))
            return Provenance.File(name: name, bytes: bytes.count, sha256: LanguageTagger.sha256(bytes))
        }
        let read = try inputs.map { url in
            Provenance.Input(name: url.lastPathComponent,
                             sha256: LanguageTagger.sha256([UInt8](try Data(contentsOf: url))))
        }
        return Provenance(family: family,
                          corpus: .init(repository: repository, commit: commit, volumes: core.provenance.volumeCount,
                                        documents: core.provenance.documentCount),
                          upstream: upstream, catalogue: try catalogue(of: manifest), inputs: read, lenses: core.lenses,
                          generated: core.generated, files: files,
                          remake: remakeCommand(commit: commit, generated: core.generated))
    }

    /// The provenance as its file holds it: sorted keys, two spaces, a line feed at the end.
    public static func encoded(_ provenance: Provenance) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(provenance) + Data("\n".utf8)
    }

    /// Reads the provenance in `folder`.
    public static func provenance(in folder: URL) throws -> Provenance {
        try JSONDecoder().decode(Provenance.self, from: Data(contentsOf: folder.appendingPathComponent(provenanceFileName)))
    }
}
