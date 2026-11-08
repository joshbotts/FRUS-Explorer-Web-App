// The editors' annotations (FRUS-Explorer#1859 to #1862): a volume page's Editors’ Annotations and the
// Browse axis of that name, as the server builds them over the kit's `VolumeAnnotationsIndex`. The
// app's own tests of the code the server mirrors, `VolumeAnnotationsPresentationTests` and
// `AnnotationsAxisTests`, are run here on the same fixtures with the same expectations, less their
// words, which are the browser app's and are held by AnnotationsParityTests; then the shipped file,
// and the routes.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct AnnotationTests {
    /// A volume of `documents` documents carrying `counts`, as the app's tests make one.
    static func volume(_ era: AnnotationEra, documents: Int, persons: Int = 0, terms: Int = 0,
                       _ counts: [AnnotationCategory: Int] = [:], sections: [String] = []) -> VolumeAnnotations {
        VolumeAnnotations(documents: documents, historicalDocuments: documents - (counts[.editorialNotes] ?? 0),
                          personsListed: persons, termsListed: terms, era: era, counts: counts, sections: sections)
    }

    static func index(_ volumes: [String: VolumeAnnotations]) -> VolumeAnnotationsIndex {
        VolumeAnnotationsIndex(generated: "2026-11-06", corpusCommit: "fixture", indexVersion: 73, volumes: volumes)
    }

    typealias Part = VolumeAnnotationsSection.Part
    typealias Accessory = AnnotationDrill.Accessory

    static func part(_ kind: String, _ count: Int, of: Int? = nil) -> Part { Part(kind: kind, count: count, of: of) }

    /// Each row's parts, by its layer.
    static func parts(_ section: VolumeAnnotationsSection) -> [String: [Part]] {
        Dictionary(uniqueKeysWithValues: section.groups.flatMap(\.rows).map { ($0.layer, $0.parts) })
    }

    /// The China volume's own counts (`frus1969-76v17`), with a despatch number and a marginal note
    /// added so every row shows, as `VolumeAnnotationsPresentationTests` has them.
    static let full = volume(.from1969, documents: 280, persons: 325, terms: 470, [
        .people: 279, .abbreviations: 278, .correspondents: 161, .subjects: 137, .participants: 67,
        .sourceCitation: 263, .sourceFileNumber: 5, .classification: 260, .excisions: 37, .despatch: 30,
        .numbered: 280, .xrefDocuments: 131, .xrefFootnotes: 65, .xrefVolumes: 89,
        .editorialNotes: 12, .footnotes: 243, .marginalNotes: 1,
    ], sections: ["back", "errata", "front", "index", "note-on-covert-actions", "persons", "preface",
                  "sources", "table-of-contents", "terms"])

    // MARK: A volume's page

    @Test func eachRowSaysItsCountsInThreeGroupsInThePagesOrder() {
        let section = VolumeAnnotationsSection(volumeId: "v", annotations: Self.full, index: Self.index(["v": Self.full]))
        #expect(section.groups.map(\.family) == ["named", "provenance", "connects"])
        #expect(section.groups.flatMap { $0.rows.map(\.layer) } == AnnotationLayer.allCases.map(\.rawValue))
        for group in section.groups {
            for row in group.rows { #expect(AnnotationLayer(rawValue: row.layer)?.family.rawValue == group.family) }
        }
        let parts = Self.parts(section)
        #expect(parts["people"] == [Self.part("ofDocuments", 279, of: 280), Self.part("personsListed", 325)])
        #expect(parts["abbreviations"] == [Self.part("ofDocuments", 278, of: 280), Self.part("termsListed", 470)])
        #expect(parts["correspondents"] == [Self.part("documents", 161)])
        #expect(parts["sourceNotes"] == [Self.part("ofDocuments", 268, of: 280), Part(kind: "sourceForm", form: "both")])
        #expect(parts["classification"] == [Self.part("ofDocuments", 260, of: 280)])
        #expect(parts["excisions"] == [Self.part("excisions", 37)])
        #expect(parts["despatch"] == [Self.part("documents", 30)])
        #expect(parts["numbered"] == [Self.part("ofDocuments", 280, of: 280)])
        // Footnotes are not cross-references the line counts.
        #expect(parts["crossReferences"] == [Self.part("xrefDocuments", 131), Self.part("xrefVolumes", 89)])
        #expect(parts["editorialNotes"] == [Self.part("editorialNotes", 12)])
        #expect(parts["marginalNotes"] == [Self.part("documents", 1)])
        // The aids a reader knows by name, in the page's order: not the containers or the contents.
        #expect(parts["printedAids"] == ["preface", "sources", "terms", "persons", "note-on-covert-actions", "index", "errata"]
            .map { Part(kind: "aid", aid: $0) })
        #expect(section.absent.isEmpty)
    }

    @Test func aLayerIsInTheVolumeOrNotUnderHalfAPervasiveLayerIsAbsent() {
        let partial = Self.volume(.from1955, documents: 10, [.people: 4, .sourceCitation: 6, .editorialNotes: 1])
        let section = VolumeAnnotationsSection(volumeId: "v", annotations: partial, index: Self.index(["v": partial]))
        let parts = Self.parts(section)
        #expect(parts["people"] == nil && parts["sourceNotes"] != nil && parts["editorialNotes"] != nil)
        #expect(section.absent.map(\.id).contains("people"))
        // One editorial note is a counted layer.
        #expect(parts["editorialNotes"] == [Self.part("editorialNotes", 1)])
        // The one form present names itself.
        #expect(parts["sourceNotes"] == [Self.part("ofDocuments", 6, of: 10), Part(kind: "sourceForm", form: "citations")])
    }

    @Test func aStandardLayerTheVolumeLacksNamesTheEraFromWhichTheSeriesMadeItStandard() throws {
        var volumes: [String: VolumeAnnotations] = [:]
        let tagged = Self.volume(.from1955, documents: 2, [.people: 2])
        for n in 0..<2 {
            volumes["a\(n)"] = Self.volume(.from1861, documents: 2)
            volumes["b\(n)"] = Self.volume(.from1945, documents: 2)
            volumes["d\(n)"] = tagged
            volumes["e\(n)"] = Self.volume(.from1969, documents: 2, [.people: 2])
        }
        volumes["c0"] = tagged
        volumes["c1"] = Self.volume(.from1951, documents: 2)
        let early = try #require(volumes["a0"])
        let section = VolumeAnnotationsSection(volumeId: "a0", annotations: early, index: Self.index(volumes))
        #expect(section.groups.isEmpty)
        #expect(section.absent.map(\.id) == ["people", "abbreviations", "sourceNotes", "classification", "numbered",
                                             "referencesToDocuments", "editorialNotes", "noteOnSources"])
        #expect(section.absent.first?.onset == AnnotationEraName(.from1955))
        #expect(section.absent.first?.onset?.firstYear == 1955)
        // A practice no era made standard here gives no onset.
        #expect(section.absent.first { $0.id == "classification" }?.onset == nil)
    }

    @Test func anAbsentRowOpensTheLayerThatHoldsIt() {
        let bare = Self.volume(.from1861, documents: 2)
        let section = VolumeAnnotationsSection(volumeId: "a", annotations: bare, index: Self.index(["a": bare]))
        let opened = Dictionary(uniqueKeysWithValues: section.absent.map { ($0.id, $0.layer) })
        #expect(opened == [
            "people": "people", "abbreviations": "abbreviations", "sourceNotes": "sourceNotes",
            "classification": "classification", "numbered": "numbered",
            "referencesToDocuments": "crossReferences", "editorialNotes": "editorialNotes",
            "noteOnSources": "printedAids",
        ])
    }

    // MARK: The axis

    @Test func aLayersReachItsVolumesInIdOrderAndEachErasShareTheRetrospectivesLast() {
        let tagged = Self.volume(.from1955, documents: 2, [.people: 2])
        let untagged = Self.volume(.from1955, documents: 2)
        let early = Self.volume(.from1861, documents: 4, [.people: 1])
        let retro = Self.volume(.retrospective, documents: 2, [.people: 2])
        let reach = AnnotationsAxis.reach(of: .people, in: Self.index([
            "frus1955-57v10": tagged, "frus1955-57v2": tagged, "frus1958-60v01": untagged,
            "frus1861": early, "frus1917-72PubDipv06": retro,
        ]))
        // Numbers compare as numbers: v2 before v10.
        #expect(reach.carrying == ["frus1917-72PubDipv06", "frus1955-57v2", "frus1955-57v10"])
        #expect(reach.total == 5)
        #expect(reach.bands.map(\.era) == AnnotationEra.chronological + [.retrospective])
        let band1955 = reach.bands.first { $0.era == .from1955 }
        #expect(band1955?.carrying == 2 && band1955?.total == 3)
        // One document in four is under half: not carried.
        #expect(reach.bands.first { $0.era == .from1861 }?.carrying == 0)
        #expect(reach.bands.last?.share == 1)
    }

    @Test func whenALayerBecameStandardOrWhereAPracticeNoEraMadeStandardIsMostCommon() {
        let volumes = Self.index([
            "a": Self.volume(.from1861, documents: 2, [.despatch: 2]),
            "b": Self.volume(.from1861, documents: 2, [.despatch: 2]),
            "c": Self.volume(.from1955, documents: 2, [.people: 2]),
            "d": Self.volume(.from1969, documents: 2, [.people: 2]),
            "e": Self.volume(.retrospective, documents: 2, [.marginalNotes: 1]),
        ])
        let people = AnnotationReach(AnnotationsAxis.reach(of: .people, in: volumes))
        #expect(people.onset == AnnotationEraName(.from1955) && people.peak == nil)
        #expect(people.carrying == 2 && people.total == 5)
        let despatch = AnnotationReach(AnnotationsAxis.reach(of: .despatch, in: volumes))
        #expect(despatch.onset == nil && despatch.peak == AnnotationEraName(.from1861))
        let marginal = AnnotationReach(AnnotationsAxis.reach(of: .marginalNotes, in: volumes))
        #expect(marginal.peak == AnnotationEraName(.retrospective))
        // A layer no volume carries says nothing of when.
        let subjects = AnnotationReach(AnnotationsAxis.reach(of: .subjects, in: volumes))
        #expect(subjects.onset == nil && subjects.peak == nil)
    }

    @Test func aPracticeNoEraMadeStandardIsMostCommonWhereItsShareIsLargestTiesToTheEarlier() {
        // Three of four volumes covering 1861–1898 print despatch numbers, and both covering 1899–1913:
        // the share decides, not the count. A later band without them leaves the practice no onset.
        var volumes: [String: VolumeAnnotations] = ["c": Self.volume(.from1914, documents: 2)]
        for n in 0..<4 { volumes["a\(n)"] = Self.volume(.from1861, documents: 2, n < 3 ? [.despatch: 2] : [:]) }
        for n in 0..<2 { volumes["b\(n)"] = Self.volume(.from1899, documents: 2, [.despatch: 2]) }
        let reach = AnnotationsAxis.reach(of: .despatch, in: Self.index(volumes))
        #expect(reach.onset == nil)
        #expect(AnnotationsAxis.peak(of: reach) == .from1899)
        // Two bands at one share: the earlier, the strip's order.
        let tied = AnnotationsAxis.reach(of: .despatch, in: Self.index([
            "a0": Self.volume(.from1861, documents: 2, [.despatch: 2]), "a1": Self.volume(.from1861, documents: 2),
            "b0": Self.volume(.from1899, documents: 2, [.despatch: 2]), "b1": Self.volume(.from1899, documents: 2),
        ]))
        #expect(tied.onset == nil && AnnotationsAxis.peak(of: tied) == .from1861)
    }

    @Test func anErasNameIsASpanAnOpenEndOrTheRetrospectives() {
        #expect(AnnotationEraName(.from1861) == AnnotationEraName(id: "1861-1898", firstYear: 1861, lastYear: 1898))
        #expect(AnnotationEraName(.from1981) == AnnotationEraName(id: "1981-", firstYear: 1981, lastYear: nil))
        #expect(AnnotationEraName(.retrospective) == AnnotationEraName(id: "retrospective", firstYear: nil, lastYear: nil))
        #expect(AnnotationsAxis.stripEras.count == 11)
    }

    // MARK: Drills

    @Test func aDrillListsItsVolumesWithEachOnesCountAndItsMarks() throws {
        let china = Self.volume(.from1969, documents: 280, persons: 325, [.people: 279])
        let unlinked = Self.volume(.from1969, documents: 100, persons: 153)
        let partial = Self.volume(.from1969, documents: 10, [.people: 3])
        let volumes = Self.index(["frus1969-76v17": china, "frus1977-80v27": unlinked, "frus1969-76v05": partial])
        let drills = AnnotationsAxis.drills(for: .people, in: volumes)
        #expect(drills.map(\.id) == ["with", "without"])
        #expect(drills.map(\.volumeIds.count) == [1, 2])
        func list(_ drill: AnnotationsAxis.Drill, from: String? = nil) -> AnnotationDrill {
            AnnotationDrill(layer: .people, drill: drill.id, rule: drill.rule, volumeIds: drill.volumeIds, total: 3,
                            index: volumes, from: from, accessoryCategory: drill.accessoryCategory)
        }
        let with = list(try #require(drills.first))
        let without = list(try #require(drills.last))
        #expect(with.volumes.map(\.volumeId) == ["frus1969-76v17"] && with.count == 1 && with.total == 3 && with.rule == "layer")
        #expect(without.volumes.map(\.volumeId) == ["frus1969-76v05", "frus1977-80v27"])
        #expect(with.volumes.first?.accessory == Accessory(kind: "ratio", count: 279, of: 280))
        // Under half shows its count; none shows nothing.
        #expect(without.volumes.first?.accessory == Accessory(kind: "ratio", count: 3, of: 10))
        #expect(without.volumes.last?.accessory == nil)
        #expect(without.volumes.map(\.unlinked) == [nil, "persons"])
        #expect(with.volumes.allSatisfy { $0.unlinked == nil && $0.from == nil })

        // Opened from a volume's page, the volume comes first, and says so after any other mark.
        let marked = list(try #require(drills.last), from: "frus1977-80v27")
        #expect(marked.volumes.map(\.volumeId) == ["frus1977-80v27", "frus1969-76v05"])
        #expect(marked.volumes.first?.unlinked == "persons" && marked.volumes.first?.from == true)
        #expect(marked.volumes.last?.from == nil)
        // A volume the list does not hold marks nothing.
        #expect(list(try #require(drills.first), from: "frus1977-80v27").volumes.map(\.volumeId) == ["frus1969-76v17"])
    }

    @Test func aLayerFoundHereAndThereCountsDocumentsEditorialNotesCountNotesReferencesNone() {
        let annotated = Self.volume(.from1969, documents: 280, [.editorialNotes: 12, .excisions: 37, .xrefDocuments: 9])
        #expect(AnnotationsAxis.accessory(for: .editorialNotes, annotated) == Accessory(kind: "notes", count: 12))
        #expect(AnnotationsAxis.accessory(for: .excisions, annotated) == Accessory(kind: "docs", count: 37))
        #expect(AnnotationsAxis.accessory(for: .crossReferences, annotated) == nil)
        let one = Self.volume(.from1969, documents: 2, [.editorialNotes: 1])
        #expect(AnnotationsAxis.accessory(for: .editorialNotes, one) == Accessory(kind: "notes", count: 1))
    }

    @Test func sourceNotesAddOneDrillPerFormThePrintedAidsHaveOnePerAid() throws {
        let volumes = Self.index([
            "c": Self.volume(.from1969, documents: 2, [.sourceCitation: 2], sections: ["persons", "index"]),
            "f": Self.volume(.from1914, documents: 2, [.sourceFileNumber: 2], sections: ["index", "intro"]),
            "b": Self.volume(.from1951, documents: 4, [.sourceCitation: 2, .sourceFileNumber: 2], sections: ["introduction"]),
        ])
        let source = AnnotationsAxis.drills(for: .sourceNotes, in: volumes)
        #expect(source.map(\.id) == ["with", "without", "citation", "fileNumber"])
        #expect(source[2].volumeIds == ["b", "c"] && source[2].rule == .sourceForm)
        #expect(source[3].volumeIds == ["b", "f"])
        let citations = AnnotationDrill(layer: .sourceNotes, drill: source[2].id, rule: source[2].rule,
                                        volumeIds: source[2].volumeIds, total: 3, index: volumes, from: nil,
                                        accessoryCategory: source[2].accessoryCategory)
        #expect(citations.volumes.first?.accessory == Accessory(kind: "ratio", count: 2, of: 4))

        let aids = AnnotationsAxis.drills(for: .printedAids, in: volumes)
        #expect(aids.map(\.id) == ["intro", "persons", "index"])
        // "intro" and "introduction" are one aid.
        let introduction = try #require(aids.first)
        #expect(introduction.volumeIds == ["b", "f"] && introduction.rule == .aid)
    }

    @Test func aCellOfTheMatrixOpensItsErasVolumesThatCarryTheLayer() {
        let volumes = Self.index([
            "frus1955-57v02": Self.volume(.from1955, documents: 2, [.people: 2]),
            "frus1955-57v10": Self.volume(.from1955, documents: 2, [.people: 2]),
            "frus1958-60v01": Self.volume(.from1955, documents: 2),
            "frus1969-76v17": Self.volume(.from1969, documents: 2, [.people: 2]),
            "frus1917-72PubDipv06": Self.volume(.retrospective, documents: 2, [.people: 2]),
        ])
        let cell = AnnotationsAxis.eraDrill(for: .people, era: .from1955, in: volumes)
        #expect(cell.volumeIds == ["frus1955-57v02", "frus1955-57v10"])
        #expect(cell.band == AnnotationsAxis.Band(era: .from1955, carrying: 2, total: 3))
        let retro = AnnotationsAxis.eraDrill(for: .people, era: .retrospective, in: volumes)
        #expect(retro.band.carrying == 1 && retro.band.total == 1)
        // An era none of whose volumes carries it opens nothing to list.
        #expect(AnnotationsAxis.eraDrill(for: .people, era: .from1861, in: volumes).volumeIds.isEmpty)
    }

    // MARK: The shipped file

    /// The bundled file the image carries, as the app's tests read it through `VolumeAnnotationsStore`.
    static func shipped() throws -> VolumeAnnotationsData {
        try #require(try TestResources.value().volumeAnnotations, "volume-annotations-index.json decodes from the app's data files")
    }

    @Test func theShippedFileTagsPeopleIn288Of553VolumesFrom1955On() throws {
        let data = try Self.shipped()
        let index = data.index
        let people = data.reach(of: .people)
        #expect(people.carrying.count == 288 && people.total == 553)
        #expect(people.onset == .from1955)
        let band1955 = try #require(people.bands.first { $0.era == .from1955 })
        #expect(band1955.carrying == 114 && band1955.total == 114)
        #expect(AnnotationsAxis.eraDrill(for: .people, era: .from1955, in: index).volumeIds.count == 114)
        // In id order, the volume the app's UI suite opens is the 126th: why a drill puts its own first.
        #expect(people.carrying.firstIndex(of: "frus1961-63v06") == 125)
        // The cached reach is the one the app's rule gives.
        #expect(people == AnnotationsAxis.reach(of: .people, in: index))

        let without = try #require(AnnotationsAxis.drills(for: .people, in: index).first { $0.id == "without" })
        #expect(without.volumeIds.count == 265)
        let unlinkedPersons = AnnotationDrill(layer: .people, drill: "without", rule: .layer, volumeIds: without.volumeIds,
                                              total: 553, index: index, from: nil)
        // `frus1941-43`'s Index of Persons is an index since index version 74, and lists no one.
        #expect(unlinkedPersons.volumes.filter { $0.unlinked != nil }.map(\.volumeId) == ["frus1977-80v27"])
        let conferences = try #require(index["frus1941-43"])
        #expect(conferences.personsListed == 0)
        #expect(conferences.prints(section: "index") && !conferences.prints(section: "persons"))

        // `frus1981-88v16` names its terms on each document's `@ana`, and carries the layer.
        let abbreviations = data.reach(of: .abbreviations)
        #expect(abbreviations.carrying.count == 310 && abbreviations.carrying.contains("frus1981-88v16"))
        #expect(index["frus1981-88v16"]?.count(.abbreviations) == 88)
        let unlinkedTerms = try #require(AnnotationsAxis.drills(for: .abbreviations, in: index).first { $0.id == "without" })
        let terms = AnnotationDrill(layer: .abbreviations, drill: "without", rule: .layer, volumeIds: unlinkedTerms.volumeIds,
                                    total: 553, index: index, from: nil)
        #expect(terms.volumes.filter { $0.unlinked != nil }.map { "\($0.volumeId) \($0.unlinked ?? "")" } == ["frus1977-80v27 terms"])

        // Every layer has volumes to show.
        for layer in AnnotationLayer.allCases {
            #expect(!data.reach(of: layer).carrying.isEmpty, "\(layer) has no volume")
        }
    }

    @Test func theShippedFileGivesChinaTheDesignsRowsAnd1890TheEightItLacks() throws {
        let index = try Self.shipped().index
        func section(_ volumeId: String) throws -> VolumeAnnotationsSection {
            VolumeAnnotationsSection(volumeId: volumeId, annotations: try #require(index[volumeId]), index: index)
        }
        let china = try section("frus1969-76v17")
        #expect(Self.parts(china)["people"] == [Self.part("ofDocuments", 279, of: 280), Self.part("personsListed", 325)])
        #expect(Self.parts(china)["classification"] == [Self.part("ofDocuments", 260, of: 280)])
        #expect(china.absent.isEmpty)

        let papers1890 = try section("frus1890")
        #expect(papers1890.absent.count == 8)
        #expect(papers1890.absent.first?.id == "people" && papers1890.absent.first?.onset?.firstYear == 1955)
        #expect(Self.parts(papers1890)["despatch"] == [Self.part("documents", 347)])
        #expect(Self.parts(papers1890)["printedAids"] == ["list-of-papers", "index"].map { Part(kind: "aid", aid: $0) })

        // One of the three fixture volumes, which the browser suite opens: every standard layer.
        let kennedy = try section("frus1961-63v06")
        #expect(kennedy.absent.isEmpty)
        #expect(Self.parts(kennedy)["people"] == [Self.part("ofDocuments", 120, of: 120), Self.part("personsListed", 58)])

        // 1981–88 vol. XVI names its terms on each document's `@ana`, so its page explains them.
        let southAmerica = try section("frus1981-88v16")
        #expect(Self.parts(southAmerica)["abbreviations"] == [Self.part("ofDocuments", 88, of: 88), Self.part("termsListed", 108)])
        #expect(!southAmerica.absent.contains { $0.id == "abbreviations" })

        // The Washington and Casablanca conferences print an Index of Persons, which is an index.
        let conferences = try section("frus1941-43")
        #expect(Self.parts(conferences)["printedAids"] == ["preface", "terms", "list-of-papers", "index"].map { Part(kind: "aid", aid: $0) })
        #expect(Self.parts(conferences)["people"] == nil)
    }

    // MARK: Routes

    @Test func aVolumesPageAnswersForAnyCatalogueVolumeTheFileHolds() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            // No index is served: the section comes from the bundled file, before any download.
            let response = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/annotations", method: .get)
            #expect(response.status == .ok)
            let section = try decode(VolumeAnnotationsSection.self, response)
            #expect(section.volumeId == "frus1961-63v06" && section.absent.isEmpty)
            #expect(section.groups.first?.rows.first == VolumeAnnotationsSection.Row(
                layer: "people", parts: [Self.part("ofDocuments", 120, of: 120), Self.part("personsListed", 58)]))
            // An absent part is left out of the JSON, not written as null.
            #expect(!String(buffer: response.body).contains("null"))

            let early = try decode(VolumeAnnotationsSection.self,
                                   try await client.execute(uri: "/api/v1/volumes/frus1890/annotations", method: .get))
            #expect(early.absent.first?.onset == AnnotationEraName(.from1955))

            let unknown = try await client.execute(uri: "/api/v1/volumes/frus-no-such-volume/annotations", method: .get)
            #expect(try problem(unknown, .notFound).code == "VOLUME_NOT_FOUND")
            let refused = try await client.execute(uri: "/api/v1/volumes/frus1890/annotations?layer=people", method: .get)
            #expect(try problem(refused, .badRequest).code == "UNKNOWN_PARAMETER")
        }
    }

    @Test func theAxisAnswersEveryLayerInItsGroupWithItsEras() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/annotations", method: .get)
            #expect(response.status == .ok)
            let axis = try decode(AnnotationsAxisPage.self, response)
            #expect(axis.total == 553)
            #expect(axis.eras.map(\.id) == AnnotationsAxis.stripEras.map(\.rawValue))
            #expect(axis.groups.map(\.family) == ["named", "provenance", "connects"])
            #expect(axis.groups.flatMap { $0.layers.map(\.layer) } == AnnotationLayer.allCases.map(\.rawValue))
            let people = try #require(axis.groups.first?.layers.first)
            #expect(people.carrying == 288 && people.total == 553 && people.onset?.firstYear == 1955 && people.peak == nil)
            #expect(people.bands.first { $0.era == "1955-1968" } == AnnotationReach.Band(era: "1955-1968", carrying: 114, total: 114))
            // Despatch numbers became standard in no era: the page names the era where they are most
            // common, by share, 18 of the 20 volumes covering 1899–1913, where 55 of 62 covering
            // 1861–1898 is the larger count.
            let despatch = try #require(axis.groups.flatMap(\.layers).first { $0.layer == "despatch" })
            #expect(despatch.onset == nil && despatch.peak == AnnotationEraName(.from1899))
            #expect(despatch.bands.prefix(2).map { "\($0.carrying)/\($0.total)" } == ["55/62", "18/20"])
        }
    }

    @Test func aLayersPageAnswersItsDrillsAndEachDrillItsVolumes() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let people = try decode(AnnotationLayerPage.self, try await client.execute(uri: "/api/v1/annotations/people", method: .get))
            #expect(people.reach.carrying == 288 && people.eras.count == 11)
            #expect(people.drills == [AnnotationLayerPage.Drill(id: "with", count: 288), AnnotationLayerPage.Drill(id: "without", count: 265)])
            let sources = try decode(AnnotationLayerPage.self, try await client.execute(uri: "/api/v1/annotations/sourceNotes", method: .get))
            #expect(sources.drills.map(\.id) == ["with", "without", "citation", "fileNumber"])
            let aids = try decode(AnnotationLayerPage.self, try await client.execute(uri: "/api/v1/annotations/printedAids", method: .get))
            #expect(aids.drills.map(\.id).prefix(1) == ["preface"] && aids.drills.allSatisfy { $0.count > 0 })

            // Opened from `frus1977-80v27`'s page, Without lists it first, with its amber mark.
            let without = try decode(AnnotationDrill.self, try await client.execute(
                uri: "/api/v1/annotations/people/drills/without?from=frus1977-80v27", method: .get))
            #expect(without.count == 265 && without.total == 553 && without.rule == "layer" && without.era == nil)
            #expect(without.volumes.first == AnnotationDrill.Volume(volumeId: "frus1977-80v27", accessory: nil, unlinked: "persons", from: true))
            let with = try decode(AnnotationDrill.self, try await client.execute(
                uri: "/api/v1/annotations/people/drills/with?from=frus1961-63v06", method: .get))
            #expect(with.volumes.first == AnnotationDrill.Volume(volumeId: "frus1961-63v06", accessory: Accessory(kind: "ratio", count: 120, of: 120),
                                                                unlinked: nil, from: true))
            #expect(with.volumes.dropFirst().allSatisfy { $0.from == nil })

            let cell = try decode(AnnotationDrill.self, try await client.execute(uri: "/api/v1/annotations/people/eras/1955-1968", method: .get))
            #expect(cell.drill == "era" && cell.era == AnnotationEraName(.from1955) && cell.count == 114 && cell.total == 114)
            let empty = try decode(AnnotationDrill.self, try await client.execute(uri: "/api/v1/annotations/people/eras/1899-1913", method: .get))
            #expect(empty.count == 0 && empty.volumes.isEmpty && empty.total > 0)
        }
    }

    @Test func aLayerADrillOrAnEraNoneOfTheAxisNamesIsNotFound() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for (uri, code) in [
                ("/api/v1/annotations/tags", "ANNOTATION_LAYER_NOT_FOUND"),
                ("/api/v1/annotations/tags/drills/with", "ANNOTATION_LAYER_NOT_FOUND"),
                ("/api/v1/annotations/people/drills/citation", "ANNOTATION_DRILL_NOT_FOUND"),
                // The printed aids have a drill per aid, and no With or Without.
                ("/api/v1/annotations/printedAids/drills/with", "ANNOTATION_DRILL_NOT_FOUND"),
                ("/api/v1/annotations/people/eras/1999-2010", "ANNOTATION_ERA_NOT_FOUND"),
            ] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .notFound).code == code, "\(uri)")
            }
            let refused = try await client.execute(uri: "/api/v1/annotations/people/eras/1955-1968?from=frus1890", method: .get)
            #expect(try problem(refused, .badRequest).code == "UNKNOWN_PARAMETER")
        }
    }

    /// A file missing, one that will not decode, and one that holds no volume, which the app's axis
    /// shows as unavailable too.
    @Test(arguments: [nil, "{}", #"{"corpusCommit":"x","fields":["documents"],"generated":"2026-11-06","indexVersion":74,"schemaVersion":1,"sections":[],"volumes":{}}"#])
    func aServerWithoutTheFileSaysSoOnEveryRoute(file: String?) async throws {
        let directory = try TemporaryDirectory()
        for name in ServerResources.requiredFiles {
            try FileManager.default.copyItem(at: RepositoryFiles.resources.appendingPathComponent(name),
                                             to: directory.url.appendingPathComponent(name))
        }
        if let file { try Data(file.utf8).write(to: directory.url.appendingPathComponent(VolumeAnnotationsFile.name)) }
        let resources = try ServerResources.load(from: directory.url)
        #expect(resources.volumeAnnotations == nil)
        let fixture = try await ServerFixture()
        let router = buildRouter(state: fixture.state, resources: resources, reader: fixture.reader)
        try await Application(router: router).test(.router) { client in
            for uri in ["/api/v1/annotations", "/api/v1/annotations/people", "/api/v1/annotations/people/drills/with",
                        "/api/v1/annotations/people/eras/1955-1968", "/api/v1/volumes/frus1890/annotations"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .serviceUnavailable).code == "ANNOTATIONS_UNAVAILABLE", "\(uri)")
            }
        }
    }
}
