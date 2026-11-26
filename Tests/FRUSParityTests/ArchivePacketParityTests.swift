// An Archives Visit's packet through the API (PLAN's S30d), over the kit's fixture index imported as an export, held to the
// kit: the packet of a plan seeding every fixture document, with tiers, notes, exclusions and an orphan, is the kit's
// exporter's text for the same plan, to the byte, with the day given, as the app's sheet renders it, the whole plan and each
// repository's slice, each repository's inquiry draft as Copy inquiry draft copies it, the repositories it covers, and the
// file saved as text; after the sheet's writes, the topic and the deliverables, the kit's text of the plan as written,
// derived again. A plan made here, by the ways in's adds and the editor's writes, exported as JSON and imported again on a
// server of its own, derives the same targets, stored state and packet, and derives as the kit derives the plan the export
// holds, the check the owner chose on 23 November over one in the Mac app. And a collection authority's record's citing
// documents are the kit's match over the fixture index, to the app's ceiling.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct ArchivePacketParityTests {
    static let day = "2026-11-25"
    static let noon = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!

    /// The kit's packet of `plan` derived as `derived`, as the app's sheet renders it (`render(_:)`), on the day given.
    static func kitPacket(_ derived: ArchiveVisitDerivation.Derived, plan: ArchiveVisitPlanExport, scope: String?) -> String {
        var exporter = TripPacketExporter(model: derived.model, projectName: ArchiveVisitPlanWrites.displayName(of: plan.name))
        exporter.facilityScope = scope
        exporter.deliverables = plan.deliverables
        exporter.overlay = derived.overlay
        exporter.seededDocumentCount = derived.seededDocumentCount
        exporter.resolvedDocumentCount = derived.indexedDocumentCount
        exporter.generatedOn = noon
        return exporter.export()
    }

    static func packet(_ session: CollectionExportParityTests.Session, _ id: UUID, _ query: String) async throws -> VisitPacket {
        try ServedFixture.decode(VisitPacket.self, try await session.get("/api/v1/me/visits/\(id.uuidString)/packet?\(query)"))
    }

    static func escaped(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }

    @Test func thePacketThroughTheAPIIsTheKitsExportersTextToTheByte() async throws {
        let built = try await FixtureIndex.value()
        let documents = try RelatedDocumentsParityTests.documents(in: built)
        let bare = try await ArchiveVisitParityTests.kit(ArchiveVisitParityTests.everyDocument(documents), over: built)
        let keys = bare.model.targets.map(\.key)
        let lots = keys.filter { $0.hasPrefix("lot|") }
        let raw = try #require(keys.first { $0.hasPrefix("r|") })
        try #require(lots.count >= 2, "two lots at College Park, one tiered with a note, the other excluded: \(keys)")
        let targets = [
            ArchiveVisitParityTests.stored(lots[0], tier: ArchiveVisitParityTests.firstTier.id, note: "Box 4"),
            ArchiveVisitParityTests.stored(lots[1], included: false),
            ArchiveVisitParityTests.stored(raw, tier: ArchiveVisitParityTests.secondTier.id, note: "Ask at the desk"),
            ArchiveVisitParityTests.stored("decimal|737.00/1-161", included: false, note: "An orphan"),
        ]
        let plan = ArchiveVisitParityTests.everyDocument(documents, targets: targets)
        let kit = try await ArchiveVisitParityTests.kit(plan, over: built)
        let offered = TripPacketExporter.offeredRepositories(model: kit.model, overlay: kit.overlay)
        #expect(!offered.isEmpty, "the packet covers a repository")
        let file = try ImportFixtures.file(ArchiveVisitParityTests.envelope([plan]))
        let id = ArchiveVisitParityTests.planId
        let title = ArchiveVisitPlanWrites.displayName(of: plan.name)

        try await ServedFixture.run { client, _ in
            #expect(try await ImportServer.importing(file, with: client).state == .succeeded)
            let session = try await CollectionExportParityTests.Session.open(client)
            let whole = try await Self.packet(session, id, "day=\(Self.day)")
            let text = try #require(whole.text)
            #expect(text == Self.kitPacket(kit, plan: plan, scope: nil), "the whole plan's packet, the kit's to the byte")
            #expect(text.contains("Generated 2026-11-25.") && text.contains("## What this packet covers"))
            #expect(whole.repositories == offered && whole.repository == nil && whole.day == Self.day)
            #expect(whole.drafts.map(\.repository) == offered)
            for draft in whole.drafts {
                #expect(draft.text == TripPacketExporter.copiedInquiryDraft(model: kit.model, projectName: title, overlay: kit.overlay,
                                                                            repository: draft.repository),
                        "Copy inquiry draft for \(draft.repository)")
            }
            // Each repository's slice, its draft and its links with the coverage report still the whole plan's.
            for repository in offered {
                let scoped = try await Self.packet(session, id, "repository=\(Self.escaped(repository))&day=\(Self.day)")
                #expect(scoped.repository == repository)
                #expect(scoped.text == Self.kitPacket(kit, plan: plan, scope: repository), "the slice of \(repository)")
            }
            #expect(whole.title == title && whole.fileName == TripPacketPDFRenderer.fileName(title: title))
            #expect(whole.topic == plan.inquiryText && whole.researchQuestion == nil)

            // The text saved is the text shown.
            let saved = try await session.get("/api/v1/me/visits/\(id.uuidString)/packet/file?format=text&day=\(Self.day)")
            #expect(Data(buffer: saved.body) == Data(text.utf8))

            // The sheet's writes: the topic and two deliverables; the packet, the kit's over the plan as written, derived
            // again by the kit with its new topic, which the server sets over the model it kept.
            _ = try await session.send(.patch, "/api/v1/me/visits/\(id.uuidString)", try CollectionExportParityTests.json([
                "inquiryText": "The Vienna letters, June 1961", "deliverables": ["includeLinks": false, "includeCitationCrib": true],
            ]))
            var rewritten = plan
            rewritten.inquiryText = "The Vienna letters, June 1961"
            rewritten.deliverables = ArchiveVisitDeliverables(includeLinks: false, includeCitationCrib: true)
            let rederived = try await ArchiveVisitParityTests.kit(rewritten, over: built)
            let written = try await Self.packet(session, id, "day=\(Self.day)")
            #expect(written.text == Self.kitPacket(rederived, plan: rewritten, scope: nil), "the packet of the plan as written")
            #expect(written.text?.contains("Topic: The Vienna letters, June 1961") == true)
            #expect(written.text?.contains("## Citing what you find") == true && written.text?.contains("Plan your visit:") == false)
            #expect(written.deliverables == .init(includeLinks: false, includeTargets: true, includeInquiry: true, includeCitationCrib: true))
            for draft in written.drafts {
                #expect(draft.text == TripPacketExporter.copiedInquiryDraft(model: rederived.model, projectName: title,
                                                                            overlay: rederived.overlay, repository: draft.repository))
            }
        }
    }

    /// A plan made here: its documents added by the picker's New row and an add, a tier given, a note, an exclusion, the
    /// topic and the deliverables written; exported as JSON and imported again on a server of its own, it derives the
    /// same targets, the same stored state and the same packet, and the kit's derivation of the plan the export holds.
    @Test func aPlanMadeHereExportedAndImportedAgainDerivesTheSameTargets() async throws {
        let built = try await FixtureIndex.value()
        let documents = try RelatedDocumentsParityTests.documents(in: built)
        let half = documents.count / 2
        let made: Made = try await ServedFixture.run { client, _ in
            let session = try await CollectionExportParityTests.Session.open(client)
            let created = try ServedFixture.decode(VisitPlanDetail.self, try await session.send(.post, "/api/v1/me/visits",
                try CollectionExportParityTests.json([
                    "name": "Made on the web", "includeSource": true, "includeExternalRefs": false,
                    "documents": documents.prefix(half).map { ["volumeId": $0.volumeId, "documentId": $0.documentId] },
                ])))
            let path = "/api/v1/me/visits/\(created.id)"
            _ = try await session.send(.post, "\(path)/documents", try CollectionExportParityTests.json([
                "includeSource": false, "includeExternalRefs": true,
                "documents": documents.map { ["volumeId": $0.volumeId, "documentId": $0.documentId] },
            ]))
            let tiered = try ServedFixture.decode(VisitPlanDetail.self, try await session.send(.post, "\(path)/tiers"))
            let tier = try #require(tiered.tiers.first?.id)
            let targets = tiered.sections.flatMap(\.targets)
            try #require(targets.count >= 3, "the plan derives targets: \(targets.map(\.key))")
            _ = try await session.send(.patch, "\(path)/targets", try CollectionExportParityTests.json(["key": targets[0].key, "tierId": tier]))
            _ = try await session.send(.patch, "\(path)/targets", try CollectionExportParityTests.json(["key": targets[1].key, "note": "Box 4"]))
            _ = try await session.send(.patch, "\(path)/targets", try CollectionExportParityTests.json(["key": targets[2].key, "included": false]))
            _ = try await session.send(.patch, path, try CollectionExportParityTests.json([
                "inquiryText": "The letters", "deliverables": ["includeCitationCrib": true],
            ]))
            let detail = try ServedFixture.decode(VisitPlanDetail.self, try await session.get(path))
            let packet = try ServedFixture.decode(VisitPacket.self, try await session.get("\(path)/packet?day=\(Self.day)"))
            let export = Data(buffer: try await session.get("/api/v1/me/export").body)
            return Made(detail: detail, packet: packet, export: export)
        }
        #expect(made.detail.documents.count == documents.count && made.detail.storedTargets.isEmpty)
        #expect(made.detail.sections.flatMap(\.targets).filter { $0.tierId != nil || $0.note != nil || $0.excluded }.count == 3)

        // The plan as the export holds it: the kit's derivation of it is what the server showed.
        let envelope = try ResearchDataEnvelope.makeDecoder().decode(ResearchDataEnvelope.self, from: made.export)
        let plan = try #require(envelope.archiveVisits.first { $0.id.uuidString == made.detail.id })
        #expect(plan.targets.count == 3 && plan.tiers.count == 1 && plan.deliverables.includeCitationCrib)
        let kit = try await ArchiveVisitParityTests.kit(plan, over: built)
        #expect(made.detail == ArchiveVisitParityTests.expected(plan, kit, read: made.detail))
        #expect(made.packet.text == Self.kitPacket(kit, plan: plan, scope: nil))

        // Imported again, on a server of its own: the same plan, targets, stored state, tiers, seeds and packet.
        try await ServedFixture.run { client, _ in
            #expect(try await ImportServer.importing(made.export, with: client).state == .succeeded)
            let session = try await CollectionExportParityTests.Session.open(client)
            let again = try ServedFixture.decode(VisitPlanDetail.self, try await session.get("/api/v1/me/visits/\(made.detail.id)"))
            #expect(again.sections == made.detail.sections, "the same targets, in the same sections, with their tiers, notes and exclusions")
            #expect(again.storedTargets == made.detail.storedTargets && again.tiers == made.detail.tiers)
            #expect(again.documents == made.detail.documents && again.summary == made.detail.summary)
            // The whole answer, but for the plan's two dates, which the export writes to the second.
            var expected = made.detail
            expected.createdAt = again.createdAt
            expected.lastModified = again.lastModified
            #expect(again == expected)
            #expect(again.lastModified.map { String($0.prefix(19)) } == made.detail.lastModified.map { String($0.prefix(19)) })
            let packet = try ServedFixture.decode(VisitPacket.self, try await session.get("/api/v1/me/visits/\(made.detail.id)/packet?day=\(Self.day)"))
            #expect(packet.text == made.packet.text)
        }
    }

    struct Made: Sendable {
        let detail: VisitPlanDetail
        let packet: VisitPacket
        let export: Data
    }

    /// In Your Library's add: the record's citing documents, every one, as the kit's match runs over the fixture index at
    /// the app's ceiling, with the record's name.
    @Test func aRecordsCitingDocumentsAreTheKitsMatchToTheAppsCeiling() async throws {
        let built = try await FixtureIndex.value()
        let authority = try CollectionAuthorityIndex(contentsOf: ServedFixture.resources.appendingPathComponent("collection-authority.json"))
        try await ServedFixture.run { client, _ in
            let session = try await CollectionExportParityTests.Session.open(client)
            let sources = try ServedFixture.decode(SourceExplorerAnswer.self,
                                                   try await session.get("/api/v1/volumes/frus1961-63v06/documents/d10/sources"))
            let id = try #require(sources.collection?.id)
            let record = try #require(authority.record(id: id))
            let answer = try ServedFixture.decode(ArchivalCollectionDocuments.self,
                                                  try await session.get("/api/v1/me/archival-collection/documents?id=\(Self.escaped(id))"))
            let kit = try await built.index.pipeline.collectionNeighbors(
                lotFileNorm: record.lotFileNorm, repository: record.repository, recordGroup: record.recordGroup,
                names: [record.name] + record.aliases, limit: 20_000)
            #expect(!answer.documents.isEmpty && answer.name == record.name && answer.totalCount == kit.totalCount)
            #expect(answer.documents.map { "\($0.volumeId)/\($0.documentId)" } == kit.documents.map { "\($0.volumeId)/\($0.documentId)" })
            #expect(answer.documents.contains { $0.volumeId == "frus1961-63v06" && $0.documentId == "d10" })
        }
    }
}
