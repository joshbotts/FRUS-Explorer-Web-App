# FRUS Explorer and FRUS Explorer Light: working across the two repositories

A proposal for the owner, and for Claude Code sessions in either repository. Drafted 4 October 2026, when the web edition was pinned to the app's commit `cfc0d3c` (build 49, index version 65). Updated the same day, when S3's pin move took the pin to `af8bedab`, with FRUSCoreKit part 1, and on 5 October, when S6's took it to `f69b4a0a`, with part 2; the build and index version are unchanged. On 6 October S8a's upstream pull request merged as `101e17d7`, the server began linking the kit, and S8b's pin move took the pin to `101e17d7`; the build and index version are unchanged. On 7 October S9b's two upstream pull requests merged as `4fc04a60` and `f384d2d5`, and S9c's pin move took the pin to `f384d2d5`; the build and index version are unchanged. On 13 October the pin moved to `c6f7b2cb`, the commit the owner tagged `build-50`: build 50, index version 69. The same day S11a's two pull requests merged as `9feff971` and `757c6d29`, and S11b's pin move took the pin to `757c6d29`; the build and index version are unchanged. On 22 October, [issue #37](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/37) found the app's `v2` at `build-51`, 85 commits past the pin, at index version 71, unseen because the daily watch of section 5 had not been added; `PLAN.md`'s S12a added it, and S12b's pin move took the pin to `f0479037`, `build-51` (1.0, build 1776, index version 71), the same day. On 23 October S12c's upstream pull request merged as `af41efa4`, and S12e's pin move took the pin there; the build and index version are unchanged. The same day S13b's merged as `2767a128`, and S13c's pin move took the pin there, with the build and index version still unchanged. That evening S16a's merged as `02521d01`, and on 24 October S15a's two as `9ae72e7e` and `503a730b`; S16b's pin move took the pin to `503a730b` the same day, past all three, the build and index version unchanged again. On 27 October S17b's, S17a's and S18a's merged as `295e5276`, `391b3461` and `1c18b51e`, and S17c's pin move took the pin to `1c18b51e`, `v2`'s head, past them and the app's own merges since `503a730b`; the build and index version are unchanged. S12d moves it to `version-1.0` (build 1861) once that is tagged.

- **The app:** FRUS Explorer, for Mac and iOS, in [`joshbotts/FRUS-Explorer`](https://github.com/joshbotts/FRUS-Explorer).
- **The web edition:** FRUS Explorer Light, a self-hosted server, in [`joshbotts/FRUS-Explorer-Web-App`](https://github.com/joshbotts/FRUS-Explorer-Web-App).

The web edition does not reimplement the app. It compiles some of the app's own Swift files on Linux, and checks its results against reference outputs made by the app's own code.

## The division of labour

**Sessions working on the app follow four rules (section 4) and do nothing else for the web edition.** The rules protect the parts of the app's architecture the web edition stands on. Since #1569, a test in the app's normal Xcode run checks rules 1 and 2 for `FRUSCoreKit/`. For everything else, the web side's Linux builds catch what gets through: its CI at each pin move, and the daily watch of section 5, which builds and tests `v2`'s head. App sessions do not label, notify, run Linux builds or write web code. When app work and the web edition pull different ways, the app's work goes ahead, and the web side adapts.

**Sessions working on the web edition carry the rest, at their own token cost:**
- they watch the app's repository and repair what stops building on Linux;
- they write every app change that only the web edition needs, as pull requests on the app's repository;
- they move the pin, and keep this document and the app's `CLAUDE.md` section current.

**The owner merges.** Each web-authored pull request on the app's repository lists the commands for a Mac check, with the results to expect. The owner runs them, merges, and sometimes makes an export the web side asks for.

## Terms

| Term | Meaning |
| --- | --- |
| Pin | The one commit of the app's repository that the web edition uses. The web repository holds the app's repository as a git submodule at `upstream/FRUS-Explorer`, set to that commit |
| Pin move | A web pull request that points the submodule at a newer commit merged on the app's `v2` |
| Shared kits | The app's folders that the web edition compiles on Linux (table in section 1) |
| Golden files | Reference outputs made on a Mac by the app's own code, kept in the web repository's `fixtures/golden/`. The web edition must reproduce them |
| Sessions S0–S10, phases 1–6 | The web edition's plan: numbered work sessions, and its release phases. See [PLAN.md](https://github.com/joshbotts/FRUS-Explorer-Web-App/blob/main/docs/PLAN.md) |
| Checks 1–12 | The web specification's parity checks, such as check 3 (search) and check 4 (rendering). See [SPEC.md, Verification](https://github.com/joshbotts/FRUS-Explorer-Web-App/blob/main/docs/SPEC.md#verification) |

## 1. How the web edition uses the app's code

**Compiled from the pin, never copied.** The web `Package.swift` compiles the shared kits straight from the submodule's folders. The web repository's rule 4 forbids copying or rewriting the app's behaviour. A fix to shared code is a pull request on the app's repository, which only the owner merges. The pin moves only to a merged commit, in a web pull request of its own.

| App folder | Compiled on Linux | Web use |
| --- | --- | --- |
| SourceNoteKit, CrossRefKit, GeneratorKit | Since S0 | Tests run in the web CI. SourceNoteKit serves the reader through FRUSCoreKit since S8a, and will serve Source Explorer. CrossRefKit has drifted from the app's own cross-reference rules, so the reader uses FRUSCoreKit's `FRUSURLScheme` instead, since S9b |
| FTS5Store | Whole kit since the pin move after S1 (web pull request #15). Its schema file was compiled from S0 and its query compiler from S4 | The parity harness compares its parse of 482 queries with the app's. The server searches with it since S8c, through its read-only open |
| TEIHeaderKit, with ManifestGeneratorCore and ManifestGeneratorTests for its tests | Since the pin move after S1 | Tests only, for now |
| SemanticVectorsKit | Since the pin move after S1 | Semantic search, from phase 4 |
| FRUSCoreKit, part 1 | Since S3's pin move, to `af8bedab` | The reader's page, which the server serves since S8a (the body) and S8c (the page, with the kit's `ReaderPage`), and Cite. The web CI runs its tests, and renders the 393 golden rows with it |
| FRUSCoreKit, part 2 | Since S6's pin move, to `f69b4a0a` | Indexing and search on the server, and Citation Lookup since S19a. The web CI runs the kit's tests (878 at `f69b4a0a`, 884 since S8b's pin move, 894 since S9c's, 950 since build 50's, 1,061 since S11b's, 1,144 since S12b's, 1,147 since S12e's, 1,150 since S13c's, 1,191 since S16b's, 1,286 since S17c's), check 7's matcher half among them, which it also runs through the server's API since S19a, and indexes and searches the fixtures with it for checks 2 and 3 |
| WordCloudKit | Not compiled | Built on Apple's NaturalLanguage framework. Phase 4 plans a separate Linux lemmatizer |

The server links FRUSCoreKit, FTS5Store and SourceNoteKit since S8a, through its `FRUSLightAPI` target. It renders the reader's HTML with the kit and reads the manifest with `FixedVolumeCatalogue`. Since S8b's pin move, to `101e17d7`, the kit can open an index read-only and immutable, where every opener before it wrote to the database it opened; the web CI opens the fixture index that way and finds it answers as the writable index does. Since S8c the server searches and browses the live index through that open, and the web CI runs check 3 through its API, on the fixture index imported as an export is. Since S9c's pin move, to `f384d2d5`, the server reads the reader's links with the kit's `FRUSURLScheme.readerLink(from:)`, and opens `PageRangeStore` and `PersonMentionStore` immutably for page links and a person's count. Since S12c, at the 1.0 pin, a search row carries the kit's date fields and `SearchResultDate`'s words for them, the reader's page takes the kit's `ReaderMeasure` for its Reading Width, and a search whose client goes is cancelled, so the kit's progress handler stops its statement (`SearchStatementStop`). The Reading Width's three steps on the iPad and Mac ladder are app code (`ReadingWidth`), which the kit leaves to its host: the server mirrors them, as it mirrors the person card's choice of count, and a parity test reads them back from the app's source at the pin. Since S12e's pin move, to `af41efa4`, a page link goes where the kit's `PageLink` sends it, from the served index's page ranges or the bundled page map, which the server decodes itself, and a link that opens a volume where `WholeVolumeLink` sends it, as both of the app's readers ask them; the line the volume's page then shows is the app's `FollowedPageLink.notice`, a localized string that stays in the app, made the server's. Since S11f, at the same pin, the search's two readings are the kit's, all of it public since #1664: the timeline counts by year through `SearchService.resultSetFacets(parameters:request:documentKeys:)`, the Years facet over the keys of what a search keeps, and the concordance is `concordance(for:parameters:radius:)` for the page shown, in `KWICSort`'s orders. The captions that say which set a reading counted are the app's `ResultSetScope`, app code, which the browser app words as the Mac's does, and a parity test holds the sets the server reads to the app's source. Since S13a, at the same pin, a section's page names the row of its own text by the kit's `VolumeSection.ownTextEntry(among:)` over the index's rows, the rule both of the app's Browse views ask (#1536); the views' own part is placing the row first and its two localized strings, which the browser app words as the app's do, and a parity test indexes the kit's own fixture volumes for those rows, copied into `fixtures/own-text` and held to the pinned test source, so a pin move that changes one fails until it is copied again. Since S13c's pin move, to `2767a128`, the exact-word filter every `=word` search runs, the kit's `frus_exact_word`, reads each candidate's text as bytes (#1785), with the same answers, so such a search over the full corpus takes under two seconds where it took about a minute. Since S16b's pin move, to `503a730b`, the kit holds three more of the app's pieces, none of which the server linked then: the Mac's JSON export (#1786), `ResearchDataEnvelope` at format version 7 with the encoder's settings and the tolerant decoder, the Markdown note file and the research database export's strip, for phase 2's import (S16c), export (S16d) and the strip of an export that holds writing (S16e); the reader's three annotation scripts, `ReaderHighlight` with its stale rule, `SelectionVerb` and the re-anchor's search (#1788), for S15c's highlights; and Citation Lookup's Batch and Structured Entry types, public (#1787), for S19a. Since S15c, at the same pin, the reader's page loads the kit's three annotation scripts, byte for byte, as the server's own files; the server makes a highlight's text and version with the kit's `flatTextExcerpt` and `ASTToRenderNodeConverter.renderingVersion(for:)`, and judges one stale by `ReaderHighlight.isStale`; and the browser app holds its colours and verbs to `HighlightColor` and `SelectionVerb`. The few lines of the app's view code it mirrors, the selection bar's place and its wait before a clear, the reader's and the review sheet's orders, the review sheet's stale lines and the ⇧⌘H shortcut, a parity test reads back from the app's source at the pin. Since S15d, at the same pin, the server writes a note's Markdown file with the kit's `ResearchNoteMarkdownExport`, its citation with the kit's `HistoryAtStateCitationFormatter`, and a summary's format and authorship with the kit's `ResponseFormat` and `SummaryAuthorship`. Three rules are app code the server mirrors, each read back from the app's source at the pin by a parity test: a document's notes as `user_search` indexes them (`ResearchNote.indexedTextPerDocument`) and the newest summary (`GeneratedSummary.ranksAbove`), standing mirrors unless a row moves them into the kit; and All Notes' filters, titles and order (`NotesPaneSnapshot`), which S17b moved into the kit and the browser app still mirrors, since it filters the notes it holds as each key is typed, held to the kit's file since S17c's pin move. A note's RTF is read and written by the web's own codec, since the app reads RTF only through AppKit, held to the app's reading by golden spans. Since S19a, at the same pin, the server answers Citation Lookup with the kit's `CitationLookupFields`, its `CitationMatchingEngine` over the served index's `SearchService` and `PageRangeStore` and a `FixedVolumeCatalogue` of the bundled manifest, with the volumes that index holds as the downloaded ones, and its `CitationBlockSplitter`, `BatchCitationRunner` and `BatchCitationOutcome`, all public since #1787, so the web CI runs check 7's matcher half through the API. The app's view code the browser app mirrors, each result's colour, symbol, headline and action, a Batch row's label, colour and symbol, the row a tap opens and Needs work first's order, a parity test reads back from the app's source at the pin. Since S16c, at the same pin, the server imports the Mac's JSON export with the kit's `ResearchDataEnvelope`, its records and its tolerant decoder, `makeDecoder()`, of any format version from 1 to 7, and writes a plan's tiers and toggles, a summary's format, a prompt's schema and a saved search's `SearchParameters` with the kit's own types, encoded as the app's setters encode them; the parity harness reads them back as the kit's records, and runs check 6 on an export's highlights with the kit's `buildFlatText`, `buildFlatTextBlocks`, `flatTextExcerpt` and `ASTToRenderNodeConverter.renderingVersion(for:)`. What the import mirrors of the app's model code, each read back from the app's source at the pin by a parity test (`ImportParityTests`), are standing mirrors unless a row moves them into the kit: the initial value of each property a file before version 7 cannot carry (`Collection`, `CollectionEntry`, `Project`); the headnote prompt every draft the app makes carries, which tells a draft in an older file; the raw value `unrecognized`, which `CollectionEntry.entryKind` reads as an inert kind, named by the kit's `CollectionEntryKind` since S17c's pin move; the scalar columns `SavedSearch.init(name:parameters:)` writes from a search; and the earliest set of synced settings, which the app's coordinator keeps. The watermark `recordRun` writes is the kit's `SavedSearchFreshness` since S17b's #1805, and since S17c's pin move the import writes it with the kit's `encoded`, and the export reads it with the kit's `decoded(from:)`. Since S16d, at the same pin, the server writes the user's research as the Mac's export, the kit's `ResearchDataEnvelope` at `currentFormatVersion` with its records, written by `makeEncoder()`, with one key of the web's own beside it, which the kit's decoder passes over. What the export mirrors of the app's exporter, `ResearchDataExporter.makeEnvelope`, app code, which reads SwiftData, is held to its source at the pin by a parity test (`ExportParityTests`), a standing mirror unless a row moves it into the kit: which of its fetches sort and by what, the orders within a collection and a plan, the summaries only with the switch, the researcher's own prompts, a note's highlights, a missing authorship written as `aiGenerated`, a score that is no number written as 0, the header's project, and the getters of a saved search's watermark and of a plan's two blobs; and the export sheet's Contents, its rows, words and counts, which the browser app mirrors. Since S16e, Import mode strips an export made with the owner's writing with the kit's `ResearchDatabaseStrip.steps`, run in their order on the server's copy and named in the kit's words, on a connection with SQLite's `secure_delete` on, and stamps the copy `my_writing_included = 0`, as the app's `IndexDatabaseExporter` stamps a copy it strips; it reads the writing from the kit's columns before the strip, and tells a note block the user's notes already hold by the standing mirror of `ResearchNote.indexedTextPerDocument`. Check 6's two forms of a highlight's text are the kit's `HighlightReanchor.extracts(passage:start:end:in:)`, public since FRUS-Explorer#1789, which the harness calls since S17c's pin move. Since that move, to `1c18b51e`, the kit also holds S17a's source for the search's user half, `SearchUserSource` with the store the read-only open attaches (#1806), for S17d; S17b's research-layer rules over values (#1805), for S17e, S17f and S19b, and for S14c's tallies; and S18a's rendering of a collection from values (#1807), for S18d to S18f. The server links none of them yet. The codec formats a colour with the kit's `CollectionProse.hex`, and the golden spans' formats split prose into paragraphs with its `append`, so of the app's reading of prose only the colour's resolution, which is AppKit's, is the codec's own. On a Mac only, the web repository's `tools/mac-golden` compiles the whole app module, unmodified, to make golden files, and since S15d links the web's codec too, so the app can read what it writes; since S17c's pin move the codec and the formats import the kit internally, so the tool links the kit's module beside the app's own copy of its files, and neither sees the other.

**The index and export contract.** In phase 1, the server serves a database the app exports with Settings ▸ Data & Recovery ▸ Export Research Database…. It serves one index version and one FTS schema generation: `IndexingPipeline.currentDateIndexVersion` (71 since S12b's pin move, to 1.0's build 1776, 69 since build 50's, 65 before it) and `FTS5Connection.currentSchemaGeneration` (4) at the pin. A web test reads both declaration lines from the submodule. The server reads the export's `research_provenance` stamp. It refuses an export from another index version or FTS generation, one taken while the app was still re-indexing, and one in use (a `-wal` or unfinished `-journal` beside it). One that includes the owner's writing it refuses on a server that keeps no user data; any other server keeps the writing in the user's store and strips its copy with the kit's statements before serving it (S16e).

**Golden files.** `tools/mac-golden` runs the app's reader (`DocumentViewModel.load`, then `HTMLTemplate.build`) and SearchService. It writes:
- the reader's HTML for all 393 rows of three small fixture volumes;
- what SearchService compiles for each of 482 queries, covering every search rule in the user manual's §7.2;
- since S15d, the golden spans: the RTF the app's note editor writes for each formatting it offers, driven through `RichTextEditorController` and `ProseRichText`, and the app's reading of RTF through `CollectionProse.paragraphs(fromRTF:)`, of that RTF, of hand-written files and of the web codec's own, under the light appearance. Linux reads no RTF, so the web's codec is held to this file.

Two more come from an export of a Mac library holding exactly those three volumes: a summary of the index, and each query's count and first 50 results. Each pin move needs a new export from the build it pins, made after Erase Everything…, since a build at the same index version does not re-index what an earlier build indexed.

Since S6's pin move the web CI compares all four, through FRUSCoreKit's public API alone, as the server uses it:
- check 2: the kit indexes the three volumes, and the summary of its index is the export's;
- check 3: the kit's SearchService returns each query's count and first 50 results as the app does, and compiles each query, in every scope, as the app does;
- check 4: the kit renders all 393 rows byte-identical to the app's reader, along the reader's path and again from one full parse per volume, the path the server serves. Since S8a the CI also fetches every row through the server's reader route.

Results may differ in the order of exactly tied scores, which passes and is reported, and the index summary leaves out what depends on indexing history.

Each golden file records a digest of the app's `FRUSCoreKit`, `FRUSExplorer`, `FTS5Store`, `SemanticVectorsKit`, `SourceNoteKit`, `TEIHeaderKit` and `WordCloudKit` folders. Nearly every merge on the app's side changes it, so at a pin move a web session remakes the golden files on a Mac.

## 2. How the app's code was made portable

Web sessions did this work, as pull requests on the app's repository.

**#1567 (session S1): guards.** TEIHeaderKit, SemanticVectorsKit and FTS5Store compile on Linux behind `#if canImport` guards. On Apple platforms, each guard selects the code that was there before:
- `SQLite3` falls back to the web edition's `CSQLite` module, and `CryptoKit` to swift-crypto's `Crypto`.
- `OSLog` is imported only where it exists. `FoundationXML` and `FoundationNetworking`, which hold `XMLParser` and `URLSession` on Linux, are imported only where they exist.
- On Linux, `TEIHeaderFetcher` reads a response whole, since Linux lacks `URLSession.bytes(for:)`.
- `FTS5Store/LinuxLogger.swift` stands in for `os.Logger`, and compiles to nothing on Apple platforms.
- FTS5StoreTests' backup-exclusion test is disabled where Darwin is missing.

The Mac app built with identical warnings, and its debug library defined the same symbols as before (233,494 unique; #1567 reported 238,006, a count that included duplicates).

**#1569 (session S3): FRUSCoreKit part 1, merged as `f102fa4d`.** The renderer and citation code lived in the app module, among SwiftUI, WebKit and SwiftData code. The pull request moves them into a new top-level `FRUSCoreKit/` folder, compiled two ways like FTS5Store and TEIHeaderKit: as source in both app targets, and as an SPM library.
- **Moved with `git mv`,** 13 files and 10 test suites, each a 100% rename in the pull request's first commit. Later commits edit some of them, so the squash-merged commit shows them as 84–100% similar.
  - the TEI parser, AST and render nodes, the AST-to-render converter and the HTML serializer;
  - the citation formatter, parser and models, and the canonical URL;
  - `PageSpanResolver`, `BrokenRefsIndex`, `VolumeStructure` and the manifest models.
- **Into the kit, out of Apple-only files** (old names kept as forwarders or a typealias, so call sites do not change):
  - the printed-text helpers and the source-note wrapper rule, from `IndexingPipeline.swift`;
  - the `frusexplorer://` link grammar and figure URLs, from the WebKit scheme handler and the figure library, now `FRUSURLScheme`;
  - the highlight colours (now `HighlightColor`) and `ExportHighlight`.
- **Out of the kit, into new app files,** because they use SwiftUI or read app state: the `NavigationPath` overload, the citation-style setting in `UserDefaults`, and the `Bundle.main` loader for `broken-refs-index.json`.
- **A reader API:** `ReaderLookups`, `ASTToRenderNodeConverter(readerOf:lookups:brokenRefs:)` and `FRUSRenderNodeHTMLSerializer.reader`. `DocumentViewModel` and `HTMLTemplate` call them, so the server renders as the reader does without copying its setup.
- **Linux shims** for `String(localized:)` and `autoreleasepool`, in `FRUSCoreKit/Linux/`, compiling to nothing on Apple platforms.
- **Public for the web edition.** #1569 makes public what the web edition will call:
  - the reader's API;
  - `CrossRefDestination` and `FRUSURLScheme.resolveCrossRefTarget`;
  - `FRUSCanonicalURL`;
  - `CitationPlainText.plain` and `CitationPunctuation.withoutTerminalPeriod`;
  - `CitableDocumentNumber`.

  Most of the moved files' other declarations were already `public` in the app and stay so, so `public` alone does not mark web use. The app compiles the kit into its own module, so access changes nothing for it.
- **Tests.** The kit's eleven test files live in `FRUSExplorerTests/FRUSCoreKit/`. Xcode compiles them into the app's tests, and `swift test` compiles them against the kit alone as `FRUSCoreKitTests` (393 tests). Anything that needs the app goes inside `#if !SWIFT_PACKAGE`.
- **A boundary test,** `FRUSCoreKitBoundaryTests`, runs in the normal Xcode run (section 3).
- **Eleven source audits** whose rules a kit file can break now read `FRUSCoreKit/` as well as `FRUSExplorer/`.

At the pull request's head:
- the kit renders all 392 golden rows byte for byte on Linux, through its public API alone;
- on the Mac, `tools/mac-golden` renders the same 392 rows identically;
- the full iOS unit run (6,484 tests) fails only the 8 Keychain tests that an unsigned build also fails on `v2`;
- a symbol diff of the Mac app shows only the names the change adds or moves.

The app computes the same results. One timing changes: the broken-references index is now read when the reader's converter is built, rather than at the first cross-reference.

**Part 2 (session S6): two pull requests.** A, the indexing pipeline and the search service, [joshbotts/FRUS-Explorer#1573](https://github.com/joshbotts/FRUS-Explorer/pull/1573), merged on `v2` as `2d216f4c` after the owner's Mac check. B, the citation matcher and splitter and `PageRangeStore`, branched from that merge, [joshbotts/FRUS-Explorer#1574](https://github.com/joshbotts/FRUS-Explorer/pull/1574), merged on `v2` as `f69b4a0a` after the owner's Mac check.
- `IndexingPipeline.swift` is the app's largest and busiest file. A moves it into the kit with the Foundation-only types it and the search service use, all but its Spotlight section and its SwiftData summary method, which stay in the app's `IndexingPipeline+App.swift` beside the initialiser every app call site uses.
- The code A moves reads five of the app's JSON files. The host passes them in (`IndexingResources`), four of which change what an index holds; the server loads them since S8a, from the image's copy of `FRUSExplorer/Resources`. B adds the manifest, which the citation matcher reads through `CitableVolumeCatalogue`: the app's `ManifestStore` conforms to it, and the server reads the manifest with a `FixedVolumeCatalogue` since S8a.
- The indexer's stamps go through a stamp store (`IndexingStampStore`), which `UserDefaults` satisfies in the app and an in-memory store on the server.
- A adds `runPostIndexPasses`, the steps after indexing (the person rollup, the broken-reference flags, the subjects), which the app's launch calls and the server's indexer will.
- B leaves Batch and Structured Entry's types (the block splitter, the batch outcome and row, the lookup form's fields) internal, since only the seam is needed for S6's checks. The web edition's citation lookup, in phase 2, makes them public in its own pull request.
- The pin move after both, to `f69b4a0a`, changed the source digest, so it remade the golden files, the two from an export with a new three-volume export from the newly pinned build.

Web sessions wrote all of part 2.

**#1575 (session S8a): the read-only open and the reader's page, merged as `101e17d7`.** [joshbotts/FRUS-Explorer#1575](https://github.com/joshbotts/FRUS-Explorer/pull/1575) gives the server what it needs to search and read without writing to the index it serves:
- `FTS5Store(readingDatabaseAt:)` and `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:)` open an index read-only and immutable (`mode=ro&immutable=1`). They skip the schema setup, the switch to write-ahead logging and the writes the other openers make. The pipeline's open still registers `frus_exact_word`, which every `=exact` query needs. The app's openers run as before.
- `FigureImages.linked(url:)` and `FRUSRenderNodeHTMLSerializer.reader(figureURL:)` let a host name each figure's image by its own address. `FRUSURLScheme.figureURL(for:)` and `isSafeComponent(_:)` are public.
- The reader's page is kit code: `ReaderPage.build`, its CSS, `ReaderAppearance` and `TextSizePreference`. `HTMLTemplate` and `FRUSTheme` forward to it with the same bytes, which tests pin by SHA-256 for both appearances and all four text sizes.

At the pull request's head, read-only answers equal read-write answers, score bits included, on Linux and on macOS; the full iOS unit run (6,505 tests) failed only the 8 Keychain tests an unsigned build fails; and `tools/mac-golden` wrote all 392 rows and 482 expressions byte for byte as at `f69b4a0a`. The pin move after it, S8b's, remade the golden files, the two from an export with the owner's new three-volume export from a build of `101e17d7`: the HTML, the expressions and the results changed only in provenance, and the index summary's 36 digests and 7 checks not at all.

**#1578 and #1579 (session S9b), merged on 7 October as `4fc04a60` and `f384d2d5`.** S9b's reader needed two things from the kit:

- [joshbotts/FRUS-Explorer#1578](https://github.com/joshbotts/FRUS-Explorer/pull/1578) brings the reader's page to WCAG 2.2 AA:
  - every text colour is at 4.5:1 or more against the page and against an editorial note's tint, in both palettes;
  - person and cross-reference links are underlined, so colour is not the only thing that marks them.

  The page changes on every platform, on the Mac's printed page too. The web edition's golden files hold the reader's body alone, and did not move.
- [joshbotts/FRUS-Explorer#1579](https://github.com/joshbotts/FRUS-Explorer/pull/1579) moves the parse of the reader's links into the kit as `FRUSURLScheme.readerLink(from:)`, verbatim, and the app's handler dispatches what it reads. It also adds `PageRangeStore(readingDatabaseAt:)` and `PersonMentionStore(readingDatabaseAt:)`, immutable opens on #1575's pattern.

S9c's pin move to `f384d2d5`, after the owner's Mac check of both:
- remade the golden files from the owner's new three-volume export. The HTML of all 392 rows and the expressions changed only in provenance, and the index summary's gating digests and checks not at all. That export indexed frus1969-76ve09p1 before frus1961-63v06, so in two queries the 50th result and its exactly tied successor changed places, which check 3 passes as a reorder within a tie;
- emptied the web edition's axe allowance: nothing on its pages fails axe, the reader's frame included;
- switched the server's link parse to the kit's;
- brought page links and the person card's count.

**Build 50's pin move, on 13 October, to `c6f7b2cb`.** No web-authored pull request was in it. Build 50 carries the app's own work since `f384d2d5`, with four index bumps, 66 to 69 (#1638, #1639, #1640 and #1645), which the app's side put into one build, so a library re-indexes once and the web pin moves once. The move:
- raised the served index version to 69, so the server refuses build 49's exports;
- met one break, in the web edition's own code: its link route's switch over `CrossRefDestination` had no case for a reference to a whole volume, which #1614 added, for #1603. The route now answers `volume`, and the browser app opens a catalogue volume in Browse, as the app's `WholeVolumeLink` does;
- replaced the schema fixture with `export-v69-schema.sql`, which differs from version 65's by one partial index, added by #1614 before the bumps;
- remade the golden files, the two made from an export with the owner's new three-volume export. The HTML of all 392 rows and the expressions changed only in provenance. Seven of the index summary's 36 gating digests moved, six with the bumps and one with #1614's index, and the kit on Linux reproduces each;
- builds `tools/mac-golden` in release, since from `845d57ea` a debug build of the app module fails under Xcode 27.0, where a whole-module build compiles it clean.

**#1664 and #1666 (session S11a), merged on 13 October as `9feff971` and `757c6d29`.** The phase-1 features need code the kit kept internal or the app kept in its own files. Both pull requests move it into the kit or make it public, and the app calls the moved code, so the two never hold two copies:

- [joshbotts/FRUS-Explorer#1664](https://github.com/joshbotts/FRUS-Explorer/pull/1664), search:
  - the concordance and the facets are public;
  - `SearchService.resultSetFacets(parameters:request:documentKeys:)` is the facet panel's route, and the panel calls it;
  - the panel's narrowing and staged selection, the Query Inspector's model and the date order move into the kit. `SearchSortOrder.sorted(_:)` replaces the comparator each view model kept.
- [joshbotts/FRUS-Explorer#1666](https://github.com/joshbotts/FRUS-Explorer/pull/1666), citations, titles and the reader:
  - the BibTeX, RIS and Zotero exporters move into the kit, with the Zotero exporter's SwiftData lookup left in an app extension;
  - the TEI's publication year becomes one scan, where each app kept a copy;
  - the display title, with the facts it reads, and the header display move into the kit;
  - the reader's footnote landing script moves into the kit;
  - `FRUSCanonicalURL.volumeURL(volumeId:)` is public.

Both build and pass on Linux over this repository's `main`. Remade at each branch, the 392 rows' HTML and the expressions change only in provenance.

S11b's pin move, the same day, to `757c6d29`:
- found nothing to repair: the web edition's own code built and passed at the new pin, and no kit folder, skip or schema changed;
- remade the golden files from the owner's three-volume export of 13 October, made from build 50 for its pin move, on the owner's word. The pin is still build 50, and no file on the indexing path changed since `c6f7b2cb`, so a new export would have indexed the same rows.

**S12b's pin move, on 22 October, to `f0479037`,** the commit tagged `build-51`: FRUS Explorer 1.0 (build 1776), 85 commits past `757c6d29`, with 18 pull requests on shared code or bundled data ([issue #37](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/37)). No web-authored pull request was in it. The move:
- raised the served index version to 71 (#1746, #1747), so the server refuses build 50's exports, and added `cited-page-map.json`, which `indexResourceNames` gained with #1747, to the files the server will not start without;
- met no break: every kit built and passed on Linux with no new skip, as issue #37's dry run had found. The web edition's own code changed only in its index version, in the tests that named build 50's facts, and in a new test of the snippet rule #1736 brought;
- kept the schema fixture: both of the owner's 1776 exports hold `export-v69-schema.sql`'s statements in its order, and `setupDatabase(_:)` is the same text;
- remade the golden files from the owner's 1776 three-volume export. The one new row, frus1969-76ve09p1's Note on U.S. Covert Actions, is #1746's, and the other 392 rows' HTML is unchanged; 15 queries' expressions lose a mark at a term's end, with parser 6.8 (#1770); 18 of the index summary's 36 gating digests moved, each with #1746, #1747 or #1710;
- published a release tag beside `edge`, `:1.0-1776`, read from the pinned `project.yml`, which moved with `edge` until S14g left it to the releases the owner cuts by hand.

**#1784 (session S12c), merged on 23 October as `af41efa4`.** 1.0 lands a link to a printed page of a volume the device does not hold on the document the bundled page map names (#1778), and otherwise opens the volume's page in Browse, which names the page. That rule was app code, in the URL handler. [joshbotts/FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784) moves `PageLink` and `WholeVolumeLink`, unchanged but for `public` and `Sendable`, to the end of the kit's `TEI/FRUSURLScheme.swift`, and both readers call them there; `FollowedPageLink`, whose notice is a localized string, stays in the app. Run beside `v2` before it opened, the Mac app's two debug libraries held the same symbols, the full iOS unit run failed only as `v2`'s does, and `swift test` ran 3,033 tests, `FRUSCoreKitTests` 1,147; the owner merged it the day it opened.

S12e's pin move, the same day, to `af41efa4`:
- found nothing to repair: the build, every kit suite and the web edition's own code passed at the new pin, with no new skip, no kit folder or schema changed, and the build and index version unchanged;
- serves the landing: the link route asks `PageLink` with the volumes the served index holds as the device's, the served `PageRangeStore`, and the page map, which the server decodes at start, and `WholeVolumeLink` for a link that opens a volume. Over the fixtures, the 31 links into volumes this server does not hold land on the document the map names for 19, and open the volume in Browse for 12;
- remade the golden files with the owner's 1776 three-volume export, on the owner's word: the build and the indexing path were unchanged, and only provenance changed.

**#1785 (session S13b), merged on 23 October as `2767a128`.** An exact-word search (`=word`) took 45 to 70 seconds over the full corpus, in the Mac app and on the server alike: the kit's `frus_exact_word` folded and split every candidate's whole text with Foundation, 21 to 22 seconds for `=Soviet`'s 58,679 rows on either platform, and a search makes that pass for its count and again for its page. [joshbotts/FRUS-Explorer#1785](https://github.com/joshbotts/FRUS-Explorer/pull/1785) makes `ExactWordMatcher` read a text's UTF-8 bytes and fold only where a scalar it cannot class asks it to, and the SQL function read the bytes SQLite holds and fold its word once a statement, so such a search takes under 1.3 seconds on both. The answers are the fold's: `containsByFolding(word:in:)` keeps the definition, the tests hold every answer to it, and over the full 1776 export every decision for the 45 parity queries' words, 3.58 million texts, was the same. It changes no index, export, schema or result, and nothing that indexes, since the pipeline's change is the search function's registration: the pin move past it may remake the golden files from the export it already uses, by the owner's choice, though `IndexingPipeline.swift` and FTS5Store are on §5's list. It also corrects #1784's records. Run beside `v2` before it opened, the Mac app's debug library held every one of `v2`'s symbols and 241 more, all the new code's or what it uses, once the numbers the compiler gives local thunks were dropped; the full iOS unit run failed only as `v2`'s did; and `swift test` ran 3,043 tests, `FTS5StoreTests` 219 and `FRUSCoreKitTests` 1,150.

S13c's pin move, the same day, to `2767a128`, the branch's head byte for byte:
- found nothing to repair: the build, every kit suite and the web edition's own code passed at the new pin, `FTS5StoreTests` at 219 and `FRUSCoreKitTests` at 1,150, with no new skip, no kit folder or schema changed, and the build and index version unchanged;
- remade the golden files with the owner's 1776 three-volume export, on the owner's word: on §5's indexing path, `git diff` shows #1785 changing only `frus_exact_word`, its matcher and a hook for the tests, which only a search's statements call, and only provenance changed;
- timed the 45 exact-word parity queries through the API over the owner's full 1776 export: 16.9 s in all, median 0.39 s, p95 1.07 s, with every count and every record check 3 reads the kit's (SPEC, check 12).

**#1786 (session S16a), merged on 23 October as `02521d01`.** Phase 2 imports a Mac's JSON export into the server's user store and writes one back, which needs the export's file in the kit and a file that carries the whole research layer. [joshbotts/FRUS-Explorer#1786](https://github.com/joshbotts/FRUS-Explorer/pull/1786) does both, one commit each:
- **The move, unchanged.** `ResearchDataEnvelope`, its records and tolerant decoder, `currentFormatVersion` and the encoder's settings go into `FRUSCoreKit/Export/`, public, with the five types they name, the Markdown note file and the research database export's strip as its statements. `makeEnvelope(modelContext:)` and the views stay in the app.
- **Format version 7.** The eight model types 6 left out, each tolerant in the decoder, and what 6 dropped from the types it carried, each optional, so files of versions 1 to 6 still decode. The kit's suite keeps a file of each version from 1 to 7.

It is the first web-authored change to a file the app writes for its users. On Apple platforms the export gains those keys, and **Contents** gains eight rows and a new footer. It also narrows one line-based sweep in `CloudKitSchemaInventoryTests`, which read the export's copy of the reserved `annotationId` as a writer. Run beside `v2`:
- the full iOS unit run failed only as `v2`'s did, at 7,623 tests;
- `swift test` ran 3,054 tests, `FRUSCoreKitTests` 1,161;
- with thunk numbers and file-private discriminators dropped, the symbol diff was 68 names removed and 1,786 added, each one the change accounts for;
- on Linux over `main`, S14a's store suites included, everything passed but the parity suites' golden-file staleness.

The owner merged it the day it opened, a squash with the branch head's tree. Mac check 10's decode reads a real export with the kit through `FRUS_RESEARCH_EXPORT`. It changes nothing on §5's indexing path. The pin move past it widens `scripts/upstream-watch`'s search for `currentFormatVersion` to `FRUSCoreKit/Export`, where the number now is.

**#1787 and #1788 (session S15a), merged on 24 October as `503a730b` and `9ae72e7e`.** S15c draws highlights in the reader with the app's own scripts and rules, and S19a runs Citation Lookup's Batch and Structured Entry with the kit's types:
- **[joshbotts/FRUS-Explorer#1788](https://github.com/joshbotts/FRUS-Explorer/pull/1788)** moves into FRUSCoreKit, public and otherwise unchanged:
  - the reader's three annotation scripts, byte for byte, which the app injects as before;
  - the JSON `FRUSHighlights.render` reads, as `ReaderHighlight`, with its stale rule;
  - `SelectionVerb` with its footnote rule;
  - the re-anchor's search, `HighlightReanchor`.

  The app keeps every old name, as a typealias or a forwarder. `ReaderAnnotationScriptTests` pins each script by SHA-256 and length.
- **[joshbotts/FRUS-Explorer#1787](https://github.com/joshbotts/FRUS-Explorer/pull/1787)** makes `CitationLookupFields`, `CitationBlockSplitter`, `BatchCitationOutcome`, `BatchCitationRow`, `BatchCitationRunner` and `ConfidenceLabels` public, which #1574 left internal.

Run beside `v2` at `02521d01`:
- both full iOS unit runs failed only as `v2`'s did, #1788 at 7,636 tests and #1787 at 7,623;
- `swift test` ran 3,084 and 3,054 tests;
- with thunk numbers and file-private discriminators dropped, #1788's symbol diff was 243 names removed and 256 added, all but one removed reappearing under the moved declaration's new name, and #1787's was 3 removed and none added;
- on Linux over `main`, everything passed but the parity suites' golden-file staleness, and a scratch file outside the kit used every newly public name without `@testable`.

Neither changes anything on §5's indexing path. Mac check 9 verifies both. Whichever merges second conflicts only in the app's records, and a web session merges `v2` into its branch to combine them. #1788 merged first, as `9ae72e7e`, with its branch head's tree; `v2` was then merged into #1787's branch, keeping both pull requests' records, and its squash, `503a730b`, has that branch's last head's tree (`b3b272c6`).

S16b's pin move, on 24 October, to `503a730b`, `v2`'s head, past all three, and so S15b's move as well, by the owner's choice and `PLAN.md`'s rule that the first pin move after a phase-2 upstream merge takes it:
- found nothing to repair: the build, every kit suite and the web edition's own code passed at the new pin, `FRUSCoreKitTests` at 1,191, with no new skip; `Package.swift` compiles the new folder and files by folder, and no schema, index resource or app source folder changed, nor the build or index version;
- widened the watch's search for the export's number to `FRUSCoreKit/Export` as well as `FRUSExplorer/Export`: 6 at the old pin, 7 at the new;
- remade the golden files with a seventh three-volume export, which the owner made from a build of `503a730b`, though on §5's indexing path `git diff` is empty from `2767a128`, and the strip's statements moved into the kit unchanged. The HTML, the expressions and the results changed only in provenance, and the index summary's gating section not at all.

**#1789 (S15c's follow-up), merged on 24 October as `96c9de0c`.** S15c found two things in the kit's highlight code, and [joshbotts/FRUS-Explorer#1789](https://github.com/joshbotts/FRUS-Explorer/pull/1789) carries both, one commit each:
- **`kHighlightsJS`'s `buildRanges` ends a range that ends on a `<br>` after the element.** It ended every range with `setEnd(node, localOffset + 1)`, which for the offset engine's `<br>` entry throws `IndexSizeError` after `FRUSHighlights.render` has cleared the page, so the app drew none of that document's highlights. `ReaderAnnotationScriptTests` re-takes the script's pin, and a WebKit suite draws such a highlight through the app's `renderHighlights(on:)`.
- **`HighlightReanchor.extracts(passage:start:end:in:)` is public:** the kit's test of a span against a stored passage in either form a highlight stores, for check 6 on a Mac's highlights in S16c.

On Apple platforms the reader draws a highlight that ends on a line break, and that document's others with it, and nothing else changes. Run beside `v2` at `503a730b`:
- the full iOS unit run failed only as `v2`'s did, at 7,643 tests against 7,636;
- `swift test` ran 3,089 tests against 3,084;
- the symbol diff, normalized, removed nothing and added `HighlightReanchor.extracts`;
- on Linux over `main`, everything passed but the parity suites' golden-file staleness.

It changes nothing on §5's indexing path. The pin move past it brings both. The host script's try of each highlight before the kit draws them can then stay, for any other the kit cannot draw, or go, and check 6's sampler may stop avoiding an end on a line break.

**#1790 (S15d's follow-up), merged on 25 October as `9fa4375d`.** S15d's probes of AppKit for the codec's golden spans found that the collection exporters read the colour of typed prose as white whenever the current appearance is dark. [joshbotts/FRUS-Explorer#1790](https://github.com/joshbotts/FRUS-Explorer/pull/1790) fixes it in `CollectionProse.hexColor(_:)`, the decoder that the HTML, Word and PDF exporters and the live preview share. The fix resolves a colour as the light appearance draws it:
- on the Mac, inside `NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance`;
- on iOS, through `resolvedColor(with:)` with a light trait collection.

On Apple platforms, typed prose now has no colour in an export under either appearance, and a system colour takes its light shade. Run beside `v2` at `96c9de0c`:
- the full iOS unit run failed only as `v2`'s did, at 7,646 tests against 7,643;
- `swift test` ran 3,089 tests on both;
- the normalized symbol diff removed nothing and added 14 names, the closure and `NSAppearance`'s;
- Linux was not run, since no package target changed.

It changes nothing on §5's indexing path. The web's codec already reads each catalog colour as Aqua draws it. At the pin move past it, `NotesAndSummariesParityTests` fails by design, since it pins `hexColor`'s old two lines, and the golden spans should change only in provenance. Its left-over, a colour outside sRGB written from iOS as more than six hex digits, is #1793's.

**#1805 (session S17b), merged on 27 October as `295e5276`.** Phase 2 shows the research layer as the app does, and each part of it was a rule the app computes over its SwiftData rows, in app files. [joshbotts/FRUS-Explorer#1805](https://github.com/joshbotts/FRUS-Explorer/pull/1805) moves those rules into FRUSCoreKit, public, each over values a host's rows map to. The app maps its rows to the values and calls the rules, and keeps every name it used. The rules are:
- a saved search's freshness, "+N since last run";
- a working corpus and a volume scope as a search's filters;
- the trail's sessions, split by a 30-minute gap;
- the method appendix's Markdown and CSV, with the scope signature and the provenance statement, rendered for a host that passes in the version, the data files that name a subject, and the locale, calendar and time zone;
- the Research page's groups and counts, the projects' and tags' tallies, and All Notes' rows and filters.

On Apple platforms nothing changes: every answer comes from the same code over the same values, and the appendix is the same to the byte. On Linux, the kit's stand-in for `String(localized:)` now groups an interpolated integer as Foundation does. A fixture trail's appendix is held to the byte by one set of literals on iOS, macOS and Linux.

The branch was cut from `v2` at `9fa4375d` and rebased onto `41950692`, past #1792 and #1793, and run beside `v2` there:
- the full iOS unit run failed only as `v2`'s did, at 7,717 tests against 7,673;
- `swift test` ran 3,136 tests against 3,090, `FRUSCoreKitTests` 1,243 against 1,197;
- with thunk numbers and file-private discriminators dropped, the symbol diff was 172 names removed and 1,043 added, as before the rebase: 106 of the removed reappear under the moved types' new names, and the rest are closures, private helpers, the moved nested types' mangled names, two `CodingKeys` witnesses and the initialisers the public ones replace;
- on Linux over `main`, everything passed or failed as at `v2` but seven parity tests, and four issues in an eighth, which read app source it moves. The pin move points them at the kit.

It changes nothing on §5's indexing path. Mac check 12 verifies it. S18a's pull request carries the same two provenance files byte for byte, so whichever of the two merges second has no conflict in them.

**#1806 (session S17a), merged on 27 October as `391b3461`.** This server keeps each researcher's notes, summaries and tags in its own store, `user_search` and `tag_assignments`, never in the index it serves, and the kit's search read that half from the index alone. [joshbotts/FRUS-Explorer#1806](https://github.com/joshbotts/FRUS-Explorer/pull/1806) gives the search a source for it, in one commit and a records commit:
- **`SearchUserSource`:** `.index`, the index's own `user_content` and `document_cache` columns, the app's and the default everywhere; or `.attachedStore(userId:)`, one user's rows of a store attached to the index's connection, joined to the index's rows on `(volume_id, document_id)`. `SearchSQLFilters.userSource` and `SearchService.userSource` carry it.
- **The read-only open attaches the store,** read-only and never immutable: `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:userStore:)`, as `user_store`.
- **Every reader of the user half takes the source:**
  - the match;
  - the tag filter, and the exact-word filter's note and summary columns;
  - a row's tags, in the search and the Meaning rows;
  - the tag counts, a tag's documents and a document's tags.

  `SearchService.userTagCounts(parameters:tagIds:documentKeys:)` is public.

On Apple platforms nothing changes. The app passes no source, and `SearchStatementTextTests` pins the 365 statements the app's calls run on the user half, text and binds, to the same file's run on `v2`. Rebased onto `41950692` and run beside `v2` there:
- the full iOS unit run failed only as `v2`'s did, at 7,681 tests against 7,673, apart from one collection test that failed under load and then passed alone twice;
- `swift test` ran 3,098 tests against 3,090, `FRUSCoreKitTests` 1,205 against 1,197;
- with thunk numbers and file-private discriminators dropped, the symbol diff was 36 names removed and 182 added. Every removed name comes back under the signature that now takes a source or a store;
- on Linux over `main`, everything passed or failed as at `v2`. Check 3 gave its golden results through the default source, and a fixture user's note, summary and tags, written through this server's own store, were found through the kit with the store attached.

On §5's indexing path, `IndexingPipeline.swift` changes only in code a search runs and in the read-only open. When S17b's #1805 merged first, `v2` was merged into the branch, the records combined. The owner merged #1806 the same day, a squash with the branch head's tree. The pin move past it, S17c's, attaches the server's store at the read-only open and gives each request's user a service with that user's source.

**#1807 (session S18a), merged on 27 October as `1c18b51e`.** Phase 2's collection rows need the kit to render a collection from values (S18a), and then to resolve one through a data source (S18b). [joshbotts/FRUS-Explorer#1807](https://github.com/joshbotts/FRUS-Explorer/pull/1807) does the first, one move per commit, each move public:
- **The payloads, options, presets and naming.** Prose is carried as the spans every format renders, which the app's resolver decodes from the RTF, and an export date can be named.
- **The outline's value core.**
- **The quotation check,** with the body-text lookup it reads.
- **The HTML renderer and exporter, the Word exporter with its ZIP writer, and the BibTeX and RIS collection exporters.** Figures come from a source the host passes in, and the word cloud comes as image data from a drawing it passes in.

What reads SwiftData, Apple Intelligence or AppKit and UIKit stays in the app, which calls the moved code by its old names. `CollectionRenderingTests` pins each output of two value collections and the preview by SHA-256 and length, at a fixed date, so the pins hold on any platform.

The branch was begun on `v2` at `9fa4375d` and rebased on 27 October onto `41950692`, then onto `391b3461`, after #1805, which carried the same provenance move byte for byte, and #1806. Run beside `v2` at `391b3461`:
- the full iOS unit run failed only as `v2`'s did, at 7,739 tests against 7,725;
- `swift test` ran 3,179 tests against 3,144, `FRUSCoreKitTests` 1,286 against 1,251;
- with thunk numbers and file-private discriminators dropped, the symbol diff was 103 names removed and 246 added. Each removed name reappears without its discriminator or under a new signature, or is a default-argument generator or implicit initialiser that the public declarations no longer need;
- each export of four test collections through `makeExporter()`, one resolved from SwiftData, was the same 22 files, byte for byte, at both;
- on Linux over `main`, everything passed or failed as at `v2` but one parity test, which reads the exporter file this moves.

On §5's indexing path, only the lookup's access changes. Mac check 13 verifies it. The owner merged it the same day, a squash with the branch head's tree (`cba143d8`). S18b's pull request is branched after it, and S18c moves the pin past S18b's alone, since S17c's took this one.

S17c's pin move, on 27 October, to `1c18b51e`, `v2`'s head, past #1805, #1806 and #1807, and so, by `PLAN.md`'s rule, past every merge since `503a730b`, #1789, #1790, #1792, #1793 and #1801 among them:
- found nothing to repair in the build: the package and every kit suite passed at the new pin, `FRUSCoreKitTests` at 1,286, with no new skip. `Package.swift` compiles the kit's new folders by folder, and no schema, index resource or app source folder changed, nor the build, the index version or the export's format version;
- pointed the parity tests that read app source at the kit's moved files, and re-took their pins on #1792's one copy of each record, which the store, one row for each user and id, holds by construction;
- made the server call the kit's code where it mirrored the app's: a saved search's watermark (`SavedSearchFreshness`), a collection entry's kinds (`CollectionEntryKind`), check 6's two forms (`HighlightReanchor.extracts`), and the codec's colour and the golden spans' paragraphs (`CollectionProse.hex` and `append`). All Notes' rows and filters stay mirrored in the browser app, held to the kit's file;
- remade the golden files with the seventh three-volume export, on the owner's word: on §5's indexing path, `git diff` shows code that a search, an export or the reader runs, and none that indexing runs. Every file changed only in provenance, but for AppKit's version stamp in the RTF the app's editor wrote, now on macOS 27.2, and the index summary's timings.

**#1809 (session S18b), merged on 27 October as `fef96201`.** [joshbotts/FRUS-Explorer#1809](https://github.com/joshbotts/FRUS-Explorer/pull/1809) does the second: a collection resolves through a data source. Its seven commits move, each public:
- **The archival indexes `ArchivalResolver` reads, and its document resolution,** with `ArchivalIndexes`, the three as one value the blocks take. The stores that read the app's bundle stay in the app.
- **The five apparatus blocks,** with their data source, the tag union the thematic index reads and a locale for the chronology.
- **A collection's values and its composition's rules,** over the research data export's `CollectionExport`, which this server's store already maps its rows to, and summary-only depth's availability, passed in.
- **A smart collection's saved search,** at most 1,000 results, and its snapshot, made from values.
- **The assembly,** `CollectionContentAssembly`, which notes and highlights an entry takes, the overrides cascaded through sections, body depth, headnotes and the summary phase, behind `CollectionContentDataSource`. The app's `CollectionContentResolver` implements it with SwiftData and `AppState`, each read the fetch it made before.
- **The `.fruscollection` file,** written from values and read into values.

`CollectionResolutionTests` resolves a fixture collection over a volume the kit's pipeline indexes and a store the test supplies, and pins the items by SHA-256. The branch was begun on `v2` at `3af1fc07`, #1807's merge with #1808's website drafts. Run beside it:
- the full iOS unit run failed only as `v2`'s did, at 7,752 tests against 7,739, but for two tests of #1360's editor, which this does not touch. Run alone, the colour picker's passed every time, and the link alert's failed 4 of 18 runs at the branch and 2 of 18 at `v2`, within chance;
- `swift test` ran 3,191 tests against 3,179, `FRUSCoreKitTests` 1,298 against 1,286;
- with thunk numbers and file-private discriminators dropped, the symbol diff was 614 names removed and 1,071 added. Each removed name is the resolver's machinery, now the kit's assembly, a signature that names a moved type or gained a locale, or a closure whose code moved;
- test collections built in SwiftData and resolved every way the app resolves one, with the `.fruscollection` file, its import and a smart snapshot, were the same files at both, three runs each, but for the order an unsorted fetch returned one document's two highlights, which changed from run to run at `v2` itself;
- on Linux over `main` at `2fac971`, every target passed but the parity suites, whose 21 issues are all the golden files' staleness, since their source digest covers `FRUSCoreKit/` and `FRUSExplorer/` whole. Every parity check that reads the app's source passed.

Nothing on §5's indexing path changes, so the golden files' export may be reused at the pin move, by the owner's choice. Mac check 14 verifies it, with the collection UI suites. The owner merged it the same day, a squash with the branch head's tree (`d1b45392`). S18c moves the pin past it.

**#1810 (S16e's follow-up), open.** S16e strips a research database exported with the writing with the kit's `ResearchDatabaseStrip.steps`, and found that the app's own export, with the switch off, kept the index of the notes and summaries in the copy's free pages. The steps rebuilt `user_content` only after `VACUUM`, which may renumber the rows the index is keyed on, so the pages that held its terms were freed after the `VACUUM`, and macOS's SQLite, whose `secure_delete` is `FAST`, writes nothing over a freed page. Decoding FTS5's leaf format in those pages gives back every term of the writing. [joshbotts/FRUS-Explorer#1810](https://github.com/joshbotts/FRUS-Explorer/pull/1810) adds two statements to the steps, in the kit, so that the app's export and every host that runs them have both:
- `user_content` emptied before the `VACUUM`, which then reclaims its pages;
- `PRAGMA secure_delete = ON` first, so that SQLite writes zeros over whatever is freed after it.

Either alone keeps the writing out. On Apple platforms a copy exported without the writing holds no word of it anywhere in its bytes, and is smaller by the size of that index; nothing else changes. Cut from `v2` at `3af1fc07`, rebased onto `fef96201` after #1809, and run beside `v2` there:
- the full iOS unit run failed only as `v2`'s did, at 7,754 tests against 7,752;
- `swift test` ran 3,192 tests against 3,191, `FRUSCoreKitTests` 1,299 against 1,298;
- the symbol diff, raw and normalized, removed nothing and added nothing;
- on `v2`'s code, its new tests fail, the export's own among them, and the kit's control passes;
- on Linux over `main`, everything passed or failed as at `v2` but S16e's free-page test, whose control expects these steps at `FAST` to leave the writing's words.

It changes nothing on §5's indexing path. The pin move past it drops the server's own `secure_delete` and changes that control.

## 3. The architecture that protects coordination

These structures let the two codebases share code without app sessions having to think about the web edition. Web sessions add and maintain them, in pull requests on the app's repository.

- **Kit folders, compiled twice.** FTS5Store, SourceNoteKit, TEIHeaderKit, SemanticVectorsKit and `FRUSCoreKit/` are top-level folders. Both app targets compile them as source, and the package also builds each as an SPM target. CrossRefKit, GeneratorKit and ManifestGeneratorCore are SPM targets only.
  - The SPM build compiles a kit alone, so it is where a kit naming an app declaration first fails.
  - A Linux-only break, such as an unguarded Apple import, shows only in a Linux build: the web CI, and the daily watch of `v2`.
- **A boundary test in the normal Xcode run.** `FRUSCoreKitBoundaryTests` fails when a `FRUSCoreKit/` file:
  - imports anything but Foundation, except FoundationXML, CryptoKit, swift-crypto's `Crypto` and SourceNoteKit, and since #1573 OSLog, SQLite3 (`CSQLite` on Linux) and FTS5Store, each inside the `canImport` branch that selects it (any other import fails, guarded or not);
  - reads `Bundle.main` or `UserDefaults`;
  - names a type, function, constant or variable that only the app declares. Since #1571, a follow-up merged as `2a4df13`, it skips members after a `.`, argument labels, and any name the kit declares for itself. So a change that touches no kit file fails it only by giving an app declaration a Foundation or standard-library name the kit uses, such as `URL` or `max`; renaming the app's declaration fixes that.

  It also fails on Linux stand-ins that Apple platforms would compile, and on a kit test that names the app outside Xcode's branches. Xcode's build alone cannot catch any of this, because it compiles the kit into the app module. Web sessions can extend the test to the other kits.
- **Forwarders and typealiases.** Code moved into a kit keeps its old name in the app, so moving it changes no call site.
- **One entry point per web use,** such as the reader API, so the server never copies app setup code. App sessions may still change it: a change the web edition depends on shows at its next pin move, and a web session follows.
- **Resources passed in, not read from `Bundle.main`.** On Linux `Bundle.main` is the server's own folder, where the app's resources are not, so a lookup quietly finds nothing.
- **Dual-compiled tests,** so the kit's behaviour is tested on every platform from one set of files.

## 4. The rules for sessions working on the app

The whole of the app side's part. Each rule costs little or nothing. The boundary test checks rules 1 and 2 for `FRUSCoreKit/`.

1. **Shared code stays free of UI and app frameworks.** "Shared code" means FTS5Store, SourceNoteKit, CrossRefKit, GeneratorKit, TEIHeaderKit, SemanticVectorsKit, ManifestGeneratorCore and `FRUSCoreKit/`, with their test folders. In them:
   - never import SwiftUI, UIKit, AppKit, WebKit, SwiftData, CoreSpotlight, TipKit or NaturalLanguage;
   - keep the existing `#if canImport` imports (SQLite3, CryptoKit, OSLog, FoundationXML, FoundationNetworking, SourceNoteKit) inside their guards. `FRUSCoreKit/` is stricter: Foundation only, apart from the guarded modules its `CLAUDE.md` entry names;
   - do not read `Bundle.main`, `UserDefaults` or the Keychain: pass such things in.

   Code inside a kit test's `#if !SWIFT_PACKAGE` branch is the app's own, compiled only by Xcode, and is exempt from rules 1 and 2.
2. **A kit file never uses an app-only type.** If kit code needs one, pass the value in, or move the declaration into the kit. If a member of a kit type has to read app state, put it in an extension in an app file.
3. **Leave the `#if canImport` guards in place.** They look redundant on Apple platforms, but Linux needs them. Change a kit's behaviour in the kit, never in an app forwarder to it. Forwarders and typealiases may be inlined.
4. **After changing shared code, run `swift test` as well as the usual unit target.** Xcode's schemes never run the kits' own suites; only `swift test` does, in about two minutes on a Mac.

**Not asked of sessions working on the app:**
- labelling or notifying for the web edition, or checking its CI;
- running Linux builds, the web repository's tools, or its golden-file refresh;
- holding back index-version bumps, export changes, kit API changes (`public` included) or refactors;
- shaping new code for the web edition, outside these rules;
- writing any feature, API or `public` access that only the web edition needs;
- porting their work after a web-authored move (section 5, Conflicts).

**What breaks when the app moves on.**
- **A break in the web edition's build** reaches none of its users. The web edition stays on its pin, and only its next pin move fails until a web session repairs it.
- **An index-version or FTS-generation bump** is different. The published server refuses exports from the new Mac build, naming the version it needs, until a pin move ships.

## 5. What sessions working on the web edition take on

| Task | When | How |
| --- | --- | --- |
| Watch the app's `v2` | Daily | A scheduled web CI job, which S12a added (described below the table), builds and tests the shared kits at `v2`'s head on Linux. It also compares the index version, FTS generation, export stamp, index resources, schema and bundled resources with the pin, and keeps one web issue on what is new |
| Repair breaks | When the watch fails, or a pin move's golden files differ | The smallest fix that leaves behaviour on Apple platforms unchanged: a web-side change when a kit's API or the index contract moved; otherwise a pull request on the app's repository that adds a guard, passes a value in, or moves a declaration into a kit. The app's change is never reverted |
| App changes only the web edition needs | When a web session needs one | A pull request on the app's repository, written by the web session (list below) |
| Pin moves | See the cadence below | Web pull request (checklist below) |
| Conflicts | When a web-authored pull request conflicts with app work | The web side merges `v2` into its branch and resolves the conflict, as the app's own workflows do, with no rebase or force-push. Before asking for the merge, it lists the app's open pull requests that touch the lines it moves, so the owner can merge it after they land. App work never waits, and never has to port a web move |
| Boundary-test upkeep | If it ever trips on an app-only change | A pull request on the app's repository that narrows the test |
| This document, and the app's `CLAUDE.md` section | When the rules or the architecture change | Web-authored pull requests in both repositories |

**The daily watch** is `.github/workflows/upstream-watch.yml`, added by S12a, which runs `scripts/upstream-watch` at 06:17 UTC each day and on demand from the Actions tab (Run workflow, with a ref other than `v2` if wanted, and a dry run that writes no issue):
- In `swift:6.4-noble`, as the web CI's swift job, it moves the submodule to `v2`'s head inside the job only, builds this package, and runs each test target on its own. A build break or a failing kit suite is the watch's finding, and fails the run, so its failure reaches the owner. The web edition's own tests check the pin's facts, so they fail past it by design: the watch lists them as information for the next pin move.
- It compares `v2` with the pin: the index version (`IndexingPipeline.currentDateIndexVersion`), the FTS generation (`FTS5Connection.currentSchemaGeneration`), the JSON export's stamp (`ResearchDataEnvelope.currentFormatVersion`, the kit's since #1786, and the app's `ResearchDataExporter.currentFormatVersion` before it), `IndexingResources.indexResourceNames`, FRUSCoreKit's and FTS5Store's `CREATE TABLE` and `ALTER TABLE` statements, the bundled resources added, changed or removed under `FRUSExplorer/Resources`, and the commits since the pin.
- It writes the report to the run's summary and to one issue labelled `upstream-watch`: it opens one when `v2` is past the pin and none is open, otherwise rewrites the open one's description, and comments when `v2`'s head or the kits' result changed, so a quiet day sends nothing. When nothing is past the pin and the kits pass, it closes the issue.
- It never moves the pin, never publishes, and needs only `contents: read` and `issues: write`. A pull request that changes the watch runs it in its dry mode; its jobs are not `main`'s required checks.

**Web-authored pull requests on the app's repository.** Each one:
- follows the app's conventions: a `claude/<topic>` branch, an outcome-sentence title, a session entry in `Planning/DEVELOPMENT-PLAN.md`, and version-history lines;
- states exactly what changes on Apple platforms, if anything;
- has already run, and quotes, both app builds, the full iOS unit run and `swift test`, from a clone at a real path (under `/tmp`, six source-scan tests fail falsely);
- lists those commands for the owner's Mac check, with the counts to expect;
- carries the `Mac` label, with "Mac verification requested" in its body;
- is opened when the app's repository is quiet, and kept small or split into reviewable commits.

**App changes only the web edition needs,** all to be written by web sessions:
- further moves into the kits (FRUSCoreKit part 2 was S6's, merged as #1573 and #1574; the read-only open and the reader's page were S8a's, #1575; the reader's AA palette, the link parse and the stores' immutable opens were S9b's, #1578 and #1579; the phase-1 features' search, citation, title and reader code is S11a's, #1664 and #1666; where a page link and a whole-volume link go, `PageLink` and `WholeVolumeLink`, is S12c's, #1784, merged as `af41efa4`, for the page-map landing #1778 gave the app, which the server serves since S12e's pin move);
- the index version shown beside Export Research Database… (phase 1), so a user can match an export to a server before copying 2.8 GB;
- the JSON export at `formatVersion` 7, adding the model types it lacks, above all saved searches and working corpora, and what 6 drops from the types it carries, a note's rich text and a collection's structure among them, after the envelope moves into FRUSCoreKit (phase 2, `PLAN.md`'s S16a): S16a's [#1786](https://github.com/joshbotts/FRUS-Explorer/pull/1786), merged as `02521d01`. It is the first web-authored change to a file the app writes for its users, so its Mac check exports and decodes again; the owner chose on 23 October to have it opened during the 1.0 submission, and merged it the same day;
- phase 2's other moves into the kit, each changing nothing on Apple platforms (`PLAN.md`, Phase 2): the reader's annotation scripts and highlight rules, and Citation Lookup's Batch and Structured types made public (S15a: [#1788](https://github.com/joshbotts/FRUS-Explorer/pull/1788) and [#1787](https://github.com/joshbotts/FRUS-Explorer/pull/1787), merged as `9ae72e7e` and `503a730b`, which the server's build compiles since S16b's pin move); a user-data source for the search's user half, which the app leaves at its own columns (S17a: [#1806](https://github.com/joshbotts/FRUS-Explorer/pull/1806), merged as `391b3461`); the research layer's rules, from a saved search's freshness to the method appendix (S17b: [#1805](https://github.com/joshbotts/FRUS-Explorer/pull/1805), merged as `295e5276`); and collections, rendered from values (S18a: [#1807](https://github.com/joshbotts/FRUS-Explorer/pull/1807), merged as `1c18b51e`), the three of them compiled into the server's build since S17c's pin move, then resolved through a data source (S18b: [#1809](https://github.com/joshbotts/FRUS-Explorer/pull/1809), merged as `fef96201`), which is the first to change how one of the app's features is put together;
- optionally, a JSON importer, so data made on the web can return to the Mac; not in phase 2, by the owner's choice of 23 October;
- public access for kit types the server needs, as each need arises, such as the re-anchor's test of a stored passage for S16c's check 6, with the kit's fix of a highlight that ends on a line break (S15c's follow-up: [#1789](https://github.com/joshbotts/FRUS-Explorer/pull/1789), merged as `96c9de0c`);
- the strip's two statements that keep the writing out of a copy's free pages: `user_content` emptied before the `VACUUM`, and `secure_delete` on, which the server set beside the kit's steps in S16e; the app's export had neither (S16e's follow-up: [#1810](https://github.com/joshbotts/FRUS-Explorer/pull/1810), open);
- boundary tests for the other kits.

**Pin cadence.** Until the app's public release, the pin holds unless the web edition needs a merged change, and web-authored pull requests are batched so it moves as seldom as possible. After the release, it moves about once per app release.

**A pin move, checklist:**
- The submodule, and the web `Package.swift` if kit folders changed.
- `Sources/FRUSLightCore/Compatibility.swift`, and the index version and app build in `docs/INSTALL.md`, if they changed.
- If the export's schema changed: a new `Tests/FRUSLightTestSupport/Fixtures/export-v<N>-schema.sql` from a real export by the pinned build (the owner is asked for one), the paths that name it, and the table list in `Tests/FRUSParity/IndexSchema.swift`.
- `fixtures/own-text`, the kit's fixture volumes for a section's own text, copied again when `OwnTextAPIParityTests` finds a suite's literal changed; and the synthetic export's rows of one of them and its outline (`SyntheticExport.ownTextRows`, `scripts/synthetic-export --own-text`, `frus1969-76v01-outline.json`), when the same suite finds them no longer the kit's index of the file.
- `UpstreamDigest.directories` and `appDirectories` in `tools/mac-golden/Package.swift`, which must stay the same list, if the app targets gained a source folder (`project.yml`).
- The CI's allow-list, if a kit test gained or lost a Linux-only skip. The web CI fails on any other skip, and on `Test.cancel`. It counts Swift Testing's skips in the results file `swift test --xunit-output` writes, where each is named by its suite and function, since the log can lose lines. It reads the log only for XCTest's skips and for cancellations, matching each by the verb right after the test's name, so a passing test whose name says "skipped" is not one.
- The golden files, remade with `scripts/make-golden --export` on a Mac. Any change to the app's sources makes every one stale, the golden spans (`fixtures/golden/rich-text/spans.json`) among them, which make-golden remakes from the app's source alone, after writing the web codec's fixtures with `frus-parity rich-text-fixtures`; commit `fixtures/rich-text` with them. The export must come from the pinned app build, in a library holding exactly the three fixture volumes, emptied with Erase Everything… and downloaded again, so the owner is asked for one. An export from an earlier pin can serve, by the owner's choice, when the app build is the same and no file on the indexing path changed between the two (`git diff` over the parser, `IndexingPipeline.swift` and its seams, FTS5Store, SourceNoteKit and `FRUSExplorer/Resources`), as S11b's did, or when the diff shows that what changed there is code only a search runs, which the pin move's log then says, as S13c's did. Until it arrives, the two files made from an export are listed in `fixtures/golden/PENDING` and the pull request stays a draft. The order the volumes are downloaded in sets the order they are indexed in, which can swap exactly tied results across the 50th place; check 3 passes that as a reorder within a tie, and adding the volumes in the order frus1894Nicaragua, frus1961-63v06, frus1969-76ve09p1 keeps the report steady.

## 6. For the owner

1. **Sections 4 and 5 are the arrangement.** #1572 added the appendix block to the app's `CLAUDE.md`. That block replaces the `CLAUDE.md` line offered as an owner item in #1567. #1569 added a FRUSCoreKit entry to `CLAUDE.md`'s list of package targets; the block points to that entry rather than repeating it.
2. **The daily watch** runs in the web repository's GitHub Actions and needs nothing from the app's repository, which is public. Its issue, labelled `upstream-watch`, is the owner's notice that the app has moved past the pin.
3. **Expect these requests from web sessions:**
   - a Mac check and merge for each web-authored pull request;
   - now and then, an export from the pinned app build: three volumes for the golden files, or any export when the schema changes;
   - the full-corpus export before S10, as the owner checkpoints in `PLAN.md` list.
4. **The three-volume export, at each pin move.** The owner made the first on 4 October, from a build of `af8bedab`, the second on 5 October, from a build of `f69b4a0a`, for S6's pin move, the third on 6 October, from a build of `101e17d7`, for S8b's, the fourth on 7 October, from a build of `f384d2d5`, for S9c's, the fifth on 13 October, from build 50, for its pin move, and the sixth on 22 October, from build 1776, for S12b's. S11b's pin move reused the fifth, and S12e's the sixth, since the build and the indexing path were unchanged. S13c's reused the sixth as well: the build was unchanged, and #1785 changes only what a search runs. The seventh came on 24 October, from a build of `503a730b`, for S16b's, which the owner chose over the sixth though neither had changed. S17c's reused the seventh, by the owner's choice: the build was unchanged, and what #1789 to #1807 change on the indexing path is code that a search, an export or the reader runs. A pin move needs another when either changes.

## Appendix: a section for the app's `CLAUDE.md`

```markdown
## Web edition (FRUS Explorer Light)

joshbotts/FRUS-Explorer-Web-App compiles this repository's shared kits on Linux from a pinned
commit. Sessions here follow four rules and do nothing else for it. Web sessions watch this
repository, repair Linux breaks, and write every change only the web edition needs, as pull
requests here for the owner to merge. The arrangement:
https://github.com/joshbotts/FRUS-Explorer-Web-App/blob/main/docs/COORDINATION.md

Shared code: FTS5Store, SourceNoteKit, CrossRefKit, GeneratorKit, TEIHeaderKit, SemanticVectorsKit,
ManifestGeneratorCore and FRUSCoreKit/, with their test folders (FRUSCoreKit's is
FRUSExplorerTests/FRUSCoreKit/; see its entry under SPM package targets). Code inside a kit test's
`#if !SWIFT_PACKAGE` branch is the app's own and exempt from rules 1 and 2.

1. In shared code, never import SwiftUI, UIKit, AppKit, WebKit, SwiftData, CoreSpotlight, TipKit
   or NaturalLanguage. Keep the existing `#if canImport` imports inside their guards; FRUSCoreKit/
   allows only Foundation and the guarded modules its entry names. Do not read Bundle.main,
   UserDefaults or the Keychain: pass them in.
2. A kit file never uses an app-only type: pass the value in, or move the declaration into the kit.
   A member that reads app state goes in an extension in an app file.
3. Leave the `#if canImport` guards in place, though they look redundant here. Change kit behaviour
   in the kit, never in an app forwarder to it.
4. After changing shared code, run `swift test` as well as the usual unit target: Xcode never runs
   the kits' own suites.

Not asked of sessions here: labelling, notifying or checking the web edition's CI; Linux builds or
its tools; holding back index-version, export, kit API (`public` included) or refactoring changes;
shaping code for it beyond these rules; any feature, API or `public` access only it needs; porting
work after a web-authored move. App work goes ahead; the web side follows.
```
