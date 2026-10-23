# Readiness notes

3 October 2026 · at `FRUS-Explorer` commit `34a5120` (index version 65, app build 49)

Sessions 0 to 9 are done: S3's upstream pull request merged as `f102fa4d`, S6's two as `2d216f4c` and `f69b4a0a`, S8a's as `101e17d7`, and S9b's two as `4fc04a60` and `f384d2d5`, and their pin moves, with the one to build 50 (`c6f7b2cb`) and S11b's past S11a's two (`9feff971`, `757c6d29`) after them, build and test FRUSCoreKit on Linux in CI, with checks 2 to 4 on the fixtures; see `docs/DEVLOG.md`. S1, S3 and S6 waited while the owner asked that sessions not open pull requests on `FRUS-Explorer`; the owner lifted that hold on 4 October. This folder keeps what a dry run on Linux found for later sessions, so their prompts can start from evidence rather than estimates.

## What was verified

| Claim | Result |
| --- | --- |
| S0's three kits build and pass on Linux | Yes, in `swift:6.4-noble` on arm64: SourceNoteKit 292 tests, CrossRefKit 10, GeneratorKit 7, no warnings. The plan's 219 was the count on 22 September |
| FTS5 works with the app's own DDL | Yes, on SQLite 3.45.1. `FTS5Types.swift` compiles on its own, since it imports only Foundation. `frus_documents` is an external-content table over `document_cache`. The porter tokenizer stems a prefix term as if it were a whole word: `negotiating*` and `negoti*` match "negotiating", but `negotiat*` stays `negotiat*`, which no stored term begins with |
| Hummingbird 2 builds | Yes: 2.27.0 with Swift 6.4 on Linux. It resolves swift-crypto 5.0.0 |
| The owner's export matches the pin | Yes, until build 50's pin move to index version 69. `~/Documents/frus-index.sqlite`, exported on 3 October from build 49: index version 65, FTS schema 4, 553 volumes and 316,768 documents, the whole manifest |
| The fixtures match the Mac's copies | Yes. HistoryAtState/frus commit `8e5da08` and the Mac app's downloads are byte-identical, for the three fixtures and for all 553 volumes. The app downloads from `master` and saves the bytes unchanged |
| TEI rendering matches on Linux | Yes. All 392 fixture documents render to byte-identical HTML on Linux and macOS, in a command-line build with the serializer's default options |
| The indexer and search run on Linux | Yes, since S6's pin move, compiled from the app's own files in FRUSCoreKit. The three fixture volumes index in 1.07 s together in a release build on arm64, and a 24-volume sample in 24.5 s (SPEC, Sizing) |

## Before the S1 prompt

S1 is done: upstream #1567 merged as `cfc0d3c`, and the pin-move pull request builds and tests the six kits on Linux in CI. Their DEVLOG entries say how.

- **Rules 2, 3 and 5 collide.** S1 needs two pull requests: the guards upstream, and the web repository's DEVLOG entry. `Package.swift` cannot add the kits until the pin moves, since they do not build on Linux without the guards, so the pin-move pull request adds them. Upstream has no CI and squash-merges, so a pull request's head never reaches `v2`, and the pin can move only after the owner merges. Decided on 3 October: S1 builds and tests the six kits against its pull request's head in the session and records the output in DEVLOG; after Mac check 1 and the merge, a separate pull request moves the pin and adds the kits to CI. Since S4, that pull request also carries golden files made again at the new pin on the owner's Mac (`scripts/make-golden`), or its `swift` check fails.
- **The library guards the plan names are enough.** `s1-linux-guards.patch` has them. The test side needs more:
  - FTS5StoreTests imports SQLite3 in 7 files. With guards, 208 of its 209 tests pass. The failure is the backup-exclusion test (`FTS5StoreTests.swift:523-529`): excluding a file from backup is a silent no-op on Linux, so the test needs a named Linux skip, as check 1 asks.
  - The logging shim must accept `os.Logger`'s `privacy:` interpolation, which FTS5Store uses 12 times. The patch's `LinuxLogger.swift` does.
  - TEIHeaderKit has no test target. Its 22 tests live in ManifestGeneratorTests, which needs FoundationNetworking and a stand-in for `URLSession.bytes(for:)`. The patch does both, and all 60 of those tests pass.
- **Dependencies live in the web repository.** Upstream's `Package.swift` declares none, so swift-crypto and `CSQLite` are declared Linux-only in this repository's `Package.swift`. Use a swift-crypto range that admits Hummingbird's 5.x, such as `"3.12.3"..<"6.0.0"`.
- **Pull requests on `FRUS-Explorer`.** Answered on 3 October: not for now, so S1, S3 and S6 waited. The owner lifted the hold on 4 October. Upstream already has a `Mac` label for rule 4.
- **Rule 3 has nothing to tick.** It ends each session with "its task ticked in `docs/PLAN.md`", but the session table has no checkbox or status column, so S0 ticked nothing. Decided on 3 October: the DEVLOG entry is the record, and rule 3 now says so.

## Before the S2 prompt

S2 settled these; its DEVLOG entry says how.


- **SPEC's first Import step cannot run as written.** SQLite refuses the rank-1 FTS5 integrity check on a read-only or immutable connection, and `quick_check` misses an FTS index that no longer matches its content. Copy the export with the backup API to a writable `/data/index/frus.db.new`, check it there, rename it into place and serve it with `immutable=1`. On the full export, `quick_check` took 28 seconds and the rank-1 check 13 seconds.
- **List the Import steps in the S2 row.** A workable list:
  1. an explicit trigger;
  2. the backup copy;
  3. the header, rollback journal mode and `user_version = 4`;
  4. `installed_index_version` equal to `current_index_version` and to the supported version, with both FTS schema versions at 4;
  5. in phase 1, a refusal for `my_writing_included = 1`;
  6. `quick_check` and the rank-1 check;
  7. a `content_hash` self-check from `document_cache` (it matched 392 of 392 fixture rows);
  8. the rename, keeping `frus.db.prev`, and an immutable reopen.

  The TEI hash comparison needs FRUSCoreKit's indexer. The server links the kit since S8a, but the comparison is not built yet.
- **The trigger cannot be a file appearing.** A file copied in with `docker compose cp` is visible under its final name while it is still copying.
- **The owner's export is a real input for local Import trials** while it matches the pin's index version: the 3 October export did until build 50's pin move, and the build-50 exports of 13 October do since.

## Before the S7 and S8 prompts

Settled on 3 October: on a Mac, FRUS Explorer's own folder once Docker Desktop is allowed to read it (tested: 553 TEI files and 96 figure folders, read-only); on Linux, a shallow clone of HistoryAtState/frus. The published image is public. The rest stays for S8.

- **Where the TEI files come from.** Docker Desktop cannot mount FRUS Explorer's own folder (`~/Library/Containers/bottsywattsy.FRUS-Explorer/...`): macOS refuses it ("operation not permitted") because it keeps other apps out of an app's container. So `compose.yaml` mounts `./tei` by default, with `FRUS_TEI_DIR` to override. The install guide (S7) and the reader (S8) need one of these:
  - a clone of HistoryAtState/frus, whose `volumes/` folder holds TEI XML byte-identical to the app's for all 553 volumes. That worked in session 5 with the owner's real export. It lacks the figure images: the app saves them in 96 `<volume>.figures/` folders, fetched from static.history.state.gov (upstream `DownloadManager.swift`), so the reader needs another source for those;
  - the app's folder, once the owner grants Docker Desktop access to other apps' data in System Settings. Tested on 3 October: it works, figures included;
  - the server fetching each volume from GitHub on first open, with a local cache. SPEC allows this in Import mode ("or fetched from GitHub without indexing"); it is new work, and an option for S8.

  Whatever the source, TEI can drift from the index: the app and a clone both follow HistoryAtState's `master`, so a volume corrected after the Mac indexed it differs from what the index holds. SPEC's import step 5, comparing each document's hashes with its TEI, catches that; the server links FRUSCoreKit's indexer since S8a, but the comparison is not built yet.
- **The published image's visibility:** public, decided on 3 October.

## Before the S3, S4 and S6 prompts

S4 settled what concerns it here: its golden files come from a library holding only the three fixture volumes, and its summary refuses any other export. Its DEVLOG entry says how. S3 settled the four items marked as settled below, in its upstream pull request and in the owner's decisions of 4 October; its DEVLOG entry says how. S6's first pull request settled the three marked for S6; the session's DEVLOG entry says how.

- **"Every Linux change to a shared file is a guard" holds only for S1.** S3's 15 app files and S6's 48 (36,861 lines, 19 of them edited) also need declarations moved out of Apple-only files: WebKit, SwiftUI, AppKit or UIKit, and SwiftData `@Model` files. `s3-linux-edits.tsv` and `s6-linux-edits.tsv` list every change. Settled for S3: its upstream pull request moves the files into `FRUSCoreKit/` and keeps every old name, and the owner chose to land it now, while `v2` is quiet, rather than after the public release. Settled for S6: its first upstream pull request moves the indexer and search the same way, from a map of their dependencies at `af8bedab` rather than from `s6-linux-edits.tsv`. It keeps three of that list's import guards (CryptoKit, OSLog and SQLite3) and replaces its code and model guards with moves into the kit and into app extensions.
- **`String(localized:)` has no Linux form.** The S3 files use it 46 times. Settled for S3: the kit's own `Linux/LinuxFoundationShims.swift` declares it, and `autoreleasepool`, where Darwin is missing, so nothing from `shims/` enters this repository's code.
- **S3's citation matcher needs SearchService and ManifestStore,** which are S6's work. Settled: the matcher, the block splitter and `PageRangeStore` move with S6's second pull request, and `ManifestStore` stays in the app behind a one-property protocol.
- **The S3 row names no upstream pull request.** Settled: `PLAN.md`'s S3 row now names it, and the session diagram has a Mac check between S3 and S4.
- **Golden files cannot come from the owner's 553-volume library.** BM25 ranks with whole-index statistics, so 5 of 7 test queries ordered differently against a three-volume index, and person rollups span volumes. The procedure needs a Mac library holding exactly the three fixture volumes, for example under a second macOS user. The S4 summary script should refuse any other export.
- **Check 4 asks for 500 or more documents.** The fixtures hold 383 documents in 392 rows. Define check 4 on the fixtures for phase 0, and run the full check on the real TEI at S10.
- **The S6 file set reads 8 JSON resources through `Bundle.main`.** On Linux they must sit beside the executable or the test runner, or indexing degrades without an error. Settled for S6: the code it moves reads six. The first pull request passes five through `IndexingResources`: the four that change what an index holds, and the collection authority, for the related-documents alias fallback. `IndexingResources.loading(fromDirectory:)` refuses a folder that lacks one of the four. The sixth, the manifest, is the citation matcher's: the second pull request passes it through `CitableVolumeCatalogue`, which the app's `ManifestStore` satisfies, and a host outside the app gives a `FixedVolumeCatalogue` decoded from `manifest.json`.
- **`IndexingPipeline.swift` imports CryptoKit, OSLog, SQLite3 and CoreSpotlight,** and UIKit on iOS. SwiftData reaches it only through one `@Model` parameter. Its 35 logging lines compile unchanged against the Linux logging shim. Settled for S6: CryptoKit, OSLog and SQLite3 go behind `canImport`, with the kit's own copy of the logging stand-in; Spotlight and the SwiftData method stay in the app.

## Sizing

A full export is 2.83 GB, not 9.3 GB. The larger figure came from an index overhead factor of 2.8 measured on 31 May, before the 9 June change to external-content FTS tables stopped storing a second copy of the text. An export that includes the owner's writing is not vacuumed, so it can be larger, up to the size of the live file. The disk and memory figures in `PLAN.md`, `SPEC.md` and `scripts/mac-check` that rest on 9.3 GB can shrink; none matters before S10.

## Pinning until the public release

`FRUS-Explorer` merges about eight pull requests a day until its public release, and its index version went from 47 to 65 in 30 days. Each pin move means a new Mac build, a new export and new golden files. Hold the pin (at `af41efa4`, one commit past `build-51` with the same build, since S12e's pin move) until the release, unless a merged pull request for this project needs it, as S3's did, or the owner's exports come from a newer index version, as build 50's did, and batch upstream pull requests so the pin moves as few times as possible. Each pin move remakes all the golden files: those made from the app's source, and those made from the owner's three-volume export, which needs a new export from the pinned build (`COORDINATION.md`, section 5). The first such export came from a build of `af8bedab`, on 4 October. The full-corpus export for S10 comes from the build pinned at S10.

## The 1.0 pin move

22 October 2026 · a dry run for S12b, at `build-51` (`f0479037`, build 1776, index version 71), 85 commits past the pin, from [issue #37](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/37)

The submodule was checked out at `build-51` in a worktree, this package's own targets were rebuilt clean, and `scripts/swift test` ran in `swift:6.4-noble` on arm64. The pin was then restored; nothing here was committed at `build-51`. S12b made the move, and its log entry says how each item below was met.

- **The build needs no repair.** The package, the server and every kit compile on Linux with no error and no warning. No kit folder, import or `Package.swift` setting has to change.
- **Every kit suite passes:**
  - FRUSCoreKitTests 1,144;
  - SourceNoteKitTests 321;
  - FTS5StoreTests 212;
  - ManifestGeneratorTests 60;
  - SemanticVectorsKitTests 40;
  - CrossRefKitTests 10 and GeneratorKitTests 7.

  The only skip is FTS5StoreTests' backup-exclusion test, which CI already allows. #1698's cancellation suite runs and passes on Linux.
- **What fails is what a pin move expects,** all in the web edition's own tests:
  - `CompatibilityTests`: the pin's index version is 71, and `Compatibility.swift` says 69. So the fixture index, now stamped 71, is refused at import, and every API parity test that imports it (check 3 through the API, the facets, the date order, the reader's links, Browse) stops at `waiting_for_export`.
  - `APITests.theSubmodulesDataFilesLoad`: `ServerResources.requiredFiles` holds 6 files, not 5, with `cited-page-map.json`. `IndexResourcesTests` lists the four index files by name, and `indexResourceNames` now has five.
  - `SummarizerTests`: the export's build is not 50.
  - Every golden file is stale: the source digest moved from `24382592d086` to `096499b657e5`.
  - `ParseParityTests`: 61 of the 482 queries parse differently, from parser 6.8 (#1770), which drops the marks at a term's ends.
  - The renderer's parity tests: the three fixture volumes now give 393 rows, not 392, so the rendered rows and the golden rows no longer line up. #1746 stores rows for a heading's footnote and for prose the index left out, and the index parity test sees the same 393 `document_revisions` rows.
- **Left to S12b with the 1.0 export:** whether the 393rd row's HTML and the other rows match the remade golden files; check 3's results with the new snippets; the index summary's digests; and the export's schema, whose `CREATE TABLE` statements the kit's diff does not change.

## Serving the page-map landing

23 October 2026 · for the pin move past [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784), merged that day as `af41efa4`: S12d's, or one of its own

S12e, a pin move of its own, served it the same day, as below; its log entry says how, and what the browser app shows.

S12c moved where a page link and a whole-volume link go, `PageLink` and `WholeVolumeLink`, into FRUSCoreKit's `TEI/FRUSURLScheme.swift`, unchanged but for `public` and `Sendable`. At a pin that holds it, the server can serve the landing #1778 gave the app:

- **The rule:** in `ReaderLinks.swift`'s `.page` case, ask `PageLink.destination(page:volumeId:citing:onDevice:store:map:)`, with `onDevice` whether the served index holds the volume, `store` the served index's `PageRangeStore`, and `map` the bundled `cited-page-map.json` decoded as the kit's `CitedPageMap`, once per process. `IndexingResources.citedPages` is internal, so the server decodes the file itself, from the folder `ServerResources` reads.
- **`.document`:** the destination, as a cross-reference to that document lands; a volume without its TEI here gets the notice a document link into such a volume gets, with the document's page on history.state.gov, where the app offers the download.
- **`.volume(volumeId:page:)`:** the volume, as `WholeVolumeLink` sends a whole-volume link, which the server can now answer for the browser app: Browse for a catalogue volume, with a line naming the page in the words of the app's `FollowedPageLink.notice`, "You followed a link to page N of this volume, which isn't downloaded", made the server's; history.state.gov otherwise.
- **The tests:** `ReaderLinkParityTests.everyPageLinkIntoAnotherVolumeIsWhereTheIndexStoresIt` expects no destination for the fixtures' 31 links into other volumes; at that pin it should expect the map's document for the 19 it names, 17 of which the index stores under rule C, and the volume for the other 12.

## Phase 2

23 October 2026 · read at the pin, `af41efa4` (1.0, build 1776, index version 71), for `PLAN.md`'s phase-2 rows

Each claim below sizes a row of phase 2. Paths are in the app's repository unless they start with `Sources/`, and line numbers are at the pin. Nothing was built at the pin but one check of Linux's Foundation.

| Claim | Result |
| --- | --- |
| The JSON export's version and types | `ResearchDataExporter.currentFormatVersion` is 6 (`FRUSExplorer/Export/ResearchDataExporter.swift:523`). The envelope carries 15 of `frusModelTypes`' 23 types: notes, tags, tag assignments, highlights, collections with their entries, user prompts, projects, summaries (only with Include AI-Generated Summaries on), the three trails, and archive visits with their documents and targets |
| The envelope can move into the kit unchanged | Its DTOs (lines 13–488) are internal Foundation `Codable` structs in a file that imports SwiftData and SQLite3; only `makeEnvelope(modelContext:)` reads SwiftData. The five types they name are Foundation-only: `ResponseFormat` and `StructuredSummarySchema` (`FRUSExplorer/Models/SupportingTypes.swift`, public already), `SummaryAuthorship` (`Models/GeneratedSummary.swift:227`), `ArchiveVisitTier` and `ArchiveVisitDeliverables` (`Models/ArchiveVisitPlan.swift:519`, `538`, in a file that imports CryptoKit and SwiftData). `ResearchDataExporterTests`' `legacyJSONDecodes` and `exportJSONDataKeysMatchSchema` pin the decoder and the key set, and `SummaryProvenanceExportTests` reads the exporter's own source, so it is re-pointed by the move. No document in the app's repository plans an importer or a version 7 |
| What version 6 drops from the types it carries | A note's `richText` (`ResearchNoteExport` has only `bodyText`); a project's `defaultUserTagIds` and `leadAxisWeights`; a summary's `isHeadnoteDraft` and `sourceContentHash`; and a collection's source. `CollectionExport` keeps a name, a note, project ids, the saved search's id and the entries, and `CollectionEntryExport` only an entry's document, order and notes. Headings, prose and apparatus blocks are entries whose `documentId` is "" (`Collections/CollectionEditorView.swift:1850`, `Collections/CollectionEntryData.swift:318`), so 6 writes each as an entry with no document, and an excerpt as the document it quotes |
| `.fruscollection` holds a collection's source | Its file struct and its coding are pure (`Collections/NativeCollectionFormat.swift`, format version 2, which a reader at 2 opens when `minimumReaderVersion` allows), but `makeFile` takes a SwiftData `Collection`, and `apply` a `ModelContext`. It leaves out ids, timestamps, project ids, the saved search, `selectedHighlightIds` and `selectedNoteIds`, and carries notes only when the export sheet says so. It keeps the device-local `headnoteSummaryId` and `summaryPromptIdOverride`, and does not write an explicit headnote Off |
| Linux reads no RTF | Checked in `swift:6.4-noble`: `NSAttributedString` exists, but neither `NSAttributedString.DocumentType` nor `init(data:options:documentAttributes:)` does. The app writes a note's and a prose block's RTF through `NSAttributedString` (`Collections/CollectionRichTextEditor.swift:89`, `96`, `767`), with bold, italic, underline, text colour and links, and its exporters read spans back with `CollectionProse.paragraphs(fromRTF:)` (`Collections/CollectionExporter.swift:1349`), from NSFont or UIFont traits and NSColor or UIColor. No export reads a note's `richText`: the Markdown, JSON and collection exports all use `bodyText` |
| The reader's annotation scripts | `kOffsetEngineJS` (27 lines of script), `kHighlightsJS` (81) and `kSelectionJS` (141) are in `TEI/FRUSWebViewConfiguration.swift`, which imports WebKit; the first two are `private`. The app injects them at document end in the main frame and registers `selectionChanged`, `selectionScrolled` and `highlightTapped`. Nothing loads the copies in `Resources/`: `frus-highlights.js` still lacks `highlightTapped`, `frus-offset-engine.js` differs only in comments and spacing, and `SelectionScriptParityTests` keeps `frus-selection.js` identical to `kSelectionJS`. `kHighlightsJS` paints with the CSS Custom Highlight API and calls `document.caretRangeFromPoint` (line 167) |
| A highlight's offsets and staleness | Offsets count UTF-16 units over `.frus-document`'s flat text, skipping `data-skip`, with `<br>` as a newline; the kit's public `buildFlatText` (`FRUSCoreKit/TEI/FRUSRenderNode.swift:628`) is the Swift twin, held to the script in WebKit by `FigureReaderTests`. `DocumentHighlight.HighlightDTO` (`Models/DocumentHighlight.swift:158`) is what `FRUSHighlights.render` reads: offsets, a colour (yellow, green, blue or pink) and `isStale`, a stored `renderingVersion` that is not the page's. `HighlightColor` is internal in the kit |
| `renderingVersion` is shared already | `ASTToRenderNodeConverter.renderingVersion(for:)` (`FRUSCoreKit/TEI/ASTToRenderNodeConverter.swift:177`) is public, and the server already sends it as `X-FRUS-Rendering-Version` and in the page's ETag (`Sources/FRUSLightAPI/Reader.swift`) |
| The web's reader frame is ready for the scripts | `/reader/host.js` already defines the three WebKit handlers as `postMessage` calls, and the page's policy allows `script-src 'self'` alone, so the kit's scripts can come as the server's own files. Nothing sends highlights in yet |
| Re-anchoring and review are app code | `HighlightReanchor.locate(passage:storedStart:storedEnd:in:)` is pure over a page's blocks, through the kit's `flatTextExcerpt(blocks:)`, in a Foundation file that extends the app's SwiftData-bound `HighlightReview`. `AnnotationReview` is a `@Model` ledger, and the banner and the 1,097-line review sheet are SwiftUI. The kit marks a revision reviewed by writing `reviewed_at` into the index, which the server serves immutably |
| The search's user half reads the index | `IndexingPipeline`'s private `matchCTE` (line 4184) unions `SELECT rowid AS docrowid, bm25(user_content) AS score FROM user_content WHERE user_content MATCH ?` with the corpus half. Its private `filterConditions` (line 5171) filters tags with a `LIKE` over `document_cache.user_tag_ids`, and the exact-word filter reads `summary_text` and `note_text`; row tags, `userTagCounts` and three other readers read `user_tag_ids`. The read-only open attaches nothing. Reading user text from `app.db` is an upstream change to private SQL |
| Saved searches keep the kit's parameters | `SavedSearch.parametersData` is the kit's public `Codable` `SearchParameters`, JSON-encoded, with the legacy columns still written. "+N since last run" is `SavedSearchFreshnessEvaluator` (`Search/SavedSearchFreshnessEvaluator.swift:49`, SwiftData and `@MainActor`): the count now less `matchCountAtLastRun`, shown only above zero |
| Corpora, scopes and projects | A working corpus becomes `documentIds`, a custom scope `volumeIds`, and Project Focus's "only new" `excludeDocumentIds`, each resolved in app code (`WorkingCorpusResolver`, `DocumentScopeGate`, `CustomScopeResolver.indexedResolution`, `runningInside(workingCorpus:)`); `SearchService.matchKeys(parameters:)` is public. The active project is device-local, in `UserDefaults`. Suggested Next is `ProjectLeadsService` over the app's `RelatedDocumentsEngine`, which needs `AppState` and the semantic vectors |
| The method appendix is app code | `QueryMethodAppendix` imports only Foundation but names `SearchHistoryEntry`, `WorkingCorpus.CaptureTruncation`, `EngagementCoverage`, `CorporaAxis`, `SearchScopeSignature` (CryptoKit) and `ProvenanceStatement`, and reads `Bundle.main`. Its CSV has 12 columns, and `count_basis` is exact, floor, complete or unrecorded |
| Corrections reach search through the index | The kit's `applyClassificationOverrides` (line 12903) updates `document_cache.is_editorial_note`, which search, its facet and the reader read; a person merge rebuilds the rollup through the kit's internal `consolidatePersonRollup`. The server's immutable open refuses both writes, so a correction made on the web needs an overlay or a new index |
| Citation Lookup's Batch and Structured are internal | `CitationLookupFields`, `CitationBlockSplitter`, `BatchCitationOutcome`, `BatchCitationRow`, `BatchCitationRunner` and `ConfidenceLabels`. The matcher, the parser and `CitationMatch`, with its confidence label, are public |
| Collections are app code | `FRUSCoreKit/Collections/` holds only the Add Documents line resolver. `CollectionContentResolver` is 1,785 lines, `@MainActor`, over `AppState` and SwiftData; the exporters are 5,300 lines: `CollectionExporter` 1,699, the HTML renderer 1,209 and its wrapper 94, Word 2,149, BibTeX 72 and RIS 77. The HTML renderer is already a string builder, whose one SwiftUI use is the reader's CSS, which the kit's `ReaderPage` gives; the Word exporter imports only Foundation and writes its own ZIP. The apparatus blocks resolve through a protocol the resolver implements. All 332 tests in `CollectionTests.swift` import the app |
| Synced preferences | `SyncedPreferences` holds the word-cloud tuning, `citationStyleRaw`, `defaultDocumentModeRaw`, `researchLoggingEnabled` and `listOrderJSON` |

Two things follow for the sessions. Check 6 needs no Mac on the fixtures, since offsets placed over `buildFlatText` test the web's page through the kit's own offset engine. And a pin move past a phase-2 upstream pull request remakes the golden files like any other. Of the seven, only S17a touches a file on COORDINATION §5's list, `IndexingPipeline.swift`, and it changes a search's statements, not what is indexed, so the owner may let the last three-volume export serve, as S13c's pin move did.

## Files

| File | What it holds |
| --- | --- |
| `s1-linux-guards.patch` | The S1 guards. It applies with `git apply` to `FRUS-Explorer` at `34a5120`: 15 files and 92 added lines, each inside a `#if canImport` guard, plus a new Linux-only `FTS5Store/LinuxLogger.swift`. With swift-crypto and `CSQLite` declared Linux-only, TEIHeaderKit, SemanticVectorsKit and FTS5Store build on Linux with no warnings. SemanticVectorsKitTests (35) and ManifestGeneratorTests (60) pass, and FTS5StoreTests passes 208 of 209 |
| `s3-linux-edits.tsv`, `s6-linux-edits.tsv` | Every change it took to compile the S3 and S6 file sets on Linux, one per line: the kind (import-guard, code-guard, model-guard, move, shim, stub or dropped), the file and the detail. `s3-linux-edits.tsv` is superseded by S3's upstream pull request, which makes those changes upstream, and `s6-linux-edits.tsv` by S6's two, which move the indexer, search and the citation matcher where the list guarded them; both stay as records |
| `shims/` | Linux stand-ins for `autoreleasepool`, `String(localized:)` and the Keychain store, from that build. They are scratch work. The first two are superseded by S3's upstream pull request, whose `FRUSCoreKit/Linux/LinuxFoundationShims.swift` declares them. `KeychainShim.swift`, the `KeychainStore` stand-in in that build's S6 file set, is not needed: S6's pull request keeps the Keychain store and the NARA client out of the kit. None of them goes into this repository's code: a stand-in belongs upstream, beside the code it serves |
