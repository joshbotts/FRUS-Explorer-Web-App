// Check 8's comparator, reached from the parity suite (S23c's pin move, for FRUS-Explorer#1894): the
// Source Explorer export generator's record builder, `SourceExplorerExportRunner.exportRecord`, public
// since #1894, called without `@testable` over the app's bundled files, as S22d's
// `frus-parity check-source-explorer` will call it for each source note it resolves through the API;
// `Package.swift` links the cores into the harness for it. The generator's reading is the export's own,
// apart from the kit's `SourceExplorerResolution`, which is what the check holds the server's answer to.
// The cores declare eight public names FRUSCoreKit declares too, CentralFilesIndex,
// CollectionAuthorityIndex, CountryRoll, LotFileEntry, NumericalFileIndex, NumericalFileRoll,
// SourceProvenanceIndex (public in the kit since FRUS-Explorer#1899) and VolumeSourcesIndex, and two the
// kit keeps internal, CountrySeriesIndex and GeoKeyNormalizer, so a file that reads them names them by
// module, as this one does, which imports no FRUSCoreKit.

import CentralFilesIndexGeneratorCore
import Foundation
import SourceExplorerExportGeneratorCore
import SourceNoteKit
import Testing
import VolumeSourcesIndexGeneratorCore

@Suite struct SourceExplorerComparatorTests {
    /// A lot citation's record, built from the bundled central-files index, volume sources and
    /// collection authority: the lot's strategy, its authority record and the live lookup the export
    /// says a Catalog search would take.
    @Test func theExportGeneratorsRecordBuilderIsReachableWithoutTestable() throws {
        let resources = ServedFixture.resources
        let central = resources.appendingPathComponent("central-files-index.json")
        let record = SourceExplorerExportRunner.exportRecord(
            volumeId: "frus1952-54v02p1", documentId: "d41", rawNote: "S/S–NSC files, lot 63 D 351, NSC 140",
            documentYear: 1953, parser: SourceNoteParser(),
            lotResolver: try BundledLotResolver(indexURL: central),
            centralFiles: try JSONDecoder().decode(
                CentralFilesIndexGeneratorCore.CentralFilesIndex.self, from: Data(contentsOf: central)),
            volumeSources: try JSONDecoder().decode(
                VolumeSourcesIndexGeneratorCore.VolumeSourcesIndex.self,
                from: Data(contentsOf: resources.appendingPathComponent("volume-sources-index.json"))),
            authority: try AuthorityLookup(indexURL: resources.appendingPathComponent("collection-authority.json")))
        #expect(record.id == "frus1952-54v02p1/d41")
        #expect(record.strategy == "lotFile")
        #expect(record.resolution.collectionAuthority?.id == "lot:63D351")
        #expect(record.resolution.liveLookupRoute == "catalogLotVariantsQuery")
    }
}
