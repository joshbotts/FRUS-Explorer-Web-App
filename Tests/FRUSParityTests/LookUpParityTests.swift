// NARA, Look Up and Zotero (PLAN's S22e), held to the app's source. The browser app's words, each where the app
// writes it, a key's sentence with the web's place for keys, Settings ▸ Keys, where the app's names Settings →
// Connections; and the server's and the browser's mirrors of the app's view code: the query Source Explorer's
// `load()` runs for a note, and its section's states; Look Up's opening strategy, its passage and its search;
// and the Zotero sends' items, names and history row. And Source Explorer's answer for a lot file over the fixture
// index, naming the query the NARA proxy runs for it.

import FRUSLightTestSupport
import FRUSParity
import Foundation
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct LookUpParityTests {
    /// The app's words the browser app takes, under their keys, and in copy.ts's blocks.
    @Test func theAppsWordsAreTheWebs() throws {
        let sources = NoteViewParityTests.Sources()
        let sheet = "SourceExplorer/NARACatalogLookupView.swift"
        let view = "SourceExplorer/SourceExplorerView.swift"
        let exportSheet = "Collections/CollectionExportSheet.swift"
        let words: [(file: String, key: String, value: String, block: String, web: String)] = [
            ("DocumentView/FloatingSelectionBar.swift", "selectionBar.lookUpInNARA", "Look Up in NARA", "lookUp", "verb"),
            (sheet, "nara.lookup.title", "Look Up in NARA Catalog", "lookUp", "title"),
            (sheet, "nara.lookup.close", "Close", "lookUp", "close"),
            (sheet, "nara.lookup.search", "Search", "lookUp", "search"),
            (sheet, "nara.lookup.queryField.header", "Search Text", "lookUp", "queryHeader"),
            (sheet, "nara.lookup.queryField.placeholder", "Lot number, file identifier, or keywords", "lookUp", "queryPlaceholder"),
            (sheet, "nara.lookup.queryField.hint", "Edit the selected text before searching if needed.", "lookUp", "queryHint"),
            (sheet, "nara.lookup.detected.header.v2", "Detected in This Passage", "lookUp", "detectedHeader"),
            (sheet, "nara.lookup.detected.hint.v2",
             "Archival citations found in the selected text and around it — select one to fill the search.", "lookUp", "detectedHint"),
            (sheet, "nara.lookup.detected.tapHint", "Fills the search text with this citation", "lookUp", "detectedTapHint"),
            (sheet, "nara.lookup.strategy.header", "Query Strategy", "lookUp", "strategyHeader"),
            (sheet, "nara.lookup.strategy.picker", "Strategy", "lookUp", "strategyPicker"),
            (sheet, "nara.lookup.periodLinks.header", "NARA Finding Aids by Period", "lookUp", "periodHeader"),
            (sheet, "nara.lookup.periodLinks.intro",
             "Select the filing period that matches the document date. Each link goes directly to the NARA research page for that period — no API key required.",
             "lookUp", "periodIntro"),
            (sheet, "nara.lookup.results.header", "NARA Catalog Results", "lookUp", "resultsHeader"),
            (sheet, "nara.lookup.results.loading", "Searching NARA Catalog…", "lookUp", "searching"),
            (sheet, "nara.lookup.results.empty",
             "No matching records found. Try editing the search text or selecting a different strategy.", "lookUp", "noResults"),
            (sheet, "nara.lookup.results.view", "View in NARA Catalog", "lookUp", "viewRecord"),
            (view, "source.explorer.nara.header", "NARA Catalog", "sources", "naraHeader"),
            (view, "source.explorer.nara.loading", "Searching NARA Catalog…", "sources", "naraLoading"),
            (view, "source.explorer.nara.noResult", "No matching record found in the NARA Catalog.", "sources", "naraNoResult"),
            (view, "source.explorer.nara.searchManually", "Search NARA Catalog Manually", "sources", "searchManually"),
            (view, "source.explorer.nara.viewRecord", "View in NARA Catalog", "sources", "viewRecord"),
            (view, "source.explorer.noKey.label", "NARA Catalog API Key Required", "sources", "noKeyLabel"),
            (exportSheet, "export.zotero.send", "Send to Zotero Library", "zotero", "send"),
            (exportSheet, "export.zotero.send.caption.connected", "Over the Zotero web API — carries your tags & research notes.", "zotero",
             "collectionCaption"),
            (exportSheet, "export.zotero.send.caption.macNoAccount",
             "Connect a Zotero account to send with your tags & research notes. Without one this saves an RIS file for Zotero’s File → Import.",
             "zotero", "collectionCaptionNoAccount"),
            (exportSheet, "export.zotero.result.title", "Sent to Zotero", "zotero", "sentTitle"),
            (exportSheet, "export.zotero.viewInZotero", "View in Zotero", "zotero", "viewInZotero"),
            (exportSheet, "export.zotero.section", "Send to a Reference Manager", "zotero", "section"),
            (exportSheet, "export.zotero.recover", "Save a Zotero file instead", "zotero", "recover"),
            ("DocumentView/DocumentView.swift", "document.share.zotero.error.title", "Couldn’t Send to Zotero", "zotero", "errorTitle"),
        ]
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        for word in words {
            #expect(NoteViewParityTests.writes(try sources.app(word.file), word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(try NoteViewParityTests.block(word.block, of: copy).contains("\(word.web): '\(word.value)'"),
                    "copy.\(word.block).\(word.web) is \(word.value)")
        }

        // The key sentences, the app's with its place, the web's with Settings ▸ Keys.
        let keyed: [(file: String, key: String, block: String, web: String)] = [
            (sheet, "nara.lookup.noKey.warning", "lookUp", "noKey"),
            (view, "source.explorer.noKey.explanation", "sources", "noKeyExplanation"),
        ]
        let place = (mac: "Settings → Connections", web: "Settings ▸ Keys")
        let macWords = [
            "nara.lookup.noKey.warning":
                "A NARA Catalog API key is required for this strategy. Add your key in Settings → Connections. The “Central files identifier” strategy does not require a key.",
            "source.explorer.noKey.explanation":
                "A free NARA Catalog API key is required to search for lot file and Presidential Library records. Add your key in Settings → Connections.",
        ]
        for word in keyed {
            let mac = try #require(macWords[word.key])
            #expect(NoteViewParityTests.writes(try sources.app(word.file), word.key, mac), "\(word.file) writes \(word.key)")
            let web = mac.replacingOccurrences(of: place.mac, with: place.web)
            #expect(try NoteViewParityTests.block(word.block, of: copy).contains("\(word.web): '\(web)'"), "copy.\(word.block).\(word.web)")
        }

        // The words written with a number, and the Mac popover's, which its source writes as they are.
        let lookUp = try NoteViewParityTests.block("lookUp", of: copy)
        #expect(NoteViewParityTests.writes(try sources.app(sheet), "nara.lookup.detected.resolved %@", "NAID %@ — from the bundled index; no API key needed"))
        #expect(lookUp.contains("resolved: (naId: string) => `NAID ${naId} — from the bundled index; no API key needed`"))
        let zotero = try NoteViewParityTests.block("zotero", of: copy)
        #expect(NoteViewParityTests.writes(try sources.app("DocumentView/DocumentView.swift"), "document.share.zotero.result %lld %lld",
                                           "Added %lld document and %lld notes to Zotero."))
        #expect(zotero.contains("documentResult: (items: number, notes: number) => `Added ${items} document and ${notes} notes to Zotero.`"))
        #expect(NoteViewParityTests.writes(try sources.app(exportSheet), "export.zotero.result %lld %lld", "Added %lld documents and %lld notes to Zotero."))
        #expect(zotero.contains("collectionResult: (items: number, notes: number) => `Added ${items} documents and ${notes} notes to Zotero.`"))
        #expect(NoteViewParityTests.writes(try sources.app(exportSheet), "export.zotero.result.failed %lld", "%lld failed."))
        #expect(zotero.contains("failed: (count: number) => `${count} failed.`"))
        let popover = try sources.app("App/SupportingViews.swift")
        #expect(popover.contains(#"actionRow("Send to Zotero Library", systemImage: "books.vertical","#))
        #expect(popover.contains(#"Text("Adds this document — with your tags and research notes — straight to your Zotero library.")"#))
        #expect(zotero.contains("documentCaption: 'Adds this document — with your tags and research notes — straight to your Zotero library.'"))
        // The kit's sentences the server says, with the web's place, are OutsideServicesTests'.
    }

    /// The server's and the browser's mirrors of the app's view code, each held to the lines it mirrors.
    @Test func theMirrorsAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let view = try sources.app("SourceExplorer/SourceExplorerView.swift")
        let server = try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/SourceExplorer.swift")
        // `load()`'s query for each citation, once it has a key: the app's, and the server's that the proxy runs.
        NoteViewParityTests.expect(view, holds: [
            "hasAPIKey = await client.hasAPIKey() guard hasAPIKey else { return } catalogEvidence = CatalogQueryEvidence.forNote(note, rawNote: rawSourceNote)",
            #"case .lotFile(let rg, let lotNumber, _): // Use variantControlNumber_is with three normalised lot number forms,"#,
            #"let rgToUse = (rg ?? "RG-59").replacingOccurrences(of: "RG-", with: "") await fetchResults { try await client.resolveLotFileVariants(lotNumber: lotNumber, recordGroup: rgToUse) }"#,
            #"if let lot { let rgToUse = rg.replacingOccurrences(of: "RG-", with: "") await fetchResults { try await client.resolveLotFileVariants(lotNumber: lot, recordGroup: rgToUse) }"#,
            #"let keywords = [series].compactMap { $0 }.joined(separator: " ") await fetchResults { try await client.searchByRecordGroup(rg, keywords: keywords, maxResults: 5) }"#,
            "try await client.searchByPresidentialMaterials( library: library, collection: collection, maxResults: 3 )",
        ], file: "SourceExplorerView.swift")
        NoteViewParityTests.expect(server, holds: [
            "let evidence = CatalogQueryEvidence.forNote(resolution.parsed, rawNote: note).map {",
            #"case .lotFile(let rg, let lotNumber, _): let rgToUse = (rg ?? "RG-59").replacingOccurrences(of: "RG-", with: "") return NARASearch(route: "lotVariants", lot: lotNumber, recordGroup: rgToUse)"#,
            #"if let lot { let rgToUse = rg.replacingOccurrences(of: "RG-", with: "") return NARASearch(route: "lotVariants", lot: lot, recordGroup: rgToUse) }"#,
            #"let keywords = [series].compactMap { $0 }.joined(separator: " ") return NARASearch(route: "recordGroup", recordGroup: rg, keywords: keywords)"#,
            #"return NARASearch(route: "presidentialMaterials", library: library, collection: collection)"#,
        ], file: "SourceExplorer.swift")
        let proxy = try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/NARACatalog.swift")
        NoteViewParityTests.expect(proxy, holds: [
            "return try await client.resolveLotFileVariants(lotNumber: lot, recordGroup: recordGroup)",
            "return try await client.searchByRecordGroup(recordGroup, keywords: keywords, maxResults: 5)",
            "return try await client.searchByPresidentialMaterials(library: library, collection: collection, maxResults: 3)",
            "return try await strategy.execute(query: query, client: client)",
        ], file: "NARACatalog.swift")
        // The section's states, and the web's: the key's prompt, the first five records, the candidate's chip, the
        // evidence's title once there is a key.
        NoteViewParityTests.expect(view, holds: [
            #"Section(catalogEvidence?.sectionTitle ?? String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")) { if requiresKey && !hasAPIKey { noAPIKeyPrompt } else if isLoading {"#,
            "} else if let error = loadError {",
            "if let caveat = catalogEvidence?.caveat {",
            "ForEach(catalogResults.prefix(5), id: \\.naId) { result in catalogResultRow(result: result, isVerified: catalogEvidence?.isVerified ?? true)",
            "if !isVerified { ConfidenceChip(confidence: .medium) }",
        ], file: "SourceExplorerView.swift")
        let page = try sources.web("sources/SourcesScreen.tsx")
        NoteViewParityTests.expect(page, holds: [
            "const evidence = keyed ? query?.evidence : undefined;",
            "<Section title={evidence?.sectionTitle ?? words.naraHeader}>",
            "{!keyed ? (",
            "{evidence?.caveat && <Caption>{evidence.caveat}</Caption>}",
            "{search.data.results.slice(0, 5).map((result) => (",
            "{result.title} {evidence && !evidence.isVerified && <ConfidenceChip />}",
        ], file: "SourcesScreen.tsx")

        // Look Up's sheet: the strategy it opens on, the passage it reads, a reading's fill, a strategy's clearing
        // and Search's rule; the server's and the web's.
        let sheet = try sources.app("SourceExplorer/NARACatalogLookupView.swift")
        NoteViewParityTests.expect(sheet, holds: [
            "_strategy = State(initialValue: found.first?.strategy ?? .keywordRG59)",
            "_queryText = State(initialValue: initialText.trimmingCharacters(in: .whitespacesAndNewlines))",
            "queryText = candidate.query strategy = candidate.strategy // Reset any prior results so the next Search reflects the new query. results = [] searchError = nil hasSearched = false",
            ".onChange(of: strategy) { _, _ in // Clear results when the strategy changes so the user sees fresh results. results = [] searchError = nil hasSearched = false }",
            "if strategy != .centralURL && !hasAPIKey {",
            ".disabled(isSearching || queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasAPIKey)",
            "private var showsPeriodLinks: Bool { strategy == .centralURL }",
            "let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines) guard !q.isEmpty else { return }",
            "results = try await strategy.execute(query: q, client: client)",
        ], file: "NARACatalogLookupView.swift")
        NoteViewParityTests.expect(proxy, holds: ["let opening = candidates.first?.strategy ?? .keywordRG59"], file: "NARACatalog.swift")
        let dialog = try sources.web("reader/LookUpDialog.tsx")
        NoteViewParityTests.expect(dialog, holds: [
            "const [text, setText] = useState(selection.text.trim());",
            "setText(candidate.query); setChosen(candidate.strategy); setSearch(null);",
            "setChosen(each.id); setSearch(null);",
            "{current?.searches && status.data && !keyed && <p className=\"hint warning\">{words.noKey}</p>}",
            "const searchable = !searching && query !== '' && keyed;",
            "const showsPeriodLinks = strategy === 'centralURL';",
            "const answer = await searchNARA(client, { strategy, query });",
        ], file: "LookUpDialog.tsx")
        // `lookupContext(vm:)`: the footnote's text, else the flat text around the offsets.
        let reader = try sources.app("DocumentView/DocumentView.swift")
        NoteViewParityTests.expect(reader, holds: [
            "if let block = webKitSelectedBlockText, !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return block }",
            "return flatTextExcerpt(from: model, start: max(0, range.0 - NARALookupAnalyzer.contextBefore), end: range.1 + NARALookupAnalyzer.contextAfter)",
        ], file: "DocumentView.swift")
        NoteViewParityTests.expect(proxy, holds: [
            "if let block = selection.blockText, !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return block }",
            "return flatTextExcerpt(from: page.model, start: max(0, start - NARALookupAnalyzer.contextBefore), end: end + NARALookupAnalyzer.contextAfter)",
        ], file: "NARACatalog.swift")

        // The Zotero sends: the document's tags and notes, its send with no collection; the collection's items in
        // their order, its name and its history row.
        let tagsAndNotes = try sources.app("Citation/ZoteroJSONExporter+App.swift")
        NoteViewParityTests.expect(tagsAndNotes, holds: [
            "for note in notes { for tagId in note.userTagIds { if let name = tagNameById[tagId] { tagNames.insert(name) } } }",
            "let noteBodies = notes.map(\\.bodyText).filter { !$0.isEmpty } return (tags: tagNames.sorted(), notes: noteBodies)",
        ], file: "ZoteroJSONExporter+App.swift")
        let send = try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/ZoteroSend.swift")
        NoteViewParityTests.expect(send, holds: [
            "for id in note.userTagIds { if let name = names[UserSearchText.uuidString(id)] { tagNames.insert(name) } }",
            "return (tagNames.sorted(), notes.map(\\.bodyText).filter { !$0.isEmpty })",
            "let result = try await send([item], collectionName: nil, key: key, services: services)",
            "let items = documents.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\\.zoteroItem)",
            "collectionName: CollectionExportNaming.zoteroCollectionName(savedName: collection.name),",
            #"try await CollectionExportRoutes.recordKept(format: "zotero-api", documents: result.addedItems, of: collection,"#,
            "let account = try await client.resolveAccount(key: key)",
        ], file: "ZoteroSend.swift")
        NoteViewParityTests.expect(try sources.app("DocumentView/DocumentView.swift"), holds: [
            "let result = try await ZoteroAPIClient().send( items: [item], collectionName: nil,",
        ], file: "DocumentView.swift")
        NoteViewParityTests.expect(try sources.app("Collections/CollectionExportSheet.swift"), holds: [
            "let items = docs.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\\.zoteroItem)",
            "collectionName: CollectionExportNaming.zoteroCollectionName(savedName: collection.name),",
            #"recordExport(format: "zotero-api", documentCount: result.addedItems)"#,
            "if isZoteroConnected { await sendToZoteroLibrary() } else { await exportZoteroRIS() }",
        ], file: "CollectionExportSheet.swift")
    }

    /// Source Explorer's NARA Catalog section for frus1961-63v06's d3, a lot file, over the fixture index: the query
    /// `load()` runs for it, which the NARA proxy runs, and the kit's evidence, verified by the lot's control number.
    @Test func aLotFilesSectionNamesTheQueryTheProxyRuns() async throws {
        let answer = try await ServedFixture.run { client, _ in
            try ServedFixture.decode(SourceExplorerAnswer.self,
                                     try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d3/sources", method: .get))
        }
        let catalog = try #require(answer.provenance.first { $0.kind == "naraCatalog" }?.catalogQuery)
        #expect(catalog.route == "lotVariants")
        #expect(catalog.search == NARASearch(route: "lotVariants", lot: "66 D 204", recordGroup: "59"))
        #expect(catalog.evidence == SourceExplorerAnswer.CatalogEvidence(sectionTitle: "NARA Catalog", caveat: nil, isVerified: true))
    }
}
