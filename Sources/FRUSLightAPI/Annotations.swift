// The editors' annotations (FRUS-Explorer#1859 to #1862): what each volume's editors annotated, read
// from the bundled volume-annotations-index.json by the kit's `VolumeAnnotationsIndex`. GET
// /api/v1/volumes/{v}/annotations is a volume page's Editors’ Annotations, and /api/v1/annotations the
// Browse axis of that name: its layers, a layer's page (/annotations/{layer}), and the volumes a page's
// drill (/annotations/{layer}/drills/{drill}) or a cell of its matrix (/annotations/{layer}/eras/{era})
// lists. When a volume carries a category, the era it belongs to and the era from which the series made
// a practice standard are the kit's (`VolumeAnnotations.carries(_:)`, `carriesSourceNotes`,
// `AnnotationEra`, `VolumeAnnotationsIndex.onset(where:)`). The table of fifteen layers and the rows,
// reaches and drills built over it are the app's view code, Foundation-only and small
// (`AnnotationLayer` and `AnnotationsAxis` in FRUSExplorer/Browser/AnnotationsAxis.swift,
// `VolumeAnnotationsPresentation` beside it), mirrored here and held to the app's lines by
// AnnotationsParityTests. Every word is the browser app's, in copy.ts: the server answers with the
// counts and the parts the app's words are made of.

import FRUSCoreKit
import Foundation
import Hummingbird

// MARK: - AnnotationLayer

/// One layer of a volume's editorial annotation, as the app shows it: a row of a volume page's
/// Editors’ Annotations and a category of the Browse axis of that name, fifteen in the page's order.
/// The app's `AnnotationLayer`: one of the kit's `AnnotationCategory` counts, or several taken
/// together, the two source-note forms, the three kinds of reference, and the printed aids, which are
/// sections, not counts.
enum AnnotationLayer: String, CaseIterable, Sendable {
    /// Names linked to the volume's List of Persons.
    case people
    /// Abbreviations linked to the volume's List of Abbreviations.
    case abbreviations
    /// The sender or the recipient marked in a document's heading.
    case correspondents
    /// A memorandum's Subject line.
    case subjects
    /// A meeting's participants, listed.
    case participants
    /// Source notes, of either form.
    case sourceNotes
    /// Classification markings.
    case classification
    /// Text marked as not declassified.
    case excisions
    /// The posts' despatch numbers.
    case despatch
    /// Documents numbered in print.
    case numbered
    /// References to the volume's documents, to other volumes and to printed pages.
    case crossReferences
    /// Editorial notes.
    case editorialNotes
    /// Footnotes.
    case footnotes
    /// Marginal notes.
    case marginalNotes
    /// The printed aids: a preface, the lists, an index.
    case printedAids

    /// The group the layer is shown in.
    var family: AnnotationCategory.Family {
        switch self {
        case .people, .abbreviations, .correspondents, .subjects, .participants:
            return .named
        case .sourceNotes, .classification, .excisions, .despatch:
            return .provenance
        case .numbered, .crossReferences, .editorialNotes, .footnotes, .marginalNotes, .printedAids:
            return .connects
        }
    }

    /// The kit category whose count the layer is, or `nil` for a layer made of several (source
    /// notes, references) or of sections (printed aids).
    var category: AnnotationCategory? {
        switch self {
        case .people: return .people
        case .abbreviations: return .abbreviations
        case .correspondents: return .correspondents
        case .subjects: return .subjects
        case .participants: return .participants
        case .classification: return .classification
        case .excisions: return .excisions
        case .despatch: return .despatch
        case .numbered: return .numbered
        case .editorialNotes: return .editorialNotes
        case .footnotes: return .footnotes
        case .marginalNotes: return .marginalNotes
        case .sourceNotes, .crossReferences, .printedAids: return nil
        }
    }

    /// `true` when `annotations` carries the layer: a category by the kit's threshold; source notes
    /// when half the documents have one of either form; references when any of the three kinds is
    /// there; the printed aids when the volume prints one the page names.
    func isCarried(by annotations: VolumeAnnotations) -> Bool {
        switch self {
        case .sourceNotes:
            return annotations.carriesSourceNotes
        case .crossReferences:
            return annotations.carries(.xrefDocuments) || annotations.carries(.xrefVolumes)
                || annotations.carries(.xrefPages)
        case .printedAids:
            return !PrintedAid.printed(in: annotations.sections).isEmpty
        default:
            return category.map(annotations.carries) ?? false
        }
    }

    /// The count a drill's row shows for the layer, or `nil` where no one count says it.
    func count(in annotations: VolumeAnnotations) -> Int? {
        switch self {
        case .sourceNotes: return annotations.sourceNotes
        case .crossReferences, .printedAids: return nil
        default: return category.map(annotations.count)
        }
    }
}

// MARK: - PrintedAid

/// The printed aids a volume's page names, in its order: the app's
/// `VolumeAnnotationsPresentation.printedAidNames`, each a section kind as the parser names it. Two
/// kinds are one aid, "intro" and "introduction", which the app names alike, and an aid is known by its
/// first kind, as the axis's drills know it (`AnnotationsAxis.aidDrills`); its name is copy.ts's. A
/// section kind not listed here (the front and back containers, the table of contents, a chapter) is
/// not an aid the page names.
enum PrintedAid {
    /// Each aid, by its first kind, with its kinds, in the order the page names them.
    static let all: [(id: String, kinds: [String])] = [
        ("preface", ["preface"]),
        ("foreword", ["foreword"]),
        ("intro", ["intro", "introduction"]),
        ("sources", ["sources"]),
        ("terms", ["terms"]),
        ("persons", ["persons"]),
        ("list-of-papers", ["list-of-papers"]),
        ("note-on-covert-actions", ["note-on-covert-actions"]),
        ("press-release", ["press-release"]),
        ("volume-summary", ["volume-summary"]),
        ("index", ["index"]),
        ("errata", ["errata"]),
    ]

    /// The aids among `sections`, each by its id once, in the order the page names them, as the app's
    /// `printedAids(in:)` names them.
    static func printed(in sections: [String]) -> [String] {
        all.filter { aid in aid.kinds.contains { sections.contains($0) } }.map(\.id)
    }
}

// MARK: - Eras

/// An era as the browser app names it: the kit's `AnnotationEra` by its raw value, with its first year
/// and its last, read from the raw value as the app's `AnnotationsAxis.eraName(_:)` reads it, for
/// "1955–1968", "1981 on" and the late retrospectives.
public struct AnnotationEraName: Codable, Equatable, Sendable {
    /// The kit's raw value: "1955-1968", "1981-" or "retrospective".
    public var id: String
    /// The band's first year; absent for the late retrospectives.
    public var firstYear: Int?
    /// Its last year; absent for the band with an open end, and for the late retrospectives.
    public var lastYear: Int?
}

extension AnnotationEraName {
    /// The name of the kit's `era`.
    init(_ era: AnnotationEra) {
        id = era.rawValue
        firstYear = era.firstYear
        let parts = era.rawValue.split(separator: "-", omittingEmptySubsequences: false)
        lastYear = era.firstYear != nil && parts.count == 2 ? Int(parts[1]) : nil
    }
}

// MARK: - AnnotationsAxis

/// The Editors’ Annotations axis's logic, the app's `AnnotationsAxis`: each layer's reach across the
/// file's volumes and their eras, where a practice no era made standard is most common, and the drills
/// into a layer's volumes, with each volume's count and its marks. Its words are the browser app's.
///
/// A drill's volumes are in volume-id order, which runs by the years each covers, so a list shows a
/// practice arriving; only the volume whose page opened the layer's comes first.
enum AnnotationsAxis {

    /// One era's share of a layer: how many of its volumes carry it.
    struct Band: Equatable, Sendable {
        /// The era.
        let era: AnnotationEra
        /// Its volumes that carry the layer.
        let carrying: Int
        /// Its volumes.
        let total: Int

        /// The share of the era's volumes that carry the layer, 0 to 1.
        var share: Double { total == 0 ? 0 : Double(carrying) / Double(total) }
    }

    /// A layer's reach across the file's volumes.
    struct Reach: Equatable, Sendable {
        /// The layer.
        let layer: AnnotationLayer
        /// The volumes that carry it, in drill order.
        let carrying: [String]
        /// The volumes the file holds.
        let total: Int
        /// The eras, earliest first, with the late retrospectives last.
        let bands: [Band]
        /// The first era from which the series made it standard, or `nil`.
        let onset: AnnotationEra?
    }

    /// What a drill's caption states after its count: the layer's rule, the rule of a source note's
    /// form, or that of a printed aid.
    enum Rule: String, Sendable {
        case layer
        case sourceForm
        case aid
    }

    /// One way into a layer's volumes from its page: with it, without it, by form or by aid.
    struct Drill: Equatable, Sendable {
        /// The drill's stable id: `with`, `without`, `citation`, `fileNumber`, or an aid's id.
        let id: String
        /// Its volumes, in drill order.
        let volumeIds: [String]
        /// The rule its caption states.
        let rule: Rule
        /// The category whose count its rows show in place of the layer's: a source note's form.
        var accessoryCategory: AnnotationCategory? = nil
    }

    /// The eras in strip order: earliest first, the late retrospectives last.
    static var stripEras: [AnnotationEra] { AnnotationEra.chronological + [.retrospective] }

    /// A layer's reach in `index`.
    static func reach(of layer: AnnotationLayer, in index: VolumeAnnotationsIndex) -> Reach {
        var carrying: [String] = []
        var perEra: [AnnotationEra: (carrying: Int, total: Int)] = [:]
        for (volumeId, annotations) in index.volumes {
            let carries = layer.isCarried(by: annotations)
            if carries { carrying.append(volumeId) }
            var tally = perEra[annotations.era] ?? (0, 0)
            tally.total += 1
            if carries { tally.carrying += 1 }
            perEra[annotations.era] = tally
        }
        let bands = stripEras.map { era in
            Band(era: era, carrying: perEra[era]?.carrying ?? 0, total: perEra[era]?.total ?? 0)
        }
        return Reach(layer: layer, carrying: order(carrying), total: index.volumes.count, bands: bands,
                     onset: index.onset(where: layer.isCarried(by:)))
    }

    /// Volume ids in drill order: by id, numbers compared as numbers, which runs by the years each
    /// volume covers ("frus1969-76v2" before "frus1969-76v17").
    static func order(_ volumeIds: [String]) -> [String] {
        volumeIds.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// For a practice no era made standard, the era where it is most common, which the app's
    /// `standardLine(for:)` names; `nil` for a layer with an onset, and for one no volume carries.
    static func peak(of reach: Reach) -> AnnotationEra? {
        guard reach.onset == nil else { return nil }
        // Ties go to the earlier band: the strip's order.
        return reach.bands.filter({ $0.carrying > 0 }).max(by: { $0.share < $1.share })?.era
    }

    /// A layer's drills: the volumes with it and without it, and for source notes one per form; the
    /// printed aids have one per aid instead, since nearly every volume prints one.
    static func drills(for layer: AnnotationLayer, in index: VolumeAnnotationsIndex, reach: Reach? = nil) -> [Drill] {
        if layer == .printedAids { return aidDrills(in: index) }
        let reach = reach ?? self.reach(of: layer, in: index)
        let with = Set(reach.carrying)
        let without = order(index.volumes.keys.filter { !with.contains($0) })
        var drills = [
            Drill(id: "with", volumeIds: reach.carrying, rule: .layer),
            Drill(id: "without", volumeIds: without, rule: .layer),
        ]
        if layer == .sourceNotes {
            let forms: [(id: String, category: AnnotationCategory)] = [
                ("citation", .sourceCitation),
                ("fileNumber", .sourceFileNumber),
            ]
            for form in forms {
                let ids = order(index.volumeIds { $0.carries(form.category) })
                drills.append(Drill(id: form.id, volumeIds: ids, rule: .sourceForm, accessoryCategory: form.category))
            }
        }
        return drills
    }

    /// One drill per printed aid any volume prints, in the order a volume's page names them; the
    /// section kinds that share a name ("intro" and "introduction") are one aid.
    private static func aidDrills(in index: VolumeAnnotationsIndex) -> [Drill] {
        PrintedAid.all.compactMap { aid in
            let ids = order(index.volumeIds { annotations in aid.kinds.contains { annotations.prints(section: $0) } })
            guard !ids.isEmpty else { return nil }
            return Drill(id: aid.id, volumeIds: ids, rule: .aid)
        }
    }

    /// The drill of one cell of the matrix: the era's volumes that carry the layer, and the era's
    /// band, which its caption states.
    static func eraDrill(for layer: AnnotationLayer, era: AnnotationEra,
                         in index: VolumeAnnotationsIndex) -> (volumeIds: [String], band: Band) {
        let members = index.volumes.filter { $0.value.era == era }
        let ids = order(members.filter { layer.isCarried(by: $0.value) }.map(\.key))
        return (ids, Band(era: era, carrying: ids.count, total: members.count))
    }

    /// A volume's count in a drill: "279/280" for a layer that runs through a volume, "37 docs" for one
    /// found here and there, "12 notes" for editorial notes; `nil` at zero, and for references and the
    /// printed aids, which no one count says.
    static func accessory(for layer: AnnotationLayer, _ annotations: VolumeAnnotations,
                          category: AnnotationCategory? = nil) -> AnnotationDrill.Accessory? {
        let count = category.map(annotations.count) ?? layer.count(in: annotations)
        guard let count, count > 0 else { return nil }
        switch layer {
        case .people, .abbreviations, .correspondents, .sourceNotes, .classification, .despatch, .numbered,
             .footnotes:
            return .init(kind: "ratio", count: count, of: annotations.documents)
        case .editorialNotes:
            return .init(kind: "notes", count: count)
        case .subjects, .participants, .excisions, .marginalNotes:
            return .init(kind: "docs", count: count)
        case .crossReferences, .printedAids:
            return nil
        }
    }

    /// The list a volume prints that a layer links to and that none of its documents links to
    /// (`frus1977-80v27`'s List of Persons, and its List of Abbreviations), which the amber line names:
    /// `persons`, `terms`, or `nil`.
    static func unlinkedList(for layer: AnnotationLayer, _ annotations: VolumeAnnotations) -> String? {
        switch layer {
        case .people where annotations.count(.people) == 0 && annotations.personsListed > 0:
            return "persons"
        case .abbreviations where annotations.count(.abbreviations) == 0 && annotations.termsListed > 0:
            return "terms"
        default:
            return nil
        }
    }
}

// MARK: - A volume page's section

/// A volume page's Editors’ Annotations, as the app's `VolumeAnnotationsPresentation` builds it: the
/// layers the volume carries, in three groups, each row's line as the parts the browser app words and
/// joins, and the standard layers it lacks, each with the era from which the series made it standard.
/// A layer is in the volume or not, by the kit's thresholds; there is no partial state, and the counts
/// carry the coverage.
public struct VolumeAnnotationsSection: Codable, Equatable, Sendable {
    public var volumeId: String
    /// The groups that hold a row, in order: who is named, where it came from, how it connects.
    public var groups: [Group]
    /// The standard layers the volume lacks, in the order the groups show them; an era-bound practice
    /// is never listed as missing.
    public var absent: [AbsentRow]

    /// One of the three groups.
    public struct Group: Codable, Equatable, Sendable {
        /// The kit's `AnnotationCategory.Family`: `named`, `provenance` or `connects`.
        public var family: String
        /// Its rows, in the order the page shows them.
        public var rows: [Row]
    }

    /// One layer the volume carries, which opens the layer's page on the axis.
    public struct Row: Codable, Equatable, Sendable {
        /// The layer's id, `AnnotationLayer`'s.
        public var layer: String
        /// Its line's parts, in order; empty for none.
        public var parts: [Part]
    }

    /// A part of a row's line, which the browser app words: `ofDocuments` ("279 of 280 documents"),
    /// `personsListed`, `termsListed`, `documents`, `excisions`, `editorialNotes`, `xrefDocuments`,
    /// `xrefVolumes` and `xrefPages`, each with its count; `sourceForm`, with its `form`; and `aid`,
    /// with the aid's id.
    public struct Part: Codable, Equatable, Sendable {
        public var kind: String
        public var count: Int?
        /// The volume's documents, for `ofDocuments`.
        public var of: Int?
        /// `citations`, `fileNumbers` or `both`, for `sourceForm`.
        public var form: String?
        /// The aid's id, for `aid`.
        public var aid: String?

        init(kind: String, count: Int? = nil, of: Int? = nil, form: String? = nil, aid: String? = nil) {
            self.kind = kind
            self.count = count
            self.of = of
            self.form = form
            self.aid = aid
        }
    }

    /// A layer the series made standard that this volume lacks.
    public struct AbsentRow: Codable, Equatable, Sendable {
        /// The standard layer: `people`, `abbreviations`, `sourceNotes`, `classification`, `numbered`,
        /// `referencesToDocuments`, `editorialNotes` or `noteOnSources`.
        public var id: String
        /// The layer whose page the row opens: two are narrower than a layer, and open the layer that
        /// holds them (references to documents the cross-references, the Note on Sources the printed
        /// aids).
        public var layer: String
        /// The era from which the series made it standard; absent when no era did.
        public var onset: AnnotationEraName?
    }

    /// The section for one volume's `annotations`, its absent layers' onsets read from `index`.
    init(volumeId: String, annotations: VolumeAnnotations, index: VolumeAnnotationsIndex) {
        self.volumeId = volumeId
        let copy = Copy(annotations: annotations)
        // The layers the volume carries, in the table's order, which is the page's (§5.2).
        var rows: [AnnotationCategory.Family: [Row]] = [:]
        for layer in AnnotationLayer.allCases where layer.isCarried(by: annotations) {
            rows[layer.family, default: []].append(Row(layer: layer.rawValue, parts: copy.detail(of: layer)))
        }
        groups = [
            Group(family: AnnotationCategory.Family.named.rawValue, rows: rows[.named] ?? []),
            Group(family: AnnotationCategory.Family.provenance.rawValue, rows: rows[.provenance] ?? []),
            Group(family: AnnotationCategory.Family.connects.rawValue, rows: rows[.connects] ?? []),
        ].filter { !$0.rows.isEmpty }

        // The standard layers, in the order the groups show them (§5.2), each with the layer its row
        // opens on the axis.
        let standard: [(id: String, layer: AnnotationLayer, carried: Bool, onset: () -> AnnotationEra?)] = [
            ("people", .people, annotations.carries(.people), { index.onset(of: .people) }),
            ("abbreviations", .abbreviations, annotations.carries(.abbreviations), { index.onset(of: .abbreviations) }),
            ("sourceNotes", .sourceNotes, annotations.carriesSourceNotes, { index.onset(where: \.carriesSourceNotes) }),
            ("classification", .classification, annotations.carries(.classification), { index.onset(of: .classification) }),
            ("numbered", .numbered, annotations.carries(.numbered), { index.onset(of: .numbered) }),
            ("referencesToDocuments", .crossReferences, annotations.carries(.xrefDocuments),
             { index.onset(of: .xrefDocuments) }),
            ("editorialNotes", .editorialNotes, annotations.carries(.editorialNotes), { index.onset(of: .editorialNotes) }),
            ("noteOnSources", .printedAids, annotations.prints(section: "sources"),
             { index.onset { $0.prints(section: "sources") } }),
        ]
        absent = standard.filter { !$0.carried }.map { layer in
            AbsentRow(id: layer.id, layer: layer.layer.rawValue, onset: layer.onset().map(AnnotationEraName.init))
        }
    }

    /// The rows' counts as parts, for one volume: the app's `VolumeAnnotationsPresentation.Copy`, its
    /// choice of what each line says, with the words left to the browser app.
    private struct Copy {
        let annotations: VolumeAnnotations

        /// "279 of 280 documents", with what the volume lists after it when there is any.
        func coverage(_ category: AnnotationCategory, listed: Part? = nil) -> [Part] {
            let line = of(annotations.count(category))
            guard let listed else { return line }
            return line + [listed]
        }

        /// "N of M documents", M the volume's documents.
        func of(_ count: Int) -> [Part] {
            [Part(kind: "ofDocuments", count: count, of: annotations.documents)]
        }

        /// "N documents".
        func documents(_ category: AnnotationCategory) -> [Part] {
            [Part(kind: "documents", count: annotations.count(category))]
        }

        /// A carried layer's line: its coverage, its count, or its parts, as each layer says it.
        func detail(of layer: AnnotationLayer) -> [Part] {
            switch layer {
            case .people: return coverage(.people, listed: personsListed)
            case .abbreviations: return coverage(.abbreviations, listed: termsListed)
            case .correspondents: return documents(.correspondents)
            case .subjects: return documents(.subjects)
            case .participants: return documents(.participants)
            case .sourceNotes: return sourceNotes
            case .classification: return coverage(.classification)
            case .excisions: return excisions
            case .despatch: return documents(.despatch)
            case .numbered: return coverage(.numbered)
            case .crossReferences: return crossReferences ?? []
            case .editorialNotes: return editorialNotes
            case .footnotes: return coverage(.footnotes)
            case .marginalNotes: return documents(.marginalNotes)
            case .printedAids:
                return PrintedAid.printed(in: annotations.sections).map { Part(kind: "aid", aid: $0) }
            }
        }

        /// "325 people listed", or `nil` when the volume prints no List of Persons the index read.
        var personsListed: Part? {
            guard annotations.personsListed > 0 else { return nil }
            return Part(kind: "personsListed", count: annotations.personsListed)
        }

        /// "470 terms listed", or `nil` when the volume prints no List of Abbreviations the index read.
        var termsListed: Part? {
            guard annotations.termsListed > 0 else { return nil }
            return Part(kind: "termsListed", count: annotations.termsListed)
        }

        /// "268 of 280 documents · archival citations (“Source: …”)": the coverage, then the form.
        var sourceNotes: [Part] {
            let citations = annotations.count(.sourceCitation) > 0
            let fileNumbers = annotations.count(.sourceFileNumber) > 0
            let form: String
            switch (citations, fileNumbers) {
            case (true, false):
                form = "citations"
            case (false, true):
                form = "fileNumbers"
            default:
                form = "both"
            }
            return of(annotations.sourceNotes) + [Part(kind: "sourceForm", form: form)]
        }

        /// "31 documents with text not declassified".
        var excisions: [Part] {
            [Part(kind: "excisions", count: annotations.count(.excisions))]
        }

        /// "12 editorial notes".
        var editorialNotes: [Part] {
            [Part(kind: "editorialNotes", count: annotations.count(.editorialNotes))]
        }

        /// The documents that cite the volume's own documents, other volumes and printed pages, the
        /// parts present; `nil` when none does.
        var crossReferences: [Part]? {
            var parts: [Part] = []
            if annotations.carries(.xrefDocuments) {
                parts.append(Part(kind: "xrefDocuments", count: annotations.count(.xrefDocuments)))
            }
            if annotations.carries(.xrefVolumes) {
                parts.append(Part(kind: "xrefVolumes", count: annotations.count(.xrefVolumes)))
            }
            if annotations.carries(.xrefPages) {
                parts.append(Part(kind: "xrefPages", count: annotations.count(.xrefPages)))
            }
            return parts.isEmpty ? nil : parts
        }
    }
}

// MARK: - The axis, a layer's page and a drill

/// A layer's reach across the file's volumes, as the axis's row and the layer's page show it.
public struct AnnotationReach: Codable, Equatable, Sendable {
    /// The layer's id, `AnnotationLayer`'s.
    public var layer: String
    /// The volumes that carry it.
    public var carrying: Int
    /// The volumes the file holds.
    public var total: Int
    /// Each era's share, in strip order: earliest first, the late retrospectives last.
    public var bands: [Band]
    /// The first era from which the series made it standard; absent when none did.
    public var onset: AnnotationEraName?
    /// For a practice no era made standard, the era where it is most common, ties to the earlier;
    /// absent with an onset, and when no volume carries it.
    public var peak: AnnotationEraName?

    /// One era's share of the layer.
    public struct Band: Codable, Equatable, Sendable {
        /// The era's id, an `AnnotationEraName`'s.
        public var era: String
        /// Its volumes that carry the layer.
        public var carrying: Int
        /// Its volumes.
        public var total: Int
    }

    init(_ reach: AnnotationsAxis.Reach) {
        layer = reach.layer.rawValue
        carrying = reach.carrying.count
        total = reach.total
        bands = reach.bands.map { Band(era: $0.era.rawValue, carrying: $0.carrying, total: $0.total) }
        onset = reach.onset.map(AnnotationEraName.init)
        peak = AnnotationsAxis.peak(of: reach).map(AnnotationEraName.init)
    }
}

/// The Editors’ Annotations axis: every layer in the three groups a volume's page uses, each with how
/// many volumes carry it, era by era.
public struct AnnotationsAxisPage: Codable, Equatable, Sendable {
    /// The volumes the file holds.
    public var total: Int
    /// The eras, in strip order, which the matrix's columns are.
    public var eras: [AnnotationEraName]
    /// The groups, in order, each with its layers in the page's order.
    public var groups: [Group]

    /// One of the three groups.
    public struct Group: Codable, Equatable, Sendable {
        /// The kit's `AnnotationCategory.Family`: `named`, `provenance` or `connects`.
        public var family: String
        public var layers: [AnnotationReach]
    }
}

/// One layer's page on the axis: its reach, and its drills into the volumes with it and without it (or,
/// for the printed aids, one drill per aid).
public struct AnnotationLayerPage: Codable, Equatable, Sendable {
    public var reach: AnnotationReach
    /// The eras, in strip order, which the strip's cells name.
    public var eras: [AnnotationEraName]
    /// The drills, in the page's order.
    public var drills: [Drill]

    /// A drill, by its id, with how many volumes it lists.
    public struct Drill: Codable, Equatable, Sendable {
        public var id: String
        public var count: Int
    }
}

/// The volumes a drill lists, the app's R-1 list of them: in drill order, the volume whose page opened
/// the layer's first, each with its count and its marks.
public struct AnnotationDrill: Codable, Equatable, Sendable {
    /// The layer's id.
    public var layer: String
    /// `with`, `without`, `citation`, `fileNumber`, an aid's id, or `era` for a cell of the matrix.
    public var drill: String
    /// A cell's era.
    public var era: AnnotationEraName?
    /// Which rule its caption states: `layer`, `sourceForm` or `aid`.
    public var rule: String
    /// How many volumes it lists.
    public var count: Int
    /// Of how many: the file's volumes, or a cell's era's.
    public var total: Int
    public var volumes: [Volume]

    /// One volume of the list.
    public struct Volume: Codable, Equatable, Sendable {
        public var volumeId: String
        /// Its count, where the layer has one and it is not zero.
        public var accessory: Accessory?
        /// `persons` or `terms`: the volume prints the list the layer links to, and none of its documents
        /// links to it.
        public var unlinked: String?
        /// `true` for the volume whose page opened the layer's.
        public var from: Bool?
    }

    /// A volume's count: `ratio`, its documents that carry the layer `of` its documents; `notes`, its
    /// editorial notes; `docs`, its documents that carry a layer found here and there.
    public struct Accessory: Codable, Equatable, Sendable {
        public var kind: String
        public var count: Int
        public var of: Int?

        init(kind: String, count: Int, of: Int? = nil) {
            self.kind = kind
            self.count = count
            self.of = of
        }
    }

    /// The list of `volumeIds`, each volume's count and marks from `index`, with `fromVolumeId` first
    /// when the list holds it, as the app's `AnnotationsAxis.spec` builds one.
    init(layer: AnnotationLayer, drill: String, era: AnnotationEra? = nil, rule: AnnotationsAxis.Rule,
         volumeIds: [String], total: Int, index: VolumeAnnotationsIndex, from fromVolumeId: String?,
         accessoryCategory: AnnotationCategory? = nil) {
        var volumeIds = volumeIds
        if let fromVolumeId, let at = volumeIds.firstIndex(of: fromVolumeId) {
            volumeIds.insert(volumeIds.remove(at: at), at: 0)
        }
        self.layer = layer.rawValue
        self.drill = drill
        self.era = era.map(AnnotationEraName.init)
        self.rule = rule.rawValue
        count = volumeIds.count
        self.total = total
        volumes = volumeIds.map { volumeId in
            let annotations = index[volumeId]
            return Volume(volumeId: volumeId,
                          accessory: annotations.flatMap {
                              AnnotationsAxis.accessory(for: layer, $0, category: accessoryCategory)
                          },
                          unlinked: annotations.flatMap { AnnotationsAxis.unlinkedList(for: layer, $0) },
                          from: volumeId == fromVolumeId ? true : nil)
        }
    }
}

extension VolumeAnnotationsSection: ResponseEncodable {}
extension AnnotationsAxisPage: ResponseEncodable {}
extension AnnotationLayerPage: ResponseEncodable {}
extension AnnotationDrill: ResponseEncodable {}

// MARK: - The bundled file

/// The bundled file's index with each layer's reach, computed once: the file is the image's, so its
/// reaches change only with the server's build.
final class VolumeAnnotationsData: Sendable {
    /// The file, decoded by the kit.
    let index: VolumeAnnotationsIndex
    /// Each layer's reach, its volumes in drill order.
    let reaches: [AnnotationLayer: AnnotationsAxis.Reach]

    init(index: VolumeAnnotationsIndex) {
        self.index = index
        reaches = Dictionary(uniqueKeysWithValues: AnnotationLayer.allCases.map {
            ($0, AnnotationsAxis.reach(of: $0, in: index))
        })
    }

    /// `layer`'s reach.
    func reach(of layer: AnnotationLayer) -> AnnotationsAxis.Reach {
        reaches[layer] ?? AnnotationsAxis.reach(of: layer, in: index)
    }
}

/// `volume-annotations-index.json`, decoded the first time a page asks, by the kit's
/// `VolumeAnnotationsIndex`, as the app's `VolumeAnnotationsStore.shared` decodes it once; nil, then
/// and after, for a file missing or malformed, and for one that holds no volume, which the app's
/// axis shows as unavailable too (`AnnotationsIndexView`'s `!index.volumes.isEmpty`): the routes
/// answer all three as unavailable.
final class VolumeAnnotationsFile: @unchecked Sendable {
    /// The file's name among the app's data files.
    static let name = "volume-annotations-index.json"

    private let lock = NSLock()
    private var loaded: VolumeAnnotationsData??

    /// The file in `directory`, decoded once.
    func data(in directory: URL) -> VolumeAnnotationsData? {
        lock.lock()
        defer { lock.unlock() }
        if let loaded { return loaded }
        let data = (try? Data(contentsOf: directory.appendingPathComponent(Self.name)))
            .flatMap { try? JSONDecoder().decode(VolumeAnnotationsIndex.self, from: $0) }
            .flatMap { $0.volumes.isEmpty ? nil : $0 }
            .map(VolumeAnnotationsData.init(index:))
        loaded = .some(data)
        return data
    }
}

// MARK: - Routes

enum AnnotationRoutes {
    static func add(to router: Router<APIRequestContext>, resources: ServerResources) {
        /// The file, or the problem a page says when the server could not read it.
        @Sendable func annotations() throws -> VolumeAnnotationsData {
            guard let data = resources.volumeAnnotations else {
                throw APIProblem(.serviceUnavailable, code: "ANNOTATIONS_UNAVAILABLE",
                                 detail: "\(VolumeAnnotationsFile.name) is missing from the app's data files, does not decode, or holds no volume.")
            }
            return data
        }
        /// The layer the path names, or the problem that names the layers.
        @Sendable func layer(_ context: APIRequestContext) throws -> AnnotationLayer {
            let id = try context.parameters.require("layer")
            guard let layer = AnnotationLayer(rawValue: id) else {
                throw APIProblem(.notFound, code: "ANNOTATION_LAYER_NOT_FOUND",
                                 detail: "No layer of editorial annotation is called \(id); the layers are \(AnnotationLayer.allCases.map(\.rawValue).joined(separator: ", ")).")
            }
            return layer
        }
        let eras = AnnotationsAxis.stripEras.map(AnnotationEraName.init)

        // A volume page's Editors’ Annotations, for any catalogue volume the file holds, downloaded or not.
        router.get("/api/v1/volumes/:volumeId/annotations") { request, context -> VolumeAnnotationsSection in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            let data = try annotations()
            guard let volume = data.index[volumeId] else {
                throw APIProblem(.notFound, code: "VOLUME_ANNOTATIONS_NOT_FOUND",
                                 detail: "\(VolumeAnnotationsFile.name) holds nothing for \(volumeId).")
            }
            return VolumeAnnotationsSection(volumeId: volumeId, annotations: volume, index: data.index)
        }
        router.get("/api/v1/annotations") { request, _ -> AnnotationsAxisPage in
            try FormQuery(request.uri.query).refuseUnknown([])
            let data = try annotations()
            let groups = AnnotationCategory.Family.allCases.map { family in
                AnnotationsAxisPage.Group(family: family.rawValue,
                                          layers: AnnotationLayer.allCases.filter { $0.family == family }.map {
                                              AnnotationReach(data.reach(of: $0))
                                          })
            }
            return AnnotationsAxisPage(total: data.index.volumes.count, eras: eras, groups: groups)
        }
        router.get("/api/v1/annotations/:layer") { request, context -> AnnotationLayerPage in
            try FormQuery(request.uri.query).refuseUnknown([])
            let layer = try layer(context)
            let data = try annotations()
            let reach = data.reach(of: layer)
            return AnnotationLayerPage(reach: AnnotationReach(reach), eras: eras,
                                       drills: AnnotationsAxis.drills(for: layer, in: data.index, reach: reach).map {
                                           .init(id: $0.id, count: $0.volumeIds.count)
                                       })
        }
        // A drill of a layer's page; `from` is the volume whose page opened the layer's, which comes first.
        router.get("/api/v1/annotations/:layer/drills/:drill") { request, context -> AnnotationDrill in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["from"])
            let from = try query.single("from")
            let layer = try layer(context)
            let id = try context.parameters.require("drill")
            let data = try annotations()
            let drills = AnnotationsAxis.drills(for: layer, in: data.index, reach: data.reach(of: layer))
            guard let drill = drills.first(where: { $0.id == id }) else {
                throw APIProblem(.notFound, code: "ANNOTATION_DRILL_NOT_FOUND",
                                 detail: "\(layer.rawValue)'s page has no list \(id); its lists are \(drills.map(\.id).joined(separator: ", ")).")
            }
            return AnnotationDrill(layer: layer, drill: drill.id, rule: drill.rule, volumeIds: drill.volumeIds,
                                   total: data.index.volumes.count, index: data.index, from: from,
                                   accessoryCategory: drill.accessoryCategory)
        }
        // A cell of the matrix: the era's volumes that carry the layer.
        router.get("/api/v1/annotations/:layer/eras/:era") { request, context -> AnnotationDrill in
            try FormQuery(request.uri.query).refuseUnknown([])
            let layer = try layer(context)
            let id = try context.parameters.require("era")
            guard let era = AnnotationEra(rawValue: id) else {
                throw APIProblem(.notFound, code: "ANNOTATION_ERA_NOT_FOUND",
                                 detail: "No era is called \(id); the eras are \(AnnotationEra.allCases.map(\.rawValue).joined(separator: ", ")).")
            }
            let data = try annotations()
            let cell = AnnotationsAxis.eraDrill(for: layer, era: era, in: data.index)
            return AnnotationDrill(layer: layer, drill: "era", era: era, rule: .layer, volumeIds: cell.volumeIds,
                                   total: cell.band.total, index: data.index, from: nil)
        }
    }
}
