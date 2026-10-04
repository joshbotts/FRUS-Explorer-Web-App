# Development log

One entry per session, newest first.

## Session 4: the parity harness

3 October 2026 · branch `claude/s4-parity-harness`

S4 builds what checks 2–4 compare, and already runs on Linux the part of check 3 that needs no further upstream code. The owner decided three things on 3 October:
- S4 copies no upstream code, so renderer parity on Linux waits for S3 (rule 4).
- Check 3 passes when results differ only in the order of documents whose Mac scores are exactly equal, and reports each such group.
- The golden files that depend only on the app's source are made in the session, on the owner's Mac. The owner makes the two that need an export.

**Delivered**

- **Golden-file formats** (`Tests/ParityFormat`), shared by the Linux harness and the Mac tool. Each golden file records the tool that made it, the upstream commit, the app build (49), the index version (65), a digest of the submodule's Swift sources, a digest of each input file, and the platform. A test recomputes the digests, so a golden file made before a pin move, or from another query list or other fixtures, fails as stale.
- **`tools/mac-golden`**, a Mac-only tool that runs the app's own code. Its package compiles the whole app module unmodified: all 520 Swift files, through six directory symlinks into the submodule, plus a one-line stub for an asset symbol that Xcode generates and SwiftPM does not. It needs macOS 26, because the app uses FoundationModels, and a debug build, because it imports the app with `@testable`. A clean build takes 45 seconds. CI does not build it.
  - `render` takes every row a full parse of each fixture volume yields and runs the Mac reader's own path: `DocumentViewModel.load`, then `HTMLTemplate.build`. It keeps the fragment inside `<body>` and copies none of the app's settings.
  - `expressions` runs SearchService's `parsedQuery(for:)`, `matchExpressions(for:)` and `exactTerms(from:)` over a throwaway empty database. The records are the same over a fixture index.
  - `results` runs `searchCount` and the first 50 results over a copy of an export, recording each score's bits. It refuses an export that is not exactly the three fixture volumes, that holds the owner's writing, or that has another index version. It also records the results after the 50th that tie with it, so a tie group crossing position 50 is known whole.
- **`frus-parity`** (`Tests/FRUSParity`, `Tests/FRUSParityTool`), on Linux and macOS:
  - `summarize` writes check 2's summary of a `frus.db`. It opens the file read-only and immutable, and hashes each table's rows with SHA-256 in natural-key order, framed as SQLite's `sha3_query` frames them, recording each statement's SQL.
    - It leaves out whatever depends on indexing history: rowids and other surrogate ids (a person rollup is named by its least member), the key order of `volume_structures`' JSON (read through `json_tree`), and the FTS5 segment layout. For full-text tables it compares `_config`, the averages record, `_docsize` by document, and the vocabulary.
    - The order of rows within a volume gates only for `document_cache`, `page_ranges` and `cross_references`, which the app reads in that order. `person_mentions` and `person_list_sources` are built from Swift sets, so their order changes from run to run.
    - It refuses an export that is not exactly the three fixture volumes (unless given `--any-volumes`), one with writing, one with another index version, one with a `-wal` file beside it, one with a stale person rollup, and one holding any schema object it cannot classify.
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

- **Tests.** FRUSParityTests' 41 tests pass on Linux arm64 and natively on macOS, with no warnings and none skipped. The other targets are unchanged (358 tests).
- **Check 3's parse runs on Linux now.** For all 482 queries, the parser compiled on Linux gives the same expression, exact terms, operands, dropped operands and flags as the app's SearchService on the Mac. CI adds amd64.
- **The summary does not depend on SQLite's version.** Two three-volume databases were built from the owner's export, with the volumes in different orders and the rollup renumbered. They gave identical gating hashes on macOS (SQLite 3.54.0) and on Linux (3.45.1). The full 2.83 GB export took 19 seconds to summarize natively, read-only, using 38 MB of memory.
- **The render is stable.** Two runs, another build, and other time zones and locales all gave byte-identical HTML. It matches, for all 392 rows, the research build that used the reader's settings. The fields the reader is opened with do not change it; the tool checks that on every 25th row.
- **Ties are common.** On a three-volume index, 72 queries have exactly tied scores in their top 50, and 12 have a tie group crossing position 50. `results` was tested on a research copy built from the owner's export, not on a new export.

**What waits**

- Index parity (check 2), and check 3's counts and results, need the Linux indexer and SearchService (S6), and the owner's golden files.
- Renderer parity (check 4) on Linux needs the TEI pipeline (S3).
- 25 queries outside the default scope compile column-scoped expressions inside SearchService, so Linux compares them in S6.

**Notes**

- **Docker Desktop hung for about two hours.** A research container mounted the owner's export from `~/Documents`, and macOS held the mount behind a privacy prompt. No container started until the owner answered it. Nothing mounts `~/Documents` now; `scripts/make-golden` copies the export to a temporary folder first.
- **The Mac tool is outside CI.** A pin move can break it unseen until the next golden refresh, which `scripts/make-golden` then reports.
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
