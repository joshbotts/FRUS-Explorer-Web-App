# Development log

One entry per session, newest first.

## Session 18d: collections and their editor

28 October 2026 · branch `claude/inspiring-volhard-81ec2e` · [#86](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/86) · upstream `32e295e5`, unchanged

Phase 2's row S18d, the first of the collection rows S18c's pin move opened. The Collections tab lists the user's collections and makes, duplicates and deletes them; the editor builds one as the app's does, sections three deep, documents, note blocks in S15d's rich text, excerpts frozen from the reader's selection or a highlight, and the five apparatus blocks, with the per-document inspector, a section's defaults, the presets and the order by date; the reader's selection bar has Excerpt, and the Research rail its Collections section. Each rule is the kit's code where #1807 and #1809 moved it there, and app code mirrored, held to the app's source, where it is the editor's. No upstream pull request, no pin move and no schema change: the rows are migration 2's, written as the import writes a Mac's record and read as the export reads one, so a collection made here travels in the JSON export as the Mac's does. One part of the row waits: Add Documents' Citations and Tags, which read kit code kept internal, so they need an upstream pull request first.

**What the kit gives,** at `32e295e5`, from FRUS-Explorer#1807 and #1809:
- `CollectionOutline`: a heading's resolved depth, its section's range, a move's new order and a section's overrides, three levels at most.
- `CollectionPreset` with its `recipe` and `apparatusBlocks(notAlreadyIn:)`; `CollectionBodyDepth.available(summariesAvailable:)` and `resolve`; `CollectionFootnoteStyle`'s flags.
- `CollectionGeneratedBlockType` with its `defaultPosition`, the chronology at the front; `CollectionEntryKind`, with `unrecognized` for an entry a newer build wrote.
- `CollectionEditorNaming`: a row's name, the list's order and the untitled section.
- And from earlier pins: `flatTextExcerpt` and `renderingVersion(for:)` for an excerpt of the page, and `HistoryAtStateCitationFormatter` for the inspector's derived title.

**Delivered**

- **The store** (`Sources/FRUSLightCore/UserCollections.swift`): `CollectionStore` over migration 2's `collections` and `collection_entries`, on both stores: a collection read and made with its entries; changed in one write that reads them, asks the API what they become and writes only the columns that differ, adding and deleting entries, so a rule that moves or renumbers many changes all or none; deleted with its entries; and the collections holding a document among their documents. An entry deleted takes its headnote draft with it, as every delete in the app's editors does, never a document's own summary an entry chose; a collection's write adds a headnote draft alone, refusing any other summary, so no collection write changes what the search reads, and none moves the search mark.
- **`/api/v1/me/collections`** (`Collections.swift`): the list, the most recently changed first; New Collection, in the project the user works in; a collection with its entries, each with its depth in the kit's outline and what its row shows; a change of its own fields, filing it under the project worked in as the app's `recordEdit` does; Delete; Duplicate, the app's `Collection.duplicate(in:)`; a preset, offered by the kit's rule; and `GET /api/v1/me/volumes/{v}/documents/{d}/collections`, for the rail.
- **The entries** (`CollectionEntries.swift`): Add Documents' add and the picker's, which a collection holding the document takes no second time; a heading, a note block and an apparatus block; an excerpt frozen from the page's version or from a highlight's passage; Move, a heading carrying its section; Sort by Date across the collection or within each section; an entry's change, the inspector's inclusions among them; Delete, Delete Section, Indent and Outdent, each where the kit's outline allows it; and the inspector, with what each Default resolves to.
- **The editor's rules** (`CollectionEditing.swift`), the app's, mirrored: its appends, deletes and moves, the outline's normalization and indent rules, `CollectionEntryOrdering` and `sortedByDate`, the appends of `CollectionDocumentDiscovery` and `CollectionExcerpts`, the duplicate, `SmartCollectionRule`, a preset's fields and `matches`, and the inspector's selections and resolved defaults.
- **The browser app:**
  - the Collections tab (`/collections`), in the header on a server that keeps user data: the list, with the app's project banner and Show All; New Collection, the Mac's sheet; Duplicate; and Delete…, which asks first;
  - the editor (`/collections/$collectionId`), the iPad's: Add, a menu with the five apparatus blocks named as the app's submenu is; Sort by Date; Collection settings, the iPad's sheet, each field saved as it is typed; and Contents, each row the app's, a collapsed heading hiding its section, with a menu for what the app's context menu holds;
  - a note block and the introduction in S15d's editor, a note block plain at rest and edited in place;
  - Add Documents, with Search and Browse, and Add Highlighted Passages…;
  - the inspector, for a document and for a section's defaults;
  - the selection bar's Excerpt, between the colours and Note, and the Add to Collection picker in both of its modes;
  - the Research rail's Collections section, closed until it is opened, after Tags;
  - `shell/MenuButton.tsx`, the WAI-ARIA menu button the editor's menus share.

**Decided here, each the web's own**

- **Briefing packet where a summary is stored.** The kit offers Briefing packet, and the Summary only depth, where summaries are available, which the app answers from its generation; this server generates none, so it answers whether a document of the collection has a summary stored that is no draft. S18f refuses the depth where a document has none, with the app's reason.
- **New Collection is the Mac's sheet.** The iPad makes an untitled collection and opens it; the web names one first, as the Mac's sheet does, and the picker's New Collection uses the same sheet.
- **Delete… asks first.** The app deletes a collection by a swipe; a button that deletes at once would be too easy to press by keyboard.
- **Menus for the context menu, and Move Up and Move Down for the drag.** Each row's menu holds what the app's context menu does, and Move Up and Move Down, by the outline's rules, move a heading with its section, a collapsed one hopped whole, where the app drags.
- **A note block is plain at rest.** The editor opens on Edit, or at once for a block just added, and saves as it is typed, half a second after the typing stops or when it is left; the formatting is S15d's.
- **A collection's changes go one at a time, and each shows at once.** The browser sends a collection's changes in turn, each once the one before is answered, and the server's answer is the copy. A switch, a checkbox or a choice shows what was chosen in the moment it is chosen (`chosen.tsx`), and the collection held shows each change until its answer stands, an answer to an earlier change shown with the later ones over it, so a second press reads the first; a refusal reads the collection again.
- **Move Up and Move Down are worked out as they are sent,** from where the moves before them left the row, so a second press before the first is answered moves the row on, and focus a move takes from a row React places anew goes back to its menu.
- **What a change stamps.** A collection's `lastModified` moves when its own fields change or an entry joins or leaves it, and an entry's when it changes, so the list's order is the app's.
- **An entry a newer build wrote stays.** The app's row for one offers nothing, and the server refuses its deletion.
- **The rail's names open the editor, and its header counts them.**
- **The inspector's New Note… and headnote card wait for S18f,** which brings headnotes the researcher writes; the live preview beside the outline waits for S18e's exports.
- **What the server cannot keep it refuses.** A collection's or an entry's text may not hold U+0000, where SQLite's text ends, or pass a note's 1 MiB, as a note's may not; null clears a note, subtitle, author line or title override and is refused for a field that cannot be none; and Summary only, set field by field where Briefing packet's card is refused, is refused as the card is, a depth the collection holds standing.
- **An add past the highest position renumbers first.** The app appends one past the highest position, which an import of an edited file can set at `Int.max`; there the app's arithmetic would trap, and on a server every user shares, so the entries are renumbered in their order first.
- **A draft the server cannot read is left out of a copy.** The app copies an entry's headnote draft whatever it holds; a draft row the export's reader cannot read the web's copy cannot copy, and shared, a delete of either entry would take the other's, so the copy's entry has none.
- **An excerpt holds text.** Where the page's flat text has none between the offsets, as for a selection of spaces, the app freezes the raw selection; the web refuses it, and offers Excerpt for no footnote, by the kit's rule.
- **The inspector's summary is the newest** where none has the collection's prompt, where the app takes the first its fetch returns, in no order it sets.
- **Citations and Tags wait upstream.** Add Documents' Citations tab reads the kit's `CollectionCitationLineResolver`, and its Tags tab the kit's `CollectionGeneratedBlocks.tagDocumentRefs`, both internal to FRUSCoreKit at `32e295e5`. A copy of either would break CLAUDE.md's rule 4, so the sheet has Search and Browse until a pull request on FRUS-Explorer makes them public and a pin move takes it.

**Tests**

- **FRUSLightCoreTests,** 162 to 167: `UserCollectionTests`, 5 on each store: a collection made and read with its entries, the user's alone, and the writes refused, a summary that is no draft among them; a change that writes what differs, adds and deletes entries and takes a deleted entry's draft but never a document's own summary, and leaves the search mark; a collection deleted with its entries and drafts; the collections holding a document; and the notes counted and the summarized documents found by document, without reading either.
- **FRUSLightServerTests,** 211 to 219: `CollectionTests`, 8, on a real socket, the eighth the server's own refusals, clears and edges below: a collection made, listed, changed and deleted as the app does; sections three deep, moved and indented as the editor moves them, with the outline's refusals; documents, excerpts, a highlight's passage and the apparatus added as the app adds them; the presets and Sort by Date over the index, Briefing packet only with a summary; the inspector; the duplicate; and the rail's list, each user's collections apart.
- **FRUSParityTests,** 206 to 209: `CollectionParityTests`, 3: every Mac word the web takes, about 220, under its key in the app's source and in copy.ts's block; the server's mirrors of the editor's rules; and the browser app's.
- **The web unit suite,** 392 to 427 tests in 42 to 45 files: `EditorChanges.test.tsx` (7: focus back to what opened a sheet, and kept on a row Move Down moves; a second Move Down worked out from the first; a switch shown as it was turned before the answer, and a second press read from it; a refused title kept and sent again; a lower-case address; a note block edited plain; and the picker pressed twice); `collectionRules.test.ts` (13: the list's scope, the rows Contents lists and their indents, Move Up and Move Down, a row's chips, the pickers' depths and the picker's order and search) and `Collections.test.tsx` (14: the list, its banner, New Collection and Delete…'s focus; the editor's Add, its rows and menus, a heading saved as typed and a note block; the inspector; Add Documents; and the picker in both modes); the selection bar's Excerpt; and the tests that count the bar's verbs and the rail's sections.
- **The browser suite,** 57 to 61 tests, at the root and under the path: `collections.spec.ts`, with axe, makes a collection three sections deep by keyboard, with documents, a note block and an apparatus block, orders it and deletes it; offers the presets, Briefing packet once a document has a summary; freezes an excerpt from the selection bar into a collection the picker makes, adds the document from the rail, and configures it and its section by pointer; and duplicates a collection and deletes the copy. `import.spec.ts` opens the collections the Mac's export brought in the editor. Each test leaves the store as it found it.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** with `scripts/swift --postgres`, PostgreSQL 18: the build gives no warning. All 2,596 tests pass, up from 2,580 on `main`, with the one named skip and nothing cancelled: FRUSLightCoreTests 167, FRUSLightServerTests 219, FRUSParityTests 209, FRUSCoreKitTests 1,299, the others as on `main`.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 427 tests in 45 files. The app's script is 668 kB, from `main`'s 597 kB, which already passed Vite's 500 kB warning.
- **The fixes' tests bite:** with the saver and the picker as they were before the review, the refused title's test and the picker's fail, and pass again with the fixes. The switch's passes either way in jsdom, which shows no moment between a press and the collection held showing it; it holds the second press, read from the first.
- **The browser suite,** over an image of the branch under a tag and port of its own (`frus-light:s18d`): `collections.spec.ts` passed its 4 tests on the first run, and again on the same store, around `import.spec.ts`, as the run under the path finds it; and on the pull request, CI's `scripts/compose-smoke --e2e` passed the browser suite's 61 tests at the root and 61 under the path, and the sign-in phase and its spec, before the review and after it.
- **A review** read the diff cold, the server's and the browser app's apart, with the pull request open as a draft. Each of the server's ten findings and the browser app's fourteen was checked against the code before it was fixed. Every one held, and each is fixed but one, an excerpt of a selection with no text, which the web refuses by its own choice (Decided here):
  - **the server could be brought down:** an add after an entry an edited import left at `Int.max` trapped on the position one past it, and a trap ends the process every user shares (Decided here);
  - **an add's `entryIds` could name another request's entries,** read before the write; they are read inside it now, and Sort by Date reads its dates again when another request added a document meanwhile;
  - **Summary only could be set field by field** where Briefing packet's card is refused; it is refused as the card is now;
  - **a text field took U+0000,** which SQLite cuts at, and had no limit; both are refused as a note's are;
  - **null was read as absent,** so it neither cleared a note, subtitle, author line or title override nor was refused for a field that cannot be none;
  - **each answer read every note and summary whole** to count notes and find summaries; the store counts them in SQL now (`noteCounts`, `summarizedDocuments`), on both stores;
  - **a duplicate could share a draft it could not read,** and an entry a newer build wrote could be moved; neither can now;
  - **the inspector's summary** was said to be the first stored where it is the newest, and the comment says what the web does;
  - in the browser app: **three sheets dropped focus to the page's body** when they closed, as did Delete Section when the server refused it; **Move Down dropped focus,** React placing the row anew, and a second press before the first was answered moved the row from where it had been; **the editor's heading took focus while it still said Collections**; **a refused save lost the edit**; **the picker, and Insert as Excerpt, added twice** when pressed twice; **controls a press replaces dropped focus** (Insert as Excerpt, Add a note, Browse's volumes and Volumes); **switches and choices showed the old value until the answer,** and a second press sent the first again; **a refused Section body went unsaid**, an unhandled rejection; **a new entry a collapsed section hid took focus when the section opened**; **the browser spec waited for Added,** which shows for 0.6 s; **a collection opened by its id in lower case showed no change**; **Add a note's name did not hold its words** (WCAG 2.5.3); **a note block or introduction the formatting editor could not show was shown altered,** where it now opens plain, as a note does; and **a second add of one document went unsaid.**

**Next:** S18e, a collection's preview and exports: the kit's HTML export of the first 20 documents with Render All, HTML, Word, BibTeX and RIS, the excerpt check before each, and each export kept in the history.

## Session 17f, follow-up: Project Home's subjects and a lead's line, upstream

28 October 2026 · branch `claude/admiring-bardeen-a3d5e2` · [#85](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/85) · upstream `32e295e5`, unchanged; [FRUS-Explorer#1813](https://github.com/joshbotts/FRUS-Explorer/pull/1813), open

S17f ([#84](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/84)) gave each user the Mac's Project Home and left two of its parts out, since the kit code that makes them is internal at `32e295e5`: the Focus subjects, with the editor they open, and the line under each lead in Suggested Next. S17f's session asked for the pull request that makes that code public: `claude/project-home-subjects-and-snippets-public`, cut from `v2` at `d7130e9b` (#1812, which adds a plan under `Planning/` and nothing else), labelled `Mac`, its body saying "Mac verification requested", and not merged. Under rule 4 it changes shared files, and this repository changes only its records. S17f's own records, written meanwhile and merged before this entry, put one more piece in the same pull request, the head the app titles a visit by, so it gained a seventh commit after its first runs, and an eighth, the head's host-style test, which S17f's session then asked for; the whole check ran again at each.

**What the two views read, found before anything changed:**
- **Project Home's Focus subjects** (`ProjectHomeView.focusSubjectsSection`) are the kit's `VolumeSubjectProfiles.allSubjects`, from the bundled `volume-subject-profiles-index.json` through the app's loader, `VolumeSubjectProfilesStore`, filtered by the project's `defaultSubjectTagIds`: each chosen subject's name, in the vocabulary's order.
- **Their editor** (`ProjectFocusSubjectsEditor`) lists the same vocabulary, each subject with its category, subcategory and the number of volumes it reaches, and above it "Suggested from your volumes": `ProjectFocusSuggestions.suggestions(engagedVolumeIds:profiles:excluding:limit:)`. That rule is pure, over the kit's type, but it was the app's, so making the vocabulary public alone would have left the server to copy it. The engaged volumes it starts from are `ProjectEngagedDocuments`', which reads SwiftData.
- **A lead's line** (`ProjectHomeView.loadLeadSnippets()`) is `IndexingPipeline.documentSnippets(forKeys:)`: the summary in the index's `summary_text`, or else the document's text from its head on, folded and cut at the last word within 240 characters.
- **A visit's head,** which S17f's History needs: the app titles a visit by `DocumentDisplayTitle` over the head `IndexingPipeline.extractHeader(from:)` reads from the parsed TEI (`DocumentViewModel.load`), internal too; S17f takes the reader's TEI title meanwhile for a document the index does not hold.

**#1813, in four commits, a commit of the review's fixes, a records commit, a seventh commit with records of its own, and an eighth commit, a test:**
- `VolumeSubjectProfiles`, its decoding, `allSubjects` and `SubjectOption`, with its five fields and `id`, public. `ResolvedSubject`, the per-volume queries and the reverse index stay internal, and the loader stays in the app.
- `ProjectFocusSuggestions` moved into the kit, `FRUSCoreKit/ProjectContext/`, public, its body unchanged, keeping its file name, which the app's scan of the arithmetic on a subject's score names.
- `IndexingPipeline.documentSnippets(forKeys:maxLength:)` public, its doc saying that the summary it prefers is the index's own column.
- `IndexingPipeline.extractHeader(from:)` public, in the seventh commit, its body unchanged; the indexer stores what it returns as `header`, as before.
- `ProjectHomeHostTests`, a kit suite, calls all three as a host does: the vocabulary from a fixture and from the bundled file, the editor's suggestions with their default of eight, and the lines over the app's index and over a copy stripped with `ResearchDatabaseStrip.steps` and opened read-only, where every line is the document's text; and, in an eighth commit, which S17f's session asked for, the head a visit is titled by, from the parsed TEI, which is the header the index stores. `FRUSCoreKitTests` goes from 1,299 tests to 1,307.

**How it was checked,** each heavy job under the app's lock, from a clone at a real path, beside `v2` at `d7130e9b` built and run the same way the same evening, Xcode 27.1, clean and unsigned, on an iPhone Air simulator (iOS 27.0), first at the fifth commit, with the review's fixes:
- **The full iOS unit run:** 7,761 tests in 930 suites against `v2`'s 7,754 in 929, both failing only the 8 Keychain tests an unsigned build fails, with the same 6 known issues and the same 17 tests and 2 suites skipped. The kit's boundary test, the EditableContent ranges, the coding-standards audit, the score scan and the lead-snippet source checks passed.
- **`swift test`:** 3,199 tests in 390 suites against 3,192 in 389, all passed; `FRUSCoreKitTests` 1,306 in 178. Each commit before the head built the kit.
- **The Mac app's symbols** are `v2`'s, 251,932 normalized names on each, none removed or added, raw or normalized; both builds had `v2`'s five and seven warning lines.
- **On `v2`'s code,** the new suite passed in Xcode, where the app compiles the kit into its own module, 7 tests of 7; against the kit alone it did not build: "cannot find 'ProjectFocusSuggestions' in scope".
- **Linux,** in a scratch worktree of this repository's `main` at `3cef58e` (the pin `32e295e5`), with `v2` and then the branch copied over the submodule, each built clean:
  - at `v2`, 2,565 tests, all passed, since `v2` differs from the pin only under `Planning/`, which the golden files' digest leaves out;
  - at the branch, 2,572: `FRUSCoreKitTests` 1,306, the new suite passing, and every other target as at `v2` but the parity suites' 21 issues, all the golden files' staleness, since their source digest hashes `FRUSCoreKit/` and `FRUSExplorer/` whole;
  - skipped at both, the one named skip and the PostgreSQL store's seven tests, which need the database `scripts/swift --postgres` gives and this run did not.
- **Public access:** a scratch file in `FRUSLightAPI`, never committed, imports FRUSCoreKit without `@testable` and uses every name the pull request makes public, as Project Home will. It built over the branch. Over `v2` it did not: "cannot find type 'VolumeSubjectProfiles' in scope", "cannot find 'ProjectFocusSuggestions' in scope" and "'documentSnippets' is inaccessible due to 'internal' protection level".
- **Again at the seventh commit** (`76b92f2d`): both builds and the symbols as before; the full iOS unit run 7,761 tests, failing only the 8 Keychain tests; `swift test` 3,199 tests, all passed; and on Linux the same 2,572, only the golden files' staleness failing, with the public-access file handing `extractHeader(from:)` a parsed document's nodes too.
- **Again at the eighth commit** (`f5149034`), which adds the head's test: the symbols `v2`'s; the full iOS unit run 7,762 tests in 930 suites, failing only the 8 Keychain tests; `swift test` 3,200 tests, all passed, `FRUSCoreKitTests` 1,307; on `v2`'s code the suite's eight tests passed in Xcode and the kit alone could not build it; and on Linux 2,573 tests, only the golden files' staleness failing.
- **A cold review** read the diff with none of the session's conclusions. It found no change of behaviour, no scan the move breaks, and the project file byte for byte what XcodeGen writes. It found that the docs and the suite said a host gets the app's lead line, which it cannot (below); that the editor's default limit and the bundled file's counts were not held by the suite itself; and that one test checked its own copy of `ProjectHomeView`'s filter. The fifth commit fixes those, and the whole Mac check and the Linux run were repeated at it.

**What the pin move past it brings:**
- **The golden files need `scripts/make-golden`,** since their source digest hashes `FRUSCoreKit/` and `FRUSExplorer/` whole. On §5's indexing path `IndexingPipeline.swift` changes in two declarations' access, their docs and the file's version history; `extractHeader(from:)` is the indexer's own, and what it stores is unchanged, so the seventh three-volume export may be used again, by the owner's choice.
- **No parity test needs pointing anywhere:** over `main` with the branch copied in, every parity check that reads the app's source passed. None reads the moved file's old path or the lines this changes.
- **`Package.swift` needs no change:** the kit's new `ProjectContext/` folder is compiled by the kit's path. The CI's allow-list needs none either: the suite skips nothing.

**What Project Home's follow-up does with it,** after that move (the shared notes have the detail):
- the server decodes the vocabulary from the image's copy of `FRUSExplorer/Resources`, which already holds the file, and Project Home's answer gains the focus subjects, filtered as `ProjectHomeView` filters them, a mirror held to its source;
- the editor's three sections and their words, its suggestions from the kit's rule over the volumes the project engages, which are `ProjectEngagedDocuments`' rule mirrored on the server, not `DocumentEngagementService.gather`'s, which counts highlights too; and the project's `defaultSubjectTagIds` written through `PATCH /api/v1/me/projects/{id}`;
- a lead's line from the served index's `documentSnippets(forKeys:)`;
- and, in History, a visit to a document the served index does not hold titled by the kit's `extractHeader(from:)` over the parsed TEI, with `DocumentDisplayTitle` as the app's reader titles it. The app's number falls back to `extractDocumentNumber(from:)`, still internal, where a document has no `@n`; every shipped document has one.
- **One difference stays,** filed in the pull request: the served copy never holds a summary in `summary_text`, so a lead the user has summarised shows its opening text on the web where the Mac shows the summary. A `userSource:` as `semanticResultRows(forKeys:userSource:)` has would close it, once measured over `user_search`, whose `user_id` FTS5 does not index.

**Delivered here**

- `COORDINATION.md`: the pull request in §2, and in §5's list of app changes the web edition needs.
- This log.

**Notes**

- **The scope grew twice.** The brief named `VolumeSubjectProfiles` and `documentSnippets`. Reading the editor found its suggestions to be app code, so the pull request moves them into the kit too, unchanged; S17f's session was asked before the runs, with that move as the default and the summary's difference left as a follow-up, and had not answered when the pull request opened. Then S17f's records, merged while this ran, put `extractHeader(from:)` in the same pull request, which its seventh commit does; S17f's session then asked for it directly, with a host-style test, the eighth.
- **Scratch:** under `~/Library/Caches/frus-project-home-kit`: the clone and its `v2` and commit worktrees, the logs and scripts, the drafts, and a scratch worktree of this repository (`web-linux`) with the public-access file.

**Next:** the owner's Mac check of FRUS-Explorer#1813 and its merge; then a pin move of its own, and Project Home's focus subjects, their editor and a lead's line. On the plan's track, S18d.

## Session 17f: projects, the history and the method appendix

28 October 2026 · branch `claude/jovial-albattani-6a881b` · [#84](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/84) · upstream `32e295e5`, unchanged

Phase 2's row S17f, the third of the search-and-research rows that S17c's pin move opened. A user works in one project at a time, chosen in the header, with the Mac's Project Home for it; the trail records the documents they visit and the searches they run, with the Mac's capture fields, and the History screen, the Session Log and the switch that stops the recording are the app's; the method appendix is the kit's, in Markdown and CSV; and the Mac's synced preferences are each user's, the citation style among them, with the reader's own order of tags and projects. Each is the kit's code where #1805 moved it there, and app code mirrored, held to the app's source, where it is the Mac's view or service. No upstream pull request and no pin move; migration 3 adds one column. One part of the row waits: Project Home's focus subjects, with a lead's snippet, which the kit makes in code it keeps internal, so they need an upstream pull request first.

**What the kit gives,** at `32e295e5`, from FRUS-Explorer#1805:
- `ResearchTrailSessions`: `group(_:idleInterval:)`, a trail's sessions, split after 30 idle minutes, and `newestFirst(_:limit:)`, the window a page of the Session Log reads; `SessionLogSnapshot.page(of:datedActivityCount:limit:)`, with its page limit and increment.
- `QueryMethodAppendix`: `make(recordedSearches:corpusNames:projectName:researchQuestion:generatedAt:corpusCoverage:)`, and `markdown(for:)` and `csv(for:)` for a `Host`, which gives the app's version, the data files, the locale, the calendar and the time zone; `RecordedSearch` and its `RecordedCount`, said by `appendixDescription(locale:)` and `basisToken`; and `Row.scopeProse(resources:locale:)`.
- `DocumentEngagementService.gather(among:forProject:)` and `partition(corpusKeys:keys:isOpenedComplete:)`, with `EngagementCoverage`'s words.
- `ResearchItemCounts.tally` and `ProjectTally.summary`, a project's "12 notes · 3 collections".
- And from earlier pins: `SearchScopeSignature.signature(for:)`, `SearchService.matchExpressions(for:)`, `FTS5InlineQueryParser.normalizingQuotationMarks(_:)`, `CorpusCaptureTruncation`'s line and `CitationStyle`.

**Delivered**

- **The store** (`Sources/FRUSLightCore/UserProjects.swift`, `UserTrail.swift`, `UserResearchRows.swift`): migration 3's `users.active_project_id`, the project each user works in, which reads as none once the project is gone; `ProjectStore`'s list, the project worked in, the deletion and the merge, as `ProjectAdminService` does them; `TrailStore`'s pages of the three trail tables, newest first and a row with no time last, the count of dated rows, and the deletions; and `PreferenceStore`'s one row a user, made with `SyncedPreferences()`'s values the first time it is written. S17e's `SearchSetStore` and these now share `ResearchRowStore`, a user's rows read and written as the export and the import map a Mac's record. Their writes change neither `user_search` nor the tag assignments, so they leave the search mark (`writing(outsideSearch:)`), and a search kept outlives a visit's recording.
- **`/api/v1/me/projects`** (`Projects.swift`): the list by name, with each project's tally and the project the user works in; New Project, which makes it that project, as the app's editor does; a project; a change of its name, question or default tags, writing the columns changed alone and stamped; Delete, which returns the user to Global Context if it was theirs and leaves the trail's rows as they were; Merge, `POST …/{id}/merge`, which files the notes and collections under the target, re-points the visit plans, the summaries and the three trails, moves the user to it if they worked in the source, and leaves the leads; and `GET` and `PUT /api/v1/me/active-project`. `PROJECT_NOT_FOUND` for a project not the user's.
- **Project Home** (`ProjectHome.swift`): `GET /api/v1/me/projects/{id}/home`, the app's `ProjectHomeSummary` over the store's rows: the counts; each corpus's coverage by the kit's engagement rules, with Log Research Sessions read as whether the opened count is complete; the focus tags; the leads not dismissed, by their score, NEW for a week, and a lead's editorial-note flag as the user's corrections leave it; and the five newest visits, notes and searches. `POST …/leads/{id}/dismiss` dismisses one.
- **The trail** (`History.swift`): `GET /api/v1/me/history`, a page of each table for a scope, each visit's title as the app's `ReadingHistoryTitle` gives it, and each search's count and scope in the appendix's words; `POST …/history/documents`, a visit, stamped with the project the user works in; `POST …/history/searches`, the server's own run of the search the screen ran, with the Mac's capture fields, refreshing the row the anchor names when its words are the same, as `SearchHistoryWriter` does; the deletion of a row and of the whole trail; `GET …/history/sessions`, the Session Log, with the Research Sessions pane's summary (`ResearchSessionsSummary`); and `GET …/history/appendix`, the method appendix as an attachment, in Markdown or CSV, its dates in the zone the browser names. While Log Research Sessions is off, the two records are `suppressed`.
- **The synced preferences** (`Preferences.swift`): `GET` and `PATCH /api/v1/me/preferences`, the Mac's `SyncedPreferences` record for each user, with `SyncedPreferences()`'s values for one who has set nothing. A change writes the fields it names, a list replacing that list alone in the Mac's payload (`ListOrderPreferences`), and a style or a mode the app has not is refused. The import and the export carry the record whole, as S16d made them.
- **The browser app:**
  - the header's project picker, with Project Home and Manage Projects, and "Working on:" over Browse and Search;
  - Project Home (`/projects/$projectId`): the question, saved as it is typed; the date focus; the tiles and the coverage; the focus tags; Suggested Next, with Dismiss, the focus going on to the next lead; and Recent Activity;
  - History (`/research/history`), beside All Notes, with its scope, its search field, Show More and Delete;
  - in Settings: Projects, with the editor, New Project…, Delete and Merge; Research Sessions, with the switch, the Session Log (`/settings/sessions/log`) and Delete Recorded Sessions…; Reading, with Open Documents In and the citation style; Data's method appendix, a link for each file; and Move to Top, Move Up and Move Down in Tags and Projects, whose order the tag picker, the note editor, My Tags and the project picker follow;
  - the reader's record of each arrival at a document, the mode a document opens in, and Cite's style, the user's;
  - Search's record of each search it runs, and Checklist Mode's line while the switch is off;
  - Export as JSON headed by the project the user works in, as the app's export sheet heads it.

**Decided here, each the web's own**

- **The project a user works in is theirs, on the server.** The Mac keeps it on each device, and a browser is any device, so the web keeps one for each user, in a column of its own in `users`, which no Mac record carries and no import changes. None is Global Context.
- **A search's record is the server's run of it.** The screen sends the search and the row it last wrote, and the server runs the search again for the Mac's capture fields: the exact count, the user's half included; the rows kept, up to the ceiling of 7,500; the ceiling; the volumes indexed; the scope's signature; the corpus; and the expression it compiled to. So a record is what the API answers, not what a browser says. A search with no words, or one the server refuses, is recorded not at all.
- **The anchor is the tab's.** The Mac's `SearchHistoryWriter` keeps the row it last wrote for its window; the browser keeps it for the tab's session, a reload included, in `sessionStorage`, so the same words run again refresh that row, and a return to a search's results records nothing again. The records go one at a time, each with the anchor the one before it answered, as the Mac's writer moves its anchor at once, and one the server could not take is tried again the next time its run is shown.
- **Remember Last reads the browser.** Open Documents In is synced, but the research panel's last state, which Remember Last reopens, stays in each browser, as the Mac keeps it on each device.
- **The citation style moves once.** The style the browser kept before S17f goes to the server once for the browser, the first time anyone's preferences are read in it, if the server holds none for them; no second user and no import that empties a style takes it. After that the server's is the style, and while the user's are read Cite shows the style this browser last chose, so a citation does not open in another first.
- **A change shows at once.** A preference, and the project the user works in, show the new value before the server answers, in every control that shows them, and the server's copy stands once the newest change is answered, or, if the server refuses it, its copy as it was. An older answer that arrives after a newer change was sent is not taken as the copy.
- **The appendix's host is the server's, and its zone the browser's.** The Generated line names "FRUS Explorer Light" and the server's version; the scopes are said with the server's data files, in US English and the Gregorian calendar, as the server's other words are; and the dates are in the time zone the browser names, since the server's is not the reader's.
- **The exports wait for S18e.** The trail's third table holds the exports an import brings; the web's own exports are collections', and S18e keeps each in the history.
- **A visit the index cannot title takes the reader's title from its TEI.** The app titles a visit by the head it parsed (`DocumentViewModel.readingHistoryTitle`), with the kit's `IndexingPipeline.extractHeader(from:)`, which is internal. The server takes the index's head where the index holds the document; for one it does not hold, as front matter is, or for any while no index is served, it takes the title the reader shows for it (`DocumentDetail(teiOnly:)`): "Preface", or "Document 3".
- **Focus subjects and a lead's snippet wait upstream.** Project Home's subjects come from the kit's `VolumeSubjectProfiles`, and a lead's snippet from `IndexingPipeline.documentSnippets(forKeys:)`, both internal to FRUSCoreKit at `32e295e5`. A copy of either would break CLAUDE.md's rule 4, so Project Home leaves both out until a pull request on FRUS-Explorer makes them public and a pin move takes it.

**Tests**

- **FRUSLightCoreTests,** 158 to 162: `UserTrailTests`, 4 on each store: the project a user works in, theirs and gone with it; a merge, re-pointing what the app's merge re-points; a trail page, newest first in its scope, with the dated count and the deletions; and the preferences' row, made once and changed by field, with a merge that reads the row as the write finds it. `UserStoreConformanceTests`' test of the search mark now holds S17f's writes to leaving it.
- **FRUSLightServerTests,** 203 to 211: `ProjectHistoryTests`, 8: projects made, changed, merged and deleted as the app does, and the project worked in; a visit to a document the index lacks, and to any with no index served, under the reader's title; a visit and a search recorded as the app records them, the anchor's refresh, the switch's suppression and the refusals; the Session Log, the kit's sessions over the trail, with the pane's summary; the method appendix, held to the kit's `markdown(for:)` and `csv(for:)` of the recorded trail for the server's host, in UTC and in Berlin's zone, with its refusals; Project Home, as the app's view shows it; the preferences, the Mac's synced settings, read, changed and refused; and two users' projects, history and preferences apart, live behind the proxy.
- **FRUSParityTests,** 203 to 206: `ProjectHistoryParityTests`, 3: every Mac word the web takes, about 170, under its key in the app's source and in copy.ts's block; the reader's own order, the History screen's filter, Project Home's and "Working on:"'s lines and the checklist's, the app's code and the web's mirrors of it, with the kit's quotation marks; and the server's mirrors of the app's views and services.
- **The web unit suite,** 356 to 392 tests in 38 to 42 files: `s17fRules.test.ts`, `ProjectsAndHistory.test.tsx` (Project Home, each project's question its own and a refused save sent again; the picker and a choice shown at once; History, its Delete's and Show More's focus and the way in from All Notes; Project Home read again after a note or a tag; and the record of a search, one at a time and kept for the tab's session), `S17fSettings.test.tsx` (Projects, Research Sessions, the Session Log, Reading, a change shown at once and put back on a refusal, the style given once for the browser, and Data's appendix) and `ReaderTrail.test.tsx` (a visit recorded once, the switch and Checklist Mode, Open Documents In, and Cite's style while the preferences are read); `ResearchRail.test.tsx`'s Remove… with a frame before the rows are drawn again; and the panes S17f changed.
- **The browser suite,** 53 to 57 tests, at the root and under the path: `projects-history.spec.ts`, with axe, makes a project by keyboard, works in it and sees its Project Home and, reached from All Notes, its History fill; turns the trail off, reads the Session Log and deletes the trail; downloads the method appendix in both formats for two recorded searches, one that found nothing; and keeps the citation style and the mode documents open in as the user's own. Each test sets back what it set.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** with `scripts/swift --postgres`, PostgreSQL 18: the build gives no warning. All 2,579 tests pass, up from 2,565 on `main`, with the one named skip and nothing cancelled: FRUSLightCoreTests 162, FRUSLightServerTests 210, FRUSParityTests 206, FRUSCoreKitTests 1,299, the others as on `main`. `ProjectHistoryParityTests` ran again alone, and passed, after the last of its holds.
- **The appendix's test bites:** with the version the server's host gives the Generated line changed, `theMethodAppendixIsTheKitsForTheRecordedTrail` fails, and it passes again with the line put back.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 381 tests in 42 files. The app's script is 597 kB, from `main`'s 546 kB, which already passed Vite's 500 kB warning.
- **The browser suite,** over an image of the branch under a tag and port of its own (`frus-light:s17f`), `scripts/compose-smoke --e2e`: the first run passed 53 of 57 at the root, and four failed:
  - `import.spec.ts` and `notes.spec.ts` find All Notes' Project filter by its name, and Playwright's name is a substring, so the header's picker, Switch project context, matched as well. Each now names the filter exactly;
  - `search-read-cite.spec.ts` chose Chicago in Cite with `check()`, and the radio showed the choice only when the server answered, as S17f had first written the style. Each synced preference now shows a change at once (Decided here), and a unit test holds it;
  - the new spec expected the CSV's `fetch_limit` for an exact count, which the kit writes for a floor alone. The spec now expects the kit's row.
  With the fixes, an image made again passed `scripts/compose-smoke --e2e` whole: the browser suite's 57 tests at the root and 57 under the path, and the sign-in phase and its spec.
- **A review** read the diff cold, the server's and the browser app's apart, with the pull request open. The server's found nothing serious, and four smaller defects; the browser app's found ten, one of them half the app's own rule. Each is fixed:
  - **another project's question on Project Home:** the screen stayed mounted as the route moved to a project whose Home was read already, and its question kept the last project's draft, which an edit then saved as this one's. Project Home is keyed by its project now;
  - **History out of reach:** only History linked to History. All Notes now has Research's navigation too, and the browser suite goes that way;
  - **a refinement recorded under no anchor:** two records in flight each carried the anchor as it stood when sent, so a refinement shown before the first record was answered added a row. The records go one at a time;
  - **the anchor lost to a reload,** which SPEC keeps for the tab's session: it is in `sessionStorage` now, and a record the server could not take is tried again. The other half, a run shown while logging is off counting as shown, stands: the app's return to the same results records nothing either, and the server hands the anchor back as it was;
  - **History's focus after Delete and Show More:** Delete read the rows before React drew the new ones and could focus the deleted row's own button, and Show More, unkeyed among keyed rows, was made again as the rows came;
  - **a refused question never sent again:** the field held the refused words as saved;
  - **the pickers snapping back:** both showed the server's project until it answered. A choice shows at once in both now, as a preference's change does;
  - **Project Home stale after a note, a highlight or a tag:** each marks it to be read again now, and a note marks the projects' tally, read where it is next shown;
  - **the citation style's move:** guarded for each component, it could run again, and on a shared browser give one user's style to another. It is once for the browser now, and Cite shows the browser's last style while the user's is read;
  - and the server's four: **a list's order lost** when a change to the other list landed between the read and the write, now merged inside the store's write (`setPreferences(_:initial:for:at:merging:)`); **a visit the index cannot title, stored untitled,** now under the reader's title from its TEI (Decided here); **a refresh reported with nothing written** when the anchored row went between the check and the update, now an insert; and **Project Home's completeness line quiet** where the app's tile draws it orange, as it draws every line but a Meaning search's.
  Each of the browser app's ten fixes has a test that fails without it, each run so with the fix taken out. The visit's title and the colour have a test each, and the colour a parity hold on the app's line too. The two races cannot be reached by a test; the merge's contract is held instead. The reviews found the user separation, both stores' SQL, the merge, the anchor rule, the appendix, a visit recorded once, and newest-change-wins in the preferences sound.
- **After the review's fixes,** locally: `ProjectHistoryTests` 8, `UserTrailTests` 4 on both stores and `ProjectHistoryParityTests` 3 pass, through the heavy-job lock, and the web job's steps are clean, the unit suite passing 391 tests in 42 files. The whole suite and the browser suite are CI's to run at the pushed head: the local runs of both were stopped while the upstream session's Mac checks held the lock. FRUSLightServerTests is 211 with the new test, and the suite 2,580.
- **CI at `b789a31`:** the swift and web jobs passed, and the compose job's browser suite passed 57 of 57 at the root and 56 under the path. `highlights-keyboard.spec.ts:25` lost its focus after a highlight's Remove: the Research rail's Remove… sent focus a frame later to the button at the removed row's place, which, while the reader had not yet drawn its rows again, was the removed row's own, and focus went with it. S15c's code, the defect the review found in History's Delete; the rail now passes over the removed row's own button, as All Notes, History and Project Home do, and a unit test that runs the frame before React draws the rows fails without the fix. The same lookups in Browse's scope members and Search's Mark Reviewed move focus after React has drawn, and are sound.

**Records**

- `docs/SPEC.md`: the project picker, Project Home, History and the record of the trail, the method appendix, Settings' Projects, Research Sessions, Reading and Tags' order, the export's header, the API's projects, history and preferences, and migration 3.
- `docs/INSTALL.md`: the features, and the API's routes.
- `docs/PLAN.md`: the row's done paragraph. `docs/COORDINATION.md` §1: the kit's code the server calls for it, and the mirrors.
- README's status, and this log. The hand-over note is `s17f-projects-history.md` in the shared notes folder.

**Next: S18d,** collections and their editor. A follow-up beside it: a pull request on FRUS-Explorer making `VolumeSubjectProfiles` and `IndexingPipeline.documentSnippets(forKeys:)` public, labelled for Mac verification, then a pin move of its own, so Project Home can show its focus subjects and a lead's snippet.

## Session 17e: saved searches, working corpora, volume scopes and Checklist Mode

28 October 2026 · branch `claude/elastic-ptolemy-767148` · [#83](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/83) · upstream `32e295e5`, unchanged

Phase 2's row S17e, the second of the search-and-research rows that S17c's pin move opened. A search is saved and recalled with the Mac's "+N since last run"; the rows a search shows are saved as a working corpus, which Browse lists and opens and a search runs inside; My Scopes keeps the reader's sets of volumes, and a scope fills a search's volume filter; and Checklist Mode hides the results reviewed, kept in the browser's memory for the session. Each is the kit's code where #1805 moved it there, and app code mirrored, held to the app's source, where it is the Mac's view or view model. No upstream pull request, no pin move and no schema change: the three tables are migration 2's.

**What the kit gives,** at `32e295e5`, from FRUS-Explorer#1805:
- `SavedSearchFreshness`: the mark a run writes (`run(at:matchCount:indexedVolumeCount:)`), its blob, and "+N since last run" (`evaluation(currentCount:)`, with the backfill of a baseline never learned, and no badge for fewer results).
- `WorkingCorpusResolver.resolve(documentKeys:)`, by volume, with its coverage; `SearchParameters.runningInside(workingCorpus:)`, a search's only document gate; `CorpusCaptureTruncation` and its line; `WorkingCorpusProvenance.isMeaningCapture`.
- `CustomScopeResolver`'s two grains, `indexedResolution(memberVolumeIds:indexed:)`, which never gives a bare empty set, and `manifestVolumeIds(memberVolumeIds:manifestIds:)`.
- And from earlier pins: `QueryQuoting.quotable`, and `SearchScopeSignature`'s `signature(for:)` and `describe(_:resources:locale:)`, which a capture's narrowing is said in.

**Delivered**

- **The store** (`Sources/FRUSLightCore/UserSearchSets.swift`, `SearchSetStore`): each user's rows of `saved_searches`, `working_corpora` and `volume_scopes`, listed, found by the Mac's id in any letter case, added, changed in the columns named alone, and deleted, written once on `RelationalUserStore` in SQL both stores read. What a row's columns hold is the API's: it writes a row as the import writes a Mac's record (`MacImport.savedSearch`, `.corpus`, `.scope`) and reads one as the export does (`ResearchExport.savedSearch`, …), so each is as the app's initialiser and getters make it, which the parity tests already hold.
- **`/api/v1/me/saved-searches`** (`SavedSearches.swift`): the list, newest first, as the Mac's sheet; Save, the whole `SearchParameters` archived beside the scalar columns, as `SavedSearch.init(name:parameters:)` writes them, the name trimmed of spaces and never empty, and a working corpus the search ran inside composed into its gate, as the Mac's window saves its parameters; Rename, as given, and Delete; `POST …/{id}/run`, a recall's stamp, from the saved search's own count, of its whole parameters, as `SavedSearchFreshnessEvaluator.recordRun` counts it; and `POST …/{id}/freshness`, the kit's evaluation, its backfill written. A saved search gives its recall's search as the API's query fields, its own gates left out, and names what it sets that the API does not take (`notRecalled`).
- **`/api/v1/me/working-corpora`** (`WorkingCorpora.swift`): the list, the most recently captured first, each with the kit's resolver's coverage over the served index, its truncation line and its words as the kit quotes them; a corpus opened, one section a volume, in `CorporaAxis`' order, with titles and dates from the index; Rename and Delete; and the capture, `POST …/capture` for the sheet and `POST` to save, of a search's retained rows less those Checklist Mode hides, with what `ResultSetScope` says of them for a keyword search, mirrored in `CorpusCapture`: the provenance sentence, the two warnings, `isCapturePartial` and the narrowing, in the kit's words for a scope.
- **`/api/v1/me/volume-scopes`** (`VolumeScopes.swift`): the list, the most recently edited first; New Scope, unnamed and empty; the editor's name, as typed, and its members, each once and sorted; Delete; each scope with the kit's two grains.
- **A search inside a corpus:** every search route takes `workingCorpusId`, which `SearchUsers.inside` resolves for the request's user over the served index, by the kit's resolver, into the parameters' gate (`runningInside(workingCorpus:)`); `CORPUS_NOT_FOUND` for a corpus not theirs, or any of a search that acts for no one. `SearchRequest.signature` takes the documents of a gate, so every answer kept of a search inside a corpus is kept apart from the same search's outside it.
- **Checklist Mode's rows:** `/search`, `/search/timeline` and `/search/concordance` take `reviewed`, the results hidden, and cut their pages, in either order, from the results kept less those, as `MacSearchViewModel.displayedResults` is paged; `/search` says how many it hid (`hidden`). Each of the three also answers a POST of its query string, for a checklist that outgrows an address.
- **The browser app:**
  - Search's Save this search and Saved searches, the Mac's two sheets, each row's watermark evaluated in turn as the sheet opens, with the NEW capsule and "+N since last run"; a recall inside the corpus applied, with its run stamped; Rename and Delete in the row;
  - Save as Working Corpus…, its sheet over what the server would capture, with the Mac's rows and warnings; the "Inside" banner with its ✕; and among the filters, My Working Corpora and My Volume Scopes, each refused with the Mac's warning for one the server holds none of;
  - a recalled search's phrase, prefix and excluded terms in the search's state, as tokens that clear them;
  - Checklist Mode (`search/checklist.ts`, `ChecklistStrip.tsx`): the toggle, the strip with Mark Page Reviewed and Undo, a row's Mark Reviewed and All Results Reviewed, its marks and the search they belong to the app's `ReviewedMarks` and `ChecklistAnchor`, mirrored; a document opened in the reader while it is on leaves the list too;
  - Browse's axes, with Working Corpora, its list and its drill by volume, and My Scopes, its list, New Scope, a scope's volumes and the editor with Add Volumes… and Delete.

**Decided here, each the web's own**

- **Checklist Mode lives in the browser, and the server pages what it leaves.** The row keeps it in the browser's memory for the session, as on the Mac, where its marks live for the launch; but the Mac pages the 7,500 results it holds less the reviewed, and the browser holds a page. So the browser sends the reviewed with each request, and the server cuts the page from the results it keeps less those, as the Mac's view model does, by POST once the list outgrows an address. Nothing of it is stored.
- **A document opened is noted in the same memory.** The Mac hides one opened since the mode came on through its reading history, which S17f brings; until then the reader notes it beside the marks, as the Mac does with Log Research Sessions on, its default, and the Mac's line for the switch turned off waits for the switch.
- **The capture is the server's.** The rows a search shows can be 7,500, more than a body under `/me` takes, so the browser names the search and the reviewed, and the server captures its retained rows; it also says what the Mac's sheet says before Save, so the sheet shows the server's own count.
- **A saved search's tag the user has since deleted** keeps S17d's rule in a search: the recall is refused, with the Tags token to clear it. The run's count and the badge's read it as matching nothing, as the Mac's re-resolution does.
- **What a recall here cannot carry is said.** A Mac's saved search can set `booleanMode`, a person in one volume, a project or a topic, which the API does not take; the sheet's row says a recall runs without them, and its count is of the whole search.
- **Rename and Delete of a corpus, and Delete Scope,** which the Mac keeps in its Settings, are in Browse, beside the drill and the editor, where the web lists them.

**Tests**

- **FRUSLightCoreTests,** 153 to 158: `UserSearchSetTests`, 5 on each store: each user's rows, their columns as written, an update of the columns named alone, a delete, and the refusals.
- **FRUSLightServerTests,** 196 to 203: `SearchSetTests`, 7: a saved search's whole search and columns, its list, rename and delete; a recall's stamp and "+N since last run", the backfill, fewer results, a deleted tag; a capture, its account and its corpus listed and opened by volume; a search inside a corpus through every route, kept apart, a corpus of nothing indexed, and refusals, a request to another address among them; Checklist Mode's pages in either order, the timeline, the concordance and the POST; a scope's two grains; and two users' sets apart, live behind the proxy.
- **FRUSParityTests,** 198 to 203: `SearchSetParityTests`, 5: every Mac word the web takes, under its key in the app's source and in copy.ts; the lists' orders, the app's queries' and the server's; the checklist's rules, the app's and checklist.ts's, with the kit's quotation marks; the capture's account, `ResultSetScope`'s and the server's; and a recall.
- **The web unit suite,** 326 to 356 tests in 38 files: `checklist.test.ts`, `SearchSets.test.tsx` (the sheets, the recall, the capture, the corpus and scope filters, a refusal, Checklist Mode, its wait for a search's rows, Undo's count and the page it resets) and `SearchSetsBrowse.test.tsx` (the axes, Working Corpora and its drill, My Scopes, New Scope, the editor and its quick removals), and `searchState`'s new fields.
- **The browser suite,** 49 to 53 tests, at the root and under the path: `search-sets.spec.ts`, by keyboard, with axe, saves, recalls and renames a search and sees "+1 since last run", saves a corpus, opens it in Browse and searches inside it, makes a scope and applies it, and hides results in Checklist Mode, marked, a page at a stroke, undone and opened.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** with `scripts/swift --postgres`, PostgreSQL 18, through the heavy-job lock: this package's own targets build clean with no warning. All 2,565 tests pass, up from 2,548 on `main`, with the one named skip and nothing cancelled, on the code with the review's fixes: FRUSLightCoreTests 158, FRUSLightServerTests 203, FRUSParityTests 203, FRUSCoreKitTests 1,299, the others as on `main`.
- **A review** read the diff cold. It found five defects, each fixed, with a test where one can reach it:
  - **a kept count shared between two searches:** `SearchRequest.signature` was the API's query fields, which leave out what the API does not take, and a saved search is counted with its whole parameters, which a Mac's can give a project's `excludeDocumentIds`, `booleanMode`, `personRef` or `subjectRef`; so a saved search's count could stand for the same words searched through the API, or the other way. The key is the whole `SearchParameters` now, as JSON with its keys sorted, and `aRecallStampsTheRunAndTheBadgeCountsWhatIsNew` counts a Mac's search with a project's exclusion before the same words;
  - **marks of the last search's rows:** while the next search's rows came, the last one's stayed on screen, and Mark Page Reviewed could mark them under the new search, which the Mac's `canMarkReviewed` stops (#1683). Marks now wait for the rows of the search the checklist is anchored to;
  - **New Scope opened on Scope Unavailable,** its editor reading the list, which did not yet hold the scope: the editor and a scope's page read the scope by its id, which New Scope's answer gives at once;
  - **two quick removals in the editor put the first back,** each sending the members it last read: the editor keeps its members as it last set them, and sends each change once the one before it is answered;
  - **Undo said "0 results are back"** when pressed before the list its mark changed had loaded: it counts by the mark's rows then.
  And two smaller ones: a mark that left the page past the last now goes back to the first, as the Mac's `clampCurrentPage` does, and the Saved Searches sheet gives its rows the focus once, not again at each reading of its list. The review found the user separation, the pages' arithmetic, the freshness rules and the SQL of both stores sound.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 356 tests in 38 files. The app's script is 546 kB, from `main`'s 504 kB, which already passed Vite's 500 kB warning.
- **The browser suite,** over an image of the branch under a tag and port of its own (`frus-light:s17e`): a scratch copy of the smoke test, its root phase alone, ran the whole suite; 51 of 53 passed and two of the new spec's tests failed on the spec itself, one tabbing away from a button the closed sheet had given the focus back to, one expecting an empty My Scopes where `import.spec.ts` leaves the kit's fixture's scope. Fixed, the new spec passes 4 of 4 alone, and each of its tests now removes only what it made. Then `scripts/compose-smoke --e2e` with that image passed whole: the browser suite's 53 tests at the root and 53 under the path, and the sign-in phase and its spec. With the review's fixes, an image made again passed it whole again, 53 and 53 and the sign-in spec.

**Records**

- `docs/SPEC.md`: Browse's axes, Search's saved searches, corpora, scopes and Checklist Mode, the API's `workingCorpusId`, `reviewed` and POSTs, and the three resources under `/me`.
- `docs/INSTALL.md`: the features, and the API's routes and fields.
- `docs/PLAN.md`: the row's done paragraph. `docs/COORDINATION.md` §1: the kit's code the server calls for them, and the mirrors.
- README's status, and this log. The hand-over note for S17f and S18f is `s17e-saved-searches.md` in the shared notes folder.

**Next: S18d,** collections and their editor, with **S17f**, projects, the history and the method appendix, beside it; S17f's history can hide a checklist's opened documents by the Mac's switch, and S18f's smart collections run the saved searches this row keeps.

## Session 18b, third follow-up: the pointer notes spec's random failure

28 October 2026 · branch `claude/amazing-wright-703c3a` · [#82](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/82) · upstream `32e295e5`, unchanged

`web/e2e/notes.spec.ts`'s first test failed at random in CI's `compose` job, which `main` requires: #77's run 40678882702, its first attempt, at about 11:28 UTC. At line 58, once the selection bar's Note had opened the editor, the new note's text never took focus, and `toBeFocused` timed out after 10 s; the suite's 47 other tests passed. #77 changes nothing under `web/`, and the same web code passed on `main` at `c209d75`. The cause is in the note editor's own focus: a race between Tiptap's timer and React's render, which the editor's code coming late brings. It is fixed and tested. No upstream change, no pin move.

**What the trace showed.** The run's `playwright-report` holds the test's trace. The dialog opened with the click, and the editor's code, a lazy chunk, was asked for at the same moment and took 259 ms to come. The text appeared about 315 ms after the click and never took focus.

**The cause, found before anything changed.** A diagnostic spec, never committed, ran the test's opening and logged every `focus()` call, with its caller and whether its element was in the page, beside the dialogs' open and close, focus events, the editor's timers and frames, and the text's arrival. `page.route` delayed the editor's code. Against an image of `main`, at the root:
- **Delayed 150 to 330 ms, in 40 runs:** every delay of 234 ms or more failed, 28 of 28, and every one of 228 ms or less passed, 12 of 12. Delays of 350 to 700 ms failed 12 of 12.
- **A failing run, delayed 255 ms:** Tiptap made the editor at 679.8 ms, in React's render, and its autofocus timer ran at 680.7. The frame that timer asked for ran at 681.7 and called `focus()` on the text while it was not yet in the page, which did nothing. React placed the text at 685.5. Tiptap's other timer, which destroys an editor no effect has claimed so that its hook makes another, never ran: React's effects had cleared it.

So, in Tiptap 3.31, `useEditor` makes the editor while React renders, mounted on an element outside the page, and runs `autofocus` on `setTimeout(0)`, which calls `view.focus()` in a frame. `EditorContent` moves the editor into the page when React commits it. When the code comes late, React shows the editor in a retry render, which it time-slices: once 5 ms have gone it pauses, here right after making the editor. The timer and the frame came in the pause, and focus went to an element not in the page, and so nowhere. Whether a run fails turns on when the code comes. Ten runs with no delay all passed, by two paths, told apart by when the editor was made and placed; in two of them, the stack where Tiptap set its timer named the render that made it:
- **Early,** in 7 of the 10: the code came with the dialog's own data, its tags, projects and summaries, and the editor was made 24 to 27 ms after its loading text appeared and placed 3 to 4 ms later, before Tiptap's timer ran. Its stack names a synchronous render, flushed in a microtask, as that data's arrival brings one: React Query gives React its data through `useSyncExternalStore`, whose renders React never pauses.
- **Held,** in the other 3: the retry render made the editor first, at about the same time, and React held its content until 300 ms after the loading text, as it holds a retried boundary's. Tiptap's other timer ran in the hold and destroyed the editor, which no effect had claimed, so the frame found nothing to focus. Once React had placed the content, the hook made the editor again, at 307 to 317 ms, and that one's own timer focused it.
- **Late:** a retry render that ends 290 ms or more after the loading text is placed at once. When it paused after making the editor, as every such run here did, the timer and the frame came in the pause, as above. CI's chunk took 259 ms, which puts the render at that edge, so the test failed at random.

**The fix.** `RichTextEditor` no longer passes `autofocus` to Tiptap. An effect calls `editor.commands.focus('end')` for a new note once React has committed the editor, after `EditorContent` has placed it in its own mount, and again for an editor the hook makes anew. Focus still comes in a frame, after the dialog has focused its heading. `NoteEditor` is unchanged.

**The tests.**
- **A unit test,** `RichTextEditor.test.tsx`'s "a new note's text", reproduces the race. With React's own scheduler, which `act` would replace with renders it never pauses, a transition renders the editor in an open dialog, and a slow sibling makes React pause after making it. `framesAtOnce` gives the frame at once, and Tiptap's timers, faked, run in Chromium's order: the first in the pause, the second only once React's effects have cleared it. With the editor as it was, it fails 10 of 10, its frame focusing the text while it is not in the page; with the fix it passes 10 of 10. The web app's unit tests go from 325 to 326, in 35 files.
- **A browser test** in `notes.spec.ts` delays the editor's code by half a second, and checks that the heading has focus while it loads and the text once it has come. Against `main`'s image it failed 10 of 10, 5 at the root and 5 under the path, at the text's focus; with the fix it passed 10 of 10. The browser suite goes from 48 tests to 49.

**How it was checked,** on the owner's Mac at load averages of 2 to 4, with images and a port of this session's own, through a scratch copy of `scripts/compose-smoke` that runs one spec, repeated, in both passes:
- **The diagnostic spec with the fix:** 40 of 40 with the code delayed by 150 to 330 ms, and 12 of 12 at 350 to 700 ms.
- **`notes.spec.ts:41`,** the test that failed: 20 of 20 at the root and 20 of 20 under the path.
- **Both notes specs,** by pointer and by keyboard, three rounds in each pass: 21 of 21 at the root and 21 of 21 under the path.
- **`scripts/compose-smoke --e2e`** with this branch's image: passed, the browser suite's 49 tests in each pass and the sign-in spec.
- **`scripts/npm run typecheck`, `run lint`, `test`:** clean; 326 tests in 35 files.

**Delivered:** the editor's focus from an effect, the two tests and this log. The session's notes, its diagnostic spec and its copy of the smoke test are in the shared notes folder, as `notes-focus-late-editor.md` and `notes-focus-late-editor/`.

**Next:** phase 2 goes on with S18d, collections and their editor, beside S17e and S17f. `v2` is one commit past the pin ([#81](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/81)): FRUS-Explorer#1812, the person authority's lane design, in the app's plans alone. It changes nothing this repository compiles, so the next pin move takes it with records alone.

## Session 18c: pin move past FRUS-Explorer#1809, #1810 and #1811, with #1808

28 October 2026 · branch `claude/nervous-mccarthy-21018c` · [#77](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/77) · upstream `32e295e5`

Phase 2's row S18c. The pin moves from `1c18b51e` to `32e295e5`, `v2`'s head. The pull request opened at `fef96201`, past S18b's [FRUS-Explorer#1809](https://github.com/joshbotts/FRUS-Explorer/pull/1809) alone. Two web-authored pull requests merged after it opened, and the owner had it take them ("Move #77 to 32e295e5"), since `PLAN.md`'s first pin move after a phase-2 upstream pull request merges takes it. With every merge since the pin, it takes four, each a squash with its branch head's tree:
- S18b's [#1809](https://github.com/joshbotts/FRUS-Explorer/pull/1809), a collection resolved through a data source in the kit, merged on 27 October as `fef96201` (tree `d1b45392`);
- S16e's follow-up's [#1810](https://github.com/joshbotts/FRUS-Explorer/pull/1810), which keeps the writing out of a stripped export's free pages, merged on 28 October as `e1d68919` (tree `0ec1f974`);
- S18b's follow-up's [#1811](https://github.com/joshbotts/FRUS-Explorer/pull/1811), which makes the app's own test of the capped editor's link alert wait for UIKit, merged on 28 October as `32e295e5` (tree `36279e2d`), from a branch that had taken `v2` at #1810;
- the app's [#1808](https://github.com/joshbotts/FRUS-Explorer/pull/1808) (`3af1fc07`), which adds the website's drafts under `Planning/website-drafts/` and, in the app's plans, makes their writing and review work for after the submission. It changes no file this repository compiles or reads.

The move is a pull request of its own under rule 5. `main` came in twice, by merges that kept both sides of every document that conflicted: at `ae1edf9`, with #78, #79 and #80, and at `c209d75`, with #75, S18b's records, and #76, S17d.

**What the move brought, in shared code**

- **#1809, in `FRUSCoreKit/SourceExplorer/`:** the archival indexes `ArchivalResolver` reads, `CentralFilesIndex`, `VolumeSourcesIndex` and `LotClaimantsIndex`, public with their decoders, and its document resolution over `ArchivalIndexes`, the three as one value. The stores that read the app's bundle stay in the app.
- **#1809, in `FRUSCoreKit/Collections/`:** the five apparatus blocks (`CollectionGeneratedBlocks`) with their data source and a locale for the chronology; a collection's composition from the research data export's values (`CollectionExportOptions(composing:)`, `CollectionBodyDepth.available(summariesAvailable:)`); a smart collection's saved search and snapshot (`SmartCollectionSnapshot`); the assembly, `CollectionContentAssembly`, behind `CollectionContentDataSource`; and the `.fruscollection` file over values (`NativeCollectionFormat.swift`).
- **#1810, in `FRUSCoreKit/Export/ResearchDatabaseStrip.swift`:** `ResearchDatabaseStrip.steps`, at its version 1.2, gains two statements: `PRAGMA secure_delete = ON` first ("preparing to overwrite freed space"), and `user_content` emptied with `'delete-all'` after the tag names and before the `VACUUM` ("emptying your-content index"). All seven run on one connection, since the first is a setting of the connection's, not the file's. The app's `IndexDatabaseExporter.strip(_:)` runs them as before; in `ResearchDataExporter.swift` only its comments change, note 3 among them.
- **In the kit's tests:** `CollectionResolutionTests.swift` (#1809), with two suites, `CollectionResolutionTests` and `CollectionValuesTests`; and in `ResearchDataEnvelopeTests.swift` (#1810), the strip's order held to seven statements, and `strippedCopyKeepsNoWordInFreedPages`, whose control runs the strip as it was. FRUSCoreKitTests runs 1,299, from 1,286.
- The rest is the app's: `CollectionContentResolver` as the data source over SwiftData and `AppState`, the bundle's three index stores, the exporter's mapping through the models' new initialisers (`Models/Collection.swift`), the trip packet; #1810's tests of the export; #1811's waits in `FRUSExplorerTests/CollectionTests.swift`; the app's `CLAUDE.md`, the manuals and the plans.

**No repair to the build.** `Package.swift` compiles `FRUSCoreKit/` by folder, so the new `SourceExplorer/` needed no change, and `tools/mac-golden` lists the kit whole. These are unchanged:
- the build (1.0, 1776), so `scripts/release-tag` still says `1.0-1776`;
- the index version (71) and the FTS generation (4), so `Compatibility.swift` and the install guide's versions stand;
- the export's schema: `IndexingPipeline.swift` is unchanged, `setupDatabase(_:)` at lines 8010–8665, and FTS5Store too, so the 47 `CREATE TABLE` and `ALTER TABLE` statements stand;
- `IndexingResources.indexResourceNames`, `FRUSExplorer/Resources`, the export's format version (7), the app's source folders in `project.yml`, and CI's allow-list.

**The server's own `secure_delete`, dropped.** Since S16e, `IndexImporter.strip` set `ExportChecks.stripSetting`, `PRAGMA secure_delete = ON`, on its copy's connection before the kit's statements: the kit's order rebuilt `user_content` after the `VACUUM`, which nothing follows to reclaim the pages the rebuild frees, and macOS's SQLite, at `FAST`, writes nothing over them. The kit's statements hold that setting now, first, and empty `user_content` before the `VACUUM` as well, so the server's copy would be shared behaviour reimplemented, against rule 4. It is gone, and Import mode runs the kit's statements alone, on the one connection they need.
- The readiness details name the two new statements in the kit's words, "Preparing to overwrite freed space in the server's copy" and "Emptying your-content index in the server's copy", as they name the others, so `ResearchDatabaseImportTests`' first test, which finds each of the kit's statements in a detail, passes as it was.
- The synthetic export's `user_content`, from a real index-69 export's schema, is an external-content table, which `'delete-all'` needs. The page the refusal test damages, the empty `terms` table's root, is still one only the `VACUUM` reads, so that test still sees the refusal at "reclaiming freed pages".

**S16e's free-page test, its control changed.** `theStripLeavesNoWordOfTheWritingInFreedPages` used the kit's statements at `FAST` as its control, and found the words of the notes and summaries in the pages the rebuild freed. At the new pin the first of them turns `secure_delete` on, so that control would find none: it is the test #1810's run over `main` found failing on Linux. Now each copy is stripped on a connection at `FAST`, as macOS's starts:
- the control, with the kit's statements but #1810's two, still finds the words of both;
- the kit's statements alone leave none, and neither does the index the server installs.

**On §5's indexing path,** `git diff 1c18b51e 32e295e5` over the parser's folder (`FRUSCoreKit/TEI`), `FRUSCoreKit/Search`, where `IndexingPipeline.swift` and its seams are, FTS5Store, SourceNoteKit, `FRUSExplorer/Resources` and `project.yml` is empty. #1809's kit code is in `FRUSCoreKit/Collections/` and `FRUSCoreKit/SourceExplorer/`, and #1810's in `FRUSCoreKit/Export/`, in statements the export runs on its copy after indexing; nothing in the parser's folder, `FRUSCoreKit/Search`, FTS5Store or SourceNoteKit names a type either adds or moves. So the owner's seventh three-volume export, made on 24 October from a build of `503a730b`, holds what the indexer at `32e295e5` would write, as it held what the indexer at `1c18b51e` would. The owner chose it in this session for the move to `fef96201`, and the question that brought "Move #77 to 32e295e5" said the move would reuse it; with the diff empty and the build still 1776, the golden files were remade from it.

**No parity test needed pointing anywhere,** as S18b's run over `main` at `2fac971` foresaw for #1809. Every check that reads the app's source passed at the new pin. `ExportParityTests`' mirror of the exporter still finds each line it reads, though #1809 moved a collection's fields into the app's `CollectionExport.init(_:entries:)` and `CollectionEntryExport.init(_:)` (`Models/Collection.swift`), the same fields as before; `ImportParityTests`' reads of `Models/Collection.swift` found theirs too. In the exporter's file, which `ExportParityTests` and `NotesAndSummariesParityTests` read, #1810 changed only comments.

**`tools/mac-golden` from a folder that never built `Crypto`.** The session's first run of `scripts/make-golden`, at `fef96201` and from the app's source alone, made nothing: the tool did not build, since `ParityFormat`'s `import Crypto` found no module. The tool had never been built in this worktree, and a second build failed the same way. `swift package dump-pif` shows why. In SwiftPM's plan for the Mac's build system, `ParityFormat` reaches swift-crypto's `Crypto` twice, directly and through FRUSCoreKit, whose dependency on it is Linux's alone, and the plan keeps only the Linux condition. So on a Mac nothing in the tool's graph builds `Crypto`, and the dependency scan of `ParityFormat` fails. Putting `Crypto` first among the target's dependencies changes nothing in the plan.
- **Since S17c's move,** which made `ParityFormat` depend on the kit, a tool built where `Crypto` was never built fails this way. S17c's own build presumably found `Crypto` left in its folder by a build before that change; its worktree is gone, so that cannot be checked.
- **The root package's plan** gives `ParityFormat` the same Linux-only edge, and FRUSParity and FRUSRichText too. Its Mac build of `frus-parity` passed: FRUSLightCore, which FRUSParity links, needs `Crypto` everywhere, so that build makes it, though nothing there orders it before `ParityFormat`.
- **The repair:** `ParityFormat` hashes as the kit does, with CryptoKit where it can import it and with swift-crypto, a dependency on Linux alone, where it cannot. `SHA256.hash(data:)` is the same call in both, and no golden file hashes the harness's own source, so none changes for it. The tool then built, and `make-golden` made every file. A build of the tool into an empty scratch folder then passed as well, in 241 seconds, and built no `Crypto` module.

**The golden files**

Remade by `scripts/make-golden --export /Users/Shared/frus-index-2026-10-24.sqlite`, under the app's `Scripts/heavy.sh` lock, on this Mac (macOS 27.2, Xcode 27.1), at `fef96201` and again at `32e295e5`: from the app's source, and, by the owner's choice, from the seventh three-volume export, which S16b's and S17c's moves were made from. The script works on a copy of the export. No new export was made, and no library was touched. Against `main`'s, at `1c18b51e`:
- **The render and the expressions:** the 393 rows' HTML is byte for byte as before, and the manifest and the expressions change only in provenance: `sourceDigest` (`60d61d5d2ef1` to `9347d9b686bf`, by way of `bf053f59eb1d` at `fef96201`) and `upstreamCommit`.
- **The results** change only in that provenance. Every query's count, first 50 results and tie tail are as before.
- **The index summary's** format and gating sections are unchanged. Beside the same provenance, its information section moves only in the summarizer's timings.
- **The golden spans** change only in that provenance. The RTF the app's editor writes keeps S17c's `\cocoartf2908`, on the same macOS, and `fixtures/rich-text/web`, the codec's own RTF, is unchanged.
- `frus-parity check-golden` passes, and `PENDING` stays empty.
- `make-golden` left `tools/mac-golden/Package.resolved` changed each time, pinning this package's 25 dependencies under Xcode 27.1's SwiftPM, as S17c's note says; the tool's own two pins, swift-crypto 5.0.0 and swift-asn1 1.7.3, are unchanged, and the change is left out.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** CI's swift job replayed with its PostgreSQL (`scripts/swift --postgres`) at `32e295e5`, over `main` at `c209d75`, this package's own targets built clean, with no warning, under the app's `Scripts/heavy.sh` lock: 2,548 tests, against the 2,535 S17d's log counts for `main` with #76, all passing with only the named skip, in Swift Testing's results file and in the log. The checks print:
  - "check 2 passes: 36 digests and 7 checks are the Mac's";
  - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups; 318 with other score bits (information)", and through the API "482 queries, 482 identical and 0 reordered only within Mac tie groups, every record the kit's own, each searched with the user's store attached";
  - "check 4 through the page: 393 of 393 rows identical", and the same on the reader's path and from one full parse per volume.
- **Per target:** FRUSCoreKitTests 1,299, from 1,286, and every other target as on `main`: SourceNoteKitTests 321, FTS5StoreTests 219, FRUSParityTests 198, FRUSLightServerTests 196, FRUSLightCoreTests 153, ManifestGeneratorTests 60, FRUSRichTextTests 42, SemanticVectorsKitTests 40, CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
- **The tests the move touches** pass: S16e's free-page test with its new control, the import's done-when on both stores, the refusal at "reclaiming freed pages", and the two parity tests that read the exporter's file.
- **Before `main` came in the second time,** the same replay at `32e295e5` over `main` at `ae1edf9` ran 2,534 tests, against the 2,521 on `main` at `2a31f41`; and **at `fef96201`,** before the re-target, over `main` at `2a31f41`, 2,533, FRUSCoreKitTests 1,298. Both passed with the named skip and the same lines from checks 2 to 4.
- **Before the golden files were remade,** S18b's run over `main` at `2fac971`, with #1809 copied over the submodule, found only their staleness, 21 issues in 20 tests, since their source digest covers `FRUSCoreKit/` and `FRUSExplorer/` whole, and #1810's run on Linux over `main` found S16e's control the one test its statements failed; this session repeated neither.
- **`tools/mac-golden`** built in release with `ParityFormat` hashing through CryptoKit, in this worktree's build folder and again into an empty one, where it built no `Crypto` module, and wrote the files above at both pins.
- **The web job and the image** are CI's: nothing under `web/` changes but what `main` brought, and the image compiles the kit at the new pin.

**The daily watch.** Its issue for the last range, [#56](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/56), was closed by hand after S17c's merge, and its scheduled run had not come today by 11:15 UTC; the last three ran between 11:39 and 13:12 UTC. If this has not merged by its next run, it opens an issue for `v2`'s four commits past `1c18b51e`, which this pull request takes, and its first run after the merge finds nothing past the pin and closes it.

**Records**

- `PLAN.md`: S18c's done paragraph after S14d's, S12d's row (from `32e295e5`), S18c's row in #75's words, the golden-files checkpoint, and the risk rows' kit counts and merges.
- `SPEC.md`: the compatibility contract, `setupDatabase(_:)`'s lines, Import mode's strip, and check 5's search of a stripped file.
- `COORDINATION.md`: the pin; §1's use of the kit, its count and Import mode's strip; #1810, merged, and this move in §2; §5's list of app changes; §6's exports.
- `docs/prep/README.md`: the pin. The README's Known gaps, its Next, and this log.

**Notes**

- **#75, S18b's records, and #76, S17d, merged while this was open,** and `main` came in again after them. `COORDINATION.md` §1 keeps S17d's search with the user's half beside this move's sentences on the strip and on #1809, §2 #75's paragraph on #1809 before #1810's and this move's, and §5 this move's line, which adds to #75's. `PLAN.md`'s S18c row was #75's words already, and S17d's done paragraph comes before this move's, as the README's sentence does.
- **Mac check 14** is still "To do" in `PLAN.md`, as 9 to 13 are. The owner merged #1809, #1810 and #1811, each labelled `Mac`; their checks are the owner's to record.
- **The heavy-job lock was seldom free.** Other sessions' Linux batches, a Mac build for #1810 and a 30-round run of the editor's link-alert test for #1811 held it between this session's first jobs, so its runs waited longer than they took.
- **`main`'s compose job failed at `2a31f41`** in one spec of the browser suite, `notes-keyboard.spec.ts`'s note written by keyboard alone, and #75's run at `0cc13e6` failed the same spec. #80 has since found races behind it, fixed two and narrowed the third, and this branch has #80 from `main`. Nothing under `web/` changes here otherwise.
- **Scratch:** the CI replay script and its logs in `.build/linux/s18c/`, `pin-*` at `fef96201`, `pin2-*` at `32e295e5` and `pin3-*` after `main`'s second merge, and the clean tool build in the session's scratch folder; neither is committed.

**Next: S18d,** collections and their editor, which puts a collection together on the server through the kit's `CollectionContentAssembly`, its store reads answered with the research data export's records. Beside it: S17e, saved searches, corpora and scopes, and S17f, projects, the history and the method appendix.

## Session 17d: search over the researcher's writing

28 October 2026 · branch `claude/silly-lewin-91841a` · [#76](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/76) · upstream `1c18b51e`, unchanged

Phase 2's row S17d, the first of the search-and-research rows that S17c's pin move opened. A search reads the researcher's own writing beside the corpus, as the Mac's does: Search in chooses the documents, the notes and the summaries; a tag filter and a row's tags read the user's tags; and the facets, the Query Inspector's counts and the readings count the same match. It goes through the kit's search with the user store's search database attached (FRUS-Explorer#1806's `SearchUserSource.attachedStore(userId:)`), each request with the half of the user it acts for. No upstream pull request, no pin move and no schema change.

**What the kit gives,** at `1c18b51e`:

- `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:userStore:)` attaches a store read-only as `user_store`, and a `SearchService` made with `.attachedStore(userId:)` reads that user's rows of its `user_search` and `tag_assignments` for every statement on the user half: the match, the tag filter, the exact-word filter's note and summary text, a row's tags, the tag counts and a tag's documents. S14d's `searchDatabase` names the file, app.db or the PostgreSQL store's copy.
- `SearchService.userTagCounts(parameters:tagIds:documentKeys:)`, the filter sheet's two routes to its tag counts.
- The app's search window, whose view code the browser app mirrors: Search in's three chips (`ScopeChip`, `SearchSheet.scopeRow`), each a column selector, and `MacSearchError.emptyScope` with all three off; My Tags, the filter's switches of the user's tags with their counts (`SearchFilterView.userTagsSection`); the Tags token's value (`MacSearchViewModel.tagFilterLabel`); and a row's ◆ chips, the first three of `UserTag.chips(for:among:)`.

**Delivered**

- **The served index attaches the store** (`Sources/FRUSLightAPI/ServedIndex.swift`). When the server keeps user data, each stack opens the pipeline with the store's `searchDatabase`; `search(for:)` gives a request's search, the kit's service for that user, new for each request, which the kit makes cheap, or the index's own for no one.
- **Whose half a search reads** (`Sources/FRUSLightAPI/UserSearch.swift`, `SearchUsers`): the user a request under `/api/v1/me` would act for, on its guard's terms. The server keeps user data, the request is sent to `FRUS_PUBLIC_URL`'s address, and the resolver names a user; behind a proxy, a request that names no one is no one's. A search for no one is the corpus's alone, with the index's own user half, which an import leaves empty.
- **The tag filter:** `SearchRequest` takes `userTagIds`, a list, the empty value no filter. Each tag must be one of the user's, by id in any letter case, as the kit matches it, else `TAG_NOT_FOUND` (404); any tag for no one is refused too. `subjectTagIds`, inert in the kit, and `booleanMode` are still refused, each with what to use instead.
- **Every search route** takes the user: `/search`, `/search/inspect` (GET and POST), `/search/facets`, `/search/facets/selection`, `/search/timeline` and `/search/concordance`.
- **`GET /api/v1/me/search/tags`,** under `/me`'s guard: the user's tags in `GET /me/tags`' order, each with how many documents of a search's results carry it, over the search as it runs, as the Mac's My Tags toggles count them (`userTagCounts`, the keyword route).
- **What a served index keeps of a search** (`RecentSearches`, `RetainedResults`, `FacetCache`, the timeline's years) is kept by whose search it is and the store's mark, `searchMark()`, before the query fields. A search for no one keeps phase 1's keys.
- **The mark** (`Sources/FRUSLightCore/RelationalUserStore.swift`): `UserSearchStore`, the search database and its mark, which the store's count of the write transactions it has committed gives. Each store's `writing` counts its commit before its caller is answered, so every path that writes, an import and a sign-in included, moves it. The PostgreSQL store counts the copy made again after a commit it could not take, and its `searchMark()` makes a stale copy again first, so the next search reads what the store holds, as the next call does; its flag is a `Mutex` now, read without the store's lock, so a search waits for a write under way only then. The mark is read before the flag, and the copy made again is counted before the flag is cleared, as a write that leaves the copy stale sets the flag before it counts itself: so a mark read with the flag clear is never one a search of the stale copy kept its answer by.
- **The browser app** (`web/src/search`):
  - Search in, the Mac's three chips, with its words, help and glyphs, on a server that keeps user data and wherever a link has turned one off; with all three off the Mac's "Enable at least one of Documents, Notes, or Summaries to search.", and no request;
  - My Tags among the filters, each tag a switch, counted once opened, with the Mac's sentence under the counts and its closed summary, Any or "N selected";
  - the Tags token, with the Mac's value, which clears the filter and gives the search box the focus;
  - a row's tags, the first three its tags name, as the Mac's ◆ chips (`tagRules.ts`);
  - every search the browser holds is asked again after a change to the user's notes, summaries, tags or a document's tags, and after an import (`searchesChanged`).

**Decided here, each the web's own**

- **A search reads the user's half on `/me`'s terms, and acts for no one otherwise, rather than refusing.** The search endpoints stay outside `/me`: they answer for the corpus without a user, as before, for scripts and for a proxy's request that names no one. But a search of a user's half reads their writing, so it needs what a read under `/me` needs: a request to the address `FRUS_PUBLIC_URL` names, since a page under another name pointed at the server could otherwise learn a user's notes through their searches. A request sent elsewhere searches the corpus alone, and a tag filter, which can only be the user's, is refused for it.
- **A tag that is not the user's is refused, not matched as nothing,** as S14e's row asks of the tag filter: `TAG_NOT_FOUND`, the code a note's tag that is not the user's has. Where two users hold one tag's id, as two imports of one Mac export give them, each filters by their own assignments. A search by a tag the user has since deleted or merged is refused the same way, where the Mac's matches nothing: the browser app shows the refusal in the results' place, and the Tags token, which then names "1 tag", clears it.
- **The mark counts every write of every user.** A count per user would need every method's user; the store's own count catches every path by construction, the import's and the sign-in's included. A write anywhere lets go of every user's kept searches, which are few: four searches, two kept for the date order, and 16 sections.
- **My Tags shows no counts while it counts,** as the Mac's toggles show none, rather than another search's.
- **The Summaries chip's help is the web's own:** the Mac's says "generated AI summaries", which is all a Mac holds, and the web keeps a researcher's own beside them.

**Tests**

- **FRUSLightCoreTests,** 152 to 153: `UserStoreConformanceTests.theSearchMarkMovesWithEachWriteTheStoreCommits`, on both stores: a tag, a document's tags, a note, a summary, a delete, a user made at a sign-in and an import move it; reads, a refused change, rolled back, and a user found do not.
- **FRUSLightServerTests,** 192 to 196:
  - `UserHalfSearchTests`, 3, under `FRUS_AUTH=none`: the user's note found by its word and its exact word in the scopes searched, their summary, both with the corpus by `OR`, none with all three off (`EMPTY_QUERY`); their tag filtering in any case, the empty list no filter, a row's tags; a tag not theirs refused by all seven routes; the facets, the timeline, the date order, the inspector's counts and empty terms, the concordance and the My Tags counts over the same match. Each write found by the next search past every answer kept: a note deleted, a tag moved, a summary rewritten. A search sent to another address, and every search on a server that keeps no user data, finds none of the user's writing and refuses their tag.
  - `SignInTests.eachUsersSearchReadsTheirWritingAlone`, the done-when's two-user half, live behind the proxy: Alice's search first, so its answers are kept, then Bob's and no one's of the same search, which find none of her note, summary or tag through any route; her tag refused for him and for no one by every route; the tag an export gives both under one id filtering each one's own documents; and hers as she left them.
  - `SearchRequestTests`: `userTagIds` read and written back, and the refused fields' pointers.
- **FRUSParityTests,** 189 to 198:
  - `AttachedUserStoreParityTests`, 7 on each store: S14d's scratch run of the kit's own `SearchUserSourceTests` over the PostgreSQL copy, now in the repository on both stores, the store written through its own methods. Through the store, every route, the search, its count and keys, the filter key set, the facets and the tag counts, answers as the app's index answers over the same notes, summaries and tags; and the exact words, the case of a tag's id, a missing store and the plan's subqueries, read once a statement.
  - `SearchViewParityTests`, 2: the Mac's Search in, My Tags, the token's and the counts' words, each under its key in the app's source and in copy.ts; and `UserTag.chips`, the three chips and `tagFilterLabel`, as the app's code and `tagRules.ts` say them.
  - `ServedAPIParityTests.checkThreePassesThroughTheAPI` now shows its searches were the single user's, with their store attached: after the 482 queries, a note the user writes is found by the next search.
- **The web unit suite,** 309 to 321 tests in 35 files: Search in's chips, the sentence with all three off, the row hidden with no user data, My Tags' counts, switch and token, the token for several tags, the row's chips; `searchState`'s scopes and tags; `tagRules`.
- **The browser suite,** 47 to 48 tests, at the root and under the path: `search-own-writing.spec.ts`, by keyboard, with axe: the note's, the summary's and the corpus's documents, d1's ◆ Berlin, Notes and Summaries off, all three off and the Mac's sentence, each on again, My Tags opened and counted, Berlin switched on, its token, and its clearing.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** with `scripts/swift --postgres`, PostgreSQL 18, through the heavy-job lock: this package's own targets build clean with no warning. All 2,535 tests pass, up from 2,521 on `main`, with the one named skip and nothing cancelled, the 58 that take a store kind on both: FRUSLightCoreTests 153, FRUSLightServerTests 196 and FRUSParityTests 198, the others as on `main`. The checks print:
  - "check 3 through the API: 482 queries, 482 identical and 0 reordered only within Mac tie groups, every record the kit's own, each searched with the user's store attached; 482 compiled as the golden file says, 43 refused; the live index unchanged", the row's done-when;
  - the Query Inspector's 482 queries inspected through the API as the kit inspects them, with their scoped counts and empty terms, and the facets, the timeline and the concordance through the API as the kit's, each now through the single user's attached store, which holds nothing of theirs there.
- **Mutation checks,** run once and put back, each through the lock:
  - with the user left out of a kept answer's key, `eachUsersSearchReadsTheirWritingAlone` fails, Bob given Alice's kept answers, and `eachWriteIsInTheNextSearch` fails;
  - with the mark frozen, `eachWriteIsInTheNextSearch` fails, a deleted note still found, and so does `theSearchMarkMovesWithEachWriteTheStoreCommits`, on both stores;
  - without the address check, `aSearchThatActsForNoOneFindsNoOnesWriting` fails, a search sent to another address finding the user's note.
- **A review** read the diff cold. It found one defect, in the PostgreSQL store alone. `ready()` cleared the stale copy's flag before it counted the copy made again, and `searchMark()` read the flag before the count. So a search in that gap, after a write whose copy failed to commit, could be given an answer kept from the stale copy under the new mark. Fixed as above; it needs a commit to the copy to fail, so no test reaches it. The review found the routes, the keys, the guard's terms and the browser app's state sound.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 321 tests in 35 files.
- **The browser suite,** over an image of the branch under a tag and port of its own (`frus-light:s17d`): a scratch copy of the smoke test, its root phase alone, passes, with the new spec and the search specs beside it, `facets`, `inspector-order`, `readings`, `search-read-cite` and `tags`, 10 of 10 in Chromium, axe finding no violation. The whole suite, twice, and the sign-in phase are CI's compose job's.
- **CI on #76 at `02fd64b`:** the swift job, amd64, with its PostgreSQL service, passes with the same counts per target and the one named skip, and prints check 3 through the API as above, 482 identical; the web job and the image builds for amd64 and arm64 pass; and the compose job passes in 16 minutes, the browser suite's 48 tests at the root and 48 under the path, the new spec among them, then the sign-in phase and its spec. The review's fix and these records follow it.
- **CI on #76 at `1740ce3`,** the review's fix and these records: every job passes as at `02fd64b`, at the same counts, the compose job in 12 minutes.
- **At the merges with `main`,** at `6b413b0` (#78, S16e's follow-up's records) and then at `ae1edf9` (#79, S18b's follow-up's records, and #80, the notes spec's races), each conflict was this log's top entry, and every entry is kept, this row's above theirs. #78 and #79 bring records alone; CI on #76 at `df50174`, after the first, passes every job. #80 brings the browser app's fixes for the notes spec's races, in files this row leaves alone, and a longer wait in the e2e helpers' `settle`, which the new spec does not call; over the merge the web job's steps pass, the unit suite's 325 tests in 35 files among them. The Swift code is `1740ce3`'s, so its runs above stand.

**Records**

- `docs/SPEC.md`: Search's S17d bullet, the API's user half of every search endpoint, `userTagIds`, the answers kept by user and mark, the refused fields, and `GET /me/search/tags` under the user's data.
- `docs/INSTALL.md`: searching one's own writing, and the API's fields.
- `docs/PLAN.md`: the row's done paragraph. `docs/COORDINATION.md` §1: the server searches with #1806's source.
- README's status, and this log.

**Next: S17e,** saved searches, working corpora and volume scopes, whose saved `SearchParameters` now carry the user's `userTagIds`; with **S17f**, projects, the history and the method appendix, beside it, and S18c's pin move past FRUS-Explorer#1809.

## Session 18b, second follow-up: the keyboard notes spec's random failure

28 October 2026 · branch `claude/nice-kalam-7067e1` · [#80](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/80) · upstream `1c18b51e`, unchanged

`web/e2e/notes-keyboard.spec.ts`'s one test failed at random in CI's `compose` job, and `main` requires that check. S18b's session cited two runs: `main`'s own at `2a31f41` and #75's first attempt, a docs-only pull request on the same code. The job's logs hold five failures of the test in two days, at three of its steps: Save's focus on the reader's frame three times (line 100), Delete's focus on All Notes' heading once (line 150), and the link dialog once (line 69). One cause, in the app's focus handling, accounts for four; a second, in the spec's waits, failed ⌘K in local runs; the fifth's cause is narrowed, not proven. No upstream change, no pin move.

**Focus sent back before the dialog had gone, four of the five.** Each dialog's parent sends focus back in an animation frame, on the rule that the dialog has gone by then: "while it is open, all else is inert". A close from a press or a key holds to that, since React commits it before the next frame. A close after the dialog's request has been answered does not: React commits it in a later task. When a frame comes first, the parent's `focus()` lands on the page still inert behind the modal dialog and does nothing, and focus falls to the page's body when the dialog goes. The spec's Save and Delete are two such closes. A local run that logged every `focus()` call and every dialog caught it: All Notes' heading was asked to take focus while Delete Note? was open, the dialog went 0.4 ms later, and the active element was the body. The same holds for six closes, each after its request: the note editor's Save and Delete, Delete Note?, Remove Highlight, the summary editor's Save and Delete Summary?.
- **`closeAtOnce`** (`web/src/shell/Modal.tsx`) calls a dialog's close in `flushSync`, as the note editor's Escape already was, so the dialog has gone before any frame. The six closes use it.
- **`framesAtOnce`** (`web/src/test/frames.ts`) gives a unit test the quickest browser: each frame comes as soon as the task that asked for it is done, and focus outside an open modal dialog is refused. jsdom has neither. Four tests use it: the reader's Save and Remove Highlight, All Notes' Delete Note? and the editor's Delete, and the summary editor's Save and Delete Summary?. Each fails with its closes as they were, the two-step ones at their second step alone, and passes with `closeAtOnce`. The web app's unit tests go from 309 to 313.

**Keys pressed while ProseMirror still treats the editor as just focused.** For 200 ms after the editor takes focus, prosemirror-view's `DOMObserver.flush` takes a caret at the start of the text for the browser's own reset on focus, and puts the editor's selection back. In two local failures the spec pressed Home 144 and 177 ms after the editor took focus back from the link dialog, so Home was undone, Ctrl+Shift+→ collapsed the selection again, and ⌘K had nothing to link. `settle()`'s 60 ms covered only ProseMirror's 20 ms one.
- **`settle()`** (`web/e2e/notes.ts`) waits 250 ms and two frames, and its comment names the 200 ms. `notes.spec.ts`'s `selectInLine` presses Home the same way after focusing the editor.
- **The spec waits for the editor to hold a selection** before ⌘B and ⌘K: the formatting bar's Link is offered only over one, and over the first word it shows no link. A selection the editor never takes fails there by name, not at the missing dialog two steps on.
- **It settles once the new note's editor has focus,** before typing, as `settle()`'s rule asks and `notes.spec.ts` does.

**The fifth, narrowed.** In `main`'s run at `2a31f41`, ⌘B found no selection and set Bold for what would be typed next, so Link stayed unoffered and its Enter did nothing. The trace's frames show "note" selected in the text 10 ms after Ctrl+Shift+←, with Link still unoffered, and 16 ms later the caret back at the end: ProseMirror put its own selection back before it read the new one. Typing had begun 10 ms after the editor took focus, at the end of a 260 ms task that loaded the editor's code. Locally typing began 100 ms after focus, and 26 to 130 ms with the CPU throttled four times over, and the step never failed: 0 of 30 runs, then 0 of 50 throttled. The settle before typing keeps the keys out of the editor's first 250 ms, which hold both of the times ProseMirror puts its selection back.

**How it was checked,** on the owner's Mac with other sessions building (load averages 6 to 110), with images and ports of this session's own, through a scratch copy of `scripts/compose-smoke` that runs one spec, repeated, in both passes:
- **`main`'s app:** 15 of 15 at the root, 12 of 15 under the path. The three failures were Delete's focus once and ⌘K twice.
- **This branch,** twice: 20 of 20 at the root and 19 of 20 under the path, then 20 of 20 in each at a load average of 2 to 4. The one failure was the test's 30 s timeout, in a spike to a load average of 110: every step up to it passed, at 10 to 60 times its usual time. In CI the test takes 6.5 to 7.7 s, and the longer `settle()` adds about 1 s.
- **`scripts/compose-smoke --e2e`** with this branch's image: passed, the browser suite's 47 tests in each pass and the sign-in spec, at a load average of 4 to 15.
- **`scripts/npm run typecheck`, `run lint`, `test`:** clean; 313 tests in 34 files.

**Delivered:** the six closes committed at once, the spec's waits, the four unit tests and this log. The session's notes are in the shared notes folder, as `notes-keyboard-flake.md`.

**Next:** phase 2 goes on as it stood: S18c, the pin move past FRUS-Explorer#1809 ([#77](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/77)), then S18d; S17e and S17f after S17d's [#76](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/76). Should the first ⌘B's failure come back, a run with the shared note's diagnostic hook would show what put the selection back.

## Session 18b, follow-up: the link-alert test's random failure, upstream

28 October 2026 · branch `claude/elated-lederberg-fc1c0a` · [#79](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/79) · upstream `1c18b51e`, unchanged; [FRUS-Explorer#1811](https://github.com/joshbotts/FRUS-Explorer/pull/1811), merged as `32e295e5`

The Mac checks of FRUS-Explorer#1785, #1807 and #1809 each lost a re-run to `RichTextRestingCapTests`' link-alert test (#1360's capped editor), which failed at random at `v2` as at each branch, and #1810's first full run failed it too. The colour-picker test failed in #1785's, #1809's and #1810's. S18b's session asked for one pull request that stops the link-alert test failing, from `claude/link-alert-test-waits-for-its-presentation`, cut from `v2` at `fef96201`. It was labelled `Mac`, its body said "Mac verification requested", and the owner merged it on 28 October. It changes one file of the app's test target, which this repository neither compiles nor hashes into its golden files, and the app's plan, so no pin move needs it, and this repository changes only its records.

**The cause, found before anything changed.** A diagnostic build, never committed, gave the test a millisecond timeline: a 5 ms sampler of the alert's presentation state, the root's transition coordinator and both first responders, with the keyboard and editing notifications and the dismissal's completion. It followed 30 runs of the suite alone on the iPhone 18 Pro Max simulator (iOS 27.0) of S18b's runs.
- The test host's `dismissPresented()` dismisses the alert with `dismiss(animated: false)` and waited 3 s for it to go, its `settle`'s default. #1807's and #1809's bodies say 5 s; the file's other hosts allow 5, but this one 3.
- A non-animated dismissal took 2.1 to 4.4 s to finish, while the keyboard went back from the alert's field to the text view and its formatting bar. In the first 16 runs, the 4 dismissals over 3 s were the 4 failures, and the 12 that passed took 2.22 to 2.90 s.
- The alert always went, and focus always came back: the editor is not at fault.
- The test asked for the dismissal while UIKit was still presenting the alert, in 16 runs of 16. That is not the cause: asked once the presentation had ended, a dismissal took 2.1 to 2.7 s, and with the alert's field resigned first, 2.3 to 2.7 s.
- The colour-picker test fails in the host's other such wait, 3 s for the system colour picker to appear.

**#1811, in a commit, two records commits and a merge of `v2`,** in `FRUSExplorerTests/CollectionTests.swift` and the app's plan:
- `RestingCapEditorHost.presentationTimeout`, 15 s, for `presented(_:)` and `dismissPresented()`. It bounds a hang, not a pace: each wait ends when UIKit is done. `settle`'s 3 s stays for the suite's waits on SwiftUI's sizing.
- A new `finishedPresenting(_:)`, which the link-alert test waits for before its half-second hold over the alert and its Cancel. It costs the test 0.8 s a run.
- A log line with each dismissal's time, and the suite's version history.

**How it was checked,** each heavy job under the app's lock, from a clone at a real path, beside `v2` at `fef96201` built and run the same way, the same day, with Xcode 27.1, clean and unsigned:
- **The suite alone, 30 rounds alternating with `v2` in one hold of the lock:** the branch passed 30 runs of 30, and `v2` 30 of 30, the Mac being quiet then (load average 4 to 8). The branch's dismissals took 1.74 to 2.35 s.
- **On two simulators created for the run,** the condition the app's A4c and A4d sessions met, with their first boot's work loading the Mac (load average 20 to 330): `v2` failed 6 runs of 6 on the dismissal. The branch passed 5 of 6, its dismissals taking 3.0 to 6.1 s. Its sixth failed because the colour picker did not appear.
- **The full iOS unit run:** 7,752 tests in 929 suites at both heads, both failing only the 8 Keychain tests an unsigned build fails, with the 6 known issues of #1606, and skipping the same 17 tests and 2 suites. The editor suite passed at both.
- **`swift test`:** 3,191 tests in 389 suites at both, all passed; `FRUSCoreKitTests` 1,298.
- **The Mac app's symbols** are `v2`'s, name for name, and both builds had `v2`'s five and seven warning lines.
- **Again once #1810 had merged.** `v2` moved to `e1d68919`, and #1811 then conflicted in the app's plan alone, where both pull requests end with a session entry. A merge of `v2`, `2d0c80b8`, kept both entries, #1810's first; against `e1d68919` the branch changes the same lines as against `fef96201`. The whole check ran again there, beside `v2` at `e1d68919`: the same builds, symbols and issues on both, with 7,754 tests in 929 suites in the full iOS run and 3,192 in `swift test`. The runs of the suite alone were not repeated, since #1810 changes nothing the suite exercises. The owner merged #1811 at `2d0c80b8` while that check ran. `32e295e5`'s tree is `2d0c80b8`'s, so the check is of what merged. A records commit with its results, `10cb8dff`, reached the branch after the merge and is not in `v2`; #1811's body has them.

**Filed, not fixed.** After a cold boot, or on a new simulator, the system colour picker sometimes never appears. A variant of the host that allowed 60 s, never committed, saw it miss the first run on each of two new simulators, and one cold boot in three of the long-used one, though Text Color's action was delivered; the next run on each new simulator presented it within 2 s. No bound fixes that, so the colour-picker test can still fail on a simulator just created or booted, at either head.

**Delivered here:** this log. The session's notes, scripts and logs are in `~/Library/Caches/frus-linkalert/`; the diagnostic is on that clone's local branch `diag/link-alert-timeline`, never pushed.

**Next:** nothing for #1811. The first pin move past `32e295e5` takes it with nothing to change here, since this repository compiles none of it and its golden files hash none of it. Phase 2 goes on with S18c, the pin move past #1809 ([#77](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/77)), and then the move past #1810, whose needs #78's entry lists.

## Session 16e, follow-up: a stripped export's free pages, upstream

27–28 October 2026 · branch `claude/magical-taussig-4755a7` · [#78](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/78) · upstream `1c18b51e`, unchanged; [FRUS-Explorer#1810](https://github.com/joshbotts/FRUS-Explorer/pull/1810), open

S16e (#69) found that the Mac's Export Research Database…, with Include My Notes, Summaries, and Tags off, keeps words of the notes and summaries in the copy's free pages, and named the fix as an upstream pull request. The session that ran it asked for that pull request: `claude/strip-secure-delete`, cut from `v2` at `3af1fc07`, rebased onto `fef96201` once S18b's #1809 merged, labelled `Mac` with "Mac verification requested", and not merged. Under rule 4 it changes shared files, and this repository changes only its records.

**What the leak was, measured further.** The kit's strip nulled the columns and rebuilt `user_content` only after `VACUUM`, as it must, since `VACUUM` may renumber the rows the index is keyed on. So the pages that held the index of the notes and summaries were freed after the `VACUUM`, and macOS's SQLite, at `FAST`, writes nothing over a freed page. Those pages are the whole index:
- **Decoding FTS5's leaf format in them** gives back every term of the writing, with the rows and positions it was at: all 1,000 of the notes' terms and 1,000 of the summaries' in a 40-document copy, where a byte search found 6 and 5, and all 300,000 and 100,000 in a 30,000-document one.
- **Size decides it more than how the writing was written.** S16e's log puts its test's need for one write down to FTS5's automerge. Written a document at a time, the same 40 notes and summaries leave as much: 13 and 14 words found, and every term decoded. An index that fits in its table's root page leaves nothing, since a rebuild clears that page rather than frees it, and `FAST` zeroes what is deleted inside a page. The fixtures' one note and one summary are that small; any library whose writing outgrew a page leaked.
- **The app's own exports:** every one made with the switch off that this session read, raw and read-only, has free pages, every one holding data. The three golden exports of 13, 22 and 24 October, from a library with no writing, have 6, 3 and 5, the corpus's own terms, which the `frus_documents` rebuild freed. Theirs are the only counts quoted: a full export's free pages measure the owner's writing.

**#1810, in one commit and a records commit:**
- **Your-content index is emptied before the `VACUUM`** (`INSERT INTO user_content(user_content) VALUES('delete-all')`, "emptying your-content index"), after the `UPDATE`. The `VACUUM` then reclaims its pages with every other free page, and the rebuild after it rebuilds the index over empty columns. The copy is smaller by the size of the index: 2,481 pages against 4,722 in the 30,000-document copy, in the same time.
- **`PRAGMA secure_delete = ON` comes first** ("preparing to overwrite freed space"). SQLite writes zeros over whatever is freed on that connection after it, the pages the `frus_documents` rebuild frees among them. Either statement alone keeps the writing out; together, the space is reclaimed and nothing freed afterwards keeps what it held.
- **In the kit, not in the app's runner.** This server's own `secure_delete` before the kit's steps was a rule of the strip kept outside the kit. The steps' doc now says they run on one connection. A second `VACUUM` after the rebuilds would have dropped their pages too, but it could renumber the rows again.
- **The app's note 3** said the strip is an erase because of the `VACUUM`. It says now that everything that held the writing is freed before it, and what `secure_delete` adds.
- **Tests:** `ResearchDatabaseStripTests` pins the seven statements, and strips four copies of a 40-document index whose notes and summaries name 1,000 words each, all from `FAST`. The strip as it was leaves words of both in the copy's bytes and data in its free pages; the strip now, the pragma alone and the index emptied alone leave none, each held to what it does. `IndexDatabaseExporterTests` runs the export's own path at the platform's own setting. `FRUSCoreKitTests` goes from 1,298 tests to 1,299, and the iOS unit target from 7,752 to 7,754.

**How it was checked,** each heavy job under the app's lock, from a clone at a real path, beside `v2` at `fef96201` built and run the same way, Xcode 27.1, clean and unsigned:
- **The full iOS unit run:** 7,754 tests in 929 suites against `v2`'s 7,752, both failing only the 8 Keychain tests an unsigned build fails, with the same 6 known issues and the same 17 tests and 2 suites skipped. A run before the rebase also failed `RichTextRestingCapTests`' colour-picker and link-alert tests, which S18b found flaky on both heads that night; this one passed them.
- **`swift test`:** 3,192 tests in 389 suites against 3,191, all passed.
- **The symbol diff,** normalized as before: no name removed and none added, raw or normalized. The change is a static array's contents, doc comments and tests.
- **On `v2`'s code,** with the two test files copied alone into a `v2` worktree at `3af1fc07`, where the code they exercise is as at `fef96201`: the iOS unit target failed `stepsInOrder`, the kit's free-page test ("stripped: 6 and 5 of the words, 92 pages, 9 free, 8 free leaves holding data, secure_delete 2") and the export's own test, the control passing; `swift test` failed the same two kit tests. So the simulator's SQLite, like macOS's, writes nothing over a freed page.
- **Linux,** in a scratch worktree of this repository's `main` at `2a31f41` (the pin `1c18b51e`), with `v2` and then the branch copied over the submodule, each built clean with no warning:
  - at `v2`, 2,533 tests, every target passing but FRUSParityTests, whose 20 failing tests are golden-file staleness, since `v2` is past the pin;
  - at the branch, 2,534: `FRUSCoreKitTests` 1,299, the strip's suite among them, the same 20 stale tests, and S16e's `theStripLeavesNoWordOfTheWritingInFreedPages`, whose control expects the kit's steps at `FAST` to leave the writing's words ("Expectation failed: left.notes > 0 && left.summaries > 0");
  - skipped at both, the one named skip and the PostgreSQL store's seven tests, which need the database `scripts/swift --postgres` gives and this run did not.
- **A review** read the diff cold. It found that the leak's size, not how the writing was written, decides whether a test sees it, which corrects S16e's explanation and this pull request's first test docs; that the steps depend on one connection; and the second statement, `delete-all` before the `VACUUM`, which this pull request took. It also found that the copy is built on the destination's volume, which the pull request files.

**What the pin move past it brings:**
- **The server's own pragma can go.** `IndexImporter`'s strip runs `ExportChecks.stripSetting` before the kit's steps, and past this pull request the first step does the same.
- **S16e's free-page test needs its control changed.** `theStripLeavesNoWordOfTheWritingInFreedPages` runs all the kit's statements at `FAST` and expects words left, and over this branch it fails, as above. The control should run the steps without the two new ones, as the kit's own test does, or be left to the kit's test.
- **`/readyz` names two more steps** while it strips: "Preparing to overwrite freed space in the server's copy" and "Emptying your-content index in the server's copy". S16e's first test reads the names from the kit's steps, so it passes as it is.
- **The golden files' export may be reused,** by the owner's choice: nothing on §5's indexing path changes, and from a library with no writing an export made past this pull request differs from one made before it only in what its free pages hold.
- **Check 5 could count free pages.** The pull request's `free-pages.py` counts a file's free leaf pages that hold any byte but zero, which needs no word of the writing. A Mac export made past this pull request should have none; `scripts/check-stripped-export` could add that count, where its snippets cannot see a single word.

**Delivered here**

- `COORDINATION.md`: the pull request in §2, and in §5's list of app changes the web edition needs.
- This log.

**Next:** the owner's Mac check of FRUS-Explorer#1810 and its merge; the first pin move after it takes it, drops the server's own pragma and changes S16e's control. On the plan's track, S17d.

## Session 18b: a collection resolves through a data source in FRUSCoreKit, upstream

27 October 2026 · branch `claude/optimistic-blackwell-d0048f` · [#75](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/75) · upstream `503a730b`, unchanged by this row; `1c18b51e` once `main` with S17c's pin move was merged in · [FRUS-Explorer#1809](https://github.com/joshbotts/FRUS-Explorer/pull/1809), merged as `fef96201`

This is phase 2's row S18b, the second of the two upstream collection rows, and Mac check 14 verifies it. S18a's #1807 made what renders a collection the kit's; this row makes what resolves one the kit's, so S18d to S18f can put a collection together on the server from its own store, as the app does from SwiftData.

This session opened one pull request on `FRUS-Explorer`, from `claude/collections-resolve-through-a-data-source`, branched from `v2` at `3af1fc07` (#1807's merge, `1c18b51e`, with #1808's website drafts). It is labelled `Mac` and its body says "Mac verification requested". The owner merged it the same day as `fef96201`, a squash with the branch head's tree (`d1b45392`). Under rule 4 the pull request changes shared files, and this repository changes only its records.

**#1809, in seven commits of moves and tests, and a records commit:**
- **The archival indexes and the document resolution** (`FRUSCoreKit/SourceExplorer/`): `CentralFilesIndex`, `VolumeSourcesIndex` and `LotClaimantsIndex`, public with their decoders, and `ArchivalResolver`'s document resolution over `ArchivalIndexes`, the three as one value. The stores that read the app's bundle and the front-matter resolution stay in the app, which passes `ArchivalIndexes.bundled`.
- **The five apparatus blocks** (`CollectionGeneratedBlocks`), public with their data source and records. The chronology's dates print in a locale the caller passes, and the tag union the thematic index reads is the kit's.
- **A collection's values and its composition's rules:** `CollectionExportOptions(composing:)` over the research data export's `CollectionExport`, `CollectionFootnoteStyle`'s two legacy mappings, `CollectionBodyDepth.available(summariesAvailable:)`, and the app's initialisers from its models to those values, which `ResearchDataExporter` now maps through, writing the same records.
- **The smart collection:** `SmartCollectionSnapshot.documentRefs(parameters:searchService:limit:)`, at most `resultLimit`, 1,000, and `snapshot(of:results:)`, the snapshot's values. The app inserts them.
- **The assembly,** `CollectionContentAssembly`: which notes and highlights an entry takes, the overrides cascaded through sections, body depth, headnotes, excerpts, the "See also:" line, the blocks, the Zotero items and the summary phase, over the collection's values, the entries' (a prose block's spans decoded by the host) and the notes as `ResearchNoteExport`.
  - `CollectionContentDataSource` is what it reads besides. The store's answers are the export's records, which this server's store already maps its rows to for S16d's export.
  - Its four export methods are the saved search's run, the volumes' download, the figure images' fetch and the summaries' generation. The assembly asks for them only for `.export`.
  - The app's `CollectionContentResolver` keeps every entry point and is the data source, each read the fetch it made before.
- **The `.fruscollection` file:** `FRUSCollectionFile`, its error, `encode`, `decode`, `makeFile(from:includeNotes:resolveNoteTexts:)` over a `CollectionExport` and `importedValues(from:)` into a `NativeCollectionImport`. Inserting SwiftData models, the file system and the index stay in the app.
- **Tests:** `CollectionResolutionTests` resolves a fixture collection over a volume the kit's own pipeline indexes and a store the test supplies, through every entry point, and pins the preview's items by SHA-256. `CollectionValuesTests` covers the rules over values. `FRUSCoreKitTests` goes from 1,286 tests to 1,298, and the iOS unit target from 7,739 to 7,752.

**How it was checked.** Each heavy job ran under the app's lock, from a clone at a real path, beside `v2` at `3af1fc07` built and run the same way: Xcode 27.1 on macOS 27.2, clean and unsigned, on an iPhone 18 Pro Max simulator (iOS 27.0). Other sessions' Docker jobs shared the lock throughout.
- **The seven commits,** made one by one in a worktree from `v2`, each built the kit with `swift build` and the Mac app with Xcode before the cold review's fixes (below); after them, the first five were built so again. The sixth differs from the seventh, the head built and tested in full, only by the seventh's test file, so its kit and Mac builds compile the head's sources.
- **The full iOS unit run:** 7,752 tests in 929 suites, against `v2`'s 7,739 in 927.
  - Both fail the 8 Keychain tests an unsigned build fails, and show the 6 known issues of `v2`'s system-log test.
  - The branch's run also failed `RichTextRestingCapTests`' colour-picker and link-alert tests, #1360's editor, which this does not touch. Run alone afterwards, alternating the heads from the same builds, the colour-picker test passed every time, and the link-alert test failed 4 of 18 runs at the branch and 2 of 18 at `v2`, each on the 5 s wait #1807 describes, which is within chance; the last six rounds, with `v2` first, passed at both.
  - Both skip the same 17 tests and 2 suites.
  - The branch's run took 996 s against 634. The difference is spread over 40 suites, led by indexing tests and one that hosts the real collection editor, whose two siblings took the same time at both heads; the two new suites took half a second.
- **`swift test`:** 3,191 tests against 3,179, all passed; `FRUSCoreKitTests` 1,298 against 1,286.
- **The symbol diff,** normalized as before: 251,475 names on `v2` and 251,932 on the branch, 614 removed and 1,071 added.
  - 416 of the removed are the resolver's private machinery, which reappears in the kit's assembly.
  - 148 name the resolver's `SmartDocumentRef` or `ResolvePurpose`, now the kit's types, with every entry point whose signature names them.
  - The other 50 are the blocks' functions that gained a locale, closures whose code moved into the kit, and `lotResolution`, internal now.
  - No moved type that keeps its name changes its mangled name.
- **Both builds** had `v2`'s five and seven warning lines.
- **Every test collection, resolving as before.** A scratch suite, appended to `CollectionTests.swift` for each run and never committed, built test collections in SwiftData over a volume a real pipeline indexed, resolved them through every entry point of `CollectionContentResolver` (preview, capped preview, export, summary-only, documents only, entry by entry, the smart path and its capped preview), and wrote the `.fruscollection` file, its import and a smart snapshot.
  - It ran three times at each head, alternating, and every file was the same at both.
  - The one difference was the order in which an unsorted SwiftData fetch returned one document's two highlights. It changed from run to run at `v2` itself, and every exporter sorts highlights by offset before drawing them.
- **Linux,** in a scratch worktree of this repository's `main` at `8e6d681`, with the branch and then `v2` copied over the submodule:
  - **the kit:** `FRUSCoreKitTests` ran 1,298 tests, against 1,286 at `v2`, with the one named skip. The fixture collection resolves over the kit's own index there, and its pin holds;
  - **the rest:** every other target passed but the parity suites, whose 42 issues are the same tests at the branch and at `v2`;
  - **2,466 tests in all,** against 2,454;
  - **public access:** a scratch file in `FRUSLightAPI`, never committed, imported FRUSCoreKit without `@testable`, implemented the data source and used every name the pull request makes public, and the target built.
- **Linux again, over `main` at `2fac971`,** after S17c's pin move to `1c18b51e`, which this branch starts from: the package built clean with no warning, and ran 2,482 tests against the 2,470 CI ran at that commit: `FRUSCoreKitTests` 1,298 against 1,286, every other target's count the same. Every target passed but the parity suites, whose 21 issues in 20 tests are all the golden files' staleness: their provenance's source digest hashes `FRUSCoreKit/` and `FRUSExplorer/` whole, so the five files read as made from other app sources until the pin move runs `scripts/make-golden`. Every parity check that reads the app's source passed, `ExportParityTests`' mirror of the exporter and `ImportParityTests`' reads of `Models/Collection.swift` among them, and the public-access file built again.
- **The records:** `CodingStandardsAuditTests` and `EditableContentKeyTests` passed again at the records head, 84 tests in 2 suites.

**For S18c, the pin move past #1809 alone** (S17c's move took #1807):
- **No parity test needs pointing anywhere.** Over `main` at `2fac971`, with this branch copied in, every parity check that reads the app's source passed. `ExportParityTests`' mirror of the exporter still finds its line: the collection mapping is now `CollectionExport(collection, entries: (entriesByCollection[collection.id] ?? []) .sorted { $0.sortOrder < $1.sortOrder } .map(CollectionEntryExport.init))`, the fields themselves in the app's new `CollectionEntryExport.init(_:)` and `CollectionExport.init(_:entries:)` (`Models/Collection.swift`), the same fields as before.
- **The golden files need `scripts/make-golden`:** their source digest hashes `FRUSCoreKit/` and `FRUSExplorer/` whole, so all five read as stale past this pull request, and those 21 issues were the run's only failures.
- **Nothing on §5's indexing path changes.** No file of the parser, `IndexingPipeline.swift`, FTS5Store, SourceNoteKit, `FRUSExplorer/Resources`, `project.yml` or `Package.swift` changes, so the golden files' export may be reused, by the owner's choice.
- **`Package.swift` needs no change:** the kit's new `SourceExplorer/` folder is compiled by folder, and `tools/mac-golden` lists `FRUSCoreKit` whole.
- **What S18d to S18f call:**
  - `CollectionContentAssembly`, with `Entry(_:proseParagraphs:)` (the codec decodes a prose block's RTF, and the introduction's, into spans) and `CollectionContentDataSource`, whose store reads answer with the export's records (`DocumentHighlightExport`, `GeneratedSummaryExport`, `UserTagExport`, `DocumentTagAssignmentExport`), the notes passed in as `ResearchNoteExport`.
  - The assembly and its data source are `@MainActor`, as `BatchCitationRunner` is, so the server resolves a collection on the main actor. Passing `locale: Locale(identifier: "en_US")` prints the chronology's dates as the app does.
  - The data source's export methods are the server's: `smartDocumentRefs()` runs the saved search through `SmartCollectionSnapshot.documentRefs(parameters:searchService:)` with the user's search service, in either purpose; `prepareVolumesForExport` has nothing to do on a server that holds every volume; `fetchAbsentFigureImages` reaches the server's figure store, or nothing; `generateSummaries` answers stored summaries, and refuses the rest, since the server has no summarizer.
  - `ArchivalIndexes`, from the three files in `upstream/FRUS-Explorer/FRUSExplorer/Resources/` (`central-files-index.json`, `volume-sources-index.json`, `lot-claimants-index.json`), which the image will need to carry.
  - `NativeCollectionSerializer.makeFile(from:includeNotes:resolveNoteTexts:)`, `encode`, `decode` and `importedValues(from:)`; `SmartCollectionSnapshot.snapshot(of:results:)`; `CollectionExportOptions(composing:)` over a `CollectionExport`; `CollectionBodyDepth.available(summariesAvailable:)`.

**Delivered here**

- `COORDINATION.md`: #1809 in §2, merged, with its runs, and in §5's list.
- `PLAN.md`: S18c's row names #1809, and keeps S15d's notes export on its own ZIP writer, as S18a's log found.
- This log.

**Notes**

- **A cold review of the diff,** given the code and none of the session's conclusions, found no defect in what the app resolves, and six things that were fixed before the runs quoted: the `.fruscollection` writer looked each entry's notes up by id, so two synced copies of one id with different selections would share the first's; a smart collection's own entries were read, healing a legacy prose blob; a static export read the collection before its volumes' download, which can take minutes, where it read it after; the data source's doc said the saved search runs only for an export; the app's and the kit's composition rules were two copies (the app's now reads the kit's); and the divided-lot test passed without the rule it tests.
- **An unsorted SwiftData fetch varies its order from run to run.** Two highlights on one document came back in either order at the same head, so the comparison puts a document's highlights in offset order, as every exporter does before drawing them.
- **`main` moved during the session,** from `8e6d681` to `17507cb`: S17c's pin move (#68), the follow-up to S14b (#72), S16e's records (#69), S14b (#70) and its second follow-up (#74), S14e (#71), S14d (#73), and the records of the follow-ups to S16e (#78) and to this session (#79). This branch was brought up to it, and the Linux run repeated over `2fac971`, at S17c's pin.
- **Other sessions' Docker jobs shared the heavy-job lock all evening,** so the runs took longer than their own time.
- **Scratch:** under `~/Library/Caches/frus-s18b`: the clone and its WIP commits, the rebuilt commits' worktree, `v2`'s worktree, the logs, the scripts, the dumps, and a scratch worktree of this repository (`web-linux`).

**Next: S18c,** the pin move past #1809, merged as `fef96201` ([#77](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/77)). Beside it: S17d, search over the researcher's writing ([#76](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/76)), with S17e and S17f.

## Session 14d: the PostgreSQL store

27 October 2026 · branch `claude/clever-banach-5614db` · [#73](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/73) · upstream `1c18b51e`, unchanged

Phase 2's row S14d, on the server's track after S14c. The user store gains its second store, SPEC's option B: a PostgreSQL database beside `app.db`, which a deployment chooses with `FRUS_USER_STORE`. Every store method is one piece of code on both, and one conformance suite holds the two alike, in CI against a PostgreSQL service. No upstream pull request, no pin move, and no change to `app.db`'s migrations. Begun over `main` at `8e6d681`, pin `503a730b`; S17c's #68 merged meanwhile, and `main` at `7722a77` was merged in, so the row lands at `1c18b51e`, whose kit its search database is held to. S16e's #69 merged after it, and `main` at `2fac971` was merged in too, so S16e's store method is ported here, as below.

**What the kit's search reads,** at `1c18b51e`, the pin since S17c's [#68](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/68). `SearchUserSource.attachedStore(userId:)` (FRUS-Explorer#1806) reads two tables of the file attached as `user_store`, and nothing else of it:

- `user_search`: its `MATCH` and `bm25`, its `user_id`, `volume_id` and `document_id`, and `summary_text` and `note_text` by name, which the exact-word filter reads through the kit's own `frus_exact_word`;
- `tag_assignments`: `user_id`, `volume_id`, `document_id` and `tag_id`, for a tag filter (`tag_id = ? COLLATE NOCASE`), a row's tags (`DISTINCT upper(tag_id)`, sorted and joined), the tag counts and a tag's documents.

So the PostgreSQL store's copy holds both tables, the row's `user_search` and the tag assignments beside it, and the assignments keep their ids and the case of their tags.

**Delivered**

- **One implementation of every store method** (`Sources/FRUSLightCore/RelationalUserStore.swift`). The users, the corrections, and the tag, note, highlight, summary, project, import and export methods move from `SQLiteUserStore` onto `RelationalUserStore`, which both stores subclass. Each store gives its own connection, its read and its write transaction, and its own migrations. The statements are the SQL both read:
  - a `?` for each value;
  - NULLs placed by `NULLS FIRST` or `NULLS LAST` wherever an order can meet one, where six orders left them to SQLite's default before, which PostgreSQL reverses;
  - `rowid` for a row's place among its table's rows;
  - one function through the connection's dialect, SQLite's `instr` or PostgreSQL's `strpos`.

  An import reads the rows the store holds in the order of their ids, so where two ids differ only in case both stores find the same one. `UserStoreTransaction` carries the store's connection and the database the kit's search attaches: app.db itself, or the copy.
- **The PostgreSQL connection** (`PostgreSQLConnection.swift`), over PostgresNIO 1.33.2, which is 1.33.1 with the swift-crypto 5 the server resolves allowed. Its future-based queries are waited for on the caller's thread, as a SQLite call is: the routes run store calls through `Blocking.run`, off the cooperative pool, and NIO's event loops answer them.
  - A `?` goes as `$n`, outside quotes and comments. A value goes as SQLite keeps it, a text cut at a NUL as SQLite's binding cuts it, and a row comes back as SQLite gives it.
  - TLS by libpq's `sslmode` names, `verify-full` by default, with `sslrootcert`; `prefer`, `allow` and any other parameter are refused. Each connection gives `application_name` `frus-light`.
  - `PostgreSQLError` keeps PostgreSQL's SQLSTATE and message, where PostgresNIO's own errors print a placeholder.
- **The store** (`PostgreSQLUserStore.swift`) and **its migrations** (`PostgreSQLMigrations.swift`): `app.db`'s two, by number, in PostgreSQL's SQL. They make the 23 tables with their columns, keys and indexes, each with `rowid` as an identity column and every text in the "C" collation, and fold `index_corrections` into classification overrides. Each runs in a transaction of its own, under an advisory lock, which every write transaction takes too. A read is one `REPEATABLE READ` snapshot. A connection that has closed is made again for the next call. A store a newer build migrated is refused, and a failed migration says where it left the store.
- **The copy,** `/data/app/user-search.db`: removed, with any journal beside it, and made from the store at each start; then written beside each write, in a transaction committed after the store's. A note's or a summary's change writes its document's row of `user_search`; a tag change, the assignments of each document it touches; an import, all of the user's. A change the store took and the copy could not makes the copy again before the next call. `searchDatabase` names the file for the kit to attach: app.db for the SQLite store.
- **Configuration:** `FRUS_USER_STORE`, `sqlite` or the database's URL, and `FRUS_POSTGRES_PASSWORD_FILE`. A problem with either never repeats the URL. The server opens the store named (`Application.swift`) and logs its URL without the password.
- **`scripts/swift --postgres`** starts `frus-light-postgres`, PostgreSQL 18, on the Docker host's network, or uses the one running, and passes `FRUS_TEST_POSTGRES_URL` into the build container.
- **CI:** a `postgres:18-alpine` service on the swift job, which the Test step names in `FRUS_TEST_POSTGRES_URL`. Without it the PostgreSQL store's own tests are skipped, and the step's count of skips fails the job, so the service cannot go missing unseen. No job is added, so `main`'s required checks are still `swift` and `compose`.

**Decided here**

- **One implementation, not two.** A PostgreSQL copy of each method would leave every later row two methods to write and keep alike. Written once, a row writes a method once, in SQL both read, and its tests once.
- **Values as `app.db` keeps them,** a `Bool` as 0 or 1 in a `BIGINT` and a date as text, rather than PostgreSQL's `boolean` and `timestamptz`. One SQL text then serves both, a row moves between them unchanged, and an order of dates is an order of texts on both. The "C" collation makes PostgreSQL compare and order texts by their bytes, as SQLite does, and its `upper` fold ASCII alone.
- **Writes take turns,** by the advisory lock: so a rule that reads before it writes, the picker's Done, a merge, an import, meets no other process's write between, as under SQLite's write lock. Its key is a constant with the hash of the store's schema, so the tests' schemas do not wait for each other.
- **Each PostgreSQL migration in a transaction of its own,** as SPEC's Upgrades already said; `app.db`'s still run in one.
- **One server per PostgreSQL store** until phase 6's change feed: a copy follows its own process's writes alone (SPEC, option B).
- **PostgreSQL 14 or later,** in INSTALL. Nothing here needs more than 13 but a test's `pg_terminate_backend(pid, timeout)`, and 13 is past its end of life. CI tests 18.
- **An empty RTF stays empty** on both stores, never none: SQLite keeps a zero-length blob, and the test that first said otherwise was wrong.

**How a later row joins the suite**

- A store method goes in an extension of `RelationalUserStore`, in SQL both stores read: a `?` for every value; `NULLS FIRST` or `NULLS LAST` in every order that can meet a NULL; `rowid` for the order rows came in; a function only one store has, only through `UserStoreDialect`; and each value of the kind `UserStoreSchema` gives its column, `.integer` 0 or 1 for a `Bool`, `.text` for a date or JSON, `.blob` for bytes. A change to notes or summaries calls `refreshSearch(of:for:in:)`, a change to a document's tag assignments `copyTagAssignments(of:for:in:)`, and one across a user's rows `rebuildSearch(for:in:)`, which copies the assignments too.
- A migration goes in `UserStoreMigrations.all` and, by the same number, in `PostgreSQLMigrations.all`. `eachStoresMigrationsMakeTheTablesTheSchemaDescribes` holds both to `UserStoreSchema`.
- Its tests take `_ kind: UserStoreKind`, with `arguments: UserStoreKind.available`, and open their store with `UserTagTests.open(kind)`; `UserStoreRows` seeds and reads either store. `scripts/swift --postgres test` runs them on both before a push.
- **S16e, merged first (#69), ported here:** its `keep(_:summaryFormat:for:)` moved from `extension SQLiteUserStore` to `extension RelationalUserStore`, its refactor of the import's row writer and its deletion of a summary from a research database take `UserStoreTransaction`, and its tests of what the store keeps take a kind: `aSummaryFromAResearchDatabaseMayBeDeletedButNotChanged`, and four of `ResearchDatabaseImportTests`, through the importer, whose fixture now opens either store. Its statements read on both as they were, and the `rebuildSearch` it ends with copies the tag assignments it writes into the PostgreSQL store's copy.
- **S14b, merged first too (#70), ported here:** its backup and restore are `app.db`'s. The server takes its lock and makes its backups in `openUserStore`'s SQLite case alone, and adds the backup service only then; `SQLiteUserStore` keeps its `changeMarker()`, and the corrections stay on the shared base. For a PostgreSQL store `GET /api/v1/admin/backup` is `BACKUP_NOT_FOUND`, though the volume keeps an earlier `app.db`'s backups, and `frus-light backup` and `restore` refuse, naming the database service's own tools: `AdminBackupTests.aServerWithAPostgreSQLStoreHasNone`, and the PostgreSQL server's test in `HTTPTests` asks for one too.
- **S14e, merged first as well (#71), ported here:** its `signedInUser(_:at:)` moves from `SQLiteUserStore` onto `RelationalUserStore`, beside `user(_:)`, its `INSERT … ON CONFLICT (user_id) DO NOTHING` read by both stores, and `UserStoreConformanceTests.aSignedInUserIsMadeOnceWithTheirIdAsTheirName` holds it on both. Its three settings follow S14b's two in `ServerConfiguration`'s initializer, after `userStore`, and `UserDataFixture` takes both rows' arguments. INSTALL's word that whoever runs the server can read everyone's research names the PostgreSQL store's database too.
- **S17d:** the kit attaches `store.searchDatabase`.

**Tests**

- **FRUSLightCoreTests,** 106 to 121:
  - `UserStoreConformanceTests`, 6 since #71, each on both stores: each store's migrations held to `UserStoreSchema`, and a store opened again migrating nothing; a user a sign-in names, made once, with their id as their name; a document's newest correction taking a change, the corrections oldest first and one with no time first of all; values in several scripts, a NUL, an RTF's bytes, an empty RTF, an integer at its end and a double; and the database search attaches after every kind of change, read through the kit's own statements at `1c18b51e`.
  - `PostgreSQLConfigurationTests`, 3: a URL's parts, the URLs refused, and the placeholders' numbers.
  - `PostgreSQLUserStoreTests`, 6, where a database is named: a store at migration 1 reaching 2 with its corrections; a failing migration leaving the store at the one before; a store a newer build migrated, refused; each start making the copy from the store, whatever an earlier process left; a closed connection made again; two stores' writes taken in turn.
  - `ConfigurationTests`, 1 more: `FRUS_USER_STORE` and its password file, whose problems never repeat the URL.
  - The method suites' 37 tests take a kind, so with the conformance suite's 5, 42 tests ran on both stores before #71.
- **FRUSLightServerTests,** 172 to 174, in `HTTPTests`: a server whose `FRUS_USER_STORE` names PostgreSQL keeps a user's tags there and their assignments in its copy, and makes no `app.db`; one it cannot reach stops its start, naming the store without its password. After #70 that server has no backup to give, and so has `AdminBackupTests`' `aServerWithAPostgreSQLStoreHasNone`, whose configuration names a PostgreSQL store, though its volume keeps a backup of `app.db`: 187 then, S14b's among them.
- **FRUSParityTests,** 1 more: `AttachedUserStoreTests`, on both stores, the kit's own search at `1c18b51e` over the fixture index served read-only with the store's search database attached, as S17d will serve it: a user's notes, summaries and tags, written through the store's methods, found by their words, their exact words, their scopes and their tags, the other user's never, a row's tags and the tag counts as the store holds them, and each change, an assignment an import brings included, in the next search.
- **Mutation checks,** run once and put back: without the advisory lock, `twoStoresOnOneDatabaseWriteInTurn` fails, a document carrying a tag twice; without the picker's Done's copy, `theSearchDatabaseHoldsWhatTheKitsSearchReads` fails, on PostgreSQL alone.

**Checked against the kit at `1c18b51e`,** before #68 merged, in a scratch worktree outside the repository: S17c's #68 at `3e03c12` with this branch merged, the submodule at `1c18b51e`. There the kit's own `SearchUserSourceTests` ran with its store swapped for a PostgreSQL store's copy, written through the store's methods: the notes, the readers' own summaries, and the assignments by import, with their ids and the case of their tags. All 7 of its tests passed, among them "every route answers as the app's index answers over the same notes, summaries and tags" and the plan test that reads the store's rows once a statement. Once #68 merged, `AttachedUserStoreTests` holds the same in the repository, on both stores; the scratch file is in the side sessions' notes for S17d.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** with `scripts/swift --postgres`, PostgreSQL 18, before the merge with #68, at `503a730b`: this package's own targets build clean with no warning. All 2,376 tests pass, up from 2,359 on main then, with the one named skip and nothing cancelled: FRUSLightCoreTests 121, in about 15 seconds, and FRUSLightServerTests 174, the others as on main.
- **CI's swift job on `c2c8513`,** the first at `1c18b51e`, amd64, with its PostgreSQL service: every target passed but FRUSParityTests, the conformance suite's 42 tests on both stores among them, with FRUSLightCoreTests 121, FRUSLightServerTests 174 and FRUSCoreKitTests 1,286. FRUSParityTests' failures were all `AttachedUserStoreTests`' searches for either of two words, alike on both stores: `SearchService` reads no `booleanMode`, and the search's parser reads an `OR` written in the query, as the kit's own tests write it, so `zanzibar quixotic` asked for both. Written so (`364b9e8`), the test passes on both stores here, through the heavy-job lock.
- **CI on #73 at `364b9e8`** is green. The swift job, amd64, with its PostgreSQL service, passes all 2,472 tests, up from 2,454 on main, with the one named skip and nothing cancelled: FRUSLightCoreTests 121, FRUSLightServerTests 174 and FRUSParityTests 189, the others as on main. The web and compose jobs pass, the compose job's image with PostgresNIO linked and no client tools, and the image builds for amd64 and arm64.
- **After the merge with #69,** at `c4c1aa0`, on Linux, arm64, with `scripts/swift --postgres` and through the heavy-job lock: FRUSLightCoreTests 128 and FRUSLightServerTests 183, S16e's tests among them, and `AttachedUserStoreTests` pass, 48 tests on both stores: the 42 before, S16e's summary that may be deleted, four of `ResearchDatabaseImportTests` and the kit's search over each store's file.
- **After the merge with #70,** at `1f06f29`, the same way, this package's targets built clean, with no warning: FRUSLightCoreTests 148 and FRUSLightServerTests 187, S14b's tests among them, and `AttachedUserStoreTests` pass, the PostgreSQL store's tests run, none skipped.
- **After the merges with #74 and #71,** at `e87a642`, the same way: FRUSLightCoreTests 152 and FRUSLightServerTests 192, S14e's tests among them, and `AttachedUserStoreTests` pass, `aSignedInUserIsMadeOnceWithTheirIdAsTheirName` on both stores. CI's compose job had failed at `429e6de`, before #71's merge brought its fix to the smoke test's log checks.

**Records**

- `docs/SPEC.md`: the user store's section, the configuration table's `FRUS_USER_STORE` and `FRUS_POSTGRES_PASSWORD_FILE`, the disk layout's copy, what option B's phase-2 half is, and, after #70, a PostgreSQL store's backups in Backups and the admin's route.
- `docs/INSTALL.md`: A PostgreSQL user store, with a `compose.override.yaml` recipe, and a line in Settings; after #70, that store's backups there, in Backups and restore, and in the errors' codes.
- `docs/PLAN.md`: the row's done paragraph.
- `CLAUDE.md`: `scripts/swift --postgres test`, and where a store method goes.
- README's status and architecture; and this log.

**Next: S17d,** which S17c's #68 has opened, searching through the kit with each store's `searchDatabase` attached, as `AttachedUserStoreTests` does; holding the search's user half to S14e's two-user test.

## Session 14e: sign-in through a trusted proxy

27 October 2026 · branch `claude/zen-volhard-bf9e37` · [#71](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/71) · upstream `503a730b`, then `1c18b51e` from `main`, unchanged by this row

Phase 2's row S14e, the last of the three asks of the shared deployment behind an organisation's reverse proxy and single sign-on, after S14f's path and S14g's releases. With `FRUS_AUTH=header` a proxy that signs people in names each in a header, the server takes the header from the proxy's address alone, and each user's research is theirs. No upstream pull request, no pin move and no schema change: the `users` table S2 made takes the new users.

**Delivered**

- **The settings** (`Sources/FRUSLightCore/Configuration.swift`): `FRUS_AUTH=header`, with `FRUS_AUTH_HEADER`, a header's name, `X-Forwarded-User` by default; `FRUS_TRUSTED_PROXIES`, IPv4 and IPv6 addresses and CIDR ranges separated by commas or spaces, each an `AddressRange`, which holds an IPv4 address as IPv6 maps it, so that a peer in either form matches; and `FRUS_ADMIN_USERS`, names separated by commas. The server does not start in header mode without a proxy, or with a range of every address, nor with any of the three set under another mode, which would leave every visitor one user. `local` stays phase 3's.
- **The one step** (`Sources/FRUSLightAPI/UserData.swift`): `ProxyHeaderResolver`, S14c's `UserResolver` for header mode. The peer must be in the list; the header's one value, at most 256 bytes of UTF-8 with no control character, is the user, made in the store the first time with it as their id and display name (`signedInUser(_:at:)`, an insert that keeps a row already there), and held in memory after, as the single user is, so that `GET /me` does not wait on an import; an admin, with the three roles, if `FRUS_ADMIN_USERS` names them, and otherwise a reader. `TrustedProxyGuard`, in the router after `/healthz` and `/readyz`, refuses every other request from a peer outside the list, the browser app and the paths no route answers included. The refusals are `PROXY_NOT_TRUSTED` and `NOT_SIGNED_IN`, both 403, and the log names each refused peer the first time, so an operator finds the proxy's address as the server sees it. The context's `peerAddress` is the connection's own.
- **The browser app:** the header says "Signed in as" the user, and the footer, under the line on the Office of the Historian, that whoever runs the instance can read everything it keeps for them, as SPEC's Privacy asks. Neither shows without sign-in, whose one user runs the server.
- **The install guide:** Signing in through the proxy, with its recipe for nginx and oauth2-proxy under a path; the address to trust for a proxy on the host, the Compose network's gateway, and the command that prints it; research kept before sign-in, which is `owner`'s, moved by an export and an import; the four settings; and the two codes. `compose.yaml` passes the four from `.env`.
- **The smoke test,** a last phase: nginx with the recipe and a stand-in for oauth2-proxy in its own container, on 127.0.0.1:4180, whose sign-in page takes a name; the server made again with nginx's address alone in the list and alice an admin; curl through the published port, from the Compose network's gateway, refused with a header naming alice, for `/api/v1/me`, the app, the API and the reader's script, and answered for the health endpoints; through nginx, no session asked to sign in, alice's session alice whatever header the browser sends, bob's bob, her tag not his, and the reader's scripts and figures reached without a session; then the sign-in spec, and the container's health check.
- **The browser suite:** `sign-in.spec.ts`, which runs alone where `FRUS_E2E_SIGN_IN` is set, as the smoke test's last phase sets it through `scripts/npm`, and is left out everywhere else (`playwright.config.ts`).

**Decided here, each the web's own**

- **"Any other request is refused" is read for the peer.** A request from an address outside the list is refused everywhere but `/healthz` and `/readyz`, whatever it names, so the server is reached only through the proxy; one from the proxy that names no one reads the corpus, the reader and the browser app, and nothing under `/api/v1/me`. The health endpoints answer anyone, for Docker's health check, which asks from inside the container, and a proxy's.
- **The reader's frame needs two locations without a session.** Before the recipe was written, Chromium showed that a sandboxed frame's requests for its scripts and images go `Sec-Fetch-Site: cross-site` and carry no `SameSite=Lax` cookie, which a session's is: nginx with a cookie check logged the frame's document with the cookie and its script and image without it. So the recipe forwards `/reader/` and the figures without the check, and with the header removed; they are the same for everyone. The browser suite's highlight is the proof that the frame's scripts arrive.
- **Every location sets the header,** to the session's user or to nothing, which nginx then leaves out, so a header the browser sends never reaches the server; the smoke test sends one.
- **The address to trust for a proxy on the host is the Compose network's gateway:** a connection through the published port reaches the container from it, as Docker Desktop showed on this Mac and Docker's proxy gives on Linux. Every program on the host reaches the port from the same address, and the guide says so.
- **A name is the header's value as it comes,** trimmed and never folded, so the proxy should send a stable one; `FRUS_ADMIN_USERS` names users the same way.
- **Both refusals are 403:** the server has no challenge a client could answer, which a 401 must carry; the proxy signs people in.
- **Research kept under `FRUS_AUTH=none` stays `owner`'s,** and a header that names `owner` acts as them. An export and an import move it to a signed-in user.
- **An export's writing, behind sign-in, is `owner`'s too:** S16e keeps the writing in an Import-mode export made with it for the store's single user, whom no one signed in through the proxy is unless the proxy names them so. The guide and SPEC say so, and steer a shared server to an export without the writing and each person's JSON import; whether header mode should refuse such an export instead is the owner's to decide.

**The search's user half** waits for S17d, which S17c's pin move, [#68](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/68), now in this branch from `main`, unblocks. The two-user test holds every route under `/api/v1/me`, and S17d's row must hold the search to it: one user's search finding none of another's notes, summaries or tags, and the tag filter refusing another's tag.

**Tests**

- **FRUSLightCoreTests,** 106 to 109: `ConfigurationTests`, 3: the header, the proxies and the admins read as listed; header mode refused without a proxy, with a range of every address, a host name or a range too long, a header's name that is none, and sign-in's settings under `none`; an address range's peers, an IPv4 one in either form, and the spellings it refuses.
- **FRUSLightServerTests,** 172 to 175: `SignInTests`, 3, on a real socket so that each request has its peer: a request from outside the list refused under `/me`, for the corpus, the reader's script, the browser app and an unknown path, with or without the header, making no user, while the health endpoints answer, and refused too where the peer is unknown; the header's user made the first time, an admin as `FRUS_ADMIN_USERS` says, a name in UTF-8, and no one, two names or one too long refused under `/me` while the corpus answers; each user's token their own; and the done-when's first half, alice writing through every kind of route under `/me` and importing, and bob reaching none of it by list or by id, through all 15 routes whose path names an id, the document's tags given hers, and every list and export, his note unable to name her tag or link her highlight, and the same export imported by both under the Mac's ids into two copies, his deleted and hers kept. `UserDataFixture` takes sign-in's settings, and `Browser` the proxy's header.
- **The web unit suite,** 304 to 306 in 34 files: `AppShell.test.tsx`, 2: the user named and the footer's line behind sign-in; neither without it, nor when the server names no one.
- **The browser suite:** `sign-in.spec.ts`, 1, in the smoke test's last phase alone: carol asks for All Notes, signs in on the proxy's page and arrives there, named, with the footer's line and none of the notes imported earlier for the server's one user, then highlights a phrase in the reader, drawn and kept; dave, in a browser of his own, signs in and finds no highlight; axe finds no violation on either. The 47 tests at the root and under the path are as they were.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** `scripts/swift test` on the branch: all 2,365 tests pass, up from 2,359 at #64, with the one named skip and nothing cancelled: FRUSLightCoreTests 109 and FRUSLightServerTests 175; the others as at #64.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 306 tests in 34 files.
- **`scripts/compose-smoke --e2e`** on the branch's image, on this Mac while other sessions' builds held its load average between 40 and 170: a scratch copy of the script that left out the two runs of the whole suite passed every step of its own over the same image, the new phase's among them, and the sign-in spec. Each of two whole runs failed two of the 47 tests at the root, a different pair each time, among `highlights-keyboard`, `notes-keyboard` and `summaries`, each on focus that came late or a shortcut's dialog that had not opened. The same three specs, three runs each over the same image, failed four of nine in the same ways with the browser app built from `main`'s shell, and one of nine with this branch's, so the load is the cause and not this branch; CI's runner, unloaded, decides.
- **CI on #71** is green at `b100cd0`: the swift job, at the same 2,365 tests per target, with the one named skip; the web job; the image built for amd64 and arm64; and the compose job, whose unloaded runner passed the 47 browser tests at the root and the 47 under the path, then the sign-in phase and its spec, in 13 minutes.
- **At the merges with `main`,** at `7722a77` (#68, S17c's pin move to `1c18b51e`), `3e94f10` (#72), `2fac971` (#69, S16e), `fb0b168` (#70, S14b) and `6479533` (#74), whose conflicts were the records', a few lines of code beside S16e's and S14b's (their log lines, their settings and S14b's injected resolver, kept with this row's), and the smoke test's header: this package's own targets, built clean, give no warning, and all 2,501 tests pass, with the one named skip: FRUSCoreKitTests 1,286, from the pin move, FRUSLightCoreTests 136 and FRUSLightServerTests 189, with S16e's, S14b's and #74's, the others as at #74. The web job's steps pass, the unit suite's 309 tests in 34 files among them; at the first merge, three had run out their second's wait in a run beside the Swift suite, and passed alone and in the whole suite after it. In the smoke test, S16e's two phases and S14b's backup and its restore run before the sign-in phase, which stays last, and a scratch copy of it with its own image tag, leaving out the two runs of the whole suite, passes over the merged image, the sign-in spec included.
- **S14b's check of the backup's hour** piped the server's whole log into `grep -q`, which stops at its match, so under `pipefail` the log's broken pipe failed it where the line was there, as on this Mac, whose Docker streams the log: it reads the whole log first now, as S16e's check says to, and so do the sign-in phase's two checks of tags.

**Records**

- `docs/SPEC.md`: Tenancy and roles, the operator's line under Privacy, The user under The user's data, the wait for a user's first request, and the configuration table's four rows.
- `docs/PLAN.md`: the row's done paragraph, Sharing beyond localhost and the risk of one store for a shared instance.
- `docs/INSTALL.md`: Signing in through the proxy, Behind a reverse proxy's warning, Settings, the API's codes and the notes.
- README's status, `compose.yaml`'s settings, and this log.

**Next: S17d,** search in notes, summaries and tags, now that S17c's pin move has merged, holding the search's user half to this row's two-user test. S16e and S14b run in sessions of their own, and S14d, the PostgreSQL store, is the server track's last row, whose conformance suite takes `signedInUser`.

## Session 14b, second follow-up: the grace runs from the last request to leave

27 October 2026 · branch `claude/mystifying-goldberg-7dfcf1` · [#74](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/74) · upstream `1c18b51e`, unchanged

#72's session found it while it fixed a flake in the same suite, and recorded it in #72's Notes; the owner started this session from its proposal. This pull request changes `RecentComputations`, its suite in `ClientConnectionTests.swift`, and this log. #72 merged while it was under way, so `main` is merged in at `3e94f10`. #69, S16e, merged while this one waited for review, so `main` was merged in again at `2fac971`, and the tests were run again there.

**What was wrong**

- `RecentComputations` keeps what a served index computed lately. With `stopsAbandoned`, it stops a computation no request waits for any more once its grace has passed.
  - Only `RetainedResults` has a grace, the default 250 ms: the results a date order keeps, 7,500 at most.
  - The grace is for the request a browser sends when the reader turns the date order round. It joins the computation the abandoned request began.
- Each request that left a computation with no one waiting began a wait of the grace. The wait then stopped the computation if no one waited at that moment, so the first wait to end decided, however recently the last request had left:
  - request A began the computation and left, and A's grace began;
  - B joined it within A's grace, and left, and B's grace began;
  - A's grace ended and stopped the computation, though B's had not passed;
  - C came within B's grace, found the computation stopped, and began another.
- The actor's doc comment said a computation is stopped "once `grace` has passed with none". A's grace had not passed with none: B waited during it.
- The cost was a date order's results computed again, in a narrow window: when the reader turns the order round twice in quick succession, and the second replacing request comes after the first grace has ended. `RecentSearches`' pages and counts have no grace, and the facets' sections are never stopped.

**The fix**

- Each computation counts its abandonments: the times it was left with no request waiting.
- A grace takes the count its own abandonment gave. When it ends, it stops the computation only if the count is still the same and no request waits. A later abandonment begins a grace of its own, so the grace runs from the last request to leave.
- Unchanged:
  - a cancelled request leaves at once;
  - a computation a request waits for runs on;
  - `RecentSearches`' grace of zero stops a computation at once;
  - without `stopsAbandoned`, nothing is stopped.
- For the tests:
  - the grace's sleep is a closure (`graceWait`), which a test replaces with a wait it ends by hand (`waitOutGraces(with:)`);
  - `gracesPassed` counts the graces whose check has run, so a test knows when one has ended without sleeping around it.
- The doc comments say the grace runs from the last request to leave.
- SPEC is unchanged. Its sentences on stopping still hold: a page or a count "is stopped at once", and the kept results "stop when no request waits for them". It never names the grace.

**The tests**

Both new tests use `RetainedResults`' settings and end each grace by hand. Each request begins only once the one before it has left, and the first test's third only once A's grace has been checked, so no two tasks reach the actor in an order left open, the cause of #72's flake.
- `theGraceRunsFromTheLastRequestToLeave` is A, B and C:
  - A's grace ends within B's, and C joins;
  - B's grace ends while C waits;
  - C gets A's computation's value, which is kept, with one computation started and none cancelled.
- `theLastRequestsGraceStopsTheComputation` holds the stop to the last grace:
  - two requests leave in turn, and the first's grace ends;
  - then the second's grace ends and stops the computation, which is computed again when asked for.
  - It passes before the fix too.
- The suite's four other tests are unchanged.

**Results**

All in `swift:6.4-noble` on arm64, while other sessions' builds loaded the Mac. Its load average ran from 11 to 142 during the runs.
- Each run is its own process of `FRUSLightServerTests`' test runner, unless it says otherwise.
- "Beside busy loops" means with 12 shell loops in the container, which has 10 CPUs.

- **Before the fix,** with the old stop logic and the tests' seam, never committed:
  - `theGraceRunsFromTheLastRequestToLeave` failed 50 of 50 runs, and 50 of 50 beside busy loops. Each failure was on the same three expectations: the third request's value, the value asked for again, and the computations started and cancelled.
  - A diagnostic run, never committed, printed "third.value 3, asked again 3, started 2, cancelled 1" in 5 runs of 5.
  - A run of the whole suite there failed only that test and #72's; `theLastRequestsGraceStopsTheComputation` passed, as it should.
- **After it:**
  - the two new tests passed 200 of 200 runs, and 200 of 200 beside busy loops;
  - one process repeating `theGraceRunsFromTheLastRequestToLeave` 5,000 times beside busy loops passed every repetition, and so did one repeating `theLastRequestsGraceStopsTheComputation` 2,000 times;
  - the whole suite, its six tests, passed 200 of 200 runs, and 200 of 200 beside busy loops. These ran before #72 merged, with its three lines applied by hand, and the test file they ran is byte for byte the merged one.
- **At the merge,** `ecc6f2e`, with this package's own targets rebuilt clean and no warning:
  - `scripts/swift test --filter FRUSLightServerTests` passed all 174 tests in 29 suites: #72's 172 and the two new ones;
  - `scripts/swift test` passed all 2,456 tests in its twelve targets, with the one named skip; no issue was recorded.
- **Again with `main` at `2fac971`** (#69) merged in, rebuilt clean the same way, with no warning:
  - the suite passed 100 of 100 runs beside busy loops;
  - `scripts/swift test --filter FRUSLightServerTests` passed all 183 tests in 30 suites, with #69's;
  - `scripts/swift test` passed all 2,472 tests, with the one named skip; no issue was recorded.

**Notes**

- **#72 merged while this was under way.** It changed three lines of the suite's first test, and this branch adds the helper above that test and the two new tests below the third, so the merge was clean.
  - Before #72 merged, the suite failed 7 of 100 runs beside busy loops without its lines, each time on #72's two expectations and never on another.
  - So the suite's runs here applied #72's lines by hand, and the merge gave the same file.
- **Two of the existing tests still wait out a real grace.**
  - `aComputationNoRequestWaitsForIsStoppedAndNotKept` waits, ten seconds at most, for a grace of 50 ms to stop its computation.
  - `aRequestThatComesWithinTheGraceJoinsTheComputation` needs its second request to come within a grace of 2 s, so it would fail if the machine stalled that long between its two requests.
  - Either could hold its grace with `waitOutGraces(with:)`. They are left as they were, since they pass and this task kept them.
- **Scratch:** the runs' scripts and logs are under `.build/linux/flake/` in the worktree `mystifying-goldberg-7dfcf1`: `before.sh`, and copies of #72's `runner.sh` and `repeat.sh`.

**Next: S17d,** search over the researcher's writing, now that S17c's pin move (#68) is merged. Beside it: S18b's upstream pull request, and on the server's track S14b (#70), S14e (#71) and S14d (#73).

## Session 16e: an export with the owner's writing

27 October 2026 · branch `claude/reverent-lumiere-6a5062` · [#69](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/69) · upstream `503a730b`, unchanged by this row; `1c18b51e` once `main` with S17c's pin move was merged in

Phase 2's row S16e, SPEC's last resort. Import mode in phase 1 refused a Mac "Export Research Database…" file made with Include My Notes, Summaries, and Tags on. It now takes one: the writing goes into the importing user's store, marked as from a research database, and the server's copy is stripped with the kit's own statements before it is checked and installed, the step S2 deferred. No upstream pull request, no pin move and no schema change.

**What the app's code says,** at `503a730b`:

- **The export with the writing** is the index as it is. `document_cache.summary_text` holds each document's newest summary that is not a headnote draft (`GeneratedSummary.newestNonDraftPerDocument`), and `note_text` every note on it, oldest first, joined by a blank line (`ResearchNote.indexedTextPerDocument`). `user_tag_ids` holds the ids of its tags, space-separated (`updateUserTagIds`), and `user_tags` every tag's id and name (`replaceUserTagNames`). The ids are `uuidString`s. The stamp says `my_writing_included` "1" and gives `exported_at` as `ISO8601DateFormatter` writes it.
- **Without the writing,** `IndexDatabaseExporter` runs `ResearchDatabaseStrip.steps`, the kit's since S16a, on its copy and stamps it "0".
- **Every summary the index keeps is the model's.** No app screen writes a document's summary by hand, and the user's own summaries are headnote drafts, which the index leaves out. The index keeps no summary's prompt, format or authorship, and no note's id, time, formatting, projects or tags.
- **SQLite's `secure_delete`,** measured: macOS 27.2's SQLite (3.54.0) defaults to `FAST`, which writes zeros over no freed page. Ubuntu noble's libsqlite3 (3.45.1), the image's, is built with `SECURE_DELETE`, so it is on.

**Delivered**

- **The importer** (`Sources/FRUSLightCore/IndexImport.swift`). For an export whose stamp says it holds the writing, `checking_writing` reads the writing from the copy. Two steps are new:
  - `stripping_writing` runs the kit's statements in their order, each named in `/readyz` in the kit's words, on the copy's connection with `secure_delete` on. It stamps the copy `my_writing_included = 0`, as the app stamps a copy it strips, and refuses a copy that still holds writing.
  - `moving_writing` comes after `checking_integrity` has checked the stripped copy, and keeps the writing in the user's store just before the copy is installed, so a file refused at any step still changes nothing.

  The import returns what the store made of the writing beside the index (`ImportedExport`). A refusal names the kit's statement it failed in. The strip asks for about twice the copy's size free, for `VACUUM`'s copy and its journal.
- **The writing and the store** (`Sources/FRUSLightCore/ResearchDatabaseWriting.swift`). `ResearchDatabaseWriting` is what the copy holds. `ResearchDatabaseMark` is how a record is known to be from a research database. `SQLiteUserStore.keep(_:summaryFormat:for:)` writes the records through S16c's row writer, which `importResearch` and it now share, and makes `user_search` again. `MovedWriting` and its report count four kinds, each as a JSON import counts a type.
- **The API** (`Sources/FRUSLightAPI/ResearchDatabaseImport.swift`). Import mode's importer is given the kit's `ResearchDatabaseStrip.steps`, and the store for its single user, whenever `FRUS_USER_DATA` is on. Notes and summaries carry `fromResearchDatabase`. `/api/v1/status`'s `lastImport` gains `writing`, the counts, and its message the report.
- **SQLite's temporary folder.** `FRUSLightServer` names `/data/tmp` in `SQLITE_TMPDIR` before anything opens a database, unless the environment names one. `compose.yaml` makes `/tmp` a tmpfs, held in memory, and `VACUUM`'s copy of the full corpus is as large as the index. The server's log names the folder.
- **The browser app.** The rail's note rows and All Notes' rows say "From a research database" of a note block, and the Summary section's header says so of a summary, in its prompt's place, with Delete… but no Edit….
- **The synthetic export:** `Tests/FRUSLightTestSupport/Fixtures/export-writing.sql`, two summaries, two note blocks and three tags, one of them on no document. `SyntheticExport.includesWriting` and `scripts/synthetic-export --writing` both read it, so the two cannot drift apart.
- **The Compose smoke test.** After its JSON import, it copies an export with writing into the running container, waits for the report, and checks that it names what moved, the mark and the JSON export. It copies the installed index out and runs `scripts/check-stripped-export` over it, then reads the note block and the summary back, marked, through the API. Then it runs the image in a container of its own whose `/tmp` holds 64 KB, where a 14 MB export with writing installs, and fails to with `SQLITE_TMPDIR=/tmp`. CI pulls `swift:6.4-noble` for the script's search.

**Decided here, each the web's own**

- **The mark is kept in values the app's model already has,** as the brief preferred, so the store gains no column and no migration. A column would also be one the Mac's envelope cannot carry (S16d), so the mark would be lost in an export.
  - **A summary carries the web's own prompt id,** `0EB00000-0000-4000-8000-000000000002`, which no prompt row holds. Its prompt id has to name something, since the index does not keep the real one. It is how the app knows a collection's headnote draft, by `0EAD0000-0000-4000-8000-000000000001`, and how the web knows its reader's own summaries, by `…0001`.
  - **A note has no field to hold a mark, so its id is the mark.** The id is a name-based UUID (version 5, RFC 9562) of its document, in a namespace of the web's own. It is recognized wherever the note goes, an export and an import included. A later export's block finds its earlier one and replaces it rather than standing beside it.
  - **The summary's id is named the same way,** for the same reason. So is each assignment's, which the index keeps without one.
  - **Tags need no mark.** They are the Mac's own records under the Mac's own ids, which the JSON export carries too, so a JSON import before or after finds the same tags. Their assignments are the same facts under ids of their own. A research database adds none for a document that carries the tag already, but a JSON import after it adds the Mac's beside them, which every reader takes as one, as the app does with two.

  The API gives the mark as `fromResearchDatabase`.
- **A research database replaces only what one brought before, while the reader has not changed it here.** The index keeps no record's own times, so each record takes the export's `exported_at`, which over-claims: a tag the Mac has not renamed since September looks newer than one renamed here in October. So:
  - **a block** is made at its export's time, and a change here stamps it later. A later export replaces a block only when the earlier one is unchanged here, and newer and different. A block's projects and tags stay, and a block the reader formatted here is plain again;
  - **a summary,** which no one changes here, is replaced when the later export's is newer and different;
  - **tags are only added,** never renamed. A Mac rename reaches the web through the JSON export, whose times are each record's own.

  So the same export again writes nothing. A stamp with no `exported_at` is refused.
- **What the user's own records hold already is not written again,** and is counted as kept:
  - a block the user's other notes on the document already are, joined as the index joins them, the standing mirror of `ResearchNote.indexedTextPerDocument`;
  - a summary whose text one of the user's summaries of the document already has;
  - a tag they hold, which keeps its name;
  - an assignment of a tag the document already carries.

  So a research database imported after a JSON import of the same library adds only what the JSON export did not bring.
- **A summary is a general one, not chunked, with no authorship and no time it was made.** The index keeps none of them. Every reader takes no authorship as an AI summary, which every summary the index keeps is, and the app ranks a summary with no time last. So the document's own summaries, which a JSON import brings, come first, and `user_search` takes the newest of them. A note block is a plain note.
- **The reader may delete a block or a summary from a research database,** but change only the block. A JSON import after a research database's brings the same notes and summaries again under the Mac's ids, so a summary that could not be deleted would stand beside its own copy for good.
- **A server that keeps no user data refuses such an export,** as phase 1 did, in the same words with the reason. An unstamped copy that holds writing is still refused, since nothing says when it was made.
- **Room for the strip is asked for before the copy.** An import with too little room is tried again every minute. If the room were asked for only after the copy, each try would copy the whole export to find there is none. So the importer reads the stamp from the file it was given and asks for three times the export's size, then asks again for twice the copy's before the strip.
- **The importing user** is the store's single user, whom `FRUS_AUTH=none` acts for and who copies the export into the drop zone. S14e, which brings more than one user, decides whose the drop zone's writing is.
- **The order puts the store last.** The brief's "moves …, then strips …, before it checks and installs it" runs here as: read the writing, strip, check, write the writing, install. Every check that can refuse a file comes before the one write outside the copy, which keeps the importer's rule that a refused file changes nothing. Only an install that fails after the store write leaves the writing kept without the index, and the import is then tried again, keeping what it kept.

**Found**

- **The kit's order leaves words of the notes and summaries in a stripped copy's free pages,** where SQLite does not write zeros over a freed page. The strip rebuilds both full-text indexes after `VACUUM`, as it must, since `VACUUM` may renumber the rows they index. The pages the rebuild of `user_content` frees then stay in the file, and they held the index's terms.
  - **Measured on a synthetic copy** of 4,000 notes and 2,000 summaries: after the kit's statements at macOS's `FAST`, 171 pages were free, and 24 of the notes' marker words, 23 of their other words and 10 of the summaries' were found whole in the file. With `secure_delete` on, none were.
  - **The Mac's own export,** S10's build-50 pair, read immutably, counts only: the free pages of the export made without the writing hold a stem of the writing that the corpus's vocabulary lacks.
  - **Why so few are found.** FTS5 stores all but the first term of each leaf prefix-compressed, so only a few terms are ever found whole. Check 5's 24-character snippets cannot see one at all, which is why S10's check 5 passed.
  - **So the app's footer overstates it.** "The words are gone rather than merely unlinked" is not quite so for a copy made on the Mac, and the fix is the app's: `secure_delete` before the strip, or a statement of the kit's own. That is an upstream pull request for a later session, with a Mac check.
  - **The server runs the statements with `secure_delete` on.** Ubuntu's SQLite already has it on, and the pragma keeps it so whatever SQLite the image carries.
- **Whether a test shows those words depends on how the index's segments came to be.** With the fixture's small writes before them, FTS5's automerge folded the strip's deletes into the terms before `VACUUM`, and nothing was left to find. The test writes its writing as one write, as a long-kept index holds most of its terms in segments merged long ago.
- **SQLite's Unix layer reads `SQLITE_TMPDIR` once, when SQLite starts** (`unixTempFileInit`), so the server sets it at the top of `main`, before anything opens a database.

**Tests**

- **FRUSLightCoreTests,** 106 to 113. `ResearchDatabaseWritingTests`, 5:
  - the ids are version-5 UUIDs, checked against RFC 9562's own example, one for each kind and document;
  - the two marks;
  - the writing read as the index keeps it, a blank block none and an id that is no UUID given one;
  - the report's words.

  `ImportTests` refuses an export with writing on a server that keeps no user data, and one whose stamp gives no time on a server that keeps it. `UserSummaryTests` deletes a summary from a research database, and refuses to change it.
- **FRUSLightServerTests,** 172 to 181. `ResearchDatabaseImportTests`, 9, through the server's own wiring, the kit's strip and the store:
  - **the row's done-when.** The steps in order. The installed index holds no writing in its tables, no term in `user_content`, the stamp of a copy made without it, and none of check 5's snippets or the writing's own words in its bytes, which the controls find in the export. The store holds every block, summary, tag and assignment, marked, and `user_search` finds them;
  - the same export again writes nothing;
  - a later export replaces the block and summary that changed, keeps the reader's tags on a block and a block the reader rewrote, and renames no tag;
  - what the user's records hold is not added again, a tag among them, which keeps its name;
  - a file damaged where only `VACUUM` reads it is refused and changes nothing;
  - too little room is the server's problem: asked for before the copy, and again before the strip;
  - **free pages.** Over 3,000 notes and 1,500 summaries, the kit's statements at `FAST` leave words of both in the file. The server's setting, run on a connection at `FAST`, leaves none, and so does the server's strip;
  - the report through `/api/v1/status`, the marked records through the user's routes, and a summary from a research database deleted but not changed.

  Two tests that list a note's and a summary's keys now list `fromResearchDatabase`, and the summary's `deletable`.
- **The web unit suite,** 304 to 307 in 33 files: the mark in the rail's rows, in All Notes and in the summary's header, which offers Delete… but not Edit… for a summary from a research database.

**Results**

- **Linux, `swift:6.4-noble`, arm64.** Before the review, at `503a730b`, all 2,372 tests passed with the one named skip. After the review's fixes and the merge of `main` with S17c's pin move, at `1c18b51e`, all 2,470 pass with the one named skip: FRUSLightCoreTests 113, FRUSLightServerTests 181, FRUSParityTests 188 and FRUSCoreKitTests 1,286, the others as before. They ran through `scripts/swift test` under the app's heavy-job lock, with this package's own targets built clean.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build clean, and 307 unit tests.
- **SQLite's temporary folder, in the image.** The branch's image was run with a 64 KB tmpfs at `/tmp` and given a 13.9 MB synthetic export with writing, whose `VACUUM` copy outgrows SQLite's page cache. It installed it, its log naming `/data/tmp`. With `SQLITE_TMPDIR=/tmp` forced, the same import failed while "reclaiming freed pages: database or disk is full", the server's problem, tried again later.
- **`scripts/compose-smoke --e2e`** on the branch's image passes: 47 browser tests at the root and 47 under the path, through nginx with INSTALL's recipe, and the smoke test's own steps.
  - **The new phase** imported `scripts/synthetic-export --own-text --writing` into the running container, whose root is read-only and whose `/tmp` is a tmpfs. The report named what moved, the mark and the JSON export.
  - **Check 5's script** ran over the index the server installed. It found 0 of the 11 snippets in its bytes, 0 rows with a summary, note or tag, 0 tags, and 0 terms in its `user_content`, where the export with writing's holds 56. Both controls held.
  - **The API** gave back the note block and the summary, marked.
- **CI on #69** was green at `5b90631`, before the review's fixes: the swift, web and compose jobs and both image builds.
  - **After the fixes and the merge,** the compose job's first run failed the new small-`/tmp` phase: it had copied the export into a container whose server had not yet made `/data/import`. The phase now waits for the drop zone, and fails at once on a refusal.
  - **At the next head,** the compose job passed both new phases in CI's own container. Check 5's script found none of the writing in the installed index, and the 13.7 MB export installed with `/data/tmp` and not with `/tmp`.
  - **The tag `frus-light:smoke`** that `scripts/compose-smoke` builds is shared by every worktree on this Mac. A check of the phase against it, after another session's run had rebuilt it from `main`, tested the wrong image.
- **A review** read the diff cold, by reading only. It found no fault in the import's order, in the candidate's cleanup on every path, in how faults are sorted, in the store's ids, or in S16c's row writer, which the refactor left as it was. It found these, and each is fixed:
  - **duplicate summaries the reader could not remove.** The report recommends a JSON import, which brings each summary again under the Mac's id, and the research database's copy, dated at the export, ranked first and was read-only. It now has no time it was made, so it ranks last, and it can be deleted;
  - **a full copy of the export every minute** when there was room for the copy but not for the strip. The room is now asked for before the copy;
  - **a later export reverting the reader's own changes.** Stamped with the export's time, a research database renamed a tag the reader had renamed here, and replaced a block the reader had rewritten, as "replacing an older copy", and counted unchanged tags as replaced. Tags are now only added, a block the reader changed is kept, and what is unchanged is not rewritten;
  - **a smoke-test check that could fail at random:** `grep -q` under `pipefail`, against a log still being written. The check also proved only the environment variable, so CI now runs the small-`/tmp` check too;
  - **a test that could not fail on CI,** since Ubuntu's SQLite zeroes freed pages by default. It now runs the server's setting on a connection at `FAST`;
  - **docs that said more than the code:** COORDINATION's contract and README's line still refused or misordered the writing; SPEC called the web's labels the export sheet's words (the sheet says Research Notes and Tags & Assignments), and put the journal in `/data/tmp`; and the browser app's readiness type lacked the two new steps.

**Records**

- `docs/SPEC.md`:
  - the Import procedure's step 3, and how Import mode takes a research database with writing;
  - the paths table's row, and the mapping's notes and summaries;
  - check 5, and the room a strip needs.
- `docs/PLAN.md`: the row's done paragraph.
- `docs/INSTALL.md`: the export step, the import's steps and status, the room, the refusal, and Bring your research from the Mac.
- `docs/COORDINATION.md` §1: the kit's strip the server runs, and its stamp.
- README's status; and this log.

**For later sessions**

- **Upstream:** the Mac's Export Research Database… with the switch off keeps words of the notes and summaries in its free pages, as Found says. It could run its strip with `secure_delete` on, or the kit's steps could begin with it. Mac check needed.
- **Check 5's script** finds no single word. A search of a stripped file's free pages for the writing's stems that the corpus lacks would find what Found found.
- **A JSON import after a research database's** brings the notes beside their blocks, which the reader then deletes. A rule that a JSON import drops a block its notes now hold whole would change S16c's "an import deletes nothing", so it is the owner's to decide.

**Next: S17d,** search in the researcher's notes, summaries and tags through the kit's search with the user's `user_search` attached, once S17c's pin move (#68) merges; with S14e, S14d and S14b on the server's track.

## Session 14b, follow-up: a request cancelled while another waits, tested in a set order

27 October 2026 · branch `claude/magical-spence-fdd44c` · [#72](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/72) · upstream `1c18b51e`, unchanged

S14b's session found it (#70, its notes), and the session that ran S14b asked for the fix in a pull request of its own. `RecentComputationsTests.aRequestCancelledWhileAnotherWaitsLeavesAtOnceAndTheValueIsKept` failed now and then, each time on the same two expectations: once in S14b's full `scripts/swift test`, while other sessions' builds loaded the Mac, and once in three runs of its suite alone. It predates S14b, and `main`'s CI had passed it every time. This pull request changes the test and this log, and `RecentComputations` is unchanged. #68, S17c's pin move to `1c18b51e`, merged while this one waited for its CI, so `main` was merged in at `7722a77`, and the tests were run again there.

**What was wrong**

- The test begins two tasks that ask `RecentComputations` for the key `a`, each with a computation of its own, which gives 1 for the first and 2 for the second. It waits until both requests wait, cancels the first, and opens the gate. It then expects 1 from the second, and 1 when `a` is asked again, with one computation started and none cancelled.
- The two tasks run on the global executor, so they reach the actor in no set order. When the second came first, its own computation began and the first joined it.
- From then on everything went as designed. The first left at once, and the computation ran on for the second and was kept, started once and never cancelled.
  - But it gave 2, so the two expectations of 1 failed, the two that failed in S14b's runs.
  - A diagnostic run, never committed, printed it: "second.value 2, asked again 2, started 1, cancelled 0".
- So nothing was stopped or begun again, and the first's cancel did not land too soon. The test already waited for both requests, and `value(for:compute:)` registers a request in the same turn of the actor that finds or begins the computation.
- The test has assumed its order since S12c wrote it (`ad48ebb`, #43). S12c's review (`9d5074e`) replaced its 20 ms sleep with the wait for both requests, which left the order open.

**The fix**

- The test begins the second task only once the first waits (`waitingCount(for: "a") == 1`). `aRequestThatComesWithinTheGraceJoinsTheComputation` already waits this way, and so does the facets' `aSectionAskedForWhileItIsComputedWaitsForThatComputation`.
- Its expectations, and their values, are as they were.

**Results**

All in `swift:6.4-noble` on arm64, while other sessions' builds loaded the Mac.
- Each run is its own process of `FRUSLightServerTests`' test runner, unless it says otherwise.
- "Beside busy loops" means with 12 shell loops in the container, which has 10 CPUs.

First at `503a730b`, over `main` at `8e6d681`. The Mac's load average was between 75 and 169 during the runs after the fix.
- **Before the fix:**
  - 5 of 50 runs failed, and 4 of 50 beside busy loops, each on the same two expectations;
  - one `swift test --maximum-repetitions 2000 --repeat-until fail` process beside busy loops failed at its 12th repetition, and the diagnostic run at its 17th.
- **After it:**
  - 200 of 200 runs passed, and 200 of 200 beside busy loops;
  - the whole suite, its four tests, passed 100 of 100 runs beside busy loops;
  - one process repeating the test 5,000 times beside busy loops passed every repetition;
  - `scripts/swift test --filter FRUSLightServerTests` passed all 172 tests in 29 suites.

Then at `1c18b51e`, with `main` merged in at `7722a77` and this package's own targets rebuilt clean, with no warning. The load average was between 36 and 50.
- 100 of 100 runs passed beside busy loops, and the whole suite passed 50 of 50.
- One process repeating the test 2,000 times beside busy loops passed every repetition.
- `scripts/swift test --filter FRUSLightServerTests` passed all 172 tests in 29 suites.

**Notes**

- **`RecentComputations`' grace runs from the first request to leave, not the last.** This was found while reading the actor for this fix, and has nothing to do with the flake.
  - Each request that leaves a computation with no one waiting starts a wait of `grace`. The first wait to end stops the computation if no one waits at that moment, however recently the last request left.
  - A scratch check over a copy of the actor, with a grace of 300 ms, showed it in 5 runs of 5:
    - A began the computation and left;
    - B joined it and left 250 ms later;
    - C came 100 ms after that, within the grace that B's leaving began, found the computation stopped, and began another (started 2, cancelled 1).
  - Only `RetainedResults` has a grace, of 250 ms. So the cost is a date order's results computed again, in a narrow window, when the reader turns the order round twice in quick succession.
  - A fix would let each wait stop only the abandonment that began it. Its test would want a grace it can end by hand, since a test that sleeps around a grace depends on timing.
  - The owner started it as a session of its own the same evening.
- **Scratch:** the runs' scripts and logs are under `.build/linux/flake/` in the worktree `magical-spence-fdd44c`, and the grace's check is under `.build/linux/grace-check/`.

**Next: S17d,** search over the researcher's writing, now that S17c's pin move (#68) is merged. Beside it: S18b's upstream pull request, S16e (#69), and on the server's track S14b (#70), S14e (#71) and S14d (#73).

## Session 14b: the user store's daily backup and its restore

27 October 2026 · branch `claude/nice-austin-7a6810` · [#70](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/70) · upstream `503a730b`, then `1c18b51e` with main at #68

Phase 2's row S14b, on the server's track after S14a. Since S15c the store holds the researcher's own writing, which may exist nowhere else. Now the server backs it up every day: seven copies in the volume, seven in a folder on the host. The API gives the newest, and a command puts one back with the server stopped. No upstream pull request, no pin move, no schema change.

**Delivered**

- **The daily backup** (`Sources/FRUSLightCore/UserStoreBackups.swift`), run by the server's `BackupService`.
  - **When.** The server looks when it starts, every five minutes, and when the hour begins: 03:00 by default, in the container's time zone (`FRUS_BACKUP_HOUR`, `TZ`). A backup is due when there is none, when the hour has begun since the newest, or when the newest is more than 24 hours old. So a Mac asleep at 03:00 backs up at the first look after it wakes.
  - **Unchanged since the newest.** Then no backup is taken. A SHA-256 of what each copy holds decides: every schema object's SQL and every table's rows in order, read in one transaction, a row at a time (`UserStoreBackup.fingerprint`). The newest backup is read once. The store is read again only when SQLite's count of its changes has moved since the last look: its own connection's `total_changes()`, and `data_version` for every other. S14a's `holdTheSame` is now that comparison.
  - **No research yet.** No backup is taken of a store that holds none. A new store's backup at the server's start would hold nothing, and would hold off the first that does, after the first import, until 03:00.
  - **The copy** is S14a's, through the backup API, named `app-<time>.db`. Seven are kept, and the copies before a migration or a restore are never among them.
  - **The host folder.** Each finished copy also goes, byte for byte through a `.partial` name and flushed, to `FRUS_BACKUP_COPY_DIR`. Compose sets it to `/backups`, mounted from `./backups` (`FRUS_BACKUP_DIR`). That folder keeps the newest seven of its own and the volume's, so a new volume's backups give up an old volume's one at a time. A folder that could not be written is filled at the next backup. A copy before a migration goes there too, at the start that makes it.
  - **`frus-light backup`,** run in the container, takes one now. The server's backups and the command's share `/data/app/backup.lock`.
- **The restore** (`UserStoreRestore.swift`): `frus-light restore <backup>`, with the server stopped, in a container of its own (`docker compose run --rm frus restore …`).
  - **The lock.** A server holds `/data/app/server.lock` shared, taken before it opens the store. The restore takes it exclusively or refuses, and a server that starts meanwhile waits. It is `flock`, on a file of its own: closing any descriptor of the store would drop the POSIX locks SQLite holds on it. It holds between containers on one Docker host.
  - **The check.** The backup, named in either folder or given by a path, is copied beside the store and checked there: `integrity_check`, `foreign_key_check`, the store's tables, and a migration from 1 to this build's. It may have no `-wal` or `-journal` beside it, and an archive's backup must match its manifest's size and SHA-256.
  - **The store it replaces** is kept as `app-<time>-before-restore.db`, through the backup API, `-wal` and all, and copied to the host folder. A store the API cannot read, as a damaged one may be, has its files moved there as they are.
  - **In place.** The store's side files are removed, so no `-wal` of another store is ever read with the backup, and one rename puts the backup in place. The next start migrates it forward, after S14a's copy.
- **`GET /api/v1/admin/backup`** (`Sources/FRUSLightAPI/AdminBackup.swift`, `Sources/FRUSLightCore/BackupArchive.swift`): the newest daily backup as one tar archive, `manifest.json` and then the backup, streamed from the handle that hashed it.
  - The manifest names the backup, its size, SHA-256 and migration; the server's version, migration, index version and SQLite; and every backup and copy kept, with whether the host folder holds each.
  - It needs the admin role, by the check S16c's import makes for the instance's corrections (`RequestUser.require`), and passes `/api/v1/me`'s guard. Its refusals are `ROLE_REQUIRED`, `USER_DATA_OFF`, `HOST_NOT_ALLOWED`, and `BACKUP_NOT_FOUND` before the first backup.
- **Compose:** `./backups` mounted at `/backups`, with `FRUS_BACKUP_COPY_DIR`, `FRUS_BACKUP_HOUR` and `TZ`.
- **The Compose smoke test** (`scripts/compose-smoke`):
  - At the start, the host folder is writable, the server names its backup's hour in `TZ`'s zone, America/New_York, and a new store is not backed up.
  - After the import through nginx and, since the merge with #69, S16e's exports, it backs up with `frus-light backup`, and a second run takes none.
  - It fetches the archive through the API: `tar -xf` opens it, its backup is the host folder's byte for byte, and the manifest names its SHA-256.
  - A restore beside the running server is refused.
  - It stops the server, removes the store, restores it, starts again, and reads the whole export back byte for byte, but for its time.
- **Tests:**
  - **FRUSLightCoreTests,** 106 to 126.
    - `UserStoreBackupTests`, 13: the hour and the day-old rule, in UTC and across New York's two clock changes; none when nothing changed, by the server's mark and by the command's read; none of a store that holds no research; one soon after a missed hour; seven kept beside the other copies; the host folder's own seven, a new volume's giving up one at a time, and one filled once it can be written; two at once taking one; the fingerprint and the mark; the names.
    - `UserStoreRestoreTests`, 6: a restore that keeps the replaced store, its log's last change among it, and leaves nothing beside the backup; an older backup migrated forward at the next start; every refusal leaving the store as it was; an archive restored as it is, read by tar, and refused once changed; a damaged store kept as its files; names and paths.
    - `ConfigurationTests`, 1.
  - **FRUSLightServerTests,** 172 to 175: `AdminBackupTests`, 3. The archive and its manifest, against the store; an admin alone; refused with user data off and to another host.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** this package's own targets built clean, with no warnings. All 2,382 tests pass, up from 2,359 at #63, with the one named skip and nothing cancelled: FRUSLightCoreTests 126 and FRUSLightServerTests 175, the others as at #63. The first full run, before the rule for an empty store, also hit the flake under Notes. On the merges with main, at #68, S17c's pin move to `1c18b51e`, and then at #69, S16e's, the package's own targets built clean again, and all 2,493 tests pass, up from 2,470 at #69, with the one named skip and nothing cancelled: FRUSLightCoreTests 133 and FRUSLightServerTests 184, the others as at #69, FRUSCoreKitTests 1,286 among them.
- **`scripts/compose-smoke`,** on this branch's image built as `frus-light:smoke`, in a Compose project and on a port of its own (18094), both removed afterwards: passes.
  - The first look named 03:00 America/New_York, and took no backup of the new store.
  - After the import through nginx, `frus-light backup` took `app-20261027T232048Z.db` and copied it to the host folder, and a second run took none.
  - `GET /api/v1/admin/backup` gave the archive, which `tar -xf` opened: its backup was the host folder's byte for byte, with its SHA-256 in the manifest.
  - A restore beside the running server was refused.
  - The store was removed and restored, and the export after the start was the export before, byte for byte but for its time.
  - CI's compose job also runs the browser suite (`--e2e`), at the root and under the path, before those steps.

**Records**

- `SPEC.md`: the Backups section (the schedule, the two rules for none, the names, the command, the restore and its lock); the configuration table's `FRUS_BACKUP_HOUR`, `TZ` and `FRUS_BACKUP_COPY_DIR`; the disk layout; the Compose sketch; and a new "An admin's data" section of the HTTP API.
- `INSTALL.md`: a Linux host's `chown` before the first start; Backups and restore, with taking one now, listing, the API, a restore and a restore after a lost volume; going back to an older server, now a restore; fetching the Compose file again on an upgrade; the settings; the error codes.
- `PLAN.md`: S14b done, after S16d's paragraph, and the Compose section's backups line. The README's Status and Next, and this log.

**Notes**

- **Three readings of the row,** as PLAN's done paragraph gives them:
  - a store that holds no research yet is not backed up;
  - "the newest with a manifest of versions" is one tar archive of the backup and its manifest;
  - "the role check the server already has" is S16c's, here for the admin role.

  The first saves a new install from a backup of nothing at its start, which would hold off the first real one, after the import, until 03:00. After a lost volume, it would also have been the newest in the host folder and pushed out a real one.
- **`TZ` without tzdata.** The runtime image has no tzdata package and needs none: the server links Foundation's ICU statically, and ICU's own data knows every zone, as the smoke test's New York shows. Nothing else the server writes depends on the zone, since every date it writes is UTC ISO 8601.
- **A host folder on Linux.** Docker makes a missing bind-mount source as root, and UID 10001 cannot write it. The server then warns at its start, and the backups stay in the volume. `INSTALL.md` has a Linux host `chown` the folder first. Docker Desktop lets any container user write one, and the smoke test makes its own folder writable by all.
- **`RecentComputationsTests`' `aRequestCancelledWhileAnotherWaitsLeavesAtOnceAndTheValueIsKept`** failed in the first full run, while other sessions' builds loaded the Mac, and in 1 of 3 runs alone. Nothing here touches it, and main's CI has passed it. A session of its own found the test's two tasks reaching the cache in either order, and [#72](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/72) fixes the test.
- **The build** reused S16d's `.build/linux` through an APFS clone (`cp -c`), at the same pin, and rebuilt this package's own targets clean; after the merge with main, S17c's at `1c18b51e`.
- **Another session's smoke test** rebuilt the shared `frus-light:smoke` tag during a local `--e2e` run, and its "under a path" step then recreated the container from the other image. Run beside other sessions with an image tag of your own (`FRUS_IMAGE`); CI passes its own.
- **The owner's install** (`frus-light`, port 8080) was not touched.

**Next: the owner's restore drill** (PLAN's owner checkpoints), after the merge, on the owner's install; the pull request's body gives its steps. Beside it on the server's track: S14d and S14e, after S14c. S17d follows S17c's pin move, and S16e and S18b are in flight.

## Session 17c: pin move past FRUS-Explorer#1805, #1806 and #1807, with #1789 to #1804

27 October 2026 · branch `claude/cranky-murdock-f76a42` · [#68](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/68) · upstream `1c18b51e`

Phase 2's row S17c. The pin moves from `503a730b` to `1c18b51e`, `v2`'s head, past the three web-authored pull requests the owner merged today:
- [FRUS-Explorer#1805](https://github.com/joshbotts/FRUS-Explorer/pull/1805) (S17b), the research layer's rules, as `295e5276`;
- [#1806](https://github.com/joshbotts/FRUS-Explorer/pull/1806) (S17a), the search's user half from a store the host attaches, as `391b3461`;
- [#1807](https://github.com/joshbotts/FRUS-Explorer/pull/1807) (S18a), a collection rendered from values, as `1c18b51e`, a squash with its branch head's tree (`cba143d8`).

`PLAN.md` has the first pin move after a phase-2 upstream merge take it, whichever row that is, so this move takes every merge since the pin as well: S15c's follow-up [#1789](https://github.com/joshbotts/FRUS-Explorer/pull/1789) (`96c9de0c`), S15d's [#1790](https://github.com/joshbotts/FRUS-Explorer/pull/1790) (`9fa4375d`), the app's [#1792](https://github.com/joshbotts/FRUS-Explorer/pull/1792) (`2b153f81`), [#1793](https://github.com/joshbotts/FRUS-Explorer/pull/1793) (`b33c05da`) and [#1801](https://github.com/joshbotts/FRUS-Explorer/pull/1801) (`36e7add7`), and six that change only the app's plans, guides, manuals and marketing copy (#1794, #1795, #1800, #1802, #1803, #1804). So S18c, which was to move past S18a's and S18b's pull requests, moves past S18b's alone. It is a pull request of its own under rule 5.

**What the move brought, in shared code**

- **#1789 and #1793, the reader's highlights.** `kHighlightsJS`'s `buildRanges` ends a range that ends on a `<br>` after the element, and builds none from a negative start; `render` skips a highlight whose range throws, alone, where one such highlight left the page with none drawn. `HighlightReanchor.extracts(passage:start:end:in:)` is public. #1793 also removes the app's unloaded copies of the engine and the renderer from `FRUSExplorer/Resources/`, and clamps a colour outside sRGB in `CollectionProse.hex`.
- **#1805:** the research layer's rules, public, over values: `SavedSearchFreshness` and "+N since last run", `WorkingCorpusResolver` and `CustomScopeResolver`, the trail's sessions, the method appendix with `RecordedSearch`, `SearchScopeSignature` and the provenance vocabulary, `DocumentEngagement`, `ResearchDocumentAggregation`, `ResearchItemCounts.tally`, `NotesPaneSnapshot` with All Notes' filter, and `CollectionEntryKind`; and, on Linux only, an interpolated integer grouped as Foundation groups it.
- **#1806:** `SearchUserSource`, and the read-only open's `userStore:`, which attaches a store read-only as `user_store`; every reader of the search's user half takes the source.
- **#1807:** the collection export's payloads, options, presets and naming, the outline's value core, the quotation check, and the HTML, Word, BibTeX and RIS exporters, with `CollectionProse.append` and `hex`, `FRUSRenderNodeHTMLSerializer.serialize(_:includeFootnotes:highlights:)`, `ExportHighlight`, `HighlightColor.ooxmlHighlightName` and `IndexingPipeline.documentBodyTextsByKey(forKeys:)` public.
- **In the kit's tests:** `SearchStatementTextTests`, `SearchUserSourceTests`, `ResearchLayerRulesTests`, `QueryMethodAppendixFixtureTests` and `CollectionRenderingTests` are new, `ExcerptVerifierTests` moved into the kit's folder, and `ReaderAnnotationScriptTests` re-took its pins of the scripts for #1789 and #1793. FRUSCoreKitTests runs 1,286, from 1,191.
- The rest is the app's: #1790's colour under the light appearance, #1792's one copy of each record, #1801's offline launch, ranking chart, word cloud and cross-reference graph, and the app's halves of the three moves.

**No repair to the build.** The package builds with no warning, every kit suite passes, and the only skip is the named one. `Package.swift` compiles `FRUSCoreKit/` by folder, so its new `Collections/`, `Provenance/` and `Research/` needed no change. These are unchanged:
- the build (1.0, 1776), so `scripts/release-tag` still says `1.0-1776`;
- the index version (71) and the FTS generation (4), so `Compatibility.swift` and the install guide's versions stand;
- the export's schema: `setupDatabase(_:)` is the same text, now at lines 8010–8665, and the watch finds the same 47 `CREATE TABLE` and `ALTER TABLE` statements;
- `IndexingResources.indexResourceNames`, the export's format version (7), the app's source folders in `project.yml`, and CI's allow-list.

The bundled resources lose `frus-highlights.js` and `frus-offset-engine.js`, which nothing loaded, and `frus-selection.js` changes in its comments. The server serves the kit's constants as its reader scripts, and its tests compare them with the constants, so its `frus-highlights.js` now has #1789's and #1793's fixes.

**On §5's indexing path,** `git diff 503a730b 1c18b51e` shows nothing that indexing runs:
- `IndexingPipeline.swift` changes in search-time code (#1806's user source in every statement builder, the tag counts and a document's tags), in the read-only open, which attaches a store, in two test hooks, and in one access level (#1807's `documentBodyTextsByKey`, a read only an export runs). The read-write open passes no store, and `setupDatabase(_:)` is the same text;
- the parser's folder, `FRUSCoreKit/TEI`, changes in comments, in access (`serialize`, `ExportHighlight`), in `ooxmlHighlightName`, which moved in from the app unchanged, in the new `FigureImageSource.swift`, which the collection exporters read, and in the reader's scripts;
- `FRUSExplorer/Resources` loses the two unloaded scripts;
- FTS5Store, SourceNoteKit and `project.yml` are unchanged, and #1792 and #1801 change no file on the path.

So the owner's seventh three-volume export, made on 24 October from a build of `503a730b`, holds what the indexer at `1c18b51e` would write: the build (1.0, 1776), the index version (71) and the FTS generation (4) are the same, and on the indexing path only code that a search, an export or the reader runs changed. The golden files were remade from it, on the owner's word.

**Parity tests repaired.** Twelve tests in five suites failed at the new pin on app source the move changed, as S17b's and S18a's entries foresaw:
- **pointed at the kit's moved files, or at the app's files the code left:** `NoteViewParityTests`' words, formats, and All Notes' rows and filters (`FRUSCoreKit/Models/NotesPaneSnapshot.swift`, with the search field's filter, which moved into it from `AllNotesScreen` as `filtered(project:tagId:query:)`, and `ResearchItemCounts.swift`); `ImportParityTests`' inert kind (`CollectionEntryKind`) and saved search, whose `recordRun` writes the kit's `encoded`; and `NotesAndSummariesParityTests`' reading of prose (`Collections/CollectionExporter+App.swift`);
- **re-taken on #1792's one copy of each record:** `ExportParityTests`' exporter lines, `NoteViewParityTests`' Contents counts (`DuplicateCopies.count`), and `NotesAndSummariesParityTests`' note text, the editor's save to every copy and its `deleteEveryCopy`. The store keeps one row for each user and id, and S16c's import keeps the newer of a file's repeated records, so the web has one copy of each by construction and nothing to collapse;
- **`UserStoreParityTests`' two:** a saved search's `freshnessData` is the kit's `SavedSearchFreshness.encoded` now, not an assignment from `JSONEncoder()`, so `AppModelSource.isWrittenAsJSON` also reads a kit type's `encoded` blob as JSON when the kit writes it with a plain `JSONEncoder`.

**Rule 4: where the kit now has the code the server mirrored, the server calls it.**
- **A saved search's watermark.** The export reads `freshness_data` with `SavedSearchFreshness.decoded(from:)`, the import writes it with the kit's `encoded`, and the parity harness reads it back as the kit's type. The three copies of the struct go: `ResearchExport.Freshness`, `SavedSearchColumns.Freshness` and `StoredResearch`'s. The import's NULL for a file that records no run stays the web's, as the app's record of a search never run holds none.
- **A collection entry's kinds.** `MacImport.inertKind` is `CollectionEntryKind.unrecognized.rawValue`, and a new entry's default kind `.document`'s.
- **Check 6's two forms.** `ExportHighlights.check` calls `HighlightReanchor.extracts(passage:start:end:in:)` over the page's blocks, where it composed the private test from the kit's public pieces, as S16c planned.
- **The codec's colour and the golden reading's paragraphs.** `RTFColor.hex` is the kit's `CollectionProse.hex`, #1793's clamp with it, which the codec already applied, and `ProseParagraphs.paragraphs(of:)` splits with the kit's `CollectionProse.append`, as S18a's entry proposed. `FRUSRichText` and `ParityFormat` depend on `FRUSCoreKit` now, imported `internal`, so `tools/mac-golden`, which links both beside the app module and its own compile of the kit's files, sees one `CollectionProse`. Only `hexColor`'s resolution of a colour, AppKit's, is the codec's own, and `theAppsParagraphsAndColoursAreTheMirrors` pins the app's AppKit body, #1790's, and the decoder's call of `append`.

Left as mirrors, with their parity tests:
- **All Notes' rows and filters** (`web/src/research/notesRules.ts`). The browser app filters the notes it holds as each key is typed; serving the kit's `NotesPaneSnapshot` would make each key a request. Its test reads the kit's file now.
- **The app's code that stays the app's:** `SavedSearch.init(name:parameters:)`'s columns, `ResearchNote.indexedTextPerDocument` and `GeneratedSummary.ranksAbove`, the exporter's `makeEnvelope`, and the export sheet's counts.

Not taken yet, each for its row: attaching the store to search, S17d's; saved searches, corpora and scopes, S17e's; the trail and the appendix, S17f's; the Research page's aggregation, S19b's; the collection renderers, S18d's to S18f's; and `ResearchItemCounts.tally`, which S14c's Settings tallies waited for.

**The reader.** The host script's try of each highlight with `buildRanges` before `FRUSHighlights.render` stays, to name in the rail any the kit cannot draw, since the kit's renderer, which skips one alone now, does not say which; its comments say why. Check 6's samples still leave out a highlight that ends on a line break. The kit's renderer draws one since #1789, ending its range after the `<br>`, but check 6 in Chromium also reads each range back through the kit's selection bridge, and `rangeEndpointToOffset` finds an endpoint by the node its map names, the `<br>` itself, not the paragraph that `setEndAfter` gives. A throwaway page in Chromium, never committed, loaded the kit's three scripts over `ab<br>cd`: the range for 0–3 ends at the paragraph's offset 2, the bridge reads that end back as -1, and the renderer draws the highlight. Ranges that end in text read back to their offsets. A reader's drag ends in the text after the break, which the bridge maps, as #1789's tests found in WebKit, so only check 6's read-back meets the gap.

**#1801** changes nothing the web serves. Its timeline is the cross-reference graph's (`CrossReferenceStore`, app code); S11f's is the search window's, through the kit's facets, and `ReadingsAPIParityTests` passes unchanged. The web has no word cloud.

**The golden files**

Remade by `scripts/make-golden`, under the app's `Scripts/heavy.sh` lock, on this Mac, which runs macOS 27.2 now, first from the app's source alone, and then, by the owner's choice, with `--export /Users/Shared/frus-index-2026-10-24.sqlite`, the seventh three-volume export, which S16b's move was made from. No new export was made, and neither library was touched.
- **The render and the expressions:** the 393 rows' HTML is byte for byte as before, and the manifest and the expressions change only in provenance: `sourceDigest` (`1c529af84686` to `60d61d5d2ef1`), `upstreamCommit`, and the platform's macOS, 27.2.0 where it was 27.0.1.
- **The results** change only in that provenance. Every query's count, first 50 results and tie tail are as before.
- **The index summary's** gating section, its 36 digests, 7 checks and volumes, is unchanged. Beside the same provenance, its information section moves only in the summarizer's timings.
- **The golden spans** change in provenance, in the harness's digest of `tools/mac-golden`'s `RichText.swift`, which this pull request edits, and in the RTF of the 90 written cases, which differ only in AppKit's writer stamp: `\cocoartf2908` on macOS 27.2, where 27.0.1 wrote `\cocoartf2907`. Every case's text, runs and paragraphs, the 51 catalog colours and the 16 code pages' readings are as before, and `fixtures/rich-text/web`, the codec's own RTF, is unchanged.
- `frus-parity check-golden` passes, and `PENDING` is empty again. Until the export was chosen, the two files made from it waited there, and the pull request was a draft whose checks 2 and 3 printed that they waited.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** CI's Build and Test steps replayed over `main` at `8e6d681`, this package's own targets built clean with no warning, all under the app's `Scripts/heavy.sh` lock:
  - **at the new pin before the repairs:** every kit suite passed, and two targets failed with 42 issues: in FRUSParityTests, 21 of golden-file staleness and 19 in ten of the twelve tests named above, and in FRUSLightCoreTests the other two;
  - **with the repairs, the source-made golden files remade and the two export-made ones pending:** every test passed but one, a check this session had added that compared the watermark's bytes, which the kit's encoder writes in no fixed order. It compares what they decode to, from before the draft was pushed. Seven tests printed that a file waits;
  - **with every golden file:** 2,454 tests, up from 2,359, all passing with only the named skip, in Swift Testing's results file and in the log. The checks print:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups; 318 with other score bits (information)", and through the API "482 queries, 482 identical and 0 reordered only within Mac tie groups, every record the kit's own";
    - "check 4 through the page: 393 of 393 rows identical", and the same on the reader's path and from one full parse per volume;
  - **per target:** FRUSCoreKitTests 1,286, SourceNoteKitTests 321, FTS5StoreTests 219, FRUSParityTests 188, FRUSLightServerTests 172, FRUSLightCoreTests 106, ManifestGeneratorTests 60, FRUSRichTextTests 42, SemanticVectorsKitTests 40, CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
- **The web job:** typecheck, lint, and 304 unit tests in 33 files, unchanged but for a comment in `notesRules.ts`.
- **`tools/mac-golden`** built in release with the codec and the formats importing the kit, and wrote the files above.
- **The image and the browser suite** are CI's compose job's. The server's reader serves the kit's scripts as they now are.

**The daily watch.** [Issue #56](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/56) reported `v2` at `41950692`, 11 commits past the pin, with every kit passing and this package's suites failing as listed. Its comment names this pull request for the 14 commits to `1c18b51e`. Its first run after the merge finds nothing past the pin and closes it.

**Records**

- `PLAN.md`: S17c's done paragraph after S16d's, S12d's row (from `1c18b51e`), S18c's row, the golden-files checkpoint and the risk row's merges.
- `SPEC.md`: the compatibility contract, and `setupDatabase(_:)`'s lines.
- `COORDINATION.md`: the pin; §1's use of the kit, the mirrors and the counts; §2's #1807, now merged, and this move after it; §5's list of app changes; §6's exports.
- `docs/prep/README.md`: the pin. The README's Status and this log.

**Notes**

- **`internal import` keeps the kit out of a client's sight.** `tools/mac-golden` compiles the kit's files into its app module and links `FRUSRichText` and `ParityFormat`, which now import the kit's module. Imported `internal`, the second module adds no name and no extension member the tool can see, so nothing it names is ambiguous.
- **`make-golden` leaves `tools/mac-golden/Package.resolved` changed.** Xcode 27.1's SwiftPM resolves every dependency of the path package `mac-golden` names, so the lockfile gains this package's 22 server dependencies, at newer versions than the root's lockfile. Resolving the tool against `main`'s manifest does the same, so it is the toolchain's and not this move's. The two pins the tool builds, swift-crypto 5.0.0 and swift-asn1 1.7.3, stay as they are, and the change is left out.
- **S14c's tallies are unblocked.** "12 notes · 3 documents" beside each Settings ▸ Tags row is `ResearchItemCounts.tally` over each note's tags and each assignment's tag, with the kit's `TagTally.summary` for its words. It is small, and in no row's way.
- **Mac checks 11, 12 and 13** are still "To do" in `PLAN.md`, as 9 and 10 are. The owner merged #1805, #1806 and #1807; their checks are the owner's to record.

**Next: S17d,** search over the researcher's writing, which attaches the store at the read-only open and gives each request's user a service with `.attachedStore(userId:)`; beside it **S17e**, saved searches, corpora and scopes, and **S17f**, projects, the history and the method appendix, with S16e and the server's track, S14e, S14d and S14b.

## Session 18a: collections render from values in FRUSCoreKit, upstream

25–27 October 2026 · branch `claude/wonderful-dewdney-bda10e` · [#67](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/67) · upstream `503a730b`, unchanged; [FRUS-Explorer#1807](https://github.com/joshbotts/FRUS-Explorer/pull/1807), open

This is phase 2's row S18a, the first of the six collection rows, and Mac check 13 verifies it. S18d to S18f bring collections to the web (their editor, their preview and their exports), with each export byte for byte the app's. For that, the kit has to render a collection from values, which this row does, and resolve one through a data source, which is S18b's.

This session opened one pull request on `FRUS-Explorer`, from `claude/collections-render-from-values`. It is labelled `Mac`, its body says "Mac verification requested", and it is not merged. Under rule 4 the pull request changes shared files, and this repository changes only its records.

It was begun on `v2` at `9fa4375d` on 25 October, and stopped before it opened when the usage limit stopped every session. On 27 October it was rebased twice:
- **onto `41950692`, past #1792, #1793 and #1801.** #1793 clamps `CollectionProse.hex(r:g:b:)`, which this branch moves into the kit, so the clamp moved with it, and #1793's new sRGB test builds its prose item from spans;
- **onto `391b3461`, when S17b's #1805 and S17a's #1806 merged during the runs.**
  - #1805 moved the provenance vocabulary byte for byte as this branch did, so the branch's commit for it fell away.
  - The `Models/Collection.swift` blocks were re-pointed again, the copy scan's baseline combined, and the records combined.
  - The branch's version line in `IndexingPipeline.swift` is 4.48, after #1806's 4.47.

Every run was taken again at each head, and every figure below is at the last.

**#1807, in six commits of moves, a commit of tests and a records commit:**
- **The export's payloads, options, presets and naming,** made public in `FRUSCoreKit/Collections/CollectionExporter.swift`, with `CollectionEditorNaming` and `CollectionGeneratedBlockType`.
  - What reads SwiftData, Apple Intelligence, the app's rendering of the method appendix, or AppKit and UIKit stays in the app's new `CollectionExporter+App.swift`, together with `ExportFormat` and the RTF decoder.
  - Two shapes change, but neither changes what an export prints:
    - a prose item carries the spans every format renders (`[[ProseFormattedSpan]]`). The content resolver decodes them from the RTF, the call each exporter used to make, and the span rules `CollectionProse.append` and `hex` are public;
    - `CollectionExportMetadata.exportDate`, a `CollectionExportDate` of moment, locale and time zone, dates the Word cover and the colophon. The app passes `nil`, which keeps the export dated now in the device's calendar, as before.
- **The outline's value core,** every rule over `StructuralRef`, three levels deep. The rules over `CollectionEntry` stay in the app.
- **The quotation check,** `ExcerptVerifier` and its report, with `IndexingPipeline.documentBodyTextsByKey(forKeys:)` and `WordCloudDocumentKey` made public.
- **The HTML renderer and exporter.**
  - The stylesheet is `ReaderPage`'s.
  - Figures come from a `FigureImageSource` the host passes in, and the word cloud as a PNG from a drawing it passes in.
  - `serialize(_:includeFootnotes:highlights:)` is public.
- **The Word exporter, with its ZIP writer.** Its figures and its word cloud come in as the HTML exporter's do, and `documentData(metadata:items:options:wordCloud:)` returns the bytes.
- **The BibTeX and RIS collection exporters,** with `bibTeX(for:options:)` and `ris(for:options:)` returning the text.
- **Tests:**
  - **`CollectionRenderingTests`** is new in the kit's suites.
    - It pins, by SHA-256 and length, each output of two collections and the live preview's page: the HTML, the Word package, the BibTeX and the RIS.
    - The date is fixed, in a fixed locale and time zone, so the pins hold on any platform.
    - It also covers the outline's core and the span rules.
  - **`ExcerptVerifierTests`** moves into the kit's suites.
  - **The counts:** `FRUSCoreKitTests` goes from 1,251 tests to 1,286, and the iOS unit target from 7,725 to 7,739.

**How it was checked.** Each heavy job ran under the app's lock, from a clone at a real path, beside `v2` at `391b3461` built and run the same way: Xcode 27.1 on macOS 27.2, clean and unsigned, on an iPhone 18 Pro simulator (iOS 27.0), which S17a's and S17b's sessions, sharing the lock, did not use.
- **The full iOS unit run:** 7,739 tests in 927 suites, against `v2`'s 7,725 in 924.
  - Both fail the 8 Keychain tests an unsigned build fails, and show the 6 known issues of `v2`'s system-log test.
  - Both skip the same 17 tests and 2 suites.
- **`swift test`:** 3,179 tests against 3,144, all passed; `FRUSCoreKitTests` 1,286 against 1,251.
- **The symbol diff,** normalized as before: 251,332 names on `v2` and 251,475 on the branch, 103 removed and 246 added, the same names as at `41950692`.
  - 32 of the removed were private, and reappear without the file-private discriminator.
  - 60 reappear under a new signature: the prose renderers now take spans, the exporters' figure source and initialiser changed, and so did the colophon's date.
  - The other 11 are default-argument generators, and an implicit `init()`, that the now-public declarations no longer need.
  - The other 152 added are the new API (`CollectionExportDate`, `CollectionWordCloud`, `FigureImageSource`, `NoFigureImages`, `FigureImagePNG`) and the names the compiler makes for it.
- **Both builds** had `v2`'s five and seven warning lines, and `swift build --target FRUSCoreKit` completed.
- **Each export, byte for byte.** A scratch suite was appended to `CollectionTests.swift` for one run and never committed. At `v2` and at the branch, the same day, it exported four test collections through `ExportFormat.makeExporter()`, as the export sheet does: in HTML, Word, BibTeX, RIS, and PDF (as text). One collection was resolved by the app's resolver from SwiftData entries.
  - All 22 files were the same, byte for byte, at both heads, and the same bytes as at `41950692`.
  - Against `v2`'s run of 25 October, the only differences were the dates a colophon and the Word cover print, so the two runs of a comparison have to be on one day.
- **`RichTextRestingCapTests`' link-alert test** fails now and then on both heads, as #1785's runs found.
  - It failed in the branch's full run of 25 October, and passed in every full run on the 27th.
  - Run alone, alternating the two heads, it failed 1 of 15 runs at `v2` and 2 of 15 at the branch, at `391b3461`, and 0 of 7 and 1 of 7 at `41950692`.
  - Every failure was the same wait for the alert to go (`host.dismissPresented()`), and nothing here touches the editor.
- **Linux,** in a scratch worktree of this repository's `main` at `37a4e35`, with `v2` and then the branch copied over the submodule:
  - **the kit:** `FRUSCoreKitTests` ran 1,286 tests, with the one named skip, so the pins hold there;
  - **the rest:** every other target passed but the parity suites, whose issues are `v2`'s but for one test:
    - 41 are the same on both: golden-file staleness (14), golden-span staleness (7), and 20 pins this repository keeps on app source that `v2` has moved since the pin, in #1792, #1805 and #1806;
    - the one that differs is `NotesAndSummariesParityTests`' `theAppsParagraphsAndColoursAreTheMirrors`. At `v2` it finds #1790's and #1793's new colour bodies, and at the branch the file it reads has moved;
  - **public access:** a scratch file in `FRUSLightAPI`, never committed, imported FRUSCoreKit without `@testable` and used every name the pull request makes public, and the target built.
- **The records:** `CodingStandardsAuditTests` and `EditableContentKeyTests`, which read `Planning/` and `Docs/`, passed again at the records head.
- **A review** read the diff cold, before the rebases. It found these, all fixed before the runs quoted:
  - the project file was missing the moved test file and the new suite;
  - one test file moved a commit early;
  - several doc lines and commit messages were wrong.

**For S18c, the pin move past S18a and S18b:**
- **`NotesAndSummariesParityTests`** fails by design at that move. Its `theAppsParagraphsAndColoursAreTheMirrors` reads `Collections/CollectionExporter.swift` for `private static func append`, `hex` and `hexColor`. After #1807:
  - `append` and `hex` are `public static func` in `FRUSCoreKit/Collections/CollectionExporter.swift`. `append`'s body is unchanged, its continuation lines moved one column, and `hex` has #1793's clamp.
  - Both `hexColor`s are in `FRUSExplorer/Collections/CollectionExporter+App.swift`, as #1790 left them.

  Rather than re-point the test, the codec (`Sources/FRUSRichText`) and `Tests/ParityFormat/RichText.swift` can call the kit's `append` and `hex` and drop those mirrors, which also takes #1793's clamp. Only `hexColor`'s colour resolution, which is AppKit's and UIKit's, stays a mirror.
- **`tools/mac-golden`'s `RichText.swift`** calls `CollectionProse.paragraphs(fromRTF:)`, unchanged in the app, and uses `ProseFormattedSpan`, now the kit's, so it compiles as it is.
  - Its comments name `paragraphs(fromDecoded:)` and `hexColor(_:)`, which are now in `CollectionExporter+App.swift`.
  - `make-golden` remakes the golden spans then, as at any pin move, and they should change only in provenance.
- **The host builds a prose item's spans** with the codec.
- **The host dates an export** with `CollectionExportDate(date:locale:timeZone:)`, so the Word cover and the colophon print the app's `en_US` long date. Without one, a Linux container prints `en_001`'s "27 October 2026" where the app prints "October 27, 2026".
- **Figures and the word cloud are passed in.** Figures come from a `FigureImageSource` over the web's own figure store, or from `NoFigureImages()`. The word cloud is PNG data, or none, since the web has no renderer for it.
- **No temporary files are needed.** `CollectionItemHTMLRenderer.pageHTML(...)`, `DocxCollectionExporter.documentData(...)`, `bibTeX(for:options:)` and `ris(for:options:)` return bytes and text.
- **The quotation check** is `ExcerptVerifier.verify(_:bodyTexts:)` over `documentBodyTextsByKey(forKeys:)`, then `upgradingVanished` with each document's revision, then `ExcerptVerificationReport.summary`.
- **On §5's indexing path,** #1807 changes `IndexingPipeline.swift` only in making `documentBodyTextsByKey` public. It is a read that only an export runs, so the golden files' export may be reused, by the owner's choice.
- **`Package.swift` needs no change.**
- **The notes export keeps its own ZIP writer.** `PLAN.md`'s S18c row says S15d's notes export may take the kit's ZIP writer. But that writer is private to `DocxCollectionExporter`, writes no file times and has no ZIP64 guard, and the web's `StoredZIP` has both.

**Delivered here**

- `COORDINATION.md`: #1790 merged and #1807 open in §2, and #1807 in §5's list of app changes only the web edition needs.
- This log.

**Notes**

- **Three sessions shared the app's lock on 25 October.** S17a's, S17b's and this one's Mac checks queued behind each other, and one simulator per session kept their installs apart. On 27 October, with S17a and S17b merged, the same runs took a fraction of the time.
- **In `swift:6.4-noble` with `LANG` unset,** `Locale.current` is `en_001`. Any date the kit formats with the current locale reads day first there.
- **An export comparison is a same-day comparison.** A colophon and the Word cover print the day of the export, so two runs a day apart differ in those lines and nowhere else.
- **Scratch:** under `~/Library/Caches/frus-s18a`: the clone with the earlier heads kept as `s18a-before-rebase` and `s18a-rebase1`, its `v2` worktree, the logs, the scripts, the dumps, and a scratch worktree of this repository (`web-linux`).

**Next: S18b,** once the owner has run Mac check 13 on #1807 and merged it, branched from `v2` after the merge. S17c's pin move, which S17a's entry names next, can go before it. If S17c moves to a `v2` without #1807, S18c takes S18a and S18b together. Beside them: S17d, S16e and the server's track.

## Session 17a: the user half of the kit's search from an attached store, upstream

25–27 October 2026 · branch `claude/vigorous-boyd-f2fce4` · [#66](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/66) · upstream `503a730b`, unchanged; [FRUS-Explorer#1806](https://github.com/joshbotts/FRUS-Explorer/pull/1806) merged as `391b3461`

Phase 2's row S17a, whose pull request Mac check 11 verifies. This server keeps each researcher's notes, summaries and tags in its own store, never in the index it serves: `user_search`, the FTS5 table S14a made and S15d's writes keep, and S14c's `tag_assignments`. S17d searches them through the kit, whose search read its user half from the index alone.

This session opened one pull request on `FRUS-Explorer`, from `claude/search-attached-user-store`, labelled `Mac` with "Mac verification requested", and not merged. It was begun on `v2` at `9fa4375d` on 25 October and stopped when the usage limit stopped every session. On 27 October it was rebased onto `41950692`, past #1792, #1793 and #1801, and the rebase was clean. Every figure below is at the rebased head. Under rule 4 it changes shared files, and this repository changes only its records.

When S17b's [#1805](https://github.com/joshbotts/FRUS-Explorer/pull/1805) merged as `295e5276`, `v2` was merged into the branch as `334e0afc`, with no rebase:
- the conflicts were records alone, and both sessions' were kept in `CLAUDE.md`'s FRUSCoreKit entry and at the end of the development plan;
- the project file was generated again;
- at the merged tree, SwiftPM ran the branch's two suites and S17b's, and passed;
- the pin, re-derived on `v2` at `295e5276` with the hook alone copied in, was the same.

The owner merged #1806 the same day as `391b3461`, a squash with the branch head's tree, before the full checks could run again at the merge; they had run at `67b90398` on `41950692`, as below.

**#1806, in one commit and a records commit:**
- **`SearchUserSource`** says where a search reads its user half:
  - `.index`, the index's own `user_content` and `document_cache` columns: the app's, and the default everywhere;
  - `.attachedStore(userId:)`, one user's rows of a store attached to the index's connection, each joined to the index's row on `(volume_id, document_id)`.

  `SearchSQLFilters.userSource` carries it into every statement builder, and `SearchService.userSource`, an initialiser parameter, into the filters the service builds.
- **The read-only open attaches the store:** `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:userStore:)`.
  - It attaches it as `user_store`, with `mode=ro` and never `immutable`, since this server writes to the store while the index is served; each statement reads the store as last committed.
  - The tables it reads are this server's, by name: `user_search` and `tag_assignments`.
- **Every reader of the user half takes the source:**
  - **the match:** the user's rows of `user_search`, joined to their `document_cache` rows for the rowid, which drops a document the index does not hold. When that half runs alone, it is grouped by rowid and materialized first: SQLite would otherwise flatten it into the grouping, where FTS5 refuses `bm25`;
  - **the tag filter and the exact-word filter's note and summary columns:** the row's key in the set that the user's assignments, or the user's rows holding the word, make. Each set is a subquery SQLite runs once a statement;
  - **a row's tags,** in the search's three shapes and the Meaning rows: the user's assignments of the document, each tag once, its id in uppercase, sorted, as the app's reconcile writes `user_tag_ids`;
  - **the tag counts,** driven from the user's assignments, **a tag's documents and a document's tags.**

  A tag id matches whatever the case of its letters, as the column's `LIKE` does.
- **`SearchService.userTagCounts(parameters:tagIds:documentKeys:)`**, public: the filter sheet's two routes to its tag counts, as the app's view model composes them, for S17d.
- **The app's statements are pinned.** `SearchStatementTextTests` runs every route to a statement on the user half through the app's own calls, for 22 searches over each scope and filter. It records each of the 365 statements as SQLite expanded it, text and binds, and pins them by SHA-256. The pin was taken by running the same file against `v2` with the trace hook alone copied in, at `9fa4375d` and again at `41950692`. So with no source, each statement is the text and binds it was.
- **`SearchUserSourceTests`, 7 tests,** over two readers' notes, summaries and tags in a store attached to a read-only index. The first reader's are also in the index's own columns of a second copy, as the app's writers keep them.
  - Through the store, every route gives the app's answers for the same text and tags, scores aside.
  - Each reader finds only their own.
  - A missing store fails the open.
  - The store, read-only, shows the next search what its host wrote since.
- **Counts:** `FRUSCoreKitTests` goes from 1,197 tests to 1,205, and the iOS unit target from 7,673 to 7,681.

**How it was checked.** Each heavy job ran under the app's lock, from a clone at a real path, beside `v2` at `41950692` built and run the same way: Xcode 27.1 on macOS 27.2, clean and unsigned, on an iPhone 17e simulator (iOS 27.0), which S17b's and S18a's sessions, sharing the lock, did not use.
- **The full iOS unit run:** 7,681 tests in 914 suites, against `v2`'s 7,673 in 912.
  - Both fail the 8 Keychain tests an unsigned build fails, and show the 6 known issues `v2`'s system-log test declares.
  - Both skip the same 17 tests and 2 suites.
  - A collection editor test failed once on the branch under load, its settings screen slow to open. Its suite then passed alone twice on the same build.
- **`swift test`:** 3,098 tests, against 3,090, all passed.
- **The symbol diff,** normalized as before: 250,315 names on `v2` and 250,461 on the branch, 36 removed and 182 added. Each removed name comes back under the signature that takes the source or the store.
- **Both builds** had `v2`'s five and seven warning lines, and `swift build --target FRUSCoreKit` completed.
- **Mutations,** each alone in a throwaway worktree:
  - a text-only change to the app's row-tag column fails the pin alone;
  - dropping the user's own rows from the match, the materialization, or the case-blind tag match each fails the store's suite and leaves the pin passing.
- **Linux,** in a scratch worktree of this repository's `main` at `4028b22`, with `v2` and then the branch copied over the submodule:
  - **the default source:** check 3's 482 queries gave the golden results, 482 identical, none reordered or different. 318 had other score bits, as S16b's pin move recorded them;
  - **an attached store:** a scratch suite, never committed and importing FRUSCoreKit without `@testable`, wrote a fixture user's note, a summary and two tags through this server's own `SQLiteUserStore`. It opened the fixture index read-only with that `app.db` attached, and found them through the kit: the note and summary in each scope, the exact word, the tag filter, a row's tags, the tag counts on both routes, and a note written after the open;
  - **the kit:** `FRUSCoreKitTests` ran 1,205 tests, with the one named skip, so the pin holds on SQLite 3.45.1;
  - **the rest:** every other target passed but FRUSParityTests. Its 32 issues are `v2`'s, the same list on both: golden-file staleness, and the pins this repository keeps on app source that `v2` has moved since the pin (the colour rules in #1790 and #1793; the notes' search text, the editor's save and the export in #1792).
- **A review** read the diff cold. It found no SQL bug, and checked the bind order and the app's text. It found a filter-only case that proved nothing, a plan assertion that either scan satisfied, the trace hook's order of release, and four doc claims. All were fixed before the runs quoted.

**What the pin move past it brings** (S17c, which takes S17b's pull request and, by PLAN's rule, #1789, #1790, #1792 and #1793):
- **The served index:** `ServedIndex` opens the pipeline with `userStore:` the store's file, and builds a `SearchService` with `.attachedStore(userId:)` for each request's user. The index's service, with `.index`, serves the rest as before.
- **Check 3** is unchanged through the default source.
- **Golden files:** on §5's indexing path, `IndexingPipeline.swift` changes only in code a search runs and in the read-only open. So the golden files may come from the export already in use, by the owner's choice, as at S13c's move.
- **#1792's rules:** the parity tests above re-take their pins on the moved source. #1792 collapses the copies of a record stored under one id. This server's store keys each record by its user and id, and S16c's import writes a repeated record once, so the store holds no such copies to collapse.

**Delivered here**

- `COORDINATION.md`: the pull request in §2, and in §5's list of app changes only the web edition needs.
- This log.

**Notes**

- **SQLite flattens a lone FTS5 half into its grouping.** `SELECT docrowid, MIN(score) FROM (SELECT …, bm25(…) …) GROUP BY docrowid` fails with "unable to use function bm25 in the requested context". The `UNION ALL` of two halves is never flattened so, which is why the app's own grouping works. `AS MATERIALIZED` keeps the user half's `bm25` where its table is matched.
- **A statement trace pins SQL by what runs, not by a copy.**
  - `sqlite3_trace_v2` with `SQLITE_TRACE_STMT`, recording `sqlite3_expanded_sql` for the statements the pipeline itself prepared, gives the text and binds of every statement a route runs.
  - The same test, run on the earlier tree with the hook copied in, gives the reference, so nothing is transcribed.
  - FTS5's own statements inside them are left out, since their text is SQLite's and can move between versions.
  - A search's snippet pass asks the vocabulary in a `Set`'s order, which differs between processes. So the pin calls the search's statement as `search(parameters:limit:offset:)` does, and leaves the snippets out.
- **Per-user BM25,** SPEC's risk, holds as written. The user half's scores are BM25 over every user's rows of `user_search`, so the same documents match, and a note's score is not the Mac's. Corpus-only searches are unchanged, scores bit for bit.
- **The exact-word set reads every row of `user_search`,** since an FTS5 table indexes none of its unindexed columns, `user_id` among them. The word is tested in the user's rows alone. It was not measured at a shared instance's size.
- **Not in the row:** `documentSnippets(forKeys:)` and `documentsInDateRange` still read `summary_text` from the index, for Related Documents, Project Home and the Chronology. None of them is in phase 2.
- **Scratch:** under `~/Library/Caches/frus-s17a`: the clone, its `v2` worktree, the logs and scripts, a scratch worktree of this repository (`web-linux`) and the mutations' worktree.

**Next: S17c,** the pin move past #1805 and #1806, both merged on 27 October, to `v2`'s head; by PLAN's rule it takes #1789, #1790, #1792 and #1793 too. Then **S17d**, search over the researcher's writing, which attaches the store and passes each user's source. Beside them, S16e and the server's track.

## Session 17b: the research layer's rules, upstream

25–27 October 2026 · branch `claude/practical-brahmagupta-626e2f` · upstream `503a730b`, unchanged; [FRUS-Explorer#1805](https://github.com/joshbotts/FRUS-Explorer/pull/1805), open

Phase 2's row S17b, whose pull request Mac check 12 verifies. Phase 2 shows the research layer as the app does: a saved search's "+N since last run", working corpora and volume scopes as a search's filters, the trail's sessions, the method appendix, and the Research page's lists and counts. Each was a rule the app computes over its SwiftData rows, in app files the server cannot compile.

This session opened one pull request on `FRUS-Explorer`, from `claude/research-layer-rules-kit`, labelled `Mac` with "Mac verification requested", and did not merge it. The branch was cut from `v2` at `9fa4375d`. When the sessions resumed on 27 October it was rebased onto `41950692`, past #1792 and #1793, on the owner's word. Under rule 4 it changes shared files, and this repository changes only its records.

**#1805 moves the research layer's rules into FRUSCoreKit, public, each over values a host's rows map to** (`claude/research-layer-rules-kit`, `6941f3fb`). The app maps its rows to those values and calls the rules, and it keeps every name it used, as a typealias, a forwarder or an extension.
- **A saved search's freshness:** `SavedSearchFreshness`, moved unchanged, with the evaluation of "+N since last run": no badge, new results, or a backfill for the host to store. It also carries the mark a run writes and its blob. The count and the store stay the host's.
- **Corpora and scopes as filters:**
  - `WorkingCorpusResolver.resolve(documentKeys:)`, `DocumentScopeGate` and `runningInside(workingCorpus:)`;
  - a capture's truncation and its line, and a Meaning capture's provenance sentence;
  - `CustomScopeResolver` and `IndexedResolution`.
- **The trail's sessions:** the 30-minute grouping, the newest window's merge and the session log's page. The loaders stay in the app.
- **The method appendix:**
  - It is made from `RecordedSearch` values, one per trail row, whose `RecordedCount` was `SearchHistoryEntry.RecordedCount`.
  - It is rendered for a `QueryMethodAppendix.Host`, which passes in the version for the Generated line, the data files that name a subject, and the locale, calendar and time zone.
  - It moves with `SearchScopeSignature`, `ProvenanceSource`, `ProvenanceStatement` and a corpus's coverage (`DocumentEngagement`, `EngagementCoverage`).
- **The Research page:** `ResearchDocumentAggregation` over values, `ResearchItemCounts.tally`, `NotesPaneSnapshot` with All Notes' filter, and `CollectionEntryKind`. Which documents a tag, a collection or a colour lists stays view code in `ResearchView`, with a hang fix the app's tests pin, and the pull request files it.
- **On Linux only,** the kit's `String(localized:)` stand-in writes an interpolated integer grouped for the locale, as Foundation does. It wrote "1200 documents" where the app writes "1,200 documents".
- **Tests:**
  - `QueryMethodAppendixFixtureTests` holds a fixture trail's appendix to the byte, with the same literals on iOS, macOS and Linux, which is the row's done-when. The Markdown is 3,381 bytes (SHA-256 `ecc9ebf0…`), and the CSV with `count_basis` is 3,945 bytes (`28273936…`).
  - `ResearchLayerRulesTests`, 38 tests in 9 suites, checks each rule over values.
  - `FRUSCoreKitTests` goes from 1,197 tests to 1,243, and the iOS unit target from 7,673 to 7,717.

**The rebase.** `v2` moved nine commits while the usage limit stopped every session. #1792 reads one copy of each note, saved search and trail row stored more than once under one id, and two of the fetches it changed are in files this pull request moves. Each fetch stays in the app, in `ResearchItemCounts+App.swift` and `NotesPaneSnapshot+App.swift`, with #1792's read, and `DuplicateCopiesTests` passes. Everything below was run at the new head.

**How it was checked.** Each heavy job ran under the app's lock, from a clone at a real path, beside `v2` at `41950692` built and run the same way, with Xcode 27.1, clean and unsigned.
- **`v2`:**
  - the full iOS unit run had 7,673 tests in 912 suites, and failed only the 8 Keychain tests an unsigned build fails, with #1606's 6 known issues and 17 tests and 2 suites skipped;
  - `swift test` ran 3,090 tests in 369 suites, `FRUSCoreKitTests` 1,197;
  - with thunk numbers and file-private discriminators dropped, its Mac library had 250,315 symbol names;
  - the Mac build had 5 warning lines and the iOS build 7.
- **The branch:**
  - the full iOS unit run had 7,717 tests in 922 suites, with the same 8 issues, the same 6 known issues and the same 17 tests and 2 suites skipped;
  - `swift test` ran 3,136 tests in 379 suites, `FRUSCoreKitTests` 1,243;
  - with thunk numbers and file-private discriminators dropped, the symbol diff was 172 names removed and 1,043 added, the same as before the rebase. 106 of the removed reappear under the moved types' new names, and the other 66 are closures, private helpers that now take the host or a locale, the moved nested types' mangled names, two `CodingKeys` witnesses, and the initialisers the public ones replace;
  - both builds had `v2`'s warning lines, and `swift build --target FRUSCoreKit` completed.
- **Linux,** in a scratch worktree of this repository's `main` at `4028b22`, with the branch and then `v2` copied over the submodule:
  - `FRUSCoreKitTests` ran 1,243 tests and 1,197, with the one named skip and no build warning;
  - seven parity tests failed on the branch only, and one more had four more issues, each reading app source the pull request moves (below);
  - everything else failed or passed as at `v2`;
  - a scratch file in `FRUSLightAPI`, never committed, used every newly public name without `@testable`, and its target built.

**Delivered here**

- `COORDINATION.md`: the pull request in §2, and in §5's list of app changes only the web edition needs; #1789's merge, in both.
- This log.

**Notes**

- **The appendix is the same file on every platform because the host passes the formatting in.** The appendix read the current locale and time zone, and Linux's stand-in for `String(localized:)` wrote integers bare. With the formatting passed in and the stand-in grouping as Foundation does, one set of literals holds on iOS, macOS and Linux. The app passes `.autoupdatingCurrent`, which is what its formatters defaulted to, so its file is unchanged.
- **For S17c,** the pin move past S17a's and S17b's pull requests:
  - **Seven parity tests read app source this moves,** and fail at the new pin until they are pointed at the kit:
    - `ImportParityTests.aSavedSearchsColumnsAreWhatTheAppWritesFromItsParameters` looks for `SavedSearchFreshness` in `Models/SavedSearch.swift`. It is public in `FRUSCoreKit/Search/SavedSearchFreshness.swift` now, and a run's blob is `SavedSearchFreshness.run(at:matchCount:indexedVolumeCount:).encoded`.
    - `ImportParityTests.anInertEntryReadsAsTheAppsUnrecognizedKind` looks for `CollectionEntryKind`'s cases in `Models/Collection.swift`. They are in `FRUSCoreKit/Models/CollectionEntryKind.swift` now.
    - `NoteViewParityTests`' `allNotesRowsAndFiltersAreTheApps`, `theAppsFormatsAreTheWebs` and `theAppsWordsAreTheWebs` read `Models/NotesPaneSnapshot.swift`. It is `FRUSCoreKit/Models/NotesPaneSnapshot.swift` now, and All Notes' search-field filter moved into it from `AllNotesScreen`, as `filtered(project:tagId:query:)`.
    - `UserStoreParityTests`' `eachColumnHoldsItsPropertysType` and `dataTheAppWritesAsJSONIsTheDataKeptAsJSON` find the `Data` columns the app writes as JSON by the encoder call in each model's file. `SavedSearch.freshnessData`'s is the kit's `SavedSearchFreshness.encoded` now, so both read it as a blob.
    - `ExportParityTests.theExportMirrorsTheAppsExporterAtThePin` gains four issues, from the same freshness lines.
  - **`web/src/research/notesRules.ts` mirrors All Notes' rows and filters,** which `NoteViewParityTests` holds to the app's source. Once the kit has them, the server can serve the kit's `NotesPaneSnapshot.build` and `filtered`, and the mirror and its parity test can go, or the test can be pointed at the kit's file.
  - **S14c's tally waits for this move:** the "12 notes · 3 documents" beside each Settings row is `ResearchItemCounts.tally`, over each note's projects and tags, each collection's projects and each assignment's tag.
  - **The kit's rules take the projects in the order given.** The app's fetch sorts them by name, so `UserProjects.swift`'s sort stays the web's.
  - **The History pane is unchanged by #1792:** the app lists each stored copy of a trail row there, and its totals count stored rows, which #1792 leaves to the owner. The web's store keeps one row per id.
  - **On Linux, an interpolated integer is now grouped** wherever the kit writes one through `String(localized:)`, as the Mac's are, Citation Lookup's labels for a page of 1,000 or more among them. No test here expects a bare one of a thousand or more.
  - **#1793 changes `kHighlightsJS`:** `render` skips a highlight whose range throws, where one such highlight left none of the document's drawn, and `buildRanges` builds no range from a negative start. `ReaderAnnotationScriptTests`' pins change with it, and the reader frame's own try of each highlight may go. It also removes the app's unloaded copies of the two scripts from `FRUSExplorer/Resources/`, which the watch lists as removed resources.
  - **The pull request changes nothing on §5's indexing path,** so the golden files' remake is decided by what else the pin move brings.
- **Scratch:** the clone, the `v2` worktree, the logs, the scripts and the scratch worktree of this repository (`web-linux`) are under `~/Library/Caches/frus-s17b`.

**Next: S17c, the pin move past S17a's and S17b's pull requests,** once the owner has run Mac checks 11 and 12 and merged both, as a pull request of its own under rule 5. S18a's pull request, made beside this one, carries the same two provenance files byte for byte, so whichever of the two merges second has no conflict in them. Beside it: S16e, and S14e, S14d and S14b on the server's track, as S16d's entry says.

## Session 16d: the export

25 October 2026 · branch `claude/s16d-export` · [#64](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/64) · upstream `503a730b`, unchanged

Phase 2's row S16d. The user's research leaves the server as the Mac's own Export as JSON writes it, the kit's envelope at format version 7, through `GET /api/v1/me/export`, with one key of the web's own beside it, and Settings ▸ Data lays out the app's export sheet: Contents, Include AI-Generated Summaries and Export as JSON. No upstream pull request, no pin move and no schema change.

**What the app's code says,** at `503a730b`:

- **The exporter,** `ResearchDataExporter.makeEnvelope` (app code, over SwiftData), fetches eight types unsorted (notes, tags, tag assignments, highlights, collections, prompts, projects, summaries), the summaries only with Include AI-Generated Summaries, which the sheet keeps off; the trail by its times, a plan by its name and then when it was made, the eight types of version 7 by when each was made, a review by when it was made, a lead by when it first surfaced, each sort putting a time that is none first; a collection's entries by their place, a plan's documents and targets by their keys. A note's `linkedHighlightIds` are the highlights whose `noteId` names it. It writes a summary with no authorship as `aiGenerated`, a lead's score that is no finite number as 0, only the researcher's own prompts, a saved search's parameters and watermark and a plan's tiers and toggles as its getters read them, and in the header the active project's name and question.
- **The encoder,** the kit's `makeEncoder()`: pretty-printed, keys sorted, ISO 8601 dates, which on Linux, as probed, cut a time to its second, never round it up.
- **The sheet,** `DataExportSections`: Contents, eighteen rows, tags and their assignments in one, the custom prompts the researcher's own; the switch, its footer counting every summary; Export as JSON, saved as `frus-research-export.json`; then the Mac's database export, the Markdown notes and the method appendix.

**Delivered**

- **The store** (`Sources/FRUSLightCore/UserResearchExport.swift`): the rows of the tables an export names, read at one moment, each with its place among its table's rows; the researcher's own prompts only, and a collection's entries and a plan's documents and targets whose parent it holds; and the counts of the same rows.
- **The mapping** (`Sources/FRUSLightAPI/ResearchExport.swift`): each row as the kit's record, every field version 7 carries, with the exporter's coercions and orders, the store's order standing for SwiftData's fetch order and breaking each tie; the envelope and the web's key, `frusExplorerLight`, written by the kit's encoder into one object; a row it cannot write, an id that is no UUID or a time the store does not write, refusing the export by table, row and column.
- **The routes** (`Sources/FRUSLightAPI/Exports.swift`): `GET /api/v1/me/export`, an attachment named as the app's, never cached, `includeGeneratedSummaries=true` for every summary and `projectId` for the header's project; `GET /api/v1/me/export/contents`, the counts.
- **The browser app:** Settings ▸ Data in the sheet's order: Contents, each count written as the sheet writes it; the switch and its footer; Export as JSON, which fetches the file and saves it, saying while it is prepared and, in the app's words, why it could not be; its footer; then the Markdown notes, counted by S15d's list of notes, and the import.
- **The parity harness:** `ExportCheck`, which imports an export into a store of its own, exports it as the route does and holds the export to the file: every record at the file's version, by `ResearchComparison`, and for a file of version 7 every top-level key; `ExportCheck.macOrdered`, the exporter's orders over the kit's records, an implementation of its own beside the export's over rows; and `frus-parity export-check <export>`, which runs it on an export it is given, printing counts, ids and keys.

**Decided here, each the web's own**

- **What only the web holds:** nothing the envelope cannot carry. The store's columns are the app's model's (S14a); the three the app's export leaves out, a summary's source content hash and the state of a visit's documents and of its targets, no path here writes; a saved search's twelve other columns are made from its parameters, which the file carries. So the added key holds its own version and what the file leaves out by choice, which the Mac's file cannot say: whether it carries the summaries and the instance's corrections. A parity test changes every column of every table in turn, a child's parent to another the store holds, and finds the file changed by each but those fifteen, and holds every table of the store to the export or to the three that hold no one's research, so a column or a table added later must find its place.
- **The store's order for SwiftData's,** as both are the order the records came: so an imported Mac file comes back in its own order.
- **The corrections are a curator's to carry,** as only a curator imports them.
- **The header's project is named, not assumed:** `projectId`, as the Mac's names its active project; an id that names no project heads the file with none, as the app's does. The browser app has no active project until S17f, and exports in the Mac's Global Context.
- **The counts and the file are two reads,** where the sheet counts in the pass that writes its file: the browser counts as the pane opens and after an import, and the file is written when it is asked for.

**The owner's export.** S16c's, the version-6 export from the library holding the owner's writing, summaries included, read only on this Mac, from a copy in the ignored build folder removed afterwards: never committed, and nothing of it is in this repository but what follows. `frus-parity export-check` imported it into a store of its own and exported that, in about 2 seconds and 1.3, and the export carried every record of each of the 15 types the file carries as the file has it, read at the file's version; the records it repeats under one id, each an exact copy, came out once each. The export is at version 7, so it adds the fields 6 cannot carry, with the app's initial values the import gave them.

**Tests**

- **FRUSLightCoreTests,** 104 to 106: `UserResearchExportTests`, 2: the rows of the tables named, the user's, every column, in the order the store took them, which a newer copy's replace keeps; an instance table's every row, the researcher's own prompts only, and the counts of the same rows.
- **FRUSLightServerTests,** 166 to 172: `ExportRouteTests`, 6: the kit's envelope at its version with the web's key, its headers and the kit's bytes; the switch, the header's project and the refusals; Contents' counts; the corrections a curator's; what the web writes, as the app's records; a row the export cannot write, named and its value never; the guard and the route under a path.
- **FRUSParityTests,** 176 to 188: `ExportParityTests`, 11: the done-when's two halves, over the kit's own files of versions 1 to 7, every type at 6 and at 7 and the browser suite's export; a file the export rewrites, out of the app's order, with two sets of synced settings or records twice, coming back as the store keeps it; what the web writes, through its own export at the file's seconds; every column of every table changed in turn, and every table of the store, accounted for; the exporter's orders over the store's rows, on the cases a wrong order gets wrong; ids in lower case; a saved search read as the app's getters read it; a child whose parent is gone; and the mirrors of the app's exporter, its getters and its sheet, held to its source. `NoteViewParityTests`, 1 more: the sheet's Contents, its rows' order, words and counts, beside `ExportSection.tsx`'s, and its words for the switch and the JSON row.
- **The web unit suite,** 300 to 304 in 33 files: `DataSettings.test.tsx`, 3 to 7: Contents, the switch and the file saved, preparing and the app's words for a failure, and the notes' export when Contents fails.
- **The browser suite,** 45 to 47 tests: `export.spec.ts`, by pointer, the kit's export of every type imported and Contents counted, the file saved without and with the summaries, each the kit's envelope with the web's key, its records what Contents counts; and by keyboard, the switch turned on and the file saved.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** CI's swift job, replayed under the app's heavy-job lock on the branch over main at #63, built this package's own targets clean with no warning. All 2,359 tests pass, up from 2,339 at #63, with the one named skip and nothing cancelled: FRUSLightCoreTests 106, FRUSLightServerTests 172 and FRUSParityTests 188; the others as at #63.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 304 tests in 33 files.
- **`scripts/compose-smoke --e2e`** on the branch's image passes: 47 browser tests at the root and 47 under the path, through nginx with INSTALL's recipe, `export.spec.ts` among them in both, and the smoke test's own steps.
- **CI on #64** is green: the swift, web and compose jobs.
- **A review** read the diff cold, by reading alone, and found no record mapped otherwise than the app's exporter maps it, and the coercions, the orders, the scoping, the one read and the guard as they should be. It found: a failed export the page did not show, since a link hands the server's refusal to the browser's downloads; Contents grouping digits the app's sheet writes ungrouped; the orders test over cases no wrong order gets wrong (plan names of one letter, no ties, no time that is none), the column test counting a child that left the file as one that reached it, and no id in lower case anywhere; `export-check` failing a file that repeats a record, against a comparison that kept the repeats; Contents counting children the file cannot carry; the Markdown export hidden when Contents fails; the app's saved-search getters mirrored in part; and docs that said more than the code. Each is fixed and tested: Export as JSON fetches the file, says it is preparing it and, in the app's words, why it could not; Contents writes each count as the sheet interpolates it; the tests take plan names a byte order gets wrong, ties and times that are none, move a child to another parent, and export a store whose ids are all in lower case; `asStored` keeps a repeated record as the import does; the store counts and reads only children whose parent it holds; the notes count on their own again; a saved search with no snapshot runs what its columns make, and its watermark reads field by field.

**Records**

- `docs/SPEC.md`: the export path's row and its limit, how the web exports, the routes under The user's data and in the route table, and Settings ▸ Data.
- `docs/PLAN.md`: the row's done paragraph.
- `docs/INSTALL.md`: Take your research with you, Settings' **Data**, and the routes.
- `docs/COORDINATION.md` §1: the kit calls the export makes, and its standing mirrors of the app's exporter and sheet.
- README's status; and this log.

**Next: S16e,** the import of a research database exported with the owner's writing, SPEC's last resort, which Import mode refuses in phase 1: the writing moved into the user store and the copy stripped with the kit's own sequence before it is installed; and **S17d** once S17c's pin move brings S17a's search of user text and S17b's rules, both in their own sessions now; with S14e, S14d and S14b on the server's track. The export's header waits on S17f's active project, and the sheet's method appendix on S17f.

## Session 16c: the import of a Mac JSON export

25 October 2026 · branch `claude/s16c-json-import` · [#63](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/63) · upstream `503a730b`, unchanged

Phase 2's row S16c, on the critical path: S16d, the export, S16e and S17d follow it. The Mac's JSON export comes into the server's research store whole, every type a file of format version 1 to 7 carries, each record under its Mac id, through `POST /api/v1/me/import` as a job, and Settings ▸ Data imports a file and shows its report. No upstream pull request, no pin move and no schema change: S14a's 23 tables hold it all.

**What the app's code says,** at `503a730b`:

- **The file** is the kit's `ResearchDataEnvelope`, read by its tolerant decoder (`makeDecoder()`): every version from 1 decodes, a type or field it cannot carry as empty or none. Version 3 added the trails, 4 a search's capture fields, 5 a summary's authorship, 6 archive visits, 7 the eight other types and what 6 dropped (a note's RTF, a collection's front matter, settings and structure, a project's focus tags and lead weights, a summary's headnote flag). It carries the researcher's own prompts only: the standard ones, whose ids each device mints (`PromptTemplate.id` is never persisted), never.
- **A smart collection whose saved search is gone** keeps its `savedSearchId`; the app reads it as "The linked saved search could not be found. It may have been deleted." and offers Unlink. **An entry of a kind it does not know** reads as `.unrecognized` (`CollectionEntry.entryKind`), an inert row that resolve and export skip. **Every headnote draft** the app makes carries the prompt `0EAD0000-0000-4000-8000-000000000001` (the inspector stamps it, a duplicate copies it). **Synced settings** in several copies keep the earliest made (`SettingsSyncCoordinator`).
- **A saved search** keeps its `SearchParameters` as JSON beside scalar columns `SavedSearch.init(name:parameters:)` writes from it, and its run as `SavedSearchFreshness`, both with a plain `JSONEncoder()`; a plan's tiers and toggles are written by their setters the same way.
- The app has no importer of its own.

**Delivered**

- **The store** (`Sources/FRUSLightCore/UserResearchImport.swift`): a batch of rows by table, each with the values its file carries and the defaults a new row takes, written under the user in one transaction. A row the store holds by user and id (by id alone in an instance's table, by user alone for the settings) is replaced only when the copy is newer by `ImportStamp`, its time of change or else its creation, or for a type with none the time of what it records; and then only in the columns the copy carries. Then the user's `user_search` rows are made again from all their notes and summaries.
- **The mapping** (`Sources/FRUSLightAPI/MacImport.swift`): each of the envelope's records as its table's row, by the file's version, with the app's initial value for each field an older file cannot carry; a record a file repeats under one id written once, the newer copy, and counted; the report.
- **The route** (`Sources/FRUSLightAPI/Imports.swift`): `POST /api/v1/me/import`, the export itself as the body, of 128 MiB at most, its `formatVersion` read at once (`INVALID_EXPORT`, `UNSUPPORTED_FORMAT_VERSION`), then a job on the server's queue, 202 with `Location: /api/v1/me/import/{id}`; one import a user at a time (`IMPORT_IN_PROGRESS`); `GET /api/v1/me/import/{id}`, the status and, once done, the report or the problem (`IMPORT_NOT_FOUND` for none).
- **The browser app:** Settings ▸ Data's Import a JSON Export: the file, Import, the job's line as it waits and runs, and the report: a table of each kind of record in the order and the words of the app's export sheet, with what the file held, came in, replaced an older copy or was kept, and a line for each thing the import made of what the file does not say.
- **The parity harness:** `StoredResearch`, which reads a user's rows back by its own SQL as the kit's records, and `ResearchComparison`, which holds them to a file type by type and id by id, naming a field that differs but never its value; `frus-parity import-check <export>`, which imports an export into a store of its own as the route's job does and reads it back; `frus-parity check-highlights <export> --tei <dir>`, check 6's Swift half on an export's highlights, which writes the browser suite's samples; and `frus-parity import-fixture`, which writes `fixtures/import/research-export.json`, the browser suite's export, made with the kit's own records, its highlight over d3's own text.

**Decided here, each the web's own**

- **No pin move first.** Check 6 on an export's highlights needs the kit's test of a stored passage, `HighlightReanchor.extracts`, which FRUS-Explorer#1789 made public after the pin. Its two forms are the kit's public `flatTextExcerpt` of the flat text between the offsets, and that text itself; the harness composes them, and `ImportParityTests` holds the kit's private body to them line for line, so the pin move past #1789, S17c's or S12d's, calls the kit's. A pin move first would have been a pull request of its own, with the golden files and check 6's samples to remake.
- **"Marked unlinked"** is read as the app reads a link whose search was deleted: the collection keeps its `savedSearchId`, and the report names it with the app's sentence. A later import that brings the search links it again, which a mark in the store would not.
- **"Kept inert":** a version-6 entry with no document is written with the kind `unrecognized`, the raw value of the app's own inert kind.
- **A field an older file cannot carry** keeps the store's value when its copy replaces the row, and in a new row takes the app's initial value, which a parity test reads from the app's model classes. So a version-6 file newer than the store's version-7 copy keeps the front matter, the RTF and the focus tags 6 does not carry.
- **A type with no time of change** compares the time it was made, so a highlight or a correction the store holds is kept; the trails, reviews, leads and settings compare the time of what they record.
- **A record repeated in one file** under one id, as the owner's was, is written once, the newer copy, and counted as repeated, apart from what the store kept.
- **The instance's two corrections** are imported for a curator only, which under `FRUS_AUTH=none` the one user is; anyone else's are set aside and counted.
- **One import a user at a time,** each kept in memory with its report, the last 50 finished, until the server restarts, under a UUID, so that an id from before a restart names no import rather than another.
- **The import holds the store while it writes,** as one transaction must with the store's one connection, so the user's other reads wait for it. The store reads each table's rows once to find a record by its id, and makes `user_search` again from one read of the notes and one of the summaries; and under `FRUS_AUTH=none` the server reads the single user once, so `GET /me` and an import's status answer while an import writes.
- **128 MiB** for an export: a summary takes a few kilobytes, so tens of thousands of them fit, and the job, which holds the file and its records at once, stays within a small server's memory. INSTALL's nginx recipes raise nginx's own limit to it.
- **The report's names** are the app's export sheet's Contents, and the web's own for the parts that sheet counts in one row: Tags and Tag Assignments, Collection Entries, Archives Visit Documents and Targets.

**The owner's export.** A version-6 export from the library holding the owner's writing, with Include AI-Generated Summaries on, made on 24 October and read only on this Mac: never committed, and nothing of it is in this repository but what follows. `frus-parity import-check` imported it, and read it back, in about 6 seconds, and read every record of each of the 15 types it carries back as the file has it, the eight types 6 cannot carry counted as not carried; some notes and trail records came twice under one id, each repeat an exact copy, which the report counts as repeated. Through the API, on a Compose install of this branch's image with no index, its own project and port and the TEI clone mounted, it imported the same, with the same report, in a job of 6 seconds. Check 6 on its highlights: in Swift, the TEI clone at `HistoryAtState/frus` `6170e4b32` matched every highlight's rendering version, and each one's selected text is the kit's excerpt; in Chromium, on the same install, `highlights-check6.spec.ts` read the samples `check-highlights` wrote (`FRUS_CHECK6_SAMPLES`) and found, on every document, the kit's flat text between each highlight's offsets in the reader's page, read by the kit's offset engine, the selection bridge reading the kit's range back to them, and the kit's renderer drawing each one. None went to review, and none failed.

**Tests**

- **FRUSLightCoreTests,** 96 to 104: `UserResearchImportTests`, 8: rows under the user with the Mac's ids; the newer-copy rule at each edge; a replace writing only what the file carries; each user's own and the instance's shared; `user_search` made again for the user; the collections whose search is not held; a batch that does not fit, writing nothing; a stamp for every table.
- **FRUSLightServerTests,** 160 to 166: `ImportRouteTests`, 6: the job queued behind another and its report, `IMPORT_IN_PROGRESS`, the same file again kept, `IMPORT_NOT_FOUND`; the refusals at once; a file whose records do not decode failing its job and keeping nothing; the guard and the import's own limit; user data off and the route under a path; the corrections set aside for a user who is no curator.
- **FRUSParityTests,** 163 to 176: `ImportParityTests`, 13: an envelope the kit writes with every type, at 7 and at 6, through the route, field for field; each of the kit's own files of versions 1 to 7 (`ResearchDataFixtures`, read from the submodule's source) whole; a newer copy replacing only its row and only what 6 carries; a record the file repeats; the check naming a record the store holds otherwise or not at all; the browser suite's export byte for byte as the command writes it; check 6 on an export's highlights over the fixture TEI; and the mirrors: the headnote prompt, the inert kind, the models' initial values, the saved search's columns and watermark, a plan's blobs and the synced settings. `NoteViewParityTests` holds the report's names to the export sheet.
- **The web unit suite,** 295 to 300 in 33 files: `ImportSection.test.tsx`, 5.
- **The browser suite,** 43 to 45 tests: `import.spec.ts`, by pointer, three imports of the browser suite's export, All Notes filtered by an imported project, and d3's imported summaries in the rail with the app's words and their prompts' names; and by keyboard, the file chosen and imported. `notes.spec.ts` reads the projects an import leaves; `highlights-check6.spec.ts` reads another file of samples by `FRUS_CHECK6_SAMPLES`.
- **`scripts/compose-smoke`:** an import of more than 4 MiB through nginx under the path, with the recipe's limit.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** CI's swift job, replayed under the app's heavy-job lock on the merge with main at #62, built this package's own targets clean with no warning. All 2,339 tests pass, up from 2,312 at #62, with the one named skip and nothing cancelled: FRUSLightCoreTests 104, FRUSLightServerTests 166 and FRUSParityTests 176; the others as at #62.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 300 tests in 33 files, on the merge.
- **`scripts/compose-smoke --e2e`** on the merge's image passes: 45 browser tests at the root and 45 under the path, through nginx with INSTALL's recipe, and an import of 5,264,647 bytes through nginx under the path with the recipe's limit.
- **A review** read the diff cold, by reading alone, and found: each row's lookup by `upper(id)`, which no index serves, so an import scanned its table once a row while it held the store; the rebuild of `user_search` a document at a time, a scan of its own each; the status poll waiting on that lock, through the guard's read of the user, so the pane said an import was queued while it ran; the pane locked, and polling twice a second for ever, after a poll failed, saying nothing was kept when the job might still run, and showing another import's report under an id a restart gave again; `import-check` leaving its store in the temporary folder when the check failed; the peek parsing the file on the cooperative pool; and the smoke step's poll ending the script without its line under `set -e`. Each is fixed, and tested where a test can hold it; the owner's import check went from 16 seconds to 6. It found the version gates, the 23 tables' columns, the defaults, the mirrors, the keys of the three tables not keyed by user and id, the rollback, the repeats and the browser suite's two runs on one store as they should be. Its last point, that a version-6 copy newer than the store's keeps the stored RTF beside a body it changed, is the rule as decided: a field the file cannot carry keeps the store's value, and the codec opens such a note plain, as it opens any RTF whose text is not the note's.

**Records**

- `docs/SPEC.md`: how the web imports a Mac JSON export, the smart collection under Two limits, the route and the report under The user's data, the body limits, Settings ▸ Data, the security line and check 6's row.
- `docs/PLAN.md`: the row's unlinked sentence, its done paragraph, and the owner's checkpoint done.
- `docs/INSTALL.md`: Bring your research from the Mac, the routes and their codes, and the nginx recipes' `client_max_body_size 128m`, which compose-smoke runs.
- `docs/COORDINATION.md` §1: the kit calls the import adds, and its standing mirrors.
- README's status; and this log.

**Next: S16d,** the export, which reads what this row writes; then S16e, and S17d once S17c's pin move brings the kit's search of user text; with S14e, S14d and S14b on the server's track. The owner's export repeated records under one id, an exact copy each: worth a look in the app, whose `DuplicateRecordCleanup` collapses such copies at `503a730b` for ten types, among which are neither notes nor the trails, the types the repeats were of: filed as [FRUS-Explorer#1791](https://github.com/joshbotts/FRUS-Explorer/issues/1791).

## Session 19a: Citation Lookup, over the API and in the browser app

24 October 2026 · branch `claude/s19a-citation-lookup` · [#62](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/62) · upstream `503a730b`, unchanged

Phase 2's row S19a, beside S16c, with which it shares no file but the records. Citation Lookup comes to the web as the app's window has it: Paste Citation, Structured Entry and Batch, through the kit's form, matcher, splitter and runner, every label and count the kit's. No upstream pull request, and no schema change: #1787 made Batch's and Structured Entry's types public, and S16b's pin brought them.

**What the app's code says,** at `503a730b`:

- **The window** (`CitationLookupView`): a segmented Input mode, Paste Citation, Structured Entry and Batch, in `CitationLookupMode.allCases`' order. Paste's field, "Paste a FRUS citation…", re-derives the five Parsed Fields from its text alone on every change (`CitationLookupFields.refreshed(forPaste:mode:parser:)`, #1474), and so does entering Paste after Batch changed the text, while a return from Structured Entry keeps what was typed there. Structured Entry is the fields. Batch shows none (#1506). Look Up is disabled until `isActionable(mode:pasteText:parser:)`, and Return in a field runs it. A result shows its label above it in its strategy's colour and symbol, the volume's title for a row naming a volume and the document's id otherwise, the volume's id, the correction note, and Download Volume or View Document; a lookup that finds nothing says No Matches Found, and one that fails Lookup Error. Batch's table has the kit's summary, Needs work first (on at first, worst first, the paste's order within a kind), each row's printed number or place, its text and its outcome's label, and a tap opens a row's first match when it names a document. Each outcome is announced to VoiceOver.
- **The lookup** hands the matcher `CitationLookupFields.input(mode:pasteText:parser:)`: the fields trimmed of white space, a document or page that is no whole number dropped, a part Arabic or Roman, and in Paste the title fragment and the paste's link, the link only while the five fields hold what the paste produced.
- **The matcher** (`CitationMatchingEngine`) reads its volumes from a `CitableVolumeCatalogue`, the app's `ManifestStore`, and takes as downloaded the volumes whose file is on disk, asking the index at each lookup whether it can answer for one (#1522). **Batch** (`BatchCitationRunner.run`) looks each split entry up in turn, its parse whole, and hands each row to the main actor; `BatchCitationOutcome` classifies, orders and sums them up.
- **The labels** (`ConfidenceLabels`): SPEC's "six confidence labels" were the app's manual's table when SPEC was written. At the pin the manual tables eight kinds, over seven strategies: Exact match; Matched by page number; Possible match, one of several on a page; Match — document number assigned digitally; and three kinds of Volume identified, to download, holding nothing the citation names, and not yet indexed; and Best guess, with why.

**Delivered**

- **The API** (`Sources/FRUSLightAPI/CitationLookup.swift`):
  - `GET /api/v1/citation-lookup`: Paste Citation with `text`, or Structured Entry with the five fields by the draft's names, read by `CitationLookupFields` as the app's Look Up hands them over, a field given in Paste standing for the reader's edit; the draft's array of `CitationMatch`, each with `isBestGuess` and its strategy's value, `bestGuessExplanation` or `sharedPageDocuments`.
  - `GET /api/v1/citation-lookup/fields`: the kit's form, the five Parsed Fields a paste fills and Look Up's gate, in each mode.
  - `POST /api/v1/citation-lookup/batch`: a block of notes as the form field `text`, split by the kit and each note run by its runner, every row with its outcome and matches, and the kit's summary.
  - The two reads answer POST with a form body too, as `/search/inspect` does, and the browser app posts.
  - One engine per served index (`ServedIndex.citations`), over its `SearchService` and `PageRangeStore`, a `FixedVolumeCatalogue` of the bundled manifest, and the volumes it holds as the downloaded ones; with no index, one over the catalogue alone.
- **The browser app** (`web/src/lookup`): `LookupScreen` at `/lookup`, opened by Find by Citation beside Search's syntax, as the Mac's Search window has it beside Tips: the mode picker as the app's segmented control, Paste's text, Batch's footnotes, the Parsed Fields, Look Up and the results, each with the kit's label in its strategy's colour and symbol (`SymbolIcon`, the app's SF Symbols drawn small), its headline, note and action; Batch's table with its summary and Needs work first; the outcome in a status line. `lookupState.ts` keeps the form for the tab's session: what the server last derived from the paste, the reader's edits over it, when to ask again, and the last lookup and block. `lookupRules.ts` holds the few lines of the app's view it mirrors.
- **Check 7's matcher half through the API** (`CitationLookupAPIParityTests`), below.

**Decided here, each the web's own**

- **`/citation-lookup/fields`,** a route the draft lacks: the browser app may not derive the Parsed Fields or Look Up's gate itself, since both are the kit's, so it asks the server as the text or a field changes, 150 ms after the last keystroke, and once more for what the form holds when Look Up is pressed, so a keystroke in between is never lost.
- **The fields as the app's form reads them,** never refused: a document or page that is no whole number is none, as in the app's form, so the browser app and the app agree on what Look Up hands over. A request in Paste sends the reader's edits alone, the server deriving the rest from the text, so a field never stands for an edit the reader did not make while the server's answer is on its way.
- **The draft's `volumeId`, `documentId` and `titleFragment`** are refused as `UNSUPPORTED_PARAMETER`, each saying to send the text, from which the kit's parser takes them, as S11f refused the concordance's.
- **The downloaded volumes** are those the served index holds, as S12c's page links take them for `PageLink`'s `onDevice`; the mounted TEI is not consulted, since a volume in a clone of the corpus that the index lacks would read "downloaded but not yet indexed; look it up again once it is", which Import mode never changes. With no index served, the catalogue alone answers, as the app's matcher does with nothing downloaded.
- **View Volume,** where the app offers Download Volume, which this server cannot: it opens the volume's page in Browse, which says what the server holds of it and, with its TEI mounted, lists and opens its documents.
- **Batch's bounds:** 500 citations a request, `TOO_MANY_CITATIONS` beyond, and a body of 256 KiB, since the runner looks each citation up in turn on the connection every search shares, and the app's has no bound. The table comes whole, where the app's fills as each row completes: a lookup takes about 7 ms, so a chapter's notes take well under a second.
- **POST for the reads,** found by the session's own review: the browser app first sent Batch's block to the form's gate in an address, which nginx refuses past 8 KiB with 414, so the two reads take a form body as `/search/inspect` does, and the browser app posts.
- **The fields at a new paste** are empty until the server has read it, never the last paste's, which stood for 150 ms and a round trip in the first cut, as the cold review found: a field typed meanwhile added to the old value ("1" and a typed "5" made "15"), and Structured Entry could look the old citation up. A field typed before the answer stands over it, as an edit. Fixing it, the session found that a text changed and changed back before it settled kept no fields at all, and that is fixed too.
- **Every Look Up asks the server,** as the app's asks its matcher, so an earlier citation looked up again is never answered from what the browser kept, which a new index may have changed. Each mode's results are asked for only in that mode, so a reload in Paste Citation sends no block.
- **A gate the server could not answer** runs the lookup, whose answer then says what went wrong; one the form's own change abandoned runs nothing.
- **Batch, 25 notes at a time:** the kit's runner turns a lookup its task stopped into a failed row and goes on, so a block whose client had gone ran to its end on the matcher every search shares. Given 25 at a time, it stops at the next 25.
- **An error is said once,** by its alert: the status line, which says each outcome, says nothing for an error.
- **The six labels** in PLAN's row and SPEC are now the kit's labels, which the browser app shows as the server gives them; the app's colours and SF Symbols are drawn in tones held to 4.5:1 in both appearances and small symbols of the web's own.
- **Focus.** The screen takes focus at its heading, as every screen does, where the app focuses the paste field; the mode picker keeps the focus as its arrows change the mode, where the app moves it to the mode's first field, since a radio group whose arrows moved focus away could not be walked (WCAG 3.2.2). Look Up is `aria-disabled`, never disabled, so it keeps the focus while it looks up.
- **The form is kept** for the tab's session, in its session storage, so a document opened from a result, Back, and a reload find the form and its results as they were, as the app's window stays open beside the documents it opens. A result's View Document is a link, which ⌘-click opens in a tab of its own, as the Mac opens a document window.
- **Return** in Paste's text looks it up, as in the app; Shift+Return begins a line. In Batch's footnotes Return begins a line, as in the app's editor.
- **Batch's results show after a batch has run.** The app's form shows Nothing to Triage in Batch after a lookup in Paste, its one `hasSearched` serving both.
- **A View Document link's name** adds the document's and volume's ids, hidden, since a list of links all named View Document names no target; the visible words stay the app's.
- **The mode picker's label,** Input mode, is hidden, as the app's segmented picker shows none.
- **"1 matches found"** is the app's announcement, kept.

**Check 7's matcher half through the API.** `CitationLookupAPIParityTests` imports the fixture index as an export is and asks Citation Lookup over HTTP. Each answer is held, field by field, to the kit's engine over the same file and catalogue, built in the test with the kit's calls alone:
- **the app's own citation of every bundled volume** (the kit's `ownCitationsAreNeverBestGuesses`), in each style, marked and as Copy Citation copies it, through Batch: 551 of 553 come back first as their own volume, never as a best guess, the two the kit excuses by name not, in each of the six forms; the three indexed volumes answer with their document 1, found by its number;
- **every fixture document,** 393, through Paste Citation and Structured Entry: its link, which names it exactly; its citation in each style as Cite writes it, read from the server's citation endpoint, each numbered document's coming back first as itself, found by its number; the same with its number edited in the Parsed Fields; and its subseries, volume, part and number, and the first and last pages it may be printed on. 3,011 lookups, each the kit's answer: exact matches, page matches, shared pages, digitally numbered documents and volumes to download among them;
- **Batch,** the kit's splitter fixtures and a chapter's notes, row for row and summary for summary, resolved, best-guess, ambiguous and missing rows among them;
- **the form,** its fields and Look Up's gate, for pastes, typed fields and blocks;
- **the kit's tests over the bundled catalogue,** titles printed whole, the series' name, a dated footnote and links, with their own expectations;
- and **the strategies' names,** the draft's enum, read from FRUS-API.openapi.yaml.

**Mirrored, with a parity test.** `CitationLookupViewParityTests` reads the app's source, the kit's and `web/src` at once: the window's 32 words and Search's two under their keys, the kit's names for the modes, and four format strings; every strategy's colour and symbol, read case by case from the app's two switches; the result's headline, note and action; each outcome's label, colour and symbol, a lone candidate's own label in place of a count; the row a tap opens; Needs work first's order and its first state; the modes' order; Parsed Fields hidden in Batch; and the kit's rule for deriving the fields again (`refreshed(forPaste:mode:parser:)`), with the view's two events that ask it, a change of the paste field's text and a change of mode, which `lookupState.ts` mirrors.

**Tests**

- **FRUSLightServerTests,** 150 to 160: `CitationLookupTests`, 10. No index; Paste with the reader's edits and a link; Structured Entry's reading; a volume not yet indexed; the form; Batch; every refusal and HEAD; POST as the query, with a paste of 20,000 characters; Batch stopping between slices when its task is stopped; under a path.
- **FRUSParityTests,** 153 to 163: `CitationLookupAPIParityTests`, 6, and `CitationLookupViewParityTests`, 4.
- **The web unit suite,** 274 to 295 in 32 files: the screen, 15, its rules, 4, and its form's store, 2. Each test of a review's finding fails on the code before its fix.
- **The browser suite,** 38 to 43 tests:
  - `citation-lookup.spec.ts`, by pointer: Find by Citation, a pasted link and its fields, View Document and Back, a page, a volume to download and View Volume; Structured Entry by page, and a part the volume lacks as the kit's best guess; Batch, worst first and as pasted, a note wrapped across lines, and a note's document; and each mode in the dark appearance;
  - `citation-lookup-keyboard.spec.ts`, by keyboard alone: Tab to the picker and the text, Return to look up, View Document, the picker's arrows to Structured Entry and to Batch, Return beginning a line in the footnotes, Needs work first by Space and a note's document by Return.
  Each runs axe at each state. No caret browsing: nothing in the reader is selected.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** CI's swift job, replayed under the app's heavy-job lock at the final code, built clean with no warning. All 2,312 tests pass, up from 2,292, with the one named skip and nothing cancelled: FRUSLightServerTests 160 and FRUSParityTests 163; the others as at #61, FRUSCoreKitTests 1,191 among them.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 295 tests in 32 files.
- **`scripts/compose-smoke --e2e`** on this branch's image at the final code: 43 browser tests at the root and 43 under the path, through nginx with INSTALL's recipe, with no axe violations.
- **Reviews.** The session's own review of the screen found the gate's settling restarted by every render, and Batch's block sent to the gate in an address that nginx refuses past 8 KiB; both are fixed. A cold review of the whole branch, by a reader given the code and the app's, not this session's conclusions, found eight things, all upheld and fixed: the Parsed Fields standing for the last paste, a gate's failure or cancellation counted as go, a reload test that could not fail, Look Up answered from the browser's cache, an abandoned Batch running on, the kit's refresh rule mirrored with no parity test, an error announced twice, and the parity test never sending an edit in the browser's shape.

**Records**

- `docs/SPEC.md`: Citation, the API table, the three routes' departures from the draft, and check 7 through the API.
- `docs/PLAN.md`: the row's labels and its done paragraph.
- `docs/INSTALL.md`: Citation Lookup in the browser app, the API's routes and `TOO_MANY_CITATIONS`.
- `docs/COORDINATION.md` §1: the server's kit calls and the view code the browser app mirrors.
- README's status, with its phase-2 gaps brought up to date.
- This log.

**Next: S16c,** the import of a Mac JSON export, which PLAN puts after S15d, with S14e, S14d and S14b beside it.

## Session 15d: notes and summaries, and the rich-text codec

24 October 2026 · branch `claude/s15d-notes-summaries` · [#61](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/61) · upstream `503a730b`, unchanged

Phase 2's row S15d, on the critical path: S16c, the import, follows it. Notes come to the reader, the rail and All Notes as the app writes them, with its formatting kept as the Mac keeps it, in RTF, read and written by a codec of the web's own and held to the app's own reading of RTF by golden spans made on the owner's Mac. Summaries are shown as the app's rail shows them, and the researcher may write their own. No upstream pull request, and no schema change: S14a's `notes`, `summaries`, `prompts`, `projects` and `user_search` hold it all.

**What the app's code says,** at `503a730b`:

- **A note** (`ResearchNote`) is a document's `bodyText`, canonical, with `richText`, RTF `Data` or nil for "use bodyText", and its `projectIds`, `userTagIds` and `selectedSummaryIds`. A highlight names it by `noteId`; deletes on either side leave the other's ids, which the app tolerates.
- **The editor** (`ResearchNoteEditorView`, the Mac's composer window): the body, with the Formatting switch the device keeps; Tags and Projects; Generated Summaries with Insert into note, which appends the text after a blank line, and Remove from note, which forgets the id only; Delete, with no question, Discard and Save. With Formatting on, the body is `RichTextEditor`: bold and italic through `NSFontManager`, underline, a colour from the shared colour panel, and a link to any text typed, `URL(string:) ?? trimmed`. With it off, the first keystroke drops the RTF (`setPlainBody`). A save writes the RTF the editor last reported, so a save that edits nothing keeps the stored bytes.
- **The selection bar's Note** opens a new note on the document, with no quote and no link. After a highlight is made, the rail offers Add Note to Highlight until it is chosen; its Save sets the highlight's `noteId`.
- **The rail** (`ResearchRailView`): Summary and Notes, both open until closed (`frus.document.researchPanel.summary` and `.notes`). Summary shows one summary at a time, newest first by `GeneratedSummary.ranksAbove` (`createdAt`, then `lastModified`, both descending, then the id), with a history control over up to 20, labelled "AI summary" whatever its authorship, and the prompt's name when the device holds it (`SummarizationPrompt.resolve`'s `.requested`). Notes lists the document's notes by `lastModified`, each its text or "Empty note" and the time since it changed.
- **All Notes** (`NotesPaneSnapshot`, `AllNotesScreen`): every note, newest first; filtered by project (All projects, Not in a project, one), tag and text over the body, the volume and the document; each row its first line cut at 90 characters, the document with its projects and tags, and its date; "Showing %lld of %@".
- **`user_search`'s mirror** in the app, `user_content`: a document's notes joined as `ResearchNote.indexedTextPerDocument` joins them, by `createdAt` then id, blank ones dropped, with a blank line between; and its newest summary that is no headnote draft.
- **The Markdown export** is the kit's `ResearchNoteMarkdownExport.render` per note, with the citation the exporter makes, one file each, handed to the share sheet.
- **How the app reads RTF:** only through AppKit (`ProseRichText.decodedRTF`), and its exporters' spans through `CollectionProse.paragraphs(fromRTF:)`: bold and italic from the font's traits, underline from any style, the colour through `usingColorSpace(.sRGB)` truncated to bytes with near-black as none, the link's string; paragraphs split on a blank line one attribute run at a time.

**What a Mac showed, measured on the owner's Mac (macOS 27.0.1, Xcode 27.1).** Linux's Foundation reads no RTF, so the codec was written against probes of AppKit itself, then held to the golden spans:

- Apple's writer always writes `\b` and `\i` for a bold or italic font, Times-Bold included, so the codec reads those words and no font's name.
- Typed text carries the catalog `textColor`. The app reads it as no colour under the light appearance and as white under the dark one, and no exporter fixes an appearance: **a collection exported while the Mac is in dark mode tags its typed prose `color:#FFFFFF` in HTML, white in Word and PDF.** That is the app's to fix, upstream; the golden spans are read under the light appearance, and the codec reads it so.
- A catalog colour is the system's colour of that name, not the values written beside it (`systemRedColor` reads `FF383C`); an unknown name is its values.
- The legacy `\colortbl` is Generic RGB to AppKit (`\red255\green0\blue0` reads `FF2600`), and the expanded table names sRGB, gray, Display P3, Generic RGB or CMYK. Over 30,000 sampled values, `\cssrgb` reads exactly as `Int(c / 100000 * 255)`; gray and the converted spaces go through ColorSync, which analytic conversions match within one step per channel at 99.6 % of points and never by more.
- Pasted text keeps its fonts, and Apple writes CJK text in such a font as `\'xx` bytes in the font's charset (GBK for `\fcharset134`, Shift-JIS for 128, Korean for 129); a list's markers as `{\listtext}`, which its reader drops; strikethrough, scripts, backgrounds and paragraph styles as words of their own, each of which breaks AppKit's runs.
- A typed CR, CRLF or U+2029 comes back from Apple's writer as a line break, so such a note's RTF text is not its `bodyText`.

**What the final review's probes of AppKit showed,** each now the codec's rule and a fixture of `fixtures/rich-text/read` or a case of the golden spans:

- **Code pages.** AppKit reads each `\'xx` byte, and 8-bit text, in its font's charset's page: 0 is Windows-1252, 77 MacRoman, 128 Shift-JIS (932), 129 Korean (949), 134 GBK (936), 136 **code page 950**, not plain Big5, and 161 to 238 the Windows pages; a font of charset 1, 2, 255 or none is the document's page. Text in no font of the table is in the document's page: its last `\ansicpgN`, `\mac` or `\ansi`, or NeXTSTEP with none; `\pc` and `\pca` are ignored, `\deff` selects no font for decoding, and `\plain` selects font 0. AppKit holds text bytes until a word it knows, a brace, or a control symbol other than `\'`, `\\`, `\{` and `\}`, then decodes them together: a byte undefined in the page loses the held text. Cocoa writes `\ansicpg936` and the like under a non-Western system, but writes the same body bytes, so Mac notes are unaffected. AppKit matched the Mac's CFString entry for entry over 12 single-byte and 4 double-byte pages, 98,960 entries; Linux's Foundation does not quite, so the codec carries the Mac's tables (`Sources/FRUSRichText/RTFCodePageTables.swift`, written by `tools/rtf-code-pages/make`), and the golden spans hold a digest of AppKit's reading of every entry, which CI holds the codec to. AppKit's 65 other `\ansicpg` pages the codec does not read; a note in one opens plain.
- **`\bin`** is read by AppKit as RTF, not skipped (`a\bin3 xyzb` reads `axyzb`), which reverses the review decision to skip it; an unterminated document reads as nothing; a document may open after CR, LF or NUL. More than 256 nested groups stays the codec's own refusal, though AppKit reads 600.
- **`\nosupersub`** clears only super- and subscript; a baseline offset holds.
- **`\uc`** is inherited by nested groups, a field's result among them, and scoped to its group; only text counts toward a `\u`'s fallback.
- **Links.** AppKit percent-encodes, in uppercase hex, a space, `"`, `<`, `>`, `\`, `^`, `` ` ``, `{`, `|`, `}`, a `[` or `]` outside an IP literal, a `%` before no two hex digits, each `#` after the first, an `@` in the userinfo before its last, and non-ASCII as UTF-8, and reads a link whose port is not digits as none. The codec stores and writes each link as the app reads it back (`RichTextRuns.appReading(ofLink:)`), matching AppKit on 1,173 of 1,241 probed links; the rest, a scheme after other characters and ports holding `(`, `)`, `<`, `>` or `%30`, are never a new followable link, and Apple's writer writes none of them.
- **U+FFFD** reads as nothing in AppKit, so the Mac loses it at its next save; a run may not hold it, and the browser drops it from a formatted edit.

**Delivered**

- **The codec** (`Sources/FRUSRichText`, a target of its own, Foundation only, so `tools/mac-golden` links it too):
  - `RTFReader` reads RTF into the text AppKit gives and runs that break where AppKit's attribute runs break, each with the app's span formatting: groups and their state, `\uN` with `\uc`, `\'xx` in the current font's charset, the expanded and legacy colour tables as above, catalog colours from a table the golden spans hold (`RTFCatalogColors`), `HYPERLINK` fields, the destinations AppKit skips, `\bin`, and a run key of everything AppKit's attributes hold, fonts, sizes, strikethrough, scripts and paragraph properties among them.
  - `RTFWriter` writes what the Mac's editor writes: AppKit's header, the editor's font at 13 points, unformatted text in the catalog text colour, so a Mac draws it in its appearance's own colour, and each colour as `\cssrgb` at its byte's midpoint, so the app's truncation reads every byte back.
  - `RichTextRun` and `RichTextRuns`: the wire's runs, and their rules.
- **The golden spans** (`fixtures/golden/rich-text/spans.json`, check 13): `tools/mac-golden rich-text` drives the note editor's own path, an `NSTextView` set up as the representable sets it with `RichTextEditorController`, for each formatting it offers, colours from each of the panel's modes and pasted attributes and fonts among them, 90 cases; reads the 35 hand-written files of `fixtures/rich-text/read` and the codec's RTF for the 39 cases of `fixtures/rich-text/web`; records each case's text, its unmerged runs by the app's span rules and `CollectionProse`'s paragraphs, under the light appearance; has the codec rewrite every written and read case, in the canonical form a web edit stores, for the app to read again; and records a digest of AppKit's reading of every byte of 16 code pages. Format 2, 1.8 MB. `scripts/make-golden` makes it, after `frus-parity rich-text-fixtures` writes the web cases' RTF natively; any change to the app's sources makes it stale, as the other golden files.
- **The store** (`Sources/FRUSLightCore`): `NoteStore`, `SummaryStore` with the one `SummaryOrder.ranksAbove` and the one rule for a summary the researcher may change (`OwnSummary.isEditable`), and a read-only `ProjectStore`; every note and summary write rewrites the document's `user_search` row in its own transaction, and a new note links its highlight in the same one.
- **The API** (`Sources/FRUSLightAPI`), under the S14c guard: notes, summaries and projects as SPEC's HTTP API section now has them, with the edit-driven save, the 4 MiB request a note's save may be, and `GET /api/v1/me/notes/export`, one ZIP of the kit's per-note files.
- **The browser app:**
  - the note editor, Tiptap 3.31.4, loaded when a note opens formatted (a chunk of its own, 362 kB; Browse and Search load none of it), with the app's toolbar words and keys, ⌘K for the link, Escape as Discard, and the colour drawn through the CSSOM;
  - Note on the selection bar, which a footnote's selection holds alone, and the bar renamed Selection;
  - the rail's Summary and Notes, with Add Note to Highlight;
  - All Notes at `/research/notes`, with `/research` leading there until S19b and Research in the header;
  - Settings ▸ Data, with Export Notes as Markdown.

**Decided here, each the web's own**

- **RTF in the store, runs on the wire, and never HTML.** PLAN's row and SPEC had the web keep "a sanitized HTML subset". The Mac's own format is RTF, which S16c imports and S18f writes back, so the store keeps the Mac's bytes, untouched until the body is edited on the web, and then the codec's; the browser and server exchange runs, stretches of the plain text with their formatting, whose text is the body exactly. Nothing stores or serves a note as HTML. PLAN's row and SPEC's passages are corrected.
- **PLAN's "the selection bar's Note links a note to its highlight"** is not the app's: its Note makes a note on the document, and the link is Add Note to Highlight's. The row is corrected.
- **A save sends the body only when it was edited,** as the app's editor reports one: without one, the store keeps the body and the RTF byte for byte, so a tags-only save keeps a Mac note's fonts, lists and colours; an edit with Formatting off drops the RTF, as the app's first plain keystroke does.
- **Links.** The Mac links any text its reader types, and AppKit percent-escapes it, so a note may hold a link a browser should not follow, such as `javascript:`. The store keeps every link and gives it back; a link made on the web must be http, https or mailto; the browser follows none of the others, drawing them as linked text.
- **A stored RTF the codec cannot read, or whose text is not the body's,** or whose runs a save could not send back, is kept as it is, and the note opens plain with a sentence (`formattingKept`), until its body is edited on the web.
- **The size of a note:** 1 MiB of text in UTF-8, in a request of 4 MiB at most, so a note of that size can be sent again with its formatting; other changes stay at 64 KiB. INSTALL's nginx recipes raise nginx's own limit, 1 MiB, to match.
- **Summaries the researcher writes** are `userWritten`, no draft, under the web's own prompt id, `0EB00000-0000-4000-8000-000000000001`, never the app's headnote id, which S16c uses to tell an older file's headnote drafts apart. Only those may be edited or deleted. The rail labels a summary by its authorship, with the app's words for each, AI summary, AI · edited and Yours, where the app's rail says AI summary for every one.
- **Ids a note names that the user does not hold:** a new one is refused, as S14c's tag rules require, and one the note already carries is kept, as the app keeps it.
- **The editor's Generated Summaries** lists every summary of the document but drafts, newest first and uncapped, where the app's lists them all, drafts included, unsorted; Insert into note keeps the note's formatting, which the app's drops.
- **The editor's Tags and Projects** are checkboxes in name order, until S17b brings the app's picker and its order.
- **The Formatting switch** is a visible switch named by its word, Formatting, since WCAG's Label in Name rules out the app's hidden "Formatted text"; the toolbar is named Text formatting.
- **⌘K** opens the link dialog over a selection; a link with no followable scheme keeps the dialog open with a sentence.
- **The selection bar is named Selection,** and a footnote's selection gets a bar with Note alone, which has no key of its own: the host answers Alt+F10 only over the text, and the rail's Add Note makes the same note.
- **A note's colour on the dark theme** is drawn lighter where it would fall under 4.5:1 on the dark page, the stored colour unchanged.
- **All Notes' Delete…** is a button on each row, where the app's is a context menu; its count is shown in the page.
- **The Markdown export** is one ZIP of the app's per-note files, where the app hands them to the share sheet; entry times are the notes' own, in UTC, with Info-ZIP's extended timestamp.
- **A footnote of the codec's own:** a colour converted from another colour space matches the app's within one step per channel, not exactly, since ColorSync's tables are not reproducible bit for bit.

**How the done-when is read.** RTF is a byte format, and the app's reading is its spans, so the codec is held to the spans, never to Apple's bytes, which carry the macOS version: it "reads every golden RTF into the app's spans" where its text is the app's text and its runs give the app's spans and paragraphs, neighbours of one formatting joined; and it "writes RTF that reads back to them" where the app reads the codec's rewrite of every written and read case back to its own spans, and the codec's RTF for each web case to that case's runs. Colours count as the app's exactly in sRGB and by catalog name, and within one step per channel where AppKit converts from another colour space.

**Mirrored, with a parity test.** `NoteViewParityTests` reads the app's source at the pin and `web/src` and holds them together: 59 of the app's words and 7 of its format strings under their keys; All Notes' title, detail, filters, order and count (`NotesPaneSnapshot`), with the text filter's fold, NFC and lower case, as `localizedCaseInsensitiveContains` reads canonical equivalents alike; the rail's order, Summary, Notes, Tags, and Add Note to Highlight above Add Note; its preview, cap of 20, history control and open states; the kit's `CountCopy.phrase`, run; and the editor's summary insertion, tag making, toggle rule and link rule. `NotesAndSummariesParityTests` holds the server's `SummaryOrder.ranksAbove` to `GeneratedSummary.ranksAbove`, `user_search`'s note text to `ResearchNote.indexedTextPerDocument`, the newest summary but a draft, a prompt's name by the `.requested` rule, the export's citation to the exporter's, and the codec's paragraph split and colour reading to `CollectionProse.append`, `hex` and `hexColor`. Standing mirrors, unless a row moves them into the kit: `ranksAbove` and `indexedTextPerDocument`; All Notes' rules move with S17b, and `append` and `hex` with S18a.

**Tests**

- **FRUSRichTextTests,** a new target, 42: the wire's rules, the reader (groups, `\uc`, `\bin`, the document's start and end, 257 groups, code pages and held bytes, `\nosupersub`, links as the app reads them), the writer (no fallback character, links, a near-limit note of many colours) and every charset's page on Linux.
- **FRUSLightCoreTests,** 78 to 96: `UserNoteTests`, `UserSummaryTests` and `UserSearchTests`. What a note keeps, verbatim; the latest first; a save that keeps the body byte for byte unless it was edited; the id rules; a new note's highlight; the reader's own summary, the app's order and what only the reader may change; prompts and projects; `user_search`'s note and summary text after each kind of write; each user's own.
- **FRUSLightServerTests,** 129 to 150: `NoteTests`, `SummaryTests` and `NotesExportTests`. Every route and refusal; canonical runs; a tags-only save keeping Apple's RTF, and a kept note's, byte for byte; a stored link given back whatever its scheme and a new `javascript:` one refused; Add Note to Highlight; `user_search` after every write; a 1 MiB note, and the limit; user data off and the routes under a path; the export's entries byte for byte as the kit renders them, with valid CRCs and times.
- **FRUSParityTests,** 129 to 153: `RichTextGoldenTests`, check 13, 10; `GoldenTests`' damaged rich-text golden, 1; `NotesAndSummariesParityTests`, 8; `NoteViewParityTests`, 5; and `HighlightViewParityTests` without the bar's old name.
- **The web unit suite,** 157 to 274 in 29 files: `runs.ts` against Tiptap's own schema, the paste, the editor, the note editor's save rules, the rail's Summary and Notes, All Notes and its rules, Settings ▸ Data, the selection bar's Note and its focus, and user data off. Vitest runs in UTC.
- **The browser suite,** 30 to 38 tests:
  - `notes.spec.ts`, by pointer: Note from the bar, bold, italic, underline, a colour, a link and its removal, plain mode, the rail's row and an edit, a tag made in the editor, All Notes' filters and Delete…, the editor's Delete; Add Note to Highlight, which the highlight takes; a footnote's bar with Note alone; and a paste of HTML with its styles, which the page's policy never sees;
  - `notes-keyboard.spec.ts`, by keyboard alone, with caret browsing: Alt+F10 and End to Note, ⌘B, the formatting bar and its Link, ⌘K refusing an address the page cannot follow, Escape discarding an edit from the rail, and All Notes' Delete…;
  - `summaries.spec.ts`: writing, moving between, editing, inserting into a note, removing from it and deleting the reader's own summaries;
  - `notes-export.spec.ts`: the ZIP from Settings ▸ Data.
  Each runs axe at each state, uses colours of 4.5:1 or more, and leaves the store empty. They wait for the editor after it takes focus and after a selection made by keys (`settle` in `e2e/notes.ts`): ProseMirror reads such a selection on `selectionchange`, and puts its own back 20 ms after taking focus, so keys faster than a person's would be lost.
- **Packages,** installed with `--before=2026-10-01`, each published before it: every `@tiptap` package at 3.31.4 (core, pm, react, extension-document, -paragraph, -text, -bold, -italic, -underline, -link, extensions, and the optional bubble and floating menus), 30 September; `prosemirror-model` 1.25.12, `-view` 1.42.6, `-transform` 1.12.2, `-changeset` 2.4.4, `-dropcursor` 1.8.4, `-history` 1.5.1, `-commands` 1.7.2 and the rest of ProseMirror's, from 2023 to 29 September; `@floating-ui` 1.8.0, `fast-equals` 5.4.3, `linkifyjs` 4.3.3, `orderedmap` 2.1.1, `rope-sequence` 1.3.4 and `w3c-keyname` 2.2.8. Nothing else in the lockfile changed.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** CI's swift job, replayed under the app's heavy-job lock at the final tree, built clean, with no warning. All 2,292 tests pass, up from 2,187, with the one named skip and nothing cancelled: FRUSLightCoreTests 96, FRUSLightServerTests 150, FRUSParityTests 153 and FRUSRichTextTests 42; the others as at #59.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 274 tests. The editor is its own chunk of 362 kB, which Browse, Search and the reader load only when a note opens formatted.
- **`scripts/compose-smoke --e2e`** on this branch's image passes: 38 browser tests at the root and 38 under the path, through nginx with INSTALL's recipe.
- **`scripts/make-golden`** on the owner's Mac (macOS 27.0.1, Xcode 27.1) wrote the render files and the expressions byte for byte as before, and the golden spans anew; `check-golden` passes natively.
- **Reviews.** The design was reviewed through four lenses before it was built, 68 of 72 findings upheld; each half was reviewed and fixed as it was built, 24 findings; and the whole branch through six lenses, 33 of 35 upheld, each fixed and checked again. The browser suite found three bugs no review had: the editor reading Tiptap's view before it was mounted, which opened a note plain at random; a selection's own report cancelling Alt+F10, a race from S15c's code that the highlights spec escaped only by its timing; and Escape giving focus back before React had closed the dialog.

**Records**

- `docs/SPEC.md`: the rich-text section, the reader and rail, All Notes, Settings ▸ Data, the HTTP API's notes, summaries and projects, the 4 MiB note limit, the mapping table, the export paths, security, and check 13.
- `docs/PLAN.md`: the row's two sentences corrected, its done paragraph, the Golden spans checkpoint done, and one-line notes on S16c, S16d, S17d, S17f, S18c and S19b.
- `docs/INSTALL.md`: notes, All Notes, the rail's Summary and Notes, Settings ▸ Data, the routes and their codes, and the nginx recipes' `client_max_body_size 4m`, which compose-smoke runs.
- `docs/COORDINATION.md`: the golden spans in section 1 and in a pin move's checklist, and the server's kit calls and standing mirrors.
- `docs/prep/README.md`: the RTF row, now that the JSON export carries rich text.
- `fixtures/rich-text/README.md`; `CLAUDE.md`'s line on `tools/rtf-code-pages`; README's status.
- This log.

**Next: S16c,** the import of a Mac JSON export, which PLAN puts after S15d and which takes a note's RTF through this codec; with S19a, S14e, S14d and S14b beside it. The upstream fix for a collection exported in dark mode, whose typed prose comes out white, is the app's, and the owner's to schedule.

## Session 15c, follow-up: the kit's highlight code, upstream

24 October 2026 · branch `claude/s15c-kit-highlight-followups` · [#60](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/60) · upstream `503a730b`, unchanged; [FRUS-Explorer#1789](https://github.com/joshbotts/FRUS-Explorer/pull/1789), open

S15c (#59) found two things in FRUSCoreKit's highlight code and named both as upstream pull requests. The session that ran it asked for them in one pull request, from `claude/highlight-line-break-and-extracts`, cut from `v2` at `503a730b`, labelled `Mac` with "Mac verification requested", and not merged. Under rule 4 it changes shared files, and this repository changes only its records.

**#1789, in two commits and a records commit:**
- **A highlight that ends on a line break is drawn, with the document's others.**
  - `kHighlightsJS`'s `buildRanges` ended every range with `setEnd(node, localOffset + 1)`. For a highlight whose last character is a `<br>`, the offset engine's `{node: BR, localOffset: 0}`, that was `setEnd(br, 1)`, and WebKit threw `IndexSizeError` after `FRUSHighlights.render` had cleared the page. The app's `renderHighlights(on:)` drops the error, so the app drew none of that document's highlights. A drag that ends at the start of the line after a `<br>` makes one.
  - `buildRanges` now ends such a range after the element (`setEndAfter`), and every other range as before. `ReaderAnnotationScriptTests` re-takes `kHighlightsJS`'s pin, 3,045 bytes to 3,344, with the reason.
  - A new WebKit suite, `HighlightLineBreakRenderTests`, Xcode's alone, makes the highlight from the selection bridge's own payload for such a drag and draws it through the app's `renderHighlights(on:)`, with the document's others. Run against `v2`'s renderer it fails both its tests, the page holding no highlight at all.
  - `FRUSExplorer/Resources/frus-highlights.js`, which nothing loads, is as it was.
- **`HighlightReanchor.extracts(passage:start:end:in:)` is public.** It is the kit's test of whether a span of the flat text reproduces a highlight's stored passage, in either form a highlight stores: `flatTextExcerpt(blocks:start:end:)`'s output, or the raw UTF-16 slice of one made before 3 July. It puts the search's own guard in front of the private test, which the search calls unchanged, so a span outside the text reproduces nothing. Four kit tests.
- `FRUSCoreKitTests` goes from 1,191 tests to 1,196, and the iOS unit target from 7,636 to 7,643.

**How it was checked,** each heavy job under the app's lock, from a clone at a real path, beside `v2` at `503a730b` built and run the same way, Xcode 27.1, clean and unsigned:
- **The full iOS unit run:** 7,643 tests in 907 suites against `v2`'s 7,636 in 906, both failing only the 8 Keychain tests an unsigned build fails, and skipping the same 17 tests and 2 suites. `FRUSOffsetEngineTests`, `TextNodeEndSelectionTests`, `SelectionScriptParityTests` and `HighlightTextRenderTests` passed.
- **`swift test`:** 3,089 tests against 3,084, all passed.
- **The symbol diff,** normalized as before: 249,767 names on `v2` and 249,768 on the branch, none removed, and one added, `HighlightReanchor.extracts(passage:start:end:in:)`. The script's change is inside a string literal.
- **Both builds** had `v2`'s five and seven warning lines, and `swift build --target FRUSCoreKit` completed.
- **Linux,** in a scratch worktree of this repository's `main` at `e067d69`, with the branch copied over the submodule:
  - every target passed but FRUSParityTests, whose 14 issues are all golden-file staleness, S15c's samples test among them;
  - `FRUSCoreKitTests` ran 1,196 tests, with the one named skip and no build warning, 2,192 tests in all;
  - a scratch file in `FRUSLightAPI`, never committed, imported FRUSCoreKit without `@testable` and called `HighlightReanchor.extracts`, and the target built.
- **A review** read the diff cold. It confirmed the end and the pins, and that both WebKit tests fail on the old `buildRanges`. It found a doc line, an assertion message and two missing shifts, all fixed before the runs quoted. It also found one throw that remains, which the pull request files: `buildRanges` has no guard for a negative start, so a highlight stored below 0 throws as the `<br>` end did. Neither reader makes one, and this server refuses offsets outside the text.

**What the pin move past it brings.** The app draws such a highlight, and the kit's renderer no longer throws for one, so:
- the host script's `drawHighlights` (`ReaderHostScript.swift`), which tries each highlight with `buildRanges` before `FRUSHighlights.render`, and the rail's "This highlight could not be drawn in the text." see none from a line break. They can stay, for any other highlight the kit cannot draw, or go;
- check 6's sampler (`Tests/FRUSParity/HighlightSamples.swift`) avoids ends on a line break, and may stop, with `samples.json` written again. Until then the samples are the same: neither change touches the converter or the flat text. It was not regenerated here, since `frus-parity highlight-samples` refuses while the golden files are stale;
- S16c's check 6 on a Mac's highlights can call `HighlightReanchor.extracts` with the page's blocks, and so read a highlight's selected text by the app's own rule in either form.

**Delivered here**

- `COORDINATION.md`: the pull request in §2, and in §5's list of app changes only the web edition needs.
- This log.

**Next: S15d,** notes and summaries, as S15c named it; the owner's Mac check of #1789 and its merge, then the first pin move after it, which takes it, as `PLAN.md`'s rule has it.

## Session 15c: highlights, and check 6

24 October 2026 · branch `claude/phase-2-afce75` · [#59](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/59) · upstream `503a730b`, unchanged

Phase 2's row S15c, on the critical path: S15d, notes, follows it. Highlights come to the reader as the app makes and draws them, with the app's own scripts from the kit, and check 6 runs in CI over the 393 fixture rows. No upstream pull request, and no schema change: S14a's `highlights` table holds it all.

**What the app's code says,** at `503a730b`:

- **A highlight** (`DocumentHighlight`) is a pair of UTF-16 offsets into the document's flat text, a `colorTag`, a `noteId`, the `selectedText` and the `renderingVersion` it was made at, and its `createdAt`. It belongs to no project.
- **Made** (`MacDocumentView.createWebKitHighlight`, iOS's `createHighlight`): the offsets are the selection bridge's last in-document report, `start >= 0 && end > start` (`hasOffsets`); the text is `flatTextExcerpt(from: model, start:, end:) ?? ""`, each paragraph's part joined by a blank line, and the version `ASTToRenderNodeConverter.renderingVersion(for: model)`, both over the reader's own model. The script's `sel.toString()` is never stored. A colour over text another highlight holds makes another: no merge, no dedup. The range goes when the selection clears, for a footnote's selection and after a verb.
- **Drawn** (`renderHighlights`): every highlight of the document, its `@Query` sorted by `createdAt`, as `ReaderHighlight` (`{startOffset, endOffset, color, isStale}`), after every load and every change. Stale is a stored version that is not the page's; a stale one is drawn in `frus-stale`'s amber and answers no tap.
- **Removed:** the kit's click listener reports a tap's `{startOffset, endOffset, color}`, and the app asks "Remove Highlight", "This highlight will be permanently removed.", with Remove and Cancel, then deletes the first highlight with those offsets.
- **Not in the app:** a way to change a highlight's colour (`colorTag` is written only at creation), a way to remove one by keyboard, and a list of a document's highlights outside the review sheet (`DocumentChangeReviewSheet`), whose rows are by `startOffset`, in its words: "Highlights", "Remove…", "Highlighted passage" for one that stored no words, and its two lines for one made against an earlier version of the text.
- **The selection bar** (`FloatingSelectionBar`): the four colours, Excerpt, Look Up in NARA and Note, in `SelectionVerb.allInOrder`, the colours drawn as dots named "Highlight Yellow" and so on; a dark pill 8 points above the selection, kept 8 inside the web view, flipped below when there is no room; a clear waits 200 ms before it hides the bar. The Mac disables the colours and Excerpt in a footnote; iOS leaves them out. The keyboard's way is the Document menu's Highlight Selection, whose Yellow is ⇧⌘H.

**Delivered**

- **The reader's page loads the app's three scripts from the kit,** `kOffsetEngineJS`, `kHighlightsJS` and `kSelectionJS`, byte for byte, as the server's own files: `/reader/frus-offset-engine.js`, `frus-highlights.js` and `frus-selection.js`, deferred, before `host.js`, in the order the app injects them at document end. The page's policy is unchanged: `script-src 'self'` admits them.
- **The host script** (`ReaderHostScript.swift`):
  - draws what the parent sends (`{kind: 'highlights'}`) with the kit's `FRUSHighlights.render`, after trying each with the kit's own `buildRanges`, so one the kit cannot draw does not keep the others from the page, and answers what it drew (`highlightsRendered`);
  - collapses the selection to its end once a colour is chosen (`collapseSelection`);
  - posts ⇧⌘H or Ctrl+Shift+H (`highlightShortcut`) and Alt+F10 (`selectionBarShortcut`), each only over a selection in the text, which the kit's `rangeEndpointToOffset` and `selectionGeometry` place, and Escape over any selection (`selectionEscape`);
  - drops the kit's `highlightTapped` for a click made from the keyboard, whose point the kit's hit test cannot read, and for a click on a reader link, which is followed instead.
- **The store** (`Sources/FRUSLightCore/UserHighlights.swift`, `HighlightStore`): a document's highlights in the reader's order, `created_at ASC NULLS FIRST, upper(id)`; all of a user's; one by id in any case; made as given; recoloured, changing `color_tag` alone; deleted by id.
- **The API** (`Sources/FRUSLightAPI/Highlights.swift`), under the S14c guard:
  - `GET /api/v1/me/volumes/{v}/documents/{d}/highlights`: the document's highlights, with its current `renderingVersion` and each one's `isStale` by `ReaderHighlight.isStale`, both absent when the TEI is not mounted or the document is not in it;
  - `POST` of the same path with `{startOffset, endOffset, colorTag, renderingVersion}`: 201, its text and version the kit's over the page's model; refused for a colour that is not one of the four, offsets outside the text, and `DOCUMENT_CHANGED` (409) when the page's version has moved;
  - `GET /api/v1/me/highlights`, and `GET`, `PATCH {colorTag}` and `DELETE` of `/api/v1/me/highlights/{id}`, `HIGHLIGHT_NOT_FOUND` for an id the user has none for.
  - `JSONBody.decode` now reads `DecodingError.dataCorrupted`, a number that is no `Int`, as `INVALID_FIELD`, where it was a 500.
  - `ReaderService` keeps each document's rendering version with the volume's parse, and builds the model the page and a new highlight share (`ReaderService.model`).
- **The browser app:**
  - `useReaderHighlights` (`web/src/reader/`): the document's highlights drawn on each load of the frame and each change; the selection held only while it lasts; the bar; ⇧⌘H; a tap's question; and the bar put away on a scroll, a press elsewhere, Escape or the rail.
  - `SelectionBar`: the four dots in a toolbar named "Highlight Selection", placed by the Mac's rule inside the frame's content box.
  - `RemoveHighlight`: the app's question, Cancel first.
  - The Research rail's Highlights section, above Tags, where S15d's Notes will come before it: the review sheet's rows and words, each with a Color group of four buttons and Remove….
  - `highlightRules.ts`, the few lines of the app's view code the browser app mirrors, and `Modal`, moved from the tag editor to `web/src/shell/` so the question uses it; it now keeps Escape from the rail around it.
- **Check 6** (`fixtures/highlights/`): `frus-parity highlight-samples` places highlights by offset over each golden row's flat text, along the server's path; FRUSParityTests holds the file to the kit; and `web/e2e/highlights-check6.spec.ts` reads every row back from the reader's page in Chromium.

**Decided here, each the web's own**

- **Recolouring,** which the app cannot do, and which the row's done-when asks for: the Research rail's Highlights section, a Color group of four buttons per row, one `PATCH` of `colorTag` a press, as the app's architecture note on highlights imagines an edit of one. A colour chosen over a highlight's text in the bar makes another highlight, as in the app.
- **Removing by keyboard,** which the app has only for a stale highlight, in its review sheet: each row's Remove…, which asks the app's question. It is also how a stale highlight, which answers no tap, is removed before phase 3's review.
- **The keyboard's way into the bar:** Alt+F10, the key rich-text editors give a toolbar. ⇧⌘H, or Ctrl+Shift+H, is the app's, and makes a yellow highlight at once. Chromium selects text by keyboard only with caret browsing, F7; the browser suite turns it on with `--blink-settings`, keeping the hover and pointer settings Playwright's headless launch passes, since Chromium keeps only the last of that switch.
- **The selection collapses to its end** once a colour is chosen, as the app's iPhone and iPad reader clears it, so the new colour is not hidden under the selection's and a caret stays where it was. The Mac keeps the selection.
- **A click on a reader link inside a highlight** follows the link and does not ask: the app does both, and two modal dialogs cannot open at once. A click made from the keyboard reports no tap, since the kit's hit test would read the point (0, 0).
- **A highlight the kit cannot draw:** the kit's `buildRanges` ends a range with `setEnd(node, offset + 1)`, which throws for a `<br>`, so a highlight that ends on a line break throws in `FRUSHighlights.render`, after it has cleared the page's highlights. The app catches the error and draws none of the document's. The web's host draws the others and the rail names that one ("This highlight could not be drawn in the text."). The fix belongs in the kit: a FRUS-Explorer pull request, which the next pin move brings.
- **`renderingVersion` in a new highlight's request,** refused with `DOCUMENT_CHANGED` when the page's text has changed since it loaded, so offsets never land on other words; after one, the reader lets the selection go and keeps the page's version until the page is loaded again, as the server's sentence asks. The page check is asked again each time the frame loads a page, so its version is the one the frame holds.
- **The rail's place for Highlights,** above Tags, where S15d's Notes will come before it, as the app's rail runs Notes, then Tags. SPEC's list of the rail's sections names it.

**How "kept verbatim" is read.** PLAN's row has `/api/v1/me/highlights` keep offsets, `selectedText` and `renderingVersion` verbatim. The store and every answer keep the three as written. A highlight made on the web takes its text and version from the kit over the page's model, as the app's reader does, and never the browser's `sel.toString()`, which counts skipped text such as a list's labels; an import (S16c) writes the Mac's three as they came.

**Check 6 on the fixtures, and in two steps.** A highlight's selected text is the kit's excerpt of the text between its offsets: within a paragraph that text, across paragraphs each one's part joined by a blank line, and for the Mac's made before 3 July that text itself. So the text the page holds between the offsets cannot equal the selected text across paragraphs, and SPEC's row now says what is compared where:
- in Chromium, `web/e2e/highlights-check6.spec.ts` loads each of the 393 golden rows' pages from the server and checks the rendering version it sends; the kit's offset engine's flat text, by length and SHA-256; each sample's text, read through the engine's map of the live page; the kit's selection bridge reading the kit's own range for each sample back to its offsets; and the kit's renderer drawing one range for each, under its colour's name or the stale one's;
- in Swift, `HighlightSamplesTests` makes `fixtures/highlights/samples.json` again along the server's path and expects it byte for byte, and checks each sample's text against the flat text and its selected text against the kit's `flatTextExcerpt`, which is what the API stores for a highlight there (`HighlightTests`).

The file is 591 KB: 393 rows and 2,498 highlights, 954 of them with a selected text that is not their text. A pin move that changes a row's flat text fails until `frus-parity highlight-samples` writes it again; a row whose text no longer matches is reported and its samples are not read, in both halves. `ReaderRenderer.fullParsePass` and the samples share one converter step (`ReaderRenderer.model`), so the path check 4 holds to the golden rows is the one the samples are placed over.

**Mirrored, with a parity test.** `HighlightViewParityTests` reads the app's source at the pin and `web/src` and holds them together: the verbs and colours to the kit's `SelectionVerb.allInOrder` and `needsDocumentOffsets`; `hasOffsets` in the browser app and in the host script; the bar's gap, margin, side, flip and clamps to `FloatingSelectionBar.anchorCenter`, and its 200 ms wait before a clear; the reader's order (`sort: \DocumentHighlight.createdAt`), which the store gives, and the review sheet's (`startOffset`); the review sheet's stale lines (`HighlightReview.status`); the ⇧⌘H shortcut; and the app's 14 words the web takes, each under its key in the app and the web.

**Tests**

- **FRUSLightCoreTests,** 73 to 78: `UserHighlightTests`, 5. What a highlight keeps, verbatim; the reader's order, a highlight with no time first and two of one time by id in uppercase, an import's lowercase id among them; another colour; a delete by id beside another over the same text; each user's own.
- **FRUSLightServerTests,** 122 to 129:
  - `HighlightTests`, 6: one made as the app's reader makes one, within a paragraph and across two, and another over the same text; the kit's stale rule, and a document the server cannot render; another colour and Remove; each refusal, nothing stored; each user's own; `FRUS_USER_DATA=off` and the routes under a path;
  - `theAppsReaderScriptsAreServedFromTheKit`; and the page, host-script and base-path tests extended, with the classification's test now holding that it reshapes the page but leaves its flat text and version.
- **FRUSParityTests,** 122 to 129: `HighlightSamplesTests`, 2, and `HighlightViewParityTests`, 5.
- **The web unit suite,** 110 to 157 in 20 files: the frame's messages; `highlightRules`; `SelectionBar`; the reader's highlights, from drawing on each load to the shortcuts, the question and the notice; and the rail's Highlights section.
- **The browser suite,** 23 to 30 tests:
  - `highlights.spec.ts`, by pointer: a phrase dragged over, the bar's four colours over the frame, Highlight Yellow, Green in the rail, a reload, and a click on it that asks Remove Highlight, with axe at each state; and a footnote's selection with no bar, and a reader link inside a highlight that opens its card and does not ask;
  - `highlights-keyboard.spec.ts`, by keyboard, with caret browsing: Tab into the text, a selection by Shift+Ctrl+Arrow, Ctrl+Shift+H for yellow, Alt+F10 and the arrows for blue, the rail by Shift+Tab, Pink, a reload, and both removed with Remove…, Escape cancelling the question and leaving the rail open, focus on the next row's Remove… and then the section;
  - `highlights-check6.spec.ts`, check 6, in about 8 seconds a run.
  Each leaves the store with no highlights, since the suite runs twice on one store.
- **`scripts/compose-smoke`:** the page names the four scripts and each is served, at the root, under the path and through nginx; and a highlight is made in the page's version, listed and removed through the guard.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** CI's swift job, replayed under the app's heavy-job lock at the final tree, over `main` at `98ef803`. This package's own targets built clean with no warning. All 2,187 tests pass, up from 2,168, with the one named skip and nothing cancelled:
  - FRUSLightCoreTests 78, FRUSLightServerTests 129 and FRUSParityTests 129;
  - the others as at #58: FRUSCoreKitTests 1,191, SourceNoteKitTests 321, FTS5StoreTests 219, ManifestGeneratorTests 60, SemanticVectorsKitTests 40, CrossRefKitTests 10, GeneratorKitTests 7 and FTS5CheckTests 3.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 157 tests in 20 files.
- **`scripts/compose-smoke --e2e`** on this branch's image passes:
  - the four scripts and the highlight's round through the guard;
  - 30 browser tests on Chromium at the root, and 30 under the path through nginx's recipe, with no axe violations;
  - in each run, check 6 over the 393 rows and their 2,498 highlights, in about 8 seconds: frus1894Nicaragua's 139 rows and 973 highlights, frus1961-63v06's 123 and 740, and frus1969-76ve09p1's 131 and 785.

**Records**

- `SPEC.md`: Reader rendering's scripts and host; the resources table's reader assets; the selection bar, highlights and the rail's Highlights section; Highlights, how one is made and what stale is; the route table; the user's data, Highlights; and check 6's row, in two steps.
- `PLAN.md`: S15c done, in a paragraph after S16b's, with check 6's two steps.
- `INSTALL.md`: highlights in the reader and the rail, by keyboard with caret browsing; the API's routes and its two new codes; and the lines on the store, its address and its backups.
- `COORDINATION.md` §1: what the server and the browser app now take from the kit, and what they mirror.
- `fixtures/highlights/README.md`; the README's Status; `web/src/copy.ts`'s account of the app's words; and this log.

**Notes**

- **Reviews.** Before code, the design was read against the app by three readers, for parity, for the browser and for the server, who between them found 31 things; every one changed the design, among them ⇧⌘H making yellow at once, the offsets held only while the selection lasts, check 6 in two steps, the review sheet's words and order for the rail, and the keyboard test in its own worker. After it, the unit tests' author found four bugs, each pinned and then fixed: a reload of the same page drew nothing; a text size changed and back before the other page came drew nothing; after one Alt+F10, every bar took focus; and after `DOCUMENT_CHANGED` a retry filed the old text's offsets under the new version. A last review in four dimensions, each finding put to a skeptic, upheld 16 of 23, all fixed here, among them focus lost from a button disabled under it, Cancel live while a removal was sent, a highlight removed in another tab, Alt+F10 in the app placing the bar from a rectangle the frame had scrolled past, and records that credited the app with a tie-break and a keyboard removal it lacks.
- **What Chromium showed:**
  - the paragraph's "Kennedy" in d1 is an unresolved name, `<a href="#">`, not a reader link, so a click on it inside a highlight is a tap and asks; the heading's names are the reader links;
  - Chromium cannot start a selection by keyboard in a page without caret browsing, and a click made from the keyboard has the point (0, 0);
  - the whole of check 6 over 393 rows, at the root and under the path, finds the page's flat text the kit's on every row: the HTML5 parser's restructuring of a `<p>` inside a `<p>` (22 rows) moves no text.
- **Not done here:** the shared copy of `PLAN.md` that the phase-2 planning session keeps.

**Next: S15d,** notes and summaries, which follows this row, its RTF codec held to golden spans that `tools/mac-golden` gains there and the owner makes on a Mac; beside it S19a, Citation Lookup, and S14e, S14d and S14b on the server's track. Two upstream pull requests would serve this row's follow-ups: the kit's `buildRanges` ending a range after a `<br>`, and the kit's test of a passage against a highlight's offsets in either of its two forms (`HighlightReanchor`'s private `extracts`) made public, for check 6 on the Mac's highlights in S16c.

## Session 16b, follow-up: a draft that waits for its export passes its checks

24 October 2026 · branch `claude/pending-results-wait` · [#58](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/58) · upstream `503a730b`, unchanged

S16b found it (#57, its Notes), and the session that ran S16b asked for the fix in a pull request of its own, which touches none of #57's files but this log. #57 merged while this one waited for its CI, so `main` was merged in, with #57's pin, `503a730b`, and its golden files, and the tests were run again there.

**What was wrong**

- COORDINATION §5 has a pin move whose export is late remove `index-summary.json` and `queries.results.json`, list them in `fixtures/golden/PENDING`, and stay a draft until the export comes. Check 2's and check 3's own tests then print that they wait. The path last ran at S6's pin move, `144d251`, on 5 October.
- Two tests written since read the results file without asking whether it waits:
  - S8c's `ServedAPIParityTests.checkThreePassesThroughTheAPI` recorded an issue when `GoldenValidation.load` found it pending, and returned before its other checks;
  - S13b's `SearchTimingTests` read it with `GoldenJSON.read`, and threw "The file doesn't exist".
- So a draft's CI would have been red with nothing wrong but the wait.

**The fix**

- Each test now reads the file with `GoldenValidation.load`, as `SearchRunTests` and `IndexParityTests` do, and when it is pending prints "queries.results.json is pending: it waits for …" with `PENDING`'s reason.
- Each checks first what needs no export, and compares with the golden file only when it is there:
  - check 3 through the API still checks the import, the live index left as it was, the records `LiveAPI` reads, the records against those the kit gives in process, the expressions over HTTP and the 43 refusals; with the file, it compares the records with the golden results and prints its line, as before;
  - the timing test still checks that the golden expressions name its 45 exact-word queries, times each one, and checks that none is refused; with the file, each count is the golden file's, as before.
- With the file present, the checks, their messages and what the tests print are as they were; only the comparison with the golden results now comes last in each test.
- Nothing is skipped: no `.disabled` and no `Test.cancel`.

**Results**

First at `2767a128`, over `main` at `c19524b`:

- **With both files pending,** listed in `PENDING` as `144d251` listed them, `scripts/swift test --filter FRUSParityTests`, under the app's `Scripts/heavy.sh` lock:
  - before the fix, 122 tests ran and the two failed, on "queries.results.json is pending" and on "The file doesn't exist";
  - with it, all 122 pass, and seven tests print that a file waits: `GoldenTests` for both, `IndexParityTests` for the summary, and `SearchRunTests`, `SearchParityTests`, check 3 through the API and the timing test for the results.
- **With both files present,** CI's swift job replayed in `swift:6.4-noble` on arm64, this package's own targets built clean with no warning:
  - no target calls `Test.cancel`, and all 2,127 tests pass with the one named skip;
  - each target runs what `main`'s CI ran: FRUSCoreKitTests 1,150, SourceNoteKitTests 321, FTS5StoreTests 219, FRUSParityTests 122, FRUSLightServerTests 122, FRUSLightCoreTests 73, ManifestGeneratorTests 60, SemanticVectorsKitTests 40, CrossRefKitTests 10, GeneratorKitTests 7 and FTS5CheckTests 3;
  - the checks print as before, and nothing prints that it waits: "check 2 passes: 36 digests and 7 checks are the Mac's"; "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups"; through the API, "482 queries, 482 identical and 0 reordered only within Mac tie groups, every record the kit's own; 482 compiled as the golden file says, 43 refused; the live index unchanged"; and "check 4 through the page: 393 of 393 rows identical".

Then at `503a730b`, with `main` merged in at `70eec63`, and #57's golden files:

- **With both files pending,** listed with the new pin in their reason, all 122 parity tests pass, and the same seven print that a file waits.
- **With both files present,** CI's swift job replayed the same way, with no warning: all 2,168 tests pass with the one named skip, and each target runs what #57's CI ran, FRUSCoreKitTests 1,191 and the others as above. Checks 2–4 print as before, and nothing prints that it waits.

**Notes**

- **COORDINATION §5 is unchanged:** its wording holds again.
- **CI tests only what is committed,** so it never takes the pending path. A pin move that will wait for its export can try it first: remove the two files, list them in `PENDING`, run `scripts/swift test --filter FRUSParityTests`, and restore them with `git checkout`.
- **Scratch:** the runs' scripts and logs are under `.build/linux/pending/` in the worktree `frus-explorer-readiness-e33c42`, the first round's in `at-c19524b/`.

**Next: S15c,** highlights and check 6, now that #57's pin move is in; beside it S19a, Citation Lookup, which that move also unblocks, and S14e, S14d and S14b on the server's track.

## Session 16b: pin move past FRUS-Explorer#1786, #1788 and #1787, which is S15b's too

24 October 2026 · branch `claude/s16b-pin-503a730b` · upstream `503a730b`

Phase 2's row S16b, and with it S15b. The pin moves from `2767a128` to `503a730b`, `v2`'s head, past three of the owner's merges:
- [FRUS-Explorer#1786](https://github.com/joshbotts/FRUS-Explorer/pull/1786) (S16a), the Mac's JSON export in the kit at format version 7, merged on the evening of 23 October as `02521d01`;
- [#1788](https://github.com/joshbotts/FRUS-Explorer/pull/1788) and [#1787](https://github.com/joshbotts/FRUS-Explorer/pull/1787) (S15a), the reader's annotation scripts and Citation Lookup's Batch and Structured Entry types, merged this morning as `9ae72e7e` and `503a730b`.

The session was briefed to move the pin to `02521d01` alone, which it did first. S15a's two merged while it waited for the owner's export, and `PLAN.md` has the first pin move after a phase-2 upstream merge take it, whichever row that is. So, by the owner's choice, this move goes to `503a730b` and is S15b's as well: one move and one set of golden files where there would have been two. S15c, S15d, S16c and S19a build on it. It is a pull request of its own under rule 5.

**What the move brought**

- **Three commits, each a squash with its branch head's tree:** `02521d01` is #1786's `aac1aefa`, and `9ae72e7e` is #1788's `edfbc73a`. #1787's branch had `v2` at `9ae72e7e` merged into it after #1788 landed, keeping both pull requests' records, so `503a730b` is the tree of its last head, `b3b272c6`, and not of `3b040885`, the head S15a's entry names.
- **In shared code:**
  - #1786: `FRUSCoreKit/Export/`, a new folder, with `ResearchDataEnvelope.swift`, `ResearchNoteMarkdownExport.swift` and `ResearchDatabaseStrip.swift`; and `SummaryTypes.swift` and `ArchiveVisitValues.swift` in `FRUSCoreKit/Models/`, the five types the envelope's records name, moved out of the app's model files unchanged but public;
  - #1788: `TEI/ReaderAnnotationScripts.swift`, with the reader's three scripts byte for byte; `ReaderHighlight` and a public `HighlightColor` in `TEI/HighlightColor.swift`; and `DocumentView/SelectionVerb.swift` and `DocumentView/HighlightReanchorSearch.swift`;
  - #1787: `CitationLookupFields`, `CitationBlockSplitter` and the Batch types public in `FRUSCoreKit/Citation/`, with three initialisers spelled out.
- **In the kit's tests:** `ResearchDataEnvelopeTests.swift`, three suites and 11 tests, with `ResearchDataFixtures.swift`, a file of each format version 1 to 7; `ReaderAnnotationTests.swift`, new; and `HighlightReanchorTests.swift`, moved into the kit's folder with its three app-only tests behind `#if !SWIFT_PACKAGE`. FRUSCoreKitTests runs 1,191, from 1,150: 1,161 after #1786, as S16a found, and 30 more from #1788.
- The rest is the app's: its exporter and reader code, now calling the kit, the model files the types left, its tests, manuals, editable content and records.
- **No repair.** The package builds with no warning, every kit suite passes, and the only skip is the named one. `Package.swift` compiles `FRUSCoreKit/` and `FRUSExplorerTests/FRUSCoreKit/` by folder, so the new folder and files needed no change. These are unchanged:
  - the build (1.0, 1776), so `scripts/release-tag` still says `1.0-1776`;
  - the index version (71) and the FTS generation (4), so `Compatibility.swift` and the install guide's versions stand;
  - the export's schema: `setupDatabase(_:)` is the same text at the same lines, 7759–8414, and the watch finds the same 47 `CREATE TABLE` and `ALTER TABLE` statements;
  - `IndexingResources.indexResourceNames`, the bundled resources, the app's source folders in `project.yml`, and CI's allow-list.

**Nothing the indexer runs changed.** `git diff 2767a128 503a730b` over COORDINATION §5's indexing path is empty for `FRUSCoreKit/Search`, FTS5Store, SourceNoteKit, `FRUSExplorer/Resources` and `project.yml`. In the parser's folder, `FRUSCoreKit/TEI`, only two files change: `HighlightColor` turns public and gains `ReaderHighlight` beside it, and `ReaderAnnotationScripts.swift` holds the scripts as strings; the serializer that paints a highlight's colour is unchanged. The one change to how an export is written is #1786's strip. It nulls the writing, drops the tag names, vacuums and rebuilds both FTS tables when Include My Notes, Summaries, and Tags is off, and its five statements moved into `ResearchDatabaseStrip.steps` with the same text, in the same order and under the same step names. `IndexDatabaseExporter.strip(_:)` now runs them in a loop. So the 1776 export would have served, as it did for S12e's and S13c's moves, but the owner made a new one from a build of `503a730b`.

**The daily watch reads the export's number from the kit.** `scripts/upstream-watch` took the first `static let currentFormatVersion = <number>` under `FRUSExplorer/Export`. Since #1786 the number is in `FRUSCoreKit/Export/ResearchDataEnvelope.swift`, and the app's line names it (`= ResearchDataEnvelope.currentFormatVersion`). So `constant_at` now takes several paths, and the export's row reads both folders, the kit's first:
- it gives 6 at `2767a128`, 7 at `02521d01` and `503a730b`, and 6 at `c6f7b2cb`;
- the row is named for `ResearchDataEnvelope.currentFormatVersion`;
- `scripts/upstream-watch report 503a730b` printed "6 | **7**", and `selftest` passes.

**The golden files**

Remade by `scripts/make-golden --export /Users/Shared/frus-index-2026-10-24.sqlite` under the app's `Scripts/heavy.sh` lock. The owner made the export that morning from a build of `503a730b`, with My Notes, Summaries, and Tags left out: 1.0 (1776), index version 71, FTS generation 4, and 393 documents in the three fixture volumes.
- **Only provenance changed** in the 393 rows' HTML, which is byte for byte as before, and in the render's manifest, the expressions and the results: `sourceDigest` (`d99bca0de69c` to `1c529af84686`), `upstreamCommit` and, for the results, the export's time. Every query's count, first 50 results and tie tail are as the 1776 export gave them.
- **The index summary's gating section,** its 36 digests, 7 checks and volumes, is unchanged. Beside its provenance, its information section moved only where an export's history and this run move it:
  - the volumes were indexed in the order COORDINATION §5 recommends, Nicaragua, then v06, then ve09p1, where the 1776 export had ve09p1 second;
  - `volume_structures`' raw bytes hash differently. Each volume's structure is the same JSON with its keys in another order, as the app's encoder leaves them, and the gating digest reads it through `json_tree`;
  - the AUTOINCREMENT sequences of three tables, which the golden library carries from every erase, the freelist, and the timings.
- `frus-parity check-golden` passes.
- At `02521d01`, before the export came, `make-golden` without one gave the same HTML and expressions, with that pin's digest, `08cc27581ac7`.

**Records**

- `PLAN.md`: S12d's row (from `503a730b`), the golden-files checkpoint, the risk row's counts, and a paragraph on the three merges and this move after S14c's.
- `SPEC.md`: the compatibility contract, and `setupDatabase(_:)`'s lines.
- `COORDINATION.md`:
  - the pin, and §1's use of the kit;
  - §2's paragraph on #1787 and #1788, now merged, with this move after it;
  - §5's watch line, naming the export's number where it now is, and its list of app changes;
  - §6's exports.
- `docs/prep/README.md`: the pin, and a line saying the phase-2 claims on the moved code describe it before the moves.
- The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Build and Test steps, this package's own targets built clean with no warning, over `main` at `c19524b`, with S14c and S15a's records: all 2,168 tests pass, up from 2,127, with the one named skip.
  - FRUSCoreKitTests runs 1,191, from 1,150. The other targets are unchanged: SourceNoteKitTests 321, FTS5StoreTests 219, FRUSParityTests 122, FRUSLightServerTests 122, FRUSLightCoreTests 73, ManifestGeneratorTests 60, SemanticVectorsKitTests 40, CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
  - S14a's `UserStoreParityTests`, which read the app's `@Model` classes, pass. #1786 moves value types out of three model files, and #1788 makes `DocumentHighlight.HighlightDTO` a typealias for the kit's `ReaderHighlight`; neither moves a stored property.
- **Against the remade golden files** the run printed:
  - "check 2 passes: 36 digests and 7 checks are the Mac's";
  - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups; 318 with other score bits (information)", and through the API "482 queries, 482 identical and 0 reordered only within Mac tie groups, every record the kit's own";
  - "check 4 through the page: 393 of 393 rows identical", and the same on the reader's path and from one full parse per volume.
- **At `02521d01` first,** over `main` at `c028783`, the same steps built with no warning and ran 2,121 tests, FRUSCoreKitTests 1,161 and the one named skip. The only failures were the parity suites' 13 issues of golden-file staleness. S15a's own Linux runs found the same for #1788 and #1787.
- **The image and the browser suite** are CI's compose job's, which builds this branch's image and runs `scripts/compose-smoke --e2e` at the root and under a path. The server links none of the new kit code yet.

**Notes**

- **A draft that waits for an export no longer passes CI.** COORDINATION §5 has a pin move list the two export-made files in `fixtures/golden/PENDING` and stay a draft until the export arrives, as S6's did. At `02521d01`, with both files pending, `scripts/swift` ran CI's Test step and two parity tests failed on the missing results file, while check 2's and check 3's own tests waited as they should:
  - `SearchTimingTests` (S13b) reads `queries.results.json` without asking `GoldenValidation` whether it is pending;
  - `ServedAPIParityTests.checkThreePassesThroughTheAPI` records an issue when it finds the file pending.

  The export came the same morning, so nothing here pushed a pending file, but the next pin move that waits for an export would show a red CI on its draft.
- **`make-golden` reads the pin from the index,** not from the submodule's checkout, so its first run stopped with "the pin is 2767a12" until the submodule move was staged.
- **Builds in a new worktree:** the Linux build reused S16a's scratch build through an APFS clone (`cp -c`), and built this package's own targets clean in under 70 seconds.
- **Not updated:** the shared copy of `PLAN.md`, as S14g and S14c left it.
- **Mac checks 9 and 10** are still "To do" in `PLAN.md`. The owner merged #1786, #1788 and #1787; their checks, an export of every type decoded again (10) and the two pull requests' builds and runs (9), are the owner's to record.

**Next: S15c,** highlights and check 6, now that S14c and this move are in; beside it S19a, Citation Lookup, which this move also unblocks, and S14e, S14d and S14b on the server's track.

## Session 14c: the write path, and tags

23 and 24 October 2026 · branch `claude/s14c-tags-and-write-guards` · [#54](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/54) · upstream `2767a128`, unchanged

Phase 2's row S14c, on the critical path: S14d, S14e and S15c follow it. The server writes the user store for the first time. Every request under `/api/v1/me` acts for a user the server resolves, behind a guard a server with no sign-in needs, and the first resources are the user's tags and a document's tags, kept by the app's rules. The browser app gains the reader's Research rail, with its Tags section and the app's tag picker, and Settings ▸ Tags. No upstream pull request, and no schema change: S14a's `tags` and `tag_assignments` hold it all.

**What the app's code says,** at `2767a128`:

- **A name** is trimmed of white space and new lines, and one with nothing left is refused: the picker's `createTag()` and the editor's `commit()` and `saveDisabled` (`UserTagPickerSheet.swift`, `TagEditorView.swift`). Two tags may share a name. Settings' New Tag… makes one named "New Tag" and opens it in the editor, without Merge and Delete.
- **Delete** is `UserTagAdmin.deleteCascading`: the id leaves every `ResearchNote.userTagIds` and every `Project.defaultUserTagIds`, and every `DocumentTagAssignment` of the tag goes, then the tag.
- **Merge** is `UserTagAdmin.merge`: each note and project drops the source and gains the target once, after the ids it keeps; each assignment of the source is re-pointed at the target; then the source goes. A document that carried both is left with two assignments of the target, which `assign`, `reindexTagColumn` and `tagColumnPlan` all read as a set.
- **`lastModified`.** The models' `didSet` observers never fire (`Project.swift` says so); `ModelModificationStamper` stamps every changed `ResearchNote`, `Project` and `UserTag` at save. So a note or project whose ids change is modified then, and a rename moves the tag's, while a merge leaves the surviving tag's alone.
- **A document's tags.** The picker's Done in its document mode replaces the document's whole set: it deletes every assignment of the document and inserts one per tag switched on (`syncAssignmentsToSwiftData`). Its Cancel deletes the tags made in the sheet. The Research rail's × deletes every assignment of that tag on the document (`removeUserTag`), and its Tags accordion is closed by default and remembered (`@AppStorage("frus.document.researchPanel.tags")`), with the count of applied tags as its badge. An assignment of a tag that no longer exists names nothing (`appliedUserTags`).
- **Order.** The app lists tags by name (`@Query(sort: \UserTag.name)`) under the reader's own order from `SyncedPreferences` (#1275), which S17f brings.
- **The tally** beside each Settings row, "12 notes · 3 documents" (`ResearchItemCounts`), is app code that S17b moves into the kit, so it waits for that move.

**Delivered**

- **The user a request acts for** (`Sources/FRUSLightAPI/UserData.swift`). A `UserResolver` resolves it once per request under `/api/v1/me`, into the request's context, and every route reads it there. Under `FRUS_AUTH=none` it is `SingleUserResolver`: the store's `owner`, who holds the three roles. S14e's proxy sign-in and phase 3's accounts are other resolvers, and nothing else changes for them.
- **The guard,** `UserDataGuard`, on the `/api/v1/me` route group:
  - **Host.** The request's `Host` names `FRUS_PUBLIC_URL`'s address. `PublicAddress`, in `Configuration.swift`, reads that address and a request's `Host` and `Origin` itself: IPv6 in brackets, an optional port, and no user name. The port may be left out of `Host`, since nginx's `$host` leaves it out. `localhost`, `127.0.0.1` and `::1` at the same port are one address. Reads are checked too, since a page under a name an attacker pointed at the server could read a user's data. The corpus's routes answer any host.
  - **A change,** anything but GET, HEAD and OPTIONS, also needs:
    - an `Origin` that is that address;
    - the user's token in `X-CSRF-Token`, which `GET /api/v1/me` gives. `CSRFTokens` makes it per user, keeps it while the process runs, and compares it in constant time;
    - a body, when there is one, declared `application/json`, of 64 KiB at most, by its length or as it is read;
    - only the fields its route takes, as a query string may hold only its parameters.
  - **Each refusal is a problem with its own code:** `HOST_NOT_ALLOWED`, `ORIGIN_NOT_ALLOWED`, `CSRF_TOKEN_INVALID`, `UNSUPPORTED_MEDIA_TYPE`, `CONTENT_TOO_LARGE`, `INVALID_BODY`, `UNKNOWN_FIELD` and `INVALID_FIELD`.
  - **`FRUS_USER_DATA=off`,** read by `ServerConfiguration`, refuses everything under `/me` but `/me` itself as `USER_DATA_OFF`, reads included, and `/me` says `userData: false`.
  - `POST /search/inspect` takes a search's form body and changes nothing, so it is outside the group.
- **`GET /api/v1/me`:** the user, `auth`, roles, `userData` and the token, never cached.
- **The tag store,** `TagStore`, which `SQLiteUserStore` implements in `Sources/FRUSLightCore/UserTags.swift`. Each change is one `BEGIN IMMEDIATE` transaction through `writing`, and every read goes through `reading`, both holding the store's `access` lock.
  - **Names** are trimmed of white space and new lines, and refused when nothing is left. A rename to the same name changes nothing, and any other moves `lastModified`.
  - **Delete** strips the id from notes' `user_tag_ids` and projects' `default_user_tag_ids`, stamping each changed row's `last_modified`, and deletes the tag's assignments.
  - **Merge** re-points notes and projects, the target after the ids they keep and once, and re-points the source's assignments. A document that carried both keeps the target's own assignment, so there is one per document and tag. The surviving tag is left as it was.
  - **A document's tags are set as the picker's Done sets them:** one assignment per tag, and a tag the document keeps keeps its oldest assignment, so its id and time survive. Every other assignment of the document goes, a duplicate or a dangling one included. An unknown tag refuses the whole set. The rail's × removes every assignment of one tag on one document.
  - **Ids** are compared as uppercase `uuidString`s, whatever case a request or an import wrote. **Order** is the app's query's: Foundation's localized standard comparison, the default of `SortDescriptor` for a string, then id.
  - `TagReferences` holds the app's two rewrites of an id list, apart from the SQL, for S14d's PostgreSQL store.
  - `UserStore` gains `user(_:)`, and `SQLiteUserStore` its `reading` and `writing` helpers.
- **The routes** (`Tags.swift`):
  - `GET` and `POST /api/v1/me/tags`;
  - `GET`, `PATCH` and `DELETE /api/v1/me/tags/{id}`;
  - `POST /api/v1/me/tags/{id}/merge`;
  - `GET` and `PUT /api/v1/me/volumes/{v}/documents/{d}/tags`, and `DELETE` of one tag there.

  A document's volume must be the catalogue's. The document is named and not looked up, since the Mac's assignments can name one the server does not hold.
- **The browser app:**
  - **The reader's toolbar opens Cite or Research**, one at a time, as `rail=cite` or `rail=research`. Research is offered only when `/me` says the server keeps user data.
  - **The Research rail** (`web/src/research/ResearchRail.tsx`) has its Tags section, closed until opened and then as left, kept in this browser as the app's `@AppStorage` keeps it. Its header counts the document's tags. Each chip's × takes its tag off, and Add Tag opens the picker.
  - **The tag picker** (`TagPicker.tsx`), a modal dialog, works as the app's document-mode sheet does:
    - New Tag makes a tag, switches it on and lists it first with a New badge, and focus goes to it, as the app moves VoiceOver;
    - Done gives the document exactly the tags switched on;
    - Cancel, or Escape, deletes the tags made in it, waiting for one still being made.
  - **Settings ▸ Tags** (`web/src/settings/TagsSettings.tsx`, `TagEditor.tsx`), at `/settings/tags`, which `/settings` opens, with Settings in the header:
    - a row for each tag, which opens Edit Tag: the name, Merge into Another Tag… and Delete Tag, with the app's footers;
    - Delete Tag's confirmation, a dialog beside the editor rather than in it;
    - Merge Tag, with the app's sentence;
    - New Tag…, which makes "New Tag" and opens it with nothing to merge or delete.
  - **`api/userData.ts`** sends every change with the token, and asks for a new one when the server no longer knows it, as after a restart. It refreshes what the change touched.
  - **Development.** The development server's proxy presents its own pages' changes as the server's own, by host and origin, and leaves any other page's origin for the server to refuse.
- **Tests:**
  - **FRUSLightCoreTests**, 63 to 73:
    - `UserTagTests`, 8: trimmed names; the order and each user's own tags; renames; delete and merge against notes, projects and assignments written beside the store; the picker's set with duplicates and dangling assignments; the rail's ×; and the id lists' rewrites.
    - `ConfigurationTests`, 2 more: `FRUS_USER_DATA`, and `PublicAddress` over hosts, origins, IPv6 and proxies' spellings.
  - **FRUSLightServerTests**, 115 to 122: `UserDataTests`, 7:
    - `/me`;
    - the tags' whole round through the API, with a note and a project beside them;
    - refusals of the token, the origin and the host, the corpus answering any host;
    - bodies' types, sizes and fields;
    - each not-found;
    - `FRUS_USER_DATA=off`;
    - and the routes under a path.
  - **The web unit suite,** 92 to 109: the rail, the picker, its Cancel and the token's renewal; Settings ▸ Tags' list, rename, delete, merge and New Tag…; and the review's cases.
  - **The browser suite,** `web/e2e/tags.spec.ts`: the done-when, by keyboard, with axe at each step. It tabs to Research, opens Tags, adds a tag in the picker and Done, closes the rail with Escape, reaches Settings with Shift+Tab, opens the tag's editor, deletes it after the confirmation, and finds the document without it.
  - **`scripts/compose-smoke`:** it now names the address the browser suite opens as `FRUS_PUBLIC_URL`, and checks the guard in the image: refused without the token, from another origin and to another host, then a tag made, trimmed, and deleted.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** each run under the app's heavy-job lock:
  - At the reviewed commit, every target passed: 2,127 tests, from 2,110, with only the named skip. FRUSLightCoreTests ran 73 and FRUSLightServerTests 122.
  - After the review's fixes, those two targets passed again, at the same counts.
- **The web job's steps,** through `scripts/npm`: typecheck, lint and the build are clean, and the unit suite passes 109 tests in 18 files.
- **`scripts/compose-smoke --e2e`** on this branch's image passes:
  - the write guard's checks, in the image;
  - 23 browser tests on Chromium at the root, from 22, and 23 under the path through nginx's recipe, with no axe violations. The new test runs in both, so the guard holds behind the proxy, whose `$host` drops the port.

**Records**

- `SPEC.md`:
  - a new section, The user's data, under the HTTP API: the user, the guard, `/me`, and each tag route by the app's rule;
  - Tenancy's one step;
  - Shell's `/settings/{pane}`;
  - the Research rail and its Tags section;
  - Settings ▸ Tags, and what waits for S17b and S17f;
  - the configuration rows for `FRUS_PUBLIC_URL` and `FRUS_USER_DATA`;
  - Security.
- `INSTALL.md`:
  - step 6 is now "Browse, search, read, cite and tag", with Research and Settings;
  - the API's tags, with the token, by curl, and the guard's refusals;
  - `down --volumes` takes the tags too;
  - behind a proxy, others can read and change the tags until sign-in, `FRUS_USER_DATA=off` makes a read-only server, and the recipes' `Host` is checked;
  - the settings rows;
  - backups of the tags come later in phase 2.
- `compose.yaml` passes `FRUS_USER_DATA`.
- `PLAN.md`: S14c done, in a paragraph after S14a's. The shared copy kept by the phase-2 planning session was not updated here.
- The README's Status, `web/src/copy.ts`'s account of the app's words, and this log.

**Notes**

- **A review before the push.** One reader took the commit cold, against the app's code and SPEC, and found ten things. Nine are fixed here:
  - the picker's Done could take tags off a document while the list of tags was still loading, or when the list was read before a tag was made in another tab;
  - Cancel during a New Tag still being made left that tag behind;
  - Settings' New Tag… made two tags on a double press;
  - the confirmation, nested in the editor's dialog, handed its Escape up to the editor, and gave focus to an element still inert;
  - the 413 for a body sent in chunks lost the server's sentence;
  - the development proxy rewrote any page's `Origin`, not only its own pages';
  - the smoke test's host check would pass on a host port of 8080;
  - the tag order was ASCII's, not the app's;
  - INSTALL named the host check for changes only.

  The tenth, the missing log entry, is this entry.
- **Three things Chromium showed that jsdom could not:**
  - the disclosure's `▸`, drawn by CSS, was read into the Tags button's name, as "▸ Tags". The mark is now a span hidden from assistive technology;
  - the badge's hidden words are padded by a browser's name computation, so the button is now named outright;
  - the synthetic export gives d1 no printed number, so the picker is "Tags — d1", the app's own fallback, and the test now expects that.
- **The header's links keep focus after they navigate,** as Browse's and Search's do, so Settings' heading does not take it. The browser test tabs on from the link.
- **Foundation's localized standard comparison on Linux** puts "berlin" before "Berlin", and "Tag 9" before "Tag 10". That is the comparison the app's sort makes, so the test holds the store to what it gives, rather than to a guess.
- **Deliberately not as the app:**
  - the picker's Done keeps a kept tag's assignment, where the app deletes and re-makes every one, so an assignment keeps its id and time through an export;
  - a merge keeps one assignment per document and tag, where the app keeps two;
  - every tag change is one transaction.
- **S14a's log missed a line,** given here: with `main` merged (S14f, S14g), all 2,110 tests passed, with only the named skip, FRUSLightCoreTests at 63 and FRUSLightServerTests at 115. It is commit `08ed770` on `claude/phase-2-start-676787`, pushed after #52 merged.

**Not done here:** the shared copy of `PLAN.md` that the phase-2 planning session keeps, which this session cannot reach.

**Next: S14e,** sign-in through a trusted proxy, and S14d, the PostgreSQL store, which both follow this row and can run beside each other; S15c, highlights, once S15b's pin move lands; and S14b, the daily backup, if it has not merged.

## Session 15a: the reader's annotation scripts and Citation Lookup's types, upstream

24 October 2026 · branch `claude/suspicious-noether-435ab4` · upstream `2767a128`, unchanged; [FRUS-Explorer#1788](https://github.com/joshbotts/FRUS-Explorer/pull/1788) and [FRUS-Explorer#1787](https://github.com/joshbotts/FRUS-Explorer/pull/1787), open

Phase 2's row S15a, whose two pull requests Mac check 9 verifies. S15c draws highlights in the reader with the app's own scripts and rules, and S19a runs Citation Lookup's Batch and Structured Entry with the kit's types, so both need code the kit did not offer. This session opened two pull requests on `FRUS-Explorer`, each from a `claude/…` branch cut from `v2` at `02521d01`, each labelled `Mac` with "Mac verification requested", and neither merged. Under rule 4 they change shared files, and this repository changes only its records.

**#1788 moves the reader's annotation code into FRUSCoreKit, public and otherwise unchanged** (`claude/reader-annotation-scripts-kit`, `edfbc73a`):
- **The three scripts,** `kOffsetEngineJS`, `kHighlightsJS` and `kSelectionJS`, byte for byte from the app's WebKit file into `FRUSCoreKit/TEI/ReaderAnnotationScripts.swift`; two were `private`. The app injects them as before.
- **`ReaderHighlight`,** the JSON `FRUSHighlights.render` reads, which was `DocumentHighlight.HighlightDTO`, with its stale rule as `isStale(renderingVersion:currentVersion:)` and an initialiser that takes a highlight's values, so the server builds one from its rows. The app's name is a typealias, and `HighlightColor` is public.
- **`SelectionVerb`,** with `allInOrder` and `needsDocumentOffsets`, the rule that keeps the colours and Excerpt off a footnote, in `FRUSCoreKit/DocumentView/SelectionVerb.swift`. Its names and symbols stay in the app.
- **`HighlightReanchor`,** the re-anchor's search, pure over a page's blocks, with `locate(passage:storedStart:storedEnd:in:)`, `Match`, `Search` and `Refusal`, for phase 3's review. The file is `HighlightReanchorSearch.swift`, since the app keeps its `HighlightReanchor.swift`. `HighlightReview` keeps its names as typealiases and a forwarder, and `move`, which writes a `DocumentHighlight`, stays in the app.
- **Tests:**
  - `HighlightReanchorTests` moved into the kit's suites, its three app-only tests behind `#if !SWIFT_PACKAGE`.
  - `ReaderAnnotationTests` is new. It pins each script by SHA-256 and UTF-8 length, as `ReaderPageTests` pins the page's head. It also checks the three handlers the scripts post to, the four JSON fields `kHighlightsJS` reads, the stale rule, and the verbs' order and footnote rule.
  - `FRUSCoreKitTests` goes from 1,161 tests to 1,191, and the iOS unit target from 7,623 to 7,636.

**#1787 makes Citation Lookup's Batch and Structured Entry types public** (`claude/citation-lookup-batch-public`, `3b040885`):
- `CitationLookupFields`, `CitationBlockSplitter` with its `Entry`, `BatchCitationOutcome`, `BatchCitationRow`, `BatchCitationRunner` and `ConfidenceLabels`, which #1574 left internal.
- Three initialisers are spelled out, since a public struct's synthesized ones stay internal. `CitationLookupFields`' keeps every default, so `CitationLookupFields()` is still the empty form.
- `ConfidenceLabels.cited(_:)` stays internal: it takes the engine's internal `CitedField`, and serves only the engine's own labels, which `CitationMatch.confidenceLabel` already carries.
- No test changes, and `FRUSCoreKitTests` stays at 1,161.

**How they were checked,** each heavy job under the app's lock, from clones at real paths, beside `v2` at `02521d01` built and run the same way, Xcode 27.1, clean and unsigned:
- **`v2`:** the full iOS unit run had 7,623 tests in 903 suites, and failed only the 8 Keychain tests an unsigned build fails. `swift test` ran 3,054 tests. With thunk numbers and file-private discriminators dropped, `v2` had 249,757 symbol names, as #1786's head had, so the squash merge's tree built to the same library.
- **#1788:**
  - the full unit run had 7,636 tests in 906 suites, with the same 8 issues and the same 17 tests and 2 suites skipped;
  - `swift test` ran 3,084 tests;
  - the symbol diff was 243 names removed and 256 added. All but one of the removed are moved declarations' and reappear under their new names. The other is a test seam the moved suite no longer needs, and the 14 other added are the kit's new API.
- **#1787:**
  - the full unit run was the same as `v2`'s;
  - `swift test` ran 3,054 tests;
  - the symbol diff was 3 names removed and none added: `CitationLookupFields.init()` and two default-argument generators, which the spelled-out initialiser replaces.
- **Both:** `FRUSOffsetEngineTests` and `SelectionScriptParityTests` passed in all three runs, both Mac builds had `v2`'s five warning lines and the iOS builds its seven, and `swift build --target FRUSCoreKit` completed.
- **Linux,** in a scratch worktree of this repository's `main` at `c028783`, with each branch copied over the submodule:
  - every target passed but FRUSParityTests, whose 13 issues are all golden-file staleness;
  - `FRUSCoreKitTests` ran 1,191 and 1,161 tests, with the one named skip and no build warning;
  - a scratch file in `FRUSLightAPI`, never committed, imported FRUSCoreKit without `@testable` and used every name each makes public, and the target built.

**Delivered here**

- `COORDINATION.md`: the two pull requests in §2, and in §5's list of app changes only the web edition needs.
- This log.

**Notes**

- **`JSONEncoder` need not write one value's keys in the same order twice.** #1788's first full unit run failed one new test, which compared two encodings of the same highlight byte for byte. The test now sorts the keys, and the run quoted in the pull request is after that fix. The renderer reads the fields by name, so S15c's host may encode `ReaderHighlight` with any encoder, but a test of its JSON should sort the keys or decode it.
- **One target cannot compile two files of the same name,** and Xcode compiles `FRUSCoreKit/` and `FRUSExplorer/` into one module. So a kit file that takes code from an app file it leaves in place needs a name of its own.
- **For S15c:**
  - the server can serve the three strings as files, loaded in their order: the engine, then the renderer, which reads the engine's map, then the selection bridge;
  - `ReaderAnnotationScriptTests`' pins fail at any pin move that changes a script, so the reader frame's own test can compare the bytes served with the kit's strings and need no pin of its own;
  - `SelectionVerb.allInOrder.filter(\.needsDocumentOffsets)` is what a selection inside the body offers, and a footnote selection offers the rest.
- **Two scripts on one simulator raced.** Each Mac-check script boots, uninstalls and shuts down the shared iPhone simulator outside the lock, so two of them queued at once can uninstall the app under the other's run. One session's runs should share one queue.
- **Scratch:** the clones, the `v2` worktree, the logs, the scripts and the scratch worktree of this repository (`web-linux`) are under `~/Library/Caches/frus-s15a`.

**Next: S15b, the pin move past #1787 and #1788** once the owner has run Mac check 9 and merged both, as a pull request of its own under rule 5.
- If S16b's move to `02521d01` merges first, S15b starts from it.
- Neither pull request touches the indexing path, so the golden files may come from the 1776 three-volume export, by the owner's choice; only provenance should change.
- `Package.swift` needs no change, and the new kit suites add no skip.
- Beside it, S14c, the write path and tags, as S14a's entry says; S15c follows S15b and S14c.

## Session 16a: the Mac's JSON export at format version 7, upstream

23 October 2026 · branch `claude/priceless-elbakyan-9dab35` · upstream `2767a128`, unchanged; [FRUS-Explorer#1786](https://github.com/joshbotts/FRUS-Explorer/pull/1786) merged as `02521d01`

Phase 2's row S16a. The owner chose to open it now, during the app's 1.0 submission, and to merge it when the submission allows. Phase 2 keeps each researcher's research layer in the server's user store, imports a Mac's **Export as JSON** file into it (S16c) and writes one back (S16d). That needs two things the app did not have:
- the export's file in the kit, so the server reads and writes the app's own envelope with the app's own decoder;
- a file that carries the whole research layer. Version 6 carried 15 of the app's 23 model types, and dropped a note's rich text, a project's focus and a collection's composition.

This session opened one pull request on `FRUS-Explorer`, [#1786](https://github.com/joshbotts/FRUS-Explorer/pull/1786), from `claude/research-export-v7`, in two commits. It is labelled `Mac`, with "Mac verification requested". Under rule 4 it changes shared files, and this repository changes only its records. The owner merged it the same day as `02521d01`, a squash whose tree is the branch head's, `aac1aefa`, byte for byte.

**The first commit moves the export's file into FRUSCoreKit, unchanged** (`73e86506`):
- `ResearchDataEnvelope`, its records and its tolerant decoder, public, in `FRUSCoreKit/Export/ResearchDataEnvelope.swift`;
- `currentFormatVersion`, and the encoder's settings as `makeEncoder()`, with `makeDecoder()` and `jsonData()`;
- the five types the records name: `ResponseFormat`, `StructuredSummarySchema` and `SummaryAuthorship` in `Models/SummaryTypes.swift`; `ArchiveVisitTier` and `ArchiveVisitDeliverables` in `Models/ArchiveVisitValues.swift`;
- the Markdown note file, whose `ResearchNoteMarkdownExport.render(noteId:…)` takes a note's values and writes the app's file to the byte;
- the research database export's strip, as its five statements in order (`ResearchDatabaseStrip.steps`). S16e strips an export with them before installing it, the step S2 deferred;
- the app keeps every name: `makeEnvelope(modelContext:)`, the rest of `IndexDatabaseExporter` and the views stay its own.

**The second commit raises the export to format version 7** (`aac1aefa`):
- **The eight model types 6 left out**, each a new array that the tolerant decoder makes empty when absent:
  - saved searches, each as the kit's `SearchParameters`, the search `SavedSearch.searchParameters` gives the app, with its last run;
  - working corpora, custom volume scopes, both kinds of correction, annotation reviews and Suggested Next leads;
  - synced preferences, every record oldest first.
- **What 6 dropped from the types it carried**, each optional so earlier files still decode:
  - a note's rich text;
  - a collection's front matter, composition and settings;
  - each entry's kind, level, text, rich text, excerpt anchors, block type and overrides, so a heading, prose block, excerpt or apparatus block is no longer an entry with no document;
  - a project's focus tags and lead weights;
  - a summary's headnote flag.
- Rich text is RTF as the app stores it, base64 in the file. S15d's codec reads it.
- **On Apple platforms nothing else changes.** The export gains those keys. **Contents** in Settings ▸ Data & Recovery counts the eight types, and the JSON footer names them under a new key, as its comment asks. A lead's score that is not a finite number is written as 0, since `JSONEncoder` refuses NaN and the whole export would fail.
- **Tests:**
  - `ResearchDataFixtures` keeps a file of each version 1 to 7, in each version's own shape.
  - The kit's suite holds versions 1 to 6 to the new decoder and decodes the version-7 file of every type whole, to the byte back. It also holds the Markdown file to the byte, and runs the strip on a copy of a real index.
  - The app's suite exports a store holding every model type and decodes it again.
  - `FRUSCoreKitTests` goes from 1,150 tests to 1,161, and the iOS unit target from 7,609 to 7,623.
- **Mac check 10's decode:** a test that decodes a file named by `FRUS_RESEARCH_EXPORT`, and checks nothing when none is named, reads the owner's real export.

**How it was checked**, each heavy job under the app's lock, from a clone at a real path, beside `v2` at `2767a128`, Xcode 27.1, clean and unsigned:
- **`FRUSExplorerMac`** built as `v2` did, with the same five warning lines. With thunk numbers and file-private discriminators dropped, its symbol diff is 68 names removed and 1,786 added, each one the change accounts for. The first commit alone is 11 removed and 59 added: the moved private helpers and the initialisers now spelled out, against the kit's new API.
- **The full iOS unit run on iOS 27.0:** 7,623 tests in 903 suites, against `v2`'s 7,609 in 900. Both have the same 8 issues, the Keychain tests an unsigned build fails, and the same 17 tests and 2 suites skipped.
- **`swift test`:** 38 runs and 3,054 tests, none failed or skipped, against 3,043 on `v2`. `FRUSCoreKitTests` ran 1,161, and 1,158 at the first commit alone, whose touched app suites also passed.
- **Linux,** in a scratch worktree of this repository's `main` with the branch copied over the submodule, at `1ca859f` and again at `7d4f671`, after S14a and S14f merged:
  - FRUSCoreKitTests: 1,161 tests passed, with the one named skip and no build warning;
  - every other target passed except FRUSParityTests, whose 13 issues are all golden-file staleness. The source digest covers the kit's folders, and the pin move remakes the files;
  - the encoder's test passed there too, so the server writes the app's layout;
  - at `7d4f671`, S14a's store suites passed with it too, `FRUSLightCoreTests` at 63. They read the app's `@Model` classes, which #1786 leaves where they were, and the three app types they map keep their names.

**Delivered here**

- `COORDINATION.md`: the pull request among §2's web-authored moves, and §5's list of app changes only the web edition needs.
- This log.

**Notes**

- **A line-based sweep took a read for a write.** `CloudKitSchemaInventoryTests` fails if any line outside the model writes `annotationId:` other than `nil`. That field is a CloudKit identifier still waiting for its first writer. The export's mapping, `annotationId: review.annotationId`, only copies the field into its record. The first full unit run failed on it, and the pull request narrows the sweep to pass a value read from a record's own `annotationId`, with the reason beside it.
- **The symbol diff needs the file-private discriminators dropped as well as the thunk numbers.** The synthesized `CodingKeys` of each moved record are private to the file they are in, so moving a file renames them. The pull request's script drops both. The discriminator has two mangled forms, `33_<32 hex>LL` and a compressed one such as `022_…LL`, and the script matches both.
- **The daily watch will read a blank format version after the merge.** `scripts/upstream-watch` looks for `static let currentFormatVersion = <number>` under `FRUSExplorer/Export`, and the number is now the kit's, in `FRUSCoreKit/Export/ResearchDataEnvelope.swift`. The pin move past the merge widens that path.
- **Kit suite names stay unique:** the three new suites' names were checked against `FRUSExplorerTests/` first, and the fixtures file carries the `#if SWIFT_PACKAGE` header `FRUSCoreKitBoundaryTests` asks of every file there.
- **Scratch:** the clone, its `v2` and first-commit worktrees, the logs and the scripts are under `~/Library/Caches/frus-s16a`, with a scratch worktree of this repository at `main` in `web-linux`.

**Next: S16b, the pin move to `02521d01`,** a pull request of its own under rule 5, since #1786 merged before S15a's two.
- It widens `scripts/upstream-watch`'s search for `currentFormatVersion` to `FRUSCoreKit/Export`.
- Its golden files may come from the 1776 three-volume export, by the owner's choice: #1786 changes nothing on the indexing path, so only provenance should change.
- **The owner's JSON export for S16c,** from a library holding every type, is the file Mac check 10 decodes with the kit through `FRUS_RESEARCH_EXPORT`.
- Beside it, S14c, the write path and tags, as S14a's entry says.

## Session 14a: the user store's schema and migrations

23 October 2026 · branch `claude/phase-2-start-676787` · upstream `2767a128`, unchanged

Phase 2's first row. The user store, `app.db`, gains migration 2: a table for each of the 23 model types in the app's `frusModelTypes`, with a column for each of their stored properties at the pin, 243 columns for 249 properties, since the six relationships are held by the ids beside them, and `user_search`. A test reads the app's own list of those properties and each class's declarations, so a pin move that adds one fails until a migration follows. Before a start migrates a store it already holds, the server copies it into `/data/backups`, and a migration that fails leaves the store as it was. Nothing writes the new tables yet: S14c brings the write path.

**What the app's source says,** at `2767a128`:

- **The app keeps a list of every stored property.** `CloudKitSchemaInventory.installedIdentifiers` (`FRUSExplorer/Models/CloudKitSchemaInventory.swift`) names each model type and each of its stored properties, relationships included: 23 types and 249 properties. The app's `CloudKitSchemaInventoryTests` rebuilds it from the live schema of `frusModelTypes` and fails when the two differ, so it is the list the web's test reads.
- **Each property's type, read twice.** A scan of the 23 classes and eight readers in a workflow, each checked by a second reader, found the same 249 declarations, with the same types and optionality. Beside Foundation's types, three are the app's own: `SummaryAuthorship`, a `String` enumeration; `ResponseFormat`, an enumeration with an associated value; and `StructuredSummarySchema`, a struct.
- **Four `Data` properties hold JSON** that the app writes with `JSONEncoder`: a saved search's `parametersData` and `freshnessData`, and a visit plan's `tiersData` and `deliverableTogglesData`. Three hold RTF, a note's and an entry's `richText` and a collection's `introductionRichText`; an entry's may instead hold an encoded `AttributedString` from an older build. A visit document's and target's `stateData` is reserved, with no payload yet, and is always nil.
- **Ids.** Most are random. A visit document's and target's are derived from their plan and key, and an annotation review's from what it reviews. A sync can leave two rows with one id, which the app's `DuplicateRecordCleanup` collapses for ten of the types at each launch; the store keeps one row for each id. `SyncedPreferences` has no id: the earliest record is the one that holds.
- **Relationships.** Three are to-one, each with the id kept beside it (`collection` with `collectionId`, and a plan's `plan` with `planId` twice), and three are the to-many sides of those. Every other reference between models is an id, which the app repairs (`OrphanedTagRepair`) rather than enforces.
- **One correction per document.** `DocumentClassificationOverrideStore.setOverride` updates the newest override for a document, changing its value and time and keeping its id and the TEI's value, and the apply pass takes them oldest first, so the newest holds.

**Delivered**

- **Migration 2** (`Sources/FRUSLightCore/UserStoreMigrations.swift`), in the order of SPEC's mapping:
  - 23 tables, named as that mapping names them, with a column for each stored property but the relationships, in snake case and in the order the model declares them.
  - 21 user tables, each with `user_id` referring to `users`, so its rows are deleted with the user. Twenty are keyed by `(user_id, id)`; `preferences` is keyed by `user_id` alone. So two users may hold rows with one Mac id, as two imports of one file would make. The two override tables are instance-wide, keyed by the Mac's id. No other column refers to another table: the Mac's references are ids that can outlive what they name.
  - Dates as ISO 8601 text in UTC with milliseconds; booleans as 0 or 1; UUIDs as their strings; arrays, the app's `Codable` values and the four JSON `Data` properties as JSON text; the RTF and the reserved payload as bytes. A column is `NOT NULL` exactly when its property is not optional, and has no default.
  - 14 indexes, for a document's notes, highlights, tags, summaries and reviews, a tag's assignments, a collection's entries, a project's leads, a plan's documents and targets, the three trails by time, and a document's corrections.
  - `user_search`, FTS5 with the corpus's `porter unicode61`: `user_id`, `document_id` and `volume_id` unindexed, and the two indexed columns of the Mac's `user_content`, `summary_text` and `note_text`. A virtual table cannot refer to `users`, so a trigger deletes a user's rows with the user.
  - `index_corrections`' rows carried into `classification_overrides`, each with a new id, and with the opposite of its value as what the TEI said, since a correction changes the flag; then the table dropped.
- **`UserStoreSchema`** (`UserStoreSchema.swift`) describes the 23 tables: each model, its table, its scope, its columns with their kinds, and its relationships.
- **Opening the store** (`UserStore.swift`, `UserStoreBackup.swift`) is now `async`.
  - Before it migrates a store at migration 1 or later, it copies it into `/data/backups` through the backup API, as `app-<time>-before-migration-<n>.db`. The copy reads the store through a read-only connection of its own, so it holds what has been committed. It is written under a `.partial` name of its own, checked with `quick_check`, switched out of write-ahead logging, and then renamed.
  - A start that finds a copy holding what the store holds now uses it rather than taking another. Compose's `restart: unless-stopped` starts a server whose migration failed again about once a minute, and a copy each time would fill the volume.
  - The migrations it applies run in one transaction, with foreign keys off until a check before the commit, as SQLite's procedure for changing a table asks. The version is read again under the write lock, so a store another process migrated first is planned again from where it stands. A failure leaves the store as it was. A store newer than the build is refused.
  - The server logs each migration and the copy. On a failure it does not start, and the message names the copy.
  - Every use of the store's one connection holds a lock, so no caller's statement runs inside another's transaction.
- **Interface 2, corrections as override rows,** is now the Mac's `ClassificationOverride`, kept in `classification_overrides` as `setOverride` keeps it, and listed oldest first, one with no time first, as the app's sort takes it. Two with one time fall to their ids rather than to SQLite's rowids, an order S14d's PostgreSQL store can keep too.
- **`UserStoreDate`** writes a date to the millisecond, and reads only that form or whole seconds, with ASCII digits and a real day: a 31 February is refused rather than carried into March.
- **Tests,** in FRUSLightCoreTests:
  - `UserStoreTests`:
    - a new store and one at migration 1 both reach 2, the second after a copy that is the store at 1, with its correction carried over;
    - a failing migration leaves the store and its copy as they were, and failing again takes no second copy until the store changes;
    - a migration that rebuilds `users` keeps the rows that refer to it, and a foreign key a migration breaks fails it;
    - a newer store is refused;
    - corrections, and dates.
  - `UserStoreParityTests`:
    - the 23 tables against `frusModelTypes` and the inventory, and the inventory against the stored properties each class declares;
    - each column's kind and optionality against its declaration, and the JSON `Data` against the app's own writers;
    - the migrated store's columns, keys, references and lack of defaults against the description;
    - `user_search` against the Mac's `user_content`, and a user's rows going with the user.
  - `AppModelSource` reads the app's source once, with Swift's comments and string literals blanked and a string's interpolations read as code.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Build and Test steps, this package's own targets built clean, with no warnings. Before the review's fixes, all 2,100 tests passed, up from 2,085, with the one named skip. After them, FRUSLightCoreTests runs 61, from 42, all passing: `UserStoreTests` 10 and `UserStoreParityTests` 9. The other targets are unchanged.
- **The drill,** in a Compose install of its own (`frus-s14a`, port 8087, removed afterwards), with this branch's image built locally as `frus-light:s14a` beside the published `edge`, which predates this change:
  1. `edge` started on a new volume, leaving the store at migration 1.
  2. The new image migrated it to 2 and logged the copy, `app-20261024T014556Z-before-migration-2.db`.
  3. `edge` again refused the store ("app.db is at migration 2, newer than this build's 1") and restarted under the restart policy.
  4. `INSTALL.md`'s steps put the copy back, and `edge` served again.
  5. The new image migrated again, reusing the same copy: one file in `/data/backups`.
- **`scripts/compose-smoke --e2e`** on `frus-light:s14a`: passes, with 21 browser tests on Chromium, and axe finds nothing.
- **Two corrections on the way:**
  - The draft kept `stateData` as JSON, from its comment's "the `parametersData` pattern". The readers found that no code writes it, so it now stays bytes, and the test holds each `Data` property to whether the app writes it with `JSONEncoder`.
  - That test then failed on `parametersData`, a fault in its own reading. Swift's regular expressions find a word boundary by Unicode's rules, under which `self.parametersData` is one word. So the search for the property's writer missed `self.parametersData = try? JSONEncoder()…`.

**Records**

- `SPEC.md`: the user store's tables, keys, values, relationships and `user_search`; the mapping's preferences row; the upgrades line on the copy before a migration; the backups line, which keeps those copies apart from the daily seven; and the ranking risk, since `user_search` pools every user's statistics.
- `INSTALL.md`: the copy an upgrade makes before it changes the store, what a failure does under Compose's restart policy, and going back to an older server, which cannot open a store a newer one has changed.
- `PLAN.md` and its shared copy (rev 231): S14a done, in a paragraph of its own after the note that closes phase 2's rows, since S14f's session wrote that note's sentence for itself. The README's Status and this log.

**Notes**

- **A review before the push.** Four readers each took one side of the change: the runner, the schema, the tests and the records. Two skeptics then tried to refute each of their 29 findings, and 15 stood. All 15 are fixed here:
  - the copies a restart loop would have piled up;
  - the way back to an older server;
  - reads inside another caller's transaction;
  - a date returned unrounded, and dates out of range;
  - the foreign keys a rebuild needs off, and the tests that could not tell;
  - a list of models passing as a JSON column;
  - a `LIKE` pattern whose `_` matched any character;
  - the lexer's interpolations;
  - the counts and placeholders in these records;
  - the copies' place beside S14b's seven;
  - the pooled ranking statistics.

  So are seven the skeptics refuted but that cost little: the trigger, the second process, the `.partial` names, the classes read beside the inventory, the dates' scope in SPEC, ties broken by id, and JSON kept as the app's bytes.
- **Who made a correction** is not kept: S2's `recorded_by`, which nothing wrote, is dropped with `index_corrections`, and the Mac's overrides carry no author. Phase 3's curator role brings the audit log that SPEC's risks name.
- **Beside this session,** S14f, S14g and S16a were proposed as sessions of their own. S14f's and S16a's ran at the same time and took the app's heavy-job lock for their builds and Mac checks, so this session's runs waited their turn.
- **The build** reused S13c's `.build/linux` through an APFS clone (`cp -c`), at the same pin, and rebuilt this package's own targets clean.

**Next: S14c,** the write path and tags, which S14d, S14e and S15c follow; S14b, the daily backup and its restore, can run beside it, with S16a's Mac check; S14g's first release is the owner's, after #50.

## Session 14f: serving under a path

23 October 2026 · branch `claude/s14f-base-path` · upstream `2767a128`, unchanged

Phase 2's row S14f, one of the three asks of a shared deployment, run beside S14a, with which it shares no files. `FRUS_PUBLIC_URL` may now end in a path, such as `https://example.org/frus-explorer/`. The server then answers the browser app, the reader and the API under that path, and `/healthz` and `/readyz` under it and at the root. One build of the browser app serves either way, and the browser suite passes both ways, the second time through nginx running the install guide's recipe.

**The server**

- **`BasePath`** (`FRUSLightCore/Configuration.swift`) is the path a public URL ends in, `/` or one such as `/frus-explorer/`, with its last slash optional. Its names may hold only letters, digits and `-._~`, so a proxy cannot forward it in another spelling and it needs no escaping where the server writes it. A path with an empty name, `.`, `..` or an escape is refused at start, as is a URL with a query or a fragment. `ServerConfiguration.basePath` is computed from `publicURL`, so the struct gains no stored property.
- **`ServedRouter`** (`Routes.swift`) puts the routes under the path. The routes stay written at the root: a request under the path reaches them without it, with the base in `APIRequestContext`, so a problem's `instance` and its 404 detail name the path the client sent. `/healthz` and `/readyz` also answer at the root, for Docker's health check, which is unchanged, and a proxy's. A GET of the path without its slash is redirected to it with 308, and of `/` with 302; every other path outside it is a 404 problem. `buildApplication` and `apiApplication` build it at the root too, where it passes every request through.
- **The browser app's page.** `WebClient.load` writes the path into the page's `<base href="/">`, and refuses to start on a page without one, which is not this release's build. `/` and `/index.html` answer with the written page, which `FileMiddleware` would have served from disk unwritten.
- **The reader's page** names its host script and its figures under the path: `ReaderRoutes.pageHead(under:)` and `figureURL(for:under:)`, through `ReaderService.render(…, base:)`.

**The browser app**

- **Built once, with relative paths:** Vite's `base` is `./`, and `index.html` carries `<base href="/" />`, so the build's `./assets/…` resolve under whatever path the server writes, and `vite preview` and the development server keep working at the root.
- **`api/base.ts`** reads the base path from the page's `<base>`, and the root without one, as in the unit tests. `getJSON`, `/readyz`, the reader's page, so the frame, and Cite's record files go under it, and the router takes it as its `basepath`.
- **Skip to content** moved focus by `href="#main"`, which against the page's `<base>` names the app's first page, so following it would have loaded that page. It now moves focus itself.

**Compose and the smoke test**

- **`compose.yaml`** takes `FRUS_PUBLIC_URL` from `.env`, with today's value, `http://localhost:<port>`, as its default.
- **`scripts/compose-smoke`** keeps its checks at the root, with the build's relative script path and `<base href="/" />`. After the restart it makes the container again with `FRUS_PUBLIC_URL` ending in `/frus-explorer/`, the index staying in the volume, and checks the page with its base written, a client route, the script, the API, the reader's page and host script under the path, health at both, the redirect, and a 404 outside it.
- **The install guide's nginx recipes run in the smoke test.** It finds each by its `<!-- compose-smoke: nginx … -->` marker, puts its `location` block in a server on nginx's port 8080 with the `frus` service as the upstream, and starts `nginx:1.28-alpine` on the Compose network: the root recipe in the first phase, the path's in the second. With `--e2e`, the browser suite runs at the root in the server's network namespace, as before, and under the path in the proxy's.
- **The browser suite's paths are relative,** `page.goto('search')` rather than `'/search'`, since Playwright resolves a leading slash against the origin and would drop the path. `playwright.config.ts` ends the base URL in a slash. `base-path.spec.ts` checks that the page's base is the path the suite was given, that the reader's frame and the skip link stay under it, and that nothing the app or the frame asks for leaves it.

**Records**

- **`INSTALL.md`:** Behind a reverse proxy, with nginx recipes for the root and for a path and how other proxies forward a path unchanged; the `FRUS_PUBLIC_URL` setting; the Notes' first line. It says the server has no sign-in yet, so a proxy must keep it to its own network or sign-in until S14e.
- **`SPEC.md`:** HTTP API's conventions, for serving under a path; `FRUS_PUBLIC_URL` and `FRUS_WEB_DIR` in Configuration; the reader's host script in Security.
- **`PLAN.md` and its shared copy (rev 230):** S14f done, in phase 2's closing note; the Compose install's port line; phase 3's line, whose proxy recipe S14f wrote.
- **`ci.yml`'s header,** the README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** in this session: the package and its tests build with no warning. FRUSLightServerTests runs 115, up from 111, with `BasePathTests`' three and a page with no `<base>` refused, and FRUSLightCoreTests 44, up from 42; `ServedAPIParityTests`' five pass with the reader's head from `pageHead(under: .root)`. CI runs the rest.
- **The browser app:** typecheck and lint are clean, and 92 unit tests pass in 16 files, up from 89 in 15: the base path read from a page, a path put under it, and the router under `/frus-explorer/`.
- **`scripts/compose-smoke --e2e`** on this branch's image: passes, with 22 browser tests on Chromium at the root and the same 22 under `/frus-explorer/` through nginx, up from 21, and axe finds nothing either way. Its first run stopped at the root recipe: in the nginx container `localhost` is `::1` first, and the test's server block listened on IPv4 alone, so it listens on both.

**Notes**

- **Builds in a new worktree:** the Linux build reused S13c's `.build/linux` through an APFS clone (`cp -c`), and built in 45 seconds once the heavy-job lock was free; it waited about ten minutes behind S16a's unit-test run on the Mac.
- **`nginx:1.28-alpine`** is pulled on the smoke test's first use, on both architectures `image.yml` tests.

**Next: S14a,** the user store's schema and migrations, open in another session, with S16a beside it; S14g's releases merged first. S14e, sign-in through the proxy, follows S14c, and builds on this row: its cookies take `FRUS_PUBLIC_URL`'s path, and S14c's `Host` and `Origin` checks its origin.

## Session 14g: releases cut by hand

23 October 2026 · branch `claude/s14g-releases-cf1032` · upstream `2767a128`, unchanged

Phase 2's row S14g, one of the three asks of a shared deployment: releases a deployer can pin, with the index version announced when it changes. The owner now cuts each release by hand from a build of `main` that passed its smoke test, and `image.yml` moves only `edge` and the `sha-` tags. This replaces the 22 October rule that a release tag moves with `edge`.

**The workflow**

- **`.github/workflows/release.yml`** runs from the Actions tab's Run workflow, with a commit to release, by default the build `edge` names, and a dry run, on by default. A run on any branch but `main` is a dry run too. Its `release` job needs `contents: write` for the tag and the release, `packages: write` for the image tags, and `actions: read` and `pull-requests: read` for the checks and the notes. One release runs at a time, and none is cancelled.
- **`scripts/release`** does the work, and runs on a Mac too:
  - `build-args` prints the image's build arguments: the server's version, the pinned app's version and build from `scripts/release-tag`, and the index version from `Compatibility.swift`. It fails, as `scripts/release-tag` did, when the app's targets disagree, so `image.yml` publishes nothing.
  - `cut` checks the build, writes the notes and makes the writes; `--dry-run` prints them instead.
  - `selftest` runs `cut` against stubs of `docker` and `gh` in sixteen cases, in a repository that borrows this one's objects and holds release tags of its own. `release.yml` runs it before every release, and on a pull request that changes the release.

**A release**

- **The checks.** The commit is on `main`, and `image.yml`'s newest run for it on `main` succeeded, so its build passed the Compose smoke test on both architectures. A commit a release already holds is refused. The image is the commit's `sha-` tag, and its labels must agree with the commit's sources: the revision is the commit, the app's version and build are what `scripts/release-tag` reads from the `project.yml` the commit pins, and the index version is `Compatibility.swift`'s. The two platforms' labels must agree too.
- **The name.** `<version>-<build>.<n>`, `<n>` one past the last release of that app build, from 1. The last release is the newest release tag on the commit's first-parent line.
- **The notes** name:
  - the digest, the image's two release tags, the platforms, the commit, the server's version and the `image.yml` run that tested it;
  - the FRUS Explorer version and build whose exports it serves, and the index version: the same since the last release, changed from what at which release, with the steps to export again, or the first release;
  - the image's labels;
  - the pull requests merged into `main` since the last release, oldest first, by number and title. The merge commits hold only the number, so the titles come from `gh`.
- **The writes,** in this order: `imagetools create` moves `:<version>-<build>` to the digest and tags it `:<version>-<build>.<n>`, and each tag is read back at that digest; then `gh release create` publishes the release, which tags the commit. A run that fails after the move can run again, since moving a tag to the digest it already names changes nothing, and the commit is not yet a release's. `imagetools create` keeps an index's digest, as `:edge`, `:sha-e15d651` and `:1.0-1776` show on the registry, each `sha256:1a10dcde…`.

**The image**

- **Three labels,** from build arguments the `Dockerfile` declares: `io.github.joshbotts.frus-explorer.version` (`1.0`), `.build` (`1776`) and `.index-version` (`71`), beside the OCI labels' server version and commit.
- **`image.yml`** takes its build arguments from `scripts/release build-args`, and its promote job moves only `edge`. A pull request that changes `scripts/release` or `scripts/release-tag` builds the image.
- **CI's compose job** builds with the same arguments, and `scripts/compose-smoke` builds with them too. After the import, the smoke test checks that the labels name an app version and build, and that the index-version label is the one `/api/v1/status` reports. It runs in `image.yml`'s verify job too, so a build of `main` without the labels does not reach `edge`.

**Decided here**

- **A release also tags the image `:<version>-<build>.<n>`,** which never moves, beside the moving `:<version>-<build>`, so a deployer can pin a release by name as well as by digest. The row asked only for the moving tag; PLAN's S14g row and SPEC now name both.
- **A build from before the labels cannot be released.** So the first release is a build from this pull request's merge on.
- **On a pull request, the dry run takes the branch's own build.** No image built before this row has the labels, and a session never publishes, so `release-dry-run` builds the branch's head for amd64 from `image.yml`'s cache and pushes it to a `registry:2` service inside the job, at `localhost:5000`. It then runs `cut --dry-run --pull-request`, which skips the two checks only a build of `main` passes, on `main` and its `image.yml` run. Nothing leaves the job.

**Checked**

- **The selftest:** all sixteen cases pass, on a Mac and in CI's `release-selftest`. The first release; the next of an app build, which leaves out the last release's pull requests; a new index version; the build `edge` names; refusals for a commit already released, one not on `main`, a newest run that failed, one still running, no run, labels of another index version or app build, an image without the labels, another commit's image, and a pull request's build outside a dry run; a pull request's build in a dry run; and a release made, whose two writes the stubs record. Breaking the numbering by one fails six cases.
- **A dry run against `edge` from a Mac,** with the real registry and `gh`: the build of `e15d651`, digest `sha256:1a10dcde…`, on `linux/amd64` and `linux/arm64`, tested by `image.yml`'s run 40044216783; FRUS Explorer 1.0 (build 1776), index version 71, the first release, `1.0-1776.1`, with 47 pull requests. It was refused, as it should be, for the labels that build predates.
- **A dry run on this branch's build,** built locally and pushed to a `registry:2` on the Mac: the labels above, the release `1.0-1776.1`, its notes and its writes, with nothing pushed. Then the same build released for real into that registry, with a stub `gh`: both tags read back at the build's digest, and the stub received the release.
- **This pull request's `release-dry-run`,** at `885b4dc`: the branch's amd64 build in the job's registry, digest `sha256:279f35a2…`, with the three labels at `1.0`, `1776` and `71` and the revision `885b4dc`; FRUS Explorer 1.0 (build 1776), index version 71, the first release, `1.0-1776.1`, with 47 pull requests; and the two writes it would make, the move checked by `imagetools create --dry-run`.
- **`scripts/compose-smoke`** passes on this branch's image, with the labels' check, on a Mac and in CI's compose job, and fails at that check against `edge`.
- **actionlint 1.7.7** finds nothing in `release.yml`; its one warning is in `image.yml`'s join of the digests, which splits words on purpose.

**Records**

- `SPEC.md`: the image's tags, its labels and what a release is; the upgrade line.
- `INSTALL.md`: a Releases section under Upgrading, with what a release is, what to set `FRUS_IMAGE` to for each way of following the server, how to hear of releases, and what to do when the index version changes; the `FRUS_IMAGE` setting.
- `PLAN.md`: `release.yml` in the workflows table; S14g's row and S12d's, whose `:1.0-1861` now comes from a release; the Compose install's upgrade line; the 22 October answer's rule, which S14g replaced; and an owner checkpoint for the first release.
- `COORDINATION.md`: S12b's release tag, which moved with `edge` until S14g. The README's Status, and this log.

**For the owner after the merge**

- The first release: Actions → release → Run workflow, on `main`, with no commit. Run it first as a dry run, the default, and read its summary; then with dry run off, which publishes `1.0-1776.1`.

**Next:** the owner's first release; then S14b, the daily backup and its restore, once S14a merges, with S14f and S16a beside it.

## Phase 2's plan: the user store, the research layer, and a shared deployment's three asks

23 October 2026 · branch `claude/phase2-plan-28c0c7` · upstream `2767a128`, S13c's, unchanged; read at `af41efa4`

The owner asked for phase 2 to be planned before any of its code is written, in rows sized one pull request each, as issue #37's revision planned the 1.0 catch-up. The owner also asked this session to take up three asks from a proposal of 16 October to run the server behind an organisation's reverse proxy and single sign-on. This session changes records only.

**Checked against the app's code at the pin** (`docs/prep/README.md`, Phase 2)

- **The JSON export is at formatVersion 6 and carries 15 of the 23 model types.** Its envelope's DTOs are internal Foundation structs in an app file that imports SwiftData, and the five types they name are Foundation-only, so they can move into the kit unchanged.
- **Version 6 also drops data from the types it carries:** a note's rich text, a project's focus tags, and a collection's whole source. It writes a heading, a prose block or an apparatus block as an entry with no document.
- **Linux's Foundation has no RTF reader or writer,** checked by compiling against it in `swift:6.4-noble`, and the Mac keeps every formatted note and prose block as RTF.
- **The reader's three annotation scripts are strings in a WebKit file,** two of them private. The web's host script already stands in for their three message handlers, and `renderingVersion` is the kit's and already served.
- **The search's user half reads the index's `user_content` and `user_tag_ids` in private SQL,** so reading user text from `app.db` is an upstream change.
- **Saved searches keep the kit's `SearchParameters`.** Their freshness, the corpus and scope resolution, the method appendix and the Research page's groups are app code.
- **Corrections reach search only through writes to the index,** which the server's immutable open refuses.
- **Collections are app code:** a 1,785-line resolver over `AppState` and SwiftData, 5,300 lines of exporters, and 332 tests, none of them compiled against the kit.

Four read-only surveys of the app's code did the reading. The claims the rows rest on were checked here again, line by line.

**The plan** (`PLAN.md`, Phase 2) has 30 rows in six groups:

- **S14, the user store and the server, without the Mac:** the schema and migrations (S14a), the daily backup and its restore (S14b), the write path and tags (S14c), the PostgreSQL store (S14d), sign-in through a trusted proxy (S14e), serving under a path (S14f) and releases cut by hand (S14g).
- **S15, writing in the reader:** the reader's scripts into the kit, with Citation Lookup's types made public (S15a, upstream); its pin move (S15b); highlights, with check 6 (S15c); notes and summaries (S15d).
- **S16, the Mac's JSON export:** the envelope into the kit at formatVersion 7 (S16a, upstream); its pin move (S16b); import (S16c), export (S16d) and an export that includes the owner's writing (S16e).
- **S17, the research layer in search:** user text in the kit's search (S17a) and the research layer's rules (S17b), both upstream; their pin move (S17c); search over notes, summaries and tags (S17d); saved searches, corpora and scopes (S17e); projects, the history and the method appendix (S17f).
- **S18, collections:** rendering from values (S18a), then resolving through a data source (S18b), both upstream; their pin move (S18c); the editor (S18d); the preview and exports (S18e); `.fruscollection` and smart collections (S18f).
- **S19:** Citation Lookup (S19a) and the Research page (S19b).

It has seven upstream pull requests and eleven owner checkpoints: Mac checks 9–14, the golden spans, the owner's JSON export, the restore drill, a web collection opened in the Mac app, and the sign-off. Eight risks are new. The answers record the plan's rule, that the store is the web's and every answer computed from it the app's, and what waits for phases 3 and 4.

**The owner's answers,** in this session:

- **The user store** is SQLite, with a PostgreSQL store beside it, tested in CI and not offered in Compose.
- **The daily backup** runs at a set hour and whenever the newest backup is more than a day old, and only when something changed; each is also copied to a folder on the host.
- **Corrections** are held as the Mac made them, not made on the web.
- **Version 7** opens upstream now, merged when the 1.0 submission allows.
- **Web to Mac** stays one `.fruscollection` at a time, with no Mac importer.
- **Imported AI summaries** are shown, read-only and labelled.
- **Sign-in through a trusted proxy** comes in phase 2, after the user store.
- **Releases** are cut by hand, with notes, which replaces the 22 October rule that a release tag moves with `edge`.

**The three asks** become S14f (serving under a path), S14e (sign-in through the proxy) and S14g (releases, with the index version announced when it changes). These records leave out the deployment's own infrastructure.

**Records**

- **`PLAN.md`:** the Phase 2 section, with its flowchart, rows and closing note; eleven checkpoints; eight risks; the two answer sections; the Summary, the Compose install's backup and upgrade lines, and A4.
- **The shared copy of `PLAN.md`** is at rev 227. Its Phase 2 diagram is drawn, as its session plan is, rather than given as Mermaid.
- **`SPEC.md`:**
  - Tenancy, with the proxy mode's phase and the guard on writes under `FRUS_AUTH=none`;
  - the user store, the import and export paths, what version 6 drops, and rich text on Linux;
  - rule 7 for an immutable index, corrections held in phase 2, and secrets from phase 3;
  - the release tags, `FRUS_PUBLIC_URL` with a path, `FRUS_ADMIN_USERS`, `FRUS_USER_DATA`, the daily backup and its restore;
  - phase 2's scope and exit, the app changes requested, and three open questions answered.
- **`COORDINATION.md` §5:** version 7, phase 2's other moves into the kit, and no Mac importer.
- **`docs/prep/README.md`:** the Phase 2 section.
- **The README's Status, and this log.**

**Results**

- No code changed. CI runs as on any pull request, at the pin.

**Next: S14a,** the user store's schema and migrations. S14f, S14g and S16a share no files with it and can run beside it; S16a, the upstream pull request for formatVersion 7, opens now by the owner's choice. S12d still waits for `version-1.0`.

## Session 13c: pin move past FRUS-Explorer#1785, the exact-word speed

23 October 2026 · branch `claude/s13c-pin-2767a128-62cc02` · upstream `2767a128`

The pin moves from `af41efa4` to `2767a128`, the owner's merge of [FRUS-Explorer#1785](https://github.com/joshbotts/FRUS-Explorer/pull/1785) the same day, so the server's exact-word filter reads each text as bytes, with the same results: through the API, each of S13b's 45 exact-word queries now takes under two seconds over the full corpus, where such a search took about a minute. S13b's log offered the move with S12d or as one of its own; the owner chose one of its own, under rule 5, before `version-1.0` was tagged.

**What the move brought**

- **One commit,** byte for byte the head of #1785's branch (`f61ca061`). In shared code, `FTS5Store/ExactWordMatcher.swift` gains `Word` and `contains(_:inUTF8:)`, the byte reading, through which `contains(word:in:)` now answers, and keeps the old body as `containsByFolding(word:in:)`. In `FRUSCoreKit/Search/IndexingPipeline.swift`, `frus_exact_word` reads the bytes SQLite holds and keeps its folded word with the statement (`ExactWordArgument`), and `exactWordFunctionForTesting` lets the tests call it. `FRUSURLScheme.swift` gains history lines only. `ExactWordMatcherTests` gains a suite of 7 tests and `ExactWordSearchTests` 3, so FTS5StoreTests runs 219 (from 212) and FRUSCoreKitTests 1,150 (from 1,147). The rest is the app's records.
- **No repair.** The package builds with no warning, every kit suite passes, and the only skip is the named one. The two test files sit in folders `Package.swift` already compiles. The build (1.0, 1776), the index version (71), the FTS generation (4), the export's schema (`setupDatabase(_:)` is the same text, now at lines 7759–8414), the kit folders, the app's source folders and CI's allow-list are unchanged, so `Compatibility.swift` and the install guide's versions stand, and `scripts/release-tag` still says `1.0-1776`.

**Nothing the indexer runs changed.** `git diff af41efa4 2767a128` over COORDINATION §5's indexing path:

- **The parser, SourceNoteKit and `FRUSExplorer/Resources`:** no change; the six changed lines of `FRUSURLScheme.swift` are comments.
- **`IndexingPipeline.swift`:** the history line 4.46; `registerExactWordFunction(_:)`'s comment and the closure SQLite calls for `frus_exact_word`; `ExactWordArgument`, which keeps the folded word; and `exactWordFunctionForTesting`, which only the tests call. The pipeline registers the function on its connection (`auxDb`) when it opens it, and outside the tests only one statement names it: the condition each exact term adds to a search's `WHERE`, `frus_exact_word(dc.<column>, ?) = 1` over the columns `SearchService.exactColumns(for:)` gives, which a search's page and count share. No statement that writes the index calls it.
- **FTS5Store:** `ExactWordMatcher.swift` alone. `word(_:)`, `normalize(_:)` and `tokens(in:)`, which give the index word the query parser keys an `=` mark on, are unchanged; `contains(word:in:)`, which only the SQL function called, answers through the byte reading.

So the owner's 1776 three-volume export holds what the indexer at `2767a128` would write, and the golden files were remade from it, on the owner's word.

**The golden files**, remade by `scripts/make-golden --export /Users/Shared/frus-index-build1776-golden.sqlite` under the app's `Scripts/heavy.sh` lock:

- The 393 rows' HTML is byte for byte as before; the render's manifest, the expressions and the results change only in `sourceDigest` (`cd37102d321b` to `d99bca0de69c`) and `upstreamCommit`.
- The index summary's gating section, its 36 digests, 7 checks and volumes, is unchanged. Beside its provenance, only four of its information section's timings moved, which record how long this run took to hash a table.
- `frus-parity check-golden` passes.

**Through the API at the new pin,** in a Compose install of its own, `frus-s13c` on port 8086, with the owner's full 1776 export imported once (321,749 documents in 553 volumes, served 59 s after the copy began), on this branch's image, `frus-light:s13c`, built locally: S13b's 45 exact-word parity queries, one `/api/v1/search` each, its count and first page of 20 as the browser app asks them, one after another, in one pass, under the heavy-job lock so no build ran beside it:

| Per request | The API at `2767a128` | The kit at #1785's branch (S13b, Linux) |
| --- | --- | --- |
| The 45 in all | 16.9 s | 15.3 s |
| Median | 0.39 s | 0.37 s |
| p95 | 1.07 s | 0.90 s |
| Slowest | 1.63 s, `=containment` | 1.08 s, `=negotiators` |

- **The slowest was the first request** after the server started on the new image. Every other took 1.14 s at most (`=negotiators`), and each was within 0.17 s faster and 0.27 s slower than the same request through the kit, the median 0.01 s slower.
- **Every result as the kit gives it.** Each count was the kit-level run's, and `frus-parity results --api` read check 3's records of the 45 through the API, counts, first 50 results and tie tails with their score bits, which `compare-results` found "45 queries, 45 identical and 0 reordered only within Mac tie groups" against S13b's Linux records from before the fix and from after it.
- **Measured right after the browser suite,** at a load average of 8 falling to 7.6, in Docker Desktop's VM with 10 CPUs and 8 GB; check 12's 4 vCPU host is still phase 5's.

**Records**

- `PLAN.md` and its shared copy (rev 212): the session intro, the flowchart (`PLAN.md`'s; the shared copy's drawing ends at phase 1), S13c's row, S12d's row (from `2767a128`), the golden-files checkpoint, Mac check 8, the two risk rows and S13c's answers.
- `SPEC.md`: check 12's measurement at the pin, the compatibility contract, and `setupDatabase(_:)`'s lines.
- `INSTALL.md`: an exact-word search's time over a whole corpus.
- `COORDINATION.md`: the pin; §1's use of the kit; §2's paragraph on #1785, now merged, and on this move; §5's rule for reusing an export; and §6's exports.
- `docs/prep/README.md`: the pin. The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Build and Test steps, this package's own targets built clean: all 2,085 tests pass, up from 2,075, with the one named skip. FTS5StoreTests runs 219 (from 212) and FRUSCoreKitTests 1,150 (from 1,147); the other targets are unchanged, FRUSParityTests at 122 and FRUSLightServerTests at 111. Before the golden files were remade, the only failures were the parity suites' 13 issues of golden-file staleness. Against the remade golden files the run printed:
  - "check 2 passes: 36 digests and 7 checks are the Mac's";
  - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
  - "check 4 through the page: 393 of 393 rows identical", and the same on the reader's path and from one full parse per volume.
- **`scripts/compose-smoke --e2e`** on this branch's image: passes, with 21 browser tests on Chromium, and axe finds nothing.

**Notes**

- **The `frus-s13c` install** was removed with `docker compose -p frus-s13c down -v`, its volume with it; the owner's install on 8080 was left as it was.
- **Builds in a new worktree:** the Linux build reused S13b's `.build/linux` through an APFS clone (`cp -c`) and built this package's own targets clean in 53 seconds; `make-golden`'s two native tools built from empty, and the whole script ran in under six minutes; the image built from its cache mount in under a minute.
- **Scratch:** the timing's scripts, `api-45.py` (each query's form as `APIParity.formEncode` writes it) and `api-timing.sh`, with their records and the Compose folder, are under `~/Library/Caches/frus-s13c`.

**Next: S12d**, once the app's repository tags `version-1.0` (build 1861), moving the pin on from `2767a128`; beside it, the first session of phase 2, as phase 2's plan in `PLAN.md` names it.

## Session 13b: the speed of exact-word search

23 October 2026 · branch `claude/s13b-exact-word-speed-111511` · upstream `af41efa4`, unchanged; [FRUS-Explorer#1785](https://github.com/joshbotts/FRUS-Explorer/pull/1785) open

The last item before a web release. A search with an exact word (`=word`) took 45 to 70 seconds over the full corpus, on the server and in the Mac app alike. The time was the kit's exact-word filter, so the fix is upstream, [FRUS-Explorer#1785](https://github.com/joshbotts/FRUS-Explorer/pull/1785), which takes such a search under 1.3 seconds on both platforms and keeps every result as it was. It needs no index change. Beside it, the server now keeps a search's page and count, so the concordance of the page on screen and the search's next page ask for neither again.

**Where the time went**, over the owner's full 1776 export, natively on this Mac and on Linux in the build container, the same file on both:

- **Not the match, nor reading the text.** FTS5 matches `soviet` in 58,679 documents in 12 ms. Reading the 425 million characters of their bodies takes 0.22 s warm and 2.3 s cold, natively.
- **The filter.** `=Soviet` runs that match with `frus_exact_word` over each candidate's header, dateline, source note and body (`SearchService.exactColumns(for:)`). The function folded each whole text with Foundation (`String.folding`, diacritics and case) and split it on `Character`'s properties to find the word, and over `=Soviet`'s rows that took 21.2 s natively and 22.1 s on Linux, 99% of the pass. The count and the page each make that pass, and so do the 7,500 results the Mac's window keeps beside its count, and the server's date order and timeline. The concordance fetched its page again.
- **The text is mostly ASCII, and almost never all ASCII.** Only 880 of those 58,679 bodies are ASCII alone, but non-ASCII is 0.3% of their characters, and 88% of it is five marks of punctuation: ’ “ ” — –.

**Before**, measured with `frus-parity time-search`, new: the 45 parity queries that apply an exact term, each its first page of 20 and then its count, as `/api/v1/search` asks the pipeline for them, through FRUSCoreKit's SearchService over the export opened as the server opens it:

| Per request, page and count | Mac, native | Linux, container |
| --- | --- | --- |
| The 45 in all | 1,343 s | 1,400 s |
| Median | 27.3 s | 30.7 s |
| p95 | 62.7 s | 63.6 s |
| Slowest | 77.7 s, `=protection protect` | 69.6 s, `=containment` |

The two ran at once, and the Mac's slowest beside a test build; run alone again, `=protection protect` took 46 s, `=containment` 51.5 and 53.8 s, `=Soviet` 52.1 and 56.4 s, and `=negotiations`, the Mac's slowest alone, 71.1 s. Every count is the same on both platforms. The largest candidate set is `negoti`'s, 66,904 documents, which `=negotiations`, `=negotiation` and `=negotiators` each read.

**The fix upstream:** [FRUS-Explorer#1785](https://github.com/joshbotts/FRUS-Explorer/pull/1785), "An exact-word search reads each candidate's text as bytes, so over the full corpus its count and its page take under a second each, not 20 to 35", labelled `Mac`, with "Mac verification requested". Under rule 4, in two shared files:

- **`ExactWordMatcher`** (FTS5Store) reads a text's UTF-8 bytes, in regions divided at each ASCII separator whose neighbours are ASCII bytes or the text's ends. The fold changes no ASCII character but `A`–`Z`, and no grapheme joins two ASCII characters but CR LF, so such a separator divides the folded text where it divides the text. A region of ASCII alone is then one token. A region holding a non-ASCII byte is read scalar by scalar, each scalar by the class the fold itself gives it between two ASCII letters: a separator (’), letters it folds to (é to `e`), or a letter that stays itself (ʼ, ½, ж). The class is probed once a process for Latin-1 to Cyrillic and General Punctuation to Number Forms. A region with any other scalar, or with bytes that are not well-formed UTF-8, goes to the fold, as the whole text did before. Two passes, eight bytes at a step, find the word as a region of ASCII alone, then read the regions holding non-ASCII bytes, and a word that folds to something other than ASCII (`gomułka`) is looked for by the fold over the whole text.
- **`frus_exact_word`** (FRUSCoreKit's `IndexingPipeline`) reads the bytes SQLite holds, to the first NUL as `String(cString:)` read them, without copying them, and folds its word once a statement, kept with it by `sqlite3_set_auxdata`.
- **The answers are the fold's.** `containsByFolding(word:in:)` keeps the old body as the definition. The tests hold every answer to it: each classed scalar in 24 contexts beside, inside and around 15 words, the scalars sent to the fold, 6,000 random texts of those pieces, 4,000 runs of ill-formed bytes, and the SQL function's own answers, with one word over many rows, a word for each row and a NUL inside a text. `FTS5StoreTests` gains 7 tests and `FRUSCoreKitTests` 3.
- **#1784's records,** which S12c left for the next web-authored pull request: the two moved types' history lines, the handler's 1.10, `CLAUDE.md` and the amendment log now say they became public and `Sendable`, and `FRUSURLScheme`'s own history logs the move. The handler's comment keeps its line count, so no editable-content range moves.

**Every result as it was**

- **Every row's decision, over the whole export:** the branch's matcher, compiled from its file, against the pin's file, for the 28 words the 45 queries mark, over every row each word's stem matches and every one of its four columns: 941,109 rows and 3,581,190 texts. The old file, the kept definition, the matcher's String path and the SQL function's byte path gave the same answer for every text, natively and on Linux, and each word's rows, texts and exact matches were the same number on both.
- **Every result, over the whole export:** `frus-parity time-search --out` wrote check 3's records of the 45 queries before and after, counts, first 50 results and tie tails with their score bits, and `compare-results` printed "check 3's results pass: 45 queries, 45 identical and 0 reordered only within Mac tie groups" natively and on Linux, with no score bits other than before's: the same rows in the same order with the same scores, on each platform. Across the platforms the after files hold the same rows in the same order, and 42 queries other score bits, macOS's SQLite 3.54.0 against Linux's 3.45.1, as check 3 has always found.
- **Check 3's 482 queries and the golden files,** on Linux with the branch over the submodule, in a scratch worktree: through the API, "482 queries, 482 identical and 0 reordered only within Mac tie groups", the read-only open's 482 results the writable index's, score bits included, and the 482 expressions as the golden file says; check 4's 393 rows identical on both of the reader's paths; and check 2's 36 digests and 7 checks with no difference. The 13 issues were all golden-file staleness, since the files' source digest covers the kit's folders (`cd37102d321b` at the pin, `b7a3ccfa0ebc` there), which the pin move past the merge remakes.
- **On Apple platforms** nothing else changes. Run here as COORDINATION §5 asks, from a clone at a real path, each heavy job under the app's lock, beside `v2` built and run the same way:
  - `FRUSExplorerMac`, Debug, clean, unsigned: built, with `v2`'s five warning lines. With the numbers the compiler gives local thunks dropped, the debug dylib holds every one of `v2`'s 247,942 names and 241 more, all the byte reading's or what it uses;
  - iOS 27.0 on an iPhone 17: a clean `build-for-testing`, with `v2`'s 7 warning lines; the full unit target, 7,609 tests in 900 suites against `v2`'s 7,606, with the same 10 issues on both, the 8 Keychain issues an unsigned build has and two presentation tests of `RichTextRestingCapTests`, which failed alone on `v2` too, and the same 17 tests and 2 suites skipped;
  - `swift build --target FRUSCoreKit`, and `swift test`: 38 runs, 3,043 tests, all passing, none skipped, against 3,033 on `v2`; `FTS5StoreTests` 219, up from 212, and `FRUSCoreKitTests` 1,150, up from 1,147.

**After**, with the branch, its code as it opened, the same 45 queries:

| Per request, page and count | Mac, native | Linux, container |
| --- | --- | --- |
| The 45 in all | 18.2 s | 15.3 s |
| Median | 0.46 s | 0.37 s |
| p95 | 0.97 s | 0.90 s |
| Slowest | 1.29 s, `=negotiators` | 1.08 s, `=negotiators` |
| The 7,500 results kept, slowest | 2.17 s | 2.55 s |

`=Soviet`'s page and count each take 0.30 s natively and 0.21 to 0.23 s on Linux, from 23 to 28 s. A word its stem's documents rarely hold costs most, since each text is read to its end: `=negotiators` reads 66,904 candidates to find 2,632.

**Through the API,** in a Compose install of its own, `frus-s13b` on port 8084, with the full 1776 export imported once: first with the published `edge` image, `main` at the pin, then with this branch's image built over the upstream branch, `frus-light:s13b`. Each request as the browser app makes it, one after another:

| Request | `=containment` before | after | `=Soviet` before | after |
| --- | --- | --- | --- | --- |
| `/search`, its count and first page | 58.1 s | 0.84 s | 59.7 s | 0.55 s |
| The same search again | 57.2 s | 0.00 s | 64.9 s | 0.00 s |
| Its concordance | 26.6 s | 0.02 s | 29.7 s | 0.02 s |
| Its timeline, the 7,500 kept | 30.3 s | 0.49 s | 34.8 s | 1.29 s |
| Its second page | 57.2 s | 0.39 s | 65.4 s | 0.27 s |

With the branch's image, `/search` for the other exact words took 0.57 to 1.36 s (`=negotiators` the slowest), and `soviet`, a common word, 0.12 s. The rows a search asks for again are the server's change: the same search, its concordance and the count of its second page ask the kit for nothing. The "before" ran beside the two record runs, as the 45-query runs ran beside other work; S11f had measured `=containment`'s timeline at 29 s and its concordance at 25 s. A first pass on `edge`, during the Mac check's unit run at a load average of 20 to 33, took 67 to 195 s a search.

**The web side**, which needs no upstream change:

- **A search's page and count are kept** (`RecentSearches`, beside `RetainedResults`): the pages of the last four searches by relevance, by their fields and a page's limit and offset, and their counts. The concordance reads the page `/search` fetched, even while it is fetched, as the browser asks for both at once when the concordance is open, and another page of a search, or the same search again, counts nothing. A page or a count no request waits for any more is stopped at once, as `/search` stopped its own when its client went (#1698). The Mac's window keeps what it fetched and pages it, so it asks for neither twice either.
- **`frus-parity time-search <export>`** times check 12's search over an export as the server opens it, on either platform: `--all` times every parity query, `--ids` some, `--retained` the 7,500 kept, and `--out` writes check 3's records, which `compare-results` holds to another run's.
- **Tests:** `RecentSearchesTests` counts the kit's statements through the pipeline's test hook: an exact word's search, its concordance, the same search again and its next page ask for three statements, not seven, with each answer the first one's; another search asks for its own two. `SearchTimingTests` runs the timing over the fixture index: the queries are the 45 the golden expressions give exact terms, and each count is the golden file's.

**Which pin move.** The change moves no index version, export, schema or result, and nothing that indexes: the pipeline's change is the search function's registration. So it can ride with S12d: if it merges after `version-1.0` is tagged, S12d moves the pin to its merge instead of to the tag, one move and one set of golden files, which the owner may remake from the three-volume export S12d uses, since no row it indexes changes. If the owner wants the pin at the App Store build's code exactly, S12d moves to the tag, and a pin move of its own follows the merge. Merging waits on the owner's Mac check, and on the submission as the owner sees fit; until then, the server's own change already halves an exact-word search's next page and spares its concordance a pass.

**Records**

- `PLAN.md` and its shared copy (rev 206): the session intro, the flowchart, S13b's row and its answers, Mac check 8, the owner's fifteen steps and the risk row.
- `SPEC.md`: check 12's measurements, and the API's kept pages and counts.
- `INSTALL.md`: an exact-word search's time over a whole corpus, and what the server keeps.
- `COORDINATION.md`: §2's paragraph on #1785.
- The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Test step, this package's own targets built clean: all 2,075 tests pass, up from 2,073 after S13a, with the one named skip. FRUSParityTests runs 122, up from 121, and FRUSLightServerTests 111, up from 110; the other targets are unchanged, FRUSCoreKitTests at 1,147.
- **With the upstream branch over the submodule,** in the scratch worktree: FTS5StoreTests 219 and FRUSCoreKitTests 1,150, all passing with the one named skip and no build warning, and every other target passing but the parity suites' golden-file staleness.
- **CI** on the pull request, [#47](https://github.com/joshbotts/FRUS-Explorer-Web-App/pull/47), before these records: `swift`, `compose` with the browser suite on Chromium, `web`, and both image builds passed.

**Notes**

- **Measured beside other work.** The before and after runs ran with other jobs on the machine, as recorded: before the fix a request's time moved by up to a third with what else ran, and after it by hundredths of a second. The Docker VM has 10 CPUs and 8 GB, so check 12's 4 vCPU host is still to be measured.
- **The `frus-s13b` install** was removed with `docker compose -p frus-s13b down -v`, its volume with it; the owner's install on 8080 was left as it was.
- **Scratch:** the upstream clone, its `v2` worktree, the Mac check's logs and a scratch worktree of this repository at the branch are under `~/Library/Caches/frus-s13b`; the benchmark that found the cost, and the clone of the export it read, are under this worktree's `.build/linux/s13b`.

**Next:** **S12d**, once the app's repository tags `version-1.0` (build 1861), moving the pin on from `af41efa4`, past the merge of #1785 if the owner has merged it by then, or a pin move of its own after the merge. Phase 2 follows.

## Session 13a: a section's own text in Browse, over the API and in the browser app

23 October 2026 · branch `claude/s13a-browse-own-text-bcd2e3` · upstream `af41efa4`, unchanged

The first of the two items left before a web release: Browse lists the text a section prints outside the documents and sections it holds, first in the section, as the app's Browse does ([joshbotts/FRUS-Explorer#1536](https://github.com/joshbotts/FRUS-Explorer/issues/1536)). Which row that is, is the kit's rule, so no upstream pull request was needed and nothing waits for a pin move. S13b, the speed of exact-word search, ran in parallel.

**What the app does**, mapped at the pin:

- **The rule is the kit's.** `VolumeSection.ownTextRowId` and `ownTextEntry(among:)` (`FRUSCoreKit/Browser/VolumeStructure.swift`, public since #1640, index version 68): a section that holds a document or a section, and has an `xml:id` of its own, can have a row under that id, and `ownTextEntry` finds it among the volume's rows (`IndexingPipeline.documents(forVolume:)`), or finds none. A leaf, whose page is the section itself, and a section with a generated id never have one, and the parse makes no row of a list (persons, sources, a table of contents, an index).
- **Both Browse views ask it,** over the rows they already load: iOS's `BrowserViewModel.loadDocuments` keeps it in `compilationOwnText` and `CompilationView.ownTextSection` draws it; the Mac's `CorpusSectionDocumentView` does both. Each puts the row first in the section, above its sections and documents, as "Read %@" with the section's title (`browser.compilation.readSection`), over "The text this section prints outside the documents and sections it holds." (`browser.compilation.ownText.footer`), and opens the index's row. It shows no date and no count. Placing the row and those two localized strings are the app's whole part.
- **What 1.0 added is the kit's too** (#1746, index version 70): a section whose only text of its own is a footnote on its heading has a row, and so does a container whose heading carries one; a section's row is dated by its documents, which Search draws and Browse does not; and the reader's order (`mergeReadingSequence`) puts the row first in its section, and a chapter's opening subsection before its documents (`leadsWithSubsections`).
- **Front matter:** a row takes the front-matter flag of its section's kind, which Search's filter reads, and Browse lists it all the same. The fixtures' 393rd row, frus1969-76ve09p1's Note on U.S. Covert Actions, is a prose leaf the reader opens directly, not a section's own text.

**The API**

- `/volumes/{v}`: each section adds `hasOwnText`, `VolumeSection.ownTextEntry(among:)` over the index's rows for the volume.
- `/volumes/{v}/sections/{s}`: `ownText` is the row the rule finds, written as the section's documents are, with its title by the kit's rule for lists and whether the reader can open it; the key is left out when there is none.
- The rows are the index's, so a volume the server has not indexed lists none, as the app lists nothing before indexing, though the reader opens a section's own text from the TEI.
- A section's page made the set of documents the reader can open once for each document it listed, and the volume's page once for each top-level section; each now makes it once.

**The browser app**

- **A section's page** lists the row first, after the count, as **Read** and the section's title, a link to the reader described by the app's sentence beneath it. One the reader cannot open is named, not linked. A section that holds no documents shows no count of them.
- **The volume's contents** open a section with such a row on its page, as one with documents, where a section that holds only prose sections had linked to the reader or been named alone.
- **The reader** opens the row between the entries the kit's order puts around it: a meeting's own text after the conference's, and before its first document.

**Checked**

- **Over the kit's own fixtures,** since no fixture volume has such a row (FRUSParityTests, `OwnTextAPIParityTests`):
  - `fixtures/own-text` holds `SectionOwnTextTests`' and `IndexVersion70Tests`' volumes, each its suite's `volumeXML` at the pin, under the id the suite gives it; a test fails, naming the file, when a pin move changes either;
  - indexed by FRUSCoreKit and dropped into the drop zone as an export, every section of both answers as the kit's rule gives it, through the volume's page and its own: 36 sections, 19 that could have a row and 14 that have one, 11 in sections that hold documents, 3 in sections that hold only sections and 1 of a front-matter kind;
  - each row opens in the reader between the entries the kit's order puts around it, and its body is the one the app's reader path renders, a parse of that section alone, one with the seating plan the fixture prints;
  - over the three fixture volumes, 28 sections, 8 that could have a row: the kit finds none, and the API lists none;
  - the synthetic export's four rows of the kit's fixture, with the outline, are the kit's index of the file, column for column.
- **The routes** over the synthetic export (FRUSLightServerTests, `OwnTextRouteTests`): the conference's and the meeting's rows, the meeting's documents and neighbours, a section without a row, and the volume before an import and without its TEI.
- **A mutation:** with the section's page listing no row, both suites fail, the parity suite with 28 differences.
- **Over the owner's full 1776 export,** in a Compose project of its own, `frus-s13a` on port 8085, with this branch's image and the corpus clone at `6170e4b32`: `frus-parity own-text`, new, read every section's page and every row's neighbours through the API, and held them to the kit's rule over the export, read through the kit's read-only open:

  | Volumes | Sections | Could have a row | Have one | Holding documents | Holding only sections | Front-matter kinds | Reader opens | Differences |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | 553 | 25,115 | 20,052 | 4,896 | 4,615 | 281 | 19 | 4,896 | 0 |

  It took 278 seconds. A volume's page, or a section's, takes 0.4 to 0.6 seconds when the server parses the volume's TEI, which it keeps for the last four volumes, and otherwise 1 to 20 ms.
- **In Chromium,** the desktop app's browser, on that install: 1945 Berlin vol. II's Meeting of the Joint Chiefs of Staff, 10 a.m., lists "Read Meeting of the Joint Chiefs of Staff, 10 a.m." over the sentence, then Documents (1), at desktop and phone width, and its row opens between No. 710, the log of the President's trip, and the minutes, as the app's own walk found; 1919 Paris vol. XIII's Part III, a section of 14 sections, lists its row above them and no count of documents. The pane's screenshots leave every document's sandboxed frame blank, so the reader's text was read through the API, where the meeting's list of those present names Brigadier General Esposito.

**Records**

- `PLAN.md` and its shared copy (rev 201): the session intro, S13a's row and its answers, and in `PLAN.md` the flowchart.
- `SPEC.md`: Browse's section page, the API's two fields, and the check against a real export.
- `INSTALL.md`: Browse's row and the API's two fields.
- `COORDINATION.md`: §1's use of the kit for the rows, and the pin-move checklist's fixtures.
- `fixtures/own-text/README.md`, the README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 2,073 tests pass, up from 2,066, with the one named skip. FRUSParityTests runs 121, up from 116, and FRUSLightServerTests 110, up from 108; the other targets are unchanged, FRUSCoreKitTests at 1,147.
- **The browser app:** typecheck and lint are clean, and 89 unit tests pass in 15 files, up from 85.
- **`scripts/compose-smoke --e2e`** on this branch's image, `frus-light:smoke`, built locally: passes, with 21 browser tests on Chromium, up from 20. The new one, `own-text.spec.ts`, browses by keyboard to the conference and its first meeting, opens the meeting's own text in the reader, turns Next and Previous through the kit's order, and runs axe on each page. It finds nothing.

**Notes**

- **frus1969-76v01 and frus1945-50Intel in the fixtures are the kit's test volumes,** under real volume ids, as the kit's and the app's tests index them: in the browser suite's catalogue, Volume I, Foundations of Foreign Policy, holds the kit's conference.
- **The `frus-s13a` install** was removed with `docker compose down --volumes`; the owner's install on 8080 was left as it was.

**Next:** **S13b**, the speed of exact-word search, the last item before a web release, which runs in parallel. **S12d** follows once the app's repository tags `version-1.0` (build 1861), moving the pin on from `af41efa4`.

## Session 11f: the timeline and the concordance, over the API and in the browser app

23 October 2026 · branch `claude/s11f-timeline-concordance-97c312` · upstream `af41efa4`, unchanged

The last phase-1 feature row, held until the web edition caught up with FRUS Explorer 1.0: the search window's timeline and concordance readings, each naming the set it read, as the Mac's do. Both are computed with kit code that #1664 made public, so no upstream pull request was needed.

**What the Mac's window does**, mapped at the pin:

- **The Reading picker** (`ResultReading`, app code): List, Timeline, Concordance and Collocates, one segmented control in the toolbar, whose tooltip says which set each covers: "The concordance covers this page; the others cover the whole retained set."
- **The timeline** (`DocumentTimelineView`, app code) plots the window's `displayedResults`: the 7,500 results it keeps, in its order, less what Checklist Mode hides. It dates them with the kit's `IndexingPipeline.datesByDocumentKey(_:)`, groups them by the first four characters of each date, and shows a Chart or a List of each year's documents; a result with no date is left out and counted. Above it, when the results kept reach their ceiling, `ResultSetScope.timelineBiasCaption` says the shape is the ranking's.
- **The concordance** (`ConcordanceView`) is the kit's `SearchService.concordance(for:parameters:radius:)` over `pagedResults`, the page on screen, with the kit's radius of 60. Align by sorts the lines it holds by `KWICSort`; its count is `ResultSetScope.concordanceCountDescription`, which names the page when there is more than one; two notes say what the per-document bound left out and which documents gave no line.

**The API**

- **`/search/timeline`** takes a search's fields, with its page and order as they stand, and counts by year the results the app keeps of it. The years and counts are the kit's Years facet over the keys of those results (`resultSetFacets(parameters:request:documentKeys:)`, the kit's route for a list it describes by its keys), which keys a document by its date's first four characters, the rule the Mac's timeline groups by, and which its year filter matches (`substr(date_iso, 1, 4)`). The results kept are the date order's, kept for the last two searches, and they stop when no request waits for them; the facet over their keys reads only the rows they name, and is kept beside the panel's sections. With `documents=true` each year carries its documents, the results kept whose date the kit keys by that year, in the order `sort` gives them; `retainedCount` says how many were kept.
- **`/search/concordance`** takes a search's fields and its page, and gives the kit's lines for the documents of the page `/search` gives, by the draft's names (`keyword`, `characterOffset`), each with the title its row draws. `orders` gives each `KWICSort` order as positions in the lines, with the kit's labels in `orderChoices`, so the browser app changes the order without asking again. `omittedCount` and `documentsWithoutLines` are the kit's. The kit keeps its bound on one document's lines internal, so `linesPerDocumentLimit` gives it as read from the answer when it left any line out: a document it cut short gave exactly that many.
- **Neither counts the match,** which `/search` counts: over the full corpus an exact-word count takes about 20 seconds, so each count a reading added would have cost that again. The draft's concordance parameters are refused as `UNSUPPORTED_PARAMETER`, each with what this concordance does instead.

**The browser app**

- **Reading**, beside Sort, offers List, Timeline and Concordance, in the Mac's words and with its tooltip, and waits for a match, as the Mac's does. A search that found nothing says so in any reading. Collocates wait for phase 4.
- **The timeline:**
  - a chart of a column for each year, from the first year to the last, one series in one colour, with rounded data ends, a hairline grid and the dataviz validator's checks passing in both appearances; dark mode draws its columns in a step of its own, `#3987e5`, since the dark accent is too light for a mark;
  - the **Table of the counts** beneath it, the chart's text alternative, which the keyboard opens, and a line that names the year and count under the pointer;
  - its **List** mode, each year's documents under it, in the order Sort gives them;
  - the Mac's caption when the search reaches the 7,500 results it keeps, its line for the results with no date, and its view of none dated, alone;
  - no pager, since it covers every result kept.
- **The concordance:**
  - each occurrence on a line, the term in a column between its contexts, 60 characters a side in a monospaced face, so the margins line up;
  - wider than a narrow screen, the lines scroll sideways, as the Mac's do, opening with the terms in view, and each line's document stays at the left of what the screen shows;
  - **Align by** with the kit's four orders, Left context first, as the Mac's;
  - its count, "1,198 occurrences in the 20 documents on this page", its view of no aligned occurrences and its two notes, with the singulars the Mac's lack;
  - a line opens its document, and reads aloud as the Mac's VoiceOver label reads it.
- **The reading, the timeline's mode and the concordance's order are in the search's address,** so Back from a document shows the search as it was, as the Mac's window stays behind a document it opens. A new search, a facet's narrowing and a page keep them; another reading opens the timeline on its chart, as the Mac's does.

**Checked**

- **Through the API, beside the kit and the app's rule,** over the fixture index imported as an export (FRUSParityTests, `ReadingsAPIParityTests`):
  - every parity query's timeline with its documents, and a sixth of them in each order of the date, is the Mac's grouping of the 7,500 results the kit keeps: 439 timelines, 359 across more than one year and 208 with undated results, and 123 orders of the date that order a year's documents otherwise;
  - each year's documents are those the kit's own year filter keeps among the results kept, and where the search keeps its whole match, its count is the facet panel's over the match, the kit's other route to the same years: 46 years of 6 searches;
  - a match larger than what is kept is counted over what is kept: with 7 kept, the timelines of 8 searches are the Mac's over their 7 best, and none is the whole match's;
  - every fourth query's concordance, in pages of 7, by relevance and in both orders of the date, is the kit's for the page `/search` gives, in each of the kit's orders: 327 pages, 77 with documents that gave no line, 11 cut at the kit's 200 lines a document, which the answer gives, and 163 pages in an order of the date whose lines the date orders otherwise;
  - the sets both readings read are held to the app's source at the pin: the timeline's grouping, `displayedResults` and `pagedResults`, the kit's own radius, and the 7,500 results the window keeps.
- **The routes** over the synthetic export (FRUSLightServerTests, `ReadingRouteTests`): before an import, the three documents by year in each order, a document with no date, the lines of `negotiating` in each order, an exact word that gives no line, a search with no words, and each refusal.
- **Over the owner's full 1776 export,** in a Compose project of its own, `frus-s11f` on port 8083, with this branch's image, each reading asked first with nothing kept, then again:

  | Search | Matches | Timeline | Its list | Concordance, page 1 |
  | --- | --- | --- | --- | --- |
  | `soviet` | 58,679 | 1.5 s, then 2 ms; 7,500 kept, 70 years, 25 undated | 0.07 s, 1.5 MB | 0.29 s; 1,198 lines, 12 left out at 200 |
  | `berlin crisis` | 1,623 | 0.64 s, then 2 ms; 97 years, 39 undated | 0.02 s | 0.08 s; 367 lines |
  | `"long telegram"` | 136 | 0.05 s; 51 years | 3 ms | 0.03 s; 63 lines |
  | `=containment` | 352 | 29 s; 48 years | 6 ms | 25 s; no line, 20 documents unaligned |

  A timeline of an exact word abandoned after 3 seconds stopped: the next search answered in 34 ms. The facet over the whole match the timeline first used, which nothing stops, ran 20 seconds for `=containment`.

- **In Chromium,** the desktop app's browser, on that install: the chart over `soviet` in light and dark, its pointer readout, the List mode, and the concordance at desktop and phone width.

**A review before the pull request opened.** Two reviewers, one for the server and one for the browser app and the records, each checked their own findings against the code. Every finding below held, and all are fixed here:

- **The timeline's facet over the whole match could not be stopped,** and for a match larger than what is kept it ran for its count alone: the kit arms only a search's statements for stopping, so an exact-word search abandoned over the full corpus kept the server busy for about 20 seconds. The years are now the facet over the keys of the results kept, which stop when no request waits for them, and the timeline counts nothing. The browser app's caption reads the results kept, as the Mac's rule does.
- **A search with no words,** such as a person's, counted every document of its page as giving a line, where the kit builds none and counts none as giving none. The count is now the lines' own.
- **A year's documents drew their dates in words,** two to four date formatters each for up to 7,500, which the list never shows. The rows carry their title and label alone.
- **The chart's axis read "1961.5"** between two adjacent years: its step is a whole year at least.
- **A reading being asked again was dimmed** below the contrast WCAG asks, and another search's answer stood in for the next one at full strength. A reading now keeps only the same search's last answer while the next loads, as the list keeps its last page, and is never dimmed.
- **A reading that failed was not asked again** when the same search was made again, or when an index became ready.
- **Timeline, chosen again while it was shown,** reset its List mode, which the Mac's picker does not, and the view of no dated documents carried the modes and the undated note, which the Mac's does not.
- **The long lists rendered again on any change to the screen:** up to 7,500 rows of the timeline's list, and 20,000 lines of a concordance of 100 documents. They render again only when their answer or their order changes.
- **The draft's concordance parameters** were refused as unknown, and the timeline refused a search's page fields, which `/search/inspect` takes.
- **A parity test could trap** rather than fail on an answer longer than the kit's; SPEC's departures left out the draft's `total` and the two counts the answer adds; and the install guide said "larger than the 7,500" where the caption follows the Mac's rule, at 7,500.

Refuted, among others: a timeline key the panel's sections could share, a cache that could outlive its index, a year read from a date otherwise than the facet keys it, early years cut off by the facet's ceiling, the bound read from the answer, wording unlike the Mac's, and tests that compare a value with itself. Kept, and now said: a concordance line names its document by its row's title, where the Mac's label gives the stored header.

**Records**

- `PLAN.md` and its shared copy (rev 199): the session intro and S11f's answers.
- `SPEC.md`: the Search section's readings, and the API's two paths and their departures from the draft.
- `INSTALL.md`: Reading, the timeline and the concordance, the API, and the memory a timeline's kept results take.
- `COORDINATION.md`: §1's use of the kit for the readings.
- The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** after the review's fixes: all 2,066 tests pass, up from 2,054, with the one named skip. FRUSParityTests runs 116, up from 111, and FRUSLightServerTests 108, up from 101; the other targets are unchanged, FRUSCoreKitTests at 1,147.
- **The browser app:** typecheck and lint are clean, and 85 unit tests pass in 15 files, up from 68 in 14.
- **`scripts/compose-smoke --e2e`** on this branch's image, `frus-light:s11f`, built locally: passes, with 20 browser tests on Chromium, up from 18. The two new ones use the timeline's chart, its table and its list, and the concordance in two orders and over an exact word, each by keyboard, open a document from each and come Back to it as it was, and run axe on each. It finds nothing.

**Notes**

- **An exact-word search's readings are slow over the full corpus,** 25 to 30 seconds each, as its count and its page are, and the concordance fetches its page again where `/search` fetched it: the speed of exact-word search remains before a release.
- **The `frus-s11f` install** on port 8083, in `~/Library/Caches/frus-s11f/compose`, serves the full 1776 export from this branch's image, for the owner to try. `docker compose down --volumes` in that folder removes it and its 2.9 GB volume. The owner's install on 8080, S10's on 8081 and S12c's on 8082 were left as they were.

**Next:** Browse's own-text rows and the speed of exact-word search remain before a release. **S12d** follows once the app's repository tags `version-1.0` (build 1861), moving the pin on from `af41efa4`.

## Session 12e: pin move past FRUS-Explorer#1784, the page-map landing

23 October 2026 · branch `claude/determined-babbage-3d30b2` · upstream `af41efa4`

The pin moves from `f0479037` (`build-51`) to `af41efa4`, the owner's merge of [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784) the same day, and the server serves the landing 1.0 gives a page link into a volume the device does not hold (#1778). S12c's log offered this pin move of its own, under rule 5, so that the landing need not wait for `version-1.0` and S12d.

**What the move brought**

- **One commit.** `FRUSCoreKit/TEI/FRUSURLScheme.swift` gains `WholeVolumeLink` and `PageLink`, public and `Sendable`, from the app's `FRUSURLSchemeHandler.swift`, and `ReaderLinkTests`' three tests of them leave the app-only block, so FRUSCoreKitTests runs 1,147, up from 1,144. The rest is the app's records.
- **No repair.** The package builds with no warning, every kit suite passes, and the only skip is the named one. The build (1.0, 1776), the index version (71), the export's schema, the kit folders, `Package.swift`, the app's source folders and CI's allow-list are all unchanged, so `Compatibility.swift` and the install guide's versions stand.

**The landing**

- **The API.** The link route's `.page` case asks `PageLink.destination(page:volumeId:citing:onDevice:store:map:)`, as both of the app's readers ask it, with:
  - `onDevice`: whether the served index holds the volume, since the page ranges it reads are that index's;
  - `store`: the served index's `PageRangeStore`, opened immutably since S9c;
  - `map`: the bundled `cited-page-map.json`, decoded at start as the kit's `CitedPageMap` (`ServerResources.citedPages`), since the kit's own provider, `IndexingResources.citedPages`, is internal. A map that will not decode stops the server at start, naming the file, as the broken-refs index does.

  A `.document` lands as a cross-reference does. A `.volume` gives `volumeId`, `wholeVolumeLink` and `url`, as a reference to a whole volume does. No destination, for a page of a volume the index holds that neither the page ranges nor the map names, leaves the answer as it was.
- **A link that opens a volume** now carries `wholeVolumeLink`, where the kit's `WholeVolumeLink` sends it: `browse` for a volume the catalogue holds, `web` for any other, whose page is `url`. The browser app follows it, where it used to decide from the catalogue entry itself.
- **The browser app.** A page link to a document opens it as a cross-reference does; in a volume without its TEI here, the notice offers the document's page on history.state.gov. A page link to the volume opens the volume's page in Browse, which says first, for instance, "You followed a link to page 859 of this volume, which isn’t on this server.": the app's `FollowedPageLink.notice`, a localized string that stays app code, made the server's. For a volume whose TEI is here and which the server has not indexed, it ends "which this server hasn’t indexed".
  - The page is kept in that visit's history entry: Back and Forward to it, and a reload, name it again, and a visit by any other route does not.
  - The reader's old notice for a page of a volume the server has not indexed ("Page N is in …, which this server hasn’t indexed") is gone, since such a page now always leads somewhere.
- **Over the fixtures,** the 31 links into the 6 volumes the server does not hold go where the app's readers send them: 19 to the document the map names, 17 of which the index stores against it under rule C (frus1894Nicaragua d15's page 469 of frus1889 is d173), and 12 to the volume in Browse. Within the three fixture volumes, the parity test's 897 links to their pages land as before, 885 on a document: the map names nothing there that the page ranges miss.

**The golden files**, remade by `scripts/make-golden --export /Users/Shared/frus-index-build1776-golden.sqlite` under the app's `Scripts/heavy.sh` lock: the owner's 1776 three-volume export, reused on the owner's word, since `af41efa4` keeps build 1776 and changes no file on the indexing path.

- The 393 rows' HTML is byte for byte as before; the render's manifest, the expressions and the results change only in `sourceDigest` and `upstreamCommit`.
- The index summary's gating section, its 36 digests, 7 checks and volumes, is unchanged. Beside its provenance, only its information section's timings moved, which record how long this run took to hash each table.
- `frus-parity check-golden` passes.

**Tests**

- `ReaderLinkParityTests`: `everyPageLinkIntoAnotherVolumeIsWhereTheIndexStoresIt` holds each of the 31 links to `PageLink`'s answer with the volume not on the device, and asserts the 19, the 17 and the 12. `everyPageLinkLandsWhereTheAppsStorePlacesIt` asks `PageLink` with the app's own store as the device's page index, and no page of a volume on the device opens the volume.
- `ReaderLinkRouteTests`: a page the synthetic index lacks and the map names (frus1961-63v06's page 3, d4); Volume XIV's page 387, now d137; its page 859, which opens the volume in Browse; a page of the microfiche supplement, which opens on history.state.gov; a page before any import, which opens its volume; and `wholeVolumeLink` on each reference to a whole volume.
- `ResourcesTests`: the page map is decoded at start, and one that will not decode is refused, by name.
- The browser app: a unit test follows a page link into Browse and reads the line, in both of its wordings, on that visit alone. The browser suite's `page-map-landing.spec.ts` follows Nicaragua d15's link by keyboard to d173's notice, and d42's link to Volume XIV's page in Browse, with Back, Forward and a later visit from the catalogue, running axe on each. `browse-link-card.spec.ts`'s page test now shows a page nothing places, since d21's link to page 387 of Volume XIV lands on d137.

**Records**

- `PLAN.md` and its shared copy (rev 195): the session intro, the flowchart, S12e's row, S12d's row (from `af41efa4`, without the landing), the golden-files checkpoint, the risk row's counts and S12e's answers.
- `SPEC.md`: the reader's links, the API's answers for a page and a whole volume, the line a volume's page shows, and what the bundled page map serves.
- `INSTALL.md`: the page-reference bullet.
- `COORDINATION.md`: the pin; §1's use of the kit; §2's paragraph on #1784, which it lacked, and on this move; §5's list; and §6's exports, which now name S12b's of 22 October.
- `docs/prep/README.md`: the pin, and the landing served. The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Build and Test steps: all 2,054 tests pass, up from 2,050, with the one named skip. FRUSCoreKitTests runs 1,147 (from 1,144) and FRUSLightServerTests 101 (from 100); the other targets are unchanged, FRUSParityTests at 111. Against the remade golden files the run printed:
  - "check 2 passes: 36 digests and 7 checks are the Mac's";
  - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
  - "check 4 through the page: 393 of 393 rows identical".
- **The browser app:** typecheck and lint are clean, and 68 unit tests pass in 14 files, up from 67.
- **`scripts/compose-smoke --e2e`** on this branch's image, `frus-light:s12e`, built locally: passes, with 18 browser tests on Chromium, up from 16, and axe finds nothing.

**Notes**

- **Chromium takes a navigation to the address already shown for a reload,** which keeps the history entry's state, so `page.goto` of Browse's own address names the followed page again. The browser test's later visit comes from the catalogue.
- **Builds in a new worktree:** the Linux build reused S12c's `.build/linux` through an APFS clone (`cp -c`), so the package and its tests built in 68 seconds; `make-golden`'s two native tools built from empty, `mac-golden` in about 3½ minutes and `frus-parity` in 34 seconds.

**Next: S11f,** the timeline and concordance readings. **S12d** follows once the app's repository tags `version-1.0` (build 1861), moving the pin on from `af41efa4`.

## Session 12c: what FRUS Explorer 1.0 changed, over the API and in the browser app

23 October 2026 · branch `claude/s12c-what-1-0-changed-64c4b9` · upstream `f0479037` (tag `build-51`), unchanged

The S12 plan's third row: what 1.0 changed that the web edition serves, each as the app shows it. Three features are served here, the rows 1.0's index changed are checked through the API and the reader's links, and the one piece that is app code, where a page link into a volume the server does not hold goes, is [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784), which the owner merged the same day.

**A result's date** (#1746)

- **The API:** each search row adds the kit's `dateISOMax` and `datePrecision` (`day`, `month` or `year`), and `drawnDate`, the words the kit's `SearchResultDate` gives them: "July 16, 1945", "August 21, 1945 – January 22, 1946", "July 1945", "1862". The server passes US English, the language of the browser app's words, where the app's `SearchResult.drawnDate` takes the device's locale.
- **The browser app:** a row draws its dateline, or for a row that prints none the drawn date, as the Mac's window draws `result.dateline ?? result.drawnDate`.
- **On the full 1776 export,** a section's row is dated by the documents it holds: frus1862's ch23, "Guatemala and Salvador.", draws "July 29, 1862 – September 15, 1862", and frus1865p3's ch14, "Mexico.", "May 4, 1861 – June 9, 1866". The export holds 7,780 rows that are not documents, 5,707 of them dated, 4,245 by a span; build 50's held 4,182, 951 and 165.

**The reader's Reading Width** (#1699)

- **The API:** the page takes `readingWidth`, `narrow`, `standard` or `wide`, beside `textSize` and `colorScheme`, and passes the step's measure to `ReaderPage.build(measure:)`: 70, 87 or 120ch, the steps the app's Settings ▸ Display offers on an iPad and the Mac, Standard by default. Until now the server passed none, so every page had the kit's 70ch.
- **The ladder is app code** (`ReadingWidth.measure(on:)`), which the kit leaves to its host, so the server mirrors its three numbers. `ReaderPageParityTests` reads the rungs, and the setting's default, from the app's source at the pin: a pin move that changes one fails there.
- **The browser app:** Reading Width, a select beside Text Size, with the app's Narrow, Standard and Wide, kept in the browser as Text Size is. A page loaded again for another width leaves focus on the control, as Text Size and Appearance do.
- **In Chromium,** measured on the Long Telegram (frus1946v06/d475) at Medium text, the app's own test document: a mean 69.5, 91.2 and 133 characters a full line at the three steps, where the app's WebKit gives 77, 100 and 145. The install guide gives both.

**A search whose client goes stops** (#1698)

- **What S10 found:** a request its client abandoned ran on; after the timeouts the server went on computing those searches.
- **The server:** Hummingbird allows half-closure and cancels nothing when a client goes. Each connection's pipeline now holds a handler that notices the client's side closing, the input closed or the connection gone, and the API's request context keeps its connection. `/search` and `/search/inspect` run their work while the client is connected: when it closes, the work is cancelled, and the kit's one progress handler (`SearchStatementStop`) stops the statement at its next call. The problem middleware logs it at debug level and answers 499, which reaches no one.
- **The kept results:** the cache of what a served index computed lately makes a waiting request leave at once when it is cancelled. The results a date order keeps are stopped once no request waits for them, as the Mac stops a replaced search; a facet section runs to its end and is kept, since nothing stops the kit's facet pass on the Mac either.
- **The browser app** already abandoned a search it replaced: TanStack Query aborts a fetch whose query loses its last observer, and the browser then closes the connection. A unit test pins it.
- **On the full 1776 export,** an exact-word search (`=Soviet`) whose client gave up after a few seconds: with S12b's image the server held a core at 100% for at least 25 seconds after; with this branch's, it was idle within about a second, and its log said "GET /api/v1/search stopped: the client closed its connection before the answer".
- **End to end in Chromium,** the desktop app's browser, on the same install: an `=Soviet` search from the box, then another typed over it while the first ran. The server logged the first one's stop and was idle by the next sample, and the second answered, 722 documents.

**The pages and rows 1.0's index changed** (#1746, #1747)

- **A section's row dated by its documents** comes through the API with its span and its words, as above.
- **Cross-volume page references under rule C:** the fixture pages hold 31 links to a printed page of another volume, into 6 volumes. Through the API each is that page, which this server, holding only the three fixture volumes, cannot place. The bundled page map names a document for 19 of them, and 1.0's index stores 17 of those against it, frus1894Nicaragua d15's page 469 of frus1889 becoming d173 among them; the rest the index leaves on the page. A new parity test asserts each link's answer and those counts.
- **The landing** the app gives such a link since #1778 is `PageLink`, app code until #1784; the web edition serves it from the pin move past `af41efa4`. `docs/prep/README.md` says how.

**The upstream pull request:** [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784), "Where a link to a whole volume or a printed page goes is FRUSCoreKit's, so FRUS Explorer Light can follow one as both readers do", labelled `Mac`, with "Mac verification requested".

- **The change:** `WholeVolumeLink` and `PageLink` move, unchanged but for `public` and `Sendable`, from the app's `FRUSURLSchemeHandler.swift` to the end of the kit's `TEI/FRUSURLScheme.swift`; `FollowedPageLink` stays. `ReaderLinkTests`' three tests of them leave the app-only block. One editable-content block is re-pointed, and `CLAUDE.md` and the app's plan record it.
- **Run here, from a clone at a real path, each heavy job under the app's lock, beside `v2` built and run the same way:**
  - `FRUSExplorerMac`, Debug, clean, unsigned: built, with `v2`'s five warning lines. The two debug dylibs hold the same 249,388 symbols, 245,175 defined: no symbol changes;
  - iOS 27.0 on an iPhone 17: a clean `build-for-testing`, with `v2`'s 7 warning lines; the full unit target, 7,606 tests in 900 suites, with the 8 Keychain issues an unsigned build has, as on `v2`, and the same 17 tests and 2 suites skipped;
  - `swift build --target FRUSCoreKit`, and `swift test`: 38 runs, 3,033 tests, all passing, none skipped, against 3,030 on `v2`; `FRUSCoreKitTests` 1,147, up from 1,144;
  - `CodingStandardsAuditTests` again at the records commit: 63 passed;
  - Linux: this package at `main` with the branch over its submodule: FRUSCoreKitTests 1,147, every other target passing but the parity suites, whose 13 issues are all golden-file staleness.
- **Merged** by the owner on 23 October as `af41efa4`, a squash of the branch's two commits whose tree is the branch's head byte for byte, now `v2`'s head; no Mac check results were posted on it. The pin stays at `f0479037` here: it moves only in a pull request of its own (rule 5).

**A review before the pull request opened.** Three reviewers, one for the server, one for the browser app and the records, and one for #1784, each checked their own findings against the code. None found a correctness defect. Every finding below held, and all are fixed here but #1784's records:

- **Turning the date order round while the kept results were computed** would have started them again. The abandoned request left the computation with no one waiting, so it was stopped, and the replacing request, for the same search, came too late: its count waited behind that computation's statement. A request now joins the kept results before it counts, and a computation no one waits for runs on for 250 ms before it is stopped, so the replacing request joins it. A test holds the grace.
- **No test failed if the server lost its watch:** the live test built an application of its own. Both now build it with `apiApplication`.
- **Two tests waited on sleeps.** The cache's and the closure's now wait for their waiters to register, and the closure's also covers a waiter cancelled while it waits.
- **A request whose client had already gone** started its work before stopping it; it now stops at once. A connection reset outright before its route asks has no pipeline left and is not watched, which the code now says; a browser that abandons a request closes with a FIN, which the half-closed pipeline keeps.
- **The browser suite's measure** read the frame by its URL and could throw while the frame was between pages; it reads the frame shown, through a locator that waits for its column. The abandoned-search test held the first search for a fixed two seconds; it now holds it until the page has abandoned it.
- **The install guide** gave Chromium's line lengths without saying so; it gives the app's too. SPEC named the app's wrong route for the measure, and its focus sentence left out Reading Width.
- **The rule-C test** printed its 19 and 17 and asserted neither; it asserts both.
- **#1784's records** say "unchanged and public" where the types are also `Sendable`, and `FRUSURLScheme`'s own history logs no move. It had merged by then, so these wait for the next web-authored upstream pull request (Notes).
- A doc comment the new parity test had pushed above the wrong test is back on its own.

Refuted, among others: a double resume or a lost wakeup in the closure or the cache, a close the pipeline would not deliver, a facet section stopped while it was still wanted, an abort test that could pass for the wrong reason, and wording unlike the Mac's.

**Records**

- `PLAN.md` and its shared copy (rev 188): the session intro, S12d's row, Mac check 7, done once #1784 merged, the risk row and S12c's answers. The file's flowchart gains Mac check 7; the shared copy's diagram covers phase 1's sessions only, as before.
- `SPEC.md`: the reader's measure, the search rows' dates, a replaced search, and the API's `readingWidth` and date fields.
- `INSTALL.md`: dates in the results, a replaced search, Reading Width and the API's `readingWidth` and `drawnDate`.
- `COORDINATION.md`: §1's use of the kit at the 1.0 pin with the Reading Width mirror, and §5's list of web-authored pull requests, with #1784.
- `docs/prep/README.md`: how to serve the landing after #1784 merges. The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Test step, after the review's fixes: all 2,050 tests pass, up from 2,037, with the one named skip. FRUSLightServerTests runs 100, up from 91, and FRUSParityTests 111, up from 107; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 67 unit tests pass in 14 files, up from 64 in 13.
- **`scripts/compose-smoke --e2e`** on this branch's image, built again after the review's fixes: passes, with 16 browser tests on Chromium, up from 13. The new ones draw the rows' dates, use the Reading Width from the keyboard with its measure read from the page, and replace a search under way, and run axe after each; the note-focus test also changes the Reading Width. It finds nothing.

**Notes**

- **The S12b install** on port 8082, `frus-s12b` in `~/Library/Caches/frus-s12b/compose`, now runs this branch's image, `frus-light:s12c`, over the full 1776 export, for the owner to try. `docker compose down --volumes` in that folder removes it and its 2.9 GB volume. S10's install on 8081 and the owner's on 8080 were left as they were.
- **A client that half-closes** its connection while it waits for an answer is taken to have gone, as Go's server takes it. No browser does; `nc -N` would.
- **#1784's records, for the next web-authored upstream pull request:** the moved types' version-history lines, the handler's 1.10, `CLAUDE.md` and the amendment log say "unchanged and public" and leave out `Sendable`, which the pull request's body and the app's session entry name; and `FRUSURLScheme`'s own history logs no 1.4 for the move. A review found them after the merge, with nothing else; none changes what the code does.
- The upstream clone, its build folders and a scratch worktree of this repository are under `~/Library/Caches/frus-s12c`.

**Next: S11f,** the timeline and concordance readings, since the app has not tagged `version-1.0`. **S12d** follows once it does, and serves the page-map landing too, since #1784 merged first; a pin move of its own to `af41efa4` can serve the landing sooner, if the owner wants it before the tag.

## Session 12b: pin move to `build-51`, FRUS Explorer 1.0 (build 1776)

22 October 2026 · branch `claude/s12b-pin-build51-544354` · upstream `f0479037` (tag `build-51`)

The pin moves from `757c6d29` (build 50, index version 69) to `f0479037`, the commit the owner tagged `build-51`: FRUS Explorer 1.0, build 1776, the TestFlight build, at index version 71. It is 85 commits on, with the 18 pull requests on shared code or bundled data that [issue #37](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/37) lists. The owner made both 1776 exports on 22 October: three volumes for the golden files, and the full corpus.

**What the move brought**

- **Index version 71** (#1746, 70; #1747, 71). `IndexCompatibility.supportedIndexVersion` follows the pin, so the server now refuses build 50's exports, naming both versions. The FTS generation (4) and the JSON export's `formatVersion` (6) are unchanged.
- **A fifth indexing resource,** `cited-page-map.json` (#1747), which `IndexingResources.indexResourceNames` now names. `ServerResources.requiredFiles` follows that list, so the server will not start without it, and the image already copies the whole resources folder.
- **No repair.** Every kit builds and passes on Linux with no new skip, as issue #37's dry run found, and no kit folder, `Package.swift` setting or app source folder changed. The web edition's own code changed only in tests, a doc comment, and the facts below.
- **The export's schema is unchanged.** Both 1776 exports hold `export-v69-schema.sql`'s 74 statements, in its order, and nothing else but FTS5's shadow tables, which the fixture leaves out by design. `setupDatabase(_:)` is the same text at the new pin, lines 7680–8335. So the fixture stands, under its name, and `IndexSchema.swift`'s list with it.
- **No pinned reader head to re-take** (#1699). No web test pins `ReaderPage`'s head: the parity tests compare the page with the kit's own build of it. The server builds the page with `ReaderMeasure`'s default, `.classic`, until S12c brings Reading Width.

**The golden files**, remade by `scripts/make-golden --export /Users/Shared/frus-index-build1776-golden.sqlite`, run under the app's `Scripts/heavy.sh` lock:

- **The render:** 393 rows, not 392. The new one is frus1969-76ve09p1's `notes`, its Note on U.S. Covert Actions, one of the prose rows the index left out until #1746 (`promotableQuasiDocumentKinds`). The other 392 rows' HTML is byte for byte as before, and the manifest changed only in provenance and that row.
- **The expressions:** 15 of the 482 queries compile differently, all by parser 6.8 (#1770), which trims a mark from a term's end: `"europe,"` is now `"europe"`, `"u.s.s.r."` `"u.s.s.r"`, `"-berlin"` `"berlin"`, `"‘test"` `"test"`, and so on. 43 are refused, as before.
- **The index summary:** its 7 checks and the schema's digest are unchanged, and 18 of its 36 gating digests moved, each with a pull request:
  - #1746's notes row: `document_cache` and its sequence, `document_dates`, `document_revisions` (also every row at 71), both FTS tables' `docsize` and `averages`, the three vocabularies, and `page_ranges` and its sequence (pages xxii–xxvi);
  - `cross_references` and its sequence, 208 rows to 221: the notes row's 13 references (#1746), and 17 references to a printed page of another volume that now name the document on it, `frus1889`'s `pg_469` becoming `d173` and the like (#1747, rule C through the page map);
  - `volume_structures`: each of the 28 sections records `leadsWithSubsections`, false for every one (#1746);
  - `volume_sources`: frus1969-76ve09p1's "POL Libya" row is keyed `POL LIBYA`, a file with no subject number that leads its row (#1746);
  - `person_rollup`: 75 of the 121 rollups lose a VIAF id, since build 51 takes no Wikidata or VIAF link from the name-authority overlay (#1710).
- **The results:** every query's score bits moved, since BM25 reads the whole index and the index has a row more. 41 counts rose by one, and in each the notes row matches the query's compiled expression; other changes in the top 50 are reorders by those scores. Ties past the 50th place fell from 12 queries to 7.
- `frus-parity check-golden` passes.

**The tests that named build 50's facts**

- `APITests.theSubmodulesDataFilesLoad`: 6 required files, the last `cited-page-map.json`. `IndexResourcesTests` lists the five index files and decodes the page map, built for the pin's index version.
- `SummarizerTests`: the summary's build is 1776. The parity export now stamps the pinned app's version as well as its build, both read from `project.yml`.
- `ServedAPIParityTests`: the fixture index holds 393 documents.
- **The snippet rule** (#1736): `aSnippetMarksAMatchOnlyInTheProse`, new, serves a synthetic export whose body opens with its heading and dateline. A word matched in the prose is marked; one matched only in the heading or dateline gives the prose's opening with nothing marked; one only in a heading the body does not repeat gives the heading again. The existing test that every row has `<b>` still holds, since both of its rows match in their prose. `SearchItem`'s doc comment says so.

**Release tags**

- **`scripts/release-tag`** prints `<version>-<build>` from the pinned `project.yml`'s `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`: `1.0-1776` here, and `0.2-50` at the old pin. It fails when the app's targets disagree, when either is missing, or when either is not numbers and dots.
- **`image.yml`** reads it in each build job, so every pull request that touches the image checks it, and the promote job, after the smoke test on both architectures, moves the release tag with `edge`: `:1.0-1776` follows `main` while the pin holds build 1776, and stays on the last such build once the pin moves on. Sessions never publish (rule 7).
- `docs/INSTALL.md` and SPEC name the release tags.

**Checks 3–5 on the full 1776 export**, as S10 ran them:

- **The install:** a Compose project of its own, `frus-s12b`, with `compose.yaml` and a `.env` naming the port, the TEI folder and the image. The port is 8082, since S10's install still holds 8081 and the owner's 8080, and both were left as they were. The image is this branch's, `frus-light:s12b`, built locally from the code of `5c59c6b`, since sessions never publish. The TEI folder is the owner's clone of HistoryAtState/frus, read-only, at `6170e4b32` (1.1.4), the corpus #1746 measured its rows on.
- **Check 5, import acceptance:** the full export was ready 43 seconds after the copy began, serving 321,749 documents from 553 volumes at index version 71. Read immutably, it holds no summary, note or tag and no `user_tags` row, and its `user_content` index no term. The refusal half, and `scripts/check-stripped-export`, need an export with the owner's writing from build 1776, which there is not; the refusal's code is unchanged since S10, and the server's tests refuse a synthetic export that holds writing.
- **Check 3:** `mac-golden results --any-volumes` ran the app's SearchService over a copy of the export in 31 minutes 11 seconds: 482 queries, 43 refused, 9 with ties past the 50th. `frus-parity results --api` read the same queries through the install's API: 886 requests in 37 minutes, none timing out. `frus-parity compare-results` printed "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups"; 392 queries have other score bits, which is information, as on build 50 (349).
- **Check 4:** the sample is the middle row that is not front matter in each of the 553 volumes, in index order, now drawn from the 1776 export. Five have an id other than `d` and a number, such as frus1943v06's `ch44`, an agreement, and frus1958-60v05mSupp's `gt_d10`. `mac-golden render --tei --rows` rendered them through the Mac reader's path in 1 minute 57 seconds, 5,652,473 bytes of HTML. `frus-parity render-api` fetched each one's body from the server and compared the bytes: "check 4 through the API: 553 of 553 rows identical", in 2 minutes 38 seconds. No row in this sample has a figure image; S10's had 14 in 2 rows.
- Each run took the app's `Scripts/heavy.sh` lock, one at a time, as the image build had.

**Records**

- SPEC: the compatibility contract (71 at `f0479037`, app 1.0 build 1776); the table definitions' lines; the image's tags; the bundled data, with `cited-page-map.json`, the resized citation and semantic files, 54 MB in all, and the Legal row gone; and the licensing lines: EmbeddingGemma 2 is Apache 2.0, from the `encoder-2` release, downloaded only at an admin's request, with no consent screen, since the Gemma Terms file is gone from the bundle (#1674). The shards' address names their generation, `generations/89481b18/`. The corpus figures follow 1.0: a full index holds about 322,000 documents, and the semantic map places 314,616 in 140 clusters.
- `INSTALL.md`: index version 71 and FRUS Explorer 1.0 (build 1776), the second version change, and the release tags.
- `COORDINATION.md`: the pin, the contract, the kit's test counts, the 393 rows and this move.
- `PLAN.md` and its shared copy (rev 180): S12b done, the golden-files and 1776-export checkpoints, the risk row's counts, and the release tag's rule.
- The README's Status, as #40 rewrote it, merged here from `main`: only what the move makes untrue, the gap behind 1.0 and S12b's line under Next. The prep note and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 2,037 tests pass, up from 1,934 at the old pin, with the one named skip, which CI's skip check allows.
  - By target: FRUSCoreKitTests 1,144 (from 1,061), SourceNoteKitTests 321 (310), FTS5StoreTests 212 (209), FRUSParityTests 107, FRUSLightServerTests 91 (90), ManifestGeneratorTests 60, FRUSLightCoreTests 42, SemanticVectorsKitTests 40 (35), CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
  - Against the remade golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 393 of 393 rows identical".
- **CI** passes on this pull request, with the same counts and the one named skip. Both architectures' image builds read the release tag `1.0-1776`, and the web app's checks and the Compose smoke test with the browser suite pass.
- **On the owner's full 1776 export:** checks 3, 4 and 5's acceptance half pass, as above.

**Notes**

- **Exact-word searches are still slow** over the full corpus: the slowest requests took 57 seconds through the API, against 66 at build 50, with nothing else running. Check 12 is phase 5's.
- **The new prose rows are front matter where `<front>` prints them.** The notes row of frus1969-76ve09p1 is one (`is_front_matter` 1, no date), and the Mac's search counts it, as the server's does; Browse's own-text rows remain before a release.
- **The owner's own install** on port 8080 serves the build 50 export. Once it runs an image at this pin it refuses that export, naming both versions, until the full 1776 export is copied in.
- **The S12b install** on port 8082, `frus-s12b` in `~/Library/Caches/frus-s12b/compose`, still serves the full 1776 export from the local image. `docker compose down --volumes` in that folder removes it and its 2.9 GB volume. S10's install on 8081 was left running.

**For the owner after the merge**

- `image.yml` publishes `ghcr.io/joshbotts/frus-explorer-light:1.0-1776` beside `edge` and the commit's `sha-` tag, once the smoke test passes on both architectures.
- Your own install then needs the full 1776 export: `docker compose pull && docker compose up -d`, then `docker compose cp -L /Users/Shared/frus-index-build1776-allvols.sqlite frus:/data/import/`, as `docs/INSTALL.md` says.

**Next: S12c,** what 1.0 changed that the web edition serves: a result's date range and precision, the reader's Reading Width, a replaced search stopping its statements, and the rows 1.0's index changed, with the upstream pull request for the page-map landing. **S12d** follows once the app's repository tags `version-1.0` (build 1861).

## Session 12a: the daily watch of `v2`

22 October 2026 · branch `claude/s12a-upstream-watch-b8c058` · upstream `757c6d29`, unchanged

The owner approved the plan of [issue #37](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/37)'s revision and asked for S12a: the daily watch COORDINATION §5 gives web sessions, whose absence let 85 of the app's commits go unseen.

**The watch**

- **`.github/workflows/upstream-watch.yml`** runs daily at 06:17 UTC and from the Actions tab's Run workflow, with a ref other than `v2` and a dry run as options. It needs `contents: read` and, in its report job only, `issues: write`. It never moves the pin and never publishes.
- **`scripts/upstream-watch`** does the work, and each step also runs on a Mac:
  - `checkout` moves the submodule's working tree to `v2`'s head inside the job, never staging it;
  - `test`, in `swift:6.4-noble` with ci.yml's cache restored and this package's targets built clean, builds the package and runs each test target on its own. A build break or a kit suite's failure is the watch's finding, and fails the scheduled run. This package's own tests check the pin's facts, so they fail past it by design, and are listed by suite as information for the pin move;
  - `report` compares `v2` with the pin: the index version, the FTS generation, the JSON export's `formatVersion`, `indexResourceNames`, FRUSCoreKit's and FTS5Store's `CREATE TABLE` and `ALTER TABLE` statements (read from the sources, with Swift's interpolations kept whole), the bundled resources added, changed or removed, and the commits since the pin, whose pull-request numbers sit in code spans so they neither link here nor mention the app's pull requests;
  - `issue` keeps one issue labelled `upstream-watch`: it opens one when `v2` is past the pin and none is open, otherwise rewrites the open one's description, and comments only when `v2`'s head or the kits' result changed. When nothing is past the pin and the kits pass, it closes the issue.
- **On a pull request** that changes the watch, the workflow runs at `v2`'s head in its dry mode: it prints the issue writes, and fails on nothing `v2` does. Its jobs, `watch-selftest`, `watch-kits` and `watch-report`, are not `main`'s required checks.

**Checked**

- **A run at `v2`'s head** (`f0479037`, `build-51`), locally in `swift:6.4-noble` on arm64 and in this pull request's dry run on CI: index version 69 → 71, the FTS generation 4 and the export's `formatVersion` 6 unchanged, `cited-page-map` the sixth index resource, `cited-page-map.json` added and `gemma-terms-of-use.txt` removed among 15 resource changes, the 47 schema statements unchanged, and 85 commits. Every kit suite passes, with the counts issue #37's dry run found (FRUSCoreKitTests 1,144, SourceNoteKitTests 321, FTS5StoreTests 212 with its one allowed skip, ManifestGeneratorTests 60, SemanticVectorsKitTests 40, CrossRefKitTests 10, GeneratorKitTests 7). FRUSLightCoreTests, FRUSLightServerTests and FRUSParityTests fail where S12b expects.
- **The issue logic,** by `scripts/upstream-watch selftest` against a stub `gh`, in CI's `watch-selftest`: no issue while nothing is past the pin; one opened; a second run at the same head updates it with no comment; a new head updates the same issue with a comment; a dry run finds it and writes nothing; it closes when nothing is past the pin, and a later change opens a new one. A dry run against this repository, which has no watch issue yet, would open one.
- **The schema reader** was checked against the upstream commit that moved the index's tables into FRUSCoreKit, where it reports all 42 of that kit's statements as new.

**Records**

- `COORDINATION.md`: §1 and §3 no longer say the watch is to come, §5's row and a paragraph below its table say what it does, and §6 says what its issue is for.
- `PLAN.md`, on top of PR #38's revision, merged while this one was open, and its shared copy (rev 174): an owner checkpoint for the watch's first run, which S12a's done-when needs and only the owner can make once the workflow is on `main`. This log.

**For the owner after the merge**

- The first run: Actions → upstream-watch → Run workflow, on `main`, with `v2`. It opens the watch issue with the report above; the label is created on that run.

**Next: S12b, the pin move to build-51 (build 1776).**

## Issue #37: the plan catches up with FRUS Explorer 1.0

22 October 2026 · branch `claude/issue-37-dev-plan-revision-846914` · upstream `757c6d29`, unchanged

The owner asked for issue #37 to be reviewed, and the plan revised to catch up with the app before feature work goes on. The issue, posted from a session in the app's repository, finds `v2` at `build-51` (`f0479037`, build 1776, the 1.0 TestFlight build), 85 commits past the pin, at index version 71. No web session had seen those commits: the daily watch COORDINATION §5 assigns to web sessions was never added. This session changes records only.

**Checked against the app's repository**

- Each fact the next pin move depends on holds at `build-51`:
  - `currentDateIndexVersion` is 71;
  - `cited-page-map.json` is added to the bundled data and `gemma-terms-of-use.txt` removed, with the other changed resources the issue lists;
  - 85 commits separate `build-51` from the pin.
- Each of the 17 pull requests' lines for the web edition was read. #1778 changes no kit code, but its page-map landing is app code the web reader would need, so S12c moves it into the kit.
- **A dry run at `build-51`** built and tested this package on Linux, then restored the pin. The build needs no repair, and every kit suite passes, with only the skip CI already allows. The web edition's own tests fail where a pin move expects: the index version, the sixth resource file, stale golden files, 61 expressions under parser 6.8, and a 393rd fixture row. `docs/prep/README.md` records it, under "The 1.0 pin move".

**The plan**

- **S11f waits.** Four rows come first:
  - S12a, the daily watch of `v2`, which needs no Mac and no export;
  - S12b, the pin move to `build-51` (1.0, build 1776), for an image tagged `:1.0-1776`;
  - S12c, what 1.0 changed that the web edition serves: result dates and their precision, the reader's Reading Width, a replaced search stopping its statements, and the rows 1.0's index changed. Its upstream pull request moves #1778's page-map landing into the kit;
  - S12d, the short pin move to `version-1.0` (build 1861) once it is tagged, for `:1.0-1861`.
- **Owner checkpoints:** a 1776 export and an 1861 export, each a three-volume one for the golden files and a full one for the owner's install, and Mac check 7.
- **The upstream-churn risk** now records the gap, and the watch as its mitigation.
- **The S12 answers** say which 1.0 changes come with the pin, which wait for phases 2–4, and what remains before a release. The owner answered the one question it left open: a release image is tagged with the app's version and build, `:1.0-1776` and `:1.0-1861`, joined by a hyphen since a tag cannot hold the slash asked for, and asked for both to be published, so the pin lands at `build-51` before `version-1.0`.

**Records**

- `PLAN.md` and its shared copy (rev 173): the S12 rows, the flowchart, the checkpoints, the risk row and the S12 answers.
- `COORDINATION.md`: the gap, and S12a as the watch's author.
- `SPEC.md`: the release tags.
- `docs/prep/README.md`: the dry run. This log.

**Results**

- No code changed. CI runs as it does on any pull request, at the pin.

**Next: S12a,** the daily watch of the app's `v2`. S12b can start beside it at `build-51`: the owner made both 1776 exports the same evening, the three-volume one (393 rows) and the full one (553 volumes), each stamped build 1776 at index version 71.

## Session 11e: the Query Inspector, and the date order

14 October 2026 · branch `claude/s11e-search-readings` · upstream `757c6d29`, unchanged

The owner merged #35 and asked for S11e. A reader mapped the Mac's search window: its Query Inspector strip and its view of a search that found nothing, the sort bar, and the timeline and concordance readings with the captions that name what each counted. The four were again too many for one reviewable pull request, as S11d's had been, so this one brings the Query Inspector and the date order, and S11f brings the timeline and concordance readings.

**The API**

- **`/search/inspect`** keeps `parse` and `search`, the expression records check 3 reads, and adds `inspection` while an index is served: the kit's `QueryInspection`, from the Query Inspector's cheap pass, `QueryInspector.inspect(parameters:indexedVolumeCount:)`, out of the volumes the index holds. It runs no search.
  - Each term comes with its tags, its index form, its corpus counts from `fts5vocab`, and the gates the strip reads.
  - `scopedCounts=true` adds each term's count within the filters, and `emptyConjuncts=true` names the terms that match nothing on their own, the kit's two expensive passes. Each runs one count a term, and is refused with `INDEX_NOT_READY` until an index is served.
  - A query of more than 64 terms is compiled but not looked up, and either pass is refused for it as `TOO_MANY_TERMS`: each term costs the index statements of its own, run one after another on the connection every search shares.
- **`/search` takes `sort`**, a `SearchSortOrder`. By relevance a page is the kit's page of the match, as before. In either order of the date it is cut from the 7,500 results the search keeps, sorted whole by `SearchSortOrder.sorted(_:)`, as both of the app's view models sort what they keep. Every list names its order and offers the three by the kit's labels.
- **What a served index computed lately** is one type now, `RecentComputations`, which keeps the facets' 16 sections and the results of the last 2 searches ordered by date, so a search's other pages fetch them once.

**The browser app**

- **The Query Inspector's strip**, under the filters, follows the box's text as it is typed, before the search is made, as the Mac's does: the text trimmed and the filters, asked for once typing pauses for 300 ms. It shows MATCH and the expression, with the caption for one narrower than typed, or the one line that says why there is none.
- **Its term detail**, behind the Mac's ▾ (**Show term detail**), lists each term with its tags (EXCLUDED, EXACT, ADVANCED), its counts and the stem that widens it, then each part left out (NOT APPLIED), and the denominator. **Count each term in scope…** counts each within the filters, and the counts go when the text or a filter changes.
- **A search that found nothing** says why in the Mac's words, from each of its terms searched alone under its filters: "formosa matches no document in your current scope", or that the combination is what matches nothing.
- **Sort** offers Relevance, Date ↑ and Date ↓, which start the order at its first page, and the order outlasts a new search and a facet's narrowing, as the Mac's does.
- **A match larger than what a search keeps** says so above the results on every page, in the Mac's words: "Showing 7,500 of 20,000 matches", and how to narrow it. It replaces the web's own note on the last page.
- **The facets' "The top three hold" caption** is no longer given of such a match, as the Mac's panel withholds it: a figure over the most relevant 7,500 is partly a statement about the ranking.

**Checked**

- **Through the API, beside the kit,** over the fixture index imported as an export (FRUSParityTests):
  - every one of the 482 parity queries is inspected as the kit inspects it, with its scoped counts and the terms that match nothing; between them they reach every state the inspector reports, from an expression that differs between documents and the reader's writing to a malformed NEAR;
  - every page of a sixth of the queries, in each order of the date, in pages of 7 and of 100, joins up to the kit's order of what the search keeps, undated documents and documents of one day among them;
  - the browser app's line for a refused query names the parser's limit on nesting, which the test reads from FTS5Store itself.
- **The Mac's strings** are the browser app's wherever a control is the same, with "this device" and "you have indexed" made this server.

**A review before the pull request opened.** Two reviewers, one for the server and one for the browser app and the records, each checked their own findings against the code. Thirteen held. Eleven are fixed, one is kept and now said, and one is left as the Mac leaves it:

- **The view of a search that found nothing** could run over the last search's page while the next loaded, and blame a search that had matches. It waits for the search shown to be the one made, as the Mac's view waits.
- **The expensive passes could run unasked:** counts came back when the text returned to what was counted, and a window regaining focus asked again. They run only when asked, or when a new index is served.
- **A failure to ask again** replaced a good answer with the generic line, and making the same search again did not ask again.
- **The strip showed the last query's expression** while the next was asked for after the box was emptied.
- **The date order over a larger match** read as the oldest of all of it. The Mac's notice now says what the search keeps, and the install guide qualifies the order.
- **The figure per document** rounded a tie away from zero, where the Mac's formatter rounds half to even.
- **Every keystroke rendered the whole screen.** The text is held by the search box, the filters and the strip.
- **Pasted text could tie up the server:** the inspector looked up every term of a query of any length. It looks up 64 at most.
- **A test could not tell** whether a scoped count read the filters, and the records said "waits" of a refusal, named a control that shows only ▾, and claimed more of the cache than it does.
- **Kept, and now said in SPEC:** `/search/inspect` takes a search's page and order too, which change nothing it says, so a search's address can be inspected as it stands.
- **Left as the Mac leaves it:** a search ordered by date that no request waits for any more still fetches what it keeps, to its end. The cache now keeps 2 such searches, not 4, and the install guide says what they hold.

Refuted, among others: a string unlike the Mac's; inspector queries that could collide or never refresh; cache keys that could join two searches; the denominator, which is the count the Mac's `indexedVolumeIds` holds; and parity tests that could pass while comparing a value with itself.

**Records**

- `PLAN.md` and its shared copy (rev 155): S11e's row, S11f's, and the S11 answers.
- `SPEC.md`: the Search section, and the API's `sort` and `/search/inspect`.
- `INSTALL.md`: Sort, the Query Inspector, the date order's limit and its memory. The README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through the Test step's own script: all 1,934 tests pass, up from 1,928, with the one named skip. FRUSParityTests runs 107, up from 104, and FRUSLightServerTests 90, up from 87; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 64 unit tests pass in 13 files, up from 50 in 12.
- **`scripts/compose-smoke --e2e`:** passes, with 13 browser tests on Chromium, up from 11. The two new ones use the Query Inspector as it is typed, its counts in scope, a search that found nothing, and both orders of the date, and run axe with the term detail open, over the view of a search that found nothing, and in the date order. It finds nothing.

**Notes**

- **A search ordered by date** fetches the 7,500 results it keeps, with their snippets, on its first page, as the Mac's window fetches them for every search. Over the whole corpus that costs what a Mac search costs; check 12 has not timed it here, over three fixture volumes.
- **The Mac's caption for expressions that differ** between documents and the reader's own writing has no place in the browser app, which sends no scope that could make them differ.

**Next: S11f,** the timeline and concordance readings over the API and in the browser app, each naming the set it counted. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11d: the facets, with include, exclude and Apply

14 October 2026 · branch `claude/s11d-search-features` · upstream `757c6d29`, unchanged

The owner merged #33 and #34 and asked for S11d. Three readers mapped the kit's public search code, the Mac's search window and what the web edition had. The search features were then too many for one reviewable pull request, as the S11c features had been, so this one brings the facets, and S11e brings the Query Inspector, the date order and the timeline and concordance readings.

**The API**

- **`/search/facets`** computes one section of a search's whole match: years, volumes, people, document type, provenance or subjects. It uses the kit's `SearchService.resultSetFacets(parameters:request:documentKeys:)`, the route the app's panel takes, as the panel computes a section when it is opened.
  - The rows come as the kit's `FacetPaging` cuts them, by a sort, page size, page and filter, each the kit's standard for the section unless given.
  - Beside them: the section's bound, the kit's titles for its sorts and page sizes, and what the panel says: the undated count, the three largest volumes' share, and the provenance and subject coverage.
- **A row that narrows on a click** (people, document type, subjects) carries its narrowing: the query fields the kit's `FacetNarrowing` changes, each with its values, or null for one it leaves out. The browser app makes that change to the search it shows, so it never needs to know which fields a narrowing touches.
- **`/search/facets/selection`** resolves a staged selection of years or volumes over the section's whole list, as `FacetSelection` and `FacetSelectionApplier` resolve the Mac's Apply. An exclusion alone means every row but those.
- **Each served index keeps the 16 sections it computed last,** by the search and the section. A section's other pages, sorts and filters, and its Apply, cost no second computation, as on the Mac, which computes a section once for a search and cuts it as it is shown. A new import opens a new index, which starts with none.
- **The search request** has one decoder for every search endpoint, and four more fields: a person's rollup and name, and a subject's place and durable name, the fields `FacetNarrowing` sets. Its new encoder writes a search back as the fields the decoder reads, for the narrowings. The draft's `facets` parameter is refused with a pointer to the new paths.

**The browser app**

- **The panel** opens from a Facets toggle beside the count, and stays open across searches (`panel=facets`). Its six sections are closed until opened, and each is fetched when it is, in the Mac's wording: titles, rows, sort and page-size menus, the filter field over 100 rows, the page footer, and each caption.
- **Years and volumes** stage rows: a click cycles one through not selected, included and excluded, in the order of the kit's `FacetRowState`, and the strip says "2 included · 1 excluded" with Clear and Apply. The resolution is the server's, so it is the kit's.
- **People, document type and subjects** narrow on a click, and focus returns to the section's heading. Provenance rows only describe, as on the Mac.
- **Each narrowing is a token** above the results, Years, Person or Subject, which clears it; a type sets the document-type filter. While the panel is open, the count says what the search narrowed from, as the Mac's does.
- **A new search** keeps each section's sort and page size, the reader's preference, and drops its page, filter and staged rows, which described the last search's rows, as the Mac's panel does.
- **The subject's name** comes from the row that set it: the kit's subject vocabulary, which the Mac's token reads, is internal.

**Checked**

- **Through the API, beside the kit,** over the fixture index imported as an export (FRUSParityTests):
  - every section of four searches is the kit's breakdown cut by `FacetPaging`, with its bounds, counts and titles;
  - a sort, page size, page and filter of the browser app's choosing cut the rows as the kit cuts them, a page past the last clamped;
  - each row's narrowing makes the search `FacetNarrowing` makes, and that search counts the row's documents;
  - five staged selections of years and of volumes resolve as the kit resolves them, and the searches they give count the chosen rows.
- **On Linux, the facets read the immutable index the server opens:** `resultSetFacets` builds a temporary table, which the read-only open keeps in memory.
- **The label sort** (`localizedStandardCompare`) puts 20 sample labels, with accents, case, numbered volume ids and apostrophes, in the same order in `swift:6.4-noble` (locale `en_001`) as on the Mac (`en_US`), and the filter's accent-insensitive match agrees.
- **The synthetic export** now has its three documents' dates from their TEI, so the browser suite's facets have years: 1960 for frus1961-63v06's d1 and d2, 1894 for frus1894Nicaragua's d1.

**A review before the pull request opened.** Two reviewers, one for the server and one for the browser app and the records, each checked their own findings against the code. Nine held, and all were fixed:

- **Apply over rows counted before a new index** could widen the search: the kit drops a key its list does not hold, and a volume selection of nothing but such keys clears the filter. The server now refuses such a key as `SECTION_CHANGED` (409), and the browser app counts the section again and drops the choice.
- **The cache had no tests.** Its computation is now a closure, and four tests show it computing a section once, a concurrent ask waiting for the same computation, the least recently used going when it is full, and a failure not kept.
- **A test would have crashed** rather than failed with too few rows, and checked one of the coverage figures where it now checks them all.
- **"Narrowed from"** was said when the match had not shrunk, and while the narrowed search was still loading; it is now said only of a smaller match, as on the Mac. The panel's "Describing all N matches" waits for the new count too.
- **A failed Apply's message** stayed under the next search's rows, and an answer that came back after another search would have been applied to the old one. Both now belong to the search they were for.
- **Focus fell to the page** when Clear, Clear filter or a token removed itself. It goes to the section, the filter field and the search box.
- **Wording:** a hint of the web's own hid the Mac's tooltip on a narrowing row, and the toggle's tooltip now reads "Hide the result-set facets" while the panel is open, as the Mac's does.
- **The records** said a type narrowing makes a token, where it sets the Document type filter, and that a section is computed once, where the 16 most recent are kept.
- **The sort and page-size menus** snapped back while a page loaded, and closing the panel lost each section's choices, which the Mac's controller keeps. The menus follow the reader's choice, and the screen keeps the panel's state.

Refuted, among others: a year list's emptiness lost on the way to the URL; a field a narrowing sets that the URL drops; a section of another search standing in; collisions in the cache's keys; and the temporary table on the read-only index.

**Records**

- `PLAN.md` and its shared copy (rev 153): S11d's row, S11e's, and the S11 answers.
- `SPEC.md`: the Search section, the API table and the facets' departures from the draft.
- `INSTALL.md`: the facets. The README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through the Test step's own script: all 1,928 tests pass, up from 1,914, with the one named skip. FRUSParityTests runs 104, up from 100, and FRUSLightServerTests 87, up from 77; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 50 unit tests pass in 12 files, up from 40 in 11.
- **`scripts/compose-smoke --e2e`:** passes, with 11 browser tests on Chromium, up from 10. The facets test runs axe with a year staged, and with every section open over a narrowed match, and it finds nothing.

**Notes**

- **Check 12's facet time** (one section within 3 seconds) is not measured here: the fixture index is three volumes. The kit measured the slowest section, People, at about 0.8 seconds over a whole-corpus match on the owner's 316,839-document index (`ResultSetFacets.swift`), and notes that paging by query would pay that again for every page; the cache is why a page here does not.
- **A person's rollup is the served index's:** a new import can number the rollups afresh, so a saved address that narrows to a person may name another after one. The app's anchor, which survives a rebuild, has no field in the API yet.

**Next: S11e,** the rest of the search features over the API and in the browser app: the Query Inspector, with the term that matched nothing; the date order; and the timeline and concordance readings, each naming the set it counted. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11c, follow-up: a reader page opened at a note keeps focus on its controls

13 October 2026 · branch `claude/s11c-note-focus` · upstream `757c6d29`, unchanged

The owner merged #33 and asked for the follow-up S11c's review had offered, before S11d.

**What was wrong**

- A reader page opened at a note (`/doc/…?note=…`) lands on the note when its frame loads.
- Another text size or appearance loads the page again, in a new frame, and that frame's load landed on the note again: focus moved from the Text Size or Appearance control into the frame.
- A keyboard user who changed either control lost their place in it (WCAG 2.2, success criterion 3.2.2, On Input). The behaviour dated from S9b; S11c's wash made it easier to see.

**The fix**

- The reader lands on a note once for each arrival at it, by a link or by Back and Forward: it keeps the document and note it arrived at, and the next frame to load lands on that note once.
- A page loaded again for another text size or appearance leaves focus on the control that asked for it, and the frame's URL fragment keeps the note in view.
- `SPEC.md`'s reader rendering says so.

**The test**

- A new browser test follows d21's link to footnote 2 of d16, then changes Text Size and Appearance from the keyboard, and checks after each that the control keeps focus. Back and Forward then land on the note again.
- It counts the frame's load events at the document, which it sees before the frame's own handler runs in the same dispatch, so it checks focus only once that handler has run.
- Against `main`'s image, before the fix, it failed where it should: after the text size changed, the control was no longer focused.

**Results**

- **The browser app:** typecheck and lint are clean, and its 40 unit tests pass.
- **`scripts/compose-smoke --e2e`:** passes, and so do the browser suite's 10 tests on Chromium, up from 9: the new one, and the rest as before, the landings by a link and in place among them.
- **Linux:** the server's code is unchanged; CI's swift job runs its tests.

**Next: S11d,** the search features over the API and in the browser app: the facets with include, exclude and Apply; the Query Inspector; the date order; and the timeline and concordance readings. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11c: BibTeX and RIS in Cite, display titles, the footnote landing, and a sturdier skip check

13 October 2026 · branch `claude/s11c-cite-titles-footnotes` · upstream `757c6d29`, unchanged

The owner merged #31 and #32, and asked for the phase-1 features. They became two pull requests, as S8's and S9's did: this one brings the citations, titles and reader features of #1666 to the API and the browser app, and S11d brings the search features of #1664. On the owner's word it also changes CI's skip check, after the `ci` run on `main` for #31's merge failed with every test passing.

**CI's skip check**

- **What failed.** Run 38490727044, on `7258ee58`, failed in the swift job's Test step:
  - all 11 targets reported passing, with the counts of #31's green run on the same tree;
  - but the step counted the named Linux-only skip 0 times, because about 240 lines of the test output never reached `test.log`: 156 "started" lines, 71 "passed", the skip's own line and a few log lines, all in FTS5StoreTests and FRUSCoreKitTests;
  - 16 lines arrived as their ends only, such as `t" started.`;
  - the backup-exclusion test's skip is a compile-time `.enabled(if:)`, so it was skipped as always. The `image` workflow does not depend on `ci`, and published that commit.
- **The change.** The Test step passes `--xunit-output`, and counts Swift Testing's skips in the results file it writes, `test-results-swift-testing.xml`:
  - each skip is a `<skipped>` element under its test's suite and function, and the backup-exclusion test (`FTS5StoreTests.FTS5StoreTests`, `backupExclusion()`, a reason beginning "Linux: ") must be the only one;
  - the log is still read for what the file cannot show: XCTest's skips, for which no file is written here, and cancellations, which the file records as passing. A lost line can hide one of those, but never fails the job;
  - `COORDINATION.md`'s pin-move checklist says how the allow-list now works.
- **How it was checked:**
  - a probe package in `swift:6.4-noble` showed what the file records for each kind of skip: a trait's, a disabled suite's (once for each of its tests), one with no reason, one with a reason over two lines or with XML's special characters, a cancellation and XCTest's;
  - the step's own script, read from `ci.yml`, ran in the swift image under `bash -eo pipefail`, with `LANG` unset and set to `C.UTF-8`, against nine cases replayed by a stand-in `swift`: the expected skip passes, and so does the failed run's own log; two extra skips (one with a reason over two lines, one with none), the named test run, skipped for another reason or found twice, no results file, an XCTest skip and a cancellation each fail;
  - this branch's full Linux run, through the same script: its results file holds 1,914 tests, one of them skipped, the backup-exclusion test.

**Cite**

- **The year.** The citation now takes the year the volume's TEI header states, read by the kit's `TEIPublicationYear` as both of the app's hosts read it, when the TEI is mounted.
  - Without the TEI, it takes the manifest's, with the Mac's fallback for the records, which the kit leaves to each host: `CitationRoutes.manifestYear` mirrors `DocumentExportSupport.effectiveYear`.
  - `publicationYear` and `publicationYearSource` (`tei` or `manifest`) say which.
  - Over HistoryAtState/frus at `99d851c79` (9 October), 552 of the 553 published volumes' headers state the manifest's year. frus1969-76v32's gives its date only as 2010-11-05, which the scan does not read, and the manifest gives 2010.
- **The records.** `bibtex` and `ris` are the kit's `BibtexExporter` and `RISExporter`, as the Mac's Copy BibTeX and Copy RIS write them; `…/citation.bib` and `…/citation.ris` serve them as files, named as the Mac names its .bib file.
  - The citation and both records are made from one volume's metadata, as iOS's reader makes them, so the printer's name follows the year cited.
- **The browser app.** Cite adds Copy BibTeX, Copy RIS and Save as .bib, in the Mac popover's wording, the last without its ellipsis, since a browser saves at once.

**Display titles**

- **Search rows** are named as the Mac's search window names them: the header less a leaked source note (`DocumentHeaderDisplay.trimmedHeader`), with the document's label beside its volume (`CitableDocumentNumber.captionLabel`), withheld when the header already opens with its number (`headerRepeatsNumber`). A row with no header takes the name the app's lists give it, where the window would leave it blank.
- **Every other list** (a section's documents, a volume's reading order) and **the reader's heading** take the kit's `DocumentDisplayTitle`: an editorial note whose head says only "Editorial Note" is named by its number, and a document with no head by its id.
  - The app names documents by it in its Research, working-corpus and cluster lists and its reader's title. Its Browse rows print the stored head (`DocumentRowLabel`), which for 2,560 notes is only "Editorial Note".
  - Browse here takes the kit's rule instead, which #1666 moved for the web edition's lists, so a row reads as the heading of the reader it opens. SPEC says so.

**The reader**

- **The footnote landing** is the app's own script: `/reader/host.js` holds the kit's `FootnoteLanding.script(keyExpression:)` byte for byte, as the body of `landOnFootnote(key)`, and runs it whenever the browser app asks it to land on a note, in another document after its page loads, or in place. The entry scrolls into view and is washed for 2.4 seconds; then it takes focus, as before.
- **A whole volume outside the catalogue**, such as the microfiche supplement v06's preface names, now carries its page on history.state.gov (`FRUSCanonicalURL.volumeURL`, public since #1666), which the app opens, and the reader offers it.

**A review before the pull request opened.** Two reviewers, one for the server and CI and one for the browser app and the records, each checked their own findings against the code. Six held, and all were fixed:

- **Cite's status:** a second copy said "Copied" again, which a live region does not announce, so Copy RIS after Copy BibTeX was silent to a screen reader. The status now empties before each copy. The browser test now waits for each record on the clipboard, where it had passed on the first copy's status.
- **"As the app's lists do":** the records said every list in the app names documents by `DocumentDisplayTitle`; its Browse rows do not. The comments, SPEC and the README now say that Browse here departs from them, and why.
- **Untested titles:** no browser-app test could tell a `displayTitle` from a `header`, or see a label withheld. Route-level unit tests now render Search, a section, a volume's reading order and the reader with the server's answers stubbed. With any of the four screens put back to `header`, or the label's guard removed, a test fails.
- **Cite's two rows of buttons touched**, and now have the gap they have when they wrap.
- **CI's results file is read as text** (`grep -a`), as the log is: a NUL byte in a skip's reason would otherwise fail the job.
- **`classify(asEditorialNote:)`,** which renames a document with the index's effective classification, had no test that could fail. The API cannot show it, since both read the same column, so a direct test does.

Refuted, among others: a mismatch between the types and the server's JSON; a download link styled as a button; the 2.4-second wash racing the tests; the host script's JavaScript under the page's policy; and the CI step's exit codes under `-e` and `pipefail`. One finding predates this session, so it is offered as a follow-up: on a reader page opened at a note, changing Text Size or Appearance reloads the frame, and the reload's landing pulls focus into it.

**Records**

- `PLAN.md` and its shared copy (rev 148): S11c's row, S11d's new one, S11b's row with the reused export, and the S11 answers.
- `SPEC.md`: the reader's landing, the API's search rows, list titles, the link's `url`, and the citation's year, records and files.
- `INSTALL.md`: Search's document numbers, Cite's three controls, the note's landing, and a volume outside the catalogue.
- `COORDINATION.md`, the README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through the Test step's own script: all 1,914 tests pass, up from 1,908, with the one named skip, which the new check allows. FRUSLightServerTests runs 77, up from 71; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 40 unit tests pass in 11 files, up from 34 in 9.
- **The Compose smoke test with `--e2e`:** passes, and so do the browser suite's 9 tests on Chromium, up from 7. Axe runs over a note just landed on, the notice for a volume outside the catalogue, and Cite after its records are copied and saved, and finds nothing.

**Notes**

- **The Mac's popover gives the records the manifest's printer**, computed from the manifest's year, while iOS and this server compute it from the year cited. They differ only for a volume whose header and manifest name years either side of 2014, and no published volume does, so nothing is filed upstream.
- **A document the index lacks** keeps the name its TEI gives it ("Document 3"), and its records take its id for a title, as the kit's exporters do for an empty header: the kit's header extraction, `IndexingPipeline.extractHeader`, is internal.
- **The synthetic export's rows carry no document numbers**, so the browser suite sees "Doc 1" beside "1. Telegram From…", as the Mac's window would for those rows. The server tests give the rows numbers to check that the label is withheld, and the unit tests stub the answers.
- **Scratch files** from the CI checks are in `.build/linux` (`ci-test-step.sh`, `guard-cases/`), which git ignores; the session left them, since its safety check would not remove them for it.

**Next: S11d,** the search features over the API and in the browser app: the facets with include, exclude and Apply; the Query Inspector; the date order; and the timeline and concordance readings. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11b: pin move past S11a's two upstream pull requests

13 October 2026 · branch `claude/s11b-pin-move` · upstream `757c6d29` (#1666's merge, after #1664's `9feff971`)

The owner merged both of S11a's pull requests, and this one moves the pin to the second's merge (rule 5). It is stacked on #31, S11a's records, so #31 merges first.

**What the move brought**

- **The app's own work since `c6f7b2cb`:** `0fe15702` and `13e093ba` change only `Planning/` and the marketing kit, so build 50 stands. Its index version (69) and FTS generation (4) are unchanged.
- **#1664 and #1666:** the kit's public search, citation, title and reader code, which S11c builds on. Nothing in the web edition's own code needed a change: the server and its tests built and passed at the new pin as they were, and no kit folder, Linux-only skip or export schema changed.

**The golden files**

- **The export,** on the owner's word: the 13 October three-volume export from build 50, which build 50's pin move used.
  - The new pin is still build 50, so the export's `app_build` is the pin's.
  - No file on the indexing path changed between `c6f7b2cb` and `757c6d29`: the TEI parser, `IndexingPipeline.swift` and its seams, FTS5Store, SourceNoteKit and the bundled resources. So a new export would have indexed the same rows.
  - COORDINATION's checklist now allows such a reuse, by the owner's choice.
- **Remade by `scripts/make-golden --export`:**
  - all 392 rows' HTML and the 482 queries' expressions changed only in provenance;
  - the results changed only in provenance: 482 queries, 43 refused and 12 with ties past the 50th, as before;
  - in the index summary, no digest or count moved, only the provenance and the timings it records as information;
  - `frus-parity check-golden` passes.

**Records**

- `PLAN.md` and its shared copy (rev 144): S11a's row, Mac check 6 done, the golden-file checkpoint, the risk rows' counts and the S11 answer on the export.
- `COORDINATION.md`: the pin, the move and when an export can be reused.
- `SPEC.md`: the pin's index version and table lines. The prep notes, the README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 1,908 tests pass, up from 1,797, with the one named skip, which CI's skip check allows.
  - By target: FRUSCoreKitTests 1,061, SourceNoteKitTests 310, FTS5StoreTests 209, FRUSParityTests 100, FRUSLightServerTests 71, ManifestGeneratorTests 60, FRUSLightCoreTests 42, SemanticVectorsKitTests 35, CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
  - Against the remade golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 392 of 392 rows identical".
- **The web app and the Compose smoke test with `--e2e`:** run by CI's web and compose jobs, since this pull request changes neither the browser app nor the server's code.

**Notes**

- **The source digest moved** with #1664 and #1666, as it does at every pin move, and so did nothing else in the golden files.
- **Next pin move:** `COORDINATION.md` says when an export can be reused, and when the owner needs to make a new one.

**Next: S11c,** the phase-1 features over the API and in the browser app: the facets with include, exclude and Apply; the Query Inspector; the date order; the timeline and concordance readings; BibTeX and RIS in Cite; display titles in lists; and the footnote landing with the app's own script. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11a: the phase-1 features' two upstream pull requests

13 October 2026 · branch `claude/s11a-phase1-upstream` · upstream [joshbotts/FRUS-Explorer#1664](https://github.com/joshbotts/FRUS-Explorer/pull/1664) and [#1666](https://github.com/joshbotts/FRUS-Explorer/pull/1666)

The owner used the S10 site and asked for the phase-1 features, which signs phase 1 off on its exit. SPEC's phase 1 lists features that S10's checks did not need, and their shared code was internal to the kit or in app files. This session opened two pull requests on `FRUS-Explorer`, both `Mac`-labelled for the owner's check. The owner merged the first, #1664, the same day as `9feff971`, and the second is rebased on it. Each moves that code into FRUSCoreKit or makes it public, and the app calls the moved code too, so nothing is copied here. The pin stays at `c6f7b2cb` until both have merged.

**#1664: search, merged as `9feff971`**

- The concordance (`KWICLine`, `KWICSort`, `ConcordanceResult` and `SearchService.concordance(for:parameters:radius:)`) and the facets (`ResultSetFacets` and its section, sort, paging, bucket, bound and request types) are public.
- `SearchService.resultSetFacets(parameters:request:documentKeys:)` is the route the app's facet panel took, moved: the match and filters the search runs, or a meaning search's keys. The panel calls it now.
- The facet panel's narrowing and staged selection move into the kit:
  - `FacetNarrowing` reads the subject vocabulary from the host's `IndexingResources`;
  - `FacetSelection`, `FacetRowState` and `FacetSelectionApplier` move with `stagedSections`, which the panel's controller held.
- The Query Inspector's model, `QueryInspection.swift`, moves whole, with its three passes public.
- `SearchSortOrder` moves with `sorted(_:)`, the date order both view models kept a copy of, and gains `String` raw values for the API.
- Its tests: FRUSCoreKitTests goes from 950 tests in 126 suites to 1,022 in 132.

**#1666: citations, titles and the reader**

- `BibtexExporter`, `RISExporter` and `ZoteroJSONExporter` with its items move into the kit; the Zotero exporter's SwiftData lookup stays in the app.
- `TEIPublicationYear` is the header scan both apps kept a copy of, and both call it, each with its own fallback.
- `DocumentDisplayTitle` with `Facts`, which was `CrossReferenceStore.DocumentTitleFacts`, and `DocumentHeaderDisplay` move into the kit.
- `FootnoteLanding` is the app's footnote landing script, byte for byte. `script(keyExpression:)` lets the reader's host here run the same script for a key it has only when the script runs.
- `FRUSCanonicalURL.volumeURL(volumeId:)` is public, the page a reference to a volume outside the catalogue opens.
- Its tests: FRUSCoreKitTests goes from 950 tests in 126 suites to 989 in 133.

**How both were checked**

- **#1664,** at its head, whose tree `9feff971` is:
  - `FRUSExplorerMac`, clean and unsigned, built as `v2` at `13e093ba` did, with the same five warning lines. Its symbol diff, normalized, has 27 removed and 37 added names, each one the move accounts for.
  - The full iOS unit run on iOS 27.0: 7,147 tests in 844 suites, against `v2`'s 7,139 in 842. Both have the same 8 issues, the Keychain tests an unsigned build fails, and the same 17 tests and 2 suites skipped.
  - `swift test`: 38 runs and 2,852 tests, none failed or skipped.
- **#1666,** at its head on `9feff971`:
  - `FRUSExplorerMac`, clean and unsigned, beside `v2` at `9feff971`, with the same five warning lines. Its symbol diff, normalized, has 107 removed and 131 added names. Nearly all of that is the facts type's new mangled name, `DocumentDisplayTitle.Facts`; with that rename undone it is 5 and 29, each one the move accounts for.
  - The full iOS unit run: 7,158 tests in 847 suites, against `9feff971`'s 7,147 in 844. Both have the same 8 Keychain issues and the same skips.
  - `swift test`: 38 runs and 2,891 tests, none failed or skipped.
- **Linux,** in a scratch worktree of this repository's `main` with each branch copied over the submodule:
  - FRUSCoreKitTests pass with the one named skip: 1,022 for #1664, and 1,061 for #1666 on it;
  - every other target passes except FRUSParityTests, whose 13 issues are all golden-file staleness. The source digest covers the kit's folders, and S11b remakes the files;
  - remade at each branch with `tools/mac-golden`, the 392 rows' HTML and the 482 queries' expressions are byte-identical to the committed golden files; only the two provenance lines differ.

**Delivered here**

- `PLAN.md` and its shared copy (rev 136): the phase-1 sign-off, S11a–S11c and Mac check 6, the answers for S11, the risk row and the count of owner steps.
- `COORDINATION.md`: the two pull requests among the web-authored moves.
- The README and this log.

**Notes**

- **The editable-content docs pin strings to source lines.** Moving code shifted 60 of their ranges in #1664 and 6 in #1666. `EditableContentKeyTests` caught it in a first iOS run, and the ranges were re-pointed through a line diff of each file, each by the distance its own key moved.
- **A new kit suite must not reuse a name the app's test target declares.** The package builds the kit's suites alone, and Xcode compiles them into one module with the app's. A first `FRUSCanonicalURLTests` collided with the app's suite of that name and became `CanonicalVolumeURLTests`.
- **The two pull requests touch the same lines:** `CLAUDE.md`'s FRUSCoreKit entry, and the ends of `Planning/DEVELOPMENT-PLAN.md` and the amendment log. #1666 was not yet pushed when #1664 merged, so it was rebased on `9feff971`, the three conflicts were combined, and its checks ran again at that head.
- **Disk:** the Mac had 13–15 GB free throughout. The checks reused S6's derived-data folders and its scratch clone, and the worktrees for `v2` and #1666 share the clone's objects.

**Next: the owner's Mac check of [#1666](https://github.com/joshbotts/FRUS-Explorer/pull/1666), and its merge.**
- **Then S11b:** the pin move past both. It needs a new three-volume export from the merged build for the golden files.
- **Then S11c:** the features over the API and in the browser app.
- **Still before a release:** Browse's own-text rows, the daily upstream watch and the speed of exact-word search.

## Session 10: the owner's export in Compose, with checks 3–5 on it

13 October 2026 · branch `claude/s10-real-export`

S10 imported the owner's full export from build 50 into a Compose install and ran checks 3–5 on it. That is phase 1's exit, which waits on the owner's sign-off. On the owner's word, S10 ran on build 50, before the phase-1 features' upstream pull request.

**The install**

- A Compose project of its own, `frus-s10`, on port 8081, set up as `docs/INSTALL.md` says: `compose.yaml`, and a `.env` naming the port, the TEI folder and the image CI published for `main` at `3963520`, the merge of #29.
- The TEI folder is the owner's clone of HistoryAtState/frus, mounted read-only. It is at `99d851c79`, the corpus that build 50's bundle and the export hold.
- The owner's own install, from S7's trial, was left as it was. It is on port 8080, with an older image and the 3 October export at index version 65.

**Check 5: import acceptance**

- **The export made with the owner's writing** went into the drop zone first. Import mode refused it at `checking_writing`, 7 seconds after it arrived: "This export includes your notes, summaries and tags." A refused file stays in the drop zone, so its copy was removed. The install guide now says to remove such a copy, since it holds the writing.
- **The stripped export** installed. It was ready 38 seconds after the copy began, serving 318,151 documents from 553 volumes at index version 69.
- **`scripts/check-stripped-export`,** new, then searched the stripped file for the writing in the export made with it. It prints counts only, as the owner chose over one planted string:
  - 6,558 summaries, 8 notes and 21 tags gave 7,102 snippets from 6,580 values; 7 values were too short to search for;
  - the controls held: the snippets were found in the export with writing for all 6,580 values, and 189 of 189 snippets of the corpus's own headers in the stripped file;
  - the stripped file's tables hold no summary, note or tag, and its `user_content` index no term, where the export with writing's holds 11,037;
  - 1,622 snippets appear in its bytes, all of them in its corpus text too, since those summaries quote documents. None is in the owner's writing alone.

**Check 3: search**

- **The Mac's results:** `mac-golden results --any-volumes`, new, ran the app's SearchService over a copy of the export. 482 queries took 32 minutes 37 seconds: 43 were refused, and 12 have ties past the 50th.
- **The server's:** `frus-parity results --api`, new, read the same queries through the Compose install's API, from a Linux container.
- **The first run:** 472 records were identical, and 10 failed in the client. Exact-word searches (`=Soviet` and the like) took longer than URLSession's minute while the server served check 4 too.
- **Read again** with a 15-minute timeout, the 10 answered: 21 requests in 989 seconds, the slowest 66. Merged into the first run, `frus-parity compare-results` printed "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups". 349 queries have other score bits, which is information, as through the API on the fixtures.

**Check 4: the reader**

- **The sample:** in each volume, the middle row of its index that is not front matter. That is 553 documents, from frus1861 to frus1989-92v31.
- **The Mac's HTML:** `mac-golden render --tei --rows`, new, rendered them from the clone through the Mac reader's path, in 2 minutes 11 seconds. The reader applied the bundled broken-references index as the app applies it: the tool puts the index beside its binary, where `BrokenRefsIndexStore.shared` reads it, and checks that the reader finds it.
- **The server's:** `frus-parity render-api`, new, fetched each document's body from the server and compared the bytes: "check 4 through the API: 553 of 553 rows identical, 14 figure images in 2 rows named by the server".

**Delivered**

- **`tools/mac-golden`:** flags in its parser; `results --any-volumes`; and `render --tei --rows --out`, which refuses an `--out` inside `fixtures/golden`.
- **`frus-parity results --api` and `render-api`,** over `LiveAPI` in FRUSParity. Its loop is ParityFormat's `ResultsLoop`, as the tests' and the Mac's are. A request may take 15 minutes, and `results` prints its slowest requests.
- **Tests:** ServedAPIParityTests' checks 3 and 4 through the API also read through `LiveAPI`, and find the same records and bodies. So CI runs the code S10 ran.
- **`scripts/check-stripped-export`.**
- **Records:**
  - `INSTALL.md`: removing a refused copy that holds the owner's writing;
  - `SPEC.md`: how a release runs checks 3–5 against a real export;
  - `PLAN.md`: the answers for S10;
  - the README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,797 tests pass, with the one named skip.
- **On the owner's export:** checks 3, 4 and 5 pass, as above.

**Notes**

- **Exact-word searches are slow over the full corpus.** On the server, with nothing else running, the 10 queries' 21 requests took 989 seconds, about 47 each, the slowest 66. SPEC's check 12 targets 1.5 seconds for keyword search. The Mac app's own search took 11 minutes 22 seconds for the same 10 queries, its copy of the export included, and gave the same records: the time is the search's own, on both platforms. Check 12 is phase 5's, and this is its first measurement.
- **The server searched on one core.** It held one CPU at 100% throughout, at 218 to 270 MiB.
- **A request the client abandons runs on.** After the 10 timeouts the server went on computing those searches: a dropped connection does not stop the kit's search.
- **The Mac slept during the owner's pause,** and Docker's VM with it. The runs took nine hours of wall time, but about 45 minutes of the VM's.
- **The Mac's disk** had about 17 GB free. The tool's 2.9 GB copy of the export was removed when it finished.
- **The owner's own install** still serves the 3 October export at index version 65, from an image older than #29. Upgrading it means pulling the new image and importing an export from build 50.

**Next: the owner's sign-off of phase 1.** In PLAN's checkpoint, the owner uses the site and confirms checks 3–5; the S10 install at http://localhost:8081 serves the export. Then the phase-1 features' upstream pull request. Browse's rows for a section's own text, the daily upstream watch and the speed of exact-word search remain before a release.

## Pin move: build 50, at index version 69

13 October 2026 · branch `claude/frus-upstream-changes-bd0cb7` · upstream `c6f7b2cb` (tag `build-50`)

The session began by reading what had changed upstream since S9c's pin, in FRUS Explorer, frus-semantic-vectors and HistoryAtState/frus, to say whether the web edition should catch up before S10. It should: the owner's full exports for S10, made from build 50, are index version 69, and the server at `f384d2d5` served only 65. On the owner's word this pull request moves the pin (rule 5).

**What had changed upstream**

- **FRUS Explorer:** 41 commits on `v2`, from `f384d2d5` to `0fe15702`. Four index bumps merged on 11 October, 65 to 69 ([joshbotts/FRUS-Explorer#1638](https://github.com/joshbotts/FRUS-Explorer/pull/1638), [#1639](https://github.com/joshbotts/FRUS-Explorer/pull/1639), [#1640](https://github.com/joshbotts/FRUS-Explorer/pull/1640) and [#1645](https://github.com/joshbotts/FRUS-Explorer/pull/1645)), and ship together in build 50, which the owner tagged on 13 October at `c6f7b2cb`; `0fe15702` changes only `Planning/`. Upstream's brief for the bumps planned it so: "The web side moves its pin once, after the last." The FTS generation (4) and the exporter are unchanged.
- **HistoryAtState/frus:** from `8e5da08` (release 1.1.1) to `99d851c79` (1.1.3, 9 October). 26 volumes were corrected (HistoryAtState/frus#470), and 47 documents restored to frus1952-54v09p1 (HistoryAtState/frus#471). No volume was added or removed, and the three fixture volumes are byte-identical, so `fixtures/tei` stands. Build 50's bundle is at `99d851c79`.
- **frus-semantic-vectors:** the shards of frus1952-54v09p1 and frus1902app1 were re-packed in place for those corrections, and the README and manifest now describe 553 shards; the provenance digest is unchanged. The web edition reads shards only from phase 4. A pin before `f23092ec` bundles the older shard manifest, which refuses the two new shards; this one bundles the new.

**The owner's exports**, read only in SQLite's immutable mode:

- **The full corpus, from build 50:** one export without the owner's writing (2.86 GB), and one with it, for check 5, of which only the stamp and counts were read. Both are index version 69 and FTS generation 4, with 553 volumes and 318,151 documents, the 47 restored ones among them, and no sidecar file. Their library has a long history: its `person_mentions` lacks the UNIQUE constraint fresh libraries have had since June, with no duplicate row, and 162 revision rows at index version 62 name documents no longer indexed. Neither stops an import, since for a stamped export the server reads the stamp.
- **Three volumes, from build 50,** for the golden files: exported at 05:21:01Z after Erase Everything…, with no writing, exactly the three fixtures (139, 123 and 130 documents, every revision at 69), indexed in the order frus1894Nicaragua, frus1961-63v06, frus1969-76ve09p1.

**Delivered**

- **The pin, `c6f7b2cb`.** Every kit builds and passes on Linux, with no new skip and no upstream repair: FRUSCoreKitTests runs 950 tests in 126 suites, up from 894 in 119.
- **Index version 69.** `IndexCompatibility.supportedIndexVersion` follows the pin, so the server now refuses build 49's exports, naming both versions.
- **A reference to a whole volume.** The kit reads one as `CrossRefDestination.volume` since [joshbotts/FRUS-Explorer#1603](https://github.com/joshbotts/FRUS-Explorer/issues/1603), and the link route's switch over the kit's destinations had no case for it, the move's one break. The route now answers `volume`, with `volumeId` and what the server holds of the volume. The browser app opens a catalogue volume in Browse, as the app's `WholeVolumeLink` does. The app opens any other volume's page on history.state.gov, an address the kit keeps internal (`FRUSCanonicalURL.volumeURL`), so the reader says the volume isn't part of the collection. The server test that pinned the old reading, a document named `frus1961-63v05`, now pins the new, with Volume V, the volume itself and the microfiche supplement the preface names.
- **The schema fixture,** `export-v69-schema.sql`, from the three-volume export, in place of `export-v65-schema.sql`. It holds version 65's statements in their order, and one more: the partial index `idx_document_cache_user_tag_ids`, which [joshbotts/FRUS-Explorer#1614](https://github.com/joshbotts/FRUS-Explorer/pull/1614) added on 9 October with no index version. No table changed, so `IndexSchema.swift`'s list stands.
- **The golden files,** remade by `scripts/make-golden --export`:
  - all 392 rows' HTML and the expressions changed only in provenance, and the render manifest's description now names the reader serializer's third setting, `listsNamedReferences` (#1599), and the release build;
  - in the results, only q324 and q430's tie at the 50th place moved: S9c's export had swapped it, and this one, indexed in the recommended order, swaps it back;
  - the index summary's 7 checks are unchanged, and seven of its 36 gating digests moved. Six follow the bumps: `cross_references`, its rows and their order (66: a reference to a footnote is an edge to its document, and one to a whole volume a row between volumes), `terms` (66: line breaks folded), `document_sources` and `volume_sources` (69: the class key) and `document_revisions` (every row at 69). The seventh, `schema`, is #1614's partial index.
- **`scripts/make-golden` builds `tools/mac-golden` in release.**
  - At build 50 the tool's debug build failed under Xcode 27.0, though Xcode builds the app. In one of the compiler's batches, `ForEach(cols)` in `ResearchRailView.swift` found the `@Model` class `Collection` not Identifiable.
  - A bisect put it at `845d57ea` (#1645), which edits neither file. A probe naming the conformance in `ResearchRailView.swift` made the module build, and a whole-module compile type-checks it clean, so the fault is the debug build's and not the app's.
  - Release compiles the module whole, and `-enable-testing` keeps the tool's `@testable import`. At `f384d2d5` the release-built tool wrote render, expressions and results byte for byte as the committed golden files. The tool's header and its render description say how it is built.
- **Tests that named 65 as the pin's version** now read `IndexCompatibility`, and the parity tests' synthetic export stamps the submodule's build. The summary's own test still names the build, now 50, so a build bump shows there. Literals that stand for another version, or for test data, stay.
- **Records:**
  - `COORDINATION.md`: the pin, the counts, the contract and this move;
  - `PLAN.md` and its shared copy (rev 126): the move, the golden-file and Mac-export checkpoints, and two risk rows;
  - `SPEC.md`: the table definitions' lines, the compatibility contract and the link route;
  - `INSTALL.md`: the version, whole-volume links and the first version change on upgrade;
  - the prep note and the README.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 1,797 tests pass, up from 1,723, with the one named skip, which CI's skip check allows.
  - By target: FRUSCoreKitTests 950, SourceNoteKitTests 310, FTS5StoreTests 209, FRUSParityTests 100, FRUSLightServerTests 71, ManifestGeneratorTests 60, FRUSLightCoreTests 42, SemanticVectorsKitTests 35, CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
  - Against the new golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 392 of 392 rows identical".
- **The web app:** typecheck, lint and 34 unit tests.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image, whose client stage builds the web app. The suite runs seven tests on Chromium, one of them new: "volume V" in d7 opens Volume V in Browse, and the microfiche supplement the preface names says it isn't part of the collection. The axe test still allows nothing.

**Notes**

- **No watch caught the bumps.** COORDINATION's daily job, which would build `v2`'s head on Linux and compare its index version with the pin's, was never added, so four index bumps and a build went unseen here until this session looked.
- **Browse lists no section's own text yet** ([joshbotts/FRUS-Explorer#1536](https://github.com/joshbotts/FRUS-Explorer/issues/1536), index version 68). The app's Browse lists it first in its section; the server's section page lists the section's documents alone. No fixture section has such a row. The corpus has them for 1,337 sections that hold documents and 33 that hold only sections. The reader's order holds them already, through the kit.
- **A volume outside the catalogue** gets history.state.gov's page once the kit makes `FRUSCanonicalURL.volumeURL` public: a line for the next upstream pull request.
- **Rule 4 glue:** the choice between a person's two counts, the `fnote-` prefix, and now the whole-volume choice, in the browser app.
- **The person rollup can depend on indexing order** ([joshbotts/FRUS-Explorer#1658](https://github.com/joshbotts/FRUS-Explorer/issues/1658)). A fix would move `currentPersonRollupVersion`, not the index version, and every fixture person's rollup has one member, so check 2 cannot show it.

**Next: S10, when the owner says.** Its input is the owner's build-50 export. The plan timed the phase-1 features' upstream pull request so its pin move came just before S10's export; the export now exists, so the owner decides between S10 on build 50, with the features after, and the features first, with another pin move and new exports if the index version moves. Browse's own-text rows and the daily watch are each a small pull request before S10.

## Session 9c: pin move to the AA reader and the kit's link parse, with page links and mention counts

7 October 2026 · branch `claude/s9c-pin-move` · upstream [joshbotts/FRUS-Explorer#1578](https://github.com/joshbotts/FRUS-Explorer/pull/1578) (merged as `4fc04a60`) and [#1579](https://github.com/joshbotts/FRUS-Explorer/pull/1579) (merged as `f384d2d5`)

S9b's two upstream pull requests merged on `v2` after the owner's Mac check. #1579 needed a merge of `v2` first, made in S9b's clone: both pull requests had added a session entry at the end of `Planning/DEVELOPMENT-PLAN.md`. The merge kept both, and its head was checked again:
- the Mac build;
- the full iOS unit run: 6,516 tests, failing only the 8 Keychain tests an unsigned build fails, with the same 17 tests and 2 suites skipped as on `v2`;
- `swift test` from an empty build folder: 38 runs, 2,557 tests;
- FRUSCoreKitTests on Linux: 894.

This pull request moves the pin to `f384d2d5` (rule 5) and remakes the golden files from the owner's new export. It also brings what S9b deferred until then:
- the kit's link parse in place of the server's mirror of the app's;
- page links, through `PageRangeStore`;
- the person card's count, through `PersonMentionStore`;
- no axe allowance.

The index version (65), the FTS generation (4) and the app's build (49) are unchanged, so the image, `compose.yaml` and the export contract are too.

**How the session got there**

- **A map first.** Two readers mapped:
  - what the move makes stale in the records, the build and the golden files;
  - the kit's two stores, the Mac's use of each, and fixture data to test them.

  `Package.swift` needed no change: the folder the kit's tests compile picks up #1579's new suite. Two of their findings shaped the tests:
  - **No fixture document has a page link within its own volume;** such links are only in the tables of contents and indexes, which the reader cannot open. So the parity test writes its own page links, every arabic page of each volume, in the serializer's form.
  - **The synthetic export had the person and page tables but no rows.**
- **A review before the pull request opened.** Four reviewers each had a skeptic check their findings. Four findings held, and all were fixed:
  - **The count's number:** the card wrote it ungrouped ("4512"), but the app's localized string groups it ("4,512"). With the full corpus, counts in the thousands will appear.
  - **A test gap:** no test sent a page link that names another indexed volume, so a lookup in the wrong volume would have passed. The parity test now sends Nicaragua's pages 9 and 15 from frus1961-63v06, whose own pages 9 and 15 hold other documents.
  - **Two records:**
    - SPEC had stopped naming the app code the server copies, the choice between a person's two counts;
    - one of PLAN's S9 answers lacked its "Done in S9c".

  The server's reviewer found nothing. The two refuted points: the person test's slack of four, since all 121 persons are counted; and a missing test that the stores open immutably, which the code shows and #1579's own tests prove.

**The owner's export**

Made on 7 October from a build of `f384d2d5` after Erase Everything…, and read here only through SQLite's immutable mode:
- exported at 10:28:02 UTC, after #1579 merged at 10:15:33 UTC;
- build 49, index version 65, FTS generation 4, with none of the owner's writing;
- exactly the three fixtures, 139, 123 and 130 documents, every revision at index version 65;
- 1,130 page ranges and 1,018 person mentions;
- no log or journal beside it.

`make-golden` copied it to a temporary folder and worked on the copy alone.

**Delivered**

- **The pin, `f384d2d5`.** FRUSCoreKitTests runs 894 tests in 119 suites on Linux, up from 884 in 118.
- **The golden files,** remade by `scripts/make-golden --export`:
  - all 392 rows' HTML, the expressions and the index summary's 36 gating digests and 7 checks are as before. #1578 changed the page's head, which the golden bodies leave out;
  - only provenance and information fields changed. These include the export's stamp, its size, its AUTOINCREMENT counters, which grew by exactly one indexing, and `volumeOrder`;
  - this export indexed frus1969-76ve09p1 before frus1961-63v06. So in q324 and q430, both "see", the 50th result and its exactly tied successor changed places. Check 3 passes that as a reorder within a Mac tie group, and now reports 480 identical and 2 reordered.
- **The link route** reads each link with `FRUSURLScheme.readerLink(from:)`. The server's mirror of the app's parse, and its tests, are gone; #1579's tests cover the parse upstream.
- **The served stack** opens `PageRangeStore(readingDatabaseAt:)` and `PersonMentionStore(readingDatabaseAt:)` beside the search stack, inside the same check that the path still names the served file.
- **Page links:** a page link lands on the document the index's page ranges place on its page. Of several documents there, it takes the one its footnote names, as the app opens it. With no index, or for a volume or page the index lacks, the reader says why.
- **The person card:** for a person in the volume's list, it shows "In Indexed Documents" and "Mentioned in N indexed documents", or "Not found in indexed documents", in the app's words. The count is the person's rollup across the corpus, else their documents in the volume, as `DocumentViewModel.loadPersonMentionCount` decides. That choice is app code, so it is recorded glue. Find all mentions is left out, as iOS leaves it out where Search cannot open: it needs a person filter in Search.
- **The synthetic export,** in both generators, holds the page ranges and person rows a real export holds for its documents. Khrushchev has a rollup and Kennedy does not, so the two counts take different branches.
- **The axe check** allows nothing: the kit's page meets WCAG 2.2 AA since #1578. The known list and the two checks that it was still needed are gone.
- **Records:**
  - `COORDINATION.md`: the pin, both merges, what the move did, and how download order affects exact ties;
  - `PLAN.md` and its shared copy (rev 118): the S9c row, Mac check 5, the golden-files and risk rows, and the S9 answers marked done;
  - `SPEC.md`: Reader rendering step 4, the link route and the compatibility contract;
  - `INSTALL.md`: page links and the card's count;
  - the prep note and the README.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 1,723 tests pass, up from 1,711, with the one named skip, which CI's skip check allows.
  - FRUSCoreKitTests: 894 in 119 suites.
  - FRUSParityTests: 100, up from 98. Its new suite prints "page links through the API: 897 links, 885 placed on a document, every one as the app's store places it" and "person counts through the API: 121 of 121 persons in the reader's lists, each as the app counts them".
  - FRUSLightServerTests: 71. The parse's suite is gone, and a test of the counts and of pages before an import is new.
  - Against the new golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 480 identical and 2 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 392 of 392 rows identical".
- **The web app:**
  - typecheck, lint, and 34 unit tests, the card's count among them;
  - the build.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image. The suite runs six tests on Chromium:
  - the done-when walk, whose Khrushchev card now shows "Mentioned in 2 indexed documents";
  - a page link from d1's frame to page 2, which lands on d2, and "vol. XIV, p. 387" in d21, which says the volume is not indexed;
  - the footnote landing and the volume off the server;
  - axe, with nothing allowed anywhere: the reader's frame, light and dark, passes;
  - S9a's two tests.

**Notes**

- **The fixtures cannot show which count branch ran:** every fixture person's rollup has one member, so the rollup's count equals the volume's. The server test sets the synthetic rollup's count apart to show that the rollup wins.
- **The tools still cannot tell exports of `101e17d7` and `f384d2d5` apart.** Only `exported_at` and the procedure distinguish them.
- **Download order** decides how exact ties at the 50th place fall in the golden results. Adding the volumes in the order frus1894Nicaragua, frus1961-63v06, frus1969-76ve09p1 keeps check 3's report steady across exports.
- **Rule 4 glue left:** the choice between a person's two counts, and the `fnote-` prefix the kit's serializer gives a note's entry.

**Next: S10.** The owner's real export imported into Compose, with the TEI folder mounted read-only; checks 3–5 pass on the real export, which is phase 1's exit. The phase-1 features' upstream pull request (the reader's scripts, facets, the inspector, date order, display titles, BibTeX and RIS) is timed so its pin move comes just before S10's export.

## Session 9b: Browse, the reader's links and cards, by keyboard and checked by axe

7 October 2026 · branch `claude/s9b-browse-links` · upstream [joshbotts/FRUS-Explorer#1578](https://github.com/joshbotts/FRUS-Explorer/pull/1578) and [#1579](https://github.com/joshbotts/FRUS-Explorer/pull/1579), open

S9's second pull request completes the phase-1 SPA. It adds Browse, the reader's links and their cards, a keyboard path through all of it, and an axe check in the browser suite. The pin stays at `101e17d7`. The session opened two upstream pull requests, which the owner checks on the Mac and merges; nothing here depends on them.

**The owner's decisions, 6 October** (PLAN, "Answered on 6 October, for S9")

- **Axe and the kit's palette:** the app's own markup may have no violations. Inside the reader's frame only the kit's known `color-contrast` and `link-in-text-block` are allowed, until the upstream palette pull request lands; a ratchet then fails the check.
- **Links:** resolved on the server by kit code, after a parse of the link that mirrors the app's dispatcher, with an upstream pull request to move the parse into the kit.
- **Page links and mention counts:** deferred until the kit's two index stores open immutably, in the same upstream pull request.
- **Browse:** the kit's alone. The app's arrangements, front-matter split and document counts wait for an upstream move.

**How the session got there**

- **A map first.** Five readers mapped:
  - the Mac's link handling and cards;
  - the Mac's Browse;
  - the server's pieces and the draft API;
  - axe and the keyboard path;
  - the fixtures.

  They found the four decisions above, and the facts the session built on:
  - every link decision is public kit API, and only the parse of the URL is app code;
  - the kit's light palette fails AA in the frame: person links 3.67:1, cross-references and footnote markers 4.02:1, datelines 3.98:1;
  - no fixture volume has a broken reference;
  - v06's d2 names d1 in a footnote, and d1's heading names Khrushchev.

  The server tests built from these predictions passed on their first run, the persons' and terms' strings included.
- **The browser suite caught two of the session's own mistakes:**
  - the shell moved focus to the heading on a page load too, so Skip to content was no longer the first Tab stop;
  - the narrow sheet's `inert` covered the reader's heading, so axe found no `<h1>`.

  Both are fixed.
- **A stale object in the incremental build.** The full Swift run crashed in FRUSParityTests while copying a `Volume` to encode it. The bad address was the ASCII of "https:/". The test file's object was from S9a: Swift 6.4's cross-module incremental build had recompiled none of the target's files after `Volume` gained stored properties. Rebuilding this package's own targets clean fixed it, and every test passed.
  - CI restores its build from an earlier run, so its swift job now deletes `.build/linux/out/Intermediates.noindex/FRUSLight.build` after the restore. That folder holds only this package's own targets; the dependencies stay cached.
  - `CLAUDE.md`'s building notes say the same for sessions.
- **A review before the pull request opened.** Five reviewers each had a skeptic check their findings. 17 of 28 held, and all were fixed:
  - **The frame's history.** Changing the frame's address added entries to the history inside it. After following a link to a page the browser had cached, Back moved the frame to the previous document while the heading and the Cite rail stayed on the current one, so Copy Citation would have cited the wrong document. Each page now loads in a new frame, and a note in the same document is revealed by the host script without navigating. The suite now checks Back's text and that a second Back leaves the reader.
  - **A long link:** an `href` of tens of kilobytes could keep a CPU busy for minutes in the kit's footnote pattern. Links over 2,048 bytes are refused before any parse.
  - **Hidden failures:** Browse's routes took TEI that would not parse for a volume without contents, and an index that could not be read for one that holds nothing. Both now report their problem.
  - **Names:** a document the index lacks was named by its raw id when it had no number ("intro1"). A prose section is now named by its title, as the kit's reading order names it.
  - **Focus:**
    - a new screen's heading took focus while it still held an id, so a screen reader announced "comp1". The heading now takes focus once it has its title, seeded from what Browse has already read;
    - a note landed on was out of reach of the keyboard. The note now takes focus;
    - a window narrowing below 900 px with the rail open dropped focus to nowhere. Focus now goes to the sheet;
    - a page loaded with Cite open put focus on Cite. Cite now takes focus only when the reader opens it.
  - **State:**
    - a card left open came back, unasked, after Back and Forward. A card or notice now clears with the document;
    - the catalogue's filter could drift from the URL after the header's Browse link or Back. It now follows the URL when anything else changes it.
  - **Presentation:**
    - document lists numbered rows whose headers already carry their numbers;
    - badges ran into the text before them for screen readers and braille.
  - **Tests:**
    - nothing showed the index's structure winning over the TEI's. The parity test now checks `structureSource` and the section ids against the index's;
    - the skip link was never activated in the suite;
    - the ratchet checked only `color-contrast`, and now checks both known ids;
    - the axe test's title claimed more than it covered. It now also covers Browse and a card in dark mode.

  The eleven refuted points include:
  - the nil-volume fallback and the in-place rule, which follow from the kit's own `CrossRefDestination`;
  - a full parse behind the volume page, which `readable` needs;
  - the note pattern's narrowness, which no footnote id in the corpus exceeds;
  - the count's live region, which speaks only when the count changes.

**The upstream pull requests**

Each was built in its own clone at a real path, reviewed by a skeptic, and fixed before it opened. Their descriptions hold the Mac check's commands and results.

- **[#1578](https://github.com/joshbotts/FRUS-Explorer/pull/1578): the reader's page meets WCAG 2.2 AA contrast and marks its links by more than colour.** Branch `claude/reader-aa-palette`, two commits.
  - Light accent `rgb(0,102,204)`, light and dark person names `rgb(0,121,107)` and `rgb(0,179,161)`, light secondary 60% black, and dark accent `rgb(64,156,255)`. Every text colour is at 4.5:1 or more on the page and on the editorial tint.
  - Person and cross-reference links have a quiet underline.
  - `ReaderPageTests`:
    - re-takes the eight head pins. Each head grew by exactly 519 bytes, and with the old values put back they hash to #1575's pins;
    - adds the WCAG arithmetic, a check of every text colour in both palettes, and the underline.
  - At its head:
    - `swift test`: 2,550 tests, all passed;
    - FRUSCoreKitTests: 887 on macOS and on Linux;
    - the Mac build, with the usual 5 warning lines;
    - the full iOS unit run, 6,508 tests, failing only the 8 Keychain tests of an unsigned build, plus a timing flake that `v2` shows too.
  - The owner's items are the colour choice and whether underlines belong on paper; the Mac's File ▸ Print draws the reader's page.
- **[#1579](https://github.com/joshbotts/FRUS-Explorer/pull/1579): the kit reads the reader's links, and the page-range and person stores open immutable.** Branch `claude/reader-link-parse-immutable-stores`, five commits, each of which passes the unit target on its own.
  - `FRUSURLScheme.readerLink(from:)` and `ReaderLink` are the app's dispatcher's parse, moved verbatim, and `dispatch(url:)` now switches on it.
  - `PageRangeStore(readingDatabaseAt:)` and `PersonMentionStore(readingDatabaseAt:)` open `FTS5Store.immutableURI(for:)`.
  - At its head:
    - FRUSCoreKitTests: 891 on macOS and on Linux;
    - `swift test`: 2,554 tests;
    - the full iOS unit run: 6,513 tests, failing only the 8 Keychain tests;
    - the symbol diff: 10 removed and 51 added, each named.
  - It reads a `person` or `gloss` link with no path as the empty ref, as the app always has. The server's parse here now does the same.

When both merge, a pin move:
- switches the server to `readerLink(from:)`;
- opens the two stores immutably for page links and mention counts;
- empties the axe list and its two checks.

**Delivered**

- **The reader's links:** `GET /api/v1/volumes/{v}/documents/{d}/link?href=` (`ReaderLinks.swift`).
  - `ReaderLinkParse` mirrors `FRUSURLSchemeHandler.dispatch(url:)`. A path's parts are decoded twice, a broken reference's target once, and a link's own volume is passed to `FRUSURLScheme.resolveCrossRefTarget`, as the app does.
  - A person or term comes from the reader's lookups, the parse the reader renders with. A broken reference comes from `BrokenRefsIndex.degradableInfo`.
  - A cross-reference gives its destination; a footnote also gives the note's entry id, `fnote-` and `FRUSRenderNode.footnoteDOMKey`. It says `inPlace` for a note of the same document, and what the server holds of the destination's volume, with its history.state.gov URL.
  - A page reference names its page and volume, and stops there.
  - An `href` over 2,048 bytes is refused before it is parsed.
- **Browse on the server:**
  - `/volumes/{v}` gives `structure`: the index's cached structure, else the kit's parse of the mounted TEI, with `structureSource`. Each section has the kit's flags, its document count and how many the index holds, and `readable` (the reader's parse makes it a document).
  - `/volumes/{v}/sections/{s}` lists a section's documents. A document the index lacks is named by `CitableDocumentNumber.rowLabel` ("Document 3"), and a prose section by its title.
  - TEI that will not parse is `TEI_UNREADABLE` on these routes, unless the index gives the structure.
  - `/volumes/{v}/documents/{d}` answers from the TEI for a document the index lacks, or before an import, and each neighbour says whether the reader can open it.
- **The host script:**
  - remembers the link it posted, and refocuses it when the parent asks;
  - scrolls to a note and gives it focus when the parent asks;
  - ignores a middle click on a reader link, which the sandbox would refuse as a popup;
  - lets Space activate an unresolved reference, which the kit marks as a button.
- **Browse in the SPA:**
  - `/` opens `/browse`, and the header gains Browse.
  - The catalogue's filter, subseries and indexed-only choices live in the URL, replaced as they change.
  - The volume page shows the publication, the editors, the coverage ("2 of 120 documents indexed on this server") and the section tree. Its fallback for a volume with no structure is the index's reading order.
  - The section page shows a breadcrumb, its subsections and its documents, with the badges Editorial Note and Not indexed on this server.
- **The reader's links in the SPA:**
  - a cross-reference goes forward, and Back returns;
  - each page loads in a new frame, so the frame adds no history of its own;
  - a note in another document lands through the frame's URL fragment, and one in the same document is revealed by the host script. Either way the note takes focus;
  - a volume not on the server gets a notice with its history.state.gov link;
  - external links appear in a notice with a real link, and page and unresolved references with a sentence;
  - a person, a term or an unresolved reference opens a modal `<dialog>` card with the Mac's titles, sentences and Done. Closing it returns focus to the link in the frame. The not-found cards keep the Mac's titles, with the web's own sentence;
  - Previous and Next replace the history entry, as the app's `DocumentJump` does, and hide a neighbour the reader cannot open.
- **Keyboard and WCAG fixes:**
  - each screen names the tab, and a new screen's heading takes focus once it has its title;
  - a card or notice clears when the document changes, by any route;
  - a search keeps its box's focus; the box is no longer remounted;
  - Escape closes the Cite rail, and below 900 px the toolbar and frame are inert while the sheet is open;
  - the toolbar is a labelled group, not an ARIA toolbar without roving focus;
  - the arrows on Previous and Next are hidden from screen readers;
  - controls have a 3:1 edge (WCAG 1.4.11), and badges carry a comma for screen readers.
- **The browser suite** (`@axe-core/playwright` 4.13.0, exact, with axe-core 4.13.0):
  - `web/e2e/fixtures.ts` fails any test on a console error;
  - `axe.ts` holds the check and the kit's known list;
  - `keyboard.ts` tabs to a target in the app or the frame;
  - `browse-link-card.spec.ts` runs the done-when walk, a footnote landing and a missing volume, and axe over every screen in both appearances and beside the narrow sheet.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, and step 6, which adds Browse, links and the API's new routes;
  - `SPEC.md`: Reader rendering step 4, the API table, four departures, and Browse's routes;
  - `PLAN.md` and its shared copy (rev 108): the owner's S9 answers, with the upstream pull requests;
  - `COORDINATION.md`: the two upstream pull requests.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,711 tests pass, up from 1,701, with the one named skip, which CI's skip check allows.
  - FRUSLightServerTests runs 71, up from 61: the link route for every kind of link, every link on five fixture pages, a broken reference from a decoded index, the refusals, the structure from the TEI, a section's documents, a document the index lacks, and TEI that will not parse.
  - FRUSParityTests' browse check now also requires the index's structure, by its section ids. The run printed check 3 and check 4 through the API as before, and "browse through the API: 3 volumes of 553 indexed, 139 of 140, 123 of 128, 130 of 134 entries in reading order held by the index".
- **The web app:**
  - typecheck, lint, and 33 unit tests in 9 files;
  - the build: `index.html` 0.5 KB, CSS 5.8 KB, and one script of 364 KB, 115 KB compressed.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image, still 400 MB. The suite runs five tests on Chromium:
  - **the done-when walk, by keyboard alone:**
    - Skip to content first, and Enter on it leaves `main` focused;
    - the catalogue narrowed to one volume, then its page, focused at its heading ("2 of 120 documents indexed on this server");
    - its compilation, then d2;
    - Enter on "Document 1" in the frame goes forward to d1, focused at its heading;
    - Enter on "Khrushchev" opens the card "Khrushchev, Nikita S.", "Chairman of the Council of Ministers of the Soviet Union", focused at its title;
    - Escape returns focus to the link in the frame;
    - Back returns to d2 with d2's text, and a second Back leaves the reader;
    - axe at the catalogue, the volume, the section, the reader and the card: none of the app's own markup fails, and in the light reader the frame fails `color-contrast` alone;
  - a note in another document lands in view and takes focus, and a document in a volume not on the server gives its history.state.gov link;
  - axe over Search, the reader with Cite, the narrow sheet (whose text is inert, and Escape returns focus to the toggle), a card, and, in dark, the reader (whose frame fails `link-in-text-block` alone) and Browse's three screens;
  - S9a's two tests.

  That is S9b's done-when, read as the owner decided: no axe violations in the app's markup, and only the kit's known two in its frame, until #1578 lands.

**Notes**

- **The frame's known failures, as axe reports them:**
  - `color-contrast` alone in the light reader (frus1961-63v06 d2);
  - `link-in-text-block` alone in the dark reader (d1), where the links pass 4.5:1 but differ from the text around them by colour alone.

  The suite asserts each, so each id on the known list is shown to be needed, and a pin move that fixes one fails its check. The map had predicted `link-in-text-block` in light too, for a cross-reference among footnote text. axe does not count a link that is nearly all of its list item as a link in a block of text.
- **Rule 4 glue, recorded:**
  - `ReaderLinkParse`, about 20 lines, until the kit's `readerLink(from:)`;
  - the `fnote-` prefix the kit's serializer writes, joined to the kit's own `footnoteDOMKey`.
- **No fixture has a broken reference.** The server test decodes a one-record `BrokenRefsIndex`, renders d2's link as broken, and resolves it. The card's text has unit tests.
- **A target that names a whole volume** (`frus1961-63v05`) resolves, as the kit does, to a document of that name in the current volume, and the reader then says it has no such document. The links pull request files a `.volume` case.
- **`href="#"`:** a person or term with no ref is still a Tab stop that scrolls the frame to its top, as in the app, until the kit writes a span for it.
- **Parse cost:** the volume page and a document the index lacks parse the volume's TEI, about half a second for the largest, shared with the reader's cache of four volumes.

**Next: S10.** The owner's real export imported into Compose, with the TEI folder mounted read-only; checks 3–5 pass on the real export, which is phase 1's exit. Before it: the owner's Mac check of the two upstream pull requests, then a pin move that empties the axe list and brings page links and mention counts. The phase-1 features' upstream pull request is timed so its pin move comes just before S10's export.

## Session 9a: the browser app's foundation, and a citation copied in Chromium

6 October 2026 · branch `claude/s9-web-client`

S9 became two pull requests at the start, by the owner's choice: S9a meets S9's done-when first, and S9b completes the phase-1 SPA. The owner also chose three things before any code:
- npm through a Docker wrapper, `scripts/npm`, as Swift goes through `scripts/swift`;
- the publication year from the manifest now, rather than waiting for the app's TEI rule upstream;
- the citation endpoint in the kit and the server only, with no upstream pull request.

The pin stays at `101e17d7`, and nothing upstream changed.

**How the session got there**

- **A map first.** The map read the kit's citation API at the pin (`CitationStyle`, `makeFormatter`, `FRUSDocumentMetadata(citing:printedNumber:)`, `FRUSVolumeMetadata(entry)`, `CitationPlainText`, `CitableDocumentNumber`, `FRUSCanonicalURL`) and Hummingbird 2.27's middleware.
  - Router middleware applies only to routes added after it, and the not-found responder runs all of it.
  - `FileMiddleware` serves files only where a route has answered 404, and has no fallback for an SPA's client routes.
  - `ContentSecurityMiddleware` adds a second policy header, which would have doubled the reader page's.
  - The manifest's publication year equals the year the app reads from the TEI header for all 553 published volumes, so the manifest's year changes no citation.
- **A review before the pull request opened.** Five reviewers each had a skeptic check their findings. 26 of 32 findings held, about 20 once duplicates are merged, and all were fixed:
  - **HEAD /readyz answered 200 with the app's page** before any import. The router made no HEAD responder for its GET routes, so a HEAD fell through to the app's fallback. Every GET route now answers HEAD itself. The fallback's own HEAD had sent a length of 0; it now sends GET's headers.
  - **The router lays a route's checked search over the raw one,** so a field the check dropped kept the URL's string. A URL with `limit=20` paged to `offset=020`, then `2020`, and `offset=-5` or an empty date reached the server. The check now returns every field.
  - **Focus:**
    - focus did not reach a new screen's heading, because the shell moved it before the screen rendered; it now waits for the router's `onRendered`;
    - changing the citation style or the page unmounted the control that had focus. The previous citation (for the same document only) and the previous page of results now stay while the next loads, and Copy Citation waits for its own style.
  - **The reader and Cite:**
    - the page check refetched when the tab regained focus, and a failure then replaced an open document with an error;
    - the Cite toggle was a link, announced as the current page. It is now a button with `aria-expanded` that toggles in place, without a history entry;
    - below 900 px the rail sat below the frame, off screen. It is now a sheet over the text, with Close, and takes focus.
  - **Search:**
    - the same search could not be asked again after a refusal, and nothing was asked again once an index became ready;
    - a page past the end said both "2 documents match" and "No documents match.", with "Page 61 of 1".
  - **Preferences:** with storage blocked, a choice was lost on the next remount. Every reader now shares this page's choices.
  - **Strings:** `copy.ts` claimed the Mac's wording where it had a string, but differed. It now uses Copy URL, Document type with All, and Text Size, and claims no more than that.
  - **The citation endpoint:**
    - `numberSource` said `index` for a number the id spelled. It now says `documentId`, and is absent when there is no number;
    - the docs had described only `_…_`, but Chicago and Turabian write `*…*` around the whole title.
  - **Tests:**
    - the fallback test's reader path had an extension, so it never tested the `/reader/` exclusion;
    - the precedence test could not tell the index's number from the id's. The index now says 7 where the TEI and the id say 1.
  - **Scripts:**
    - `vite preview` listened on 4173 while `scripts/npm` published 5173;
    - on Linux without Node, `run dev` sent the API to `host.docker.internal`; it now shares the host's network;
    - the doctor took an empty `node_modules` volume for an install, and now looks inside it.

  The six refuted points:
  - the app's error pages lack its policy, but they are Hummingbird's plain 404s, with no page to protect;
  - client routes serve an `index.html` read at start, which differs only when `web/dist` is rebuilt under a running server, never in the image;
  - INSTALL's "History at State" is the kit's own name for the style;
  - PLAN's copy of the session rules records session 0's;
  - the missing log entry, which is this one.

**Delivered**

- **`scripts/npm`:** npm for `web/`.
  - It runs natively on Linux when Node at `web/.node-version`'s major is on PATH, as in CI after `setup-node` and in a cloud session. Otherwise, and always on a Mac, it runs in `node:22-bookworm-slim`, with `web/node_modules` in a Docker volume per checkout, since Linux builds of esbuild and Rollup cannot run on macOS.
  - `--playwright` runs `npx playwright test` in `mcr.microsoft.com/playwright` at the version the lockfile holds, and `--playwright-image` prints that image.
- **The server serves the SPA** (`WebClient`, `WebClientMiddleware`), from `FRUS_WEB_DIR`, which defaults to the image's `/usr/share/frus-light/web`.
  - A GET or HEAD outside `/api/` and `/reader/` gets a file of the build when there is one. Any other path whose last segment has no extension gets `index.html`, so a client route survives a reload. A missing script stays a 404, and an unknown API path keeps its problem details.
  - Every response of the app's carries its own policy: `default-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`, with `nosniff` and `Referrer-Policy: no-referrer`.
  - Files under `/assets/` are cached as immutable for a year; everything else is `no-cache`.
  - Without a build at the default the server serves the API alone. A folder that `FRUS_WEB_DIR` names must hold one, or the server exits with status 2.
- **`GET /api/v1/volumes/{v}/documents/{d}/citation`:** the kit's formatter, as the app's Cite uses it, in `historyAtState` (the default), `chicago` or `turabian`.
  - It returns `citation` with the formatter's Markdown emphasis, and `plainText`, which is what Copy writes.
  - It also returns the canonical URL, the document number and label, and the styles with the kit's names for them.
  - The number is the index's; for a row with none, or with no index, it is the TEI's printed number. The response names its sources: `numberSource` for the number and `publicationYearSource: "manifest"` for the year.
- **`web/`:** React 19.3, TanStack Router 1.170 (code-based routes) and Query 5.104, Vite 8.3, TypeScript 6.0, Vitest 5 with jsdom, ESLint 10, and Playwright 1.63, with exact versions and a lockfile.
  - **The shell:** a skip link, the appearance (System, Light or Dark), a banner while no index is served, focus on each screen's heading, and the footer's notice that an instance is not an Office of the Historian service.
  - **Search:** the query box with a summary of the syntax; the document-type, date and front-matter filters, and volume chips; the exact count with its coverage; snippets whose `<b>` markers become `<mark>`, never markup from a string; and pages of 10 to 100, as far as the 7,500th result. Every search is a URL, in the server's form encoding.
  - **The reader:** a check of the page before the frame loads it, so an error shows as a notice; the server's page in an iframe sandboxed with `allow-scripts` alone; Previous and Next; text size; and Open on history.state.gov. A link inside the page shows a notice until S9b.
  - **The Cite rail:** the three styles, from the server, with the choice remembered; Copy Citation and Copy URL; and Close. Beside the text from 900 px wide, a sheet over it below that. Where the browser refuses the clipboard, the text is selected in a field.
  - `copy.ts` holds every string. ESLint forbids `dangerouslySetInnerHTML` and assignments to `innerHTML`.
- **The image:** a client stage on the build platform runs `npm ci` and `vite build`, and the runtime copies `dist` to `/usr/share/frus-light/web`. The server stage now copies only what it builds, and `.dockerignore` keeps everything else out.
- **`scripts/compose-smoke`:**
  - before the import, it checks that `/` and two client routes give the same `index.html` with the app's policy, that the app's script is immutable, and that a missing asset and an unknown API path are 404s;
  - `--e2e` runs `web/e2e` in the server's network namespace, so the app is at `http://localhost:8080`, a secure context, which the clipboard needs.
- **CI:**
  - a `web` job: `setup-node` at `web/.node-version`, then typecheck, lint, unit tests and the build, and a check that the Dockerfile's Node image is the same major;
  - the compose job runs `scripts/compose-smoke --e2e` and uploads Playwright's report when it fails;
  - `image.yml` builds on pull requests that touch `web/`.
- **`scripts/doctor`:** a Web section for the Node image, `web/node_modules` and the Playwright image. A missing Playwright image is a note, not a fix, since only `--e2e` needs it.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, and step 6, which becomes search, read and cite in the browser, with the API after it;
  - `SPEC.md`: the citation endpoint, how the SPA is served and cached, its policy, `FRUS_WEB_DIR`, and the reader frame's sandbox;
  - `PLAN.md` and its shared copy (rev 105): S9a and S9b;
  - `CLAUDE.md`: **rule 1 now names `scripts/npm` in place of `npm --prefix web`**, and the building notes add it and `--e2e`.
  - the README's status.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,701 tests pass, up from 1,693, with the one named skip, which CI's skip check allows. FRUSLightServerTests runs 61, up from 53: the citation route in each style, the number's three sources, the printer's name either side of 2014, and the app's files, client routes, policy, caching and HEAD, with what the fallback must leave alone.
- **The web app:** typecheck, lint, 26 unit tests in 7 files, and the build: `index.html` 0.5 KB, CSS 4.5 KB, and one script of 348 KB, 111 KB compressed, with no inline script and no source map.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image, still 400 MB, since the app adds 364 KB:
  - before the import, `/` and two client routes give the same page with the app's policy, its script is immutable, and a missing asset and an unknown API path are 404s;
  - after it, Playwright 1.63 on Chromium, in `mcr.microsoft.com/playwright:v1.63.0-noble`, searches "treaties" and finds the two documents, their matches marked;
  - it opens frus1961-63v06 d1, focused at its heading, finds the document's text in the frame and the host script running there under the sandbox and the page's policy;
  - it opens Cite, which takes focus, chooses Chicago and copies the citation. The clipboard holds the API's `plainText`, which is the same text the Swift test holds;
  - Close hands focus back to the toggle, and Back returns to the results, focused at their heading. No console error or policy violation occurred in the page or the frame.

  That is S9's done-when.

**Notes**

- **The frame's origin.** The sandbox without `allow-same-origin` gives the reader's page an opaque origin, yet its policy's `'self'` still admits `/reader/host.js`, since `'self'` is the page's URL's origin. The browser suite checks that the host script ran inside the frame. The page's messages arrive with origin `null`, so the app accepts them by their source, the frame's window.
- **The clipboard** needs a secure context. `http://localhost` is one, but another machine's address over plain http is not, so the panel's fallback selects the text there. Phase 3's TLS proxy makes the clipboard work for a shared instance.
- **On a Mac,** `web/node_modules` lives in a Docker volume, so an editor's TypeScript service cannot see the packages. Running `npm ci` natively as well would give it a copy.
- **Not yet, for S9b:** Browse, the reader's links and the person and gloss cards, a keyboard-only path, and an axe check. Display titles, BibTeX and RIS wait for the phase-1 features' upstream pull request.

**Next: S9b.** Browse (the catalogue and a volume's reading order), the reader's links (`doc/` navigates, `person/` and `gloss/` open cards, `brokenref/` the Unresolved Reference sheet), a full keyboard path, and an axe check in the browser suite. Its done-when: Playwright browses to a volume, opens a document, follows a link inside it and opens a person card, by keyboard alone, with no axe violations.

## Session 8c: search, browse and the reader's page over the imported index

6 October 2026 · branch `claude/s8c-search-browse-reader`

S8's last pull request serves the endpoints over the kit's read-only stack, which S8b's pin move brought in, and runs check 3 through the API on the real Import path. That is S8's exit. The pin stays at `101e17d7`, and nothing upstream changed.

**How the session got there**

- **No new map.** S8's map at the start of S8a had designed these endpoints. S8b had confirmed every kit call they make at the pin: the read-only opens, the search service, the browse calls, `ReaderPage`, `reader(figureURL:)` and `FRUSURLScheme`. This session checked the rest against the source: the search result's fields, `document(forDocumentId:inVolume:)`, `datesByDocumentKey`, `effectiveIsEditorialNote` with `applyingClassificationOverride`, `FRUSCanonicalURL` and the parser's detailed result.
- **A review before the pull request opened.** Five reviewers and a skeptic per finding; 12 findings held, some found more than once, and all were fixed:
  - **A stack opened between an import's rename and the switch:** it could have opened the new file over the path and been kept as the old index's stack. `CorpusIndex` now records the file it opened (device and inode), and a stack whose path names another file is refused with a 503, which the next request retries.
  - **The smoke test's search check** depended on the JSON's key order, which varies from run to run.
  - **Two gaps in the tests:** the browse test now holds each list to the kit's reading order, and a synthetic test shows the index's classification reshaping a page.
  - **The records:** INSTALL's example `NEAR` was no proximity search; SPEC's security bullet still described three app scripts; the list of departures from the draft was incomplete; the claim of drift covered one script, not three; and a few sentences, here and in comments, were in the future tense or gave a wrong code.

  The six refuted points include a weak `If-None-Match` comparison, which this route's own weak tags make unnecessary, and links followed inside a figure folder, which the owner's own mounted folder holds.

**Delivered**

- **The served stack** (`ServedIndex`, `ServedIndexProvider`):
  - for each installed index, `FTS5Store(readingDatabaseAt:)`, `IndexingPipeline(readingIndexAt:…)` over the TEI folder, and a `SearchService`, opened off Swift's pool with `Blocking.run`;
  - built on the first request that needs it, shared by the requests after, and built again when an import installs a new index. Requests already holding the old stack finish on the file they opened, whose immutable connections keep reading it.
  - A route that needs an index answers 503 `INDEX_NOT_READY` until one is served, naming the readiness step.
  - A stack is refused, with a 503 the next request retries, when the path no longer names the file its `CorpusIndex` opened, as between an import's rename and the switch to the new index. `CorpusIndex` now records that file's device and inode.
- **`GET /api/v1/search`:** S8a's decoder, then the kit's exact `searchCount` and one page of `search`.
  - It returns `{total, countBasis: "exact", limit, offset, retainedLimit: 7500, items, coverage}`.
  - Each item has the draft's `SearchResult` fields, `bm25Score` among them, whose bits survive the JSON, and the kit's `isFrontMatter`, which the draft lacks.
  - A query with nothing left to search is 400 `EMPTY_QUERY`, carrying the kit's refusal, `emptyQuery`, as `searchError`.
  - Snippets keep the kit's `<b>` markers and are not escaped; a client escapes them.
- **`GET` and `POST /api/v1/search/inspect`:** what the kit compiles for the same parameters, the parse of the typed text with the structured fields, then each table's MATCH expression, in the keys of the parity harness's expression records.
  - A refused query is a 200 naming the refusal.
  - Before an import it compiles on a scratch index in the temporary folder, since compiling reads no index.
- **Browse:**
  - `GET /api/v1/volumes/{v}` adds the volume's structure, its front matter, chapters and back matter, when the index holds it.
  - `GET /api/v1/volumes/{v}/documents` lists the volume in reading order (`readingSequence`), with each entry's date and whether the index holds it, in pages of up to 1,000.
  - `GET /api/v1/volumes/{v}/documents/{d}` gives the document's metadata in place of the draft's render model, which the kit cannot encode: its effective classification, its canonical URL on history.state.gov, and its neighbours in reading order.
- **The reader's page,** by default from `…/html`, with `part=body` for the fragment alone:
  - `ReaderPage.build` in the draft's `colorScheme` and `textSize`, with `<script src="/reader/host.js" defer>` in its head;
  - figure images named by the server's address, through `reader(figureURL:)`;
  - when an index is served, its effective classification of the document reshapes the parse first, as the app's reader does;
  - a weak ETag of the rendering version and the page's bytes, with 304 for `If-None-Match`;
  - a policy that loads nothing from elsewhere and runs only the host script and the figure handler, which it allows by its SHA-256.
- **`GET /api/v1/volumes/{v}/figures/{file}`:** a `.png` from `<volume>.figures/` beside the TEI, where FRUS Explorer keeps a volume's figures. A volume outside the manifest is 404 `VOLUME_NOT_FOUND`. A name that is not a single safe path component (`FRUSURLScheme.isSafeComponent`), or not a `.png`, or a missing file, is 404 `FIGURE_NOT_FOUND`.
- **`GET /reader/host.js`:** the web's stand-in for the app's WebKit host. It gives the three message handlers the app's reader scripts post to, and handles the reader's `frusexplorer://` links. Each becomes a message to the parent page.
- **`scripts/compose-smoke`,** after the import: a search finding the synthetic export's two documents, a document's page with its host script and policy, and the host script.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, and step 6, search and read;
  - `SPEC.md`:
    - Reader rendering's steps, among them that `frus-print.css` is for collection exports, and that the Resources copy of `frus-highlights.js` has drifted from the script the app injects;
    - the reader page's own content security policy;
    - the exact count with the 7,500 retained;
    - the draft's retired `/subjects` struck from the API table;
    - where the API departs from the draft;
  - `COORDINATION.md` and the README.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,693 tests pass, up from 1,675, with the one named skip, which CI's skip check allows. FRUSLightServerTests runs 53, up from 38, and FRUSParityTests 98, up from 95. The run printed:
  - "check 3 through the API: 482 queries, 482 identical and 0 reordered only within Mac tie groups, every record the kit's own; 482 compiled as the golden file says, 43 refused; the live index unchanged";
  - "check 4 through the page: 392 of 392 rows identical, 8 figure images in 2 rows named by the server; one head for every page";
  - "browse through the API: 3 volumes of 553 indexed, 139 of 140, 123 of 128, 130 of 134 entries in reading order held by the index", each list the kit's reading order;
  - checks 2 to 4 in process, as at the pin move.

  The kit's fixture index is dropped into the drop zone as a copy, imported, checked and installed. It is then served through the read-only open, and every query is read over HTTP with the golden tool's results loop. Check 3 passes through the API: S8's exit.
- **The Compose smoke test** passes on the local arm64 image: after the import, a search finds the synthetic export's two documents, and frus1961-63v06 d1's page, 21,837 bytes, comes with its host script and policy.

**Notes**

- **One stack for every request.** The pipeline is one actor on one connection, so searches, counts and browse calls take turns, and its SQLite runs on Swift's cooperative pool, as a volume's parse does (S8a). That suits one user. Check 12's load target needs a pool of stacks over the same immutable file, and parsing moved off the pool.
- **Not yet:**
  - **Facets, date sort and the full inspector:** the kit's facets are internal, and the app's date order and Query Inspector are app code.
  - **The reader's own scripts:** `kOffsetEngineJS` and the others are app constants.
  - **The publication year a citation takes from the TEI:** app code.

  All of these wait for the phase-1 features' upstream pull request. Persons, terms and cross-references wait for S9 or later.
- **The fixtures cannot show the classification override.** Every fixture document's classification in the index is its TEI's, so check 4 through the page shows only that the override changes nothing where nothing is overridden. A synthetic server test marks a document as an editorial note in the served index and finds its page reshaped as one.

**Next.**
- S9: the browser app for phase 1, Browse, Search, the reader and Cite, over these endpoints. Cite needs a citation endpoint (the kit's formatter is public; the TEI's publication year is app code).
- The phase-1 features' upstream pull request: the reader's scripts, the publication year, facets, the inspector, date order, display titles, and BibTeX and RIS. It is timed so its pin move comes just before the full export for S10.
- A web session adds the daily watch of the app's `v2`.

## Session 8b: pin move to the read-only open and the reader's page

6 October 2026 · branch `claude/pin-101e17d` · upstream [joshbotts/FRUS-Explorer#1575](https://github.com/joshbotts/FRUS-Explorer/pull/1575) (merged as `101e17d7`)

S8a's upstream pull request merged on `v2` as `101e17d7`, directly after the old pin. This pull request moves the pin there (rule 5). That brings the kit's read-only open, a host's figure addresses and the reader's page into this repository's build. It remakes the golden files from the owner's new export, and tests the read-only open on the fixture index on Linux. The index version (65), the FTS generation (4) and the app's build (49) are unchanged, so the server, the image, `compose.yaml` and `docs/INSTALL.md` are too.

**How the session got there**

- **A map first.** Three readers mapped the records and line citations the move makes stale, the build and the Mac-side tools, and the tests. The build side needed one change. #1575's two new suites hash with CryptoKit, which is swift-crypto's Crypto on Linux. `tools/mac-golden`, `CompatibilityTests` and CI's skip check needed nothing. The app's `HTMLTemplate.build` keeps its signature and forwards to the kit's page, and the new suites have no skip traits.
- **A review before the pull request opened.** Four reviewers and a skeptic per finding; three findings held, one found twice, and all were fixed:
  - the read-only tests took the file's baseline after opening it, so a write made while opening would have passed; the baseline is now the file as copied, checked again once the connections close;
  - the tests compared the compiled expressions, which read no index, as evidence about the read-only connection; that comparison is gone;
  - one sentence of this entry.

  The map also found that the writable index's 482 queries ran twice per process; `FixtureIndex.results()` now runs them once, for check 3 and the read-only comparison.

**Delivered**

- **The pin, `101e17d7`,** and `Package.swift`: FRUSCoreKitTests gains Crypto on Linux. FRUSCoreKitTests runs 884 tests in 118 suites, up from 878 in 116.
- **The golden files,** remade by `scripts/make-golden --export` from the owner's export (below):
  - **All 392 rows' HTML** are byte for byte as before, and so are the expressions and the results. Only the provenance changed.
  - **The index summary's 36 gating digests and 7 checks** are the same. Four information fields changed, none of them compared:
    - the export's stamp;
    - the timings;
    - `volume_structures`' JSON key order, already information because the app writes those keys unsorted;
    - the AUTOINCREMENT counters, which about doubled because the library's tables were emptied and filled again.

  So the reader's page moving into the kit, and the figure case beside `.reader`, changed nothing the app writes.
- **The read-only open on the fixture index** (`ReadOnlyOpenTests`, 3 tests). A copy of the kit's fixture index in rollback-journal mode, alone in a folder as `/data/index/frus.db` is, is opened through `FTS5Store(readingDatabaseAt:)` and `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:)`:
  - **Search:** all 482 queries' counts, first 50 results and tie tails, score bits included, are the writable index's. So the read-only connection runs every query as the writable one does, the `=exact` queries among them, which need `frus_exact_word` registered on it.
  - **Browse:** each volume's documents, reading order and cached structure are the writable index's.
  - **Writes:** a write is refused by SQLite as read-only, code 8, with the fixtures' TEI in reach, so the refusal is not a missing volume's.
  - **The file:** it is as it was copied, before anything opened it: the same SHA-256, only `frus.db` in its folder, and header bytes 18 and 19 still 1. Each test checks that after its connections close, and the search test while they are open too.
- **What #1575 gives the reader** (`ReaderPageParityTests`, 3 tests), on all 392 golden rows along the server's full-parse path:
  - `reader(figureURL:)` given the app's own addresses writes `.reader`'s bytes.
  - A host's addresses change exactly the 8 image sources, 7 in frus1969-76ve09p1's d87 and 1 in d116. Mapped back, every row is the golden file's.
  - `ReaderPage.build` holds each row's golden fragment between its one `<body>\n` and `\n</body>\n</html>`, after one head shared by every document. Dark and extra large change the head only.
- **The harness:** `ReaderRenderer.fullParsePass` takes what writes each document, the reader's fragment by default.
- **Records:**
  - five line citations of `IndexingPipeline.swift`, which #1575 moved: four in the harness's comments and SPEC's `setupDatabase` range;
  - `COORDINATION.md`: the pin, the test counts, the read-only open and #1575's pin move;
  - `PLAN.md` and its shared copy (rev 104): the Golden files checkpoint and the risk row;
  - `SPEC.md`'s compatibility contract;
  - the prep note;
  - `Package.swift`'s comments.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,675 tests pass, up from 1,663, with the one named skip, which CI's skip check allows. FRUSCoreKitTests runs 884, and FRUSParityTests 95, up from 89; the other targets are unchanged. Against the new golden files the run printed:
  - "check 2 passes: 36 digests and 7 checks are the Mac's";
  - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups; 359 with other score bits (information)";
  - "check 3's expressions: 482 of 482 queries compile as the golden file says, 25 of them outside the default scope; 43 refused";
  - "check 4, the reader's path: 392 of 392 rows identical", and so along the full-parse path and through the API;
  - "the read-only open: 482 queries' results are the writable index's, score bits included; 43 refused by both; the file is as it was copied";
  - "a host's figure addresses: 8 images in 2 rows; mapped back, 392 of 392 rows identical";
  - "the reader's page: 392 of 392 rows' bodies identical, one head for every document".
- **The Compose smoke test** passes on the local arm64 image, built at the new pin.
- **The first run at the new pin** overlapped `make-golden`. Its only failures were three staleness checks on the files made from the export, which had not been rewritten yet, and FRUSCoreKitTests' 884 tests passed, none skipped.

**The owner's export**

Made on 6 October from a build of `101e17d7` after Erase Everything…, and checked in S8a's entry: build 49, index version 65 and FTS generation 4, with none of the owner's writing, the three fixtures only, and no log or journal beside it. `make-golden` copied it to a temporary folder and worked on the copy alone.

**Notes**

- **The tools still cannot tell exports of `f69b4a0a` and `101e17d7` apart:** their build and index version are the same. Only the procedure, and `exported_at`, distinguish them.
- **Left to S8c,** which serves the full page: SPEC's Reader rendering steps 2 and 6, which still name `HTMLTemplate` and `FRUSTheme.cssVariables`, now the app's forwarders to `ReaderPage`.

**Next.**
- S8c: search, browse and the reader's full page over the read-only stack, with figures by the server's own address, and check 3 through the API on the real Import path.
- A web session adds the daily watch of the app's `v2`.

## Session 8a: the read-only open upstream, and the server links the kit

6 October 2026 · branch `claude/s8-search-reader-api` · upstream [joshbotts/FRUS-Explorer#1575](https://github.com/joshbotts/FRUS-Explorer/pull/1575) (merged as `101e17d7`)

S8 serves search, browse and the reader over the imported index. A map at the start found that it cannot do so at the pin: every kit opener writes to the database it opens. `FTS5Connection` switches the file to write-ahead logging, and `IndexingPipeline`'s set-up runs schema statements and four writes that throw on a read-only connection. Pointed at `/data/index/frus.db`, the kit would rewrite the file under the server's immutable reader and leave `-wal` and `-shm` files beside it. So S8 became three pull requests. This session opened S8a's upstream pull request, which the owner checked and merged. It also built the web groundwork that needs no new upstream API, at the old pin `f69b4a0a`.

**The owner's decisions, 6 October**

- **Split:** S8a (the upstream pull request, plus web groundwork at the old pin), S8b (the pin move, with a new three-volume export) and S8c (the endpoints, with check 3 through the API).
- **Upstream scope:** the read-only opens, the reader's page and the host's figure addresses. The reader's scripts, the publication year, facets, the inspector, date order, display titles and BibTeX and RIS wait for a later upstream pull request of phase-1 features.
- **API shape:** the draft, extended where the Mac needs more (`PLAN.md`, Answered on 6 October).
- **Check 3:** through the real Import path. The kit's fixture index goes in as an unstamped copy, and is searched through the read-only open.

**How the session got there**

- **A map first.** Five readers mapped the API contract, the server, the kit's search and browse, the rendering, and parity through the API, and a sixth synthesized the plan and the four decisions above. Three of their claims did not hold:
  - **`+` in a query string.** Hummingbird's `uri.queryParameters` leaves `+` as it is, but a browser's `URLSearchParams` writes a space as `+`. The server reads the raw query with form semantics instead.
  - **`frus-print.css`.** The app loads it for collection exports only, not in the reader, as SPEC's Reader rendering step 3 says.
  - **The 7,500 cap.** It limits only how many results the app keeps. The count is exact, so SPEC's "at least 7,500" does not match the Mac.

  S8c corrects SPEC for the last two.
- **A review before the upstream pull request opened.** Four reviewers and a skeptic per finding; 11 findings held and all were fixed. Among them:
  - the test of the pipeline's refusal of a missing file passed without reaching the pipeline;
  - one refusal message was wrong;
  - three doc sentences claimed more than the code does.
- **A review before this pull request opened.** Four reviewers and a skeptic per finding; 12 of 21 findings held, all fixed:
  - the log named `Blocking.run` as the way to move parses off Swift's pool, which it cannot do (Notes);
  - the date check took a digit carrying a combining mark as a digit;
  - `/api/v1/status` took parameters it ignores;
  - the image copied the data files with the checkout's modes, which a strict umask would make unreadable to the server's user;
  - no test reached the route's lookups, the cache's order, an unparseable volume, or the middleware's 500;
  - six sentences in the records and comments.
- **One mistake.** Text holding backticks went through an unquoted heredoc, and the shell ran the backticked commands, among them a Linux build and test run in this worktree. The session stopped them, confirmed that both checkouts were clean and that nothing was left running, and wrote the pull request's description with a file instead. Text with backticks now goes only through quoted heredocs or files.

**The upstream pull request**

Branch `claude/web-readonly-reader-page`, from `v2` at `f69b4a0a`: seven commits in review order. Its description holds the Mac check's commands and expected results.

- **`FTS5Store(readingDatabaseAt:)`** opens `file:…?mode=ro&immutable=1` read-only. It checks the FTS generation and both tables, and sets only the busy timeout, in-memory temporary tables and the cache sizes. It never sets the journal mode.
- **`IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:)`** opens the same way. It skips `setupDatabase`, the cache-insert statement and the iOS memory observer, and still registers `frus_exact_word`, without which every `=exact` query breaks. `isReadOnly` says which open made a pipeline.
- **Figures:** `FigureImages.linked(url:)` writes the reader's markup with the host's address, and `FRUSRenderNodeHTMLSerializer.reader(figureURL:)` wraps it. `FRUSURLScheme.figureURL(for:)` and `isSafeComponent(_:)` are public.
- **The reader's page** moved into `FRUSCoreKit/TEI/ReaderPage.swift`: `ReaderPage.build(model:appearance:textSize:serializer:head:)`, its CSS, and `ReaderAppearance`. `TextSizePreference` moved too, keeping its name. `HTMLTemplate` and `FRUSTheme` forward to them.
- **Tests:**
  - `IndexReadOnlyOpenTests`: nine queries answer read-only exactly as read-write, score bits included. The index browses, refuses a write, and keeps the same bytes with nothing beside it.
  - `ReaderPageTests` pins the SHA-256 of the page's head for both appearances and all four text sizes, recorded from `v2`'s `HTMLTemplate.build` before the move.
  - FRUSCoreKitTests goes from 878 tests in 116 suites to 884 in 118.

**Results at its head**

- **Linux,** in a scratch checkout with the branch in its submodule folder:
  - "✔ Test run with 884 tests in 118 suites passed", none skipped;
  - the read-only open answers as the writable one, on macOS too;
  - this repository's harness failed only its staleness checks.
- **`tools/mac-golden`,** built against the branch, wrote the HTML of all 392 rows and the expressions of all 482 queries byte-identical to the committed golden files. Only their provenance changed.
- **macOS and iOS**, which the upstream description gives in full:
  - both Mac builds have the same five warning lines;
  - the normalized symbol diff is 14 removed and 92 added, each name explained;
  - the full unit run gives 6,505 tests in 767 suites, failing only the 8 Keychain tests an unsigned build fails, against `v2`'s 6,498 in 765;
  - `swift test` gives 38 runs and 2,547 tests, all passed.

The owner ran the Mac check, and #1575 merged on `v2` as `101e17d7`, directly after `f69b4a0a`.

**Delivered in this repository** (at `f69b4a0a`)

- **`FRUSLightAPI`,** a new library target, holds the HTTP application. It depends on FRUSLightCore, FRUSCoreKit, FTS5Store, Hummingbird, swift-service-lifecycle and swift-log. FRUSLightServer keeps the command line, the configuration from the environment and the health check, and FRUSLightCore still links no kit.
- **The app's data files.**
  - **The setting:** `FRUS_RESOURCES_DIR`, by default `/usr/share/frus-light/resources`, where the image copies `FRUSExplorer/Resources` whole. `scripts/swift` points it at the submodule's folder.
  - **The load:** `ServerResources` reads the manifest through the kit's `FixedVolumeCatalogue`, the broken-refs index and `IndexingResources.loading(fromDirectory:)`, once at start. A folder lacking any of the five files it needs stops the server with exit status 2, naming them, before anything is written.
- **Problem details.** `APIProblem` answers RFC 9457 `application/problem+json`: `{type: "about:blank", title, status, detail, instance, code, searchError?}`. A middleware gives every error under `/api/` that shape, including a path no route matches; an unexpected error is logged and answered as a 500 that names nothing internal.
- **The catalogue.** `GET /api/v1/volumes` takes the draft's `status`, `subseries`, `limit` and `offset`, with pages of up to 1,000 so one request lists all 553. `GET /api/v1/volumes/{v}` returns the draft's fields, written by the server rather than by the kit's `Encodable`, which would add the app's `provenance`. Each volume says whether the index holds it, how many of its documents, and whether its TEI is in the mounted folder. The list carries `coverage`: indexed volumes and documents, the 553 manifest volumes and the index version. `CorpusIndex` now counts documents per volume when it opens.
- **The reader's body.** `GET /api/v1/volumes/{v}/documents/{d}/html?part=body` renders through check 4's full-parse path:
  - `ReaderService`, an actor, parses each volume once with `parseVolumeFull` and keeps the four most recent. A volume whose file changes size or modification time is parsed again, and requests for a volume being parsed wait for that parse.
  - Each document renders with the reader's lookups, the converter with the bundled broken-refs index, and the `.reader` serializer.
  - It needs no index, so it answers before an import. Only a manifest id is ever joined into a path.
  - A volume that will not parse is a 500 `TEI_UNREADABLE`, and is not kept, so the repaired file renders.
  - The response is `text/html; charset=utf-8`, with `X-FRUS-Rendering-Version`, a content security policy that runs no script, `nosniff` and `no-referrer`.
  - The errors are 404 `VOLUME_NOT_FOUND`, `TEI_NOT_AVAILABLE` and `DOCUMENT_NOT_FOUND`. Without `part=body` the answer is 501 `PAGE_NOT_AVAILABLE`, since the full page needs #1575's `ReaderPage`.
- **The search request.** `SearchRequest(formEncoded:)` turns a query string into the kit's `SearchParameters`, a limit and an offset, for S8c's `GET /search`:
  - form semantics, through `FormQuery`, refusing malformed escapes and bytes that are not UTF-8;
  - thirteen names for twelve fields, `keywords` passed on exactly as typed;
  - a list is its name repeated, and one empty value is the empty list, which keeps `yearKeys: []` (matches nothing) apart from no filter;
  - a date bound may be empty, so an open range has a form;
  - `limit` 1 to 100, and `offset + limit` within 7,500;
  - the draft's `facets`, `booleanMode`, `subjectTagIds` and `personRef` are refused until they arrive, and so is any unknown name.
- **The image.**
  - The runtime stage installs `libxml2`: the static binary links FoundationXML's libxml2 dynamically, and the first smoke run failed at start without it.
  - It copies the data files and sets `MALLOC_ARENA_MAX=2` (Notes).
  - The image is 399 MB on arm64, up from 251 MB:
    - the data files are 52 MB;
    - libxml2 and ICU are about 38 MB;
    - the stripped binary is 73 MB.
- **`scripts/compose-smoke`,** before the import, checks:
  - the catalogue's 553 volumes;
  - a document rendered from the mounted fixtures;
  - problem details for an unknown volume.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, the image size, memory, the TEI folder, and a new step 6 to read a document;
  - `SPEC.md`: the setting, and two conventions, problem details and query strings;
  - `PLAN.md` and its shared copy (rev 102): S8's three rows, Mac check 4, the decisions, the risk and memory rows;
  - `COORDINATION.md`: the server links the kit, and #1575's part;
  - `compose.yaml`, the prep note and three comments.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,663 tests pass, up from 1,631, with the one named skip, which CI's skip check allows. Checks 2 to 4 pass as at the pin move.
  - FRUSLightServerTests runs 38 tests, up from 9. FRUSParityTests runs 89, up from 86.
  - "check 4 through the API: 392 of 392 rows identical": every golden row, fetched from the reader's route with the fixtures in the TEI folder, is the golden file's bytes. The three volumes are parsed once each.
  - "check 3 through the API: all 482 queries decode into the Mac's SearchParameters, in both encodings". Every parity query is written as a strict client and as `URLSearchParams` would write it. Each decodes into exactly what `LinuxSearch.parameters` builds, which mirrors `tools/mac-golden`, and its text keeps the same UTF-8 bytes. Since `matchExpressions(for:)` depends on those parameters alone, the search S8c serves compiles every query as the golden file says.
- **The Compose smoke test** passes on the local arm64 image.
- **The reader on real volumes,** from a HistoryAtState clone mounted read-only into the image:
  - the first document of a 12 MB volume takes about 0.55 s, the parse;
  - another document of a parsed volume takes 6 ms.
- **PR #22's CI, on amd64,** for the record: check 2 passes; check 3's results show 482 identical, with 366 queries' scores in other bits than the Mac's, where arm64 had 359.

**The owner's export for S8b**

The owner built `101e17d7`, ran Erase Everything…, downloaded the three fixture volumes and exported with notes, summaries and tags off. Its stamp, read through SQLite's immutable mode:
- `exported_at` 2026-10-06T04:31:35Z, after the merge (04:15:56Z);
- build 49, index version 65 and FTS generation 4, with none of the owner's writing;
- exactly the three fixtures, 139, 123 and 130 documents, with every revision at index version 65;
- no log or journal beside it.

**Notes**

- **Memory.** Reading across the 16 largest manifest volumes, about 11–13 MB each:
  - With glibc's default arenas, the process grew from 7 MB to 221 MB in one pass, and to 303 MB in three.
  - With `MALLOC_ARENA_MAX=2` it reached 127 MB in one pass, and held near 142 MB and then 166 MB over eight.
  - That is the allocator keeping freed parses in per-thread arenas, not a leak: the cache keeps four volumes, and a test shows it parses an evicted volume again. The image sets two arenas.
- **A parse blocks one of Swift's cooperative threads** for about half a second on a large volume, since `XMLParser` runs synchronously inside the kit's parser actor. That is acceptable for one user. Before check 12's load target, parsing should leave the pool. `Blocking.run` cannot move it, since it takes a synchronous closure and the kit's parse entry points are all async methods of that actor. Two ways can:
  - run the parse under `withTaskExecutorPreference` with an executor the server owns, which a default actor follows (SE-0417);
  - or have upstream add a synchronous parse entry point.

  Either way the server should then limit parses in flight to one or two. Today the pool's width is the only limit, and the cache bounds only finished volumes.
- **The body's figure images** keep the reader's `frusexplorer://figure/` addresses, as the golden files do. S8c serves them by the server's own address, through #1575's `.linked` case.
- **A TEI file cut short** rendered its first document with no error on Linux, where the kit's parser does not report the early end. A file still being copied into the TEI folder is parsed again when its size changes, so this matters only for a file left cut short.
- **Not changed:** the index version and the app build, so `Compatibility.swift` and the export contract are unchanged.

**Next.**
- S8b: the pin move to `101e17d7`, with golden files from the owner's export above, the Crypto dependency FRUSCoreKitTests gains on Linux, and the read-only open tested on the fixture index.
- S8c: search, browse and the reader's full page over the read-only stack, with check 3 through the API on the real Import path.
- A web session adds the daily watch of the app's `v2`.

## Pin move: FRUSCoreKit, part 2, on Linux in CI

5 October 2026 · branch `claude/pin-f69b4a0` · upstream [joshbotts/FRUS-Explorer#1573](https://github.com/joshbotts/FRUS-Explorer/pull/1573) (merged as `2d216f4c`) and [joshbotts/FRUS-Explorer#1574](https://github.com/joshbotts/FRUS-Explorer/pull/1574) (merged as `f69b4a0a`)

Both of S6's upstream pull requests merged after the owner's Mac checks. This pull request moves the pin from `af8bedab` to `f69b4a0a`, `v2`'s head. That puts FRUSCoreKit's indexer, search and citation matcher into this repository's build. CI now runs checks 2 and 3 on the fixtures through the kit's public API alone, as the server will use it. The index version (65), the FTS generation (4) and the app's build (49) are unchanged, so the server, the image, `compose.yaml` and `docs/INSTALL.md` are too.

**How the session got there**

- **A map first.** Three readers mapped the build and CI, checks 2 and 3 as tests, and the records and the export. A fourth synthesized the plan.
- **A review after the draft opened.** Five reviewers looked at five things: correctness, CI and the build, the parity rules and the golden files, the records, and the Mac-side tools. A skeptic checked each finding. Four of the twelve held, all fixed before the export:
  - `COORDINATION.md` still called #1574 open;
  - `PLAN.md`'s Golden files checkpoint still said Done;
  - two prep notes still said the TEI hash comparison waits for S6;
  - the skip check anchored skips but not cancellations.

  Three refuted points were cheap enough to take anyway: a citation's line order, `frus-parity index` naming a volume twice, and `IndexCopy` leaving a partial file behind.
- **Two findings shaped the work:**
  - **CI's skip check.** It would have failed at the new pin on the passing test "A Lot File(s) prefix is skipped, never captured into the key".
  - **The export.** The owner's export must be made again after Erase Everything…. With the index version unchanged, a build of the new pin does not re-index the three volumes an earlier build indexed, so an export taken without erasing would still hold the old build's index.

**Delivered**

- **The pin and `Package.swift`.**
  - FRUSCoreKit depends on FTS5Store, with CSQLite on Linux and upstream's sqlite3 link on macOS.
  - FRUSCoreKitTests adds FTS5Store, SourceNoteKit and CSQLite.
  - FRUSParityTests adds FRUSCoreKit.
- **CI's skip check** now matches a skip or a cancellation by its verb right after the test's or suite's name, and still matches XCTest's `Test Case '…' skipped (` line. I ran the step itself with GNU grep in the container, with `LANG` unset and set to `C.UTF-8`:
  - it passes the full Linux log, with the named skip once;
  - it passes that log with passing tests whose names say "skipped" or "was cancelled";
  - it fails a log with nine planted skip and cancel lines, all nine reported.
- **The harness** (`Tests/FRUSParity`):
  - `ParityIndex` indexes TEI volumes with the kit's pipeline. It loads the data files with `IndexingResources.loading(fromDirectory:)` over the submodule's `FRUSExplorer/Resources`, keeps stamps in memory, and runs `runPostIndexPasses`.
  - `IndexCopy` copies a live index with the backup API, reading it through the normal pager, then takes the copy out of write-ahead-log mode for the summary.
  - `LinuxSearch` runs the query list's results and compiled expressions.
  - `ResultsLoop`, in ParityFormat, is the results loop. `tools/mac-golden` now runs the same code.
  - `ParseParity.recordMismatches` compares the compiled expressions in every scope.
  - `GoldenValidation.load` reads one golden file for a check.
- **The CI tests** (FRUSParityTests, 76 → 86 tests in 14 suites). The fixtures are indexed once per test process, from a copy of `fixtures/tei`.
  - **Check 2:** the summary of the kit's index against the golden summary. While that file is pending, the test still checks that:
    - every check is at its right value;
    - the person rollup is rebuilt;
    - each volume's documents match the render golden's (139, 123 and 130).
  - **Check 3's results:** all 482 queries against the golden results.
  - **Check 3's expressions:** every query, the 25 outside the default scope among them. Until now Linux compared only the default scope's expressions, by inference from the parse.
  - **The four data files:** present, and each decodes. Check 2 cannot show the broken-references index, since it flags nothing in the fixtures.
  - **The copied mapping** from query to search parameters, field by field.
  - **The results loop**, `measureDocuments` and `recordMismatches`.
- **`frus-parity index`** indexes the fixtures, or any folder of volumes, with the kit. With `--metrics` it prints the timings and peak memory; with `--out` it keeps a copy for `summarize`.
- **The golden files.**
  - `scripts/make-golden`, run without an export, rebuilt `tools/mac-golden` against the new pin. Only the provenance of the render manifest and the expressions changed: all 392 rows' HTML and all 482 queries' expressions are byte for byte as before.
  - The index summary and the results, from the owner's new export (below). Until it arrived they waited in `fixtures/golden/PENDING`, and the pull request stayed a draft.
- **`fixtures/sample`:** 24 volumes' names and SHA-256 sums at HistoryAtState/frus `8e5da08c`, for measuring. No TEI is committed.
- **Docs.**
  - `SPEC.md`: the table definitions' new place, and the measurements under Sizing.
  - `PLAN.md` and its shared copy (rev 90): Mac check 3 and the Golden files checkpoint done, the risk rows, the export note.
  - `COORDINATION.md`, the prep notes, the README, `CLAUDE.md` and `scripts/make-golden`'s export steps.
  - The comments that waited for session 6, and four line citations of `IndexingPipeline.swift`.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,631 tests pass, with the one named skip. FRUSCoreKitTests runs 878, up from 393, and FRUSParityTests 86, up from 76; the other targets are unchanged.
- **Checks 2 and 3,** against the new export's golden files: both pass (below). Before the export arrived, the comparisons also passed against the 4 October files (made from a build of `af8bedab`, restored for that run), and only their staleness checks failed.
- **Check 3's expressions:** "482 of 482 queries compile as the golden file says, 25 of them outside the default scope; 43 refused".
- **The refactored `tools/mac-golden`** runs the shared loop. Built against the new pin and run over the 4 October export, which its checks still accept at an unchanged build and index version, it writes all 482 records identical to the committed results, score bits included.
- **Indexing, a release build:**
  - **Setup:** Docker Desktop with 10 CPUs and 7.7 GiB.
  - **Fixtures:** three runs. The three volumes and the passes after indexing take 1.06, 1.07 and 1.10 s, at a peak of 128–130 MiB.
  - **Sample:** the 24 volumes (165 MB, 13,425 documents) index in 24.5 s, about 550 documents a second, at a peak of 136 MiB, into a 141 MB index. The passes after indexing take 0.6 s of that.
  - **Limited to 4 CPUs:** 24.6 s, peaking at 140 MiB, because volumes are indexed one at a time.
  - **Scaled by size:** the 3.34 GB corpus would take about 8 minutes and make about 2.9 GB, which is the Mac's full export's size.
  - **Caveats:** the first volume's time includes decoding the data files; the peak is the whole process's; the rollup's cost at full size is not known.

**The owner's export**

The owner built `f69b4a0a`, ran Erase Everything…, downloaded only the three fixture volumes, waited for indexing and the person rollup, and exported with notes, summaries and tags off. Its stamp, read through SQLite's immutable mode:
- `exported_at` is 2026-10-06T01:34:52Z, after the pin's commit (2026-10-05T10:46:10Z);
- build 49, index version 65 and FTS generation 4, with none of the owner's writing;
- exactly the three fixtures, 139, 123 and 130 documents;
- no log or journal beside it.

`scripts/make-golden --export` wrote both files and emptied `PENDING`, and `check-golden` passes. Against the 4 October export's files, the new export changes nothing that is compared:
- all 36 gating digests and 7 checks are the same;
- all 482 result records are the same, score bits included;
- only the provenance, the export date and the history-dependent information fields differ.

The full Linux suite then printed:
- "check 2 passes: 36 digests and 7 checks are the Mac's";
- "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups; 359 with other score bits (information)";
- "check 3's expressions: 482 of 482 queries compile as the golden file says, 25 of them outside the default scope; 43 refused";
- "check 4, the reader's path: 392 of 392 rows identical", and so along the full-parse path.

Checks 2 to 4 pass on the three fixture volumes, with indexing speed and memory recorded: phase 0's exit.

**Notes**

- **The tools cannot tell an `af8bedab` export from an `f69b4a0a` one,** because the build and index version are the same. Only the procedure, and `exported_at`, distinguish them.
- **The query mapping stays copied** between `tools/mac-golden` (the app's `SearchParameters`) and `LinuxSearch` (the kit's). A Linux test pins the Linux side, field by field.
- **Not changed:**
  - the Settings row in `PLAN.md` and its open question about the container runtime, which are the owner's to close;
  - `docs/INSTALL.md`, since the image compiles no kit.

**Next.**
- S8: search, browse and document-render endpoints over the imported index. It needs its own upstream pull request first, for a read-only pipeline open, the figure URLs and the page shell.
- A web session adds the daily watch of the app's `v2`.

## Session 6b: FRUSCoreKit, part 2, upstream pull request B

5 October 2026 · branch `claude/s6b-citation-lookup` · upstream [joshbotts/FRUS-Explorer#1574](https://github.com/joshbotts/FRUS-Explorer/pull/1574)

The owner's Mac check 3 passed for #1573, and it merged on `v2` as `2d216f4c`. S6's second upstream pull request branches from that merge. It moves Citation Lookup's matcher into `FRUSCoreKit/`, with its block splitter, its page-range store and what their suites use, so check 7's matcher half can run on Linux. As with S6a, this entry records the results at the pull request's head. The pin stays at `af8bedab` until the pin move that follows this merge. This repository's pull request is records only, and passes CI at that pin.

**Decided in the session**

The owner's 4 October answers covered this pull request's shape. Two smaller decisions were the session's:
- **Check 7's matcher count is 70, not 74.** `PLAN.md` took 74 from the whole file `CitationMatchingEngineTests.swift`. Four of its tests can run only in the app. One builds the app's `AppState`, one dispatches through the WebKit link handler, and two read the app's views' source. They stay Xcode's, guarded with their reasons. Rewriting the handler test for Linux would copy the handler's code, which rule 4 forbids. `PLAN.md` now says 70 of 74.
- **Only the seam is new public API.** The engine and `PageRangeStore` were already public. Batch and Structured Entry's types (the splitter, the batch outcome and row, the form's fields) stay internal until the web edition's citation lookup needs them, in phase 2, under the owner's rule that only what S6's checks need becomes public.

**How the session got there**

- **A map first.** Three readers mapped the source closure, the tests, and the scans and records at `2d216f4c`, and a fourth synthesized the plan. The one app name the moved code used was `ManifestStore`, read for one property, `citableEntries`. None of the files had changed since `af8bedab`, so the S6 map's line numbers held.
- **A review before the pull request opened.** Five reviewers looked at five things: behaviour preservation, the tests, the records, the source scans and audits, and this repository's side. A skeptic checked each finding. Three of the reviewers found nothing. One finding held: a commit message said the page-range store bound page numbers as text, when it binds only volume ids. The message was corrected before the first push. The four findings about this repository were real, but none is a defect of the upstream pull request. They are this pull request's records and the pin move's work, both below.

**The upstream pull request**

Branch `claude/fruscorekit-part2b`: eight commits in review order. Its description lists them and holds the Mac check 3 commands, the expected results and the symbol-diff script. This time the script is written to `/tmp/symdiff.py` by the command block itself, and `v2` is built from a worktree beside the checkout, so the checkout never leaves the branch. Both changes answer what went wrong in #1573's check.

- **Moves.**
  - Four files by `git mv`:
    - `CitationMatchingEngine`, with `ConfidenceLabels`;
    - `CitationBlockSplitter`, with the batch outcome, row and runner;
    - `PageRangeStore`;
    - `CountCopy`, with `StatusBarCopy`.
  - `CitationLookupFields` and `CollectionCitationLineResolver` moved verbatim out of their SwiftUI files.
  - The kit goes from 29,223 lines in 40 files to 31,887 in 47.
- **The seam** (`FRUSCoreKit/Citation/CitableVolumeCatalogue.swift`):
  - `CitableVolumeCatalogue` has one requirement, `var citableEntries: [VolumeManifestEntry] { get async }`, and the engine holds `any CitableVolumeCatalogue`.
  - The app conforms `ManifestStore` with an empty extension. Its main-actor getter witnesses the requirement, so each read still hops to the main actor.
  - `FixedVolumeCatalogue(contentsOf:)` decodes a `manifest.json`. The server will pass one made from the submodule's `FRUSExplorer/Resources/manifest.json`.
  - The initialisers keep the label `manifestStore:`, so no caller changed.
- **Linux.** `PageRangeStore` imports SQLite3 behind `canImport`, else `CSQLite`. It binds text with `SQLITE_TRANSIENT` where it bound a temporary `NSString`'s buffer as static, which only Apple's autorelease pool kept alive.
- **Tests.** Three suites dual-compiled, and `CitationTestSupport.swift`. It reads the bundled manifest from the repository in the package, and builds a `FixedVolumeCatalogue` where Xcode builds a `ManifestStore`.
  - Three guards are lifted: `CitationLookupFieldsTests`, the manifest-backed punctuation test, and `matchSurvivesNoisyVolume`.
  - A new suite, `CitableVolumeCatalogueTests`.
  - `FRUSCoreKitTests` goes from 765 tests in 108 suites to 878 in 116.
- **Audits and docs.**
  - The boundary audit is unchanged.
  - Four path reads, and one count-scan baseline key.
  - The app's `CLAUDE.md`.
  - 16 editable-content paths and 12 ranges.
  - Version histories.
  - The session entry.

**Results at the pull request's head**

- **Check 7's matcher half on Linux.** Check 7's three parts, in the same setup as S6a (a scratch checkout of this repository, the branch copied into its submodule folder, `Package.swift` patched as the pin move will patch it):
  - CitationMatchingEngineTests' 70: 27 in its first suite and 43 in `CitationLookupIndexedTests`;
  - CitationBlockSplitterTests' 18;
  - the punctuation test, which reads the bundled manifest.

  All pass, inside "✔ Test run with 878 tests in 116 suites passed", none skipped, in 24 s. With S3's formatter and parser half, 81 tests, check 7 runs 170 tests on Linux.
- **The matcher on both platforms.** In Debug, the engine's suites print 3,732 log lines: each lookup's strategy and verdict, and the round trip of the app's own citation of all 553 bundled volumes in three formats, marked and plain. In each of the six forms, 551 of 553 resolve first to their own volume. The lines are identical on macOS and on Linux.
- **The whole Linux suite** passes, except the three tests that check the golden files' provenance. Those fail only on the source digest, as they must until the pin move remakes the golden files, and their row comparisons pass.
- **Checks 2 and 3, unchanged.** The S6a probe, rerun at this head:
  - check 2: "check 2 passes: 36 digests and 7 checks";
  - check 3: "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups".

  Xcode was building at the same time, so this run's timings are not measurements.
- **Check 4 at the head.** `tools/mac-golden`, built against the branch, wrote all 392 rows' HTML and all 482 queries' expressions byte-identical to the committed golden files. Only their provenance changed.
- **macOS and iOS**, which the upstream description gives in full:
  - **Builds and symbols.**
    - Clean unsigned builds of `FRUSExplorerMac` succeed beside `v2`'s, with the same five warning lines.
    - The normalized symbol diff is 29 removed and 59 added, each name explained.
  - **The full unit run:** "✘ Test run with 6498 tests in 765 suites failed after 479.912 seconds with 8 issues."
    - The 8 are the Keychain tests that an unsigned build fails.
    - The 4 extra tests are the new suite's.
    - The run skips the same 17 tests and 2 suites as `v2`.
  - **`swift test`, whole:** 38 runs and 2,541 tests, all passed.
  - **The audit, mutated:** four of its twelve tests failed on four planted violations, each naming its line.

**Delivered here**

- **`PLAN.md`** and its shared copy (rev 78):
  - the S6 row's check 7 count, 70 of 74;
  - Mac check 3: A done, B awaiting the owner.
- **`docs/COORDINATION.md`** section 2: A merged; B open, with the catalogue seam and how the server will pass the manifest. Section 3: the imports the audit allows since #1573.
- **`docs/prep/README.md`:** what B settled.

**Results here**

No code changed. CI runs the suite at `af8bedab` as before, 1,136 tests.

**The pin-move pull request, after #1574 merges**

As S6a listed, and also:
- **Check 7 in CI.** `FRUSCoreKitTests` at the new pin includes check 7's matcher half, 89 tests, with no change to this repository beyond the pin and `Package.swift`.
- **CI's skip check** (`.github/workflows/ci.yml`, the Test step) matches any log line with `Test`, then `skipped` after a space. At the new pin, one passing test's name contains the word: "A Lot File(s) prefix is skipped, never captured into the key". The pattern needs to require the verb right after the test's name, keeping XCTest's `Test Case '…' skipped` form. The scratch checkout's full Linux log has no other such name.
- **`docs/SPEC.md` and `PLAN.md`** name no moved citation file by path, so nothing else moves.

**Next.**
- The owner: Mac check 3 on #1574, with the commands in its description, and then the merge.
- Then the pin move after both, with a new three-volume export from the newly pinned build.
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Session 6a: FRUSCoreKit, part 2, upstream pull request A

4–5 October 2026 · branch `claude/s6-fruscorekit-part2` · upstream [joshbotts/FRUS-Explorer#1573](https://github.com/joshbotts/FRUS-Explorer/pull/1573)

S6's first upstream pull request moves the app's indexing pipeline and search service into `FRUSCoreKit/`, so that this repository can index and search on Linux with the app's own code. It branches from `v2` at `af8bedab`, which is still the pin; nothing has merged on `v2` since. As with S3, this entry records the results at the pull request's head. The indexer and search reach this repository's CI in the pin move that follows both of S6's pull requests. This pull request makes the parity tools ready for that, and passes CI at `af8bedab`.

**The owner's decisions, 4 October**

- **Two upstream pull requests and one pin move.** A moves the indexer and search, which brings checks 2 and 3 to Linux. B, branched from `v2` after A merges, moves the citation matcher, the block splitter and `PageRangeStore`, which brings check 7's matcher half. One pin move follows both, so the owner makes one new three-volume export.
- **All of `IndexingPipeline.swift`, and the core suites.** A moves the whole file and the Foundation-only types it uses, and about 370 of the indexer's and search's tests compile twice, under Xcode and against the kit alone.
- **No `UserDefaults` or `Bundle.main` in the kit.** The stamps go through a stamp-store interface that `UserDefaults` already satisfies. The data files go through providers the app passes, so nothing loads earlier than before. The boundary audit lets the kit import logging, SQLite (`CSQLite` on Linux) and FTS5Store, each behind the `canImport` that selects it.
- **Mac check 3 takes Mac check 2's form,** once for each pull request.
- **Left to the session, as recommended:**
  - one kit call runs the passes after indexing, and the app's launch calls it too;
  - the iOS memory-warning observer stays where it is, matched by the notification's name;
  - only what S6's checks need becomes public;
  - indexing is measured on the fixtures and on a sample of 20 to 30 volumes;
  - check 3 keeps to exact ties.

**How the session got there**

- **A map first.** Six readers mapped the code's dependencies at `af8bedab`: the indexer, search, the citation matcher, the stores, the tests and this repository's side. A seventh synthesized the plan and the decisions above. `docs/prep/s6-linux-edits.tsv`, from the dry run at `34a5120`, was a list of guards. The map showed that moves avoid most of them:
  - the pipeline needs kit internals, so it lives in `FRUSCoreKit` itself;
  - six data files are read, not eight;
  - the Keychain and NARA shims are unneeded.
- **Two audits before the pull request opened.**
  - **The tree walks.** A scan of the test target's 50 walks of `FRUSExplorer/` judged whether each could stop reading code that moved, and each change it proposed was checked again independently: nine path reads, four walks widened to `FRUSCoreKit/`, and one repository path in a moved suite.
  - **The whole change.** Five reviewers looked at behaviour preservation, the seams, the tests, the records and this repository's tools, and each finding was checked by a skeptic. 20 of the 28 findings held, some found twice, and all were fixed before the pull request opened. Among them:
    - `runPostIndexPasses` held the pipeline's actor across all three passes where the launch had released it between them; it is `nonisolated` now;
    - one sanity set no longer proved that the walk reads the test target's free functions;
    - several guard reasons, counts, commit-message details and doc sentences were wrong.
  - **And one the session found itself.** The pipeline's comment said a test pinned the memory-warning notification's name, and none did. `IndexingSeamsTests` now does, and also checks that `IndexingResources.bundled` serves the app's stores and tests the seams under both compilers.

**The upstream pull request**

Branch `claude/fruscorekit-part2`: ten commits in review order. Its description lists them and holds the Mac check 3 commands, the expected results and the symbol-diff script.

- **Moves.** Fourteen files by `git mv`:
  - `IndexingPipeline`, `SearchService`, `KWICLine`, `PersonClusterer`, `ResultSetFacets`, `DecimalFileSegment` and `IndexingStateTracker`;
  - `ChronologyModels`, `DocumentKey`, `PersonMentionStore`, `PersonAuthorityIndex` and `VolumeSubjectProfiles`;
  - two renamed: `DocumentSubjectIndex` and `DecimalClassLabelTable`.

  Fourteen Foundation-only value types moved verbatim into six new kit files, `SearchParameters.swift` among them. The kit goes from 10,183 lines in 18 files to 29,219 in 40.
- **The seams** (`FRUSCoreKit/Search/IndexingSeams.swift`):
  - `IndexingResources`, with `.none` and `loading(fromDirectory:)`, which refuses a folder lacking one of the four files that change an index;
  - `IndexingStampStore`, whose requirements are `UserDefaults`' own methods, and `InMemoryIndexingStampStore`;
  - `IndexedDocumentDonor` and `DonatedDocument`;
  - `runPostIndexPasses(overrides:afterRollupRebuild:)`.
- **The app's half** (`IndexingPipeline+App.swift`): the old initialiser, passing `.bundled`, `UserDefaults` and the Spotlight donor; the Spotlight section; `updateSummary(_:)`. The app's three launch branches call `runPostIndexPasses`.
- **Linux.** Guarded imports, and the kit's own copy of FTS5Store's logging stand-in. The kit depends on FTS5Store.
- **Tests.** Thirteen suites dual-compiled, and `IndexingTestSupport.swift`, which gives the package's pipelines the app's data files and one shared stamp store. `FRUSCoreKitTests` goes from 393 tests to 765.
- **Audits and docs.**
  - `FRUSCoreKitBoundaryTests` 1.2.
  - Nine path reads, and four tree walks widened to `FRUSCoreKit/`.
  - The app's `CLAUDE.md`.
  - 35 editable-content ranges, the API spec and version histories.
  - The session entry.

**Results at the pull request's head**

- **Linux, `swift:6.4-noble`, arm64.** The setup: a scratch checkout of this repository, with the branch copied into its submodule folder and `Package.swift` patched as the pin move will patch it (FTS5Store and `CSQLite` for the kit and its tests).
  - `FRUSCoreKit` builds with no warning.
  - "✔ Test run with 765 tests in 108 suites passed", none skipped. The other kit targets pass.
  - This repository's own harness fails only where it must until the pin move. The golden files' provenance names `af8bedab`'s sources. `CompatibilityTests` on `main` reads `IndexingPipeline.swift` at its old path, which this pull request's path tolerance fixes.
- **Checks 2 and 3 on Linux.** A throwaway probe in the scratch checkout, not committed, used the kit's public API alone, as the server will:
  1. `FTS5Store` and `IndexingPipeline(resources: .loading(fromDirectory:), defaults: InMemoryIndexingStampStore())`, with the submodule's `FRUSExplorer/Resources`;
  2. `indexVolume` for the three fixtures;
  3. `runPostIndexPasses()`;
  4. a page-for-page copy in rollback-journal mode through SQLite's backup API, then `IndexSummarizer`;
  5. `SearchService`, with `tools/mac-golden`'s results loop.

  The results:
  - **Check 2:** "check 2 passes: 36 digests and 7 checks", against the golden summary of the owner's three-volume export. So a raw Linux index, copied without the app's exporter, equals the Mac's export.
  - **Check 3:** `frus-parity compare-results` printed "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups".
    - 359 passing queries have other score bits than the Mac's: 1,349 scores in all, each 1 to 3 ulp away (1,165 one, 182 two, 2 three), the largest relative difference 4.3 × 10⁻¹⁶.
    - The smallest gap between two distinct adjacent Mac scores is 4.6 × 10⁻⁸. So rounding cannot reorder results, and exact ties stay the right rule.
  - **Speed and memory,** release, an idle Mac with 10 CPUs:
    - the three volumes index in 0.53, 0.28 and 0.30 s;
    - the passes after indexing take 0.05 s, so 1.18 s in all;
    - the 482 queries take 10.7 s, counting the paging of tie tails;
    - the peak resident memory is 130 MiB (VmHWM 133,228 KiB).
- **Check 4 at the head.** `tools/mac-golden`, built against the branch in the scratch checkout, wrote the HTML of all 392 rows and the expressions of all 482 queries byte-identical to the committed golden files. Only their provenance changed. The Linux renders against those files: "check 4, the reader's path: 392 of 392 rows identical", and so along the full-parse path.
- **macOS and iOS**, which the upstream description gives in full:
  - Clean unsigned builds of `FRUSExplorerMac` succeed beside `v2`'s, with the same five warning lines.
  - The normalized symbol diff is 97 removed and 389 added, each name explained.
  - A clean iOS `build-for-testing` takes 144 s, with the 7 known warning lines.
  - **The full unit run:** "✘ Test run with 6494 tests in 764 suites failed after 373.887 seconds with 8 issues." `v2`: "✘ Test run with 6486 tests in 763 suites failed after 389.226 seconds with 9 issues."
    - Both fail the 8 Keychain tests an unsigned build fails; `v2` also had the late-image flake.
    - Both skip the same 17 tests and 2 suites.
    - The 8 extra tests are the new seams suite's.
  - **`swift test`, whole:** 38 runs and 2,428 tests, all passed.
  - **The audit, mutated:** five of its twelve tests failed on seven planted violations, each naming its lines.

**Delivered here**

- **Check 3's results comparison.**
  - `Tests/FRUSParity/SearchParity.swift` compares a candidate results file with `fixtures/golden/queries.results.json`. It uses ParityFormat's tie-aware `ResultComparison` for each query and reports four things:
    - each permutation inside a Mac tie group;
    - each difference: a count, a missing or extra document, an order outside a tie, an error string, or a missing, extra or repeated record;
    - which passing queries have other score bits, as information.
  - `frus-parity compare-results <golden> <candidate>` prints "check 3's results pass" or "fail": the compiled expressions are the rest of check 3, and ParseParity's.
- **`Tests/FRUSParity/IndexingMetrics.swift`:** step timing with `ContinuousClock`, documents per second, and the process's peak resident memory (VmHWM on Linux, `ru_maxrss` on macOS), for the pin move's indexing measurements.
- **Path tolerance for the move.** `CompatibilityTests` and `scripts/mac-check` read the index version from whichever of `FRUSExplorer/Search/` and `FRUSCoreKit/Search/` holds `IndexingPipeline.swift`, and fail if both or neither do.
- **Tests:** 14 new in FRUSParityTests (11 for the comparison, among them the committed results file against itself, and 3 for the metrics), so 76.
- **The docs.**
  - `PLAN.md` and its shared copy (rev 75): the S6 row (two pull requests, one pin move), Mac check 3, the owner's decisions, and two risk rows.
  - `docs/COORDINATION.md` section 2: part 2's two pull requests, A's seams, and the guarded imports the audit will allow.
  - `docs/prep/README.md`: what A settled, and what remains of `s6-linux-edits.tsv` and `shims/`.

**Results here**

- **Linux, `swift:6.4-noble`, arm64.** All 1,136 tests pass, with the one named skip:

  | Target | Tests |
  | --- | --- |
  | FRUSCoreKitTests | 393 |
  | SourceNoteKitTests | 292 |
  | FTS5StoreTests | 209 |
  | FRUSParityTests | 76 |
  | ManifestGeneratorTests | 60 |
  | FRUSLightCoreTests | 42 |
  | SemanticVectorsKitTests | 35 |
  | CrossRefKitTests | 10 |
  | FRUSLightServerTests | 9 |
  | GeneratorKitTests | 7 |
  | FTS5CheckTests | 3 |

- `frus-parity compare-results` passes the committed results file against itself, and the probe's Linux results from the head as above.

**The pin-move pull request, after both merges**

- **`Package.swift`.** `FRUSCoreKit` gains FTS5Store and `CSQLite` on Linux; `FRUSCoreKitTests` gains FTS5Store, SourceNoteKit and `CSQLite`, as the scratch package had them.
- **The indexer and search in CI,** with the probe's steps as tests. They index the fixtures once per process with `IndexingResources.loading(fromDirectory:)` over the submodule's resources and an in-memory stamp store, then run the passes:
  - check 2: copy the index with the backup API into rollback-journal mode, summarize it and compare;
  - check 3: run the 482 queries with `tools/mac-golden`'s loop and compare with SearchParity;
  - a test that the four index files are present and decode;
  - `frus-parity index --metrics`.

  Check 3's expressions for the queries outside the default scope still need a Linux comparison.
- **Golden files.** All four, remade by `scripts/make-golden --export` from a new three-volume export by the newly pinned build. The source digest changes with the move.
- **Paths.** `docs/SPEC.md` and the comments citing `IndexingPipeline.swift` by line move with it.

**Notes**

- **For S8.** The pipeline's initialiser opens its database read-write, runs its schema setup and sets WAL mode, which does not suit an immutable export. S8's own upstream pull request needs a read-only open, with the figure URLs and the page shell it already needs.
- **On Linux,** `IndexingResources.loading(fromDirectory:)` answers nothing for the collection authority's alias fallback, which only related-documents queries use. It changes no index.
- **The probe and the scratch checkout** are not committed. The pin move's tests replace the probe.
- **The owner's next steps:** Mac check 3 on #1573, from a clone at a real path, with the commands in its description, and then the merge.

**Next.**
- S6b: the second upstream pull request, the citation matcher, the block splitter and `PageRangeStore`, with check 7's matcher half, branched from `v2` after #1573 merges.
- Then the pin move after both, with a new three-volume export from the owner.
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Golden files from the owner's three-volume export

4 October 2026 · branch `claude/golden-export`

The owner built FRUS Explorer from `af8bedab`, the pin, as build 49. Their Apple ID held no FRUS Explorer data, so instead of setting up a second macOS user they emptied the app's own 553-volume library with Settings ▸ Data & Recovery ▸ Erase Everything…. They then downloaded the three fixture volumes, let indexing and the person rollup finish, and exported the research database with Include My Notes, Summaries, and Tags turned off, to `/Users/Shared/frus-golden.sqlite`. This pull request commits the two golden files made from that export, which completes the Golden files checkpoint. The server, the image and `compose.yaml` are unchanged.

**Delivered**

- **`fixtures/golden/index-summary.json`,** check 2's golden summary, 32,682 bytes: 36 gating digests and 7 checks over exactly the three fixture volumes.
  - Among its tables: 392 `document_cache` rows, 121 persons, 1,018 person mentions, 1,130 page ranges, 208 cross-references, 98 terms, 1,242 document subjects and 9 external citations.
  - Every check has its right value: `integrity` ok, no `docsize` orphans in either full-text table, no revision history, `user_version` 4.
- **`fixtures/golden/queries.results.json`,** check 3's counts and first 50 results, 844,004 bytes, one record for each of the 482 queries:
  - 439 have a count, and 178 exceed 50. 27 are zero, each by design. For 22 of them, the query's note in `fixtures/parity/queries.jsonl` says so. The other five are R55's queries, which search with document text off over an index that holds no notes or summaries, as `fixtures/parity/README.md` says.
  - 12 have one result after the 50th that ties with it, kept in the record's tie tail.
  - 43 are refused as `emptyQuery`: the same 43 the expressions file refuses.
- **`fixtures/golden/PENDING`** lists nothing, so `GoldenTests` validates all four golden files and none waits.
- **The other two golden files** were made again at `af8bedab` in the same run, byte-identical to the committed ones.
- **`scripts/make-golden`'s header** names the route the owner took, and says why Reset This Device does not do (see the notes).
- **The docs.**
  - In `PLAN.md` and its shared copy (rev 74), the Golden files checkpoint is Done. The Mac item for a pin move now asks for a new three-volume export and `scripts/make-golden --export`.
  - `docs/COORDINATION.md` says the export-based golden files exist, and that a pin move remakes them from a new export, in sections 1, 2, 5 and 6.
  - `docs/prep/README.md`'s pinning note says each pin move remakes them from a new export.

**Results**

- **The export.** Index version 65, FTS schema 4, `user_version` 4, app build 49, `my_writing_included` 0. It holds the three fixture volumes alone: 392 `document_cache` rows, and 392 `document_revisions` rows, all at index version 65. The app's three downloads match `fixtures/tei/SHA256SUMS`, and HistoryAtState's `master` is still `8e5da08`.
- **`scripts/make-golden --export`** on the owner's Mac, macOS 27.0.1 with Xcode 27.0: every step ok. "results: 482 queries, 43 refused, 12 with ties past the 50th", and `frus-parity check-golden` passes.
- **A cross-check against a new index.** Emptying a library that had held 553 volumes might leave something behind. To test that, a throwaway `mac-golden` command, not committed, built a new `frus.db` from the three fixtures with the app's own code:
  1. `FTS5Store` and `IndexingPipeline`, constructed as `mac-golden results` constructs them, with the app's 36 JSON resources beside the tool;
  2. `indexVolume` for each fixture;
  3. `consolidatePersonRollupIfNeeded` with no overrides, then `applyBrokenRefsIndexIfNeeded` and `applyDocumentSubjectsIfNeeded`, the passes the app runs after indexing;
  4. `IndexDatabaseExporter.export`, with the writing left out, as Export Research Database… does, but with a stamp the command built itself.

  `frus-parity compare-summary` of the golden summary against it: "check 2 passes: 36 digests and 7 checks are identical". `mac-golden results` over it gave all 482 records identical to the golden file. So the golden files describe the index a new library makes. The two summaries differ only in information they do not compare. Besides the export time and the timings, the differences are:
  - `sqlite_sequence`. The emptied library's counters continue from the 553-volume library's: `page_ranges` is at 766,807 against 1,130. The summary leaves those surrogate ids out of every hash. They also account for the file sizes and page counts: 5,111,808 bytes in 1,248 pages, against 5,099,520 in 1,245.
  - `volume_structures.json`. Each process encodes the structure JSON with its keys in another order; the two are equal as JSON.
  - The stamp's `semantic_provenance_digest`. The app stamps its bundled vectors' digest, `a726ca60…`. The throwaway command loaded no vectors, so its stamp has none.
- **The same index without the resources.** With no JSON resources beside the tool, check 2 fails with 15 gating differences, in five tables. `document_subjects`, `document_subject_refs` and `document_subject_volumes` are empty, `external_citations` has 4 rows instead of 9, and the `person_rollup` content differs. So the check catches an index made without them.
- **Linux, `swift:6.4-noble`, arm64.** All 1,122 tests pass, with the one named skip, in 1 minute 50 seconds with an incremental build. `committedGoldenFilesAreCurrentAndWhole` finds nothing pending, and `frus-parity check-golden` prints "golden files: 4 present and valid, 0 pending".
- **macOS, natively.** FRUSParityTests' 62 tests pass, both renders giving 392 of 392.

**Notes**

- **Erase Everything, not Reset This Device.** Both delete the volumes, their figures and the search index. Reset This Device keeps `document_revisions`, the per-document change log, since it promises that annotations come back; only Erase Everything clears it. After Reset This Device, an export would still name every volume the library held in that table, and `frus-parity summarize` refuses an export whose tables name volumes `document_cache` does not hold. Erase Everything also deletes every note, collection and project, on the device and in iCloud, so it suits only an account with nothing to keep, as the owner's was.
- **The owner's library now holds the three fixtures alone.** `~/Documents/frus-index.sqlite`, the 553-volume export of 3 October from build 49, is unchanged. It stays the input for local Import trials while the pin holds. The S10 export needs a full library again, from the build pinned at S10.
- **For S6.** The cross-check shows the app's own code making, from scratch, the index the golden summary describes. It needs the indexing calls and the three passes above, and the bundle's JSON resources. A Linux index made the same way should pass check 2; one made without the resources fails it in those five tables. S6's upstream pull request only moves code, so in the session its Linux index can be compared with these files by `frus-parity compare-summary`, which compares no provenance. Its pin move changes the source digest, so that pull request remakes all four golden files, the two from an export with a new three-volume export from the newly pinned build.
- **The platform recorded** in both files: macOS 27.0.1, SQLite 3.54.0, `en_US`, America/New_York. Check 2 compares no platform field.

**Next.**
- S6: FRUSCoreKit part 2, an upstream pull request that moves the indexer, search, the citation matcher and splitter, and `PageRangeStore` into the kit. Its pin move remakes the golden files from a new three-volume export, as the note above says, and runs checks 2 and 3 on Linux against them, with check 7's matcher and splitter half.
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Pin move: FRUSCoreKit on Linux in CI

4 October 2026 · branch `claude/pin-2a4df13` · upstream [joshbotts/FRUS-Explorer#1569](https://github.com/joshbotts/FRUS-Explorer/pull/1569), merged as `f102fa4d`, [#1571](https://github.com/joshbotts/FRUS-Explorer/pull/1571), merged as `2a4df13c`, and [#1572](https://github.com/joshbotts/FRUS-Explorer/pull/1572), merged as `af8bedab`

The owner ran Mac check 2 and squash-merged #1569 as `f102fa4d`, then #1571, which narrows the boundary test, as `2a4df13c`, and #1572, the app's `CLAUDE.md` section for the web edition, as `af8bedab`. They are the only commits on `v2` after `cfc0d3c`. This is the pull request Session 3's entry describes: it moves the pin, compiles FRUSCoreKit and its suites, and runs check 4 on Linux in CI. The index version stays 65, the FTS schema 4 and the app build 49, so `Compatibility.swift`, `docs/INSTALL.md` and the export's schema fixture are unchanged.

**Delivered**

- **The pin** moves from `cfc0d3c` to `af8bedab` (rule 5). #1572, the last of the three, changes only `CLAUDE.md` and the app's session log, which no golden file digests. The submodule has no local changes.
- **`Package.swift`,** with the targets of the working manifest in #1569's description:
  - `FRUSCoreKit`, from the submodule's `FRUSCoreKit/`. It depends on SourceNoteKit, as upstream's manifest declares, and on swift-crypto's `Crypto` for Linux only, which its `CryptoKit` guard falls back to.
  - `FRUSCoreKitTests`, the kit's eleven suites from `FRUSExplorerTests/FRUSCoreKit/`, depending on the kit alone: under SwiftPM each suite imports FRUSCoreKit and nothing else.
  - FRUSParity depends on the kit, for check 4. FRUSLightCore and the server depend on neither target, and `Package.resolved` is unchanged.
- **Check 4 on Linux.** `Tests/FRUSParity/RenderParity.swift` renders the fixtures through the kit's public API alone. It imports the kit without `@testable`, as the server will. `RenderParityTests`, in FRUSParityTests, has four tests:
  - **The reader's path,** for each of the 392 rows of `fixtures/golden/render/manifest.json`:
    1. a new parser's `parseDocument`;
    2. `ReaderLookups` from the volume's `parsePersons` and `parseTerms`;
    3. `ASTToRenderNodeConverter(readerOf:lookups:brokenRefs:)`, with the submodule's `FRUSExplorer/Resources/broken-refs-index.json` decoded as `BrokenRefsIndex`;
    4. `FRUSRenderNodeHTMLSerializer.reader`.

    Each row's UTF-8 bytes must be the committed file's, and their size and SHA-256 the manifest row's. A difference reports both, and `RenderDiff.firstDifference`.
  - **One full parse per volume,** the path S8 will serve, without a parse per document. `parseVolumeFull` must yield exactly the golden rows, in their order. Rendering from its ASTs, with its own persons and terms, must give the same bytes. Its persons and terms must also equal `parsePersons` and `parseTerms`, field for field, since the bytes cannot show them (see the notes).
  - **An `<abbr>` naming a glossary term,** in a volume the test writes. Along both paths it renders as the term's link whatever its case, and an `<abbr>` that names no term stays text.
  - **The comparison itself,** on golden files the test writes. Identical HTML passes. Canonically equivalent text, a missing document, an unlisted row and a manifest that disagrees with its file are each reported.

  Both renders first require the golden manifest to be current at the pin, by `GoldenValidation`'s staleness check. One made from other app sources would test other code, so it fails as stale instead.
  - The persons and terms are parsed once per volume. The reader parses them for each document it opens, but `FRUSDocumentParser` keeps no state between calls: each reads the file with a new `XMLParser`.
  - Rows render concurrently, as many at once as the machine has processors.
- **`frus-parity render`** runs check 4 on any machine, both passes, and prints their timings. It also compares the full parse's persons and terms with the reader's. Given a volume and a document, it renders that one, along the reader's path or with `--full-parse`, and `--out` saves its HTML. The HTML never goes to standard output, where a debug build of the kit prints its parser's log.
- **Check 7's formatter and parser half** runs in CI, inside FRUSCoreKitTests: 81 tests in all.
  - The eight suites `CitationFormatterTests.swift` compiles under `swift test`: 32 tests.
  - CitationParserTests: 26.
  - The three suites in `PageSpanResolverTests.swift`: 23.
- **Golden files.** `scripts/make-golden` ran on the owner's Mac at `2a4df13`, and again at `af8bedab`, where only the recorded commit changed, in 89 seconds.
  - `tools/mac-golden` compiled 529 app files and the stub, all 18 of FRUSCoreKit's among them.
  - The HTML of all 392 rows (3,554,115 bytes) and the expressions of all 482 queries are byte-identical to `cfc0d3c`'s.
  - Only the provenance changed, in four lines: `upstreamCommit` and `sourceDigest`, in `render/manifest.json` and `queries.expressions.json`. `check-golden` passes.
  - The new digest, `39d9aed1…`, is the one S3 rehearsed at #1569's head. A Python recomputation gives the same over 612 files. Without `FRUSCoreKit`, the other 594 files give `b425aaa1…`.
- **CI needs no change.** The kit's suites skip nothing on Linux, none calls `Test.cancel`, and no line of their log matches the skip guard's pattern.

**Results**

- **Linux, `swift:6.4-noble`, arm64.** A clean build with tests: "Build complete! (59.52 secs)", 86 seconds with the dependencies' checkout, and no warnings. Of the 1,122 tests, 1,121 pass, and the one skip is the named one:

  | Target | Tests |
  | --- | --- |
  | FRUSCoreKitTests | 393 |
  | SourceNoteKitTests | 292 |
  | FTS5StoreTests | 209 |
  | ManifestGeneratorTests | 60 |
  | SemanticVectorsKitTests | 35 |
  | CrossRefKitTests | 10 |
  | GeneratorKitTests | 7 |
  | FRUSParityTests | 62 |
  | FRUSLightCoreTests | 42 |
  | FRUSLightServerTests | 9 |
  | FTS5CheckTests | 3 |

  - The seven kits hold 1,006 of them: S1's 613, and FRUSCoreKitTests' "✔ Test run with 393 tests in 49 suites passed after 0.100 seconds.", the count #1569 states.
  - FRUSParityTests has four tests more than before. The renders print "check 4, the reader's path: 392 of 392 rows identical" and "check 4, one full parse per volume: 392 of 392 rows identical, and its persons and terms are the reader's: 0 and 0, 58 and 19, 63 and 79".
- **macOS, natively.** The same 1,122 tests, with the same counts per target, all pass with none skipped. A clean build: "Build complete! (46.40 sec)", with no warnings. FRUSCoreKitTests: "✔ Test run with 393 tests in 49 suites passed after 0.066 seconds." Both renders give 392 of 392.
- **The guard.** The Test step's script and No runtime skips, read from `ci.yml`, ran in the swift image under `bash -eo pipefail`, with `LANG` unset and set to `C.UTF-8`, against this branch's real Linux log.
  - Both pass, and the named skip appears once.
  - No runtime skips searched 27 directories, the kit's two among them. It fails when `Test.cancel` is planted in a kit suite.
- **A difference, planted.** One character added to a golden file made both renders fail on that row alone. Each named the row and printed the first differing piece, ending "February 13, 1961.X</p></div>" in the golden file and "February 13, 1961.</p></div>" in the render.
- **The lookups, broken on purpose.** Rendering with empty lookups, along either path, fails the `<abbr>` test for that path while the 392 rows still match. A full parse that loses its last person, or one volume's terms, fails the list comparison.
- **Timing.** Testing took 113 seconds on Linux arm64 with 10 CPUs, 98 of them in FTS5StoreTests.
  - The test targets run one after another, so FRUSParityTests' time adds to the step's: 7.4 seconds, up from 3.9 at `cfc0d3c`.
  - Within that run, the reader's path took 7.1 seconds and the full-parse pass 3.2. Run alone, they took 4.0 and 0.6, and with Docker limited to 4 CPUs the reader's path took 7.5.
  - At PR #15, GitHub's amd64 runner ran FTS5StoreTests 3.9 times slower than this Mac (372 seconds against 96). At that ratio, the reader's path should take about 30 seconds there, and FRUSCoreKitTests well under one.
  - macOS took 87 seconds to test.
- **The image is unaffected.** `scripts/compose-smoke` passes. The image's build compiled FRUSLightCore and the server and no kit, and the stripped server binary was byte-identical to the previous build's: its layer came from the cache. The image is still 251 MB.

**Notes**

- **The parser's debug log.** A debug build of the kit prints `[TEIParser]` lines, so the Linux test log now holds about 1,000 of them, about 580 from the renders. Most are "Warning: unparseable <pb n=…>", for two bracketed page numbers that every parse of their volume meets. They match neither guard pattern.
- **The golden HTML cannot show the lookups.** The serializer writes a person's or a term's link from its ref alone, and drops the entry the lookup found. The one link a lookup decides, an `<abbr>` whose text names a term, occurs in none of the three fixture volumes. So the 392 rows would match with empty lists, or another volume's, as review showed by rendering with empty lookups. The full-parse test therefore compares the lists themselves, and the `<abbr>` test covers the one lookup that changes the HTML.
- **For S8.** `parseVolumeFull`'s persons and terms are `parsePersons`' and `parseTerms`', field for field, in all three volumes (none in the 1894 volume, 58 persons and 19 terms, and 63 and 79). Rendering from its ASTs gives the same bytes. So one XML pass per volume gives the server everything the reader's HTML needs.
- **The owner's next Mac build comes from `af8bedab`,** for the Golden files checkpoint, as `PLAN.md` says for a pin move. The S10 export will come from the build pinned at S10, after S6's pin move.
- **Mac check 2 is Done** in `PLAN.md`'s owner checkpoints. `docs/COORDINATION.md` records that FRUSCoreKit is compiled, that the CI compares both golden files made from the app's source, and that #1571 has merged.

**The owner's next step.** The three-volume export for the Golden files checkpoint can now be made, from a Mac build of `af8bedab`, in a library holding exactly the three fixture volumes. `scripts/make-golden --export <file>` then writes `index-summary.json` and `queries.results.json`. The top of the script says how to make the export.

**Next.**
- After the export, S6: FRUSCoreKit part 2, the indexer and search on Linux, and check 7's matcher and splitter half.
- Done alongside: #1572 added `docs/COORDINATION.md`'s appendix block to the app's `CLAUDE.md`, closing [joshbotts/FRUS-Explorer#1570](https://github.com/joshbotts/FRUS-Explorer/issues/1570).
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Coordination with the app's repository

4 October 2026 · branch `claude/coordination`

**Delivered:** `docs/COORDINATION.md`, a proposal the owner asked for, for Claude Code sessions in both repositories. The owner directed that synchronization work, and its token cost, fall on this repository's sessions. The app's sessions are not to be diverted beyond a few agreed rules, and app changes only the web edition needs are this repository's to write. The document:
- explains how the web edition uses the app's code: the pin, the shared kits, the index and export contract, and the golden files;
- explains how #1567 and #1569 made that code portable, and what part 2 will move;
- describes the app architecture that protects the arrangement: kit folders compiled twice, the FRUSCoreKit boundary test, forwarders, and single entry points;
- sets four rules for app sessions, and lists what they are not asked to do;
- assigns the rest to web sessions: a daily Linux watch of the app's `v2` (to be built), repairs, every web-only app change, pin moves and conflicts;
- includes a block for the app's `CLAUDE.md`.

It is filed for the app's sessions as [joshbotts/FRUS-Explorer#1570](https://github.com/joshbotts/FRUS-Explorer/issues/1570), which closes when the `CLAUDE.md` pull request merges. Three review rounds checked it against both repositories, and fixed several overstatements. Two of them needed fixes upstream. #1569 had merged by then, so they went in a follow-up, [joshbotts/FRUS-Explorer#1571](https://github.com/joshbotts/FRUS-Explorer/pull/1571):
- `public` does not mark web use, because most kit declarations were already public;
- the boundary test could trip on an app-only change, so its name check was narrowed.

**Next.** #1569 has merged. A web session:
- moves the pin to it (S3's pin move);
- opens the pull request adding the `CLAUDE.md` block to the app's repository;
- adds the daily watch.

## Session 3: FRUSCoreKit, part 1, upstream

4 October 2026 · branch `claude/s3-fruscorekit` · upstream [joshbotts/FRUS-Explorer#1569](https://github.com/joshbotts/FRUS-Explorer/pull/1569)

S3's upstream pull request, the second, moves the TEI pipeline and the citation code out of `FRUSExplorer/` into `FRUSCoreKit/`, a Foundation-only directory that both app targets compile and upstream's `Package.swift` builds as a target of its own. It branches from `v2` at `cfc0d3c`, which is still the pin; nothing has merged on `v2` since. As with S1, this entry records the results at the pull request's head, and the kit reaches CI in the pin-move pull request after the owner's Mac check 2 and merge. This pull request makes the parity tools ready for that pin, and passes CI at `cfc0d3c`, where `FRUSCoreKit` does not exist yet.

**The owner's decisions, 4 October**

- **Land it now,** while `v2` is quiet, rather than after the public release.
- **All of part 1:**
  - the TEI pipeline;
  - the citation formatter, parser and models, and `PageSpanResolver`;
  - the reader's path as the kit's API, which `DocumentViewModel.load` and `HTMLTemplate.build` call: `ReaderLookups`, `ASTToRenderNodeConverter.init(readerOf:lookups:brokenRefs:)` and `FRUSRenderNodeHTMLSerializer.reader`;
  - public access for the types S8 and S9 will need, provided each is what they need and making it public changes nothing for the app.

  The citation matcher, the block splitter and `PageRangeStore` stay in the app for S6, which brings the SearchService and ManifestStore they need.
- **The kit's suites are compiled twice,** by Xcode and by `swift test`, in `FRUSExplorerTests/FRUSCoreKit/`. Whatever needs the app sits behind `#if !SWIFT_PACKAGE`. Three more parser suites join them. A source audit guards the kit's boundary, and the tree-walking audits read `FRUSCoreKit/` wherever their rules apply.
- **Mac check 2:**
  - clean builds of both schemes;
  - the full iOS unit run, signed, with `v2`'s skips;
  - `swift test`, with the `FRUSCoreKitTests` count the pull request states;
  - a normalized symbol diff that shows only the names the pull request expects.
- **The three-volume export waits.** The owner's export for the Golden files checkpoint comes after the S3 pin move. That move changes the source digest, so golden files made from an export at `cfc0d3c` would go stale with it.
- **Left to the session:**
  - the trial's names: `FRUSURLScheme`, `HighlightColor`, `StoredSourceNote`, `ReaderLookups`, `FRUSASTNode+PrintedText.swift` and `ReaderRendering.swift`;
  - the old names stay as permanent forwarders;
  - what S8 needs beyond this, figure URLs for the web and the page shell, waits for pull requests of its own.

**The upstream pull request**

Branch `claude/fruscorekit-part1`: eight commits in review order, 72 files, 2,112 lines added and 715 removed. There is no index-version bump, no CloudKit schema change and no new dependency.

- **Moves.** 13 files and 10 suites move with `git mv` and no line changed, so each reads as a 100% rename. They come from `FRUSExplorer/TEI/`, `Citation/`, `CrossReference/`, `Browser/` and `Models/Manifest/`. `project.yml` compiles `FRUSCoreKit/` in both app targets.
- **Splits.** What the kit used from Apple-only files moves in, verbatim:
  - `FRUSURLScheme`: the cross-reference grammar and the figure URL, from the WebKit scheme handler;
  - `HighlightColor`: from the SwiftData highlight model;
  - `FRUSASTNode+PrintedText.swift`, with `StoredSourceNote`: from `IndexingPipeline.swift`.

  Three kit files lose their Apple-only halves to new app files: `VolumeStructure`'s `NavigationPath` overload, `CitationStyle.current`'s `UserDefaults` read and `BrokenRefsIndexStore`'s `Bundle.main` read. Every old name forwards.
- **Guards.** Each takes the old code on an Apple platform:
  - `CryptoKit` falls back to swift-crypto's `Crypto`;
  - `FoundationXML` is imported where it exists;
  - `SourceNoteKit` is imported where it is a module of its own;
  - `CitationPlainText` parses Markdown only where Darwin exists.

  `Linux/LinuxFoundationShims.swift` declares `String(localized:)` and `autoreleasepool` where Darwin is missing, and compiles to nothing on Apple platforms.
- **The reader's path** is public, in `TEI/ReaderRendering.swift`, and the app's reader calls it. The web reader will render through the app's own path, not a copy of it.
- **Public for S8 and S9:**
  - `CrossRefDestination`, stated `Sendable`, since a public enum is not inferred to be;
  - `FRUSURLScheme.resolveCrossRefTarget`;
  - `FRUSCanonicalURL`;
  - `CitationPlainText.plain` and `CitationPunctuation.withoutTerminalPeriod`;
  - every member of `CitableDocumentNumber`.

  The figure URL stays internal, for S8.
- **Eleven dual-compiled suites:** the seven the kit's files had, FootnoteLabelTests, PersonsListEncodingTests and FlushLeftSourcesParseTests, and ReaderRenderingTests, new with the reader's API.
  - Each imports the kit under `swift test` and the app in Xcode.
  - 33 `#if !SWIFT_PACKAGE` guards, each with its reason, keep the app's half in Xcode: 4 around the six suites whose subject is the app, 17 around tests and 12 around statements. The in-app citation suite is guarded test by test, so its caption rules run under `swift test` too.
  - Two tests pin what Linux reaches another way: CitationPlainTextTests copies each style's citation, which Apple platforms do by a Markdown parse and Linux by a marker strip, and the serializer suite checks a broken reference's VoiceOver label, which on Linux goes through the `String(localized:)` stand-in.
  - Under `swift test` they make `FRUSCoreKitTests`: 393 tests in 49 suites.
- **Audits.** `FRUSCoreKitBoundaryTests` (10 tests) reads the kit's source: the app compiles the kit into its own module, so it would build even if a kit file named an app type. The audit fails on:
  - an import other than Foundation outside its `canImport` branch;
  - `Bundle.main` or `UserDefaults`;
  - a type, function, constant or variable of the app's, named outside comments and strings;
  - unguarded code under `Linux/`;
  - a suite that, outside Xcode's branches, imports the app or names a top-level declaration of the app's or of the test target's other files, which Xcode builds and passes and only `swift test` fails;
  - `project.yml` or `Package.swift` dropping the kit.

  Eleven tree-walking audits whose rules a kit file can break now read `FRUSCoreKit/` too, the localized-Markdown census among them.
- **Records:**
  - upstream's `CLAUDE.md`, with a rule: after editing the kit, run `swift build --target FRUSCoreKit` and `swift test --filter FRUSCoreKitTests`;
  - the editable-content pointers, the stale paths and line citations, and CrossRefKit's comments, which no longer claim a parity its hard-coded fixtures never checked;
  - version-history entries and a session entry.

**Results at the pull request's head**

- **Linux, `swift:6.4-noble`, arm64**, in a scratch package that declares the kit as this repository will:
  - A clean build with tests took 25.2 s: "Build complete! (22.45 secs)", with no warning or error line.
  - `swift test list` lists 393 FRUSCoreKitTests. "✔ Test run with 393 tests in 49 suites passed after 0.125 seconds.", with no skips.
- **The renderer on Linux.** A command-line reader that uses only the kit's public API rendered the rows of `fixtures/golden/render/manifest.json`.
  - Debug and release each printed "rows: 392, golden: 392, identical: 392, differ: 0, missing: 0, same order: true".
  - A pass from one `parseVolumeFull` per volume gave "identical 392 of 392" (569 ms debug, 476 ms release).
  - The release build took 24.3 s. Rendering took 40.4 ms per row at the median, 15.9 s in all, with a 38.2 MB peak.
- **The citation rules.** Every newly public citation rule ran over 553 volumes, 3 styles and 4 number shapes: 7,220 lines. The Linux and macOS outputs are byte-identical (sha256 `b2c3dc33…`), and CitationPlainTextTests now holds both ways to the same expectations.
- **The same package natively on macOS**, built clean: "✔ Test run with 393 tests in 49 suites passed after 0.058 seconds.", and the reader rendered 392 of 392 rows identically, in a debug and a release build.
- **macOS, upstream's whole package,** from a clean `.build`:
  - `swift build --build-tests` took 45 s: "Build complete! (43.98 sec)", with 12 warning lines, the same six generator warnings S1 recorded and none from the kit.
  - `swift test` exited 0 in 116 s: 38 runs and 2,056 tests, all passed, none skipped. FRUSCoreKitTests: "✔ Test run with 393 tests in 49 suites passed after 0.061 seconds." 2,056 − 393 = 1,663, S1's count.
- **`FRUSExplorerMac`**, clean, unsigned, Debug: "** BUILD SUCCEEDED **" in 43 s at the head and 44 s at `cfc0d3c`, with identical warning lines (5 lines, the two known residues). The debug dylib defines 233,540 unique symbols at the head and 233,494 on `v2` (`nm -U -j | sort -u`). S1's 238,006 for the same `v2` code counted duplicates: its dylib gives 233,494 unique.
- **iOS**, clean, unsigned `build-for-testing`: "** TEST BUILD SUCCEEDED **" in 143 s at the head and 145 s at `cfc0d3c`, with 7 warning lines each, the two known residues.
- **The full iOS unit run**, unsigned, with the TEI mirror:
  - Head: "✘ Test run with 6484 tests in 763 suites failed after 384.845 seconds with 8 issues."
  - `cfc0d3c`: "✘ Test run with 6470 tests in 760 suites failed after 338.166 seconds with 8 issues."
  - The same 8 tests fail on both, all Keychain `.securityError(-34018)`, since an unsigned test host has no keychain: KeychainStoreTests 5, SettingsTests 2, SourceExplorerTests 1.
  - Both runs skip the same 17 tests and 2 suites.
  - The 14 extra tests are ReaderRenderingTests' 3, FRUSCoreKitBoundaryTests' 10 and CitationPlainTextTests' 1.
- **The audits, mutated.** Planted at once: `import SwiftUI`, `IndexingPipeline`, `UserDefaults.standard` and the app's `frusSubseries(from:)` in `FRUSCanonicalURL.swift`; an unguarded file under `Linux/`; `IndexingPipeline` and the test target's `makeTestPipeline` in `ReaderRenderingTests.swift`, outside its guards; and a `**…**` default in `CitationFormatter.swift`. The app's build still succeeded, and 6 tests failed, each naming the file and line: five of the boundary audit's and the localized-Markdown census. The package fails to build on each of the app's names.
- **The symbol diff** of the two Mac dylibs printed "raw: removed 522 added 568", then "normalized: removed 56 added 105". Every remaining name is expected:
  - the new kit types and members;
  - `normalizedWhitespace`, private before and internal now;
  - the closures of moved bodies;
  - two renumbered thunks;
  - SwiftUI generic metadata over `HighlightColor`, renumbered.
- **Which tree was measured.** The clean builds, the symbol diff, the mutation, and the Linux and native runs are of the head's code before upstream's session entry had its numbers; the head differs from that tree in `Planning/DEVELOPMENT-PLAN.md` alone, which nothing builds or reads. At the head itself, `8498587d`, the full iOS unit run above was made with the app removed first, and `swift test` on macOS and the Linux tests and release render were repeated, with the same results.

**Delivered here**

- **The source digest takes in `FRUSCoreKit` once the pin has it.** `UpstreamDigest.directories` lists `FRUSCoreKit`, and a listed directory with nothing at its path contributes nothing. So the digest at `cfc0d3c` is unchanged, and the committed golden files stay current. Anything else at a listed path must be a directory that can be read: a file, or a link pointing nowhere, is an error, never skipped. A submodule holding none of the directories, as an uninitialized one does, is an error too.
- **`tools/mac-golden` compiles `FRUSCoreKit` once the pin has it.** Its manifest lists the kit and compiles only the listed directories the submodule has.
  - A committed link to `FRUSCoreKit` would point nowhere until the pin moves, and SwiftPM warns about a link that points nowhere ("ignoring broken symlink"), even when it is excluded ("Invalid Exclude … File not found").
  - So the six per-directory links in `Sources/FRUSExplorer` become one, `upstream`, to the submodule, which exists at every pin. The manifest excludes the submodule's other top-level entries, as well as everything in the compiled directories that is not Swift.
- **Tests.** A new ProvenanceTests test covers the missing directory:
  - an absent `FRUSCoreKit` leaves the digest unchanged, and so does an empty one;
  - moving a file into it changes the digest, as the pin move will;
  - a file or a dangling link in its place is an error, and so is an empty or absent submodule.

  The old test's last step, which held that a missing directory is an error, gave way to it. With the skip removed, 18 of FRUSParityTests' 58 tests fail at `cfc0d3c`: this one, the check of the committed golden files, and the tests that summarize a database or validate golden files, since both compute the digest.

**Results here**

- **Linux, `swift:6.4-noble`, arm64.** A clean build with tests: "Build complete! (43.63 secs)", with no warnings. 725 tests: 724 pass, and the one skip is the named one. FRUSParityTests has 58, one more than before. CI's Test-step guard, run from `ci.yml` in the container, passes, and so does No runtime skips.
- **macOS, natively.** The same 725 tests pass, none skipped.
- **At `cfc0d3c`, in this worktree:**
  - `frus-parity check-golden` passes.
  - The digest is `a5bd78c2…`, the committed `sourceDigest` of both golden files. A Python recomputation gives the same, over 604 files.
  - A clean `tools/mac-golden` build: "Build complete! (40.47 sec)", with one warning, the app's known `GeneratedSummary` residue. The app module compiles the same 521 files as before, plus the stub.
  - `render` printed "render: 392 rows, 3554115 bytes of HTML". The HTML is byte-identical to the committed files, the rows match in order, and every provenance field is equal.
  - `expressions` wrote a byte-identical `queries.expressions.json`.
- **At the upstream head `8498587d`, in a scratch clone of this branch:**
  - The same manifest compiles 529 app files, 18 of them in `FRUSCoreKit`: "Build complete! (45.16 sec)" from clean, with the same one warning.
  - The HTML of all 392 rows is byte-identical to the committed files.
  - `scripts/make-golden`, with the head recorded as the pin, passed `check-golden`. Only provenance changed: `upstreamCommit` and `sourceDigest`, in `render/manifest.json` and `queries.expressions.json`, four lines.
  - The digest there, `39d9aed1…`, covers 612 files. Without `FRUSCoreKit` in the list it would have covered 594, missing the kit's 18.

**The pin-move pull request, after the merge**

- **`Package.swift`.** `FRUSCoreKit` (depending on SourceNoteKit, and on swift-crypto's `Crypto` for Linux only) and `FRUSCoreKitTests`, from the working manifest in the upstream pull request's description.
- **A check 4 test.** It renders all 392 golden rows on Linux through the kit's public API alone, and compares each byte for byte with `fixtures/golden/render`:
  1. `parseDocument`;
  2. `ReaderLookups` from the volume's persons and terms;
  3. `init(readerOf:lookups:brokenRefs:)` with the bundled broken-refs index;
  4. `FRUSRenderNodeHTMLSerializer.reader`.

  The upstream pull request's command-line reader did exactly that, for 392 of 392.
- **Check 7's formatter and parser half in CI**, inside FRUSCoreKitTests: the eight suites `CitationFormatterTests.swift` compiles under `swift test` (32 tests), CitationParserTests (26) and the three suites in `PageSpanResolverTests.swift` (23), 81 in all.
- **CI.** The count per target gains FRUSCoreKitTests, 393. The skip guard needs no change: the kit's suites skip nothing on Linux, no line of their log matches its pattern, and none calls `Test.cancel`.
- **Golden files.** `scripts/make-golden` on the owner's Mac at the merged commit. Only provenance may change, as rehearsed above. `tools/mac-golden` and the digest need no edit.

**Notes**

- **CI time, from PR #15** on GitHub's amd64 runner:
  - the `swift` job took 568 s, the Test step 384 s, and FTS5StoreTests 372 s of that;
  - the Build step took 71 s, from a restored cache, and the `compose` job 271 s.

  The scratch package with the kit, SourceNoteKit and swift-crypto built clean in 25.2 s on Linux arm64, and the kit's tests take well under a second, so the job stays far inside its 45-minute limit.
- **Two older issues** are listed in the upstream pull request for the owner to file:
  - CrossRefKit's grammar has drifted from the app's: its hard-coded fixtures expect `.document` for `#d100fn2`, where the app has returned `.footnote` since #988, and it does not treat a `mailto:` target as external. The upstream pull request's comments now say so instead of claiming parity. S8 should resolve cross-references with `FRUSURLScheme.resolveCrossRefTarget`, the app's own, now public.
  - `CitationPlainText` parses Markdown on Apple platforms and strips the paired markers on Linux. The two agree on all 7,220 lines above, and CitationPlainTextTests holds both to the formatters' own output, but a title with other Markdown syntax could print differently in S9's Cite.
- **One behaviour moves:** `BrokenRefsIndexStore.shared` is read when the reader's converter is built, not at the first cross-reference. It loads once per launch either way.
- **What was not run upstream:** a signed iOS run, since every run in the session was unsigned. The intermediate commits were not built one by one; upstream squash-merges.
- **`docs/prep/`.** `s3-linux-edits.tsv` is superseded by the upstream pull request, which makes those changes upstream, and so are the autoreleasepool and `String(localized:)` shims in `shims/`, by its `FRUSCoreKit/Linux/LinuxFoundationShims.swift`. `shims/KeychainShim.swift`, the `KeychainStore` stand-in, stays as S6's reference, to go upstream with S6's pull request. The shims never enter this repository's code. `PLAN.md` records the owner's decisions and Mac check 2. It now has a Mac check between S3 and S4, and splits check 7 between S3 and S6.

**Next.** The owner's Mac check 2 and merge of the upstream pull request, then the S3 pin-move pull request above. After it, the owner's three-volume export for the Golden files checkpoint. S6 follows, with the indexer, search and check 7's matcher half.

## Pin move: the six kits on Linux in CI

4 October 2026 · branch `claude/pin-cfc0d3c` · upstream [joshbotts/FRUS-Explorer#1567](https://github.com/joshbotts/FRUS-Explorer/pull/1567), merged as `cfc0d3c`

The owner ran Mac check 1 and squash-merged #1567 as `cfc0d3c`, the only commit on `v2` after `34a5120`. This is the pull request Session 1's entry describes: it moves the pin, adds the three kits the guards made portable, and lets CI allow the one named skip. The index version stays 65, the FTS schema 4 and the app build 49.

**Delivered**

- **The pin** moves from `34a5120` to `cfc0d3c` (rule 5). The submodule has no local changes.
- **`Package.swift`.**
  - The whole of FTS5Store replaces the `FTS5Schema` target, which compiled only its four pure-Swift files. Every dependency on that target, and the four files that imported it, now name `FTS5Store`. The module still holds a type called `FTS5Schema`, so `FTS5Schema.frusDocuments` reads as before.
  - New targets: TEIHeaderKit; ManifestGeneratorCore and ManifestGeneratorTests, which hold TEIHeaderKit's tests; SemanticVectorsKit and its tests; and FTS5StoreTests.
  - The guards' dependencies are Linux-only: `CSQLite` for FTS5Store and its tests, and swift-crypto's `Crypto` for SemanticVectorsKit. swift-crypto was already a dependency, so `Package.resolved` is unchanged.
  - sqlite3 is linked from one place on each platform. On Linux, `CSQLite`'s module map links it. The SDK's `SQLite3` module links nothing, so upstream's `linkedLibrary("sqlite3")` stays, for macOS only. Each test binary that uses SQLite depends on `libsqlite3` once, on both platforms.
  - The server and FRUSLightCore depend on none of the kits.
- **`ci.yml`.**
  - The Test step's skip guard allows one skip by name: FTS5StoreTests' "Database file has isExcludedFromBackupKey set after creation", skipped with a reason that begins "Linux: ". It is the named Linux-only skip SPEC's check 1 allows. Any other skip fails the job, from a trait or XCTSkip, and so does a test or suite that cancels itself with `Test.cancel`, or this test skipped for another reason. The named skip must appear exactly once. The log names no suite, so a second test with the same name would otherwise pass, and its absence means the test now runs or the log's format has changed. The guard reads the log with `grep -a`, so a NUL byte in a test's output cannot hide the lines after it.
  - A new step, No runtime skips, fails if any target in `Package.swift` calls `Test.cancel`. When it cancels one case of a parameterized test, the log has no line for it and the test is reported as passed, so the Test step cannot see it. No target calls it at `cfc0d3c`. The step reads the targets' directories from `swift package dump-package`.
  - The `swift` job's time limit is 45 minutes, as the `compose` job's is, up from 30 (see Timing).
- **Golden files.** `scripts/make-golden` ran at `cfc0d3c` on the owner's Mac, in 71 seconds. The HTML of all 392 rows (3,554,115 bytes) and the expressions of all 482 queries are byte-identical to `34a5120`'s. Only the provenance changed, in `render/manifest.json` and `queries.expressions.json`: `upstreamCommit`, and `sourceDigest`, since the guards change files inside the digest. `check-golden` passes. `PENDING` still lists the two files that wait for the owner's export.

**Results**

- **Linux, `swift:6.4-noble`, arm64.** A clean build with tests took 77 seconds, with no warnings. Of the 724 tests, 723 pass, and the one skip is the named one:

  | Target | Tests |
  | --- | --- |
  | SourceNoteKitTests | 292 |
  | FTS5StoreTests | 209 |
  | ManifestGeneratorTests | 60 |
  | SemanticVectorsKitTests | 35 |
  | CrossRefKitTests | 10 |
  | GeneratorKitTests | 7 |
  | FRUSParityTests | 57 |
  | FRUSLightCoreTests | 42 |
  | FRUSLightServerTests | 9 |
  | FTS5CheckTests | 3 |

  The six kits hold 613 of them, as S1 counted at the pull request's head.
- **macOS, natively.** The same 724 tests, with the same counts per target, all pass with none skipped. The backup-exclusion test runs there, and passes. A clean build took 52 seconds, with no warnings.
- **The guard, tested.** The Test step's script, read from `ci.yml`, ran in the swift image under `bash -eo pipefail`, as Actions runs a step, with `LANG` unset and set to `C.UTF-8`. It ran against the real Linux logs from arm64 and amd64, and against altered copies of them. A probe package in the image printed the real line for each kind of skip and cancellation.
  - It passes on both real logs, where the named skip appears once.
  - It fails with no skip at all. It fails when an extra skip sits beside the named one: a test with a "Linux: " reason, a test with no reason, a suite, or an XCTest case. It fails on a test or suite cancelled at runtime, with a reason or without, and on an extra skip after a NUL byte or after invalid UTF-8.
  - It fails when the named test is skipped for another reason, and when a skipped test's name is the named one with a prefix or a suffix. It fails on a second skipped test with the same name, and on two skips torn onto one line.
  - An earlier draft of the guard, without `-a`, the cancelled form or the count, passed with a cancelled test or suite, a second test of the same name, two skips on one line, or a skip after a NUL byte.
  - No runtime skips passes on this branch. It fails when `Test.cancel` is added to a kit's tests, to the web tests or to a library, and when `Package.swift` does not compile. It passes when the call is in a target this package does not build.
- **Timing.** Testing took 111 seconds on Linux arm64, 96 of them in FTS5StoreTests, whose exhaustive query-combination suites dominate; macOS took 102. GitHub's `ubuntu-24.04` runner is amd64 with 4 vCPUs, so the suite was also measured on amd64: in linux/amd64 `swift:6.4-noble` under Rosetta on this Mac, limited to 4 CPUs, a build with tests and no cache took 709 seconds, with no warnings, and testing took 331, 309 of them in FTS5StoreTests. All 724 tests ran there, with the same counts per target, and the guard passes on that log. A runner's vCPU is probably no faster than Rosetta on this Mac, so a run with no cache could come near the old 30-minute limit, and the limit is now 45.
- **The image is unaffected.** `scripts/compose-smoke` passes. The image's build compiles FRUSLightCore and the server and no kit, and the image is still 251 MB.

**Notes**

- **swift-build crashed once on Linux,** with signal 11 while planning the build, in its target-triple parsing on a worker thread. The same command then built. If CI's Build step ever fails that way, run it again.
- **The guard matches text.** A passing test whose display name contains "skipped" also matches `(Test|Suite) .* (skipped|was cancelled)`. No target built here has one, but upstream has 32 in 23 files at `cfc0d3c`. Nine are in its package's generator tests: RefHarvesterTests, POCOMIndexBuilderTests, and the LotClaimants, RecordGroupCatalog and SourceNoteEval generators' tests. The other 23 are in FRUSExplorerTests, among them IndexingPipelineTests, which S6 may compile. A session that adds such a target will see the guard fail, which errs the safe way. It must then narrow the pattern, for example to the forms Swift Testing prints: `skipped: "`, a closing `skipped.`, and `was cancelled after`.
- **The owner's next Mac build comes from `cfc0d3c`,** for the Golden files checkpoint and the S10 export, as `PLAN.md` says for a pin move. The guards change no code on Apple platforms, and the index version is still 65.
- **Mac check 1 is Done** in `PLAN.md`'s owner checkpoints.

**Next.** S3, the TEI renderer and Citation, is under way alongside: its upstream refactor is larger, and `docs/prep/README.md` lists what it needs. The owner's Golden files checkpoint still waits for a three-volume export.

## Session 1: the shared kits on Linux

4 October 2026 · branch `claude/s1-linux-guards` · upstream [joshbotts/FRUS-Explorer#1567](https://github.com/joshbotts/FRUS-Explorer/pull/1567)

The owner lifted the hold on upstream pull requests on 4 October. S1 opened the first one, as decided on 3 October: this session builds and tests the six kits against that pull request's head, and records the result here. After the owner's Mac check and merge, a separate pull request moves the pin and adds the kits to CI.

**Delivered**

- **The upstream pull request**, from `v2` at `34a5120`, which is still the pin: `v2` had not moved since 3 October. It contains:
  - **Import guards in 14 files.** `SQLite3` falls back to this repository's `CSQLite`, `CryptoKit` to swift-crypto's `Crypto`, and `OSLog` is imported only where it exists. `FoundationXML` and `FoundationNetworking` are imported only where they exist, which is not on Apple platforms.
  - **`URLSession.bytes(for:)` on Linux.** swift-corelibs-foundation lacks it, so on Linux `TEIHeaderFetcher` reads the response whole and replays it into the same scan.
  - **`FTS5Store/LinuxLogger.swift`**, a stand-in for `os.Logger`, compiled only where `OSLog` is missing, with upstream's licence header. Without the header, upstream's coding-standards audit would have failed the Mac check: the prepared patch in `docs/prep/` lacked it.
  - **Six `project.pbxproj` lines** from `xcodegen` for the new file, in both app targets.
  - **One named Linux-only skip.** FTS5StoreTests' backup-exclusion test is disabled where Darwin is missing, with the reason "Linux: swift-corelibs-foundation keeps no backup attribute, so excluding a file from backup is a silent no-op". It still runs on Apple platforms. This is the skip SPEC's check 1 asks to be named.
  - **Upstream's records:** version-history lines and a session entry in its `Planning/DEVELOPMENT-PLAN.md`.

**Results at the pull request's head**

- **Linux, `swift:6.4-noble`, arm64.** A local copy of this package, with the six kits' targets added and the submodule at the pull request, built with no warnings. All six kits' tests pass: SourceNoteKitTests 292, FTS5StoreTests 209, ManifestGeneratorTests 60 (which hold TEIHeaderKit's 22), SemanticVectorsKitTests 35, CrossRefKitTests 10, GeneratorKitTests 7. That is 613 tests. The one skip is the named one. At `34a5120`, each of the three kits stops at its first Apple-only import.
- **macOS, the same package:** 613 tests pass, none skipped.
- **Apple platforms compile what they did before.**
  - A `canImport` probe shows each guard taking its old code on the macOS, iOS Simulator and iOS SDKs.
  - A clean `FRUSExplorerMac` build gives the same warnings as `v2`, and a debug library defining the same 238,006 symbols.
  - The iOS unit target passes 6,470 tests in 760 suites, with the same 17 skips as `v2`.
  - Upstream's whole package passes under `swift test`: 1,663 tests in 37 runs.
  - One reader test fails from a cold simulator on `v2` too; the pull request leaves it for the owner to file.

**The pin-move pull request, after the merge**

- **`Package.swift`.**
  - FTS5Store replaces the `FTS5Schema` target, since two targets cannot compile the same files, and the four files that import `FTS5Schema` import `FTS5Store`.
  - Add TEIHeaderKit, ManifestGeneratorCore and its tests, and SemanticVectorsKit and its tests.
  - `CSQLite` and swift-crypto are Linux-only dependencies of the kits that need them.
  - The working manifest is in the upstream pull request's description. None of this can land before the pin moves: at `34a5120` FTS5Store does not build on Linux.
- **`ci.yml`.** Its skip guard allows the one named skip by name. As it stands, the guard fails on that line.
- **Golden files.** `scripts/make-golden` on the Mac at the merged commit: the guards change files inside the digest. A trial run gave byte-identical HTML and expressions, so only their provenance changes.

**Notes**

- **Mac check 1** now runs `swift test` too, from a clone at a real path. Xcode's schemes never run the kits' own test suites, and under `/tmp` six of upstream's source-scan tests fail falsely. The pull request lists the commands.
- **Nothing upstream keeps the guards alive.** Upstream has no CI, so a new unguarded Apple-only import in one of these kits would break the web build unseen, until the next pin move. The pull request offers the owner a line for upstream's `CLAUDE.md`.
- **On Linux, the logging shim prints every level to standard error,** debug included: FTS5StoreTests prints about 200 debug lines. S6 may want to quiet it.

**Next.** The owner's Mac check 1 and merge of #1567, then the pin-move pull request. S3 can start alongside: its upstream refactor is larger, and `docs/prep/README.md` lists what it needs.

## Import mode: unfinished journals and symbolic links

4 October 2026 · branch `claude/import-journal-symlinks`

Session 4's review found two gaps in its index summary, both fixed there. Import mode had the same two:
- It opens an export with `immutable=1`, which never rolls back a hot rollback journal, so a copy left mid-transaction would have been imported half-written.
- The drop zone skipped a symbolic link without a word, so a link that `docker compose cp` copied in sat in `/data/import` while `/readyz` still asked for an export. The importer, called directly, followed a link.

**Delivered**

- **Unfinished transactions.** An export arriving with a `-journal` file that may hold an unfinished transaction is refused, like one with a `-wal` file. The test is SQLite's own: the journal is not empty and its first byte is not zero, and one that cannot be opened or read counts as hot. Anything else in the journal's place, such as a link or a FIFO, counts too and is never opened. An empty or zeroed journal holds nothing to roll back and is accepted. Both refusals now say to remove the side file first, then copy in a fresh export: the side file would get the fresh export refused too.
- **Symbolic links.** A link in the drop zone is refused before anything reads through it, and not tried again until it changes. `docker compose cp` copies a link as a link, usually to a path that exists only on the host. The message says to copy the export itself with `docker compose cp -L`. The importer refuses a link too, in case anything else hands it one.
- **Links are seen, not skipped.** The scanner keeps a symbolic link as well as a regular file, reading the link's own attributes and never its target's, so the link is refused out loud on Linux and macOS alike.
- **`docs/INSTALL.md`.** Its table of refusals has both new messages.

**Results.** FRUSLightCoreTests has 5 new tests, 42 in all, covering:
- a journal holding an unfinished transaction;
- a journal that cannot be judged: a link to nowhere, a link to a zeroed journal, a FIFO and an unreadable file;
- an empty journal and a zeroed one;
- a link to an export, and a link pointing nowhere, both in the importer and in the drop zone, which reports a link once.

All pass on Linux arm64 and natively on macOS, with none skipped. Against `main`'s code, the journal test and both link tests fail; the test that accepts an empty or zeroed journal passes, as it should.

**Review.** An adversarial review confirmed 8 findings, all fixed. The main one: a journal the server could not open counted as harmless, the opposite of SQLite's rule, so a half-written copy could have been imported. A FIFO in the journal's place would have hung the importer. The install guide's advice for a link would have deleted the export just copied.

**Next.** Unchanged: the owner's Golden files checkpoint. S1, S3 and S6 wait for upstream pull requests.

## Session 4: the parity harness

3 October 2026 · branch `claude/s4-parity-harness`

S4 builds what checks 2–4 compare, and already runs on Linux the part of check 3 that needs no further upstream code. The owner decided three things on 3 October:
- S4 copies no upstream code, so renderer parity on Linux waits for S3 (rule 4).
- Check 3 passes when results differ only in the order of documents whose Mac scores are exactly equal, and reports each such group.
- The golden files that depend only on the app's source are made in the session, on the owner's Mac. The owner makes the two that need an export.

**Delivered**

- **Golden-file formats** (`Tests/ParityFormat`), shared by the Linux harness and the Mac tool. Each golden file records the tool that made it, the upstream commit, the app build (49), the index version (65), a digest of the app's sources and resources in the submodule, a digest of each input, and the platform. The inputs are the fixture TEI, the query list's queries (not their notes, so editing a note changes nothing) and, for the two files made from an export, the export's `research_provenance` stamp. A test recomputes the digests, so a golden file made from other app sources or resources, another query list or other fixtures fails as stale. The two export-based files must come from one export made by the pinned app build.
- **`tools/mac-golden`**, a Mac-only tool that runs the app's own code. Its package compiles the whole app module unmodified: all 520 Swift files, through six directory symlinks into the submodule, plus a one-line stub for an asset symbol that Xcode generates and SwiftPM does not. It needs macOS 26, because the app uses FoundationModels, and a debug build, because it imports the app with `@testable`. A clean build takes 45 seconds. CI does not build it.
  - `render` takes every row a full parse of each fixture volume yields and runs the Mac reader's own path: `DocumentViewModel.load`, then `HTMLTemplate.build`. It keeps the fragment inside `<body>` and copies none of the app's settings.
  - `expressions` runs SearchService's `parsedQuery(for:)`, `matchExpressions(for:)` and `exactTerms(from:)` over a throwaway empty database. The records are the same over a fixture index.
  - `results` runs `searchCount` and the first 50 results over a copy of an export, recording each score's bits. It refuses an export that is not exactly the three fixture volumes, that holds the owner's writing, or that has another index version. It also records the results after the 50th that tie with it, so a tie group crossing position 50 is known whole.
- **`frus-parity`** (`Tests/FRUSParity`, `Tests/FRUSParityTool`), on Linux and macOS:
  - `summarize` writes check 2's summary of a `frus.db`. It opens the file read-only and immutable, and hashes each table's rows with SHA-256 in natural-key order, framed as SQLite's `sha3_query` frames them, recording each statement's SQL.
    - It leaves out whatever depends on indexing history: rowids and other surrogate ids (a person rollup is named by its least member), the key order of `volume_structures`' JSON (read through `json_tree`), and the FTS5 segment layout. For full-text tables it compares `_config`, the averages record, `_docsize` by document, and the vocabulary.
    - The order of rows within a volume gates only for `document_cache`, `page_ranges` and `cross_references`, which the app reads in that order. `person_mentions` and `person_list_sources` are built from Swift sets, so their order changes from run to run.
    - It refuses an export that is not exactly the three fixture volumes (unless given `--any-volumes`), one with writing, one with another index version, one with a `-wal` file or an unfinished rollback journal beside it, one with a stale person rollup, and one holding any schema object it cannot classify. It also refuses fixture TEI that does not match `SHA256SUMS`. A path through a symbolic link is checked as the file it points to.
  - `compare-summary` compares two summaries.
  - `parse` prints the Linux parse of the query list.
  - `check-golden` validates `fixtures/golden`.
- **The query list** (`fixtures/parity`): 482 queries over 69 rules. R01–R46 follow the manual's §7.2 in order, with its examples verbatim. R47–R69 cover stemming, ranking, scopes, filters, dates, document types, front matter and the tokenizer. Re-deriving §7.2 found one rule the first draft missed: a phrase typed without inner quotation marks still matches text that prints them.
- **Golden files made in this session** (`fixtures/golden`):
  - the HTML of all 392 fixture rows, 3.55 MB;
  - the compiled expressions of all 482 queries.

  `fixtures/golden/PENDING` lists the two still to come from the owner's export: `index-summary.json` and `queries.results.json`.
- **`scripts/make-golden`**, the owner's script, in the style of `scripts/mac-check`. It builds the tool and writes the golden files that need only the app's source. With `--export`, it also writes the export-based ones from a temporary copy of the export. Then it runs `check-golden` and leaves the commit to the owner.

**Results**

- **Tests.** FRUSParityTests' 57 tests pass on Linux arm64 and natively on macOS, with no warnings and none skipped. The other targets are unchanged (358 tests).
- **Check 3's parse runs on Linux now.** For all 482 queries, the parser compiled on Linux gives the same expression, exact terms, operands, dropped operands and flags as the app's SearchService on the Mac. For the 457 queries in the default scope, it also gives the same compiled expressions. Comparisons are byte for byte. CI adds amd64.
- **The summary does not depend on SQLite's version.** Two three-volume databases were built from the owner's export, with the volumes in different orders and the rollup renumbered. They gave identical gating hashes on macOS (SQLite 3.54.0) and on Linux (3.45.1). The full 2.83 GB export took 19 seconds to summarize natively, read-only, using 38 MB of memory.
- **The render is stable.** Two runs, another build, and other time zones and locales all gave byte-identical HTML. It matches, for all 392 rows, the research build that used the reader's settings. The fields the reader is opened with do not change it; the tool checks that on every 25th row.
- **Ties are common.** On a three-volume index, 72 queries have exactly tied scores in their top 50, and 12 have a tie group crossing position 50. `results` was tested on a research copy built from the owner's export, not on a new export.

**What waits**

- Index parity (check 2), and check 3's counts and results, need the Linux indexer and SearchService (S6), and the owner's golden files.
- Renderer parity (check 4) on Linux needs the TEI pipeline (S3).
- The 25 queries outside the default scope wait for SearchService on Linux (S6), because their compiled expressions depend on its scope logic. 14 compile column-scoped expressions, 7 compile the unscoped parse for one table only, and 4 are refused.

**Review.** An adversarial review confirmed 17 findings, some overlapping. All are fixed, and each fix to the Swift code has a test that fails without it:
- a database reached through a symbolic link skipped the `-wal` check and the size limit, and `mac-golden` opened such a link read-write in place;
- an unfinished rollback journal went unnoticed;
- comparisons used Swift's `==`, which takes canonically equivalent text as equal;
- the staleness digest missed bundled resources, such as the broken-references index that changes the reader's HTML;
- the export-based golden files were not tied to the fixtures, to the pinned build or to each other;
- editing a query's notes would have made the golden files stale;
- the compiled-expression half of the golden file was never compared;
- `index-summary.json` would not have recorded the upstream commit.

**Notes**

- **Docker Desktop hung for about two hours.** A research container mounted the owner's export from `~/Documents`, and macOS held the mount behind a privacy prompt. No container started until the owner answered it. Nothing mounts `~/Documents` now; `scripts/make-golden` copies the export to a temporary folder first.
- **The Mac tool is outside CI.** A pin move can break it unseen until the next golden refresh, which `scripts/make-golden` then reports. The pull request that moves the pin must carry refreshed golden files, or its `swift` check fails.
- **Import mode has the same gap the review found here.** `IndexImport` checks only for a non-empty `-wal`, not for an unfinished journal, and does not resolve symbolic links. It is outside S4; it is flagged for a later session.
- **Each summary has its own timings.** A regenerated `index-summary.json` always differs in its `information.timings` section.

**Next.** The owner's Golden files checkpoint: a Mac library holding exactly the three fixture volumes, an export from it, then `scripts/make-golden --export`. `docs/prep/README.md` advises doing it once, after the public release. S1, S3 and S6 wait for upstream pull requests; until then, phase 1's server track has no further session that runs without them.

## Session 7: the published image and the install guide

3 October 2026 · branches `claude/s7-image-install`, `claude/s7-after-publish` and `claude/s7-trial`

**Delivered**

- **`.github/workflows/image.yml`.** On every push to `main` it publishes `ghcr.io/joshbotts/frus-explorer-light` in four jobs:
  1. Each architecture builds natively and in parallel: amd64 on `ubuntu-24.04`, arm64 on `ubuntu-24.04-arm`, free for public repositories. Each pushes by digest.
  2. A second job joins them under `sha-<commit>`, the commit's first 7 characters.
  3. A third pulls that tag and runs the Compose smoke test on both architectures.
  4. Only then does a fourth move `edge` to it.

  Rule 7 holds in two places: on a pull request that changes the image, the server or the submodule, both architectures build and nothing is pushed; a manual run publishes only from `main`. Each job gets only the permissions it needs, the actions are their Node 24 releases (as are `ci.yml`'s), and the image carries version and revision labels.
- **`docs/INSTALL.md`** covers a Mac and a Linux host: getting `compose.yaml`, the TEI folder (FRUS Explorer's own on a Mac once Docker Desktop may read it; a shallow HistoryAtState/frus clone on Linux), starting, exporting with the app's exact menu and option names, importing, what each `/readyz` step means, each kind of refusal and its fix, clearing the drop zone, upgrading, removing, and the settings.
- **`compose.yaml`.** Gotenberg is now behind a `pdf` profile. Nothing uses it before phase 3, and it is a 700 MB download.
- **The owner's decisions,** recorded in `PLAN.md` (and its shared copy, rev 51): the image is public, and the TEI sources are as above.

**A rehearsal of the guide on the owner's Mac.** It used the image built locally under the published name, which was removed afterwards so that it cannot shadow the real one:
- `compose.yaml` in its own folder, with `FRUS_TEI_DIR` in `.env` pointing at FRUS Explorer's folder: 553 TEI files and 96 figure folders, read-only;
- `docker compose up -d` started the server alone;
- the owner's real export was ready 37 seconds after `docker compose cp` began;
- memory peaked at 128 MiB, against SPEC's estimate of 4 GB, and the index takes 2.8 GB (2.7 GiB) in the volume.

**After merge**

- **The first publish.** `image.yml`'s run on `main` passed all six jobs in under six minutes: both builds, the join, the smoke test on both architectures, then `edge`. `edge` and `sha-7ecf0c9` name the same image index, for amd64 and arm64.
- **Public from the start.** The package came out public and linked to the repository. The settings change planned here was not needed.
- **An anonymous pull.** The `edge` manifest was fetched with an anonymous registry token. `docker pull` then ran with an empty Docker config on the owner's Mac. It got the arm64 image, 251 MB, labelled with revision `7ecf0c9`; `--version` answers `frus-light 0.1.0-dev`.
- **The macOS setting.** `INSTALL.md` now names the exact macOS setting, from the owner's screenshot on macOS 27. It also says what to do if Docker is not listed there yet.
- **The owner's Mac trial,** S7's done-criterion, followed the guide with the published image and found nothing wrong in it. `/readyz` answered `200`, serving 316,768 documents from 553 volumes at index version 65. Docker Desktop already had the Files & Folders permission, so the guide's advice for a Mac where Docker is not listed yet is untested.
- **What ready looks like.** `INSTALL.md` now says that `/readyz`'s ready answer gives the number of documents and volumes served.
- **`main` requires `compose` too.** Pull requests into `main` now need both CI jobs, `swift` and `compose`, to pass. Both run on every pull request.

**Next.** S8, the search, browse and document endpoints, joins both tracks: it needs the Linux indexer and search (S6), which wait for upstream pull requests. S4, the parity harness, needs no upstream changes. S9, the browser app, depends on S8.

## Session 5: the image and a Compose smoke test

3 October 2026 · branch `claude/s5-image-compose`

**Delivered**

- **`docker/Dockerfile`.** Two stages:
  - The build stage makes a release build in `swift:6.4-noble` with the Swift runtime linked in (`--static-swift-stdlib`). It uses SwiftPM's native build system, which SwiftPM marks deprecated, because with Swift 6.4's default (swiftbuild) that link leaves Foundation's CoreFoundation and ICU symbols unresolved. Explicit linker flags did not help. Revisit with the next Swift release.
  - Its SwiftPM cache mount, which speeds up local rebuilds, is one per architecture and locked, so concurrent or two-platform builds cannot share a build database. `.dockerignore` keeps docs, scripts, CI and the submodule's `Planning`, `Docs` and `Vendor` folders out of the build context.
  - The runtime stage is Ubuntu 24.04 with `libsqlite3-0` (3.45.1, FTS5), `libstdc++6`, CA certificates and `tini`. The server runs as UID 10001, and `/data` belongs to that user, so a new named volume starts with that ownership. The image is 251 MB.
  - A `HEALTHCHECK` runs `frus-light --check-health`, which asks the server's own `/healthz` over a socket, since the image has no curl. It tries 127.0.0.1, then ::1 when nothing listens on IPv4, and prints the status line or the error for Docker's health log. A listener that never answers costs one 3-second timeout, inside Docker's 5 seconds, and a reset connection cannot kill it with SIGPIPE.
  - A server that cannot write its data directory, such as a host folder owned by another user, now says it must be writable by its UID.
  - The encoder (phase 4), the web client (S9), `FRUSExplorer/Resources` (S8) and `rclone` (runtime options) arrive with the work that needs them.
- **`compose.yaml`.** The plan's file, with these additions:
  - `read_only: true` and a `/tmp` tmpfs, as SPEC's Security section asks;
  - every Linux capability dropped, and `no-new-privileges`;
  - `FRUS_IMAGE`, to run another image;
  - `FRUS_TEI_DIR`, defaulting to `./tei`;
  - `FRUS_HOST_PORT`, defaulting to 8080.

  It leaves out SPEC's `FRUS_ENCODER` (phase 4) and the secret key file, since phase 1 stores no keys. Until S7 publishes the image, its header shows how to build it under the default name. SPEC's Licensing asks for a `NOTICE` in the image; the repository has none yet, so only `LICENSE` ships.
- **`scripts/synthetic-export`.** It writes a small valid export from the real schema with the host's `sqlite3`, reading the index and FTS schema versions from `Compatibility.swift`.
- **`scripts/compose-smoke`.** It starts the Compose server and checks that:
  - it runs as UID 10001;
  - the root filesystem and the TEI folder are read-only, tested as root so that the mounts are tested rather than the server user's permissions, while `/data` and `/tmp` are writable;
  - the port is published on 127.0.0.1 only;
  - `/readyz` answers 503 before an import;
  - after `docker compose cp` of a synthetic export, `/readyz` answers 200 and the status reports 3 documents;
  - the container reports healthy;
  - after a restart, the index is still served.

  It runs the same locally and in CI.
- **`ci.yml`.** A `compose` job builds the image with Buildx, caching layers between runs, and runs the smoke test.

**Import mode, one addition.** `docker compose cp` keeps a file's mode, so an export saved 0600 arrives unreadable to UID 10001. It used to sit in `/readyz` as "still copying" forever. Now `/readyz` says the server cannot read it, names the fix (`docker compose cp -a`, or a `chmod`), and the file is tried again every minute.

**Results.** The smoke test passed locally against the arm64 image, and in review against an amd64 build made under emulation. The Swift targets pass on Linux and macOS with no warnings: FRUSLightCoreTests 37, and FRUSLightServerTests 9, with a test of the health check against a live server. The owner's real 2.83 GB export, copied in through Compose with `FRUS_TEI_DIR` pointing at the HistoryAtState/frus clone, was ready 37 seconds after the copy began, with all 744 TEI files visible read-only and the container healthy.

**A finding that changes the plan.** Docker Desktop cannot mount FRUS Explorer's own TEI folder. macOS refuses it with "operation not permitted", because it keeps other apps out of an app's container, so the plan's Compose sketch failed at `docker compose up`. `compose.yaml` now mounts `./tei` by default; nothing reads TEI files until the reader in S8. `docs/PLAN.md` (and its shared copy, rev 50) and `docs/prep/README.md` record the options for the owner to choose before S7:
- a HistoryAtState/frus clone, with the same TEI XML but not the 96 folders of figure images the app downloads;
- the app's folder, once Docker Desktop is allowed access to other apps' data;
- fetching from GitHub on first open, which SPEC allows.

**Notes**

- The `compose` check is not yet required on `main`; the owner can add it once it has run.
- The health check tries 127.0.0.1, then ::1, so a server bound to either answers.

**Next: S7.** The published image and `docs/INSTALL.md`. It needs two decisions from the owner: where TEI files come from, and whether the image is public. S4, the parity harness, can run first.

## Session 2: the server and Import mode

3 October 2026 · branch `claude/s2-server-import`

S1 waits. The owner asked that sessions not open pull requests on `FRUS-Explorer` for now, so the server track went first. Like S0, this session ran on the owner's Mac.

**Delivered**

- **The server.** `FRUSLightServer` is a Hummingbird 2.27 server with three endpoints:
  - `/healthz` answers as soon as the process runs.
  - `/readyz` returns 503 naming the current step, and 200 once an index is open.
  - `/api/v1/status` reports the versions, SQLite's version, the index summary, and an import's progress and outcome.

  `--version` still prints the version.
- **Configuration.** The phase-1 variables in SPEC's table are read: `FRUS_MODE`, `FRUS_AUTH`, `FRUS_DATA_DIR`, `FRUS_PUBLIC_URL`, `FRUS_PDF_URL` and `FRUS_OFFLINE`. Every problem is reported at once. Standalone mode and sign-in are refused until their phases. Beyond SPEC's table:
  - `FRUS_HOST` defaults to 127.0.0.1, as SPEC's Security section asks; the image in S5 sets 0.0.0.0.
  - `FRUS_PORT` defaults to 8080.
  - `FRUS_IMPORT_POLL_SECONDS` defaults to 2, from 0.05 to 3600.
  - `LOG_LEVEL` sets the log level.
- **Import mode.** A watcher looks at `/data/import`. It imports a file once the file has stopped changing between two looks and has reached the size its SQLite header records; `docker compose cp` makes a file visible while it is still copying. The steps:
  1. `copying_export`: the backup API copies the export into `frus.db.new`.
  2. `checking_format`: the tables are present, `user_version` is 4, and the copy is switched to rollback-journal mode.
  3. `checking_versions`: a stamped export must have both index versions at 65 and both FTS schema versions at 4. An unstamped copy must have every `document_revisions.index_version` at 65.
  4. `checking_writing`: an export with notes, summaries or tags is refused, since phase 1 serves the corpus only. So is a stamp that denies writing the file holds.
  5. `checking_integrity`: `quick_check`, then the rank-1 check on both FTS tables, run on the writable copy.
  6. `installing_index`: through `IndexWriter`, `frus.db` becomes `frus.db.prev` and `frus.db.new` becomes `frus.db`.
  7. `opening_index`: the index opens with `immutable=1`.

  Failures are sorted by fault:
  - **The file's fault** (a refusal): it stays where it is and is not tried again until it changes.
  - **The server's fault** (too little disk space, a write error): it is tried again after a minute.

  An installed file is removed from the drop zone. If it cannot be removed, the import report says so, and it is not imported again. An export that is already live, found again after a restart that came between installing it and removing it, is removed rather than re-imported over the rollback copy. A copy that arrives with a non-empty `-wal` beside it is refused: `immutable=1` would ignore the newest data in it.

  The install keeps the old index as `frus.db.prev` through a hard link, then replaces `frus.db` with one atomic `rename`, so `frus.db` exists at every instant.

  Blocking SQLite work runs on Dispatch threads, off Swift's cooperative pool. At start, the server listens before it opens the existing index, so `/healthz` answers at once; meanwhile `/readyz` reports `opening_index`. An index at another version leaves the server not ready, with both versions named. A file still arriving is named in `/readyz`.
- **The five v1 interfaces**, each with its phase 1 implementation:
  1. `IndexWriter`: `LocalIndexWriter`, plus `ReadOnlyIndexWriter` for snapshot mode.
  2. `CorrectionStore`: override rows in `app.db`.
  3. `UserStore`: `SQLiteUserStore`, with numbered migrations. Migration 1 adds `users` and `index_corrections`.
  4. `SessionStore` (in memory), `JobQueue` (in process; imports run as jobs) and `FileStore` (`DataDirectory`).
  5. `/healthz` and `/readyz`.
- **Tests.** Synthetic exports are built from the real v65 export's schema, kept as `Tests/FRUSLightTestSupport/Fixtures/export-v65-schema.sql` (schema only, no rows). The tests cover:
  - every refusal reason;
  - disk space as a server-side problem that is tried again;
  - an undeletable drop file, and an export that is already live;
  - the walk through every import step, checked at `/readyz` through the router;
  - a restart, and the watcher's import, through the application `buildApplication` makes;
  - a clean stop on shutdown;
  - that the supported index version, the FTS schema version and the export's FTS DDL match the pinned submodule.

  One path is covered only by sorting a SQLite failure by its result code: a destination write failing during the copy.

**Results**

| Target | Tests | Linux, arm64 | macOS, native |
| --- | --- | --- | --- |
| SourceNoteKitTests | 292 | Pass | Pass |
| CrossRefKitTests | 10 | Pass | Pass |
| GeneratorKitTests | 7 | Pass | Pass |
| FTS5CheckTests | 3 | Pass | Pass |
| FRUSLightCoreTests | 36 | Pass | Pass |
| FRUSLightServerTests | 8 | Pass | Pass |

**The owner's real export.** The 2.83 GB file, exported on 3 October from build 49, was imported on Linux in a container, with `/data` in a named volume and the file copied in with `docker cp`:
- the server waited for the copy to finish;
- it imported in about 18 seconds: 3 to copy, 15 to check;
- it then served 316,768 documents from 553 volumes, at index version 65.

A restart was ready in 2 seconds with no copy. The import was then repeated with the container on one CPU:
- across 164 `/healthz` requests made during the 15-second integrity check, the slowest took 17 ms;
- SIGTERM stopped the server with exit status 0 in 0.15 seconds.

**Deferred, with the reason**

- Comparing each document's `content_hash` and `body_hash` with its TEI (SPEC's import step 5), and a `content_hash` self-check. Both need `IndexingPipeline` (S6); hashing here would reimplement it (rule 4).
- Moving an export's writing into the user store waits for phase 2, as do the backups that precede each `app.db` migration.
- SPEC rule 7 has the server write corrections into the index, but phase 1 serves it immutable. Corrections are stored as override rows first, and how they reach a served index is decided before phase 3.

**Next: S5.** The image and a Compose smoke test, on the server track. S4, the parity harness, needs no upstream changes and can run too. S1, S3 and S6 wait for upstream pull requests.

## Session 0: the scaffold

3 October 2026 · branch `claude/s0-scaffold`

This session ran on the owner's Mac rather than in a cloud session: macOS 27, Docker Desktop 4.93, `swift:6.4-noble` on arm64. No tool available here opens a cloud session with both repositories selected. CI runs the same build on GitHub's amd64 runner. The shared plan (rev 43) and specification matched their files when the session started.

**Delivered**

- `upstream/FRUS-Explorer`, pinned to `34a5120` (tag `build-49`, index version 65). That commit matches the owner's Mac build and research export.
- `scripts/swift`, which runs SwiftPM in `swift:6.4-noble` plus `libsqlite3-dev`, in a derived image it builds once. `scripts/doctor` checks Docker, the image, the submodule and the container's network.
- `Package.swift`:
  - `CSQLite`;
  - SourceNoteKit, CrossRefKit and GeneratorKit and their tests, from the submodule with upstream's settings;
  - `FTS5Schema`, which is `FTS5Types.swift` alone;
  - the FTS5 check;
  - `FRUSLightServer`, which prints its version.
- `.github/workflows/ci.yml`: build, test (failing on any skipped test) and counts per target.
- `fixtures/tei/`: the three volumes from HistoryAtState/frus `8e5da08`, with `SOURCE` and `SHA256SUMS`. They are byte-identical to the Mac app's copies and to GitHub's.
- `CLAUDE.md`, this log and `.gitignore`.

**Results**

| Target | Tests | Linux, arm64 | macOS, native |
| --- | --- | --- | --- |
| SourceNoteKitTests | 292 | Pass | Pass |
| CrossRefKitTests | 10 | Pass | Pass |
| GeneratorKitTests | 7 | Pass | Pass |
| FTS5CheckTests | 3 | Pass | Pass |

Both builds have no warnings. CI on GitHub's amd64 runner passed with the same counts (run 37146459177); the build took 26 seconds. The FTS5 check builds `frus_documents` with `FTS5Schema.frusDocuments.createTableSQL` over a `document_cache` content table.
- **Prefix stemming:** FTS5's porter tokenizer stems a prefix term as if it were a whole word. So `negoti*` and `negotiating*` match "negotiating", while `negotiat*` stays `negotiat*` and matches nothing; no stored term begins with it.
- **NEAR distance:** a second document holds both words beyond the NEAR distance, so the distance itself is tested.
- **Malformed queries:** a malformed query must throw rather than return no rows.

**Notes for later sessions**

- `scripts/swift` passes proxy variables and a CA bundle only when they are set, and none were set here. S1, the first cloud session, should run `scripts/doctor` first and record whether the container reaches github.com.
- Both scripts add `~/.docker/bin` to `PATH` when `docker` is missing, as on a Mac where Docker Desktop's CLI is not on a non-interactive shell's path.
- In a git worktree, `/src/.git` points outside the container's mount, so git inside the container fails at the repository root. SwiftPM builds don't need it; `scripts/doctor` runs its network check from `/tmp`.
- Rule 3 asks for the session's task to be ticked in `docs/PLAN.md`, but the plan has no per-session checkbox, so nothing was ticked. Changing the plan would also put it out of step with its shared copy. `docs/prep/README.md` now lists this under "Before the S1 prompt".
- After this CI has run, the owner protects `main`: pull requests required, no required approvals, and the `swift` check required.

**Next: S1.** An upstream pull request with Linux guards for TEIHeaderKit, SemanticVectorsKit and FTS5Store. Before writing its prompt, settle the items under "Before the S1 prompt" in `docs/prep/README.md`, and answer the plan's open question on pull requests to `FRUS-Explorer`. `docs/prep/s1-linux-guards.patch` is a starting point.
