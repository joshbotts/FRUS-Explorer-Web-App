// The four data files that change what an index holds: present in the submodule, and each decodes.

@testable import FRUSCoreKit
import FRUSParity
import Foundation
import Testing

@Suite struct IndexResourcesTests {
    /// `IndexingResources.loading(fromDirectory:)` refuses a folder lacking one of the four files,
    /// but a file that is present and will not decode answers nil, and the index is built without it
    /// while every step reports success. Check 2 would show a missing subject or authority file, but
    /// not the broken-references index, which flags no cross-reference in the fixtures. So each
    /// file is decoded here, through the kit's internal providers, and holds what the index reads.
    @Test func theFourIndexFilesArePresentAndDecode() throws {
        let directory = Repository.layout.upstream.appendingPathComponent(ParityIndex.resourcesPath)
        #expect(IndexingResources.indexResourceNames
                == ["person-authority-index", "document-subject-index", "decimal-class-labels", "broken-refs-index"])
        for name in IndexingResources.indexResourceNames {
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(name).json").path), "\(name).json")
        }
        let resources = try IndexingResources.loading(fromDirectory: directory)
        #expect(resources.personAuthority()?.authority.isEmpty == false, "person-authority-index")
        #expect(resources.documentSubjects()?.subjectRows(forVolume: "frus1961-63v06").isEmpty == false, "document-subject-index")
        #expect(resources.decimalClassLabels()?.schedules.isEmpty == false, "decimal-class-labels")
        #expect(resources.brokenRefs()?.records.isEmpty == false, "broken-refs-index")
    }
}
