// The People screen and the curators' corrections (PLAN's S21g), held to the app's source at the pin. The rules
// the app's views apply over the kit's rollup, `PersonIndexRow.subtitle`, `PersonIndexSection.makeSections`,
// `PersonLifespan.text(born:died:)`, the sheet's register role and Mentions, mirrored in `PeopleRules` (People.swift),
// each where the app writes it; the corrections' sequence, the kit's calls the app's stores make; and the words the
// browser app takes, each where the app's source writes it under its key and in copy.ts's block, "syncs across your
// devices" the web's "for everyone on this server". A pin move that changes one fails here until the web follows it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct PeopleParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func kit(_ path: String) throws -> String { try SearchSetParityTests.kit(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }

    /// The rules the server mirrors, where the app's source writes them, and run over entries of each shape.
    @Test func theListsAndTheSheetsRulesAreTheApps() throws {
        let view = try Self.app("Browser/PersonIndexView.swift")
        NoteViewParityTests.expect(view, holds: [
            // PersonIndexRow.subtitle
            "if let roleEra = indexEntry.entry.roleEraSubtitle { parts.append(roleEra) }",
            "if indexEntry.volumeCount > 1 {",
            #"parts.append(String(localized: "people.row.volumeCount", defaultValue: "\(indexEntry.volumeCount) volumes"))"#,
            #"return parts.isEmpty ? nil : parts.joined(separator: " · ")"#,
            // PersonIndexSection.makeSections
            ##"let letter = e.entry.name.isEmpty ? "#" : String(e.entry.name.prefix(1).uppercased())"##,
            "return dict.keys.sorted().map { PersonIndexSection(letter: $0, entries: dict[$0]!) }",
            // The sheet: the register's role where it adds to the description; Mentions; Active; the VIAF link.
            #"&& role.caseInsensitiveCompare(indexEntry.entry.description ?? "") != .orderedSame"#,
            #"Text("\(displayCount) document\(displayCount == 1 ? "" : "s")")"#,
            "if let era = indexEntry.entry.eraText {",
            #"URL(string: "https://viaf.org/viaf/\(viaf)")"#,
            "if let url = authorityEntry?.wikidataURL {",
            // The merge's anchors: each identity's representative record.
            "let mine = try? await store.representativeMember(forRollupId: myRollup)",
            "let theirs = try? await store.representativeMember(forRollupId: otherRollupId)",
            "if members.count > 1 {",
        ], file: "PersonIndexView.swift")
        // PersonLifespan.text(born:died:), each year never grouped: the kit's since FRUS-Explorer#1906, which moved it
        // unchanged from the view's file into Models/POCOMIndex.swift.
        NoteViewParityTests.expect(try Self.kit("FRUSCoreKit/Models/POCOMIndex.swift"), holds: [
            #"defaultValue: "\(born, format: plain)–\(died, format: plain)")"#,
            #"defaultValue: "Born \(born, format: plain)")"#,
            #"defaultValue: "Died \(died, format: plain)")"#,
            "(authority?.b ?? career?.b, authority?.d ?? career?.d)",
        ], file: "POCOMIndex.swift")

        func entry(_ name: String, role: String? = nil, start: Int? = nil, end: Int? = nil, volumes: Int = 1) -> PersonIndexEntry {
            PersonIndexEntry(entry: PersonEntry(ref: "p_X", name: name, description: role, role: role, startYear: start, endYear: end),
                             mentionCount: 3, rollupId: 1, volumeCount: volumes)
        }
        #expect(PeopleRules.subtitle(entry("A", role: "Ambassador", start: 1961, end: 1963, volumes: 2)) == "Ambassador · 1961–1963 · 2 volumes")
        #expect(PeopleRules.subtitle(entry("A", start: 1953)) == "1953")
        #expect(PeopleRules.subtitle(entry("A", volumes: 3)) == "3 volumes")
        #expect(PeopleRules.subtitle(entry("A")) == nil)
        #expect(PeopleRules.letter(of: "adenauer") == "A" && PeopleRules.letter(of: "") == "#")
        #expect(PeopleRules.sections([entry("Bundy"), entry("Acheson"), entry("Ball"), entry("")]).map(\.letter) == ["#", "A", "B"])
        #expect(PeopleRules.sections([entry("Bundy"), entry("Ball")]).first?.entries.map(\.entry.name) == ["Bundy", "Ball"], "the store's order")
        #expect(PeopleRules.lifespan(born: 1893, died: 1971) == "1893–1971")
        #expect(PeopleRules.lifespan(born: 1893, died: nil) == "Born 1893" && PeopleRules.lifespan(born: nil, died: 1971) == "Died 1971")
        #expect(PeopleRules.lifespan(born: nil, died: nil) == nil)
        // And as the kit's rule answers, public since FRUS-Explorer#1906.
        for (born, died) in [(1893, 1971), (1893, nil), (nil, 1971), (nil, nil)] as [(Int?, Int?)] {
            #expect(PeopleRules.lifespan(born: born, died: died) == PersonLifespan.text(born: born, died: died))
        }
        #expect(PeopleRules.registerRole("Ambassador", description: "ambassador") == nil && PeopleRules.registerRole("Ambassador", description: nil) == "Ambassador")
        #expect(PeopleRules.mentions(1) == "1 document" && PeopleRules.mentions(12) == "12 documents")
    }

    /// The corrections' calls, the app's stores' over the kit's, and the server's over the same calls.
    @Test func theCorrectionsCallTheKitAsTheAppsStoresCallIt() throws {
        let persons = try Self.app("Models/PersonClusterOverrideStore.swift")
        let classification = try Self.app("Models/DocumentClassificationOverride.swift")
        let rail = try Self.app("DocumentView/ResearchRailView.swift")
        NoteViewParityTests.expect(persons, holds: [
            "guard a.volumeId != b.volumeId || a.ref != b.ref else { return nil }",
            "(o.volumeIdA == a.volumeId && o.refA == a.ref && o.volumeIdB == b.volumeId && o.refB == b.ref) ||",
            "(o.volumeIdA == b.volumeId && o.refA == b.ref && o.volumeIdB == a.volumeId && o.refB == a.ref)",
            "$0.overrideKind == .split && $0.volumeIdA == member.volumeId && $0.refA == member.ref",
            "try? await pipeline.consolidatePersonRollup(overrides: overrides, forceReload: false)",
            "sortBy: [SortDescriptor(\\.createdAt, order: .reverse)])",
        ], file: "PersonClusterOverrideStore.swift")
        NoteViewParityTests.expect(classification, holds: [
            "isEditorialNote: restore.parsedIsEditorialNote,",
            "try? await pipeline.applyClassificationOverrides([restoreEntry], volumeId: restore.volumeId)",
            "try? await pipeline.applyClassificationOverrides(snapshot(context: context))",
            "fetchAll(context: context).reversed().map(\\.snapshot)",
        ], file: "DocumentClassificationOverride.swift")
        NoteViewParityTests.expect(rail, holds: [
            "isEditorialNote: !effective,",
            "parsedIsEditorialNote: displayedParsedIsEditorialNote ?? effective,",
            "parsedIsEditorialNote: displayedParsedIsEditorialNote ?? override.parsedIsEditorialNote)",
        ], file: "ResearchRailView.swift")
        let kit = try Self.kit("FRUSCoreKit/TEI/FRUSASTNode.swift")
        #expect(kit.contains("public var isShapedAsEditorialNote: Bool {"), "the rule the indexer applies, which a restore reads")
        // The server's: the same calls, each where the server writes it (the order is `IndexCorrections.apply`'s, read there).
        let corrections = try Self.server("Sources/FRUSLightCore/IndexCorrections.swift")
        NoteViewParityTests.expect(corrections, holds: [
            "isEditorialNote: value, parsedIsEditorialNote: value)], volumeId: document.volumeId)",
            "try await pipeline.applyClassificationOverrides(classification)",
            "try await pipeline.consolidatePersonRollup(overrides: person, forceReload: false)",
            "return ast.isShapedAsEditorialNote",
            "await pipeline.runPostIndexPasses(overrides: person)",
        ], file: "IndexCorrections.swift")
        let store = try Self.server("Sources/FRUSLightCore/UserCorrections.swift")
        NoteViewParityTests.expect(store, holds: [
            "(o.volumeIdA == a.volumeId && o.refA == a.ref && o.volumeIdB == b.volumeId && o.refB == b.ref)",
            "|| (o.volumeIdA == b.volumeId && o.refA == b.ref && o.volumeIdB == a.volumeId && o.refB == a.ref))",
            "$0.kind == .split && $0.volumeIdA == member.volumeId && $0.refA == member.ref",
            "FROM person_overrides ORDER BY created_at DESC NULLS LAST, rowid DESC",
        ], file: "UserCorrections.swift")
        let routes = try Self.server("Sources/FRUSLightAPI/Corrections.swift")
        NoteViewParityTests.expect(routes, holds: [
            "guard let mine = try await served.persons.representativeMember(forRollupId: body.rollupId),",
            "let theirs = try await served.persons.representativeMember(forRollupId: body.otherRollupId) else {",
            "let parsed = await parse(document, reader: reader) ?? effective",
            "let parsed = await parse(document, reader: reader) ?? kept.parsedIsEditorialNote",
        ], file: "Corrections.swift")
    }

    /// The words the browser app takes, where the app's source writes each under its key, and in copy.ts's block.
    @Test func theWebsWordsAreTheApps() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let people = try NoteViewParityTests.block("people", of: raw)
        let classification = try NoteViewParityTests.block("classification", of: raw)
        let view = try Self.app("Browser/PersonIndexView.swift")
        let corrections = try Self.app("Browser/PersonCorrectionsView.swift")
        let rail = try Self.app("DocumentView/ResearchRailView.swift")
        let tagging = try Self.app("Browser/AnnotationsAxisViews.swift")
        let words: [(source: String, key: String, value: String, block: String, web: String)] = [
            (view, "people.title", "People", people, "title: 'People'"),
            (view, "people.loading", "Loading people\\u{2026}", people, "loading: 'Loading people…'"),
            (view, "people.empty.title", "No People Indexed", people, "emptyTitle: 'No People Indexed'"),
            (view, "people.search.prompt", "Search people", people, "searchPrompt: 'Search people'"),
            (view, "people.corrections.toolbar", "Corrections", people, "corrections: 'Corrections'"),
            (view, "people.row.candidate.a11y", "Possible duplicate", people, "possibleDuplicate: 'Possible duplicate'"),
            (view, "people.row.candidate.help", "May be the same as another person — open to review", people,
             "candidateHelp: 'May be the same as another person — open to review'"),
            (view, "people.detail.reconciled", "Reconciled identity", people, "reconciled: 'Reconciled identity'"),
            (view, "people.detail.reconciled.help", "Matched to the bundled name-authority data", people,
             "reconciledHelp: 'Matched to the bundled name-authority data'"),
            (view, "people.detail.mentions", "Mentions", people, "mentions: 'Mentions'"),
            (view, "people.detail.active", "Active", people, "active: 'Active'"),
            (view, "people.detail.findMentions", "Find all mentions", people, "findMentions: 'Find all mentions'"),
            (view, "people.detail.findMentions.help", "Open Search filtered to documents that mention this person", people,
             "findMentionsHelp: 'Open Search filtered to documents that mention this person'"),
            (view, "people.detail.findMentions.noMentions",
             "This person has no indexed document mentions to open — they appear only in a volume’s front-matter person list.", people,
             "noMentions: 'This person has no indexed document mentions to open — they appear only in a volume’s front-matter person list.'"),
            (view, "people.detail.viaf", "View on VIAF", people, "viaf: 'View on VIAF'"),
            (view, "people.detail.viaf.help", "Open this person’s VIAF authority record", people, "viafHelp: 'Open this person’s VIAF authority record'"),
            (view, "people.detail.wikidata", "View on Wikidata", people, "wikidata: 'View on Wikidata'"),
            (view, "people.detail.wikidata.help", "Open this person’s Wikidata item", people, "wikidataHelp: 'Open this person’s Wikidata item'"),
            (view, "people.detail.mergeManual", "Merge with another person…", people, "mergeManual: 'Merge with another person…'"),
            (view, "people.detail.mergeManual.help", "Combine this identity with another person you choose", people,
             "mergeManualHelp: 'Combine this identity with another person you choose'"),
            (view, "people.detail.possiblySame.header", "Possibly the Same Person", people, "possiblySameHeader: 'Possibly the Same Person'"),
            (view, "people.detail.merge", "Merge", people, "merge: 'Merge'"),
            (view, "people.detail.records.footer", "Separate a record if it refers to a different person.", people,
             "recordsFooter: 'Separate a record if it refers to a different person.'"),
            (view, "people.detail.separate", "Separate", people, "separate: 'Separate'"),
            (view, "people.detail.mergeConfirm.title", "Merge these identities?", people, "mergeConfirmTitle: 'Merge these identities?'"),
            (view, "people.detail.mergeConfirm.action", "Merge", people, "mergeConfirmAction: 'Merge'"),
            (view, "people.detail.mergeConfirm.authorityWarning",
             "These records match different entries in the bundled name-authority data, so they may be distinct. Merge only if you’re sure.", people,
             "mergeAuthorityWarning: 'These records match different entries in the bundled name-authority data, so they may be distinct. Merge only if you’re sure.'"),
            (view, "people.detail.correction.inProgress", "Applying correction…", people, "inProgress: 'Applying correction…'"),
            (tagging, "people.tagging.link", "Volumes that tag people", people, "taggingLink: 'Volumes that tag people'"),
            (corrections, "people.mergePicker.title", "Merge With…", people, "pickerTitle: 'Merge With…'"),
            (corrections, "people.mergePicker.row.hint", "Merges this person into the current identity", people,
             "pickerHint: 'Merges this person into the current identity'"),
            (corrections, "people.corrections.title", "Corrections", people, "correctionsTitle: 'Corrections'"),
            (corrections, "people.corrections.empty.title", "No Corrections", people, "correctionsEmptyTitle: 'No Corrections'"),
            (corrections, "people.corrections.undo", "Undo", people, "undo: 'Undo'"),
            (corrections, "people.corrections.undo.inProgress", "Undoing correction…", people, "undoInProgress: 'Undoing correction…'"),
            (corrections, "people.corrections.undo.done", "Correction undone", people, "undoDone: 'Correction undone'"),
            (rail, "panel.classification.title", "Classification", classification, "title: 'Classification'"),
            (rail, "panel.classification.note", "Editorial note", classification, "note: 'Editorial note'"),
            (rail, "panel.classification.document", "Document", classification, "document: 'Document'"),
            (rail, "panel.classification.restore", "Restore FRUS’s Classification", classification, "restore: 'Restore FRUS’s Classification'"),
            (rail, "panel.classification.toDocument", "Reclassify as Document…", classification, "toDocument: 'Reclassify as Document…'"),
            (rail, "panel.classification.toNote", "Reclassify as Editorial Note…", classification, "toNote: 'Reclassify as Editorial Note…'"),
            (rail, "panel.classification.note.inline", "an editorial note", classification, "noteInline: 'an editorial note'"),
            (rail, "panel.classification.document.inline", "a document", classification, "documentInline: 'a document'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "the app writes \(word.key) as \(word.value)")
            #expect(word.block.contains(NoteViewParityTests.flattened(word.web)), "copy.ts holds \(word.web)")
        }
        // The app's sentences with a value, as copy.ts's functions say them.
        let formats: [(source: String, app: String, block: String, web: String)] = [
            (view, #"defaultValue: "%lld mentions"), Int64(indexEntry.mentionCount))"#, people, "mentionCountSpoken: (count: number) => `${count} mentions`"),
            (view, #"defaultValue: "Merge %@ into this person"), candidate.name))"#, people, "mergeSpoken: (name: string) => `Merge ${name} into this person`"),
            (view, #"defaultValue: "Records in This Identity (\(members.count))"))"#, people,
             "recordsHeader: (count: number) => `Records in This Identity (${count})`"),
            (view, #"defaultValue: "Separate %@ into its own identity"), member.entry.name))"#, people,
             "separateSpoken: (name: string) => `Separate ${name} into its own identity`"),
            (view, #"defaultValue: "Merged %1$@ into %2$@"), otherName, indexEntry.entry.name)"#, people, "mergeDone: (a: string, b: string) => `Merged ${a} into ${b}`"),
            (view, #"defaultValue: "Separated %@"), member.entry.name)"#, people, "separateDone: (name: string) => `Separated ${name}`"),
            (view, #"defaultValue: "“%1$@” and “%2$@” will become a single identity. Merging is transitive — if you later merge a third record with either one, all three become one identity. You can undo this from Corrections."), target.entry.name, indexEntry.entry.name)"#,
             people, "`“${a}” and “${b}” will become a single identity. Merging is transitive — if you later merge a third record with either one, all three become one identity. You can undo this from Corrections.`"),
            (corrections, #"defaultValue: "%1$@ and %2$@ — merged"), nameA, nameB)"#, people, "correctionMerged: (a: string, b: string) => `${a} and ${b} — merged`"),
            (corrections, #"defaultValue: "%@ — separated"), nameA)"#, people, "correctionSeparated: (a: string) => `${a} — separated`"),
            (corrections, #"defaultValue: "Undo: %@"), row.title))"#, people, "undoSpoken: (title: string) => `Undo: ${title}`"),
            (view, #"defaultValue: "People are tagged in %@, and only those volumes' people appear here. In the others, search for the names.")"#,
             people, "`People are tagged in ${volumes}, and only those volumes' people appear here. In the others, search for the names.`"),
        ]
        for format in formats {
            let source = format.app.contains("People are tagged") ? tagging : format.source
            #expect(source.contains(NoteViewParityTests.flattened(format.app)), "the app holds \(format.app.prefix(50))")
            #expect(format.block.contains(NoteViewParityTests.flattened(format.web)), "copy.ts holds \(format.web.prefix(50))")
        }
        // "Syncs across your devices", "you" and "Settings ▸ Search": everyone on this server, and here.
        let adapted: [(source: String, app: String, web: String)] = [
            (view, "Use this when one person appears under different names and the app kept them apart. The change syncs across your devices and can be undone from Corrections.",
             "Use this when one person appears under different names and the index kept them apart. The change is for everyone on this server and can be undone from Corrections."),
            (view, "Merge if these records refer to the same person. The change syncs across your devices.",
             "Merge if these records refer to the same person. The change is for everyone on this server."),
            (corrections, "Undoing a correction rebuilds the affected identities and syncs across your devices.",
             "Undoing a correction rebuilds the affected identities for everyone on this server."),
            (rail, "FRUS tags this as %@ — reclassified by you.", "FRUS tags this as ${what} — reclassified on this server."),
            (rail, "FRUS now tags this the same way, so your correction no longer changes anything. You can restore FRUS’s classification.",
             "FRUS now tags this the same way, so this server’s correction no longer changes anything. You can restore FRUS’s classification."),
            (rail, "The document’s body styling, badges, search filters, counts, and exports will follow the new classification on all your devices. Bundled series-analytics dashboards are computed from the published corpus and cannot see this change, and other open windows reflect it when reopened. You can restore FRUS’s own classification at any time from here or from Settings ▸ Search.",
             "The document’s body styling, badges, search filters, counts, and exports will follow the new classification for everyone on this server. Bundled series-analytics dashboards are computed from the published corpus and cannot see this change, and other open pages reflect it when reloaded. You can restore FRUS’s own classification at any time from here."),
        ]
        for line in adapted {
            #expect(line.source.contains(line.app), "the app holds \(line.app.prefix(50))")
            #expect((people + classification).contains(line.web), "copy.ts holds \(line.web.prefix(50))")
        }
    }
}
