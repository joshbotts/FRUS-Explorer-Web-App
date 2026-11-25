// Archives Visits through the API (PLAN's S30c), over the kit's fixture index imported as an export, held to the kit: a
// plan seeding every fixture document, with stored state on targets it derives, a row minted under a key the re-index
// re-spelled, a row another is shown over and an orphan, derives through /api/v1/me/visits as `ArchiveVisitDerivation.derive`
// derives the same plan over the same index and the six bundled files, its sections, rows, words and stored targets; a
// write through the overlay of the plan as it stands writes the rows the kit's rule answers, the re-spelled row found
// through the overlay's stored keys; and the import fixture's Mac plan derives as its export says, its
// `decimal|737.00/1-161` an orphan. The view's order and words over the kit's values are `ArchiveVisitMirrorParityTests`'.

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

@Suite struct ArchiveVisitParityTests {
    /// The six bundled files the packet reads, decoded from the pinned resources apart from the server's, as a host
    /// decodes them.
    static func indexes() throws -> TripPacketIndexes {
        let resources = ServedFixture.resources
        func decoded<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            try JSONDecoder().decode(type, from: Data(contentsOf: resources.appendingPathComponent(name)))
        }
        return TripPacketIndexes(
            archival: ArchivalIndexes(centralFiles: try decoded(CentralFilesIndex.self, "central-files-index.json"),
                                      volumeSources: try decoded(VolumeSourcesIndex.self, "volume-sources-index.json"),
                                      claimants: try decoded(LotClaimantsIndex.self, "lot-claimants-index.json")),
            seriesFacts: try SeriesFactsIndex(contentsOf: resources.appendingPathComponent("series-facts-index.json")),
            digitizedRanges: try DigitizedRangeIndex(contentsOf: resources.appendingPathComponent("digitized-ranges-index.json")),
            rollScans: try RollScansIndex(contentsOf: resources.appendingPathComponent("roll-scans-index.json")))
    }

    /// The kit's derivation of `plan` over the fixture index the server serves, its three volumes indexed, and the
    /// bundled files, with the catalogue the app's editor hands its data source.
    @MainActor
    static func kit(_ plan: ArchiveVisitPlanExport, over built: FixtureIndex.Built) async throws -> ArchiveVisitDerivation.Derived {
        let catalogue = try FixedVolumeCatalogue(contentsOf: ServedFixture.resources.appendingPathComponent("manifest.json")).citableEntries
        let dataSource = TripPacketDataSource(pipeline: built.index.pipeline,
                                              manifestMap: Dictionary(catalogue.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }))
        return await ArchiveVisitDerivation.derive(plan: plan, indexedVolumeIds: Set(ParityFixtures.volumes), dataSource: dataSource,
                                                   indexes: try indexes())
    }

    static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    static let planId = ImportFixtures.id(300)
    static let firstTier = ArchiveVisitTier(id: ImportFixtures.id(301), label: "First morning", order: 0)
    static let secondTier = ArchiveVisitTier(id: ImportFixtures.id(302), order: 1)
    static let made = Self.date("2026-11-01T00:00:00Z")

    /// A plan seeding every fixture document, both halves on but for three: one without its source, one without its
    /// references and one with neither, which contributes nothing.
    static func everyDocument(_ documents: [DocumentKey], targets: [ArchiveVisitTargetExport] = []) -> ArchiveVisitPlanExport {
        let seeds = documents.enumerated().map { offset, document in
            ArchiveVisitDocumentExport(id: ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: document.compositeString),
                                       documentKey: document.compositeString, includeSource: offset != 0 && offset != 2,
                                       includeExternalRefs: offset != 1 && offset != 2, createdAt: made, lastModified: made)
        }
        return ArchiveVisitPlanExport(id: planId, name: "Every fixture document", inquiryText: "The fixtures' records", projectIds: [],
                                      tiers: [firstTier, secondTier], deliverables: ArchiveVisitDeliverables(), documents: seeds,
                                      targets: targets, createdAt: made, lastModified: made)
    }

    /// A stored target row as the app mints one, under its derived id.
    static func stored(_ key: String, tier: UUID? = nil, included: Bool = true, note: String? = nil,
                       created: String = "2026-11-02T00:00:00Z") -> ArchiveVisitTargetExport {
        ArchiveVisitTargetExport(id: ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: key), targetKey: key, tierId: tier,
                                 included: included, userNote: note, createdAt: Self.date(created),
                                 lastModified: Self.date(created))
    }

    static func envelope(_ plans: [ArchiveVisitPlanExport]) -> ResearchDataEnvelope {
        ResearchDataEnvelope(formatVersion: ResearchDataEnvelope.currentFormatVersion, exportedAt: Self.date("2026-11-03T00:00:00Z"),
                             notes: [], tags: [], tagAssignments: [], highlights: [], collections: [], prompts: [], projects: [],
                             summaries: [], archiveVisits: plans)
    }

    /// The API's answer as the kit's derivation of the same plan maps to it: the server's own mapping over the kit's
    /// `Derived`, with the facts and sparsity the server read, so that every derived value is the kit's.
    static func expected(_ plan: ArchiveVisitPlanExport, _ derived: ArchiveVisitDerivation.Derived, read answer: VisitPlanDetail)
        -> VisitPlanDetail {
        var expected = ArchiveVisitRoutes.detail(plan, derivation: VisitDerivation(derived: derived, facts: [:], sparsity: answer.sparsity),
                                                 projects: [])
        expected.documents = answer.documents
        expected.project = answer.project
        expected.createdAt = answer.createdAt
        expected.lastModified = answer.lastModified
        return expected
    }

    /// Each target the kit derives, as a line the answer's row must carry, read straight from the kit's values: key,
    /// label, section, records and access lines, claims, lots, tier, exclusion and note.
    static func lines(_ derived: ArchiveVisitDerivation.Derived) -> [String: String] {
        let overlay = derived.overlay
        return Dictionary(uniqueKeysWithValues: derived.model.targets.map { target in
            let parts: [String] = [
                target.label, ArchiveVisitCounts.sectionHeading(for: target), target.recordsLine ?? "-",
                TripPacketExporter.restrictionLines(target.restriction).joined(separator: " / "),
                "drawn \(target.drawnFrom.count): " + target.drawnFrom.prefix(8).map(\.id).joined(separator: ","),
                "pointed \(target.pointedAt.count): " + target.pointedAt.prefix(8).map { TripPacketExporter.footnoteLine(for: $0) }.joined(separator: " | "),
                "lots " + target.lots.map(\.lotAsPrinted).joined(separator: ","),
                "tier " + (overlay.tier(for: target.key)?.id.uuidString ?? "-"), "excluded \(overlay.excludedKeys.contains(target.key))",
                "note " + (overlay.notes[target.key] ?? "-"),
            ]
            return (target.key, parts.joined(separator: " ¶ "))
        })
    }

    static func lines(_ answer: VisitPlanDetail) -> [String: String] {
        Dictionary(uniqueKeysWithValues: answer.sections.flatMap { section in
            section.targets.map { target in
                let parts: [String] = [
                    target.label, section.heading, target.recordsLine ?? "-", target.accessLines.joined(separator: " / "),
                    "drawn \(target.drawnFromCount): " + target.drawnFrom.map { "\($0.volumeId)/\($0.documentId)" }.joined(separator: ","),
                    "pointed \(target.pointedAtCount): " + target.pointedAt.map(\.line).joined(separator: " | "),
                    "lots " + target.lots.map { String($0.title.dropFirst("Lot ".count).prefix { $0 != "—" }.dropLast()) }.joined(separator: ","),
                    "tier " + (target.tierId ?? "-"), "excluded \(target.excluded)", "note " + (target.note ?? "-"),
                ]
                return (target.key, parts.joined(separator: " ¶ "))
            }
        })
    }

    @Test func aPlanOfEveryFixtureDocumentDerivesThroughTheAPIAsTheKitDerivesIt() async throws {
        let built = try await FixtureIndex.value()
        let documents = try RelatedDocumentsParityTests.documents(in: built)
        // The targets the plan derives with no stored state, whose keys the stored rows below are written under.
        let bare = try await Self.kit(Self.everyDocument(documents), over: built)
        let keys = bare.model.targets.map(\.key)
        #expect(keys.count >= 12, "the fixtures derive targets of several forms: \(keys)")
        let forms = Set(bare.model.targets.map(\.form))
        #expect(forms.isSuperset(of: [.lotFile, .raw]), "\(forms)")
        // A key the v59 re-index's rule finds again once its spaces are gone (`ArchiveVisitTargetKeys.sameTarget`): a raw
        // note's, with a space added.
        let respelledTarget = try #require(keys.first { $0.hasPrefix("r|") && $0.contains(" ") })
        let respelled = respelledTarget.replacingOccurrences(of: " ", with: "  ")
        // A target two rows answer for: its own row, shown, and the re-spelled one of another, kept as superseded.
        let shownTarget = try #require(keys.first { $0.hasPrefix("r|") && $0.contains(" ") && $0 != respelledTarget })
        let supersededKey = shownTarget.replacingOccurrences(of: " ", with: "  ")
        let lot = try #require(keys.first { $0.hasPrefix("lot|") })
        // Three more targets, none of the three above.
        let others = keys.filter { ![respelledTarget, shownTarget, lot].contains($0) }
        try #require(others.count >= 3)
        let targets = [
            Self.stored(others[0], tier: Self.firstTier.id, note: "Box 4"),
            Self.stored(lot, included: false),
            Self.stored(others[1], tier: Self.secondTier.id),
            Self.stored(respelled, tier: Self.secondTier.id, note: "Re-spelled"),
            Self.stored(shownTarget, tier: Self.firstTier.id, created: "2026-11-02T00:00:00Z"),
            Self.stored(supersededKey, included: false, note: "Kept apart", created: "2026-11-01T12:00:00Z"),
            Self.stored("decimal|737.00/1-161", included: false, note: "An orphan"),
            // A tier no longer among the plan's, which reads as Unprioritized.
            Self.stored(others[2], tier: ImportFixtures.id(399)),
        ]
        let plan = Self.everyDocument(documents, targets: targets)
        let kit = try await Self.kit(plan, over: built)
        #expect(kit.overlay.storedKeys[respelledTarget] == respelled, "the re-spelled row answers for its target")
        #expect(kit.overlay.superseded[supersededKey]?.targetKey == shownTarget, "the row minted under the target's own key is shown")
        #expect(kit.overlay.orphanKeys == ["decimal|737.00/1-161"])

        let file = try ImportFixtures.file(Self.envelope([plan]))
        try await ServedFixture.run { client, _ in
            #expect(try await ImportServer.importing(file, with: client).state == .succeeded)
            let session = try await CollectionExportParityTests.Session.open(client)
            let answer = try ServedFixture.decode(VisitPlanDetail.self, try await session.get("/api/v1/me/visits/\(Self.planId.uuidString)"))
            // Every derived value is the kit's: the sections, their order and links, each row, the stored targets, the
            // tiers, the counts and the summary.
            #expect(answer == Self.expected(plan, kit, read: answer))
            #expect(Self.lines(answer) == Self.lines(kit), "each row, read from the kit's values")
            #expect(answer.sections.map(\.heading) == ArchiveVisitCounts.sectionHeadings(of: kit.model.targets))
            #expect(answer.summary == ArchiveVisitCounts.editorSummary(of: kit.model))
            #expect(answer.documentCount == documents.count && answer.indexedDocumentCount == kit.indexedDocumentCount)
            #expect(answer.storedTargets.map(\.key) == ["decimal|737.00/1-161", supersededKey])
            #expect(answer.storedTargets.last?.partOf == kit.model.targets.first { $0.key == shownTarget }?.label)
            #expect(answer.storedTargets.last?.excludedWhenOwn == true)
            #expect(answer.tiers.map(\.displayName) == ["First morning", "Priority 2"])
            #expect(answer.tiers.map(\.members) == [2, 2], "each tier's stored rows, the superseded among them")
            // The seeds' facts, through the same data source: which halves exist, as the builder reads them.
            let nothing = try #require(answer.documents.first { $0.key == documents[2].compositeString })
            #expect(!nothing.includeSource && !nothing.includeExternalRefs)
            #expect(answer.documents.allSatisfy { $0.hasSourceNote != nil && $0.referenceCount != nil && $0.header != nil })
            #expect(answer.documents.map(\.key) == documents.map(\.compositeString).sorted())
            #expect(answer.sparsity.map { $0.indexed > 0 && $0.withReferences <= $0.indexed } == true)

            // A tier written to the re-spelled target's row: the kit's rule over the overlay of the plan as it stands finds
            // the row through the overlay's stored keys and writes its tier alone, minting none.
            let written = ArchiveVisitPlanWrites.settingTier(Self.firstTier.id, forKey: respelledTarget, resolvedBy: kit.overlay,
                                                             among: plan.targets, planId: plan.id)
            guard case .stored(let row) = written else { Issue.record("the rule minted a row: \(written)"); return }
            #expect(row.record.targetKey == respelled)
            let after = try ServedFixture.decode(VisitPlanDetail.self, try await session.send(
                .patch, "/api/v1/me/visits/\(Self.planId.uuidString)/targets",
                try CollectionExportParityTests.json(["key": respelledTarget, "tierId": Self.firstTier.id.uuidString])))
            let rows = try await Self.exported(session).first { $0.id == Self.planId }
            #expect(rows?.targets.count == targets.count, "no row minted")
            #expect(rows?.targets.first { $0.targetKey == respelled }?.tierId == Self.firstTier.id)
            #expect(rows?.targets.first { $0.targetKey == respelled }?.userNote == "Re-spelled", "its other fields as they were")
            var replanned = plan
            replanned.targets = rows?.targets ?? []
            #expect(Self.lines(after) == Self.lines(try await Self.kit(replanned, over: built)), "the answer, the kit's over the rows written")
        }
    }

    /// The import fixture's Mac plan, "College Park": d3's source and d4's references, a lot's row with its tier and note,
    /// and `decimal|737.00/1-161`, a key none of the app's four forms writes, an orphan with its exclusion kept.
    @Test func anImportedMacPlanDerivesAsItsExportSays() async throws {
        let built = try await FixtureIndex.value()
        let envelope = ImportFixtures.everyType(formatVersion: ResearchDataEnvelope.currentFormatVersion)
        let plan = try #require(envelope.archiveVisits.first)
        let kit = try await Self.kit(plan, over: built)
        #expect(kit.overlay.orphanKeys.contains("decimal|737.00/1-161") && kit.overlay.excludedKeys.contains("decimal|737.00/1-161"))
        try await ServedFixture.run { client, _ in
            #expect(try await ImportServer.importing(try ImportFixtures.file(envelope), with: client).state == .succeeded)
            let session = try await CollectionExportParityTests.Session.open(client)
            let list = try ServedFixture.decode(VisitPlanList.self, try await session.get("/api/v1/me/visits"))
            let item = try #require(list.items.first { $0.id == plan.id.uuidString })
            #expect(item.displayName == "College Park" && item.documentCount == 2 && item.indexedDocumentCount == 2)
            #expect(item.summary == ArchiveVisitCounts.listSummary(of: kit.model))
            let answer = try ServedFixture.decode(VisitPlanDetail.self, try await session.get("/api/v1/me/visits/\(plan.id.uuidString)"))
            #expect(answer == Self.expected(plan, kit, read: answer))
            #expect(Self.lines(answer) == Self.lines(kit))
            let orphan = try #require(answer.storedTargets.first)
            #expect(orphan.key == "decimal|737.00/1-161" && orphan.kind == "orphan" && orphan.label == "737.00/1-161")
            #expect(answer.inquiryText == "The Zapata files" && answer.tiers.map(\.displayName) == ["First morning", "Priority 2"])
            #expect(answer.project == nil || answer.project?.id == ImportFixtures.id(40).uuidString)
        }
    }

    /// The user's plans as the export reads them.
    static func exported(_ session: CollectionExportParityTests.Session) async throws -> [ArchiveVisitPlanExport] {
        let response = try await session.get("/api/v1/me/export")
        return try ResearchDataEnvelope.makeDecoder().decode(ResearchDataEnvelope.self, from: Data(buffer: response.body)).archiveVisits
    }
}
