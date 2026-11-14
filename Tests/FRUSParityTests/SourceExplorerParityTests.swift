// Source Explorer (PLAN's S22d), over the kit's fixture index imported as an export. Check 8: every source note
// of the three fixture volumes, as the export generator reads them from the TEI, resolved through the API and
// each record held to the generator's (`SourceExplorerCheck`, which `frus-parity check-source-explorer` runs
// against a running server). This file imports neither FRUSCoreKit nor the generator's cores, which share eight
// public names; `SourceExplorerCheck` reads the cores, and the server the kit.

import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct SourceExplorerParityTests {
    /// The done-when's first part: check 8 passes over the fixtures' source notes, through the API.
    @Test func checkEightPassesThroughTheAPI() async throws {
        let notes = try SourceExplorerCheck.notes(teiDirectory: Repository.layout.tei, volumes: ParityFixtures.volumes)
        let comparator = try SourceExplorerCheck.Comparator(resources: ServedFixture.resources)
        let result = try await ServedFixture.run { client, _ in
            await SourceExplorerCheck.run(notes: notes, comparator: comparator) { path in
                let response = try await client.execute(uri: path, method: .get)
                return (Int(response.status.code), Data(buffer: response.body))
            }
        }
        for difference in result.differences { print("differs  \(difference)") }
        #expect(result.differences.isEmpty, "\(result.differences.count) differ:\n\(result.differences.prefix(40).joined(separator: "\n"))")
        #expect(result.passes, "\(result.summary(volumes: ParityFixtures.volumes.count))")
        // The year rule, as it stands at this pin: the seven documents whose datelines read "undated", which the
        // export dates from frus:doc-dateTime-min and both of the app's views do not date. A change to either
        // side's year changes this list.
        #expect(result.undatedByDateline == ["d14", "d30", "d49", "d73", "d75", "d98", "d117"].map { "frus1961-63v06/\($0)" })
        print(result.summary(volumes: ParityFixtures.volumes.count))
    }
}
