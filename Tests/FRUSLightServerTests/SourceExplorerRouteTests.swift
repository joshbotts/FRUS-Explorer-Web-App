// Source Explorer's routes (PLAN's S22d), over the synthetic export: what a request may ask and what is refused,
// for a document's sources, the archival neighbours and a collection's record, and the answer while no index is
// served; how a neighbours request is read, as the app's sheet reads its own; and the panels the app's view draws
// for notes of the kinds the fixture volumes lack, built from the kit's resolution with the server's files. Every
// fixture note's record is held to the export generator's through the API in `SourceExplorerParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SourceExplorerRouteTests {
    static let volume = UserHalfSearchTests.volume

    @Test func theSourcesRequestsAndRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let base = "/api/v1/volumes/\(Self.volume)/documents/d1/sources"
            let answer = try decode(SourceExplorerAnswer.self, try await client.execute(uri: base, method: .get))
            #expect(answer.volumeId == Self.volume && answer.documentId == "d1")
            #expect(answer.hasSourceNote == !answer.rawSourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            // A note's sections, or a note-less document's: the provenance panels for one, never both.
            #expect(answer.hasSourceNote || (answer.provenance.isEmpty && answer.classificationMarking == nil))
            #expect(problemCode(try await client.execute(uri: "\(base)?scope=all", method: .get)) == "UNKNOWN_PARAMETER")
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/frus1800nowhere/documents/d1/sources", method: .get))
                    == "VOLUME_NOT_FOUND")
            let long = String(repeating: "d", count: 257)
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/\(Self.volume)/documents/\(long)/sources", method: .get))
                    == "INVALID_PARAMETER")
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/\(Self.volume)/documents/d999/sources", method: .get))
                    == "DOCUMENT_NOT_FOUND")
        }
        let waiting = try await UserDataFixture()
        defer { withExtendedLifetime(waiting) {} }
        try await waiting.app.test(.router) { client in
            for path in ["/api/v1/volumes/\(Self.volume)/documents/d1/sources",
                         "/api/v1/archival-neighbors?volumeId=\(Self.volume)&documentId=d1",
                         "/api/v1/archival-collection?id=lot:66D204",
                         "/api/v1/volumes/\(Self.volume)/sources"] {
                let response = try await client.execute(uri: path, method: .get)
                #expect(response.status == .serviceUnavailable && problemCode(response) == "INDEX_NOT_READY", "\(path)")
            }
        }
    }

    @Test func theNeighboursRequestsAndRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let base = "/api/v1/archival-neighbors"
            let document = try decode(ArchivalNeighborsAnswer.self,
                                      try await client.execute(uri: "\(base)?volumeId=\(Self.volume)&documentId=d1", method: .get))
            // A document's list opens on All volumes, anchored on its volume, with the sheet's scopes.
            #expect(document.scope == "all" && document.anchorVolumeId == Self.volume)
            #expect(document.scopes.first == "volume" && document.scopes.last == "all")
            #expect(document.documents.allSatisfy { !($0.volumeId == Self.volume && $0.documentId == "d1") })
            let volume = try decode(ArchivalNeighborsAnswer.self,
                                    try await client.execute(uri: "\(base)?volumeId=\(Self.volume)&documentId=d1&scope=volume", method: .get))
            #expect(volume.scope == "volume" && volume.documents.allSatisfy { $0.volumeId == Self.volume })
            // A Sources row's opens on This volume; a class alone has no picker.
            let row = try decode(ArchivalNeighborsAnswer.self,
                                 try await client.execute(uri: "\(base)?lotFile=66%20D%20204&anchor=\(Self.volume)", method: .get))
            #expect(row.scope == "volume" && row.anchorVolumeId == Self.volume)
            let cls = try decode(ArchivalNeighborsAnswer.self, try await client.execute(uri: "\(base)?decimalClass=611.61", method: .get))
            #expect(cls.scopes.isEmpty && cls.scope == "all" && cls.anchorVolumeId == nil)
            let collection = try decode(ArchivalNeighborsAnswer.self, try await client.execute(uri: "\(base)?collection=lot:66D204", method: .get))
            #expect(collection.scopes.isEmpty && collection.scope == "all")
            for (query, code) in [
                ("", "INVALID_PARAMETER"), ("volumeId=\(Self.volume)", "INVALID_PARAMETER"),
                ("volumeId=frus1800nowhere&documentId=d1", "VOLUME_NOT_FOUND"), ("lotFile=1&anchor=frus1800nowhere", "VOLUME_NOT_FOUND"),
                ("collection=nowhere", "COLLECTION_NOT_FOUND"), ("decimalClass=611.61&scope=volume", "SCOPE_NOT_OFFERED"),
                ("volumeId=\(Self.volume)&documentId=d1&scope=everywhere", "INVALID_PARAMETER"),
                ("volumeId=\(Self.volume)&documentId=d1&year=12", "INVALID_PARAMETER"), ("degree=1", "UNKNOWN_PARAMETER"),
            ] {
                #expect(problemCode(try await client.execute(uri: "\(base)?\(query)", method: .get)) == code, "\(query)")
            }
            let aliases = (0...ArchivalNeighborsRoutes.maximumAliases).map { "aliasName=n\($0)" }.joined(separator: "&")
            #expect(problemCode(try await client.execute(uri: "\(base)?lotFile=1&\(aliases)", method: .get)) == "INVALID_PARAMETER")
        }
    }

    @Test func aNeighboursRequestIsReadAsTheSheetReadsIts() throws {
        let resources = try TestResources.value()
        func request(_ query: String) throws -> ArchivalNeighborsRoutes.NeighborsRequest {
            try ArchivalNeighborsRoutes.neighborsRequest(try FormQuery(query), resources: resources)
        }
        let document = try request("volumeId=\(Self.volume)&documentId=d3&year=1961")
        #expect(document == .document(volumeId: Self.volume, documentId: "d3", documentYear: 1961))
        #expect(document.defaultScope == .all && document.anchorVolumeId == Self.volume && document.aliasFallback == nil)
        let row = try request("lotFile=66%20D%20204&recordGroup=59&aliasLot=66D204&aliasName=Presidential%20Correspondence&anchor=\(Self.volume)")
        #expect(row.defaultScope == .volume && row.anchorVolumeId == Self.volume)
        #expect(row.aliasFallback?.lotFileNorm == "66D204" && row.aliasFallback?.names == ["Presidential Correspondence"])
        // A Sources row with no anchor opens on All volumes; a class with nothing else is the class's request.
        #expect(try request("lotFile=1").defaultScope == .all)
        #expect(try request("decimalClass=611.61") == .decimalClass("611.61"))
        #expect(try request("decimalClass=611.61&anchor=\(Self.volume)").defaultScope == .volume)
        guard case .collection(let lot, _, _, let names) = try request("collection=lot:66D204") else {
            Issue.record("a collection's request")
            return
        }
        let record = try #require(resources.collectionAuthority?.record(id: "lot:66D204"))
        #expect(lot == record.lotFileNorm && names == [record.name] + record.aliases)
    }

    @Test func aCollectionsRecordAndItsRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let record = try #require(try TestResources.value().collectionAuthority?.record(id: "lot:66D204"))
        try await fixture.app.test(.router) { client in
            let answer = try decode(ArchivalCollectionAnswer.self,
                                    try await client.execute(uri: "/api/v1/archival-collection?id=lot:66D204", method: .get))
            #expect(answer.id == record.id && answer.name == record.name && answer.aliases == record.aliases)
            #expect(answer.lotFileNorm == record.lotFileNorm && answer.volumes.map(\.volumeId) == record.volumeIds)
            #expect(answer.volumes.allSatisfy { $0.title != nil })
            #expect(answer.children.map(\.name) == record.children.map(\.name))
            for (query, code) in [("", "INVALID_PARAMETER"), ("id=", "INVALID_PARAMETER"), ("id=nowhere", "COLLECTION_NOT_FOUND"),
                                  ("id=a&id=b", "INVALID_PARAMETER"), ("scope=all", "UNKNOWN_PARAMETER")] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/archival-collection?\(query)", method: .get)) == code, "\(query)")
            }
        }
    }

    /// The panels for notes of the kinds the fixtures lack, through the kit's resolution with no index, as the app's
    /// view draws them while its index starts.
    @Test func aVolumesOutlineAndItsRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let base = "/api/v1/volumes/\(Self.volume)/sources"
            let outline = try decode(VolumeSourcesOutline.self, try await client.execute(uri: base, method: .get))
            #expect(outline.volumeId == Self.volume)
            #expect(problemCode(try await client.execute(uri: "\(base)?scope=all", method: .get)) == "UNKNOWN_PARAMETER")
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/frus1800nowhere/sources", method: .get)) == "VOLUME_NOT_FOUND")
        }
    }

    /// The outline's rows as the app's view draws them, from rows of the kinds a volume's Sources section holds,
    /// with the server's bundled files: a lot's record and entry numbers, a record group the row names and not one
    /// it inherits, nothing for a lot NARA divides, and plain prose and published works.
    @Test func theOutlinesRows() throws {
        let resources = try TestResources.value()
        let rows = VolumeSourcesRoutes.outline(volumeId: Self.volume, entries: [
            VolumeSourceEntry(kind: .prose, rawText: "Unpublished Sources", note: "A note no prose row shows."),
            VolumeSourceEntry(kind: .item, depth: 0, isHeading: true, rawText: "National Archives and Records Administration"),
            VolumeSourceEntry(kind: .item, depth: 1, recordGroup: "59", rawText: "RG 59, Records of the Department of State"),
            VolumeSourceEntry(kind: .item, depth: 2, recordGroup: "59", rawText: "Central Files, 1970–1973"),
            VolumeSourceEntry(kind: .item, depth: 2, recordGroup: "59", lotFile: "66 D 204", lotFileNorm: "66D204",
                              rawText: "Presidential Correspondence: Lot 66 D 204", note: "Correspondence of the President."),
            VolumeSourceEntry(kind: .item, depth: 2, recordGroup: "59", lotFile: "62 D 430", lotFileNorm: "62D430",
                              rawText: "Executive Secretariat Files: Lot 62 D 430"),
            VolumeSourceEntry(kind: .bibliography, lotFile: "66 D 204", rawText: "A book that names Lot 66 D 204."),
        ], resources: resources).rows
        #expect(rows.map(\.kind) == ["prose", "item", "item", "item", "item", "item", "bibliography"])
        #expect(rows[0].note == nil && rows[0].catalogURL == nil)
        #expect(rows[1].isHeading && rows[1].catalogURL == nil)
        #expect(rows[2].catalogURL == "https://catalog.archives.gov/id/388")
        // A row beneath the record group that does not name it borrows no link.
        #expect(rows[3].catalogURL == nil)
        #expect(rows[4].catalogURL == "https://catalog.archives.gov/id/2538452" && rows[4].entryNumbers == ["A1 1590"])
        #expect(rows[4].note == "Correspondence of the President." && rows[4].seriesEntryNumbers == nil)
        // NARA divides 62 D 430 across several series, so it resolves to none of them.
        #expect(rows[5].catalogURL == nil && rows[5].entryNumbers == nil)
        #expect(rows[6].catalogURL == nil && rows[6].entryNumbers == nil)
    }

    @Test func thePanelsTheFixturesLack() async throws {
        let resources = try TestResources.value()
        func answer(_ note: String, dateline: String? = nil) async -> SourceExplorerAnswer {
            let entry = DocumentBrowserEntry(documentId: "d1", volumeId: Self.volume, header: "A document", dateline: dateline, sourceNote: note)
            let dependencies = SourceExplorerResolution.Dependencies(
                collectionAuthority: resources.collectionAuthority, centralFiles: resources.archivalIndexes.centralFiles,
                chiefsOfMission: .empty, presidentialLibraries: resources.sourceExplorer(\.presidentialLibraries),
                curatedLibraries: resources.sourceExplorer(\.curatedLibraries),
                parsedDocuments: SourceExplorerRoutes.ReaderDocuments(reader: ReaderService(volumesDirectory: RepositoryFiles.resources, resources: resources)),
                volumeURL: nil)
            let resolution = await SourceExplorerResolution(rawSourceNote: note).resolved(
                route: CountrySeriesRoute(header: entry.header, dateline: dateline, year: nil, volumeId: nil, documentId: nil),
                pipeline: nil, dependencies: dependencies)
            return SourceExplorerRoutes.answer(entry: entry, resolution: resolution, resources: resources)
        }
        func kinds(_ answer: SourceExplorerAnswer) -> [String] { answer.provenance.map(\.kind) }

        // RG 256: the Paris Peace Conference's records, from the kit, after the Provenance rows.
        let paris = await answer("Paris Peace Conf. 185.001/28: Telegram")
        #expect(kinds(paris).prefix(2) == ["centralFiles", "parisPeace"])
        let peace = try #require(paris.provenance.first { $0.kind == "parisPeace" })
        #expect(peace.title == ParisPeaceRecords.sectionTitle && peace.records?.count == 2 && peace.findingAids?.isEmpty == false)

        // A 1906–1910 file number: the Numerical File's rolls or its gap, the year read from the dateline.
        let numerical = await answer("File No. 551/79", dateline: "Washington, March 4, 1908.")
        #expect(numerical.year == 1908 && kinds(numerical).contains("numericalFile"))

        // A decimal file in a digitized class: NARA's scans of the range its serial lands in.
        let scanned = await answer("File No. 763.72111/6000.")
        let scans = try #require(scanned.provenance.first { $0.kind == "digitizedScans" })
        #expect(scans.scanState == "resolved" && scans.scans?.count == 1 && scans.caveat == SourceExplorerPanels.scanCaveat)

        // A lot cited through the National Archives: its lot cards, and the guarded lot search for S22e.
        let nara = await answer("Source: National Archives, RG 59, S/P Files, Lot 64 D 563, Box 12. Secret.")
        #expect(nara.parsed.kind == "naraCollection" && nara.parsed.fields["lotFile"] != nil)
        #expect(kinds(nara).first == "naraCollection" && kinds(nara).last == "naraCatalog")
        #expect(nara.provenance.last?.catalogQuery?.route == "lotVariants" && nara.provenance.last?.catalogQuery?.manualSearchURL != nil)

        // A post's lot file (an F lot): RG 84's type and its catalogue search.
        let post = await answer("Moscow Embassy Files: Lot 64 F 75")
        #expect(post.parsed.kind == "lotFile" && post.parsed.fields["recordGroup"] == "RG-84")
        #expect(post.provenance.first?.postRecords == true && post.provenance.first?.recordGroup == "RG 84")
        #expect(post.provenance.last?.catalogQuery?.manualSearchURL != nil)

        // Previously published: the grammar's publication and what to look for, or none it recognizes.
        let papers = await answer("Source: Public Papers of the Presidents of the United States: John F. Kennedy, 1961, pp. 1–3.")
        #expect(kinds(papers) == ["previouslyPublished"] && papers.provenance.first?.publication == "publicPapers")
        let un = await answer("U.N. Doc. A/1857")
        #expect(kinds(un) == ["previouslyPublished"] && un.provenance.first?.publication == nil)

        // A note-less document of 1894, with no index: not checked, and the era's likely series.
        let noNote = await answer("", dateline: "Managua, February 1, 1894.")
        #expect(noNote.provenance.isEmpty && noNote.noSourceNote?.state == "notChecked" && noNote.noSourceNote?.predictedSeries == "diplomatic")
        #expect(noNote.noSourceNote?.reason == "noDocumentIdentity")
    }
}
