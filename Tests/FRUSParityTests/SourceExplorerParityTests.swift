// Source Explorer (PLAN's S22d), over the kit's fixture index imported as an export. Check 8: every source note
// of the three fixture volumes, as the export generator reads them from the TEI, resolved through the API and
// each record held to the generator's (`SourceExplorerCheck`, which `frus-parity check-source-explorer` runs
// against a running server). And the browser app's words and the server's and the browser's mirrors of the app's
// view code, held to the app's source: the iOS view's sections and their conditions, the neighbours sheet's scopes
// and queries, the collection page's caps, the published-source guidance's links, and the chips' words. This file
// imports neither FRUSCoreKit nor the generator's cores, which share eight public names; `SourceExplorerCheck`
// reads the cores, and the server the kit.

import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct SourceExplorerParityTests {
    /// The done-when's first part: check 8 passes over the fixtures' source notes, through the API.
    @Test func checkEightPassesThroughTheAPI() async throws {
        let notes = try SourceExplorerCheck.notes(teiDirectory: Repository.layout.tei, volumes: ParityFixtures.volumes)
        let comparator = try SourceExplorerCheck.Comparator(resources: ServedFixture.resources)
        let result = try await ServedFixture.run { client, _ in
            await SourceExplorerCheck.run(notes: notes, comparator: comparator) { path in
                let response = try await client.execute(uri: path, method: .get)
                return (Int(response.status.code), Data(buffer: response.body))
            }
        }
        for difference in result.differences { print("differs  \(difference)") }
        #expect(result.differences.isEmpty, "\(result.differences.count) differ:\n\(result.differences.prefix(40).joined(separator: "\n"))")
        #expect(result.passes, "\(result.summary(volumes: ParityFixtures.volumes.count))")
        // The year rule, as it stands at this pin: the seven documents whose datelines read "undated", which the
        // export dates from frus:doc-dateTime-min and both of the app's views do not date. A change to either
        // side's year changes this list.
        #expect(result.undatedByDateline == ["d14", "d30", "d49", "d73", "d75", "d98", "d117"].map { "frus1961-63v06/\($0)" })
        print(result.summary(volumes: ParityFixtures.volumes.count))
    }

    // MARK: - The app's words and view code

    /// The app's words the browser app takes, each where the app's source writes it, under its key, and in
    /// copy.ts's block under the key the page reads.
    @Test func theAppsWordsAreTheWebs() throws {
        let view = "SourceExplorer/SourceExplorerView.swift"
        let words: [(file: String, key: String, value: String, block: String, web: String)] = [
            (view, "source.explorer.title", "Source Explorer", "sources", "title"),
            ("DocumentView/ResearchRailView.swift", "researchRail.tile.sources", "Sources", "sources", "tile"),
            ("DocumentView/ResearchRailView.swift", "researchRail.tile.sources.help",
             "Resolve this document’s source note in the NARA Catalog or RG-59 records", "sources", "tileHelp"),
            ("Theme/FRUSTheme.swift", "source.explorer.info.heading", "About Source Explorer", "sources", "heading"),
            ("Theme/FRUSTheme.swift", "source.explorer.info.shows.title", "What you’re seeing", "sources", "title"),
            ("Theme/FRUSTheme.swift", "source.explorer.info.why.title", "Why it matters", "sources", "title"),
            ("Theme/FRUSTheme.swift", "source.explorer.info.catalog.title", "Links to the National Archives", "sources", "title"),
            (view, "source.explorer.rawNote.header", "Source Note", "sources", "rawNote"),
            (view, "source.explorer.provenance.header", "Provenance", "sources", "provenance"),
            (view, "source.explorer.centralFiles.type", "Type", "sources", "type"),
            (view, "source.explorer.centralFiles.identifier", "File Identifier", "sources", "fileIdentifier"),
            (view, "source.explorer.lotFile.rg", "Record Group", "sources", "recordGroup"),
            (view, "source.explorer.nara.viewRecord", "View in NARA Catalog", "sources", "viewRecord"),
            (view, "source.explorer.centralFiles.cite.note",
             "To request the original record from NARA, give them the decimal file number above. Add any telegram serial number, the from/to information, and the document’s date from the source note. Archivists use these details to find the record within the file.",
             "sources", "centralFilesCite"),
            (view, "source.explorer.subjectNumeric.typeValue", "State Dept. Subject-Numeric File (February 1963–1973)", "sources", "subjectNumericType"),
            (view, "source.explorer.subjectNumeric.designation", "File Designation", "sources", "designation"),
            (view, "source.explorer.subjectNumeric.block", "File Years", "sources", "block"),
            (view, "source.explorer.subjectNumeric.cite.note",
             "To request the original record from NARA, give them the file designation above and the block of years it was filed in (1963, 1964–66, 1967–69 or 1970–73). Add any telegram or airgram number, the from/to information, and the document’s date from the source note. NARA asks that a central-file citation name the file designation, not a folder or a box.",
             "sources", "subjectNumericCite"),
            (view, "source.explorer.decimalPeriod.header", "NARA Finding Aids by Period", "sources", "periodHeader"),
            (view, "source.explorer.decimalPeriod.matched", "Filing Period", "sources", "filingPeriod"),
            (view, "source.explorer.subjectNumeric.period", "February 1963–1973 (Subject-Numeric File)", "sources", "subjectNumericPeriod"),
            (view, "source.explorer.decimalPeriod.link", "Open NARA Finding Aids for This Period", "sources", "periodLink"),
            (view, "source.explorer.decimalPeriod.manualLink", "Filing Manual for This Period (PDF)", "sources", "manualLink"),
            (view, "source.explorer.decimalPeriod.hint",
             "Purport indexes and the filing manual for this period are available on the linked NARA page. Box lists are available on-site at the National Archives at College Park.",
             "sources", "periodHint"),
            (view, "source.explorer.subjectNumeric.hint",
             "The filing handbooks are on the linked NARA page: the 1963 handbook for 1963 and the 1965 handbook for 1964–1973. Box lists are available on-site at the National Archives at College Park.",
             "sources", "subjectNumericHint"),
            (view, "source.explorer.decimalPeriod.noYear", "Select the filing period that matches the document date:", "sources", "noYear"),
            (view, "source.explorer.cfpf.typeValue", "State Dept. Central Foreign Policy File (1973–1979)", "sources", "cfpfType"),
            (view, "source.explorer.cfpf.cite.note",
             "To request the original record from NARA, give them the file identifier above. Add any telegram channel and serial numbers, the from/to information, and the document’s date from the source note.",
             "sources", "cfpfCite"),
            (view, "source.explorer.cfpf.resources.header", "Research Resources", "sources", "cfpfResources"),
            (view, "source.explorer.cfpf.faqLink", "CFPF Research Guide (PDF)", "sources", "cfpfGuide"),
            (view, "source.explorer.cfpf.aadLink", "Search AAD Electronic Telegrams Database", "sources", "cfpfAAD"),
            (view, "source.explorer.cfpf.note",
             "CFPF records are available on microfilm (P-Reels, D-Reels, N-Reels) printouts at NARA and as P-Reel index descriptions and electronic telegrams in the AAD database. No API key is required for either resource.",
             "sources", "cfpfNote"),
            (view, "source.explorer.numericalFile.header", "Digitized Numerical File (M862)", "sources", "numericalFile"),
            (view, "source.explorer.numericalFile.gap",
             "No digitized roll directly covers this file number. Use the Card Index to confirm the case number, then browse the Numerical File series.",
             "sources", "numericalGap"),
            (view, "source.explorer.numericalFile.cardIndex", "Open Card Index (M1889) in NARA Catalog", "sources", "cardIndex"),
            (view, "source.explorer.numericalFile.series", "Browse the Numerical File series", "sources", "numericalSeries"),
            (view, "source.explorer.scans.header.v2", "Digitized Scans", "sources", "scans"),
            (view, "source.explorer.lotFile.typeValue", "State Dept. Lot File", "sources", "lotType"),
            (view, "source.explorer.lotFile.typeValueRG84", "State Dept. Post Records Lot File (RG 84)", "sources", "lotTypePost"),
            (view, "source.explorer.lotFile.lot", "Lot Number", "sources", "lotNumber"),
            (view, "source.explorer.curatedLot.possible.header", "Possible NARA Catalog Record", "sources", "possibleHeader"),
            (view, "source.explorer.curatedLot.open", "Open Series in NARA Catalog", "sources", "openSeries"),
            (view, "source.explorer.lotFile.bundled.open", "Open Series in NARA Catalog", "sources", "openSeries"),
            (view, "source.explorer.curatedLot.possible.note",
             "This match was made by collection name, not by a catalog control number. Confirm the lot number against the series before citing it.",
             "sources", "possibleNote"),
            (view, "source.explorer.curatedLot.candidates.header", "Candidate NARA Series", "sources", "candidatesHeader"),
            (view, "source.explorer.curatedLot.creator", "NARA Creator", "sources", "creator"),
            (view, "source.explorer.curatedLot.seeAll", "See all series by this creator", "sources", "seeAll"),
            (view, "source.explorer.curatedLot.candidates.note",
             "NARA did not accession this lot as a single series, so no one record is the answer. Review the candidates against the document’s date and type and consult with NARA archivist staff.",
             "sources", "candidatesNote"),
            (view, "source.explorer.curatedLot.referral.header", "Ask a NARA Archivist", "sources", "referralHeader"),
            (view, "source.explorer.curatedLot.referral.seriesCount", "Series in the collection", "sources", "seriesCount"),
            (view, "source.explorer.curatedLot.referral.entryRange", "HMS/MLR Entry Range", "sources", "entryRange"),
            (view, "source.explorer.curatedLot.referral.browse", "Browse the collection’s series", "sources", "browseSeries"),
            (view, "source.explorer.lotFile.hmsMlr", "HMS/MLR Entry", "sources", "hmsMlr"),
            (view, "source.explorer.curatedLot.dateRange", "Series Dates", "sources", "seriesDates"),
            (view, "source.explorer.lotFile.seriesYears", "Series Dates", "sources", "seriesDates"),
            (view, "source.explorer.lotFile.bundled.header", "NARA Catalog Record", "sources", "bundledHeader"),
            (view, "source.explorer.lotFile.series", "File Series", "sources", "fileSeries"),
            (view, "source.explorer.namedSeries.series", "File Series", "sources", "fileSeries"),
            (view, "source.explorer.lotFile.access", "Access", "sources", "access"),
            (view, "source.explorer.lotFile.use", "Use", "sources", "use"),
            (view, "source.explorer.lotFile.extent", "Extent", "sources", "extent"),
            (view, "source.explorer.lotFile.heldAt", "Held At", "sources", "heldAt"),
            (view, "source.explorer.lotFile.findingAids", "Finding Aids", "sources", "findingAids"),
            (view, "source.explorer.lotFile.hmsMlr.series", "HMS/MLR Entry (series)", "sources", "hmsMlrSeries"),
            (view, "source.explorer.lotFile.hmsMlr.series.note",
             "These entry numbers identify the enclosing file series, not this specific file unit.", "sources", "hmsMlrSeriesNote"),
            (view, "source.explorer.lotFile.cite.note",
             "When requesting the original records from NARA, cite the HMS/MLR entry number together with the lot number — it is the identifier archives staff use to locate the series.",
             "sources", "lotCite"),
            (view, "source.explorer.lotFile.bundled.note",
             "Resolved from the bundled index — no API key required. Records may be described at the series level rather than digitized page-by-page.",
             "sources", "bundledNote"),
            (view, "source.explorer.nara.repository", "Repository", "sources", "repository"),
            (view, "source.explorer.nara.series", "Series", "sources", "series"),
            (view, "source.explorer.nara.lot", "Lot File", "sources", "lotFile"),
            (view, "source.explorer.nara.box", "Box", "sources", "box"),
            (view, "source.explorer.cia.job", "Job/Accession No.", "sources", "ciaJob"),
            (view, "source.explorer.cia.header", "CIA Research", "sources", "ciaHeader"),
            (view, "source.explorer.cia.crestLink", "Search CIA CREST for This Job Number", "sources", "ciaLink"),
            (view, "source.explorer.cia.crestLinkGeneral", "Browse CIA CREST Database", "sources", "ciaLinkGeneral"),
            (view, "source.explorer.cia.note",
             "CIA records are not in the NARA Catalog. The CREST database (cia.gov/readingroom) holds declassified CIA documents, including released operational files and historical collections.",
             "sources", "ciaNote"),
            (view, "source.explorer.presLib.typeValue", "Presidential Library", "sources", "libraryType"),
            (view, "source.explorer.presLib.library", "Library", "sources", "library"),
            (view, "source.explorer.presLib.collection", "Collection", "sources", "collection"),
            (view, "source.explorer.curatedLibrary.header", "Finding Aid", "sources", "findingAid"),
            (view, "source.explorer.curatedLibrary.catalog", "NARA Catalog Record", "sources", "catalogRecord"),
            (view, "source.explorer.nara.header", "NARA Catalog", "sources", "naraHeader"),
            (view, "source.explorer.nara.searchManually", "Search NARA Catalog Manually", "sources", "searchManually"),
            (view, "source.explorer.namedSeries.file", "File", "sources", "file"),
            (view, "source.explorer.foreignArchive.typeValue", "Foreign Government Archive", "sources", "foreignType"),
            (view, "source.explorer.foreignArchive.note",
             "Foreign government archives are not indexed in the NARA Catalog. Consult the archive directly for access.", "sources", "foreignNote"),
            (view, "source.explorer.published.typeValue", "Previously Published", "sources", "publishedType"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.note",
             "This document was previously published. Consult the cited publication for the original source.", "sources", "publishedNote"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.family.treatySeries",
             "Treaty Series (Department of State)", "sources", "name"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.family.eas",
             "Executive Agreement Series (Department of State)", "sources", "name"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.family.bulletin", "Department of State Bulletin", "sources", "name"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.family.publicPapers", "Public Papers of the Presidents", "sources", "name"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.link.treaties",
             "Open the U.S. treaties research guide (Library of Congress)", "sources", "link"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.link.bulletin", "Browse the Bulletin on the Internet Archive", "sources", "link"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.link.publicPapers", "Browse the Public Papers on GovInfo", "sources", "link"),
            (view, "source.explorer.unrecognized.typeValue", "Unrecognized Format", "sources", "unrecognizedType"),
            (view, "source.explorer.unrecognized.explanation",
             "The source note format was not recognized. Its raw text is shown under Source Note. Automated NARA Catalog resolution is unavailable for this entry.",
             "sources", "unrecognizedExplanation"),
            (view, "source.explorer.countrySeries.header.v2", "Digitized Department of State Records (pre-1906)", "sources", "countrySeries"),
            (view, "source.explorer.countrySeries.intro",
             "This document predates the 1906 Numerical File. Based on its dateline and FRUS chapter, it was likely filed in the digitized series below — open a roll and review the images for the document’s date.",
             "sources", "countrySeriesIntro"),
            (view, "source.explorer.noNote.header", "Archival Source", "sources", "noNote"),
            (view, "source.explorer.noNote.detail",
             "This document carries no archival source note, and its exact filing couldn’t be predicted from its dateline and FRUS chapter.",
             "sources", "noNoteDetail"),
            (view, "source.explorer.noNote.series.diplomatic",
             "Documents of this era are held in the country-arranged diplomatic series (Despatches and Instructions) at the National Archives, Record Group 59.",
             "sources", "diplomatic"),
            (view, "source.explorer.noNote.series.numerical",
             "Documents of this era are filed in the 1906–1910 Numerical File at the National Archives, Record Group 59, arranged by case number rather than by country or date.",
             "sources", "numerical"),
            (view, "source.explorer.related.header", "Archival Neighbors", "sources", "neighbours"),
            (view, "source.explorer.related.empty.noNeighbors",
             "No other indexed documents cite this archival source. Index more volumes to surface related documents.", "sources", "noNeighbors"),
            (view, "source.explorer.related.empty.subjectNumeric",
             "This source note cites the Subject-Numeric File. No other indexed document was matched to the same file. Index more volumes to surface related documents.",
             "sources", "subjectNumericNoNeighbors"),
            (view, "source.explorer.related.empty.subjectNumeric.unkeyed",
             "This source note cites the Subject-Numeric File, but not in a form the app can match on, so documents from the same file can’t be matched.",
             "sources", "subjectNumericUnkeyed"),
            (view, "source.explorer.related.empty.unmatched",
             "This source note doesn’t cite a recognized lot file, central file, or presidential library, so related documents can’t be matched.",
             "sources", "unmatched"),
            ("Search/SearchView.swift", "search.result.archivalNeighbors", "Archival Neighbors…", "sources", "allNeighbours"),
            (view, "source.explorer.collection.header", "Archival Collection", "sources", "collectionHeader"),
            (view, "source.explorer.collection.footer", "Matched against the bundled cross-volume collection authority.", "sources", "collectionFooter"),
            ("SourceExplorer/MacSourceExplorerView.swift", "source.explorer.collection.open", "View Collection", "sources", "openCollection"),
            (view, "source.explorer.unprinted.header", "Unprinted Material", "sources", "unprinted"),
            (view, "source.explorer.unprinted.inherited", "Carried from the previous note", "sources", "inherited"),
            ("FRUSCoreKit/SourceExplorer/CentralFilesClassifier.swift", "centralFiles.confidence.medium", "Possible", "sources", "possible"),
            ("FRUSCoreKit/Provenance/ProvenanceSource.swift", "provenance.source.frusText", "FRUS text", "sources", "label"),
            ("FRUSCoreKit/Provenance/ProvenanceSource.swift", "provenance.source.nara", "FRUS + NARA catalog", "sources", "label"),
            ("FRUSCoreKit/Provenance/ProvenanceSource.swift", "provenance.source.ohPeople", "FRUS + OH people data", "sources", "label"),
            ("FRUSCoreKit/Provenance/ProvenanceSource.swift", "provenance.source.stateSchedule", "FRUS + State Dept. schedule", "sources", "label"),
            ("Provenance/ProvenanceChip.swift", "provenance.chip.a11y.frusOnly", "Source: the FRUS volumes only.", "sources", "spoken"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.title", "Archival Neighbors", "archivalNeighbors", "title"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.scope.label", "Scope", "archivalNeighbors", "scope"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.scope.volume", "This volume", "archivalNeighbors", "volume"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.scope.subseries", "This subseries", "archivalNeighbors", "subseries"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.scope.all", "All volumes", "archivalNeighbors", "all"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.preparingIndex", "Preparing your index…", "archivalNeighbors", "preparing"),
            (view, "source.explorer.related.loading", "Searching indexed volumes…", "archivalNeighbors", "loading"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.empty", "No Archival Neighbors", "archivalNeighbors", "empty"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.empty.detail",
             "No documents in your indexed volumes cite this archival source — indexing more volumes may surface some.", "archivalNeighbors", "emptyDetail"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.empty.detail.scoped",
             "No documents in this scope cite this archival source — switch to All volumes to search the whole index.", "archivalNeighbors", "emptyDetailScoped"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.title", "Collection", "archivalCollection", "title"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.overview.header", "Archival Collection", "archivalCollection", "overview"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.repository", "Repository", "archivalCollection", "repository"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.recordGroup", "Record Group", "archivalCollection", "recordGroup"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.lot", "Lot File", "archivalCollection", "lot"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.aliases", "Also cited as", "archivalCollection", "aliases"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.local.header", "In Your Library", "archivalCollection", "local"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.local.loading", "Counting your indexed documents…", "archivalCollection", "localLoading"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.local.empty",
             "Nothing in your index cites this collection yet. Index more of its citing volumes to surface documents.", "archivalCollection", "localEmpty"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.local.footer",
             "Counted from your own indexed volumes — the series-wide list below is independent of what you have downloaded.", "archivalCollection", "localFooter"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.neighbors", "Show Archival Neighbors", "archivalCollection", "neighbours"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.neighbors.hint",
             "Lists your indexed documents drawn from this collection", "archivalCollection", "neighboursHint"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.volumes.showFewer", "Show fewer", "archivalCollection", "showFewer"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.volumes.row.hint", "Opens this volume in the browser", "archivalCollection", "volumeHint"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.children.header", "Sub-Series", "archivalCollection", "children"),
            ("Browser/VolumeSourcesView.swift", "browser.sources.archivalNeighbors", "Archival Neighbors", "archivalCollection", "childNeighbours"),
            ("Browser/VolumeSourcesView.swift", "browser.sources.archivalNeighbors.help",
             "Show indexed documents drawn from this archival source", "archivalCollection", "childNeighboursHelp"),
            ("Browser/ArchivesBrowseView.swift", "browser.archives.collection.unavailable.title", "Collection Unavailable", "archivalCollection", "unavailable"),
            ("Browser/ArchivesBrowseView.swift", "browser.archives.collection.unavailable.detail",
             "This collection is not in the bundled archival authority.", "archivalCollection", "unavailableDetail"),
        ]
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let sources = NoteViewParityTests.Sources()
        for word in words {
            #expect(NoteViewParityTests.writes(try sources.app(word.file), word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(try NoteViewParityTests.block(word.block, of: copy).contains("\(word.web): '\(word.value)'"),
                    "copy.\(word.block).\(word.web) is \(word.value)")
        }
    }

    /// The app's format strings and interpolations, each a function in copy.ts that writes what the app writes: a
    /// `%lld` ungrouped, as `String(format:)` prints it, an interpolated count grouped, as a localized string's is.
    @Test func theAppsFormatsAreTheWebs() throws {
        let view = "SourceExplorer/SourceExplorerView.swift"
        let formats: [(file: String, key: String, value: String, block: String, web: String)] = [
            ("SourceExplorer/ClassificationChip.swift", "classification.chip.accessibility %@", "Classification markings: %@", "sources",
             "classification: (marking: string) => `Classification markings: ${marking}`,"),
            ("SourceExplorer/ConfidenceChip.swift", "confidence.chip.accessibility %@", "Confidence: %@", "sources",
             "confidence: (label: string) => `Confidence: ${label}`,"),
            (view, "source.explorer.related.matchKey %@", "Matching archival source: %@", "sources",
             "matchKey: (key: string) => `Matching archival source: ${key}`,"),
            (view, "source.explorer.collection.cited %lld", "Cited in %lld volumes across the series", "sources",
             "collectionCited: (count: number) => `Cited in ${count} volumes across the series`,"),
            (view, "source.explorer.related.overflow", #"\(relatedTotalCount - relatedDocs.count) more documents not shown"#, "sources",
             "neighboursMore: (count: number) => `${count.toLocaleString('en-US')} more documents not shown`,"),
            (view, "source.explorer.numericalFile.found",
             #"These digitized rolls hold File No. \(fileIdentifier). Open one and review the images page by page — documents are filed in numeric order by case."#,
             "sources",
             "numericalFound: (fileIdentifier: string) => `These digitized rolls hold File No. ${fileIdentifier}. Open one and review the images page by page — documents are filed in numeric order by case.`,"),
            ("SourceExplorer/PublishedSourceLinkTable.swift", "source.explorer.published.lookFor", #"Look for \(designation) in this publication."#, "sources",
             "publishedLookFor: (designation: string) => `Look for ${designation} in this publication.`,"),
            ("SourceExplorer/ArchivalNeighborsSheet.swift", "archivalNeighbors.overflow %lld",
             "%lld more share this source — open Source Explorer to see them all.", "archivalNeighbors",
             "overflow: (count: number) => `${count} more share this source — open Source Explorer to see them all.`,"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.aliases.more %lld", "%lld more variant forms", "archivalCollection",
             "aliasesMore: (count: number) => `${count} more variant forms`,"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.local.counts %lld %lld",
             "%lld documents in %lld of your indexed volumes cite this collection.", "archivalCollection",
             "localCounts: (documents: number, volumes: number) => `${documents} documents in ${volumes} of your indexed volumes cite this collection.`,"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.volumes.header %lld", "Cited Across the Series (%lld volumes)", "archivalCollection",
             "volumes: (count: number) => `Cited Across the Series (${count} volumes)`,"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.volumes.showAll %lld", "Show all %lld volumes", "archivalCollection",
             "showAllVolumes: (count: number) => `Show all ${count} volumes`,"),
            ("SourceExplorer/CollectionDetailView.swift", "collection.detail.child.volumes %lld", "Cited in %lld volumes", "archivalCollection",
             "childVolumes: (count: number) => `Cited in ${count} volumes`,"),
        ]
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let sources = NoteViewParityTests.Sources()
        for format in formats {
            #expect(NoteViewParityTests.writes(try sources.app(format.file), format.key, format.value), "\(format.file) writes \(format.key) as \(format.value)")
            #expect(try NoteViewParityTests.block(format.block, of: copy).contains(NoteViewParityTests.flattened(format.web)),
                    "copy.\(format.block) holds \(format.web)")
        }
        // The two multi-line literals, the scans' and the custody's, word for word, and the central files' type.
        let app = try sources.app(view)
        let block = try NoteViewParityTests.block("sources", of: copy)
        NoteViewParityTests.expect(app, holds: [
            #"\(ranges.count) scanned file ranges contain \(fileIdentifier). \ They are listed narrowest first. NARA digitized this file in \ overlapping sets, so the widest range is not wrong. The \ narrowest is simply the most specific."#,
            #"NARA has scanned \(count) file ranges in decimal class \(cls), \ but none of them covers \(fileIdentifier). The scans for this \ file are partial."#,
            #"\(repository) is not a National Archives repository, so the NARA \ Catalog has no record of this collection. A search on the \ collection name alone can return results that look authoritative but \ are not. None are shown here."#,
            #"defaultValue: "State Dept. Central Files (\(recordGroup.replacingOccurrences(of: "RG-", with: "RG ")))")"#,
            #"value: "National Archives and Records Administration""#, #"value: "Central Intelligence Agency""#,
        ], file: "SourceExplorerView.swift")
        NoteViewParityTests.expect(block, holds: [
            "scansMultiple: (count: number, fileIdentifier: string) => `${count.toLocaleString('en-US')} scanned file ranges contain ${fileIdentifier}. They are listed narrowest first. NARA digitized this file in overlapping sets, so the widest range is not wrong. The narrowest is simply the most specific.`,",
            "scansClassOnly: (count: number, decimalClass: string, fileIdentifier: string) => `NARA has scanned ${count.toLocaleString('en-US')} file ranges in decimal class ${decimalClass}, but none of them covers ${fileIdentifier}. The scans for this file are partial.`,",
            "outsideCustody: (repository: string) => `${repository} is not a National Archives repository, so the NARA Catalog has no record of this collection. A search on the collection name alone can return results that look authoritative but are not. None are shown here.`,",
            "centralFilesType: (recordGroup: string) => `State Dept. Central Files (${recordGroup})`,",
            "nara: 'National Archives and Records Administration',", "cia: 'Central Intelligence Agency',",
        ], file: "copy.ts")
        // The chips' spoken words: the app's sentences over the kit's partners.
        let chip = try sources.app("Provenance/ProvenanceChip.swift")
        #expect(NoteViewParityTests.writes(chip, "provenance.chip.a11y.joined %@", "Source: FRUS joined to %@."))
        let kit = try sources.app("FRUSCoreKit/Provenance/ProvenanceSource.swift")
        for (key, partner) in [("provenance.partner.nara", "the National Archives catalog"),
                               ("provenance.partner.ohPeople", "the Office of the Historian's working data on people (its HistoryAtState/people repository) and its Principal Officers and Chiefs of Mission"),
                               ("provenance.partner.stateSchedule", "the State Department's decimal classification schedule")] {
            #expect(NoteViewParityTests.writes(kit, key, partner), "the kit writes \(key)")
            #expect(block.contains(NoteViewParityTests.flattened("Source: FRUS joined to \(partner).")), "copy.sources speaks \(key)")
        }
        // The two reasons the pre-1906 section gives of "this device", said of this server.
        let classifier = try sources.app("FRUSCoreKit/SourceExplorer/CentralFilesClassifier.swift")
        for (reason, said) in [
            ("documentNotIndexed", "Not checked — this document is not in the search index on this device, so its dateline and FRUS chapter could not be read."),
            ("noVolumeStructure", "Not checked — this volume’s chapters are not in the search index on this device, and the chapter is what names the country."),
        ] {
            #expect(NoteViewParityTests.writes(classifier, "source.explorer.countrySeries.state.notChecked.\(reason)", said))
            #expect(block.contains("\(reason): '\(said.replacingOccurrences(of: "on this device", with: "on this server"))'"), "copy.sources.notChecked.\(reason)")
        }
    }

    /// The view code the server and the browser app mirror, held to the app's source: the iOS view's sections and
    /// their conditions, the neighbours sheet's scopes and queries, the collection page's caps, and the published-source
    /// guidance's links and freshness.
    @Test func theMirrorsAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let view = try sources.app("SourceExplorer/SourceExplorerView.swift")
        NoteViewParityTests.expect(view, holds: [
            "if let subjectNumeric = Self.subjectNumericCitation(parsed: parsed, note: rawSourceNote, documentDay: documentDay) {",
            "if let fileIdentifier, let year = effectiveYear, (1906...1910).contains(year) { numericalFileSection(fileIdentifier: fileIdentifier) }",
            #"if recordGroup == "RG-59" || recordGroup == "59" { centralFilesPeriodSection(fileIdentifier: fileIdentifier) }"#,
            "if ParisPeaceRecords.applies(recordGroup: recordGroup) { parisPeaceSection() }",
            "if let fileIdentifier { digitizedScansSection(fileIdentifier: fileIdentifier) }",
            "let curatedRG = CuratedLotResolutionsStore.shared?.recordGroup(forRawLot: lotNumber) let effectiveRG = curatedRG ?? recordGroup",
            #"let rg = effectiveRG ?? "RG-59" if rg == "RG-84" { return client.resolveRG84LotFile(lotNumber: lotNumber) } return client.resolveRG59CentralFiles(fileIdentifier: "Lot \(lotNumber)")"#,
            #"let fb = client.resolveRG59CentralFiles(fileIdentifier: [series, lotFile].compactMap { $0 }.joined(separator: " "))"#,
            "if libraryOutcome.isHit { offlineLibrarySection(libraryOutcome) } else if NARACustody.mayQueryCatalog(forRepository: library) {",
            "let fallback = client.libraryFallbackURL(libraryName: library)",
            "if let curated = CuratedLibraryResolutionsStore.shared?.resolution( repository: library, collection: collection, subCollection: CuratedLibraryResolutions.subCollection( inNote: rawSourceNote, afterCollection: collection)) {",
            "if curated == nil { Text(NamedFileSeriesRouting.explainer(seriesName: seriesName))",
            "if NamedFileSeriesRouting.offersStateRecordsLink(seriesName: seriesName) {",
            "if let outcome = CuratedLotResolutionsStore.shared?.outcome(forSeriesName: seriesName) { curatedLotSection(outcome) }",
            "if let routing = NamedFileSeriesRouting.routing(forSeriesName: seriesName) { namedSeriesRoutingSection(routing) }",
            "switch cards?.bundled { case .divided(let divided)?: curatedLotSection(divided) case .single(let entry)?: bundledLotSection(entry) case nil: EmptyView() }",
            "if !entry.isSeriesLevel, let seriesTitle = entry.displaySeriesTitle {",
            "if facts.isUseRestricted, let use = facts.useStatus {",
            #"? access : "\(access) — \(facts.accessRestrictions.joined(separator: ", "))""#,
            "if let entries = entry.hmsMlrEntryNumbers, !entries.isEmpty {",
            "} else if let seriesEntries = entry.seriesHmsMlrEntryNumbers, !seriesEntries.isEmpty {",
            "if citation.handbooks.count == 1, let handbook = citation.handbooks.first {",
            "switch countrySeriesOutcome { case .resolved: countrySeriesSection case .loading, .notChecked, .noMatch, .notApplicable: if !hasSourceNote { noSourceNoteSection } }",
            "countryResolutions.contains { $0.part.isEnclosure }",
            "case ..<1906:", "case 1906...1910:",
            "if hasSourceNote, let parsed { provenanceSection(parsed: parsed) }",
            "if let marking = IndexingPipeline.classificationMarking( sourceNote: rawSourceNote, stored: indexedClassification) {",
            "let row = DocumentHeaderDisplay.numberedRow(header: doc.header, number: doc.documentNumber)",
            "Text(row.title.isEmpty ? doc.documentId : row.title)",
            "if relatedTotalCount > relatedDocs.count {",
        ], file: "SourceExplorerView.swift")
        let server = try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/SourceExplorer.swift")
        NoteViewParityTests.expect(server, holds: [
            "if let subjectNumeric = SourceExplorerPanels.subjectNumericCitation(parsed: parsed, note: note, documentDay: resolution.documentDay) {",
            "if let fileIdentifier, let year, (1906...1910).contains(year) {",
            #"if recordGroup == "RG-59" || recordGroup == "59" {"#,
            "if ParisPeaceRecords.applies(recordGroup: recordGroup) {",
            "let curatedRG = resources.sourceExplorer(\\.curatedLots)?.recordGroup(forRawLot: lotNumber) let effectiveRG = curatedRG ?? recordGroup",
            #"let fallback: URL = (effectiveRG ?? "RG-59") == "RG-84" ? client.resolveRG84LotFile(lotNumber: lotNumber) : client.resolveRG59CentralFiles(fileIdentifier: "Lot \(lotNumber)")"#,
            #"let fallback = client.resolveRG59CentralFiles(fileIdentifier: [series, lotFile].compactMap { $0 }.joined(separator: " "))"#,
            "if outcome.isHit { panels.append(offlineLibraryPanel(outcome)) } else if NARACustody.mayQueryCatalog(forRepository: library) {",
            "subCollection: CuratedLibraryResolutions.subCollection(inNote: note, afterCollection: collection)) {",
            "if curated == nil { provenance.explainer = NamedFileSeriesRouting.explainer(seriesName: seriesName) if NamedFileSeriesRouting.offersStateRecordsLink(seriesName: seriesName) {",
            "case .divided(let divided)?: panels.append(curatedPanel(divided)) case .single(let entry)?:",
            "if !entry.isSeriesLevel { lot.seriesTitle = entry.displaySeriesTitle }",
            "if facts.isUseRestricted, let use = facts.useStatus {",
            "if let entries = entry.hmsMlrEntryNumbers, !entries.isEmpty {",
            "} else if let seriesEntries = entry.seriesHmsMlrEntryNumbers, !seriesEntries.isEmpty {",
            "let showsPartLabels = homes.contains { $0.part.isEnclosure }",
            #"case ..<1906: section.predictedSeries = "diplomatic" case 1906...1910: section.predictedSeries = "numerical""#,
            "provenance: hasSourceNote ? panels.provenance(parsed) : [],",
            "? IndexingPipeline.classificationMarking(sourceNote: note, stored: resolution.storedClassification) : nil,",
            "let row = DocumentHeaderDisplay.numberedRow(header: document.header, number: document.documentNumber)",
            "title: row.title.isEmpty ? document.documentId : row.title,",
        ], file: "SourceExplorer.swift")
        // The web's halves: a bundled lot's rows, the handbook rule and the access row.
        let page = try sources.web("sources/SourcesScreen.tsx")
        NoteViewParityTests.expect(page, holds: [
            "{handbooks.length === 1 && handbooks[0] ? (",
            "const seriesEntries = !entries && lot.seriesEntryNumbers && lot.seriesEntryNumbers.length > 0 ? lot.seriesEntryNumbers : undefined;",
            "{(entries || seriesEntries) && <Caption>{words.lotCite}</Caption>}",
            "{neighbours.totalCount > shown.length && <p className=\"se-dates\">{words.neighboursMore(neighbours.totalCount - shown.length)}</p>}",
        ], file: "SourcesScreen.tsx")
        NoteViewParityTests.expect(view, holds: [
            "if entry.hmsMlrEntryNumbers?.isEmpty == false || entry.seriesHmsMlrEntryNumbers?.isEmpty == false {",
        ], file: "SourceExplorerView.swift")

        // The neighbours sheet: its scopes, its defaults and its queries, and the server's.
        let sheet = try sources.app("SourceExplorer/ArchivalNeighborsSheet.swift")
        NoteViewParityTests.expect(sheet, holds: [
            "guard let anchorVolumeId else { return [.allIndexed] } var scopes: [NeighborScope] = [.volume(anchorVolumeId)] if let key = anchorSubseriesKey, subseriesMembers(key).count > 1 { scopes.append(.subseries(key: key, anchorVolumeId: anchorVolumeId)) } scopes.append(.allIndexed)",
            "case .allIndexed: return nil case .volume(let v): return [v] case .subseries(let key, _): let members = subseriesMembers(key) return members.isEmpty ? nil : Set(members)",
            "case .volumeSource: return anchorVolumeId.map { .volume($0) } ?? .allIndexed case .document, .collection, .decimalClass: return .allIndexed",
            "guard aliasLot != nil || !aliasNames.isEmpty else { return nil } return .init(lotFileNorm: aliasLot, names: aliasNames)",
            "names: [record.name] + record.aliases)",
            "forLotFile: nil, recordGroup: nil, series: nil, repository: nil, decimalClass: cls,",
            "Text(doc.header.isEmpty ? doc.documentId : doc.header)",
            "if totalCount > docs.count {",
        ], file: "ArchivalNeighborsSheet.swift")
        let neighbours = try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/ArchivalNeighbors.swift")
        NoteViewParityTests.expect(neighbours, holds: [
            "let offered = asked.anchorVolumeId.map { RelatedDocumentsRoutes.scopes(for: $0, resources: resources) } ?? [.all]",
            "case .volumeSource: return anchorVolumeId == nil ? .all : .volume case .document, .collection, .decimalClass: return .all",
            "guard aliasLot != nil || !aliasNames.isEmpty else { return nil } return .init(lotFileNorm: aliasLot, names: aliasNames)",
            "names: [record.name] + record.aliases)",
            "forLotFile: nil, recordGroup: nil, series: nil, repository: nil, decimalClass: cls,",
            "title: $0.header.isEmpty ? $0.documentId : $0.header,",
        ], file: "ArchivalNeighbors.swift")
        // Related Documents' mirror of the same scope rule, which the neighbours' route reads.
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/RelatedDocuments.swift"), holds: [
            "var scopes: [RelatedScope] = [.volume] if let key = subseriesKey(of: volumeId, resources: resources), resources.manifest.filter({ $0.subseries == key }).count > 1 { scopes.append(.subseries) } scopes.append(.all)",
        ], file: "RelatedDocuments.swift")

        // The collection page's caps and sections, and the web's.
        let detail = try sources.app("SourceExplorer/CollectionDetailView.swift")
        NoteViewParityTests.expect(detail, holds: [
            "private static let aliasDisplayCap = 6",
            "ForEach(record.aliases.prefix(Self.aliasDisplayCap), id: \\.self) { alias in",
            "lotFileNorm: record.lotFileNorm, repository: record.repository, recordGroup: record.recordGroup, names: [record.name] + record.aliases",
            #"value: "RG \(rg)""#,
        ], file: "CollectionDetailView.swift")
        NoteViewParityTests.expect(try sources.app("FRUSCoreKit/SourceExplorer/CollectionRelations.swift"), holds: ["static let previewRowCap = 5"],
                                   file: "CollectionRelations.swift")
        let record = try sources.web("sources/CollectionScreen.tsx")
        NoteViewParityTests.expect(record, holds: [
            "export const aliasDisplayCap = 6;", "export const previewRowCap = 5;",
            "collection.aliases.slice(0, aliasDisplayCap)", "collection.volumes.slice(0, previewRowCap)",
        ], file: "CollectionScreen.tsx")

        // The published-source guidance: its links, the day they were confirmed, and how long they stay fresh.
        let table = try sources.app("SourceExplorer/PublishedSourceLinkTable.swift")
        let facts = try sources.app("TripPacket/RepositoryFactTable.swift")
        NoteViewParityTests.expect(table, holds: [
            #"url: "https://guides.loc.gov/researching-treaties-and-international-agreements","#,
            #"url: "https://archive.org/details/pub_department-of-state-bulletin","#,
            #"url: "https://www.govinfo.gov/app/collection/PPP","#,
            "year: 2026, month: 8, day: 28).date",
            "if link.isStale(), let checked = link.verifiedDate {",
        ], file: "PublishedSourceLinkTable.swift")
        NoteViewParityTests.expect(facts, holds: ["static let freshnessWindow: TimeInterval = 180 * 24 * 60 * 60"], file: "RepositoryFactTable.swift")
        NoteViewParityTests.expect(try sources.web("sources/sourcesRules.ts"), holds: [
            "treatySeries: 'https://guides.loc.gov/researching-treaties-and-international-agreements',",
            "stateBulletin: 'https://archive.org/details/pub_department-of-state-bulletin',",
            "publicPapers: 'https://www.govinfo.gov/app/collection/PPP',",
            "export const publishedLinksConfirmed = Date.UTC(2026, 7, 28);",
            "const freshnessWindow = 180 * 24 * 60 * 60 * 1000;",
            "return restrictions && restrictions.length > 0 ? `${status} — ${restrictions.join(', ')}` : status;",
            "const parts = [series.entryNumber, series.dateRange].filter((part): part is string => !!part);",
            "return parts.length > 0 ? parts.join(' · ') : undefined;",
        ], file: "sourcesRules.ts")
        // The provenance chip's glyphs by tier, drawn here as shapes.
        NoteViewParityTests.expect(try sources.app("Provenance/ProvenanceChip.swift"), holds: [
            #"case .frusOnly: return "square.fill" case .joined: return "triangle.fill" case .computed: return "circle.fill""#,
        ], file: "ProvenanceChip.swift")
    }
}
