# FRUS Explorer and FRUS Explorer Light: working across the two repositories

A proposal for the owner, and for Claude Code sessions in either repository. Drafted 4 October 2026, when the web edition was pinned to the app's commit `cfc0d3c` (build 49, index version 65). Updated the same day, when S3's pin move took the pin to `af8bedab`, with FRUSCoreKit part 1, and on 5 October, when S6's took it to `f69b4a0a`, with part 2; the build and index version are unchanged. On 6 October S8a's upstream pull request merged as `101e17d7`, and the server began linking the kit; the pin stays at `f69b4a0a` until S8b moves it.

- **The app:** FRUS Explorer, for Mac and iOS, in [`joshbotts/FRUS-Explorer`](https://github.com/joshbotts/FRUS-Explorer).
- **The web edition:** FRUS Explorer Light, a self-hosted server, in [`joshbotts/FRUS-Explorer-Web-App`](https://github.com/joshbotts/FRUS-Explorer-Web-App).

The web edition does not reimplement the app. It compiles some of the app's own Swift files on Linux, and checks its results against reference outputs made by the app's own code.

## The division of labour

**Sessions working on the app follow four rules (section 4) and do nothing else for the web edition.** The rules protect the parts of the app's architecture the web edition stands on. Since #1569, a test in the app's normal Xcode run checks rules 1 and 2 for `FRUSCoreKit/`. For everything else, the web side's daily Linux build catches what gets through. App sessions do not label, notify, run Linux builds or write web code. When app work and the web edition pull different ways, the app's work goes ahead, and the web side adapts.

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
| SourceNoteKit, CrossRefKit, GeneratorKit | Since S0 | Tests run in the web CI. SourceNoteKit serves the reader through FRUSCoreKit since S8a, and will serve Source Explorer. CrossRefKit has drifted from the app's own cross-reference rules, so the reader will use FRUSCoreKit's `FRUSURLScheme.resolveCrossRefTarget` instead |
| FTS5Store | Whole kit since the pin move after S1 (web pull request #15). Its schema file was compiled from S0 and its query compiler from S4 | The parity harness compares its parse of 482 queries with the app's. The server will use it for search |
| TEIHeaderKit, with ManifestGeneratorCore and ManifestGeneratorTests for its tests | Since the pin move after S1 | Tests only, for now |
| SemanticVectorsKit | Since the pin move after S1 | Semantic search, from phase 4 |
| FRUSCoreKit, part 1 | Since S3's pin move, to `af8bedab` | The reader's HTML, which the server serves since S8a, and Cite. The web CI runs its tests, and renders the 392 golden rows with it |
| FRUSCoreKit, part 2 | Since S6's pin move, to `f69b4a0a` | Indexing and search on the server, and Citation Lookup's matcher in phase 2. The web CI runs the kit's 878 tests, check 7's matcher half among them, and indexes and searches the fixtures with it for checks 2 and 3 |
| WordCloudKit | Not compiled | Built on Apple's NaturalLanguage framework. Phase 4 plans a separate Linux lemmatizer |

The server links FRUSCoreKit, FTS5Store and SourceNoteKit since S8a, through its `FRUSLightAPI` target. At `f69b4a0a` it renders the reader's HTML with the kit and reads the manifest with `FixedVolumeCatalogue`. Search waits for S8b's pin move, which brings the read-only open: every opener before it writes to the database it opens. On a Mac only, the web repository's `tools/mac-golden` compiles the whole app module, unmodified, to make golden files.

**The index and export contract.** In phase 1, the server serves a database the app exports with Settings ▸ Data & Recovery ▸ Export Research Database…. It serves one index version and one FTS schema generation: `IndexingPipeline.currentDateIndexVersion` (65) and `FTS5Connection.currentSchemaGeneration` (4) at the pin. A web test reads both declaration lines from the submodule. The server reads the export's `research_provenance` stamp. It refuses an export from another index version or FTS generation, one taken while the app was still re-indexing, one that includes the owner's writing, and one in use (a `-wal` or unfinished `-journal` beside it).

**Golden files.** `tools/mac-golden` runs the app's reader (`DocumentViewModel.load`, then `HTMLTemplate.build`) and SearchService. It writes:
- the reader's HTML for all 392 rows of three small fixture volumes;
- what SearchService compiles for each of 482 queries, covering every search rule in the user manual's §7.2.

Two more come from an export of a Mac library holding exactly those three volumes: a summary of the index, and each query's count and first 50 results. Each pin move needs a new export from the build it pins, made after Erase Everything…, since a build at the same index version does not re-index what an earlier build indexed.

Since S6's pin move the web CI compares all four, through FRUSCoreKit's public API alone, as the server will use it:
- check 2: the kit indexes the three volumes, and the summary of its index is the export's;
- check 3: the kit's SearchService returns each query's count and first 50 results as the app does, and compiles each query, in every scope, as the app does;
- check 4: the kit renders all 392 rows byte-identical to the app's reader, along the reader's path and again from one full parse per volume, the path the server serves. Since S8a the CI also fetches every row through the server's reader route.

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

At the pull request's head, read-only answers equal read-write answers, score bits included, on Linux and on macOS; the full iOS unit run (6,505 tests) failed only the 8 Keychain tests an unsigned build fails; and `tools/mac-golden` wrote all 392 rows and 482 expressions byte for byte as at `f69b4a0a`.

## 3. The architecture that protects coordination

These structures let the two codebases share code without app sessions having to think about the web edition. Web sessions add and maintain them, in pull requests on the app's repository.

- **Kit folders, compiled twice.** FTS5Store, SourceNoteKit, TEIHeaderKit, SemanticVectorsKit and `FRUSCoreKit/` are top-level folders. Both app targets compile them as source, and the package also builds each as an SPM target. CrossRefKit, GeneratorKit and ManifestGeneratorCore are SPM targets only.
  - The SPM build compiles a kit alone, so it is where a kit naming an app declaration first fails.
  - A Linux-only break, such as an unguarded Apple import, shows only in a Linux build: the web CI and its daily watch.
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
| Watch the app's `v2` | Daily | A scheduled web CI job, which a web session will add, builds and tests the shared kits at `v2`'s head on Linux. It also compares the index version, FTS generation and export stamp with the pin, and opens a web issue for anything new |
| Repair breaks | When the watch fails, or a pin move's golden files differ | The smallest fix that leaves behaviour on Apple platforms unchanged: a web-side change when a kit's API or the index contract moved; otherwise a pull request on the app's repository that adds a guard, passes a value in, or moves a declaration into a kit. The app's change is never reverted |
| App changes only the web edition needs | When a web session needs one | A pull request on the app's repository, written by the web session (list below) |
| Pin moves | See the cadence below | Web pull request (checklist below) |
| Conflicts | When a web-authored pull request conflicts with app work | The web side merges `v2` into its branch and resolves the conflict, as the app's own workflows do, with no rebase or force-push. Before asking for the merge, it lists the app's open pull requests that touch the lines it moves, so the owner can merge it after they land. App work never waits, and never has to port a web move |
| Boundary-test upkeep | If it ever trips on an app-only change | A pull request on the app's repository that narrows the test |
| This document, and the app's `CLAUDE.md` section | When the rules or the architecture change | Web-authored pull requests in both repositories |

**Web-authored pull requests on the app's repository.** Each one:
- follows the app's conventions: a `claude/<topic>` branch, an outcome-sentence title, a session entry in `Planning/DEVELOPMENT-PLAN.md`, and version-history lines;
- states exactly what changes on Apple platforms, if anything;
- has already run, and quotes, both app builds, the full iOS unit run and `swift test`, from a clone at a real path (under `/tmp`, six source-scan tests fail falsely);
- lists those commands for the owner's Mac check, with the counts to expect;
- carries the `Mac` label, with "Mac verification requested" in its body;
- is opened when the app's repository is quiet, and kept small or split into reviewable commits.

**App changes only the web edition needs,** all to be written by web sessions:
- further moves into the kits (FRUSCoreKit part 2 was S6's, merged as #1573 and #1574; the read-only open and the reader's page were S8a's, #1575);
- the index version shown beside Export Research Database… (phase 1), so a user can match an export to a server before copying 2.8 GB;
- the JSON export at `formatVersion` 7, adding the model types it lacks, above all saved searches and working corpora (phase 2);
- optionally, a JSON importer, so data made on the web can return to the Mac;
- public access for kit types the server needs, as each need arises;
- boundary tests for the other kits.

**Pin cadence.** Until the app's public release, the pin holds unless the web edition needs a merged change, and web-authored pull requests are batched so it moves as seldom as possible. After the release, it moves about once per app release.

**A pin move, checklist:**
- The submodule, and the web `Package.swift` if kit folders changed.
- `Sources/FRUSLightCore/Compatibility.swift`, and the index version and app build in `docs/INSTALL.md`, if they changed.
- If the export's schema changed: a new `Tests/FRUSLightTestSupport/Fixtures/export-v<N>-schema.sql` from a real export by the pinned build (the owner is asked for one), the paths that name it, and the table list in `Tests/FRUSParity/IndexSchema.swift`.
- `UpstreamDigest.directories` and `appDirectories` in `tools/mac-golden/Package.swift`, which must stay the same list, if the app targets gained a source folder (`project.yml`).
- The CI's allow-list, if a kit test gained or lost a Linux-only skip. The web CI fails on any other skip, and on `Test.cancel`. It matches a skip by the verb right after the test's name, so a passing test whose name says "skipped" is not one.
- The golden files, remade with `scripts/make-golden --export` on a Mac. The export must come from the pinned app build, in a library holding exactly the three fixture volumes, emptied with Erase Everything… and downloaded again, so the owner is asked for one. Until it arrives, the two files made from an export are listed in `fixtures/golden/PENDING` and the pull request stays a draft.

## 6. For the owner

1. **Sections 4 and 5 are the arrangement.** #1572 added the appendix block to the app's `CLAUDE.md`. That block replaces the `CLAUDE.md` line offered as an owner item in #1567. #1569 added a FRUSCoreKit entry to `CLAUDE.md`'s list of package targets; the block points to that entry rather than repeating it.
2. **Allow the daily watch.** It runs in the web repository's GitHub Actions and needs nothing from the app's repository, which is public.
3. **Expect these requests from web sessions:**
   - a Mac check and merge for each web-authored pull request;
   - now and then, an export from the pinned app build: three volumes for the golden files, or any export when the schema changes;
   - the full-corpus export before S10, as the owner checkpoints in `PLAN.md` list.
4. **The three-volume export, at each pin move.** The owner made the first on 4 October, from a build of `af8bedab`, the second on 5 October, from a build of `f69b4a0a`, for S6's pin move, and the third on 6 October, from a build of `101e17d7`, for S8's. Each later pin move needs another.

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
