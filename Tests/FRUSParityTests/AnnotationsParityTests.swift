// The app's words and the lines of its code that the web takes for the editors' annotations
// (FRUS-Explorer#1859 to #1862, their follow-ups #1868, #1873 and #1874, which S21b's pin move
// followed, and PLAN's rule for view code: "mirrored with a parity test that reads the app's source
// at the pin"), read from the app's source, the kit's, the server's and the browser
// app's at once: a volume page's Editors’ Annotations (`VolumeAnnotationsPresentation`,
// `VolumeAnnotationsSection`) and Browse's axis of that name (`AnnotationLayer`, `AnnotationsAxis`,
// `AnnotationsAxisViews`). The table of layers, the rows, the reaches and the drills are the server's
// mirrors (Sources/FRUSLightAPI/Annotations.swift), over the kit's `VolumeAnnotationsIndex`; the words
// and the way they are put together are the browser app's (web/src/copy.ts, web/src/browse/annotationRules.ts).
// A pin move that changes one fails here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct AnnotationsParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func kit(_ path: String) throws -> String { try SearchSetParityTests.kit(path) }
    static func web(_ path: String) throws -> String { try SearchSetParityTests.web(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }

    static let presentation = "Browser/VolumeAnnotationsPresentation.swift"
    static let section = "Browser/VolumeAnnotationsSection.swift"
    static let axis = "Browser/AnnotationsAxis.swift"
    static let views = "Browser/AnnotationsAxisViews.swift"
    static let countCopy = "FRUSCoreKit/Models/CountCopy.swift"

    /// Whether copy.ts's block holds `name` with `value`, in either of the quotes a string takes.
    static func holds(_ block: String, _ name: String, _ value: String) -> Bool {
        block.contains("\(name): '\(value)'") || block.contains("\(name): \"\(value)\"")
    }

    /// The objects nested in copy.ts's `annotations` block, each of plain strings.
    static let nestedNames = ["families", "layers", "aids", "sourceForms", "rules", "practices", "appUse"]

    /// The flattened `name: { … }` object nested in the block.
    static func nested(_ name: String, in block: String) throws -> String {
        let start = try #require(block.range(of: "\(name): {"), "copy.annotations has \(name)")
        let end = try #require(block.range(of: "}", range: start.upperBound..<block.endIndex))
        return String(block[start.lowerBound..<end.upperBound])
    }

    /// Where the block holds the word the app's `key` names: the nested object of its kind, or the
    /// block's top level, its nested objects taken out, so a word in the wrong place is found wanting.
    static func scope(of key: String, in block: String) throws -> String {
        let parts = key.split(separator: ".").map(String.init)
        let name: String?
        if key.hasPrefix("browser.volume.annotations.group.") {
            name = "families"
        } else if key.hasPrefix("browser.volume.annotations.sourceNotes.") {
            name = "sourceForms"
        } else if key.hasPrefix("browser.annotations.rule.") {
            name = "rules"
        } else if key.hasPrefix("browser.annotations.practice.") {
            name = "practices"
        } else if key.hasPrefix("browser.annotations.app.") {
            name = "appUse"
        } else if parts.count == 4, key.hasPrefix("browser.volume.annotations."),
                  AnnotationLayer.allCases.map(\.rawValue).contains(parts[3]) {
            name = "layers"
        } else {
            name = nil
        }
        if let name { return try nested(name, in: block) }
        var top = block
        for nestedName in nestedNames { top = top.replacingOccurrences(of: try nested(nestedName, in: block), with: "") }
        return top
    }

    /// Each word the web takes, where the app's or the kit's source writes it under its key, and in
    /// copy.ts's `annotations` block under the name the screens read.
    @Test func theAppsWordsAreTheWebs() throws {
        let block = try NoteViewParityTests.block("annotations", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts"))
        let words: [(file: String, key: String, value: String, web: String)] = [
            (Self.presentation, "browser.volume.annotations.header", "Editors’ Annotations", "title"),
            (Self.presentation, "browser.volume.annotations.group.named", "Who is named", "named"),
            (Self.presentation, "browser.volume.annotations.group.provenance", "Where it came from", "provenance"),
            (Self.presentation, "browser.volume.annotations.group.connects", "How it connects", "connects"),
            (Self.presentation, "browser.volume.annotations.people", "People tagged", "people"),
            (Self.presentation, "browser.volume.annotations.abbreviations", "Abbreviations explained", "abbreviations"),
            (Self.presentation, "browser.volume.annotations.correspondents", "Senders and recipients", "correspondents"),
            (Self.presentation, "browser.volume.annotations.subjects", "Subject lines", "subjects"),
            (Self.presentation, "browser.volume.annotations.participants", "Meeting participants", "participants"),
            (Self.presentation, "browser.volume.annotations.sourceNotes", "Source notes", "sourceNotes"),
            (Self.presentation, "browser.volume.annotations.classification", "Classification markings", "classification"),
            (Self.presentation, "browser.volume.annotations.excisions", "Redactions marked as not declassified", "excisions"),
            (Self.presentation, "browser.volume.annotations.editorialOmissions", "Marked editorial omissions", "editorialOmissions"),
            (Self.presentation, "browser.volume.annotations.despatch", "Despatch numbers", "despatch"),
            (Self.presentation, "browser.volume.annotations.numbered", "Numbered documents", "numbered"),
            (Self.presentation, "browser.volume.annotations.crossReferences", "Cross-references", "crossReferences"),
            (Self.presentation, "browser.volume.annotations.referencesToDocuments", "References to documents", "referencesToDocuments"),
            (Self.presentation, "browser.volume.annotations.editorialNotes", "Editorial notes", "editorialNotes"),
            (Self.presentation, "browser.volume.annotations.footnotes", "Footnotes", "footnotes"),
            (Self.presentation, "browser.volume.annotations.marginalNotes", "Marginal notes", "marginalNotes"),
            (Self.presentation, "browser.volume.annotations.printedAids", "Front and back matter", "printedAids"),
            (Self.presentation, "browser.volume.annotations.noteOnSources", "Note on Sources", "noteOnSources"),
            (Self.presentation, "browser.volume.annotations.sourceNotes.citations", "archival citations (“Source: …”)", "citations"),
            (Self.presentation, "browser.volume.annotations.sourceNotes.fileNumbers", "file numbers above the heading", "fileNumbers"),
            (Self.presentation, "browser.volume.annotations.sourceNotes.both", "archival citations and file numbers", "both"),
            (Self.presentation, "browser.volume.annotations.absent.people.hint", "Search the names instead.", "peopleHint"),
            (Self.section, "browser.volume.annotations.row.hint", "Opens what the editors did, and the volumes that carry it.", "rowHint"),
            (Self.axis, "browser.annotations.rule.people",
             "A volume counts when at least half its documents link a name to its List of Persons.", "people"),
            (Self.axis, "browser.annotations.rule.abbreviations",
             "A volume counts when at least half its documents link a term to its List of Abbreviations.", "abbreviations"),
            (Self.axis, "browser.annotations.rule.correspondents",
             "A volume counts when at least half its documents mark a sender or a recipient in the heading.", "correspondents"),
            (Self.axis, "browser.annotations.rule.subjects", "A volume counts when one of its documents prints a Subject line.", "subjects"),
            (Self.axis, "browser.annotations.rule.participants",
             "A volume counts when one of its documents lists who attended a meeting.", "participants"),
            (Self.axis, "browser.annotations.rule.sourceNotes",
             "A volume counts when at least half its documents carry a source note, of either form.", "sourceNotes"),
            (Self.axis, "browser.annotations.rule.classification",
             "A volume counts when at least half its documents carry a classification marking, as the app reads them.", "classification"),
            (Self.axis, "browser.annotations.rule.excisions",
             "A volume counts when one of its documents marks a redaction as not declassified: text in it, or the whole document.",
             "excisions"),
            (Self.axis, "browser.annotations.rule.editorialOmissions",
             "A volume published from 1925 counts when one of its documents says, in brackets, what the editors left out: “[Here follows …]” or “[Omitted here is …]”.",
             "editorialOmissions"),
            (Self.axis, "browser.annotations.rule.despatch",
             "A volume counts when at least a tenth of its documents carry a despatch number.", "despatch"),
            (Self.axis, "browser.annotations.rule.numbered",
             "A volume counts when at least half its documents print a document number.", "numbered"),
            (Self.axis, "browser.annotations.rule.crossReferences",
             "A volume counts when one of its documents cites another of its documents, another volume or a printed page.",
             "crossReferences"),
            (Self.axis, "browser.annotations.rule.editorialNotes", "A volume counts when it prints an editorial note.", "editorialNotes"),
            (Self.axis, "browser.annotations.rule.footnotes",
             "A volume counts when at least half its documents carry a footnote.", "footnotes"),
            (Self.axis, "browser.annotations.rule.marginalNotes",
             "A volume counts when one of its documents prints a marginal note.", "marginalNotes"),
            (Self.axis, "browser.annotations.rule.printedAids",
             "A volume counts when it prints one of the sections listed below.", "printedAids"),
            (Self.axis, "browser.annotations.rule.sourceForm",
             "A volume counts when at least half its documents carry a source note of this form.", "sourceForm"),
            (Self.axis, "browser.annotations.rule.aid", "A volume counts when it prints this section.", "aid"),
            (Self.axis, "browser.annotations.practice.people",
             "The editors linked each person a document names to the volume's List of Persons, where the person is identified.", "people"),
            (Self.axis, "browser.annotations.practice.abbreviations",
             "The editors linked each abbreviation in a document to the volume's List of Abbreviations, where it is spelled out.",
             "abbreviations"),
            (Self.axis, "browser.annotations.practice.correspondents",
             "The editors marked who sent each document, and to whom, in its heading.", "correspondents"),
            (Self.axis, "browser.annotations.practice.subjects",
             "Where a memorandum carried a Subject line, the editors printed it with the memorandum.", "subjects"),
            (Self.axis, "browser.annotations.practice.participants",
             "Where a memorandum of conversation lists who took part, the editors marked the list.", "participants"),
            (Self.axis, "browser.annotations.practice.sourceNotes",
             "A source note says where the editors found a document. It was printed first as a file number above the heading, and later as a note that begins “Source:” with the full archival citation. The earliest volumes print none: a despatch there carries the post's own number instead.",
             "sourceNotes"),
            (Self.axis, "browser.annotations.practice.classification",
             "The editors printed each document's security classification, first above the dateline and later in the source note.",
             "classification"),
            (Self.axis, "browser.annotations.practice.excisions",
             "The editors mark what declassification review redacted: a gap in the printed text, “[… not declassified]”, or a whole document withheld, listed in its place with its heading, its source note and the number of pages not declassified. From Secretary Kellogg’s 1925 order until the 1991 statute, volumes marked an omission with an ellipsis, whether the editors left the text out or it was not cleared for publication, so their redactions cannot be told from the editors’ omissions and are not counted here. Volumes published before the 1925 order marked an omission with a row of asterisks, under no written rule and without saying whose cut it was; those are not counted here either.",
             "excisions"),
            (Self.axis, "browser.annotations.practice.editorialOmissions",
             "Since Secretary Kellogg’s 1925 order, where the editors left out part of a document as not relevant to the volume, they could say so in brackets and describe what was omitted. Until the 1991 statute an ellipsis could also mark an omission, the editors’ or a redaction, and those are not counted here. Volumes published before the order marked an omission with a row of asterisks, not a bracketed note, and are not counted here.",
             "editorialOmissions"),
            (Self.axis, "browser.annotations.practice.despatch",
             "Older volumes print the number a diplomatic post gave each despatch it sent, “No. 74.”, by which the despatch is found in the archives.",
             "despatch"),
            (Self.axis, "browser.annotations.practice.numbered",
             "The editors numbered the documents in print, so that each heading opens with its number: “12. Telegram From …”.", "numbered"),
            (Self.axis, "browser.annotations.practice.crossReferences",
             "The editors' notes point to other documents in the volume, to other volumes and to printed pages: “See Document 12”, “see p. 123”.",
             "crossReferences"),
            (Self.axis, "browser.annotations.practice.editorialNotes",
             "Where no single document tells the story, the editors wrote a note of their own, set between the documents.", "editorialNotes"),
            (Self.axis, "browser.annotations.practice.footnotes",
             "The editors' footnotes explain a document: who it names, what it answered, what became of it.", "footnotes"),
            (Self.axis, "browser.annotations.practice.marginalNotes",
             "A few volumes print the notes written in a document's margin, set off from its text.", "marginalNotes"),
            (Self.axis, "browser.annotations.practice.printedAids",
             "Besides its documents, a volume prints front and back matter to help readers use it: a preface, lists of sources, abbreviations and persons, an index.",
             "printedAids"),
            // The sentences of "In the app" whose screens this server has too; the others are the web's own, below.
            (Self.axis, "browser.annotations.app.abbreviations", "The reader opens a linked abbreviation's meaning.", "abbreviations"),
            (Self.axis, "browser.annotations.app.numbered", "Document titles and citations give the number the volume prints.", "numbered"),
            (Self.axis, "browser.annotations.app.editorialNotes", "Search can limit its results to editorial notes.", "editorialNotes"),
            (Self.axis, "browser.annotations.app.footnotes", "The reader shows each footnote with its document.", "footnotes"),
            (Self.axis, "browser.annotations.app.none", "The reader shows these as printed. Nothing else in the app reads them yet.", "none"),
            (Self.axis, "browser.annotations.era.retrospective", "the late retrospectives", "eraRetrospective"),
            (Self.axis, "browser.annotations.era.retrospective.short", "Retro.", "eraRetrospectiveShort"),
            (Self.axis, "browser.annotations.era.retrospective.title", "Late retrospectives", "eraRetrospectiveTitle"),
            (Self.axis, "browser.annotations.standard.none.retrospective",
             "No era made it standard. It is most common in the late retrospective volumes.", "standardNoneRetrospective"),
            (Self.axis, "browser.annotations.standard.redactions",
             "Volumes produced after the passage of the 1991 statute include explicit editorial annotation of redactions made during the declassification process.",
             "standardRedactions"),
            (Self.axis, "browser.annotations.drill.with", "Volumes with it", "drillWith"),
            (Self.axis, "browser.annotations.drill.without", "Volumes without it", "drillWithout"),
            (Self.axis, "browser.annotations.drill.sourceCitation", "Archival citations (“Source: …”)", "drillCitation"),
            (Self.axis, "browser.annotations.drill.sourceFileNumber", "File numbers above the heading", "drillFileNumber"),
            (Self.axis, "browser.annotations.note.from", "You came here from this volume.", "noteFrom"),
            (Self.axis, "browser.annotations.note.people.unlinked",
             "Prints a List of Persons, but none of its documents links a name to it.", "notePersonsUnlinked"),
            (Self.axis, "browser.annotations.note.abbreviations.unlinked",
             "Prints a List of Abbreviations, but none of its documents links a term to it.", "noteTermsUnlinked"),
            (Self.axis, "browser.annotations.note.editorialOmissions.before1925",
             "Published before the 1925 order, when the editors marked an omission with a row of asterisks, not a bracketed note.",
             "noteBefore1925"),
            (Self.views, "browser.annotations.unavailable.title", "Editors’ Annotations Unavailable", "unavailableTitle"),
            (Self.views, "browser.annotations.row.help",
             "What the editors did, when it became standard, and the volumes that carry it", "rowHelp"),
            (Self.views, "browser.annotations.category.practice", "What the editors did", "practiceHeader"),
            (Self.views, "browser.annotations.category.eras", "Era by era", "erasHeader"),
            (Self.views, "browser.annotations.category.app", "In the app", "appHeader"),
            (Self.views, "browser.annotations.category.volumes", "Volumes", "volumesHeader"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(try Self.app(word.file), word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(Self.holds(try Self.scope(of: word.key, in: block), word.web, word.value),
                    "copy.annotations holds \(word.web) as \(word.value), where \(word.key) belongs")
        }
        // The axis's name in Browse's axes, as the Mac's sidebar names it.
        let axes = try NoteViewParityTests.block("axes", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts"))
        #expect(try Self.app("App/MacCorpusBrowserWindow.swift").contains("Text(VolumeAnnotationsPresentation.title) .lineLimit(2)"))
        #expect(Self.holds(axes, "annotations", "Editors’ Annotations"))
    }

    /// The web's own words where the app's would not be true of this server, each held beside the app's
    /// sentence, so that a pin move that changes the app's says that the web's needs reading again.
    @Test func theWebsOwnWordsStandBesideTheApps() throws {
        let block = try NoteViewParityTests.block("annotations", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts"))
        let axis = try Self.app(Self.axis)
        let own: [(key: String, app: String, web: String, line: String)] = [
            // The People browser and Person analytics are S21g's and S24g's; the reader's person card is this server's.
            ("browser.annotations.app.people",
             "The People browser and Person analytics read these links. Where a volume does not link its names, search for them instead.",
             "people", "The reader opens a linked person’s entry. Where a volume does not link its names, search for them instead."),
            // Source Explorer and the Archives axis are S22d's and later.
            ("browser.annotations.app.sourceNotes",
             "Source Explorer and the Archives axis read them, and a chapter's list of documents shows the first line of each note.",
             "sourceNotes", "The reader shows each document’s source note."),
            // Search's rows show no classification chip here until S22d; the reader prints the marking,
            // and the kit's chip beside a "Source:" note's, which a volume that prints it in the opener has none of.
            ("browser.annotations.app.classification", "Search's results and Source Explorer show a document's marking.",
             "classification", "The reader shows a document’s marking as the volume prints it."),
            // The reader's pages are a full parse's documents, which leave out a volume's index and its lists
            // of sources and persons, where the app's Read Index opens each (S21b's follow-up).
            ("browser.annotations.app.printedAids",
             "A volume's page lists them under Front Matter and Back Matter, and the reader opens each one.",
             "printedAids", "A volume’s page lists them under Front Matter and Back Matter, and the reader opens most of them; its index and its lists of sources and persons do not open here yet."),
            // The graph and Cross-Volume Connections are S23e's.
            ("browser.annotations.app.crossReferences",
             "The reader follows each one, and the Cross-Reference graph and Cross-Volume Connections draw them.",
             "crossReferences", "The reader follows each one."),
        ]
        let appUse = try Self.nested("appUse", in: block)
        for sentence in own {
            #expect(NoteViewParityTests.writes(axis, sentence.key, sentence.app), "\(Self.axis) writes \(sentence.key) as \(sentence.app)")
            #expect(Self.holds(appUse, sentence.web, sentence.line), "copy.annotations.appUse.\(sentence.web) is \(sentence.line)")
        }
        // Despatch numbers: Source Explorer, which the app names, is not this server's, so the web says of
        // them what the app says of a layer nothing else reads.
        #expect(NoteViewParityTests.writes(axis, "browser.annotations.app.despatch",
                                           "Source Explorer shows a document's despatch number with its archival series."))
        #expect(!appUse.contains("despatch:"))
        // The app says to reinstall it; the web keeps its first sentence.
        let unavailable = "The bundled annotation data could not be loaded."
        #expect(NoteViewParityTests.writes(try Self.app(Self.views), "browser.annotations.unavailable.detail",
                                           unavailable + " Reinstalling the app restores it."))
        #expect(Self.holds(block, "unavailableDetail", unavailable))
    }

    /// The app's format strings, each a function in copy.ts that writes what the format writes, its
    /// arguments in the format's order; and `CountCopy`'s rule for them, which annotationRules.ts mirrors.
    @Test func theAppsFormatsAreTheWebs() throws {
        let block = try NoteViewParityTests.block("annotations", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts"))
        let formats: [(file: String, key: String, value: String, web: String)] = [
            (Self.presentation, "browser.volume.annotations.row.spoken", "%1$@: %2$@.",
             "rowSpoken: (label: string, detail: string) => `${label}: ${detail}.`,"),
            (Self.presentation, "browser.volume.annotations.absent.spoken", "Not in this volume: %@.",
             "absentSpoken: (label: string) => `Not in this volume: ${label}.`,"),
            (Self.presentation, "browser.volume.annotations.absent.header", "Not in this volume (%@)",
             "absentTitle: (count: string) => `Not in this volume (${count})`,"),
            (Self.presentation, "browser.volume.annotations.absent.onset", "Standard in the volumes covering %@ on.",
             "standardFrom: (year: string) => `Standard in the volumes covering ${year} on.`,"),
            (Self.presentation, "browser.volume.annotations.ofDocuments.one", "%2$@ of %1$@ document",
             "ofDocumentsOne: (total: string, count: string) => `${count} of ${total} document`,"),
            (Self.presentation, "browser.volume.annotations.ofDocuments.many", "%2$@ of %1$@ documents",
             "ofDocumentsMany: (total: string, count: string) => `${count} of ${total} documents`,"),
            (Self.presentation, "browser.volume.annotations.people.listed.one", "%@ person listed",
             "personsListedOne: (count: string) => `${count} person listed`,"),
            (Self.presentation, "browser.volume.annotations.people.listed.many", "%@ people listed",
             "personsListedMany: (count: string) => `${count} people listed`,"),
            (Self.presentation, "browser.volume.annotations.terms.listed.one", "%@ term listed",
             "termsListedOne: (count: string) => `${count} term listed`,"),
            (Self.presentation, "browser.volume.annotations.terms.listed.many", "%@ terms listed",
             "termsListedMany: (count: string) => `${count} terms listed`,"),
            (Self.presentation, "browser.volume.annotations.excisions.one", "%@ document with a redaction marked",
             "excisionsOne: (count: string) => `${count} document with a redaction marked`,"),
            (Self.presentation, "browser.volume.annotations.excisions.many", "%@ documents with redactions marked",
             "excisionsMany: (count: string) => `${count} documents with redactions marked`,"),
            (Self.presentation, "browser.volume.annotations.editorialOmissions.one", "%@ document with an editorial omission marked",
             "editorialOmissionsOne: (count: string) => `${count} document with an editorial omission marked`,"),
            (Self.presentation, "browser.volume.annotations.editorialOmissions.many", "%@ documents with editorial omissions marked",
             "editorialOmissionsMany: (count: string) => `${count} documents with editorial omissions marked`,"),
            (Self.presentation, "browser.volume.annotations.editorialNotes.one", "%@ editorial note",
             "editorialNotesOne: (count: string) => `${count} editorial note`,"),
            (Self.presentation, "browser.volume.annotations.editorialNotes.many", "%@ editorial notes",
             "editorialNotesMany: (count: string) => `${count} editorial notes`,"),
            (Self.presentation, "browser.volume.annotations.xrefs.documents.one", "%@ document cites another in this volume",
             "xrefDocumentsOne: (count: string) => `${count} document cites another in this volume`,"),
            (Self.presentation, "browser.volume.annotations.xrefs.documents.many", "%@ documents cite others in this volume",
             "xrefDocumentsMany: (count: string) => `${count} documents cite others in this volume`,"),
            (Self.presentation, "browser.volume.annotations.xrefs.volumes.one", "%@ document cites other volumes",
             "xrefVolumesOne: (count: string) => `${count} document cites other volumes`,"),
            (Self.presentation, "browser.volume.annotations.xrefs.volumes.many", "%@ documents cite other volumes",
             "xrefVolumesMany: (count: string) => `${count} documents cite other volumes`,"),
            (Self.presentation, "browser.volume.annotations.xrefs.pages.one", "%@ document cites printed pages",
             "xrefPagesOne: (count: string) => `${count} document cites printed pages`,"),
            (Self.presentation, "browser.volume.annotations.xrefs.pages.many", "%@ documents cite printed pages",
             "xrefPagesMany: (count: string) => `${count} documents cite printed pages`,"),
            (Self.countCopy, "count.documents.one", "%@ document", "documentsOne: (count: string) => `${count} document`,"),
            (Self.countCopy, "count.documents.many", "%@ documents", "documentsMany: (count: string) => `${count} documents`,"),
            (Self.countCopy, "count.volumes.one", "%@ volume", "volumesOne: (count: string) => `${count} volume`,"),
            (Self.countCopy, "count.volumes.many", "%@ volumes", "volumesMany: (count: string) => `${count} volumes`,"),
            (Self.countCopy, "count.docs.one", "%@ doc", "docsOne: (count: string) => `${count} doc`,"),
            (Self.countCopy, "count.docs.many", "%@ docs", "docsMany: (count: string) => `${count} docs`,"),
            (Self.axis, "browser.annotations.ofVolumes.one", "%2$@ of %1$@ volume",
             "ofVolumesOne: (total: string, count: string) => `${count} of ${total} volume`,"),
            (Self.axis, "browser.annotations.ofVolumes.many", "%2$@ of %1$@ volumes",
             "ofVolumesMany: (total: string, count: string) => `${count} of ${total} volumes`,"),
            (Self.axis, "browser.annotations.era.span", "%1$@–%2$@", "eraSpan: (first: string, last: string) => `${first}–${last}`,"),
            (Self.axis, "browser.annotations.era.from", "%@ on", "eraFrom: (first: string) => `${first} on`,"),
            (Self.axis, "browser.annotations.standard.none", "No era made it standard. It is most common in the volumes covering %@.",
             "standardNone: (era: string) => `No era made it standard. It is most common in the volumes covering ${era}.`,"),
            (Self.axis, "browser.annotations.row.spoken", "%1$@: %2$@.", "layerSpoken: (label: string, volumes: string) => `${label}: ${volumes}.`,"),
            (Self.axis, "browser.annotations.band.spoken", "%1$@: %2$@", "bandSpoken: (era: string, volumes: string) => `${era}: ${volumes}`,"),
            (Self.axis, "browser.annotations.cell.spoken", "%1$@, %2$@", "cellSpoken: (label: string, band: string) => `${label}, ${band}`,"),
            (Self.axis, "browser.annotations.index.caption",
             "What the editors of %@ annotated, layer by layer. A layer that runs through a volume, such as people tagged, counts when it reaches at least half the volume's documents; one found here and there, such as an editorial note, when one document carries it. Each strip shades the eras, earliest first and the late retrospectives last, by the share of their volumes that carry the layer.",
             "indexCaption: (volumes: string) => `What the editors of ${volumes} annotated, layer by layer. A layer that runs through a volume, such as people tagged, counts when it reaches at least half the volume's documents; one found here and there, such as an editorial note, when one document carries it. Each strip shades the eras, earliest first and the late retrospectives last, by the share of their volumes that carry the layer.`,"),
            (Self.axis, "browser.annotations.drill.with.title", "With: %@", "drillWithTitle: (label: string) => `With: ${label}`,"),
            (Self.axis, "browser.annotations.drill.without.title", "Without: %@", "drillWithoutTitle: (label: string) => `Without: ${label}`,"),
            (Self.axis, "browser.annotations.era.drill.title", "%1$@, %2$@", "eraDrillTitle: (label: string, era: string) => `${label}, ${era}`,"),
            (Self.axis, "browser.annotations.drill.caption", "%1$@. %2$@", "drillCaption: (count: string, rule: string) => `${count}. ${rule}`,"),
            (Self.axis, "browser.annotations.accessory.notes.one", "%@ note", "notesOne: (count: string) => `${count} note`,"),
            (Self.axis, "browser.annotations.accessory.notes.many", "%@ notes", "notesMany: (count: string) => `${count} notes`,"),
            (Self.views, "browser.annotations.drill.spoken", "%1$@: %2$@", "drillSpoken: (title: string, volumes: string) => `${title}: ${volumes}`,"),
        ]
        for format in formats {
            let source = format.file.hasPrefix("FRUSCoreKit/") ? try Self.kit(format.file) : try Self.app(format.file)
            #expect(NoteViewParityTests.writes(source, format.key, format.value), "\(format.file) writes \(format.key) as \(format.value)")
            #expect(block.contains(NoteViewParityTests.flattened(format.web)), "copy.annotations holds \(format.web)")
        }
        // The middle dot that joins a row's parts, a code line in the app.
        #expect(try Self.app(Self.presentation).contains(#"static let separator = " · ""#))
        #expect(block.contains("separator: ' · ',"))
        // `CountCopy`'s rule: the one form at exactly one, the count grouped; and where a form takes a
        // second count, the form chosen by the first argument, the total, as `phrase(_:one:many:then:)`.
        let kit = try Self.kit(Self.countCopy)
        NoteViewParityTests.expect(kit, holds: [
            "String(format: count == 1 ? one : many, count.formatted(.number.locale(locale)))",
            "String(format: count == 1 ? one : many, arguments: [count.formatted(.number.locale(locale))] + arguments)",
        ], file: "CountCopy.swift")
        NoteViewParityTests.expect(try Self.app(Self.presentation), holds: [
            "CountCopy.phrase(annotations.documents,", "then: [count.formatted(.number.locale(locale))], locale: locale)",
        ], file: "VolumeAnnotationsPresentation.swift")
        NoteViewParityTests.expect(try Self.web("browse/annotationRules.ts"), holds: [
            "const grouped = count.toLocaleString('en-US'); return count === 1 ? one(grouped) : many(grouped);",
            "const grouped = total.toLocaleString('en-US'); return total === 1 ? one(grouped, count.toLocaleString('en-US')) : many(grouped, count.toLocaleString('en-US'));",
        ], file: "annotationRules.ts")
    }

    /// The printed aids, in the order the app's page names them, each kind with its name: the
    /// server's `PrintedAid.all`, an aid known by its first kind and holding the kinds the app names
    /// alike, and copy.ts's names, by that kind.
    @Test func thePrintedAidsAreTheApps() throws {
        let source = try Self.app(Self.presentation)
        let pattern = try Regex(#"\("([a-z-]+)", String\(localized: "browser\.volume\.annotations\.aid\.(\w+)", defaultValue: "([^"]+)"\)\)"#)
        var aids: [(name: String, kinds: [String])] = []
        for match in source.matches(of: pattern) {
            let kind = String(try #require(match.output[1].substring))
            let name = String(try #require(match.output[3].substring))
            if let at = aids.firstIndex(where: { $0.name == name }) { aids[at].kinds.append(kind) } else { aids.append((name, [kind])) }
        }
        #expect(aids.count == 12 && aids.flatMap(\.kinds).count == 13, "the app's table names 13 kinds as 12 aids")
        #expect(PrintedAid.all.map(\.id) == aids.compactMap(\.kinds.first))
        #expect(PrintedAid.all.map(\.kinds) == aids.map(\.kinds))
        let block = try Self.nested("aids", in: try NoteViewParityTests.block("annotations", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")))
        for aid in aids {
            let id = try #require(aid.kinds.first)
            #expect(Self.holds(block, id, aid.name) || Self.holds(block, "'\(id)'", aid.name), "copy.annotations.aids['\(id)'] is \(aid.name)")
        }
        // An aid is one per name, and its drill is known by its first kind, as the app's are.
        NoteViewParityTests.expect(try Self.app(Self.axis), holds: [
            "if let at = kindsByName.firstIndex(where: { $0.name == name }) { kindsByName[at].kinds.append(kind) } else { kindsByName.append((name, [kind])) }",
            "guard !ids.isEmpty, let first = aid.kinds.first else { return nil }",
            "return Drill(id: first, title: aid.name, count: ids.count,",
        ], file: "AnnotationsAxis.swift")
        NoteViewParityTests.expect(source, holds: [
            "for (kind, name) in printedAidNames where sections.contains(kind) && !names.contains(name) {",
        ], file: "VolumeAnnotationsPresentation.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/Annotations.swift"), holds: [
            "all.filter { aid in aid.kinds.contains { sections.contains($0) } }.map(\\.id)",
            "guard !ids.isEmpty else { return nil } return Drill(id: aid.id, volumeIds: ids, rule: .aid)",
        ], file: "Annotations.swift")
    }

    /// The table of layers: the app's sixteen, in its order, as the server's `AnnotationLayer` and the
    /// browser app's `annotationLayers` list them.
    @Test func theLayersAreTheAppsInItsOrder() throws {
        let source = try NoteViewParityTests.read(NoteViewParityTests.app, Self.axis)
        let start = try #require(source.range(of: "enum AnnotationLayer: String"))
        let end = try #require(source.range(of: "var id: String", range: start.upperBound..<source.endIndex))
        let cases = String(source[start.upperBound..<end.lowerBound]).matches(of: try Regex(#"(?m)^\s*case (\w+)$"#)).compactMap {
            $0.output[1].substring.map(String.init)
        }
        #expect(cases.count == 16)
        #expect(AnnotationLayer.allCases.map(\.rawValue) == cases)
        let web = try NoteViewParityTests.read(NoteViewParityTests.web, "api/annotations.ts")
        let listStart = try #require(web.range(of: "export const annotationLayers = ["))
        let listEnd = try #require(web.range(of: "] as const;", range: listStart.upperBound..<web.endIndex))
        let listed = String(web[listStart.upperBound..<listEnd.lowerBound]).matches(of: try Regex("'(\\w+)'")).compactMap {
            $0.output[1].substring.map(String.init)
        }
        #expect(listed == cases)
    }

    /// The server's mirrors of the app's view code, each held by the line the app's source writes it in
    /// and the server's line that mirrors it, the same text where the server's line says the same thing.
    @Test func theServersMirrorsAreTheApps() throws {
        let app = try Self.app(Self.axis)
        let presentation = try Self.app(Self.presentation)
        let server = try Self.server("Sources/FRUSLightAPI/Annotations.swift")
        // The same lines in both: the table, the reach, the order, the drills, the counts and the marks.
        let same = [
            // `AnnotationLayer.family`
            "case .people, .abbreviations, .correspondents, .subjects, .participants: return .named",
            "case .sourceNotes, .classification, .excisions, .editorialOmissions, .despatch: return .provenance",
            "case .numbered, .crossReferences, .editorialNotes, .footnotes, .marginalNotes, .printedAids: return .connects",
            // `category`
            "case .people: return .people case .abbreviations: return .abbreviations case .correspondents: return .correspondents",
            "case .subjects: return .subjects case .participants: return .participants case .classification: return .classification",
            "case .excisions: return .excisions case .editorialOmissions: return .editorialOmissions case .despatch: return .despatch case .numbered: return .numbered",
            "case .editorialNotes: return .editorialNotes case .footnotes: return .footnotes case .marginalNotes: return .marginalNotes",
            "case .sourceNotes, .crossReferences, .printedAids: return nil",
            // `isCarried(by:)` and `count(in:)`
            "case .sourceNotes: return annotations.carriesSourceNotes",
            "case .crossReferences: return annotations.carries(.xrefDocuments) || annotations.carries(.xrefVolumes) || annotations.carries(.xrefPages)",
            "default: return category.map(annotations.carries) ?? false",
            "case .sourceNotes: return annotations.sourceNotes case .crossReferences, .printedAids: return nil default: return category.map(annotations.count)",
            // `AnnotationsAxis.reach(of:in:)` and `order(_:)`
            "static var stripEras: [AnnotationEra] { AnnotationEra.chronological + [.retrospective] }",
            "let carries = layer.isCarried(by: annotations) if carries { carrying.append(volumeId) } var tally = perEra[annotations.era] ?? (0, 0) tally.total += 1 if carries { tally.carrying += 1 } perEra[annotations.era] = tally",
            "Band(era: era, carrying: perEra[era]?.carrying ?? 0, total: perEra[era]?.total ?? 0)",
            "return Reach(layer: layer, carrying: order(carrying), total: index.volumes.count, bands: bands, onset: index.onset(where: layer.isCarried(by:)))",
            "volumeIds.sorted { $0.localizedStandardCompare($1) == .orderedAscending }",
            // Ties to the earlier band.
            "reach.bands.filter({ $0.carrying > 0 }).max(by: { $0.share < $1.share })",
            // `drills(for:in:from:locale:)`
            "let with = Set(reach.carrying) let without = order(index.volumes.keys.filter { !with.contains($0) })",
            #"Drill(id: "with","#, #"Drill(id: "without","#, "if layer == .sourceNotes {",
            #"("citation", .sourceCitation"#, #"("fileNumber", .sourceFileNumber"#,
            "let ids = order(index.volumeIds { $0.carries(form.category) })",
            "let ids = order(index.volumeIds { annotations in aid.kinds.contains { annotations.prints(section: $0) } })",
            // `eraDrill(for:era:in:locale:)`
            "let members = index.volumes.filter { $0.value.era == era } let ids = order(members.filter { layer.isCarried(by: $0.value) }.map(\\.key))",
            "Band(era: era, carrying: ids.count, total: members.count)",
            // `spec`: the volume a page came from first.
            "if let fromVolumeId, let at = volumeIds.firstIndex(of: fromVolumeId) { volumeIds.insert(volumeIds.remove(at: at), at: 0) }",
            // `accessory(for:_:category:locale:)`
            "let count = category.map(annotations.count) ?? layer.count(in: annotations) guard let count, count > 0 else { return nil }",
            "case .people, .abbreviations, .correspondents, .sourceNotes, .classification, .despatch, .numbered, .footnotes:",
            "case .subjects, .participants, .excisions, .editorialOmissions, .marginalNotes:",
            // `gateNote(for:_:)`: the 1925 gate's mark, by the kit's `publishedBeforeEditorialOmissionsOrder`
            "guard layer == .editorialOmissions, annotations.publishedBeforeEditorialOmissionsOrder else { return nil }",
            // `unlinkedList(for:_:)`
            "case .people where annotations.count(.people) == 0 && annotations.personsListed > 0:",
            "case .abbreviations where annotations.count(.abbreviations) == 0 && annotations.termsListed > 0:",
            // `eraName(_:)`'s reading of a raw value
            #"let parts = era.rawValue.split(separator: "-", omittingEmptySubsequences: false)"#,
        ]
        NoteViewParityTests.expect(app, holds: same, file: "AnnotationsAxis.swift")
        NoteViewParityTests.expect(server, holds: same, file: "Annotations.swift")
        // The same lines in both, from the page's presentation.
        let samePage = [
            "for layer in AnnotationLayer.allCases where layer.isCarried(by: annotations) {",
            "].filter { !$0.rows.isEmpty }",
            "absent = standard.filter { !$0.carried }.map { layer in",
            "let line = of(annotations.count(category)) guard let listed else { return line }",
            "case .people: return coverage(.people, listed: personsListed) case .abbreviations: return coverage(.abbreviations, listed: termsListed)",
            "case .correspondents: return documents(.correspondents) case .subjects: return documents(.subjects) case .participants: return documents(.participants)",
            "case .sourceNotes: return sourceNotes case .classification: return coverage(.classification) case .excisions: return excisions",
            "case .editorialOmissions: return editorialOmissions case .despatch: return documents(.despatch) case .numbered: return coverage(.numbered)",
            "case .editorialNotes: return editorialNotes case .footnotes: return coverage(.footnotes) case .marginalNotes: return documents(.marginalNotes)",
            "guard annotations.personsListed > 0 else { return nil }", "guard annotations.termsListed > 0 else { return nil }",
            "let citations = annotations.count(.sourceCitation) > 0 let fileNumbers = annotations.count(.sourceFileNumber) > 0",
            "switch (citations, fileNumbers) { case (true, false):",
            "if annotations.carries(.xrefDocuments) {", "if annotations.carries(.xrefVolumes) {", "if annotations.carries(.xrefPages) {",
        ]
        NoteViewParityTests.expect(presentation, holds: samePage, file: "VolumeAnnotationsPresentation.swift")
        NoteViewParityTests.expect(server, holds: samePage, file: "Annotations.swift")
        // The groups, in the page's order; the standard layers, each with the layer it opens and its onset.
        NoteViewParityTests.expect(presentation, holds: [
            "Group(id: .named, title: Labels.named, rows: rows[.named] ?? []), Group(id: .provenance, title: Labels.provenance, rows: rows[.provenance] ?? []), Group(id: .connects, title: Labels.connects, rows: rows[.connects] ?? []),",
            #"("people", Labels.people, .people, annotations.carries(.people), { index.onset(of: .people) }),"#,
            #"("abbreviations", Labels.abbreviations, .abbreviations, annotations.carries(.abbreviations), { index.onset(of: .abbreviations) }),"#,
            #"("sourceNotes", Labels.sourceNotes, .sourceNotes, annotations.carriesSourceNotes, { index.onset(where: \.carriesSourceNotes) }),"#,
            #"("classification", Labels.classification, .classification, annotations.carries(.classification), { index.onset(of: .classification) }),"#,
            #"("numbered", Labels.numbered, .numbered, annotations.carries(.numbered), { index.onset(of: .numbered) }),"#,
            #"("referencesToDocuments", Labels.referencesToDocuments, .crossReferences, annotations.carries(.xrefDocuments), { index.onset(of: .xrefDocuments) }),"#,
            #"("editorialNotes", Labels.editorialNotes, .editorialNotes, annotations.carries(.editorialNotes), { index.onset(of: .editorialNotes) }),"#,
            #"("noteOnSources", Labels.noteOnSources, .printedAids, annotations.prints(section: "sources"), { index.onset { $0.prints(section: "sources") } }),"#,
            // What the server leaves to the browser app's words.
            "return line + VolumeAnnotationsPresentation.separator + listed",
            "return of(annotations.sourceNotes) + VolumeAnnotationsPresentation.separator + form",
            #"case .crossReferences: return crossReferences ?? """#,
        ], file: "VolumeAnnotationsPresentation.swift")
        NoteViewParityTests.expect(server, holds: [
            "Group(family: AnnotationCategory.Family.named.rawValue, rows: rows[.named] ?? []), Group(family: AnnotationCategory.Family.provenance.rawValue, rows: rows[.provenance] ?? []), Group(family: AnnotationCategory.Family.connects.rawValue, rows: rows[.connects] ?? []),",
            #"("people", .people, annotations.carries(.people), { index.onset(of: .people) }),"#,
            #"("abbreviations", .abbreviations, annotations.carries(.abbreviations), { index.onset(of: .abbreviations) }),"#,
            #"("sourceNotes", .sourceNotes, annotations.carriesSourceNotes, { index.onset(where: \.carriesSourceNotes) }),"#,
            #"("classification", .classification, annotations.carries(.classification), { index.onset(of: .classification) }),"#,
            #"("numbered", .numbered, annotations.carries(.numbered), { index.onset(of: .numbered) }),"#,
            #"("referencesToDocuments", .crossReferences, annotations.carries(.xrefDocuments), { index.onset(of: .xrefDocuments) }),"#,
            #"("editorialNotes", .editorialNotes, annotations.carries(.editorialNotes), { index.onset(of: .editorialNotes) }),"#,
            #"("noteOnSources", .printedAids, annotations.prints(section: "sources"), { index.onset { $0.prints(section: "sources") } }),"#,
            "return line + [listed]",
            #"return of(annotations.sourceNotes) + [Part(kind: "sourceForm", form: form)]"#,
            "case .crossReferences: return crossReferences ?? []",
        ], file: "Annotations.swift")
        // The app's lines whose mirror differs in what it names: the aids' table, the source-form
        // drills' count, the drill list's marks, and when a layer with no onset names its peak.
        NoteViewParityTests.expect(app, holds: [
            "case .printedAids: return !VolumeAnnotationsPresentation.printedAids(in: annotations.sections).isEmpty",
            "if layer == .printedAids { return aidDrills(in: index, from: fromVolumeId, locale: locale) }",
            "accessoryCategory: form.category)))",
            "if let unlinked = unlinkedList(for: layer, annotations) { lines.append(unlinked) } if let gated = gateNote(for: layer, annotations) { lines.append(gated) } if volumeId == fromVolumeId {",
            "if reach.onset != nil { return VolumeAnnotationsPresentation.standardFrom(reach.onset) }",
            "volumeIds: ids, rule: layer.rule, layer: layer, index: index, from: nil,",
        ], file: "AnnotationsAxis.swift")
        NoteViewParityTests.expect(server, holds: [
            "case .printedAids: return !PrintedAid.printed(in: annotations.sections).isEmpty",
            "if layer == .printedAids { return aidDrills(in: index) }",
            "rule: .sourceForm, accessoryCategory: form.category))",
            "unlinked: annotations.flatMap { AnnotationsAxis.unlinkedList(for: layer, $0) }, gated: annotations.flatMap { AnnotationsAxis.gateNote(for: layer, $0) }, from: volumeId == fromVolumeId ? true : nil)",
            "guard reach.onset == nil else { return nil }",
            #"return AnnotationDrill(layer: layer, drill: "era", era: era, rule: .layer, volumeIds: cell.volumeIds, total: cell.band.total, index: data.index, from: nil)"#,
        ], file: "Annotations.swift")
    }

    /// The browser app's mirrors of the app's view code, each held by the lines the app's source writes
    /// it in and the lines of annotationRules.ts and the screens that mirror them.
    @Test func theWebsMirrorsAreTheApps() throws {
        NoteViewParityTests.expect(try Self.app(Self.presentation), holds: [
            // A row's spoken label, and an absent row's.
            #"label, detail.replacingOccurrences(of: VolumeAnnotationsPresentation.separator, with: "; "))"#,
            #"return note.isEmpty ? lead : lead + " " + note"#,
            // The people hint after the onset.
            #"if layer.id == "people" {"#, #"note = note.isEmpty ? hint : note + " " + hint"#,
            // A year goes in through `String(_:)`.
            #"guard let year = era?.firstYear else { return "" }"#, "String(year))",
            // The disclosure's count, grouped.
            "absent.count.formatted())",
        ], file: "VolumeAnnotationsPresentation.swift")
        NoteViewParityTests.expect(try Self.app(Self.axis), holds: [
            // An era's names.
            "guard let first = era.firstYear else {", "if parts.count == 2, let last = Int(parts[1]) {",
            #"String(localized: "browser.annotations.era.span", defaultValue: "%1$@–%2$@"), String(first), String(last))"#,
            "return String(first)",
            // When a layer became standard, Redactions' sentence before any era's, and the row and band read aloud.
            "if reach.layer == .excisions { return redactionsStandardLine }",
            "if peak.era == .retrospective {",
            #"return standard.isEmpty ? lead : lead + " " + standard"#,
            "let name = band.era == .retrospective",
            // A list's caption, its count of the file's volumes, and its marks joined.
            "volumesLine(volumeIds.count, of: index.volumes.count, locale: locale), rule)",
            "spokenBand(band, locale: locale), layer.rule)",
            #"if !lines.isEmpty { notes[volumeId] = lines.joined(separator: " ") }"#,
            // A volume's count in a list.
            #"return count.formatted(.number.locale(locale)) + "/" + annotations.documents.formatted(.number.locale(locale))"#,
        ], file: "AnnotationsAxis.swift")
        NoteViewParityTests.expect(try Self.app(Self.views), holds: [
            // The strip's shade, and the matrix's empty cell, drawn and read but disabled.
            "band.carrying == 0 ? .clear : Color.accentColor.opacity(0.15 + 0.85 * band.share)",
            ".disabled(band.carrying == 0)",
            // A drill's row reads its title and how many volumes it lists.
            "drill.title, CountCopy.volumes(drill.count)))",
        ], file: "AnnotationsAxisViews.swift")
        NoteViewParityTests.expect(try Self.web("browse/annotationRules.ts"), holds: [
            "return words.rowSpoken(layerLabel(layer), rowDetail(parts).replaceAll(words.separator, '; '));",
            "return note === '' ? lead : `${lead} ${note}`;",
            "if (row.id === 'people') note = note === '' ? words.peopleHint : `${note} ${words.peopleHint}`;",
            "if (era?.firstYear === undefined) return ''; return words.standardFrom(String(era.firstYear));",
            "return words.absentTitle(count.toLocaleString('en-US'));",
            "if (era.firstYear === undefined) return words.eraRetrospective;",
            "if (era.lastYear !== undefined) return words.eraSpan(String(era.firstYear), String(era.lastYear));",
            "return words.eraFrom(String(era.firstYear));",
            "return era.firstYear === undefined ? words.eraRetrospectiveShort : String(era.firstYear);",
            "if (reach.layer === 'excisions') return words.standardRedactions; if (reach.onset) return standardFrom(reach.onset);",
            "if (reach.peak.firstYear === undefined) return words.standardNoneRetrospective;",
            "return standard === '' ? lead : `${lead} ${standard}`;",
            "const name = era.firstYear === undefined ? words.eraRetrospectiveTitle : eraName(era);",
            "const count = drill.era ? spokenBand(drill.era, { carrying: drill.count, total: drill.total }) : volumesLine(drill.count, drill.total);",
            "if (volume.gated === 'before1925') lines.push(words.noteBefore1925); if (volume.from) lines.push(words.noteFrom); return lines.join(' ');",
            "if (accessory.kind === 'ratio') return `${accessory.count.toLocaleString('en-US')}/${accessory.of.toLocaleString('en-US')}`;",
            "return `${Math.round((0.15 + 0.85 * share) * 100)}%`;",
            "return words.drillSpoken(drillRowTitle(drill), counted(count, words.volumesOne, words.volumesMany));",
        ], file: "annotationRules.ts")
        NoteViewParityTests.expect(try Self.web("browse/AnnotationsScreen.tsx"), holds: [
            "{band.carrying === 0 ? (",
            #"<a className="era-cell" role="link" aria-disabled="true" aria-label={spoken} title={spoken} />"#,
        ], file: "AnnotationsScreen.tsx")
    }
}
