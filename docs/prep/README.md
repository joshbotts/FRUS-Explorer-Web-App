# Readiness notes

3 October 2026 · at `FRUS-Explorer` commit `34a5120` (index version 65, app build 49)

Sessions 0 and 2 are done; see `docs/DEVLOG.md`. S1 waits, because the owner asked that sessions not open pull requests on `FRUS-Explorer` for now. This folder keeps what a dry run on Linux found for later sessions, so their prompts can start from evidence rather than estimates.

## What was verified

| Claim | Result |
| --- | --- |
| S0's three kits build and pass on Linux | Yes, in `swift:6.4-noble` on arm64: SourceNoteKit 292 tests, CrossRefKit 10, GeneratorKit 7, no warnings. The plan's 219 was the count on 22 September |
| FTS5 works with the app's own DDL | Yes, on SQLite 3.45.1. `FTS5Types.swift` compiles on its own, since it imports only Foundation. `frus_documents` is an external-content table over `document_cache`. The porter tokenizer stems a prefix term as if it were a whole word: `negotiating*` and `negoti*` match "negotiating", but `negotiat*` stays `negotiat*`, which no stored term begins with |
| Hummingbird 2 builds | Yes: 2.27.0 with Swift 6.4 on Linux. It resolves swift-crypto 5.0.0 |
| The owner's export matches the pin | Yes. `~/Documents/frus-index.sqlite`, exported on 3 October from build 49: index version 65, FTS schema 4, 553 volumes and 316,768 documents, the whole manifest |
| The fixtures match the Mac's copies | Yes. HistoryAtState/frus commit `8e5da08` and the Mac app's downloads are byte-identical, for the three fixtures and for all 553 volumes. The app downloads from `master` and saves the bytes unchanged |
| TEI rendering matches on Linux | Yes. All 392 fixture documents render to byte-identical HTML on Linux and macOS, in a command-line build with the serializer's default options |
| The indexer and search run on Linux | Yes, after the S6 edits listed below. The three fixture volumes index in 0.2–0.4 seconds each, in a debug build on arm64 |

## Before the S1 prompt

- **Rules 2, 3 and 5 collide.** S1 needs two pull requests: the guards upstream, and the web repository's DEVLOG entry and `Package.swift`. Upstream has no CI and squash-merges, so a pull request's head never reaches `v2`, and the pin can move only after the owner merges. Decided on 3 October: S1 builds and tests the six kits against its pull request's head in the session and records the output in DEVLOG; after Mac check 1 and the merge, a separate pull request moves the pin and adds the kits to CI.
- **The library guards the plan names are enough.** `s1-linux-guards.patch` has them. The test side needs more:
  - FTS5StoreTests imports SQLite3 in 7 files. With guards, 208 of its 209 tests pass. The failure is the backup-exclusion test (`FTS5StoreTests.swift:523-529`): excluding a file from backup is a silent no-op on Linux, so the test needs a named Linux skip, as check 1 asks.
  - The logging shim must accept `os.Logger`'s `privacy:` interpolation, which FTS5Store uses 12 times. The patch's `LinuxLogger.swift` does.
  - TEIHeaderKit has no test target. Its 22 tests live in ManifestGeneratorTests, which needs FoundationNetworking and a stand-in for `URLSession.bytes(for:)`. The patch does both, and all 60 of those tests pass.
- **Dependencies live in the web repository.** Upstream's `Package.swift` declares none, so swift-crypto and `CSQLite` are declared Linux-only in this repository's `Package.swift`. Use a swift-crypto range that admits Hummingbird's 5.x, such as `"3.12.3"..<"6.0.0"`.
- **Pull requests on `FRUS-Explorer`.** Answered on 3 October: not for now, so S1, S3 and S6 wait. Upstream already has a `Mac` label for rule 4.
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

  The TEI hash comparison needs S3 and S6, so it waits.
- **The trigger cannot be a file appearing.** A file copied in with `docker compose cp` is visible under its final name while it is still copying.
- **The owner's export is a real input for local Import trials** while the pin stays at index version 65.

## Before the S3, S4 and S6 prompts

- **"Every Linux change to a shared file is a guard" holds only for S1.** S3's 15 app files and S6's 48 (36,861 lines, 19 of them edited) also need declarations moved out of Apple-only files: WebKit, SwiftUI, AppKit or UIKit, and SwiftData `@Model` files. That is an upstream refactor pull request, best landed after the public release. `s3-linux-edits.tsv` and `s6-linux-edits.tsv` list every change.
- **`String(localized:)` has no Linux form.** The S3 files use it 46 times. `shims/StringLocalizedShim.swift` covers the forms they use, including `format:`.
- **S3's citation matcher needs SearchService and ManifestStore,** which are S6's work. Either limit S3 to the TEI files and the citation formatter, or move the matcher to S6.
- **The S3 row names no upstream pull request.** The session diagram has no Mac check between S3 and S4, though the owner checkpoints list Mac check 2 there.
- **Golden files cannot come from the owner's 553-volume library.** BM25 ranks with whole-index statistics, so 5 of 7 test queries ordered differently against a three-volume index, and person rollups span volumes. The procedure needs a Mac library holding exactly the three fixture volumes, for example under a second macOS user. The S4 summary script should refuse any other export.
- **Check 4 asks for 500 or more documents.** The fixtures hold 383 documents in 392 rows. Define check 4 on the fixtures for phase 0, and run the full check on the real TEI at S10.
- **The S6 file set reads 8 JSON resources through `Bundle.main`.** On Linux they must sit beside the executable or the test runner, or indexing degrades without an error.
- **`IndexingPipeline.swift` imports CryptoKit, OSLog, SQLite3 and CoreSpotlight,** and UIKit on iOS. SwiftData reaches it only through one `@Model` parameter. Its 35 logging lines compile unchanged against the Linux logging shim.

## Sizing

A full export is 2.83 GB, not 9.3 GB. The larger figure came from an index overhead factor of 2.8 measured on 31 May, before the 9 June change to external-content FTS tables stopped storing a second copy of the text. An export that includes the owner's writing is not vacuumed, so it can be larger, up to the size of the live file. The disk and memory figures in `PLAN.md`, `SPEC.md` and `scripts/mac-check` that rest on 9.3 GB can shrink; none matters before S10.

## Pinning until the public release

`FRUS-Explorer` merges about eight pull requests a day until its public release, and its index version went from 47 to 65 in 30 days. Each pin move means a new Mac build, a new export and new golden files. Hold the pin at `34a5120` until the release unless a merged guard pull request needs it, and batch upstream pull requests so the pin moves as few times as possible. Make the golden files and the S10 export once, against a pin from after the release.

## Files

| File | What it holds |
| --- | --- |
| `s1-linux-guards.patch` | The S1 guards. It applies with `git apply` to `FRUS-Explorer` at `34a5120`: 15 files and 92 added lines, each inside a `#if canImport` guard, plus a new Linux-only `FTS5Store/LinuxLogger.swift`. With swift-crypto and `CSQLite` declared Linux-only, TEIHeaderKit, SemanticVectorsKit and FTS5Store build on Linux with no warnings. SemanticVectorsKitTests (35) and ManifestGeneratorTests (60) pass, and FTS5StoreTests passes 208 of 209 |
| `s3-linux-edits.tsv`, `s6-linux-edits.tsv` | Every change it took to compile the S3 and S6 file sets on Linux, one per line: the kind (import-guard, code-guard, model-guard, move, shim, stub or dropped), the file and the detail |
| `shims/` | Linux stand-ins for `autoreleasepool`, `String(localized:)` and the Keychain store, from that build. They are scratch work, to review before use |
