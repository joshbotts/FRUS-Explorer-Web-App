// A Standalone server's side-load in its library (PLAN's S21e): the file's name gives the volume's id, as
// the app's validator takes it, only for a name that is one visible path component; the kit's validator
// checks the file, which takes its name by link(2) whole or not at all, and refuses a volume present; a
// volume the catalogue lacks needs a header the kit's `LocalVolumeCatalog` reads; and the store keeps the
// row `sideloaded`, on every store `UserStoreKind.available` names.

import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SideloadTests {
    /// A volume's file's name, and the id it gives.
    @Test func aNameGivesAVolumeIdOnlyWhenItIsOneVisiblePathComponent() {
        #expect(VolumeLibrary.sideloadedVolumeId(fromFileName: "frus1969-76v99.xml") == "frus1969-76v99")
        #expect(VolumeLibrary.sideloadedVolumeId(fromFileName: "Draft_2.1.xml") == "Draft_2.1")
        for name in ["", ".xml", "frus.XML", "frus", "../frus.xml", "a/b.xml", "a\\b.xml", ".hidden.xml", "-dash.xml", "_x.xml",
                     "name with space.xml", "frus\u{0}.xml", "x.figures.xml", "x.frusmeta.xml", "frús.xml",
                     String(repeating: "v", count: 129) + ".xml"] {
            #expect(VolumeLibrary.sideloadedVolumeId(fromFileName: name) == nil, "\(name)")
        }
        #expect(VolumeLibrary.sideloadedVolumeId(fromFileName: String(repeating: "v", count: 128) + ".xml") != nil)
    }

    /// The library side-loads a catalogue volume's file and one the catalogue lacks, refuses one present, one
    /// that is no FRUS volume and one whose header cannot be read, and leaves no staging folder behind.
    @Test func theLibrarySideloadsWholeOrNotAtAll() async throws {
        let f = try await LibraryTests.open(github: FakeGitHub())
        defer { withExtendedLifetime(f.directory) {} }
        func stage(_ id: String, _ text: String) throws -> URL {
            let staged = try f.library.sideloadStaging(for: id)
            try text.write(to: staged, atomically: false, encoding: .utf8)
            return staged
        }
        let tei = try String(contentsOf: RepositoryFiles.tei.appendingPathComponent("frus1894Nicaragua.xml"), encoding: .utf8)
        #expect(try await f.library.sideload(staged: try stage("frus1894Nicaragua", tei), requestedBy: "alice") == "frus1894Nicaragua")
        #expect(try await f.library.sideload(staged: try stage("draft-volume", tei), requestedBy: nil) == "draft-volume")
        #expect(f.library.isVolumeDownloaded("frus1894Nicaragua") && f.library.isVolumeDownloaded("draft-volume"))
        #expect(try Data(contentsOf: f.volumes.appendingPathComponent("draft-volume.xml")) == Data(tei.utf8))
        await #expect(throws: VolumeLibrary.SideloadRefusal.exists("draft-volume", sentence: SideloadError.duplicateVolume(volumeId: "draft-volume").errorDescription!)) {
            try await f.library.sideload(staged: try stage("draft-volume", tei), requestedBy: nil)
        }
        await #expect(throws: VolumeLibrary.SideloadRefusal.self) {
            try await f.library.sideload(staged: try stage("not-a-volume", "<html><p>no</p></html>"), requestedBy: nil)
        }
        // A header the kit's parser stops reading at an entity that expands without end, which libxml2 refuses.
        var bomb = "<?xml version=\"1.0\"?>\n<!DOCTYPE TEI [\n<!ENTITY a \"aaaaaaaaaa\">\n"
        for level in 1...9 { bomb += "<!ENTITY a\(level) \"" + String(repeating: "&a\(level == 1 ? "" : String(level - 1));", count: 10) + "\">\n" }
        bomb += "]>\n<TEI xmlns=\"http://www.tei-c.org/ns/1.0\"><teiHeader><title>&a9;</title></teiHeader></TEI>\n"
        let unreadable = bomb
        await #expect(throws: VolumeLibrary.SideloadRefusal.self) {
            try await f.library.sideload(staged: try stage("no-header", unreadable), requestedBy: nil)
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: f.volumes.path).sorted()
        #expect(left == ["draft-volume.xml", "frus1894Nicaragua.xml"], "\(left)")
        #expect(await f.library.isSideloaded("frus1894Nicaragua"))
        #expect(await f.library.isSideloaded("draft-volume"))
        // Removed by its file's name, a volume the catalogue lacks among them, with the sidecar beside it.
        try "{}".write(to: f.volumes.appendingPathComponent("draft-volume.frusmeta.json"), atomically: true, encoding: .utf8)
        try await f.library.remove("draft-volume")
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.volumes.path) == ["frus1894Nicaragua.xml"])
        #expect(try f.store.libraryVolume("draft-volume") == nil)
    }

    /// The store keeps a side-load's row: downloaded, marked side-loaded, with the file's hash, length and
    /// time and no figure images, over any row it had; a download of the volume ends the mark.
    @Test(arguments: UserStoreKind.available)
    func theStoreKeepsASideloadMarked(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let (t1, t2) = (LibraryTests.start, LibraryTests.start.addingTimeInterval(60))
        try store.recordLibraryFailure("v1", error: "It failed.", at: t1)
        try store.recordLibrarySideload("v1", LibraryDownloadRecord(blobSHA: "abc", sizeBytes: 12, modifiedAt: t1, figuresStored: 0, figuresRefused: 0),
                                        requestedBy: "alice", at: t2)
        #expect(try store.libraryVolume("v1") == LibraryVolume(volumeId: "v1", state: .downloaded, blobSHA: "abc", sizeBytes: 12, modifiedAt: t1,
                                                                 downloadedAt: t2, sideloaded: true, figuresStored: 0, figuresRefused: 0,
                                                                 requestedBy: "alice", updatedAt: t2))
        try store.recordLibraryDownload("v1", LibraryDownloadRecord(blobSHA: "def", sizeBytes: 13, figuresStored: 1, figuresRefused: 0), at: t2)
        #expect(try store.libraryVolume("v1")?.sideloaded == false)
    }
}
