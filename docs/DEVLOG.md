# Development log

One entry per session, newest first.

## Pin move: FRUSCoreKit on Linux in CI

4 October 2026 · branch `claude/pin-2a4df13` · upstream [joshbotts/FRUS-Explorer#1569](https://github.com/joshbotts/FRUS-Explorer/pull/1569), merged as `f102fa4d`, and [#1571](https://github.com/joshbotts/FRUS-Explorer/pull/1571), merged as `2a4df13c`

The owner ran Mac check 2 and squash-merged #1569 as `f102fa4d`, then #1571, which narrows the boundary test, as `2a4df13c`. They are the only commits on `v2` after `cfc0d3c`. This is the pull request Session 3's entry describes: it moves the pin, compiles FRUSCoreKit and its suites, and runs check 4 on Linux in CI. The index version stays 65, the FTS schema 4 and the app build 49, so `Compatibility.swift`, `docs/INSTALL.md` and the export's schema fixture are unchanged.

**Delivered**

- **The pin** moves from `cfc0d3c` to `2a4df13` (rule 5). The submodule has no local changes.
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
- **Golden files.** `scripts/make-golden` ran at `2a4df13` on the owner's Mac, in 89 seconds.
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
- **The owner's next Mac build comes from `2a4df13`,** for the Golden files checkpoint, as `PLAN.md` says for a pin move. The S10 export will come from the build pinned at S10, after S6's pin move.
- **Mac check 2 is Done** in `PLAN.md`'s owner checkpoints. `docs/COORDINATION.md` records that FRUSCoreKit is compiled, that the CI compares both golden files made from the app's source, and that #1571 has merged.

**The owner's next step.** The three-volume export for the Golden files checkpoint can now be made, from a Mac build of `2a4df13`, in a library holding exactly the three fixture volumes. `scripts/make-golden --export <file>` then writes `index-summary.json` and `queries.results.json`. The top of the script says how to make the export.

**Next.**
- After the export, S6: FRUSCoreKit part 2, the indexer and search on Linux, and check 7's matcher and splitter half.
- Alongside it, a web session opens the pull request that adds `docs/COORDINATION.md`'s appendix block to the app's `CLAUDE.md`. Its merge closes [joshbotts/FRUS-Explorer#1570](https://github.com/joshbotts/FRUS-Explorer/issues/1570).
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
