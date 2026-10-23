# FRUS Explorer Light

FRUS Explorer Light is a self-hosted web edition of [FRUS Explorer](https://github.com/joshbotts/FRUS-Explorer), the iOS, iPadOS and macOS app for researching the *Foreign Relations of the United States* series. One container serves the corpus, its full-text index, and each researcher's notes and highlights to any modern browser.

## Status

Phase 1 is done: a Docker Compose install that serves a FRUS Explorer research export, read-only, at `http://localhost:8080`. The owner signed it off on 13 October 2026. [`docs/INSTALL.md`](docs/INSTALL.md) is the install guide, [`docs/PLAN.md`](docs/PLAN.md) the plan and [`docs/DEVLOG.md`](docs/DEVLOG.md) the record of each session.

**What works today**, from the published image `ghcr.io/joshbotts/frus-explorer-light:edge`, for amd64 and arm64:

- Import of a Mac export copied into the `/data` volume, checked and served read-only. The server refuses an export from another index version and one that holds the owner's writing.
- Search with the app's query language, with the facets, the Query Inspector, the order by relevance or date, and the timeline and concordance readings, each saying which results it read. Each result carries its date, drawn as the app draws it, and a search you replace stops on the server.
- Browse, which lists a section's own text first, as the app does: a meeting's list of those present, say, above its minutes. The reader, with its text size and Reading Width, its links, which follow a printed page into a volume the server does not hold as 1.0 does, and the cards for people and terms. All of it is usable by keyboard and free of axe violations.
- Cite, with BibTeX and RIS.
- Parity with the Mac app, checked in CI on three fixture volumes: the same index rows, search results and document HTML. The server compiles the app's own Swift code from a pinned submodule.
- A daily CI watch of the app's `v2` branch, which reports in one issue what the next pin move has to handle.

**Known gaps**

- **Behind FRUS Explorer 1.0's last step.** The pin is 1.0 build 1776, the TestFlight build, at index version 71, with [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784) one commit after it: the server serves that build's exports, and its image is also tagged `:1.0-1776`. The App Store build, 1861, waits for S12d.
- **Phase-1 features still to come:** faster exact-word search.
- **Later phases:**
  - no notes, highlights or collections on the web (phase 2);
  - no accounts, sharing beyond localhost, or indexing from TEI on the server (phase 3);
  - no search by meaning (phase 4);
  - no AWS deployment (phase 6).

**Next**

1. **Before a release**: faster exact-word search (S13b).
2. **S12d**, once the app tags `version-1.0`: the pin moves to 1.0 build 1861, the App Store build, and CI publishes `:1.0-1861`.
3. **Phase 2**: user data and its nightly backup.

## Goals

- **Keep the research tools.** Browse, full-text search with the app's query language, the reader with highlights and notes, collections and their exports, citation tools, Source Explorer and analytics all stay. Search by meaning follows in a later phase.
- **Match the Mac app's results.** On the same inputs, the web edition must produce the same index rows, the same search results in the same order, and the same document HTML.
- **Serve a researcher or a small group.** One person on a laptop or a home server, or a class or team sharing one instance. It is not designed as a public, high-traffic site.
- **Deploy simply.** Docker Compose on a Mac or a Linux host first; a managed deployment on AWS follows in phase 6.

"Light" leaves out what depends on Apple-only frameworks: summary generation, iCloud sync, widgets and Live Activities, Spotlight, Handoff, TipKit tips, Audio Graphs and native multi-window scenes. Browser tabs replace windows, and data tables replace Audio Graphs. Summaries imported from the app are shown with their authorship labels, and people can write their own.

## Architecture

A Swift 6 server owns two SQLite files: `frus.db`, the corpus index, and `app.db`, the users and their data. The browser runs a TypeScript single-page app and shows document HTML that the server renders.

```mermaid
flowchart LR
  B[Browser] -->|localhost:8080| S
  subgraph C[Docker Compose on a Mac or a Linux host]
    S[frus-light server<br/>Swift 6, Hummingbird] --- I[(frus.db<br/>imported Mac export)]
    S --- U[(app.db<br/>users and their data)]
    S -.-> P[Gotenberg<br/>optional PDF]
  end
  T[/TEI volumes folder<br/>mounted read-only/] --> S
  S -.-> X[GitHub, NARA, Zotero]
```

The diagram shows the Docker Compose install that ships first, with both databases in the `/data` volume. From phase 6, the same image also runs on AWS as one ECS task, with the index copied from S3.

| Part | Technology | Role |
| --- | --- | --- |
| Server | Swift 6 on Linux, Hummingbird 2 | REST API, sessions, jobs, and the single-page app's static files |
| Shared core | The Mac app's own Swift files, compiled from a pinned `FRUS-Explorer` submodule | Indexing, search and its query language, TEI parsing and HTML, citations, Source Explorer |
| Corpus index | SQLite FTS5 with the `porter unicode61` tokenizer | The Mac index's schema, at the pinned index version |
| User store | SQLite, with FTS5 over each user's notes and summaries | Notes, highlights, tags, collections, projects, users and sessions |
| Web client | TypeScript, React and Vite | Every screen. The reader reuses the app's own HTML, CSS and JavaScript in a sandboxed iframe |
| Optional services | `llama-server` running EmbeddingGemma; Gotenberg | Search by meaning; PDF export |

### Design decisions

| Decision | Reason |
| --- | --- |
| The index lives on the server, and the browser is a thin client | A container has real disk and CPU, so SQLite FTS5 runs natively, and one copy of user data needs no sync engine |
| The server compiles the Mac app's own Swift files | Query parsing, source-note parsing, citation matching and TEI rendering are large and heavily tested, and a second implementation would drift |
| The index comes from a Mac export, or the server builds it from TEI | The Mac's Export Research Database… file is version-stamped and verifiable, so serving it ships first; indexing on Linux follows |
| User data lives apart from the corpus index | The Mac index copies notes, summaries and tags into corpus rows, which a shared server cannot do |
| Summaries are shown and hand-written, never generated | Apple's on-device FoundationModels framework has no Linux equivalent |
| The reader reuses the app's rendering assets | Highlight offsets depend on that exact document structure |

## Deployment

- **Docker Compose, first:** one image and one Compose file on a Mac or a Linux host, listening on 127.0.0.1. Everything the server keeps lives in a named volume at `/data`, because SQLite's write-ahead log needs a local filesystem, and on a Mac a folder shared from macOS into Docker's virtual machine is not one. A folder of TEI volumes is mounted read-only, and a Mac export is imported with `docker compose cp`. CI publishes the image to GitHub Container Registry for amd64 and arm64.
- **AWS, in phase 6:** one ECS task on Fargate, in private subnets behind an Application Load Balancer that handles sign-in. At start the task copies a read-only snapshot of the index from S3 and opens it with SQLite's `immutable=1`. User data stays in SQLite, replicated to S3 by Litestream. A deploy stops the old task before starting the new one, trading a short outage for a single writer and no database service. The estimate is about $155–170 a month.

## Documents

- [`docs/INSTALL.md`](docs/INSTALL.md): installing the server with Docker Compose on a Mac or a Linux host, and importing a FRUS Explorer export.
- [`docs/PLAN.md`](docs/PLAN.md): the development plan. It covers the owner's setup, the rules every session follows, eleven sessions to phase 1 as a Compose install, the Compose install itself, the deferred AWS design, owner checkpoints and risks.
- [`docs/COORDINATION.md`](docs/COORDINATION.md): how the web edition and the Mac app's repository work together. App sessions follow four rules; web sessions carry the rest.
- [`docs/SPEC.md`](docs/SPEC.md): the specification. It covers what the web edition keeps, its architecture, data and operating modes, the HTTP API, deployment and runtime options, the managed-platform variant, verification and the delivery plan.
- [`docs/prep/`](docs/prep/README.md): readiness notes from a Linux dry run on 3 October, with the changes sessions 1–6 will need in the shared Swift files.
- Both files have living copies in shared documents, the [specification](https://claude.ai/code/artifact/b4714a33-dd0c-4205-a78f-6839a718afca) and the [plan](https://claude.ai/code/artifact/14a2723a-7662-496d-b7c4-1aa33678233e); ask the owner for access.
- The FRUS volumes come from the Office of the Historian's public [HistoryAtState/frus](https://github.com/HistoryAtState/frus) repository.

## License

Apache License 2.0; see [`LICENSE`](LICENSE). The FRUS text itself is in the public domain. EmbeddingGemma is never bundled with the image: an admin downloads it only after accepting the Gemma Terms of Use.
