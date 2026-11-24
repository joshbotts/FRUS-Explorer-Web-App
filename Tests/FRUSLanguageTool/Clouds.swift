// frus-language clouds (PLAN's S29d): the app's cloud-vector generator, `CloudVectorsRunner.run(tagger:cloudLenses:
// environment:)`, run with the web's tagger over the corpus's TEI, the cloud files carrying the six lenses the
// references price, and the family's provenance written beside the four files. scripts/make-language runs it.

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import CloudVectorsGeneratorCore
import FRUSLanguage
import Foundation
import WordCloudKit

enum Clouds {
    /// The app's files the run reads, at the pin, by default.
    static let resources = "upstream/FRUS-Explorer/FRUSExplorer/Resources"

    /// Runs the generator and writes the provenance; prints the run's time, its peak memory and the files.
    static func run(_ arguments: inout Arguments) throws {
        guard let volumes = arguments.take("--volumes"), let commit = arguments.take("--corpus-commit"),
              let upstream = arguments.take("--upstream") else {
            throw ToolError("clouds needs --volumes, --corpus-commit and --upstream")
        }
        let repository = arguments.take("--repository") ?? "https://github.com/HistoryAtState/frus"
        let manifest = arguments.take("--manifest") ?? "\(resources)/manifest.json"
        let lexicons = arguments.take("--lexicons") ?? "\(resources)/word-cloud-lexicons.json"
        let stopwords = arguments.take("--stopwords") ?? "\(resources)/word-cloud-stopwords.json"
        let out = arguments.take("--out") ?? "resources/language"
        let generated = arguments.take("--generated")
        let verify = arguments.take("--verify-printed")
        try arguments.finish()
        guard commit.count == 40, commit.allSatisfy(\.isHexDigit) else {
            throw ToolError("--corpus-commit takes the corpus's commit, 40 hex digits")
        }
        if let verify, verify != "1" { throw ToolError("--verify-printed takes 1") }
        if let generated, generated.count != 10 { throw ToolError("--generated takes a day, yyyy-MM-dd") }
        let output = URL(fileURLWithPath: out, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        var environment = ["VOLUMES_DIR": volumes, "MANIFEST": manifest, "LEXICONS": lexicons, "STOPWORDS": stopwords,
                           "OUTPUT_DIR": output.path]
        if let generated { environment["GENERATED_DATE"] = generated }
        if verify != nil { environment["VERIFY_PRINTED_WALK"] = "1" }

        let tagger = FRUSWordCloudTagger()
        note("clouds: counting with \(tagger.identity), the cloud files carrying \(CloudVectorsRunner.baselineLenses.map(\.rawValue).joined(separator: ", "))")
        let clock = ContinuousClock()
        let started = clock.now
        try CloudVectorsRunner.run(tagger: tagger, cloudLenses: CloudVectorsRunner.baselineLenses, environment: environment)
        let elapsed = clock.now - started

        let provenance = try write(output, family: tagger.tagger.identity, repository: repository, commit: commit,
                                   upstream: upstream, inputs: [manifest, lexicons, stopwords])

        var usage = rusage()
        #if canImport(Glibc)
        getrusage(__rusage_who_t(RUSAGE_SELF.rawValue), &usage)
        #else
        getrusage(RUSAGE_SELF, &usage)
        #endif
        let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        // ru_maxrss is in kilobytes on Linux.
        note(String(format: "clouds: %.1f s elapsed, %.1f s of processor time, peak resident %.0f MB",
                    Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18, cpu,
                    Double(usage.ru_maxrss) / 1024))
        note("clouds: \(provenance.corpus.volumes) volumes, \(provenance.corpus.documents) documents at \(commit), stamped \(provenance.generated)")
        for file in provenance.files {
            note("clouds: \(file.name) \(file.bytes) bytes, SHA-256 \(file.sha256)")
        }
    }

    /// The provenance of the four files in `output`, written beside them.
    static func write(_ output: URL, family: LanguageIdentity, repository: String, commit: String, upstream: String,
                      inputs: [String]) throws -> LanguageFamily.Provenance {
        let provenance = try LanguageFamily.provenance(of: output, family: family, repository: repository, commit: commit,
                                                       upstream: upstream, inputs: inputs.map { URL(fileURLWithPath: $0) })
        try LanguageFamily.encoded(provenance).write(to: output.appendingPathComponent(LanguageFamily.provenanceFileName))
        return provenance
    }

    /// `frus-language provenance`: the provenance of four files a run wrote, written again beside them by this tool's
    /// code, without counting anything, for a change to the provenance's own form.
    static func provenance(_ arguments: inout Arguments) throws {
        guard let commit = arguments.take("--corpus-commit"), let upstream = arguments.take("--upstream") else {
            throw ToolError("provenance needs --corpus-commit and --upstream")
        }
        let repository = arguments.take("--repository") ?? "https://github.com/HistoryAtState/frus"
        let inputs = [arguments.take("--manifest") ?? "\(resources)/manifest.json",
                      arguments.take("--lexicons") ?? "\(resources)/word-cloud-lexicons.json",
                      arguments.take("--stopwords") ?? "\(resources)/word-cloud-stopwords.json"]
        let out = arguments.take("--out") ?? "resources/language"
        try arguments.finish()
        let provenance = try write(URL(fileURLWithPath: out, isDirectory: true), family: LanguageTagger.shared.identity,
                                   repository: repository, commit: commit, upstream: upstream, inputs: inputs)
        note("provenance: \(provenance.files.count) files of \(provenance.family), in \(out)")
    }
}
