// Check 7 at full scale's own path (PLAN's S25b), over the kit's fixture index imported as an export, in process:
// `CitationCheck.run`, which `frus-parity check-citations` runs against a server over a whole corpus, holds every
// answer through the API to the kit's engine over the same file: the app's own citation of every catalogue volume by
// Batch, in each style, marked and plain, row for row, and each volume's first, middle and last documents by Paste
// Citation and Structured Entry.

import FRUSCoreKit
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CitationCheckTests {
    @Test func theFullCorpussCheckPassesOverTheFixtures() async throws {
        let result = try await ServedFixture.run { client, files in
            let kit = try CitationCheck.Kit(index: files.liveIndex, manifest: ServedFixture.resources.appendingPathComponent("manifest.json"),
                                            volumesDirectory: files.volumesDirectory)
            return await CitationCheck.run(kit: kit) { path, form in
                let response = if let form {
                    try await client.execute(uri: path, method: .post,
                                             headers: [.contentType: "application/x-www-form-urlencoded;charset=UTF-8"],
                                             body: ByteBuffer(string: form))
                } else {
                    try await client.execute(uri: path, method: .get)
                }
                return (Int(response.status.code), Data(buffer: response.body))
            }
        }
        #expect(result.passes, "\(result.differences.prefix(10))")
        #expect(result.volumes == 3 && result.documents == 9)
        #expect(result.batchRows == 553 * 6)
        // The kit's own expectations, as its `ownCitationsAreNeverBestGuesses` has them: every volume first as
        // itself, bar the two whose titles cannot tell them from a sibling's, and never by a best guess.
        for form in ["history.state.gov", "Chicago", "Turabian"].flatMap({ [$0, $0 + " (plain)"] }) {
            #expect(result.ownCitationsFirst[form] == 551, "\(form)")
            #expect(result.ownCitationsNotFirst[form] == ["frus1877app", "frus1894app2"], "\(form)")
        }
        #expect(result.ownCitationsGuessed.isEmpty, "\(result.ownCitationsGuessed)")
        #expect(result.citationsNotFindingTheirDocument.isEmpty, "\(result.citationsNotFindingTheirDocument)")
        #expect(result.strategies["exactDocumentNumber", default: 0] > 0 && result.strategies["manifestOnly", default: 0] > 0)
        #expect(result.summary().hasPrefix("check 7 passes through the API"))
    }

    /// An answer that is not the kit's is named, field by field, and fails the check.
    @Test func anAnswerThatIsNotTheKitsFails() async throws {
        let result = try await ServedFixture.run { client, files in
            let kit = try CitationCheck.Kit(index: files.liveIndex, manifest: ServedFixture.resources.appendingPathComponent("manifest.json"),
                                            volumesDirectory: files.volumesDirectory)
            return await CitationCheck.run(kit: kit, perVolume: 1) { path, form in
                let response = if let form {
                    try await client.execute(uri: path, method: .post,
                                             headers: [.contentType: "application/x-www-form-urlencoded;charset=UTF-8"],
                                             body: ByteBuffer(string: form))
                } else {
                    try await client.execute(uri: path, method: .get)
                }
                var body = Data(buffer: response.body)
                // A server that ranks every Paste Citation's first match 9th.
                if form == nil, path.hasPrefix("/api/v1/citation-lookup?"),
                   var matches = try? JSONSerialization.jsonObject(with: body) as? [[String: Any]], !matches.isEmpty {
                    matches[0]["rank"] = 9
                    body = try JSONSerialization.data(withJSONObject: matches)
                }
                return (Int(response.status.code), body)
            }
        }
        #expect(!result.passes)
        #expect(result.differences.contains { $0.contains("rank 1:") }, "\(result.differences.prefix(3))")
    }
}
